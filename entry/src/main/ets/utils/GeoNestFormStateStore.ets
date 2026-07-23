import { fileIo as fs } from '@kit.CoreFileKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

const FORM_STATE_TAG: string = 'GeoNestFormState';
const FORM_STATE_DOMAIN: number = 0xF815;
const FORM_STATE_MAGIC: string = 'GEONEST_FORM_STATE_V1';
const FORM_STATE_FILE_NAME: string = 'geonest_form_state.dat';
const FORM_IDS_FILE_NAME: string = 'geonest_form_ids.dat';

export class GeoNestFormState {
  projectName: string = '未命名工程';
  projectFileName: string = '未保存工程';
  layerSummary: string = '暂无图层';
  cloudStatus: string = '云空间同步未初始化';
  processingStatus: string = '暂无处理任务';
  actionHint: string = '打开工程 · 添加数据 · 继续上次工作';
  thumbnailUri: string = '';
  updatedAt: number = 0;
}

export class GeoNestFormBindingData {
  projectName: string = '';
  projectFileName: string = '';
  layerSummary: string = '';
  cloudStatus: string = '';
  processingStatus: string = '';
  actionHint: string = '';
  thumbnailUri: string = '';
  updatedText: string = '';
}

export class GeoNestFormStateStore {
  private static instance: GeoNestFormStateStore | null = null;

  private constructor() {}

  public static getInstance(): GeoNestFormStateStore {
    if (GeoNestFormStateStore.instance === null) {
      GeoNestFormStateStore.instance = new GeoNestFormStateStore();
    }
    return GeoNestFormStateStore.instance;
  }

  public readState(filesDir: string): GeoNestFormState {
    let state: GeoNestFormState = new GeoNestFormState();
    let content: string = this.readText(this.stateFilePath(filesDir));
    if (content.length === 0) {
      state.updatedAt = Date.now();
      return state;
    }
    let lines: string[] = content.split('\n');
    if (lines.length === 0 || this.cleanLine(lines[0]) !== FORM_STATE_MAGIC) {
      state.updatedAt = Date.now();
      return state;
    }
    state.projectName = this.valueForKey(lines, 'projectName', state.projectName);
    state.projectFileName = this.valueForKey(lines, 'projectFileName', state.projectFileName);
    state.layerSummary = this.valueForKey(lines, 'layerSummary', state.layerSummary);
    state.cloudStatus = this.valueForKey(lines, 'cloudStatus', state.cloudStatus);
    state.processingStatus = this.valueForKey(lines, 'processingStatus', state.processingStatus);
    state.actionHint = this.valueForKey(lines, 'actionHint', state.actionHint);
    state.thumbnailUri = this.valueForKey(lines, 'thumbnailUri', state.thumbnailUri);
    state.updatedAt = this.numberForKey(lines, 'updatedAt', Date.now());
    return state;
  }

  public writeState(filesDir: string, state: GeoNestFormState): void {
    if (filesDir.length === 0) {
      return;
    }
    if (state.updatedAt <= 0) {
      state.updatedAt = Date.now();
    }
    let content: string = FORM_STATE_MAGIC + '\n';
    content += 'projectName=' + this.encodeValue(state.projectName) + '\n';
    content += 'projectFileName=' + this.encodeValue(state.projectFileName) + '\n';
    content += 'layerSummary=' + this.encodeValue(state.layerSummary) + '\n';
    content += 'cloudStatus=' + this.encodeValue(state.cloudStatus) + '\n';
    content += 'processingStatus=' + this.encodeValue(state.processingStatus) + '\n';
    content += 'actionHint=' + this.encodeValue(state.actionHint) + '\n';
    content += 'thumbnailUri=' + this.encodeValue(state.thumbnailUri) + '\n';
    content += 'updatedAt=' + state.updatedAt.toString() + '\n';
    this.writeText(this.stateFilePath(filesDir), content);
  }

  public updateProcessingStatus(filesDir: string, processingStatus: string): void {
    let state: GeoNestFormState = this.readState(filesDir);
    state.processingStatus = processingStatus;
    state.updatedAt = Date.now();
    this.writeState(filesDir, state);
    this.updateKnownForms(filesDir);
  }

  public updateThumbnail(filesDir: string, thumbnailUri: string): void {
    let state: GeoNestFormState = this.readState(filesDir);
    state.thumbnailUri = thumbnailUri;
    state.updatedAt = Date.now();
    this.writeState(filesDir, state);
    this.updateKnownForms(filesDir);
  }

  public createBindingData(filesDir: string): formBindingData.FormBindingData {
    let state: GeoNestFormState = this.readState(filesDir);
    let data: GeoNestFormBindingData = new GeoNestFormBindingData();
    data.projectName = state.projectName;
    data.projectFileName = state.projectFileName;
    data.layerSummary = state.layerSummary;
    data.cloudStatus = state.cloudStatus;
    data.processingStatus = state.processingStatus;
    data.actionHint = state.actionHint;
    data.thumbnailUri = state.thumbnailUri;
    data.updatedText = this.formatUpdatedText(state.updatedAt);
    return formBindingData.createFormBindingData(data);
  }

  public registerFormId(filesDir: string, formId: string): void {
    if (filesDir.length === 0 || formId.length === 0) {
      return;
    }
    let ids: string[] = this.readFormIds(filesDir);
    for (let i: number = 0; i < ids.length; i++) {
      if (ids[i] === formId) {
        return;
      }
    }
    ids.push(formId);
    this.writeFormIds(filesDir, ids);
  }

  public unregisterFormId(filesDir: string, formId: string): void {
    if (filesDir.length === 0 || formId.length === 0) {
      return;
    }
    let ids: string[] = this.readFormIds(filesDir);
    let kept: string[] = [];
    for (let i: number = 0; i < ids.length; i++) {
      if (ids[i] !== formId) {
        kept.push(ids[i]);
      }
    }
    this.writeFormIds(filesDir, kept);
  }

  public updateKnownForms(filesDir: string): void {
    if (filesDir.length === 0) {
      return;
    }
    let ids: string[] = this.readFormIds(filesDir);
    if (ids.length === 0) {
      return;
    }
    let data: formBindingData.FormBindingData = this.createBindingData(filesDir);
    for (let i: number = 0; i < ids.length; i++) {
      let formId: string = ids[i];
      formProvider.updateForm(formId, data).catch((error: BusinessError) => {
        hilog.warn(FORM_STATE_DOMAIN, FORM_STATE_TAG,
          'update form failed. code=%{public}d message=%{public}s', error.code, error.message);
      });
    }
  }

  private stateFilePath(filesDir: string): string {
    if (filesDir.length === 0) {
      return '';
    }
    return filesDir + '/' + FORM_STATE_FILE_NAME;
  }

  private formIdsFilePath(filesDir: string): string {
    if (filesDir.length === 0) {
      return '';
    }
    return filesDir + '/' + FORM_IDS_FILE_NAME;
  }

  private readFormIds(filesDir: string): string[] {
    let ids: string[] = [];
    let content: string = this.readText(this.formIdsFilePath(filesDir));
    if (content.length === 0) {
      return ids;
    }
    let lines: string[] = content.split('\n');
    for (let i: number = 0; i < lines.length; i++) {
      let line: string = this.cleanLine(lines[i]).trim();
      if (line.length > 0 && line !== FORM_STATE_MAGIC) {
        ids.push(line);
      }
    }
    return ids;
  }

  private writeFormIds(filesDir: string, ids: string[]): void {
    let content: string = FORM_STATE_MAGIC + '\n';
    for (let i: number = 0; i < ids.length; i++) {
      content += ids[i] + '\n';
    }
    this.writeText(this.formIdsFilePath(filesDir), content);
  }

  private readText(path: string): string {
    if (path.length === 0) {
      return '';
    }
    let file: fs.File | null = null;
    try {
      file = fs.openSync(path, fs.OpenMode.READ_ONLY);
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

  private writeText(path: string, content: string): void {
    if (path.length === 0) {
      return;
    }
    let file: fs.File | null = null;
    try {
      let temporaryPath: string = path + '.tmp';
      file = fs.openSync(temporaryPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, content);
      fs.fsyncSync(file.fd);
      fs.closeSync(file);
      file = null;
      fs.renameSync(temporaryPath, path);
    } catch (error) {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (_closeError) {
        }
      }
      hilog.warn(FORM_STATE_DOMAIN, FORM_STATE_TAG, 'write form state failed: %{public}s', String(error));
    }
  }

  private valueForKey(lines: string[], key: string, fallback: string): string {
    let prefix: string = key + '=';
    for (let i: number = 0; i < lines.length; i++) {
      let line: string = this.cleanLine(lines[i]);
      if (line.startsWith(prefix)) {
        return this.decodeValue(line.substring(prefix.length));
      }
    }
    return fallback;
  }

  private numberForKey(lines: string[], key: string, fallback: number): number {
    let raw: string = this.valueForKey(lines, key, '');
    if (raw.length === 0) {
      return fallback;
    }
    let value: number = Number(raw);
    if (Number.isNaN(value)) {
      return fallback;
    }
    return value;
  }

  private cleanLine(value: string): string {
    if (value.endsWith('\r')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  private encodeValue(value: string): string {
    let result: string = '';
    for (let i: number = 0; i < value.length; i++) {
      let ch: string = value.charAt(i);
      if (ch === '\\') {
        result += '\\\\';
      } else if (ch === '\n') {
        result += '\\n';
      } else if (ch === '\r') {
        result += '\\r';
      } else if (ch === '=') {
        result += '\\e';
      } else {
        result += ch;
      }
    }
    return result;
  }

  private decodeValue(value: string): string {
    let result: string = '';
    let escaping: boolean = false;
    for (let i: number = 0; i < value.length; i++) {
      let ch: string = value.charAt(i);
      if (escaping) {
        if (ch === 'n') {
          result += '\n';
        } else if (ch === 'r') {
          result += '\r';
        } else if (ch === 'e') {
          result += '=';
        } else {
          result += ch;
        }
        escaping = false;
      } else if (ch === '\\') {
        escaping = true;
      } else {
        result += ch;
      }
    }
    if (escaping) {
      result += '\\';
    }
    return result;
  }

  private formatUpdatedText(updatedAt: number): string {
    if (updatedAt <= 0) {
      return '刚刚更新';
    }
    let date: Date = new Date(updatedAt);
    return '更新 ' + this.pad2(date.getHours()) + ':' + this.pad2(date.getMinutes());
  }

  private pad2(value: number): string {
    if (value < 10) {
      return '0' + value.toString();
    }
    return value.toString();
  }
}
