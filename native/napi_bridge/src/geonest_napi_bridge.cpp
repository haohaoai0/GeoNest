#include "geonest_napi_bridge.h"

#include "geonest_gis_core.h"
#include <cstring>
#include <cstdlib>

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

static napi_value CreateGeoProcessResult(napi_env env, const char *resultInfo, int32_t errCode)
{
    napi_value result = nullptr;
    napi_create_object(env, &result);

    napi_value infoVal = nullptr;
    napi_create_string_utf8(env, resultInfo ? resultInfo : "", NAPI_AUTO_LENGTH, &infoVal);
    napi_set_named_property(env, result, "resultInfo", infoVal);

    napi_value errVal = nullptr;
    napi_create_int32(env, errCode, &errVal);
    napi_set_named_property(env, result, "errCode", errVal);
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
    char requestJson[32768] = {0};
    if (!GetStringArg(env, info, 1, requestJson, sizeof(requestJson))) {
        return CreateGeoProcessResult(env,
            "{\"ok\":false,\"code\":6,\"message\":\"Processing request is empty\","
            "\"outputPath\":\"\",\"outputLayerName\":\"\",\"featureCount\":0}",
            geonest::GIS_ERR_INVALID_PARAM);
    }
    int32_t errCode = 0;
    const char *resultInfo = geonest::ExecuteProcessingAlgorithm(requestJson, &errCode);
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
// queryFeatures(handle, minX, minY, maxX, maxY, limit): { featurePage: string, errCode: number }
// ---------------------------------------------------------------------------
static napi_value NapiQueryFeatures(napi_env env, napi_callback_info info)
{
    size_t argc = 6;
    napi_value args[6];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t handle = 0;
    double minX = 0, minY = 0, maxX = 1, maxY = 1;
    int32_t limit = 0;

    if (argc >= 1) napi_get_value_int32(env, args[0], &handle);
    if (argc >= 2) napi_get_value_double(env, args[1], &minX);
    if (argc >= 3) napi_get_value_double(env, args[2], &minY);
    if (argc >= 4) napi_get_value_double(env, args[3], &maxX);
    if (argc >= 5) napi_get_value_double(env, args[4], &maxY);
    if (argc >= 6) napi_get_value_int32(env, args[5], &limit);

    int32_t errCode = 0;
    const char *pageJson = geonest::QueryFeatures(handle, minX, minY, maxX, maxY, limit, &errCode);

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

static napi_value NapiExportMapLayout(napi_env env, napi_callback_info info)
{
    size_t argc = 15;
    napi_value args[15];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    char title[512] = {0};
    char outputPath[2048] = {0};
    char format[32] = {0};
    char legendTitle[512] = {0};
    char scaleText[512] = {0};
    char footerText[512] = {0};
    char basemapLabel[512] = {0};
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
    if (argc >= 15) GetStringValue(env, args[14], visibleLayerHandles, sizeof(visibleLayerHandles));
    int32_t errCode = 0;
    const char *resultInfo = geonest::ExportMapLayout(title, outputPath, format, showLegend, showScaleBar,
        showNorthArrow, showGrid, width, height, legendTitle, scaleText, footerText, basemapMode, basemapLabel,
        visibleLayerHandles, &errCode);
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
        { "openVectorLayer", nullptr, NapiOpenVectorLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "openRasterLayer", nullptr, NapiOpenRasterLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "closeLayer", nullptr, NapiCloseLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getLayerInfo", nullptr, NapiGetLayerInfo, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "queryFeatures", nullptr, NapiQueryFeatures, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getFeature", nullptr, NapiGetFeature, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "bufferLayer", nullptr, NapiBufferLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "simplifyLayer", nullptr, NapiSimplifyLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "dissolveLayer", nullptr, NapiDissolveLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "centroidLayer", nullptr, NapiCentroidLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "repairLayer", nullptr, NapiRepairLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "clipLayer", nullptr, NapiClipLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "exportLayer", nullptr, NapiExportLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "defineLayerProjection", nullptr, NapiDefineLayerProjection, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "projectLayer", nullptr, NapiProjectLayer, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "applyVectorStyle", nullptr, NapiApplyVectorStyle, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "applyVectorLabeling", nullptr, NapiApplyVectorLabeling, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "configureRasterDisplay", nullptr, NapiConfigureRasterDisplay, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "exportMapLayout", nullptr, NapiExportMapLayout, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "describeCoordinateReferenceSystem", nullptr, NapiDescribeCoordinateReferenceSystem, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "transformCoordinate", nullptr, NapiTransformCoordinate, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "transformEnvelope", nullptr, NapiTransformEnvelope, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "addFeature", nullptr, NapiAddFeature, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "deleteFeature", nullptr, NapiDeleteFeature, nullptr, nullptr, nullptr, napi_default, nullptr },
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
