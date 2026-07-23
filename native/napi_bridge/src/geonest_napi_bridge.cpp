#include "geonest_napi_bridge.h"

#include "geonest_gis_core.h"
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstring>
#include <cstdlib>
#include <deque>
#include <map>
#include <memory>
#include <mutex>
#include <new>
#include <string>
#include <vector>

static constexpr size_t MAX_PROCESSING_REQUEST_BYTES = 1024 * 1024;

enum class DynamicStringReadStatus {
    Ok,
    MissingArgument,
    InvalidType,
    EmptyValue,
    TooLarge,
    ReadFailed,
    AllocationFailed
};

// ---------------------------------------------------------------------------
// Helper: extract C string from napi_value
// ---------------------------------------------------------------------------
static bool GetStringArg(napi_env env, napi_callback_info info, size_t maxArgs, char *buf, size_t bufSize)
{
    size_t argc = maxArgs;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 1) return false;
    size_t result = 0;
    napi_get_value_string_utf8(env, args[0], buf, bufSize, &result);
    return result > 0;
}

static bool GetStringValue(napi_env env, napi_value value, char *buf, size_t bufSize)
{
    size_t result = 0;
    napi_get_value_string_utf8(env, value, buf, bufSize, &result);
    return result > 0;
}

static DynamicStringReadStatus GetStringArgDynamic(napi_env env, napi_callback_info info, std::string &value)
{
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) != napi_ok) {
        return DynamicStringReadStatus::ReadFailed;
    }
    if (argc < 1) {
        return DynamicStringReadStatus::MissingArgument;
    }
    napi_valuetype valueType = napi_undefined;
    if (napi_typeof(env, args[0], &valueType) != napi_ok) {
        return DynamicStringReadStatus::ReadFailed;
    }
    if (valueType != napi_string) {
        return DynamicStringReadStatus::InvalidType;
    }
    size_t requiredLength = 0;
    napi_status status = napi_get_value_string_utf8(env, args[0], nullptr, 0, &requiredLength);
    if (status != napi_ok) {
        return DynamicStringReadStatus::ReadFailed;
    }
    if (requiredLength == 0) {
        return DynamicStringReadStatus::EmptyValue;
    }
    if (requiredLength > MAX_PROCESSING_REQUEST_BYTES) {
        return DynamicStringReadStatus::TooLarge;
    }
    try {
        std::vector<char> buffer(requiredLength + 1, 0);
        size_t copiedLength = 0;
        status = napi_get_value_string_utf8(env, args[0], buffer.data(), buffer.size(), &copiedLength);
        if (status != napi_ok || copiedLength == 0) {
            return DynamicStringReadStatus::ReadFailed;
        }
        value.assign(buffer.data(), copiedLength);
    } catch (const std::bad_alloc &) {
        value.clear();
        return DynamicStringReadStatus::AllocationFailed;
    } catch (...) {
        value.clear();
        return DynamicStringReadStatus::ReadFailed;
    }
    return DynamicStringReadStatus::Ok;
}

static const char *DynamicStringReadError(DynamicStringReadStatus status)
{
    switch (status) {
        case DynamicStringReadStatus::MissingArgument:
            return "Processing request argument is missing";
        case DynamicStringReadStatus::InvalidType:
            return "Processing request must be a string";
        case DynamicStringReadStatus::EmptyValue:
            return "Processing request is empty";
        case DynamicStringReadStatus::TooLarge:
            return "Processing request exceeds the 1 MiB limit";
        case DynamicStringReadStatus::AllocationFailed:
            return "Processing request memory allocation failed";
        case DynamicStringReadStatus::ReadFailed:
            return "Processing request could not be read";
        case DynamicStringReadStatus::Ok:
        default:
            return "";
    }
}

static napi_value CreateGeoProcessResult(napi_env env, const char *resultInfo, int32_t errCode)
{
    napi_value result = nullptr;
    if (napi_create_object(env, &result) != napi_ok || result == nullptr) {
        return nullptr;
    }

    napi_value infoVal = nullptr;
    const char *safeResult = resultInfo ? resultInfo :
        "{\"ok\":false,\"code\":5,\"message\":\"Processing result allocation failed\","
        "\"outputPath\":\"\",\"outputLayerName\":\"\",\"featureCount\":0,"
        "\"executionId\":\"\",\"elapsedMs\":0,\"environment\":{},\"messages\":[]}";
    if (napi_create_string_utf8(env, safeResult, NAPI_AUTO_LENGTH, &infoVal) != napi_ok || infoVal == nullptr) {
        return nullptr;
    }
    if (napi_set_named_property(env, result, "resultInfo", infoVal) != napi_ok) {
        return nullptr;
    }

    napi_value errVal = nullptr;
    if (napi_create_int32(env, errCode, &errVal) != napi_ok || errVal == nullptr) {
        return nullptr;
    }
    if (napi_set_named_property(env, result, "errCode", errVal) != napi_ok) {
        return nullptr;
    }
    return result;
}

// ---------------------------------------------------------------------------
// Background processing queue
// ---------------------------------------------------------------------------

struct NativeProcessingTask {
    std::string taskId;
    std::atomic<int32_t> progressPermille {0};
    std::atomic<int64_t> processedCount {0};
    std::atomic<int64_t> startedAtMs {0};
    std::atomic<int64_t> elapsedMs {0};
    std::atomic<bool> cancelRequested {false};
    std::atomic<bool> done {false};
    std::mutex statusMutex;
    std::string state = "queued";
    std::string stage = "queued";
    std::string message = "Task queued";
    std::string resultInfo;
    int32_t errCode = geonest::GIS_OK;
    geonest::PreparedProcessingTask *preparedTask = nullptr;
    napi_env env = nullptr;
    napi_async_work work = nullptr;
};

struct NativeProcessingWork {
    explicit NativeProcessingWork(const std::shared_ptr<NativeProcessingTask> &taskValue) : task(taskValue) {}
    std::shared_ptr<NativeProcessingTask> task;
    geonest::PreparedProcessingTask *preparedTask = nullptr;
};

static std::mutex g_processingQueueMutex;
static std::map<std::string, std::shared_ptr<NativeProcessingTask>> g_processingTasks;
static std::deque<std::shared_ptr<NativeProcessingTask>> g_processingQueue;
static std::shared_ptr<NativeProcessingTask> g_activeProcessingTask;
static std::atomic<uint64_t> g_processingTaskSequence {1};
static bool g_processingQueueShuttingDown = false;
static napi_async_cleanup_hook_handle g_pendingProcessingCleanup = nullptr;
static napi_env g_processingOwnerEnv = nullptr;

static int64_t ProcessingClockMilliseconds()
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}

static std::string CreateProcessingTaskId()
{
    uint64_t sequence = g_processingTaskSequence.fetch_add(1, std::memory_order_relaxed);
    return "native-processing-" + std::to_string(ProcessingClockMilliseconds()) + "-" +
        std::to_string(sequence);
}

static std::string EscapeTaskJsonString(const std::string &value)
{
    std::string result;
    result.reserve(value.size() + 16);
    for (size_t i = 0; i < value.size(); i++) {
        unsigned char current = static_cast<unsigned char>(value[i]);
        if (current == '"') {
            result += "\\\"";
        } else if (current == '\\') {
            result += "\\\\";
        } else if (current == '\n') {
            result += "\\n";
        } else if (current == '\r') {
            result += "\\r";
        } else if (current == '\t') {
            result += "\\t";
        } else if (current < 0x20) {
            result += ' ';
        } else {
            result += static_cast<char>(current);
        }
    }
    return result;
}

static std::string BuildBackgroundFailureResult(const std::string &taskId, int32_t errCode,
                                                const std::string &message)
{
    std::string result = "{\"ok\":false,\"code\":";
    result += std::to_string(errCode);
    result += ",\"message\":\"";
    result += EscapeTaskJsonString(message);
    result += "\",\"outputPath\":\"\",\"outputLayerName\":\"\",\"featureCount\":0,";
    result += "\"executionId\":\"";
    result += EscapeTaskJsonString(taskId);
    result += "\",\"elapsedMs\":0,\"environment\":{},\"messages\":[]}";
    return result;
}

static void FreePreparedTask(const std::shared_ptr<NativeProcessingTask> &task)
{
    geonest::PreparedProcessingTask *preparedTask = task->preparedTask;
    task->preparedTask = nullptr;
    if (preparedTask) {
        geonest::FreePreparedProcessingTask(preparedTask);
    }
}

static bool MarkBackgroundTaskTerminal(const std::shared_ptr<NativeProcessingTask> &task,
                                       const std::string &state, int32_t errCode,
                                       const std::string &message, const std::string &resultInfo)
{
    std::lock_guard<std::mutex> lock(task->statusMutex);
    if (task->done.load(std::memory_order_acquire)) {
        return false;
    }
    task->state = state;
    task->stage = state;
    task->message = message;
    task->resultInfo = resultInfo;
    task->errCode = errCode;
    if (state == "succeeded") {
        task->progressPermille.store(1000, std::memory_order_relaxed);
    }
    task->done.store(true, std::memory_order_release);
    return true;
}

static void MarkBackgroundTaskCanceled(const std::shared_ptr<NativeProcessingTask> &task,
                                       const std::string &message)
{
    MarkBackgroundTaskTerminal(task, "canceled", geonest::GIS_ERR_CANCELED, message,
        BuildBackgroundFailureResult(task->taskId, geonest::GIS_ERR_CANCELED, message));
}

static void FreePreparedWorkTask(NativeProcessingWork *workContext)
{
    if (!workContext || !workContext->preparedTask) {
        return;
    }
    geonest::FreePreparedProcessingTask(workContext->preparedTask);
    workContext->preparedTask = nullptr;
}

static bool BackgroundTaskIsCanceled(void *userData)
{
    NativeProcessingTask *task = static_cast<NativeProcessingTask *>(userData);
    return !task || task->cancelRequested.load(std::memory_order_acquire);
}

static void BackgroundTaskReportProgress(void *userData, double progress, int64_t processedCount,
                                         const char *stage)
{
    NativeProcessingTask *task = static_cast<NativeProcessingTask *>(userData);
    if (!task) {
        return;
    }
    double safeProgress = std::max(0.0, std::min(100.0, progress));
    int32_t progressPermille = static_cast<int32_t>(safeProgress * 10.0 + 0.5);
    task->progressPermille.store(progressPermille, std::memory_order_relaxed);
    task->processedCount.store(std::max<int64_t>(0, processedCount), std::memory_order_relaxed);
    if (stage && std::strlen(stage) > 0) {
        std::lock_guard<std::mutex> lock(task->statusMutex);
        task->stage = stage;
        if (!task->cancelRequested.load(std::memory_order_relaxed)) {
            task->message = stage;
        }
    }
}

static bool SetTaskStringProperty(napi_env env, napi_value object, const char *name,
                                  const std::string &value)
{
    napi_value property = nullptr;
    if (napi_create_string_utf8(env, value.c_str(), value.size(), &property) != napi_ok || !property) {
        return false;
    }
    return napi_set_named_property(env, object, name, property) == napi_ok;
}

static bool SetTaskInt32Property(napi_env env, napi_value object, const char *name, int32_t value)
{
    napi_value property = nullptr;
    if (napi_create_int32(env, value, &property) != napi_ok || !property) {
        return false;
    }
    return napi_set_named_property(env, object, name, property) == napi_ok;
}

static bool SetTaskInt64Property(napi_env env, napi_value object, const char *name, int64_t value)
{
    napi_value property = nullptr;
    if (napi_create_int64(env, value, &property) != napi_ok || !property) {
        return false;
    }
    return napi_set_named_property(env, object, name, property) == napi_ok;
}

static bool SetTaskDoubleProperty(napi_env env, napi_value object, const char *name, double value)
{
    napi_value property = nullptr;
    if (napi_create_double(env, value, &property) != napi_ok || !property) {
        return false;
    }
    return napi_set_named_property(env, object, name, property) == napi_ok;
}

static bool SetTaskBooleanProperty(napi_env env, napi_value object, const char *name, bool value)
{
    napi_value property = nullptr;
    if (napi_get_boolean(env, value, &property) != napi_ok || !property) {
        return false;
    }
    return napi_set_named_property(env, object, name, property) == napi_ok;
}

static napi_value CreateProcessingTaskStatus(napi_env env,
                                             const std::shared_ptr<NativeProcessingTask> &task)
{
    napi_value result = nullptr;
    if (napi_create_object(env, &result) != napi_ok || !result) {
        return nullptr;
    }

    std::string state;
    std::string stage;
    std::string message;
    std::string resultInfo;
    int32_t errCode = geonest::GIS_OK;
    bool done = false;
    {
        std::lock_guard<std::mutex> lock(task->statusMutex);
        state = task->state;
        stage = task->stage;
        message = task->message;
        resultInfo = task->resultInfo;
        errCode = task->errCode;
        done = task->done.load(std::memory_order_acquire);
    }
    int64_t elapsedMs = task->elapsedMs.load(std::memory_order_relaxed);
    int64_t startedAtMs = task->startedAtMs.load(std::memory_order_relaxed);
    if (!done && startedAtMs > 0) {
        elapsedMs = std::max<int64_t>(0, ProcessingClockMilliseconds() - startedAtMs);
    }

    if (!SetTaskStringProperty(env, result, "taskId", task->taskId) ||
        !SetTaskStringProperty(env, result, "state", state) ||
        !SetTaskDoubleProperty(env, result, "progress",
            static_cast<double>(task->progressPermille.load(std::memory_order_relaxed)) / 10.0) ||
        !SetTaskInt64Property(env, result, "processedCount",
            task->processedCount.load(std::memory_order_relaxed)) ||
        !SetTaskStringProperty(env, result, "stage", stage) ||
        !SetTaskStringProperty(env, result, "message", message) ||
        !SetTaskStringProperty(env, result, "resultInfo", resultInfo) ||
        !SetTaskInt32Property(env, result, "errCode", errCode) ||
        !SetTaskInt64Property(env, result, "elapsedMs", elapsedMs) ||
        !SetTaskBooleanProperty(env, result, "cancelRequested",
            task->cancelRequested.load(std::memory_order_relaxed)) ||
        !SetTaskBooleanProperty(env, result, "done", done)) {
        return nullptr;
    }
    return result;
}

static std::shared_ptr<NativeProcessingTask> CreateTransientTaskStatus(const std::string &taskId,
                                                                       int32_t errCode,
                                                                       const std::string &message,
                                                                       const std::string &state)
{
    std::shared_ptr<NativeProcessingTask> task = std::make_shared<NativeProcessingTask>();
    task->taskId = taskId;
    MarkBackgroundTaskTerminal(task, state, errCode, message,
        BuildBackgroundFailureResult(taskId, errCode, message));
    return task;
}

static std::shared_ptr<NativeProcessingTask> FindBackgroundTask(const std::string &taskId)
{
    std::lock_guard<std::mutex> lock(g_processingQueueMutex);
    std::map<std::string, std::shared_ptr<NativeProcessingTask>>::iterator iterator =
        g_processingTasks.find(taskId);
    if (iterator == g_processingTasks.end()) {
        return std::shared_ptr<NativeProcessingTask>();
    }
    return iterator->second;
}

static void ScheduleNextBackgroundTask(napi_env env);

static void ExecuteBackgroundProcessing(napi_env env, void *data)
{
    (void)env;
    NativeProcessingWork *workContext = static_cast<NativeProcessingWork *>(data);
    if (!workContext || !workContext->task) {
        return;
    }
    std::shared_ptr<NativeProcessingTask> task = workContext->task;
    task->startedAtMs.store(ProcessingClockMilliseconds(), std::memory_order_relaxed);
    {
        std::lock_guard<std::mutex> lock(task->statusMutex);
        task->state = task->cancelRequested.load(std::memory_order_relaxed) ?
            "cancelRequested" : "running";
        task->stage = task->cancelRequested.load(std::memory_order_relaxed) ?
            "cancelRequested" : "preparing";
        task->message = task->cancelRequested.load(std::memory_order_relaxed) ?
            "Task cancellation requested" : "Task started";
    }

    if (task->cancelRequested.load(std::memory_order_acquire)) {
        task->elapsedMs.store(std::max<int64_t>(0,
            ProcessingClockMilliseconds() - task->startedAtMs.load(std::memory_order_relaxed)),
            std::memory_order_relaxed);
        FreePreparedWorkTask(workContext);
        MarkBackgroundTaskCanceled(task, "Task canceled before execution");
        return;
    }

    geonest::ProcessingCallbacks callbacks;
    callbacks.userData = task.get();
    callbacks.isCanceled = BackgroundTaskIsCanceled;
    callbacks.reportProgress = BackgroundTaskReportProgress;

    int32_t errCode = geonest::GIS_ERR_NATIVE_NOT_READY;
    const char *nativeResult = nullptr;
    try {
        nativeResult = geonest::RunPreparedProcessingTask(workContext->preparedTask, &callbacks, &errCode);
    } catch (const std::bad_alloc &) {
        errCode = geonest::GIS_ERR_NATIVE_NOT_READY;
    } catch (...) {
        errCode = geonest::GIS_ERR_NATIVE_NOT_READY;
    }

    std::string resultInfo;
    if (nativeResult) {
        resultInfo = nativeResult;
        geonest::FreeCString(const_cast<char *>(nativeResult));
    }
    FreePreparedWorkTask(workContext);
    task->elapsedMs.store(std::max<int64_t>(0,
        ProcessingClockMilliseconds() - task->startedAtMs.load(std::memory_order_relaxed)),
        std::memory_order_relaxed);

    if (errCode == geonest::GIS_ERR_CANCELED) {
        MarkBackgroundTaskCanceled(task, "Task canceled");
    } else if (errCode == geonest::GIS_OK && !resultInfo.empty()) {
        MarkBackgroundTaskTerminal(task, "succeeded", geonest::GIS_OK,
            "Task completed", resultInfo);
    } else {
        if (errCode == geonest::GIS_OK) {
            errCode = geonest::GIS_ERR_NATIVE_NOT_READY;
        }
        if (resultInfo.empty()) {
            resultInfo = BuildBackgroundFailureResult(task->taskId, errCode,
                "Background processing failed");
        }
        MarkBackgroundTaskTerminal(task, "failed", errCode,
            "Background processing failed", resultInfo);
    }
}

static void CompleteBackgroundProcessing(napi_env env, napi_status status, void *data)
{
    NativeProcessingWork *workContext = static_cast<NativeProcessingWork *>(data);
    if (!workContext || !workContext->task) {
        delete workContext;
        return;
    }
    std::shared_ptr<NativeProcessingTask> task = workContext->task;
    if (status == napi_cancelled && !task->done.load(std::memory_order_acquire)) {
        FreePreparedWorkTask(workContext);
        MarkBackgroundTaskCanceled(task, "Task canceled before execution");
    } else if (status != napi_ok && !task->done.load(std::memory_order_acquire)) {
        FreePreparedWorkTask(workContext);
        MarkBackgroundTaskTerminal(task, "failed", geonest::GIS_ERR_NATIVE_NOT_READY,
            "Native async work failed",
            BuildBackgroundFailureResult(task->taskId, geonest::GIS_ERR_NATIVE_NOT_READY,
                "Native async work failed"));
    }
    FreePreparedWorkTask(workContext);

    napi_async_work completedWork = nullptr;
    {
        std::lock_guard<std::mutex> lock(task->statusMutex);
        completedWork = task->work;
        task->work = nullptr;
    }
    if (completedWork) {
        napi_delete_async_work(env, completedWork);
    }

    napi_async_cleanup_hook_handle cleanupHandle = nullptr;
    bool scheduleNext = false;
    {
        std::lock_guard<std::mutex> lock(g_processingQueueMutex);
        if (g_activeProcessingTask.get() == task.get()) {
            g_activeProcessingTask.reset();
        }
        if (g_processingQueueShuttingDown && !g_activeProcessingTask) {
            cleanupHandle = g_pendingProcessingCleanup;
            g_pendingProcessingCleanup = nullptr;
            g_processingQueue.clear();
            g_processingTasks.clear();
            g_processingOwnerEnv = nullptr;
            g_processingQueueShuttingDown = false;
        } else if (!g_processingQueueShuttingDown) {
            scheduleNext = true;
        }
    }
    delete workContext;

    if (cleanupHandle) {
        napi_remove_async_cleanup_hook(cleanupHandle);
    } else if (scheduleNext) {
        ScheduleNextBackgroundTask(env);
    }
}

static void MarkBackgroundSchedulingFailure(const std::shared_ptr<NativeProcessingTask> &task,
                                            const std::string &message)
{
    FreePreparedTask(task);
    MarkBackgroundTaskTerminal(task, "failed", geonest::GIS_ERR_NATIVE_NOT_READY, message,
        BuildBackgroundFailureResult(task->taskId, geonest::GIS_ERR_NATIVE_NOT_READY, message));
}

static void ScheduleNextBackgroundTask(napi_env env)
{
    while (true) {
        std::shared_ptr<NativeProcessingTask> task;
        NativeProcessingWork *workContext = nullptr;
        {
            std::lock_guard<std::mutex> lock(g_processingQueueMutex);
            if (g_processingQueueShuttingDown || g_activeProcessingTask) {
                return;
            }
            while (!g_processingQueue.empty()) {
                task = g_processingQueue.front();
                g_processingQueue.pop_front();
                if (task && !task->done.load(std::memory_order_acquire)) {
                    break;
                }
                task.reset();
            }
            if (!task) {
                return;
            }
            workContext = new (std::nothrow) NativeProcessingWork(task);
            if (workContext) {
                workContext->preparedTask = task->preparedTask;
                task->preparedTask = nullptr;
                g_activeProcessingTask = task;
            }
        }

        if (!workContext) {
            MarkBackgroundSchedulingFailure(task, "Cannot allocate native async work context");
            continue;
        }
        if (!workContext->preparedTask) {
            MarkBackgroundTaskTerminal(task, "failed", geonest::GIS_ERR_NATIVE_NOT_READY,
                "Prepared processing task ownership was lost",
                BuildBackgroundFailureResult(task->taskId, geonest::GIS_ERR_NATIVE_NOT_READY,
                    "Prepared processing task ownership was lost"));
        } else {
            napi_value resourceName = nullptr;
            napi_status status = napi_create_string_utf8(env, "GeoNestProcessingTask", NAPI_AUTO_LENGTH,
                &resourceName);
            napi_async_work work = nullptr;
            if (status == napi_ok && resourceName) {
                status = napi_create_async_work(env, nullptr, resourceName, ExecuteBackgroundProcessing,
                    CompleteBackgroundProcessing, workContext, &work);
            }
            if (status == napi_ok && work) {
                {
                    std::lock_guard<std::mutex> lock(task->statusMutex);
                    task->env = env;
                    task->work = work;
                }
                status = napi_queue_async_work(env, work);
            }
            if (status == napi_ok) {
                return;
            }
            if (work) {
                napi_delete_async_work(env, work);
            }
            {
                std::lock_guard<std::mutex> lock(task->statusMutex);
                task->work = nullptr;
            }
            FreePreparedWorkTask(workContext);
            MarkBackgroundTaskTerminal(task, "failed", geonest::GIS_ERR_NATIVE_NOT_READY,
                "Cannot queue native async work",
                BuildBackgroundFailureResult(task->taskId, geonest::GIS_ERR_NATIVE_NOT_READY,
                    "Cannot queue native async work"));
        }
        FreePreparedWorkTask(workContext);
        delete workContext;

        {
            std::lock_guard<std::mutex> lock(g_processingQueueMutex);
            if (g_activeProcessingTask.get() == task.get()) {
                g_activeProcessingTask.reset();
            }
        }
    }
}

static void CleanupBackgroundProcessing(napi_async_cleanup_hook_handle handle, void *data)
{
    napi_env cleanupEnv = static_cast<napi_env>(data);
    std::vector<std::shared_ptr<NativeProcessingTask>> queuedTasks;
    std::shared_ptr<NativeProcessingTask> activeTask;
    {
        std::lock_guard<std::mutex> lock(g_processingQueueMutex);
        if (!g_processingOwnerEnv || g_processingOwnerEnv != cleanupEnv) {
            napi_remove_async_cleanup_hook(handle);
            return;
        }
        g_processingQueueShuttingDown = true;
        g_pendingProcessingCleanup = handle;
        activeTask = g_activeProcessingTask;
        while (!g_processingQueue.empty()) {
            queuedTasks.push_back(g_processingQueue.front());
            g_processingQueue.pop_front();
        }
    }

    for (size_t i = 0; i < queuedTasks.size(); i++) {
        std::shared_ptr<NativeProcessingTask> task = queuedTasks[i];
        if (!task || task->done.load(std::memory_order_acquire)) {
            continue;
        }
        task->cancelRequested.store(true, std::memory_order_release);
        FreePreparedTask(task);
        MarkBackgroundTaskCanceled(task, "Task canceled because the native environment is closing");
    }
    if (activeTask) {
        napi_async_work workToCancel = nullptr;
        napi_env workEnv = nullptr;
        {
            std::lock_guard<std::mutex> lock(activeTask->statusMutex);
            if (!activeTask->done.load(std::memory_order_acquire)) {
                activeTask->cancelRequested.store(true, std::memory_order_release);
                activeTask->state = "cancelRequested";
                activeTask->stage = "cancelRequested";
                activeTask->message =
                    "Task cancellation requested because the native environment is closing";
                workToCancel = activeTask->work;
                workEnv = activeTask->env;
            }
        }
        if (workToCancel && workEnv) {
            napi_cancel_async_work(workEnv, workToCancel);
        }
    }

    bool finishCleanup = false;
    {
        std::lock_guard<std::mutex> lock(g_processingQueueMutex);
        if (!g_activeProcessingTask) {
            g_pendingProcessingCleanup = nullptr;
            g_processingQueue.clear();
            g_processingTasks.clear();
            g_processingOwnerEnv = nullptr;
            g_processingQueueShuttingDown = false;
            finishCleanup = true;
        }
    }
    if (finishCleanup) {
        napi_remove_async_cleanup_hook(handle);
    }
}

static napi_value NapiStartProcessingTask(napi_env env, napi_callback_info info)
{
    std::string taskId = CreateProcessingTaskId();
    std::shared_ptr<NativeProcessingTask> task;
    try {
        task = std::make_shared<NativeProcessingTask>();
    } catch (...) {
        return CreateProcessingTaskStatus(env, CreateTransientTaskStatus(taskId,
            geonest::GIS_ERR_NATIVE_NOT_READY, "Cannot allocate processing task", "failed"));
    }
    task->taskId = taskId;

    {
        std::lock_guard<std::mutex> lock(g_processingQueueMutex);
        if (!g_processingOwnerEnv && !g_processingQueueShuttingDown) {
            g_processingOwnerEnv = env;
        }
        if (g_processingOwnerEnv != env || g_processingQueueShuttingDown) {
            std::string message = "Background processing is owned by another native environment";
            MarkBackgroundTaskTerminal(task, "failed", geonest::GIS_ERR_NATIVE_NOT_READY, message,
                BuildBackgroundFailureResult(taskId, geonest::GIS_ERR_NATIVE_NOT_READY, message));
            return CreateProcessingTaskStatus(env, task);
        }
    }

    std::string requestJson;
    DynamicStringReadStatus readStatus = GetStringArgDynamic(env, info, requestJson);
    if (readStatus != DynamicStringReadStatus::Ok) {
        std::string message = DynamicStringReadError(readStatus);
        MarkBackgroundTaskTerminal(task, "failed", geonest::GIS_ERR_INVALID_PARAM, message,
            BuildBackgroundFailureResult(taskId, geonest::GIS_ERR_INVALID_PARAM, message));
    } else {
        char *prepareError = nullptr;
        int32_t prepareErrCode = geonest::GIS_OK;
        task->preparedTask = geonest::PrepareProcessingTask(requestJson.c_str(), &prepareError,
            &prepareErrCode);
        std::string prepareMessage = prepareError ? prepareError : "";
        geonest::FreeCString(prepareError);
        if (!task->preparedTask) {
            if (prepareMessage.empty()) {
                prepareMessage = "Processing task preparation failed";
            }
            if (prepareErrCode == geonest::GIS_OK) {
                prepareErrCode = geonest::GIS_ERR_NATIVE_NOT_READY;
            }
            MarkBackgroundTaskTerminal(task, "failed", prepareErrCode, prepareMessage,
                BuildBackgroundFailureResult(taskId, prepareErrCode, prepareMessage));
        }
    }

    bool queueTask = !task->done.load(std::memory_order_acquire);
    {
        std::lock_guard<std::mutex> lock(g_processingQueueMutex);
        g_processingTasks[taskId] = task;
        if (queueTask && !g_processingQueueShuttingDown) {
            g_processingQueue.push_back(task);
        } else if (queueTask) {
            queueTask = false;
        }
    }
    if (!queueTask && !task->done.load(std::memory_order_acquire)) {
        FreePreparedTask(task);
        task->cancelRequested.store(true, std::memory_order_release);
        MarkBackgroundTaskCanceled(task, "Processing queue is shutting down");
    } else if (queueTask) {
        ScheduleNextBackgroundTask(env);
    }
    return CreateProcessingTaskStatus(env, task);
}

static napi_value NapiGetProcessingTaskStatus(napi_env env, napi_callback_info info)
{
    std::string taskId;
    DynamicStringReadStatus readStatus = GetStringArgDynamic(env, info, taskId);
    if (readStatus != DynamicStringReadStatus::Ok || taskId.size() > 512) {
        std::string message = readStatus == DynamicStringReadStatus::Ok ?
            "Processing task id is too long" : DynamicStringReadError(readStatus);
        return CreateProcessingTaskStatus(env, CreateTransientTaskStatus(taskId,
            geonest::GIS_ERR_INVALID_PARAM, message, "notFound"));
    }
    std::shared_ptr<NativeProcessingTask> task = FindBackgroundTask(taskId);
    if (!task) {
        return CreateProcessingTaskStatus(env, CreateTransientTaskStatus(taskId,
            geonest::GIS_ERR_LAYER_NOT_FOUND, "Processing task was not found", "notFound"));
    }
    return CreateProcessingTaskStatus(env, task);
}

static napi_value NapiCancelProcessingTask(napi_env env, napi_callback_info info)
{
    std::string taskId;
    DynamicStringReadStatus readStatus = GetStringArgDynamic(env, info, taskId);
    if (readStatus != DynamicStringReadStatus::Ok || taskId.size() > 512) {
        std::string message = readStatus == DynamicStringReadStatus::Ok ?
            "Processing task id is too long" : DynamicStringReadError(readStatus);
        return CreateProcessingTaskStatus(env, CreateTransientTaskStatus(taskId,
            geonest::GIS_ERR_INVALID_PARAM, message, "notFound"));
    }
    std::shared_ptr<NativeProcessingTask> task = FindBackgroundTask(taskId);
    if (!task) {
        return CreateProcessingTaskStatus(env, CreateTransientTaskStatus(taskId,
            geonest::GIS_ERR_LAYER_NOT_FOUND, "Processing task was not found", "notFound"));
    }

    bool isActive = false;
    geonest::PreparedProcessingTask *queuedPreparedTask = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_processingQueueMutex);
        if (!task->done.load(std::memory_order_acquire)) {
            isActive = g_activeProcessingTask.get() == task.get();
            if (!isActive) {
                for (std::deque<std::shared_ptr<NativeProcessingTask>>::iterator iterator =
                    g_processingQueue.begin(); iterator != g_processingQueue.end();) {
                    if (iterator->get() == task.get()) {
                        iterator = g_processingQueue.erase(iterator);
                    } else {
                        ++iterator;
                    }
                }
                queuedPreparedTask = task->preparedTask;
                task->preparedTask = nullptr;
            }
        }
    }

    if (!isActive && queuedPreparedTask) {
        task->cancelRequested.store(true, std::memory_order_release);
        geonest::FreePreparedProcessingTask(queuedPreparedTask);
        MarkBackgroundTaskCanceled(task, "Task canceled before execution");
    } else if (isActive) {
        napi_async_work workToCancel = nullptr;
        napi_env workEnv = nullptr;
        {
            std::lock_guard<std::mutex> lock(task->statusMutex);
            if (!task->done.load(std::memory_order_acquire)) {
                task->cancelRequested.store(true, std::memory_order_release);
                task->state = "cancelRequested";
                task->stage = "cancelRequested";
                task->message = "Task cancellation requested";
                workToCancel = task->work;
                workEnv = task->env;
            }
        }
        if (workToCancel && workEnv) {
            napi_cancel_async_work(workEnv, workToCancel);
        }
    }
    return CreateProcessingTaskStatus(env, task);
}

static napi_value NapiReleaseProcessingTask(napi_env env, napi_callback_info info)
{
    std::string taskId;
    DynamicStringReadStatus readStatus = GetStringArgDynamic(env, info, taskId);
    bool released = false;
    if (readStatus == DynamicStringReadStatus::Ok && taskId.size() <= 512) {
        std::lock_guard<std::mutex> lock(g_processingQueueMutex);
        std::map<std::string, std::shared_ptr<NativeProcessingTask>>::iterator iterator =
            g_processingTasks.find(taskId);
        if (iterator != g_processingTasks.end() && iterator->second &&
            iterator->second->done.load(std::memory_order_acquire)) {
            for (std::deque<std::shared_ptr<NativeProcessingTask>>::iterator queueIterator =
                g_processingQueue.begin(); queueIterator != g_processingQueue.end();) {
                if (queueIterator->get() == iterator->second.get()) {
                    queueIterator = g_processingQueue.erase(queueIterator);
                } else {
                    ++queueIterator;
                }
            }
            g_processingTasks.erase(iterator);
            released = true;
        }
    }
    napi_value result = nullptr;
    napi_get_boolean(env, released, &result);
    return result;
}

// ---------------------------------------------------------------------------
// Basic functions
// ---------------------------------------------------------------------------
static napi_value GetNativeVersion(napi_env env, napi_callback_info info)
{
    napi_value result = nullptr;
    napi_create_string_utf8(env, geonest::GetNativeVersion(), NAPI_AUTO_LENGTH, &result);
    return result;
}

static napi_value GetCoreProfile(napi_env env, napi_callback_info info)
{
    napi_value result = nullptr;
    napi_create_string_utf8(env, geonest::GetCoreProfile(), NAPI_AUTO_LENGTH, &result);
    return result;
}

static napi_value NapiGetProcessingAlgorithms(napi_env env, napi_callback_info info)
{
    napi_value result = nullptr;
    const char *catalog = geonest::GetProcessingAlgorithms();
    napi_create_string_utf8(env, catalog ? catalog : "{\"backend\":\"none\",\"algorithms\":[]}",
        NAPI_AUTO_LENGTH, &result);
    geonest::FreeCString(const_cast<char *>(catalog));
    return result;
}

static napi_value NapiExecuteProcessingAlgorithm(napi_env env, napi_callback_info info)
{
    std::string requestJson;
    DynamicStringReadStatus readStatus = GetStringArgDynamic(env, info, requestJson);
    if (readStatus != DynamicStringReadStatus::Ok) {
        requestJson = "{\"validationError\":\"";
        requestJson += DynamicStringReadError(readStatus);
        requestJson += "\"}";
    }
    int32_t errCode = 0;
    const char *resultInfo = geonest::ExecuteProcessingAlgorithm(requestJson.c_str(), &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiReadQgisProject(napi_env env, napi_callback_info info)
{
    char pathBuf[4096] = {0};
    if (!GetStringArg(env, info, 1, pathBuf, sizeof(pathBuf))) {
        return CreateGeoProcessResult(env,
            "{\"ok\":false,\"code\":6,\"message\":\"Project path is empty\","
            "\"projectTitle\":\"\",\"projectCrs\":\"\",\"layerCount\":0,\"layers\":[]}",
            geonest::GIS_ERR_INVALID_PARAM);
    }
    int32_t errCode = 0;
    const char *resultInfo = geonest::ReadQgisProject(pathBuf, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiWriteQgisProject(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    char pathBuf[4096] = {0};
    char nameBuf[1024] = {0};
    char crsBuf[4096] = {0};
    char handlesBuf[8192] = {0};
    if (argc >= 1) GetStringValue(env, args[0], pathBuf, sizeof(pathBuf));
    if (argc >= 2) GetStringValue(env, args[1], nameBuf, sizeof(nameBuf));
    if (argc >= 3) GetStringValue(env, args[2], crsBuf, sizeof(crsBuf));
    if (argc >= 4) GetStringValue(env, args[3], handlesBuf, sizeof(handlesBuf));

    int32_t errCode = 0;
    const char *resultInfo = geonest::WriteQgisProject(pathBuf, nameBuf, crsBuf, handlesBuf, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiExtractZipArchive(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    char zipPath[4096] = {0};
    char outputDirectory[4096] = {0};
    if (argc >= 1) GetStringValue(env, args[0], zipPath, sizeof(zipPath));
    if (argc >= 2) GetStringValue(env, args[1], outputDirectory, sizeof(outputDirectory));

    int32_t errCode = 0;
    const char *resultInfo = geonest::ExtractZipArchive(zipPath, outputDirectory, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

// ---------------------------------------------------------------------------
// openVectorLayer(filePath: string): { handle: number, layerInfo: string, errCode: number }
// ---------------------------------------------------------------------------
static napi_value NapiOpenVectorLayer(napi_env env, napi_callback_info info)
{
    char pathBuf[2048] = {0};
    napi_value result = nullptr;
    napi_create_object(env, &result);

    if (!GetStringArg(env, info, 1, pathBuf, sizeof(pathBuf))) {
        napi_value v = nullptr;
        napi_create_int32(env, 0, &v);
        napi_set_named_property(env, result, "handle", v);
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &v);
        napi_set_named_property(env, result, "layerInfo", v);
        napi_create_int32(env, geonest::GIS_ERR_INVALID_PARAM, &v);
        napi_set_named_property(env, result, "errCode", v);
        return result;
    }

    char *layerInfo = nullptr;
    int32_t errCode = 0;
    geonest::LayerHandle handle = geonest::OpenVectorLayer(pathBuf, &layerInfo, &errCode);

    napi_value v = nullptr;
    napi_create_int32(env, handle, &v);
    napi_set_named_property(env, result, "handle", v);
    napi_create_string_utf8(env, layerInfo ? layerInfo : "", NAPI_AUTO_LENGTH, &v);
    napi_set_named_property(env, result, "layerInfo", v);
    napi_create_int32(env, errCode, &v);
    napi_set_named_property(env, result, "errCode", v);

    geonest::FreeCString(layerInfo);
    return result;
}

// ---------------------------------------------------------------------------
// openRasterLayer(filePath: string): { handle: number, layerInfo: string, errCode: number }
// ---------------------------------------------------------------------------
static napi_value NapiOpenRasterLayer(napi_env env, napi_callback_info info)
{
    char pathBuf[2048] = {0};
    napi_value result = nullptr;
    napi_create_object(env, &result);

    if (!GetStringArg(env, info, 1, pathBuf, sizeof(pathBuf))) {
        napi_value v = nullptr;
        napi_create_int32(env, 0, &v);
        napi_set_named_property(env, result, "handle", v);
        napi_create_string_utf8(env, "", NAPI_AUTO_LENGTH, &v);
        napi_set_named_property(env, result, "layerInfo", v);
        napi_create_int32(env, geonest::GIS_ERR_INVALID_PARAM, &v);
        napi_set_named_property(env, result, "errCode", v);
        return result;
    }

    char *layerInfo = nullptr;
    int32_t errCode = 0;
    geonest::LayerHandle handle = geonest::OpenRasterLayer(pathBuf, &layerInfo, &errCode);

    napi_value v = nullptr;
    napi_create_int32(env, handle, &v);
    napi_set_named_property(env, result, "handle", v);
    napi_create_string_utf8(env, layerInfo ? layerInfo : "", NAPI_AUTO_LENGTH, &v);
    napi_set_named_property(env, result, "layerInfo", v);
    napi_create_int32(env, errCode, &v);
    napi_set_named_property(env, result, "errCode", v);

    geonest::FreeCString(layerInfo);
    return result;
}

// ---------------------------------------------------------------------------
// closeLayer(handle: number): number (error code)
// ---------------------------------------------------------------------------
static napi_value NapiCloseLayer(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t handle = 0;
    napi_get_value_int32(env, args[0], &handle);

    int32_t result = geonest::CloseLayer(handle);

    napi_value retVal = nullptr;
    napi_create_int32(env, result, &retVal);
    return retVal;
}

// ---------------------------------------------------------------------------
// getLayerInfo(handle: number): { layerInfo: string, errCode: number }
// ---------------------------------------------------------------------------
static napi_value NapiGetLayerInfo(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t handle = 0;
    napi_get_value_int32(env, args[0], &handle);

    int32_t errCode = 0;
    const char *layerInfo = geonest::GetLayerInfo(handle, &errCode);

    napi_value result = nullptr;
    napi_create_object(env, &result);

    napi_value infoVal = nullptr;
    napi_create_string_utf8(env, layerInfo ? layerInfo : "", NAPI_AUTO_LENGTH, &infoVal);
    napi_set_named_property(env, result, "layerInfo", infoVal);

    napi_value errVal = nullptr;
    napi_create_int32(env, errCode, &errVal);
    napi_set_named_property(env, result, "errCode", errVal);

    geonest::FreeCString(const_cast<char *>(layerInfo));
    return result;
}

// ---------------------------------------------------------------------------
// listVectorSublayers(filePath): { resultInfo: string, errCode: number }
// ---------------------------------------------------------------------------
static napi_value NapiListVectorSublayers(napi_env env, napi_callback_info info)
{
    char pathBuf[4096] = {0};
    if (!GetStringArg(env, info, 1, pathBuf, sizeof(pathBuf))) {
        return CreateGeoProcessResult(env, "{\"ok\":false,\"layers\":[]}",
            geonest::GIS_ERR_INVALID_PARAM);
    }
    int32_t errCode = 0;
    const char *resultInfo = geonest::ListVectorSublayers(pathBuf, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

// ---------------------------------------------------------------------------
// queryFeatures(handle, minX, minY, maxX, maxY, limit, offset): { featurePage: string, errCode: number }
// ---------------------------------------------------------------------------
static napi_value NapiQueryFeatures(napi_env env, napi_callback_info info)
{
    size_t argc = 7;
    napi_value args[7];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t handle = 0;
    double minX = 0, minY = 0, maxX = 1, maxY = 1;
    int32_t limit = 0;
    int32_t offset = 0;

    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_double(env, args[1], &minX);
    if (argc >= 3) napi_get_value_double(env, args[2], &minY);
    if (argc >= 4) napi_get_value_double(env, args[3], &maxX);
    if (argc >= 5) napi_get_value_double(env, args[4], &maxY);
    if (argc >= 6) napi_get_value_int32(env, args[5], &limit);
    if (argc >= 7) napi_get_value_int32(env, args[6], &offset);
    if (offset < 0) offset = 0;

    int32_t errCode = 0;
    const char *pageJson = geonest::QueryFeatures(handle, minX, minY, maxX, maxY, limit, offset, &errCode);

    napi_value result = nullptr;
    napi_create_object(env, &result);

    napi_value pageVal = nullptr;
    napi_create_string_utf8(env, pageJson ? pageJson : "", NAPI_AUTO_LENGTH, &pageVal);
    napi_set_named_property(env, result, "featurePage", pageVal);

    napi_value errVal = nullptr;
    napi_create_int32(env, errCode, &errVal);
    napi_set_named_property(env, result, "errCode", errVal);

    geonest::FreeCString(const_cast<char *>(pageJson));
    return result;
}

// selectFeaturesByGeometry(handle, wkt, predicateMode, limit)
static napi_value NapiSelectFeaturesByGeometry(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    int32_t predicateMode = 0;
    int32_t limit = 0;
    char wkt[65536] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], wkt, sizeof(wkt));
    if (argc >= 3) napi_get_value_int32(env, args[2], &predicateMode);
    if (argc >= 4) napi_get_value_int32(env, args[3], &limit);
    int32_t errCode = 0;
    const char *selectionJson = geonest::SelectFeaturesByGeometry(handle, wkt, predicateMode, limit, &errCode);
    napi_value result = nullptr;
    napi_create_object(env, &result);
    napi_value jsonValue = nullptr;
    napi_create_string_utf8(env, selectionJson ? selectionJson : "", NAPI_AUTO_LENGTH, &jsonValue);
    napi_set_named_property(env, result, "selectionJson", jsonValue);
    napi_value errorValue = nullptr;
    napi_create_int32(env, errCode, &errorValue);
    napi_set_named_property(env, result, "errCode", errorValue);
    geonest::FreeCString(const_cast<char *>(selectionJson));
    return result;
}

// ---------------------------------------------------------------------------
// getFeature(handle: number, fid: number): { feature: string, errCode: number }
// ---------------------------------------------------------------------------
static napi_value NapiGetFeature(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t handle = 0;
    int64_t fid = 0;

    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) {
        double fidDouble = 0;
        napi_get_value_double(env, args[1], &fidDouble);
        fid = static_cast<int64_t>(fidDouble);
    }

    int32_t errCode = 0;
    const char *featJson = geonest::GetFeature(handle, fid, &errCode);

    napi_value result = nullptr;
    napi_create_object(env, &result);

    napi_value featVal = nullptr;
    napi_create_string_utf8(env, featJson ? featJson : "", NAPI_AUTO_LENGTH, &featVal);
    napi_set_named_property(env, result, "feature", featVal);

    napi_value errVal = nullptr;
    napi_create_int32(env, errCode, &errVal);
    napi_set_named_property(env, result, "errCode", errVal);

    geonest::FreeCString(const_cast<char *>(featJson));
    return result;
}

// ---------------------------------------------------------------------------
// bufferLayer(handle, distance, outputPath, outputLayerName)
// ---------------------------------------------------------------------------
static napi_value NapiBufferLayer(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t handle = 0;
    double distance = 0.0;
    char outputPath[2048] = {0};
    char outputLayerName[512] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_double(env, args[1], &distance);
    if (argc >= 3) GetStringValue(env, args[2], outputPath, sizeof(outputPath));
    if (argc >= 4) GetStringValue(env, args[3], outputLayerName, sizeof(outputLayerName));

    int32_t errCode = 0;
    const char *resultInfo = geonest::BufferLayer(handle, distance, outputPath, outputLayerName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiSimplifyLayer(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    double tolerance = 0.0;
    char outputPath[2048] = {0};
    char outputLayerName[512] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_double(env, args[1], &tolerance);
    if (argc >= 3) GetStringValue(env, args[2], outputPath, sizeof(outputPath));
    if (argc >= 4) GetStringValue(env, args[3], outputLayerName, sizeof(outputLayerName));
    int32_t errCode = 0;
    const char *resultInfo = geonest::SimplifyLayer(handle, tolerance, outputPath, outputLayerName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiDissolveLayer(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    char outputPath[2048] = {0};
    char outputLayerName[512] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], outputPath, sizeof(outputPath));
    if (argc >= 3) GetStringValue(env, args[2], outputLayerName, sizeof(outputLayerName));
    int32_t errCode = 0;
    const char *resultInfo = geonest::DissolveLayer(handle, outputPath, outputLayerName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiCentroidLayer(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    char outputPath[2048] = {0};
    char outputLayerName[512] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], outputPath, sizeof(outputPath));
    if (argc >= 3) GetStringValue(env, args[2], outputLayerName, sizeof(outputLayerName));
    int32_t errCode = 0;
    const char *resultInfo = geonest::CentroidLayer(handle, outputPath, outputLayerName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

// ---------------------------------------------------------------------------
// repairLayer(handle, outputPath, outputLayerName)
// ---------------------------------------------------------------------------
static napi_value NapiRepairLayer(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t handle = 0;
    char outputPath[2048] = {0};
    char outputLayerName[512] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], outputPath, sizeof(outputPath));
    if (argc >= 3) GetStringValue(env, args[2], outputLayerName, sizeof(outputLayerName));

    int32_t errCode = 0;
    const char *resultInfo = geonest::RepairLayer(handle, outputPath, outputLayerName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiValidateTopologyRules(napi_env env, napi_callback_info info)
{
    size_t argc = 8;
    napi_value args[8];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t sourceHandle = 0, targetHandle = 0;
    double tolerance = 0.0;
    char rules[8192] = {0}, dirtyExtent[512] = {0}, outputPath[2048] = {0}, outputName[512] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &sourceHandle);
    if (argc >= 2) napi_get_value_int32(env, args[1], &targetHandle);
    if (argc >= 3) GetStringValue(env, args[2], rules, sizeof(rules));
    if (argc >= 4) GetStringValue(env, args[3], dirtyExtent, sizeof(dirtyExtent));
    if (argc >= 5) napi_get_value_double(env, args[4], &tolerance);
    if (argc >= 6) GetStringValue(env, args[5], outputPath, sizeof(outputPath));
    if (argc >= 7) GetStringValue(env, args[6], outputName, sizeof(outputName));
    int32_t errCode = 0;
    const char *resultInfo = geonest::ValidateTopologyRules(sourceHandle, targetHandle, rules, dirtyExtent,
        tolerance, outputPath, outputName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiRepairTopologyIssues(napi_env env, napi_callback_info info)
{
    size_t argc = 9;
    napi_value args[9];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t sourceHandle = 0, targetHandle = 0;
    double tolerance = 0.0;
    bool previewOnly = true;
    char featureIds[8192] = {0}, strategy[128] = {0}, outputPath[2048] = {0}, outputName[512] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &sourceHandle);
    if (argc >= 2) napi_get_value_int32(env, args[1], &targetHandle);
    if (argc >= 3) GetStringValue(env, args[2], featureIds, sizeof(featureIds));
    if (argc >= 4) GetStringValue(env, args[3], strategy, sizeof(strategy));
    if (argc >= 5) napi_get_value_double(env, args[4], &tolerance);
    if (argc >= 6) napi_get_value_bool(env, args[5], &previewOnly);
    if (argc >= 7) GetStringValue(env, args[6], outputPath, sizeof(outputPath));
    if (argc >= 8) GetStringValue(env, args[7], outputName, sizeof(outputName));
    int32_t errCode = 0;
    const char *resultInfo = geonest::RepairTopologyIssues(sourceHandle, targetHandle, featureIds, strategy,
        tolerance, previewOnly, outputPath, outputName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

// ---------------------------------------------------------------------------
// clipLayer(inputHandle, clipHandle, outputPath, outputLayerName)
// ---------------------------------------------------------------------------
static napi_value NapiClipLayer(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t inputHandle = 0;
    int32_t clipHandle = 0;
    char outputPath[2048] = {0};
    char outputLayerName[512] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &inputHandle);
    if (argc >= 2) napi_get_value_int32(env, args[1], &clipHandle);
    if (argc >= 3) GetStringValue(env, args[2], outputPath, sizeof(outputPath));
    if (argc >= 4) GetStringValue(env, args[3], outputLayerName, sizeof(outputLayerName));

    int32_t errCode = 0;
    const char *resultInfo = geonest::ClipLayer(inputHandle, clipHandle, outputPath, outputLayerName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

// ---------------------------------------------------------------------------
// exportLayer(handle, outputPath, outputLayerName)
// ---------------------------------------------------------------------------
static napi_value NapiExportLayer(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t handle = 0;
    char outputPath[2048] = {0};
    char outputLayerName[512] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], outputPath, sizeof(outputPath));
    if (argc >= 3) GetStringValue(env, args[2], outputLayerName, sizeof(outputLayerName));

    int32_t errCode = 0;
    const char *resultInfo = geonest::ExportLayer(handle, outputPath, outputLayerName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

// ---------------------------------------------------------------------------
// exportLayerToFormat(handle, outputPath, outputLayerName, driverName)
// ---------------------------------------------------------------------------
static napi_value NapiExportLayerToFormat(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t handle = 0;
    char outputPath[2048] = {0};
    char outputLayerName[512] = {0};
    char driverName[256] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], outputPath, sizeof(outputPath));
    if (argc >= 3) GetStringValue(env, args[2], outputLayerName, sizeof(outputLayerName));
    if (argc >= 4) GetStringValue(env, args[3], driverName, sizeof(driverName));

    int32_t errCode = 0;
    const char *resultInfo = geonest::ExportLayerToFormat(handle, outputPath, outputLayerName,
        driverName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

// ---------------------------------------------------------------------------
// defineLayerProjection(handle, targetDefinition, outputPath, outputLayerName)
// ---------------------------------------------------------------------------
static napi_value NapiDefineLayerProjection(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t handle = 0;
    char targetDefinition[4096] = {0};
    char outputPath[2048] = {0};
    char outputLayerName[512] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], targetDefinition, sizeof(targetDefinition));
    if (argc >= 3) GetStringValue(env, args[2], outputPath, sizeof(outputPath));
    if (argc >= 4) GetStringValue(env, args[3], outputLayerName, sizeof(outputLayerName));

    int32_t errCode = 0;
    const char *resultInfo = geonest::DefineLayerProjection(handle, targetDefinition, outputPath,
        outputLayerName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

// ---------------------------------------------------------------------------
// projectLayer(handle, targetDefinition, outputPath, outputLayerName)
// ---------------------------------------------------------------------------
static napi_value NapiProjectLayer(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t handle = 0;
    char targetDefinition[4096] = {0};
    char outputPath[2048] = {0};
    char outputLayerName[512] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], targetDefinition, sizeof(targetDefinition));
    if (argc >= 3) GetStringValue(env, args[2], outputPath, sizeof(outputPath));
    if (argc >= 4) GetStringValue(env, args[3], outputLayerName, sizeof(outputLayerName));

    int32_t errCode = 0;
    const char *resultInfo = geonest::ProjectLayer(handle, targetDefinition, outputPath,
        outputLayerName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiApplyVectorStyle(napi_env env, napi_callback_info info)
{
    size_t argc = 14;
    napi_value args[14];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    int32_t rendererMode = 0;
    char rendererField[512] = {0};
    int32_t colorRamp = 0;
    int32_t linePattern = 0;
    int32_t fillPattern = 0;
    char pointColor[64] = {0};
    char lineColor[64] = {0};
    char fillColor[64] = {0};
    char strokeColor[64] = {0};
    double lineWidth = 1.0;
    double pointRadius = 6.0;
    double opacity = 1.0;
    char symbolName[256] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_int32(env, args[1], &rendererMode);
    if (argc >= 3) GetStringValue(env, args[2], rendererField, sizeof(rendererField));
    if (argc >= 4) napi_get_value_int32(env, args[3], &colorRamp);
    if (argc >= 5) napi_get_value_int32(env, args[4], &linePattern);
    if (argc >= 6) napi_get_value_int32(env, args[5], &fillPattern);
    if (argc >= 7) GetStringValue(env, args[6], pointColor, sizeof(pointColor));
    if (argc >= 8) GetStringValue(env, args[7], lineColor, sizeof(lineColor));
    if (argc >= 9) GetStringValue(env, args[8], fillColor, sizeof(fillColor));
    if (argc >= 10) GetStringValue(env, args[9], strokeColor, sizeof(strokeColor));
    if (argc >= 11) napi_get_value_double(env, args[10], &lineWidth);
    if (argc >= 12) napi_get_value_double(env, args[11], &pointRadius);
    if (argc >= 13) napi_get_value_double(env, args[12], &opacity);
    if (argc >= 14) GetStringValue(env, args[13], symbolName, sizeof(symbolName));
    int32_t errCode = 0;
    const char *resultInfo = geonest::ApplyVectorStyle(handle, rendererMode, rendererField, colorRamp,
        linePattern, fillPattern, pointColor, lineColor, fillColor, strokeColor, lineWidth, pointRadius,
        opacity, symbolName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiImportQmlStyle(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    char qmlPath[4096] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], qmlPath, sizeof(qmlPath));
    int32_t errCode = 0;
    const char *resultInfo = geonest::ImportQmlStyle(handle, qmlPath, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiExportQmlStyle(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    char qmlPath[4096] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], qmlPath, sizeof(qmlPath));
    int32_t errCode = 0;
    const char *resultInfo = geonest::ExportQmlStyle(handle, qmlPath, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiApplyVectorLabeling(napi_env env, napi_callback_info info)
{
    size_t argc = 9;
    napi_value args[9];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    bool enabled = false;
    char labelField[512] = {0};
    double labelSize = 12.0;
    char labelColor[64] = {0};
    bool halo = true;
    bool avoidance = true;
    double minScale = 0.0;
    double maxScale = 0.0;
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_bool(env, args[1], &enabled);
    if (argc >= 3) GetStringValue(env, args[2], labelField, sizeof(labelField));
    if (argc >= 4) napi_get_value_double(env, args[3], &labelSize);
    if (argc >= 5) GetStringValue(env, args[4], labelColor, sizeof(labelColor));
    if (argc >= 6) napi_get_value_bool(env, args[5], &halo);
    if (argc >= 7) napi_get_value_bool(env, args[6], &avoidance);
    if (argc >= 8) napi_get_value_double(env, args[7], &minScale);
    if (argc >= 9) napi_get_value_double(env, args[8], &maxScale);
    int32_t errCode = 0;
    const char *resultInfo = geonest::ApplyVectorLabeling(handle, enabled, labelField, labelSize, labelColor,
        halo, avoidance, minScale, maxScale, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiConfigureRasterDisplay(napi_env env, napi_callback_info info)
{
    size_t argc = 8;
    napi_value args[8];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    int32_t bandMode = 0;
    int32_t stretchMode = 0;
    int32_t colorRamp = 0;
    double opacity = 1.0;
    char noData[128] = {0};
    char transparentColor[64] = {0};
    bool hillshade = false;
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_int32(env, args[1], &bandMode);
    if (argc >= 3) napi_get_value_int32(env, args[2], &stretchMode);
    if (argc >= 4) napi_get_value_int32(env, args[3], &colorRamp);
    if (argc >= 5) napi_get_value_double(env, args[4], &opacity);
    if (argc >= 6) GetStringValue(env, args[5], noData, sizeof(noData));
    if (argc >= 7) GetStringValue(env, args[6], transparentColor, sizeof(transparentColor));
    if (argc >= 8) napi_get_value_bool(env, args[7], &hillshade);
    int32_t errCode = 0;
    const char *resultInfo = geonest::ConfigureRasterDisplay(handle, bandMode, stretchMode, colorRamp, opacity,
        noData, transparentColor, hillshade, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiRenderMapView(napi_env env, napi_callback_info info)
{
    size_t argc = 9;
    napi_value args[9];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    char outputPath[2048] = {0};
    char visibleLayerHandles[4096] = {0};
    char destinationCrs[512] = {0};
    double minX = 0.0;
    double minY = 0.0;
    double maxX = 0.0;
    double maxY = 0.0;
    int32_t width = 800;
    int32_t height = 600;
    if (argc >= 1) GetStringValue(env, args[0], outputPath, sizeof(outputPath));
    if (argc >= 2) napi_get_value_double(env, args[1], &minX);
    if (argc >= 3) napi_get_value_double(env, args[2], &minY);
    if (argc >= 4) napi_get_value_double(env, args[3], &maxX);
    if (argc >= 5) napi_get_value_double(env, args[4], &maxY);
    if (argc >= 6) napi_get_value_int32(env, args[5], &width);
    if (argc >= 7) napi_get_value_int32(env, args[6], &height);
    if (argc >= 8) GetStringValue(env, args[7], visibleLayerHandles, sizeof(visibleLayerHandles));
    if (argc >= 9) GetStringValue(env, args[8], destinationCrs, sizeof(destinationCrs));

    int32_t errCode = 0;
    const char *resultInfo = geonest::RenderMapView(outputPath, minX, minY, maxX, maxY, width, height,
        visibleLayerHandles, destinationCrs, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiExportMapLayout(napi_env env, napi_callback_info info)
{
    size_t argc = 16;
    napi_value args[16];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    char title[512] = {0};
    char outputPath[2048] = {0};
    char format[32] = {0};
    char legendTitle[512] = {0};
    char scaleText[512] = {0};
    char footerText[512] = {0};
    char basemapLabel[512] = {0};
    char basemapImagePath[2048] = {0};
    char visibleLayerHandles[4096] = {0};
    bool showLegend = true;
    bool showScaleBar = true;
    bool showNorthArrow = true;
    bool showGrid = true;
    int32_t width = 1600;
    int32_t height = 1100;
    int32_t basemapMode = 0;
    if (argc >= 1) GetStringValue(env, args[0], title, sizeof(title));
    if (argc >= 2) GetStringValue(env, args[1], outputPath, sizeof(outputPath));
    if (argc >= 3) GetStringValue(env, args[2], format, sizeof(format));
    if (argc >= 4) napi_get_value_bool(env, args[3], &showLegend);
    if (argc >= 5) napi_get_value_bool(env, args[4], &showScaleBar);
    if (argc >= 6) napi_get_value_bool(env, args[5], &showNorthArrow);
    if (argc >= 7) napi_get_value_bool(env, args[6], &showGrid);
    if (argc >= 8) napi_get_value_int32(env, args[7], &width);
    if (argc >= 9) napi_get_value_int32(env, args[8], &height);
    if (argc >= 10) GetStringValue(env, args[9], legendTitle, sizeof(legendTitle));
    if (argc >= 11) GetStringValue(env, args[10], scaleText, sizeof(scaleText));
    if (argc >= 12) GetStringValue(env, args[11], footerText, sizeof(footerText));
    if (argc >= 13) napi_get_value_int32(env, args[12], &basemapMode);
    if (argc >= 14) GetStringValue(env, args[13], basemapLabel, sizeof(basemapLabel));
    if (argc >= 16) {
        GetStringValue(env, args[14], basemapImagePath, sizeof(basemapImagePath));
        GetStringValue(env, args[15], visibleLayerHandles, sizeof(visibleLayerHandles));
    } else if (argc >= 15) {
        GetStringValue(env, args[14], visibleLayerHandles, sizeof(visibleLayerHandles));
    }
    int32_t errCode = 0;
    const char *resultInfo = geonest::ExportMapLayout(title, outputPath, format, showLegend, showScaleBar,
        showNorthArrow, showGrid, width, height, legendTitle, scaleText, footerText, basemapMode, basemapLabel,
        basemapImagePath, visibleLayerHandles, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiDescribeCoordinateReferenceSystem(napi_env env, napi_callback_info info)
{
    char definition[8192] = {0};
    napi_value result = nullptr;
    napi_create_object(env, &result);

    if (!GetStringArg(env, info, 1, definition, sizeof(definition))) {
        napi_value infoVal = nullptr;
        napi_create_string_utf8(env,
            "{\"ok\":false,\"code\":6,\"message\":\"CRS definition is empty\",\"input\":\"\","
            "\"isValid\":false,\"authId\":\"\",\"description\":\"\",\"friendlyName\":\"\","
            "\"projectionAcronym\":\"\",\"ellipsoidAcronym\":\"\",\"geographicCrsAuthId\":\"\","
            "\"celestialBodyName\":\"\",\"isGeographic\":false,\"hasAxisInverted\":false,"
            "\"srsId\":0,\"postgisSrid\":0,\"mapUnitCode\":0,\"unitName\":\"unknown\","
            "\"unitType\":0,\"bounds\":{\"minX\":0,\"minY\":0,\"maxX\":0,\"maxY\":0},"
            "\"proj\":\"\",\"wkt\":\"\"}",
            NAPI_AUTO_LENGTH, &infoVal);
        napi_set_named_property(env, result, "resultInfo", infoVal);

        napi_value errVal = nullptr;
        napi_create_int32(env, geonest::GIS_ERR_INVALID_PARAM, &errVal);
        napi_set_named_property(env, result, "errCode", errVal);
        return result;
    }

    int32_t errCode = 0;
    const char *resultInfo = geonest::DescribeCoordinateReferenceSystem(definition, &errCode);
    result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiTransformCoordinate(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    char sourceDefinition[8192] = {0};
    char targetDefinition[8192] = {0};
    double x = 0.0;
    double y = 0.0;
    if (argc >= 1) GetStringValue(env, args[0], sourceDefinition, sizeof(sourceDefinition));
    if (argc >= 2) GetStringValue(env, args[1], targetDefinition, sizeof(targetDefinition));
    if (argc >= 3) napi_get_value_double(env, args[2], &x);
    if (argc >= 4) napi_get_value_double(env, args[3], &y);

    int32_t errCode = 0;
    const char *resultInfo = geonest::TransformCoordinate(sourceDefinition, targetDefinition, x, y, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiTransformEnvelope(napi_env env, napi_callback_info info)
{
    size_t argc = 6;
    napi_value args[6];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    char sourceDefinition[8192] = {0};
    char targetDefinition[8192] = {0};
    double minX = 0.0;
    double minY = 0.0;
    double maxX = 0.0;
    double maxY = 0.0;
    if (argc >= 1) GetStringValue(env, args[0], sourceDefinition, sizeof(sourceDefinition));
    if (argc >= 2) GetStringValue(env, args[1], targetDefinition, sizeof(targetDefinition));
    if (argc >= 3) napi_get_value_double(env, args[2], &minX);
    if (argc >= 4) napi_get_value_double(env, args[3], &minY);
    if (argc >= 5) napi_get_value_double(env, args[4], &maxX);
    if (argc >= 6) napi_get_value_double(env, args[5], &maxY);

    int32_t errCode = 0;
    const char *resultInfo = geonest::TransformEnvelope(sourceDefinition, targetDefinition, minX, minY, maxX, maxY,
        &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

using EditSessionFunction = const char *(*)(geonest::LayerHandle, int32_t *);

static napi_value CallEditSessionFunction(napi_env env, napi_callback_info info, EditSessionFunction function)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    if (argc >= 1) {
        napi_get_value_int32(env, args[0], &handle);
    }
    int32_t errCode = 0;
    const char *resultInfo = function(handle, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiBeginEditSession(napi_env env, napi_callback_info info)
{
    return CallEditSessionFunction(env, info, geonest::BeginEditSession);
}

static napi_value NapiCommitEditSession(napi_env env, napi_callback_info info)
{
    return CallEditSessionFunction(env, info, geonest::CommitEditSession);
}

static napi_value NapiRollbackEditSession(napi_env env, napi_callback_info info)
{
    return CallEditSessionFunction(env, info, geonest::RollbackEditSession);
}

static napi_value NapiUndoEdit(napi_env env, napi_callback_info info)
{
    return CallEditSessionFunction(env, info, geonest::UndoEdit);
}

static napi_value NapiRedoEdit(napi_env env, napi_callback_info info)
{
    return CallEditSessionFunction(env, info, geonest::RedoEdit);
}

using EditStateFunction = bool (*)(geonest::LayerHandle);

static napi_value CallEditStateFunction(napi_env env, napi_callback_info info, EditStateFunction function)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    if (argc >= 1) {
        napi_get_value_int32(env, args[0], &handle);
    }
    napi_value result = nullptr;
    napi_get_boolean(env, function(handle), &result);
    return result;
}

static napi_value NapiIsEditing(napi_env env, napi_callback_info info)
{
    return CallEditStateFunction(env, info, geonest::IsEditing);
}

static napi_value NapiHasPendingEdits(napi_env env, napi_callback_info info)
{
    return CallEditStateFunction(env, info, geonest::HasPendingEdits);
}

static napi_value NapiCanUndo(napi_env env, napi_callback_info info)
{
    return CallEditStateFunction(env, info, geonest::CanUndo);
}

static napi_value NapiCanRedo(napi_env env, napi_callback_info info)
{
    return CallEditStateFunction(env, info, geonest::CanRedo);
}

static napi_value NapiAddFeature(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    int32_t geometryType = 0;
    char coordsText[8192] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_int32(env, args[1], &geometryType);
    if (argc >= 3) GetStringValue(env, args[2], coordsText, sizeof(coordsText));
    int32_t errCode = 0;
    const char *resultInfo = geonest::AddFeature(handle, geometryType, coordsText, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiDeleteFeature(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    int64_t fid = 0;
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) {
        double fidDouble = 0.0;
        napi_get_value_double(env, args[1], &fidDouble);
        fid = static_cast<int64_t>(fidDouble);
    }
    int32_t errCode = 0;
    const char *resultInfo = geonest::DeleteFeature(handle, fid, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiInspectPointCloud(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    char filePath[4096] = {0};
    if (argc >= 1) GetStringValue(env, args[0], filePath, sizeof(filePath));
    int32_t errCode = 0;
    const char *resultInfo = geonest::InspectPointCloud(filePath, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiProcessPointCloud(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    char inputPath[4096] = {0};
    char operation[64] = {0};
    char optionsText[4096] = {0};
    char outputPath[4096] = {0};
    if (argc >= 1) GetStringValue(env, args[0], inputPath, sizeof(inputPath));
    if (argc >= 2) GetStringValue(env, args[1], operation, sizeof(operation));
    if (argc >= 3) GetStringValue(env, args[2], optionsText, sizeof(optionsText));
    if (argc >= 4) GetStringValue(env, args[3], outputPath, sizeof(outputPath));
    int32_t errCode = 0;
    const char *resultInfo = geonest::ProcessPointCloud(inputPath, operation, optionsText, outputPath, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiMoveFeatureNode(napi_env env, napi_callback_info info)
{
    size_t argc = 6;
    napi_value args[6];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    double fidDouble = 0.0;
    int32_t partIndex = 0;
    int32_t pointIndex = 0;
    double x = 0.0;
    double y = 0.0;
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_double(env, args[1], &fidDouble);
    if (argc >= 3) napi_get_value_int32(env, args[2], &partIndex);
    if (argc >= 4) napi_get_value_int32(env, args[3], &pointIndex);
    if (argc >= 5) napi_get_value_double(env, args[4], &x);
    if (argc >= 6) napi_get_value_double(env, args[5], &y);
    int32_t errCode = 0;
    const char *resultInfo = geonest::MoveFeatureNode(handle, static_cast<int64_t>(fidDouble), partIndex, pointIndex,
        x, y, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiDeleteFeatureNode(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    double fidDouble = 0.0;
    int32_t partIndex = 0;
    int32_t pointIndex = 0;
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_double(env, args[1], &fidDouble);
    if (argc >= 3) napi_get_value_int32(env, args[2], &partIndex);
    if (argc >= 4) napi_get_value_int32(env, args[3], &pointIndex);
    int32_t errCode = 0;
    const char *resultInfo = geonest::DeleteFeatureNode(handle, static_cast<int64_t>(fidDouble), partIndex,
        pointIndex, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiCopyFeature(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    double fidDouble = 0.0;
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_double(env, args[1], &fidDouble);
    int32_t errCode = 0;
    const char *resultInfo = geonest::CopyFeature(handle, static_cast<int64_t>(fidDouble), &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiSplitFeature(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    double fidDouble = 0.0;
    char coordsText[8192] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_double(env, args[1], &fidDouble);
    if (argc >= 3) GetStringValue(env, args[2], coordsText, sizeof(coordsText));
    int32_t errCode = 0;
    const char *resultInfo = geonest::SplitFeature(handle, static_cast<int64_t>(fidDouble), coordsText, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiMergeFeatures(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    char fidListText[2048] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], fidListText, sizeof(fidListText));
    int32_t errCode = 0;
    const char *resultInfo = geonest::MergeFeatures(handle, fidListText, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiSnapLayer(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    int32_t targetHandle = 0;
    double tolerance = 0.0;
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_int32(env, args[1], &targetHandle);
    if (argc >= 3) napi_get_value_double(env, args[2], &tolerance);
    int32_t errCode = 0;
    const char *resultInfo = geonest::SnapLayer(handle, targetHandle, tolerance, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiUpdateFeatureAttribute(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    double fidDouble = 0.0;
    char fieldName[512] = {0};
    char value[2048] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_double(env, args[1], &fidDouble);
    if (argc >= 3) GetStringValue(env, args[2], fieldName, sizeof(fieldName));
    if (argc >= 4) GetStringValue(env, args[3], value, sizeof(value));
    int32_t errCode = 0;
    const char *resultInfo = geonest::UpdateFeatureAttribute(handle, static_cast<int64_t>(fidDouble), fieldName,
        value, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiBatchAssignAttribute(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    char fieldName[512] = {0};
    char filterText[2048] = {0};
    char value[2048] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], fieldName, sizeof(fieldName));
    if (argc >= 3) GetStringValue(env, args[2], filterText, sizeof(filterText));
    if (argc >= 4) GetStringValue(env, args[3], value, sizeof(value));
    int32_t errCode = 0;
    const char *resultInfo = geonest::BatchAssignAttribute(handle, fieldName, filterText, value, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiAddLayerField(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    char fieldName[512] = {0};
    char typeName[128] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], fieldName, sizeof(fieldName));
    if (argc >= 3) GetStringValue(env, args[2], typeName, sizeof(typeName));
    int32_t errCode = 0;
    const char *resultInfo = geonest::AddLayerField(handle, fieldName, typeName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiDeleteLayerField(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    char fieldName[512] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], fieldName, sizeof(fieldName));
    int32_t errCode = 0;
    const char *resultInfo = geonest::DeleteLayerField(handle, fieldName, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

static napi_value NapiCalculateField(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t handle = 0;
    char fieldName[512] = {0};
    int32_t calculatorMode = 0;
    char value[2048] = {0};
    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) GetStringValue(env, args[1], fieldName, sizeof(fieldName));
    if (argc >= 3) napi_get_value_int32(env, args[2], &calculatorMode);
    if (argc >= 4) GetStringValue(env, args[3], value, sizeof(value));
    int32_t errCode = 0;
    const char *resultInfo = geonest::CalculateField(handle, fieldName, calculatorMode, value, &errCode);
    napi_value result = CreateGeoProcessResult(env, resultInfo, errCode);
    geonest::FreeCString(const_cast<char *>(resultInfo));
    return result;
}

// ---------------------------------------------------------------------------
// Module registration
// ---------------------------------------------------------------------------
EXTERN_C_START
napi_value InitGeoNestGisModule(napi_env env, napi_value exports)
{
    napi_property_descriptor descriptors[] = {
        { "getNativeVersion", nullptr, GetNativeVersion, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getCoreProfile", nullptr, GetCoreProfile, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getProcessingAlgorithms", nullptr, NapiGetProcessingAlgorithms, nullptr, nullptr, nullptr,
            napi_default, nullptr },
        { "executeProcessingAlgorithm", nullptr, NapiExecuteProcessingAlgorithm, nullptr, nullptr, nullptr,
            napi_default, nullptr },
        { "startProcessingTask", nullptr, NapiStartProcessingTask, nullptr, nullptr, nullptr,
            napi_default, nullptr },
        { "getProcessingTaskStatus", nullptr, NapiGetProcessingTaskStatus, nullptr, nullptr, nullptr,
            napi_default, nullptr },
        { "cancelProcessingTask", nullptr, NapiCancelProcessingTask, nullptr, nullptr, nullptr,
            napi_default, nullptr },
        { "releaseProcessingTask", nullptr, NapiReleaseProcessingTask, nullptr, nullptr, nullptr,
            napi_default, nullptr },
        { "readQgisProject", nullptr, NapiReadQgisProject, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "writeQgisProject", nullptr, NapiWriteQgisProject, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "extractZipArchive", nullptr, NapiExtractZipArchive, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "openVectorLayer", nullptr, NapiOpenVectorLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "openRasterLayer", nullptr, NapiOpenRasterLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "closeLayer", nullptr, NapiCloseLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getLayerInfo", nullptr, NapiGetLayerInfo, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "listVectorSublayers", nullptr, NapiListVectorSublayers, nullptr, nullptr, nullptr,
            napi_default, nullptr },
        { "queryFeatures", nullptr, NapiQueryFeatures, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "selectFeaturesByGeometry", nullptr, NapiSelectFeaturesByGeometry, nullptr, nullptr, nullptr,
            napi_default, nullptr },
        { "getFeature", nullptr, NapiGetFeature, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "bufferLayer", nullptr, NapiBufferLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "simplifyLayer", nullptr, NapiSimplifyLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "dissolveLayer", nullptr, NapiDissolveLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "centroidLayer", nullptr, NapiCentroidLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "repairLayer", nullptr, NapiRepairLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "validateTopologyRules", nullptr, NapiValidateTopologyRules, nullptr, nullptr, nullptr,
            napi_default, nullptr },
        { "repairTopologyIssues", nullptr, NapiRepairTopologyIssues, nullptr, nullptr, nullptr,
            napi_default, nullptr },
        { "clipLayer", nullptr, NapiClipLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "exportLayer", nullptr, NapiExportLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "exportLayerToFormat", nullptr, NapiExportLayerToFormat, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "defineLayerProjection", nullptr, NapiDefineLayerProjection, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "projectLayer", nullptr, NapiProjectLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "applyVectorStyle", nullptr, NapiApplyVectorStyle, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "importQmlStyle", nullptr, NapiImportQmlStyle, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "exportQmlStyle", nullptr, NapiExportQmlStyle, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "applyVectorLabeling", nullptr, NapiApplyVectorLabeling, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "configureRasterDisplay", nullptr, NapiConfigureRasterDisplay, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "renderMapView", nullptr, NapiRenderMapView, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "exportMapLayout", nullptr, NapiExportMapLayout, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "describeCoordinateReferenceSystem", nullptr, NapiDescribeCoordinateReferenceSystem, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "transformCoordinate", nullptr, NapiTransformCoordinate, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "transformEnvelope", nullptr, NapiTransformEnvelope, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "beginEditSession", nullptr, NapiBeginEditSession, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "commitEditSession", nullptr, NapiCommitEditSession, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "rollbackEditSession", nullptr, NapiRollbackEditSession, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "undoEdit", nullptr, NapiUndoEdit, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "redoEdit", nullptr, NapiRedoEdit, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "isEditing", nullptr, NapiIsEditing, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "hasPendingEdits", nullptr, NapiHasPendingEdits, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "canUndo", nullptr, NapiCanUndo, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "canRedo", nullptr, NapiCanRedo, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "addFeature", nullptr, NapiAddFeature, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "deleteFeature", nullptr, NapiDeleteFeature, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "inspectPointCloud", nullptr, NapiInspectPointCloud, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "processPointCloud", nullptr, NapiProcessPointCloud, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "moveFeatureNode", nullptr, NapiMoveFeatureNode, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "deleteFeatureNode", nullptr, NapiDeleteFeatureNode, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "copyFeature", nullptr, NapiCopyFeature, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "splitFeature", nullptr, NapiSplitFeature, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "mergeFeatures", nullptr, NapiMergeFeatures, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "snapLayer", nullptr, NapiSnapLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "updateFeatureAttribute", nullptr, NapiUpdateFeatureAttribute, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "batchAssignAttribute", nullptr, NapiBatchAssignAttribute, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "addLayerField", nullptr, NapiAddLayerField, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "deleteLayerField", nullptr, NapiDeleteLayerField, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "calculateField", nullptr, NapiCalculateField, nullptr, nullptr, nullptr, napi_default, nullptr },
    };
    napi_define_properties(env, exports, sizeof(descriptors) / sizeof(descriptors[0]), descriptors);
    napi_status cleanupStatus = napi_add_async_cleanup_hook(env, CleanupBackgroundProcessing,
        static_cast<void *>(env), nullptr);
    if (cleanupStatus != napi_ok) {
        napi_throw_error(env, nullptr, "Cannot register GeoNest background processing cleanup");
        return nullptr;
    }
    return exports;
}
EXTERN_C_END

static napi_module geonestGisModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = InitGeoNestGisModule,
    .nm_modname = "geonestgis",
    .nm_priv = nullptr,
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterGeoNestGisModule(void)
{
    napi_module_register(&geonestGisModule);
}
