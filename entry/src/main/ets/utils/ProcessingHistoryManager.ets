import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  APP_PROCESSING_AUTO_LOAD_OUTPUT_KEY,
  APP_PROCESSING_HISTORY_LIMIT_KEY,
  APP_PROCESSING_KEEP_HISTORY_KEY,
  APP_PROCESSING_OUTPUT_FOLDER_KEY,
  APP_PROCESSING_OVERWRITE_OUTPUT_KEY,
  DEFAULT_PROCESSING_AUTO_LOAD_OUTPUT,
  DEFAULT_PROCESSING_HISTORY_LIMIT,
  DEFAULT_PROCESSING_KEEP_HISTORY,
  DEFAULT_PROCESSING_OUTPUT_FOLDER,
  DEFAULT_PROCESSING_OVERWRITE_OUTPUT
} from '../model/AppPreferences';
import { GisGeoProcessResult } from '../model/GeoNestModels';

const PROCESSING_HISTORY_TAG: string = 'GeoNestProcessing';
const PROCESSING_HISTORY_DOMAIN: number = 0xF814;
const PROCESSING_HISTORY_MAGIC: string = 'GEONEST_PROCESSING_HISTORY_V1';
const PROCESSING_HISTORY_FILE_NAME: string = 'geonest_processing_history.dat';
const PROCESSING_HISTORY_MAX_RECORDS: number = 200;

export const PROCESSING_TASK_STATUS_RUNNING: number = 0;
export const PROCESSING_TASK_STATUS_SUCCEEDED: number = 1;
export const PROCESSING_TASK_STATUS_FAILED: number = 2;
export const PROCESSING_TASK_STATUS_CANCELED: number = 3;
export const PROCESSING_HISTORY_REVISION_KEY: string = 'gnProcessingHistoryRevision';
export const PROCESSING_TASK_REVISION_KEY: string = 'gnProcessingTaskRevision';

export class ProcessingTaskRecord {
  taskId: string = '';
  algorithmId: string = '';
  inputLabel: string = '';
  overlayLabel: string = '';
  parameterSummary: string = '';
  outputPath: string = '';
  outputLayerName: string = '';
  status: number = PROCESSING_TASK_STATUS_RUNNING;
  startedAt: number = 0;
  finishedAt: number = 0;
  durationMs: number = 0;
  code: number = 0;
  message: string = '';
  featureCount: number = 0;
}

export class ProcessingEnvironmentSnapshot {
  outputFolder: string = DEFAULT_PROCESSING_OUTPUT_FOLDER;
  overwriteOutput: boolean = DEFAULT_PROCESSING_OVERWRITE_OUTPUT;
  autoLoadOutput: boolean = DEFAULT_PROCESSING_AUTO_LOAD_OUTPUT;
  keepHistory: boolean = DEFAULT_PROCESSING_KEEP_HISTORY;
  historyLimit: number = DEFAULT_PROCESSING_HISTORY_LIMIT;
}

export class ProcessingHistoryManager {
  private static instance: ProcessingHistoryManager | null = null;
  private historyFilePath: string = '';
  private filesDirectory: string = '';
  private records: ProcessingTaskRecord[] = [];
  private sequence: number = 0;

  private constructor() {}

  public static getInstance(): ProcessingHistoryManager {
    if (ProcessingHistoryManager.instance === null) {
      ProcessingHistoryManager.instance = new ProcessingHistoryManager();
    }
    return ProcessingHistoryManager.instance;
  }

  public init(context: common.UIAbilityContext): void {
    this.filesDirectory = context.filesDir;
    this.historyFilePath = context.filesDir + '/' + PROCESSING_HISTORY_FILE_NAME;
    this.records = this.loadRecords();
    let recoveredInterruptedTask: boolean = false;
    for (let i: number = 0; i < this.records.length; i++) {
      let record: ProcessingTaskRecord = this.records[i];
      if (record.status === PROCESSING_TASK_STATUS_RUNNING) {
        record.status = PROCESSING_TASK_STATUS_FAILED;
        record.finishedAt = Date.now();
        record.durationMs = Math.max(0, record.finishedAt - record.startedAt);
        record.code = 5;
        record.message = '应用在任务完成前退出';
        recoveredInterruptedTask = true;
      }
    }
    let priorCount: number = this.records.length;
    this.trimToConfiguredLimit();
    if (recoveredInterruptedTask || priorCount !== this.records.length) {
      this.persist();
    }
    AppStorage.setOrCreate<number>(PROCESSING_HISTORY_REVISION_KEY, 0);
    AppStorage.setOrCreate<number>(PROCESSING_TASK_REVISION_KEY, 0);
    this.bumpRevision();
  }

  public environment(): ProcessingEnvironmentSnapshot {
    let snapshot: ProcessingEnvironmentSnapshot = new ProcessingEnvironmentSnapshot();
    snapshot.outputFolder = this.sanitizeFolderName(
      AppStorage.get<string>(APP_PROCESSING_OUTPUT_FOLDER_KEY) ?? DEFAULT_PROCESSING_OUTPUT_FOLDER);
    snapshot.overwriteOutput = AppStorage.get<boolean>(APP_PROCESSING_OVERWRITE_OUTPUT_KEY) ??
      DEFAULT_PROCESSING_OVERWRITE_OUTPUT;
    snapshot.autoLoadOutput = AppStorage.get<boolean>(APP_PROCESSING_AUTO_LOAD_OUTPUT_KEY) ??
      DEFAULT_PROCESSING_AUTO_LOAD_OUTPUT;
    snapshot.keepHistory = AppStorage.get<boolean>(APP_PROCESSING_KEEP_HISTORY_KEY) ??
      DEFAULT_PROCESSING_KEEP_HISTORY;
    snapshot.historyLimit = this.validHistoryLimit(
      AppStorage.get<number>(APP_PROCESSING_HISTORY_LIMIT_KEY) ?? DEFAULT_PROCESSING_HISTORY_LIMIT);
    return snapshot;
  }

  public outputDirectory(): string {
    if (this.filesDirectory.length === 0) {
      return '';
    }
    return this.filesDirectory + '/' + this.environment().outputFolder;
  }

  public environmentJson(): string {
    let environment: ProcessingEnvironmentSnapshot = this.environment();
    return '{"overwriteOutput":' + (environment.overwriteOutput ? 'true' : 'false') +
      ',"autoLoadOutput":' + (environment.autoLoadOutput ? 'true' : 'false') +
      ',"outputWorkspace":"' + this.escapeJson(this.outputDirectory()) + '"}';
  }

  public validateOutputPath(outputPath: string): string {
    if (outputPath.length === 0) {
      return '未指定输出路径';
    }
    let environment: ProcessingEnvironmentSnapshot = this.environment();
    if (!environment.overwriteOutput) {
      try {
        let components: string[] = this.outputComponents(outputPath);
        for (let i: number = 0; i < components.length; i++) {
          if (fs.accessSync(components[i])) {
            return '输出或其配套文件已存在；请更换名称或在地理处理设置中允许覆盖输出';
          }
        }
      } catch (_error) {
        return '无法检查输出路径，请确认输出工作空间可用';
      }
    }
    return '';
  }

  private outputComponents(outputPath: string): string[] {
    let result: string[] = [outputPath];
    let lowerPath: string = outputPath.toLowerCase();
    let basePath: string = outputPath;
    if (lowerPath.endsWith('.shp')) {
      basePath = outputPath.substring(0, outputPath.length - 4);
      result = [basePath + '.shp', basePath + '.shx', basePath + '.dbf', basePath + '.prj',
        basePath + '.cpg', basePath + '.qix', basePath + '.sbn', basePath + '.sbx'];
    } else if (lowerPath.endsWith('.asc')) {
      basePath = outputPath.substring(0, outputPath.length - 4);
      result = [basePath + '.asc', basePath + '.prj', outputPath + '.aux.xml'];
    } else if (lowerPath.endsWith('.gpkg')) {
      result = [outputPath, outputPath + '-wal', outputPath + '-shm'];
    }
    return result;
  }

  public startTask(algorithmId: string, inputLabel: string, overlayLabel: string,
    parameterSummary: string, outputPath: string, outputLayerName: string): string {
    let now: number = Date.now();
    this.sequence++;
    let taskId: string = now.toString() + '-' + this.sequence.toString();
    let environment: ProcessingEnvironmentSnapshot = this.environment();
    if (!environment.keepHistory) {
      return taskId;
    }
    let record: ProcessingTaskRecord = new ProcessingTaskRecord();
    record.taskId = taskId;
    record.algorithmId = this.cleanValue(algorithmId);
    record.inputLabel = this.cleanValue(inputLabel);
    record.overlayLabel = this.cleanValue(overlayLabel);
    record.parameterSummary = this.limitText(this.cleanValue(parameterSummary), 400);
    record.outputPath = this.cleanValue(outputPath);
    record.outputLayerName = this.cleanValue(outputLayerName);
    record.status = PROCESSING_TASK_STATUS_RUNNING;
    record.startedAt = now;
    this.records.unshift(record);
    this.trimToConfiguredLimit();
    this.persist();
    this.bumpRevision();
    return taskId;
  }

  public finishTask(taskId: string, result: GisGeoProcessResult): void {
    if (taskId.length === 0) {
      return;
    }
    for (let i: number = 0; i < this.records.length; i++) {
      let record: ProcessingTaskRecord = this.records[i];
      if (record.taskId !== taskId) {
        continue;
      }
      if (record.status !== PROCESSING_TASK_STATUS_RUNNING) {
        return;
      }
      if (result.code === 8) {
        record.status = PROCESSING_TASK_STATUS_CANCELED;
      } else {
        record.status = result.ok ? PROCESSING_TASK_STATUS_SUCCEEDED : PROCESSING_TASK_STATUS_FAILED;
      }
      record.finishedAt = Date.now();
      record.durationMs = result.elapsedMs > 0 ? result.elapsedMs :
        Math.max(0, record.finishedAt - record.startedAt);
      record.code = result.code;
      record.message = this.limitText(this.cleanValue(result.message), 800);
      record.featureCount = result.featureCount;
      if (result.outputPath.length > 0) {
        record.outputPath = this.cleanValue(result.outputPath);
      }
      if (result.outputLayerName.length > 0) {
        record.outputLayerName = this.cleanValue(result.outputLayerName);
      }
      this.persist();
      this.bumpRevision();
      return;
    }
  }

  public history(): ProcessingTaskRecord[] {
    let priorCount: number = this.records.length;
    this.trimToConfiguredLimit();
    if (this.records.length !== priorCount) {
      this.persist();
    }
    let result: ProcessingTaskRecord[] = [];
    for (let i: number = 0; i < this.records.length; i++) {
      result.push(this.copyRecord(this.records[i]));
    }
    return result;
  }

  public clearHistory(): void {
    let runningRecords: ProcessingTaskRecord[] = [];
    for (let i: number = 0; i < this.records.length; i++) {
      if (this.records[i].status === PROCESSING_TASK_STATUS_RUNNING) {
        runningRecords.push(this.records[i]);
      }
    }
    this.records = runningRecords;
    this.persist();
    this.bumpRevision();
  }

  public notifyTaskRevision(): void {
    let revision: number = AppStorage.get<number>(PROCESSING_TASK_REVISION_KEY) ?? 0;
    AppStorage.setOrCreate<number>(PROCESSING_TASK_REVISION_KEY, revision + 1);
  }

  private copyRecord(source: ProcessingTaskRecord): ProcessingTaskRecord {
    let copy: ProcessingTaskRecord = new ProcessingTaskRecord();
    copy.taskId = source.taskId;
    copy.algorithmId = source.algorithmId;
    copy.inputLabel = source.inputLabel;
    copy.overlayLabel = source.overlayLabel;
    copy.parameterSummary = source.parameterSummary;
    copy.outputPath = source.outputPath;
    copy.outputLayerName = source.outputLayerName;
    copy.status = source.status;
    copy.startedAt = source.startedAt;
    copy.finishedAt = source.finishedAt;
    copy.durationMs = source.durationMs;
    copy.code = source.code;
    copy.message = source.message;
    copy.featureCount = source.featureCount;
    return copy;
  }

  private trimToConfiguredLimit(): void {
    let limit: number = this.environment().historyLimit;
    while (this.records.length > limit) {
      this.records.pop();
    }
  }

  private validHistoryLimit(value: number): number {
    if (value <= 20) {
      return 20;
    }
    if (value >= 100) {
      return 100;
    }
    return 50;
  }

  private sanitizeFolderName(value: string): string {
    let source: string = value.trim();
    let result: string = '';
    for (let i: number = 0; i < source.length; i++) {
      let ch: string = source.charAt(i);
      if (ch === '/' || ch === '\\' || ch === ':' || ch === '*' || ch === '?' || ch === '"' ||
        ch === '<' || ch === '>' || ch === '|') {
        result += '_';
      } else if (ch === '\r' || ch === '\n' || ch === '\t') {
        result += '_';
      } else {
        result += ch;
      }
    }
    if (result.length === 0 || result === '.' || result === '..') {
      return DEFAULT_PROCESSING_OUTPUT_FOLDER;
    }
    return result;
  }

  private cleanValue(value: string): string {
    let result: string = '';
    for (let i: number = 0; i < value.length; i++) {
      let ch: string = value.charAt(i);
      if (ch === '\r' || ch === '\n' || ch === '\t') {
        result += ' ';
      } else {
        result += ch;
      }
    }
    return result;
  }

  private limitText(value: string, maxLength: number): string {
    if (value.length <= maxLength) {
      return value;
    }
    return value.substring(0, maxLength);
  }

  private escapeJson(value: string): string {
    let result: string = '';
    for (let i: number = 0; i < value.length; i++) {
      let ch: string = value.charAt(i);
      if (ch === '\\') {
        result += '\\\\';
      } else if (ch === '"') {
        result += '\\"';
      } else {
        result += ch;
      }
    }
    return result;
  }

  private persist(): void {
    if (this.historyFilePath.length === 0) {
      return;
    }
    let content: string = PROCESSING_HISTORY_MAGIC + '\n';
    content += 'recordCount=' + this.records.length.toString() + '\n';
    for (let i: number = 0; i < this.records.length; i++) {
      let prefix: string = 'record.' + i.toString() + '.';
      let record: ProcessingTaskRecord = this.records[i];
      content += prefix + 'taskId=' + this.cleanValue(record.taskId) + '\n';
      content += prefix + 'algorithmId=' + this.cleanValue(record.algorithmId) + '\n';
      content += prefix + 'inputLabel=' + this.cleanValue(record.inputLabel) + '\n';
      content += prefix + 'overlayLabel=' + this.cleanValue(record.overlayLabel) + '\n';
      content += prefix + 'parameterSummary=' + this.cleanValue(record.parameterSummary) + '\n';
      content += prefix + 'outputPath=' + this.cleanValue(record.outputPath) + '\n';
      content += prefix + 'outputLayerName=' + this.cleanValue(record.outputLayerName) + '\n';
      content += prefix + 'status=' + record.status.toString() + '\n';
      content += prefix + 'startedAt=' + record.startedAt.toString() + '\n';
      content += prefix + 'finishedAt=' + record.finishedAt.toString() + '\n';
      content += prefix + 'durationMs=' + record.durationMs.toString() + '\n';
      content += prefix + 'code=' + record.code.toString() + '\n';
      content += prefix + 'message=' + this.cleanValue(record.message) + '\n';
      content += prefix + 'featureCount=' + record.featureCount.toString() + '\n';
    }
    this.writeText(content);
  }

  private loadRecords(): ProcessingTaskRecord[] {
    let result: ProcessingTaskRecord[] = [];
    let content: string = this.readText();
    if (content.length === 0) {
      return result;
    }
    let lines: string[] = content.split('\n');
    if (lines.length === 0 || this.cleanLine(lines[0]) !== PROCESSING_HISTORY_MAGIC) {
      return result;
    }
    let count: number = this.numberForKey(lines, 'recordCount', 0);
    if (count < 0) {
      count = 0;
    }
    if (count > PROCESSING_HISTORY_MAX_RECORDS) {
      count = PROCESSING_HISTORY_MAX_RECORDS;
    }
    for (let i: number = 0; i < count; i++) {
      let prefix: string = 'record.' + i.toString() + '.';
      let record: ProcessingTaskRecord = new ProcessingTaskRecord();
      record.taskId = this.valueForKey(lines, prefix + 'taskId');
      record.algorithmId = this.valueForKey(lines, prefix + 'algorithmId');
      record.inputLabel = this.valueForKey(lines, prefix + 'inputLabel');
      record.overlayLabel = this.valueForKey(lines, prefix + 'overlayLabel');
      record.parameterSummary = this.valueForKey(lines, prefix + 'parameterSummary');
      record.outputPath = this.valueForKey(lines, prefix + 'outputPath');
      record.outputLayerName = this.valueForKey(lines, prefix + 'outputLayerName');
      record.status = this.numberForKey(lines, prefix + 'status', PROCESSING_TASK_STATUS_FAILED);
      record.startedAt = this.numberForKey(lines, prefix + 'startedAt', 0);
      record.finishedAt = this.numberForKey(lines, prefix + 'finishedAt', 0);
      record.durationMs = this.numberForKey(lines, prefix + 'durationMs', 0);
      record.code = this.numberForKey(lines, prefix + 'code', 0);
      record.message = this.valueForKey(lines, prefix + 'message');
      record.featureCount = this.numberForKey(lines, prefix + 'featureCount', 0);
      if (record.taskId.length > 0 && record.algorithmId.length > 0) {
        result.push(record);
      }
    }
    return result;
  }

  private writeText(content: string): void {
    let file: fs.File | null = null;
    try {
      let temporaryPath: string = this.historyFilePath + '.tmp';
      file = fs.openSync(temporaryPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, content);
      fs.fsyncSync(file.fd);
      fs.closeSync(file);
      file = null;
      fs.renameSync(temporaryPath, this.historyFilePath);
    } catch (error) {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (_closeError) {
        }
      }
      hilog.warn(PROCESSING_HISTORY_DOMAIN, PROCESSING_HISTORY_TAG,
        'persist processing history failed: %{public}s', String(error));
    }
  }

  private readText(): string {
    if (this.historyFilePath.length === 0) {
      return '';
    }
    let file: fs.File | null = null;
    try {
      file = fs.openSync(this.historyFilePath, fs.OpenMode.READ_ONLY);
      let stat: fs.Stat = fs.statSync(file.fd);
      if (stat.size <= 0) {
        fs.closeSync(file);
        return '';
      }
      let buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      file = null;
      let decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      return decoder.decodeToString(new Uint8Array(buffer));
    } catch (_error) {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (_closeError) {
        }
      }
      return '';
    }
  }

  private cleanLine(value: string): string {
    if (value.endsWith('\r')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  private valueForKey(lines: string[], key: string): string {
    let prefix: string = key + '=';
    for (let i: number = 0; i < lines.length; i++) {
      let line: string = this.cleanLine(lines[i]);
      if (line.startsWith(prefix)) {
        return line.substring(prefix.length);
      }
    }
    return '';
  }

  private numberForKey(lines: string[], key: string, fallback: number): number {
    let valueText: string = this.valueForKey(lines, key);
    if (valueText.length === 0) {
      return fallback;
    }
    let value: number = Number(valueText);
    if (value !== value) {
      return fallback;
    }
    return value;
  }

  private bumpRevision(): void {
    let revision: number = AppStorage.get<number>(PROCESSING_HISTORY_REVISION_KEY) ?? 0;
    AppStorage.setOrCreate<number>(PROCESSING_HISTORY_REVISION_KEY, revision + 1);
  }
}
