import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const RECOVERY_TAG: string = 'GeoNestRecovery';
const RECOVERY_DOMAIN: number = 0xF813;
const RECOVERY_MAGIC: string = 'GEONEST_RECOVERY_V1';
const RECOVERY_SEPARATOR: string = '\n---PROJECT---\n';
const RECOVERY_FILE_NAME: string = 'geonest_project_recovery.dat';
const PROJECT_MAGIC: string = 'GEONEST_PROJECT_V1';

export class ProjectRecoverySnapshot {
  projectText: string = '';
  projectUri: string = '';
  projectFileName: string = '';
  projectName: string = '';
  projectState: number = 1;
  savedAt: number = 0;
  hadPendingEdits: boolean = false;

  constructor(projectText: string, projectUri: string, projectFileName: string, projectName: string,
    projectState: number, savedAt: number, hadPendingEdits: boolean) {
    this.projectText = projectText;
    this.projectUri = projectUri;
    this.projectFileName = projectFileName;
    this.projectName = projectName;
    this.projectState = projectState;
    this.savedAt = savedAt;
    this.hadPendingEdits = hadPendingEdits;
  }
}

export class ProjectRecoveryManager {
  private recoveryFilePath: string = '';

  init(context: common.UIAbilityContext): void {
    this.recoveryFilePath = context.filesDir + '/' + RECOVERY_FILE_NAME;
  }

  path(): string {
    return this.recoveryFilePath;
  }

  save(projectText: string, projectUri: string, projectFileName: string, projectName: string,
    projectState: number, hadPendingEdits: boolean): boolean {
    if (this.recoveryFilePath.length === 0 || projectText.length === 0) {
      return false;
    }
    let savedAt: number = Date.now();
    let content: string = RECOVERY_MAGIC + '\n';
    content += 'savedAt=' + savedAt.toString() + '\n';
    content += 'projectUri=' + this.cleanHeaderValue(projectUri) + '\n';
    content += 'projectFileName=' + this.cleanHeaderValue(projectFileName) + '\n';
    content += 'projectName=' + this.cleanHeaderValue(projectName) + '\n';
    content += 'projectState=' + projectState.toString() + '\n';
    content += 'hadPendingEdits=' + (hadPendingEdits ? 'true' : 'false');
    content += RECOVERY_SEPARATOR;
    content += projectText;
    return this.writeText(content);
  }

  load(): ProjectRecoverySnapshot | null {
    let content: string = this.readText();
    if (content.length === 0 || !content.startsWith(RECOVERY_MAGIC + '\n')) {
      return null;
    }
    let separatorIndex: number = content.indexOf(RECOVERY_SEPARATOR);
    if (separatorIndex < 0) {
      return null;
    }
    let headerText: string = content.substring(0, separatorIndex);
    let projectText: string = content.substring(separatorIndex + RECOVERY_SEPARATOR.length);
    if (projectText.length === 0 ||
      (projectText !== PROJECT_MAGIC && !projectText.startsWith(PROJECT_MAGIC + '\n'))) {
      return null;
    }
    let lines: string[] = headerText.split('\n');
    let savedAt: number = Number(this.valueForKey(lines, 'savedAt'));
    if (!Number.isFinite(savedAt) || savedAt < 0) {
      savedAt = 0;
    }
    let projectState: number = Number(this.valueForKey(lines, 'projectState'));
    if (!Number.isFinite(projectState)) {
      projectState = 1;
    }
    let hadPendingEdits: boolean = this.valueForKey(lines, 'hadPendingEdits') === 'true';
    return new ProjectRecoverySnapshot(
      projectText,
      this.valueForKey(lines, 'projectUri'),
      this.valueForKey(lines, 'projectFileName'),
      this.valueForKey(lines, 'projectName'),
      projectState,
      savedAt,
      hadPendingEdits
    );
  }

  clear(): void {
    if (this.recoveryFilePath.length === 0) {
      return;
    }
    this.writeText('');
  }

  private cleanHeaderValue(value: string): string {
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

  private valueForKey(lines: string[], key: string): string {
    let prefix: string = key + '=';
    for (let i: number = 0; i < lines.length; i++) {
      let line: string = lines[i];
      if (line.startsWith(prefix)) {
        return line.substring(prefix.length);
      }
    }
    return '';
  }

  private writeText(content: string): boolean {
    let file: fs.File | null = null;
    try {
      let temporaryPath: string = this.recoveryFilePath + '.tmp';
      file = fs.openSync(temporaryPath,
        fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, content);
      fs.fsyncSync(file.fd);
      fs.closeSync(file);
      file = null;
      fs.renameSync(temporaryPath, this.recoveryFilePath);
      return true;
    } catch (error) {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (_closeError) {
        }
      }
      hilog.warn(RECOVERY_DOMAIN, RECOVERY_TAG, 'write recovery failed: %{public}s', String(error));
      return false;
    }
  }

  private readText(): string {
    if (this.recoveryFilePath.length === 0) {
      return '';
    }
    let file: fs.File | null = null;
    try {
      file = fs.openSync(this.recoveryFilePath, fs.OpenMode.READ_ONLY);
      let stat: fs.Stat = fs.statSync(file.fd);
      if (stat.size <= 0) {
        fs.closeSync(file);
        file = null;
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
}
