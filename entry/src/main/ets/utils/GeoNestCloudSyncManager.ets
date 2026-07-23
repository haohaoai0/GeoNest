import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs, cloudSync, fileUri } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

const CLOUD_TAG: string = 'GeoNestCloudSync';
const CLOUD_DOMAIN: number = 0xF812;
const CLOUD_MANIFEST_MAGIC: string = 'GEONEST_CLOUD_PACKAGE_V1';
const CLOUD_PACKAGE_DIR_NAME: string = 'geonest_project_sync';
const CLOUD_MANIFEST_FILE_NAME: string = 'manifest.txt';
const LOCAL_IMPORT_DIR_NAME: string = 'geonest_cloud_import';
const MAX_LOG_COUNT: number = 80;
const CLOUD_SYNC_TIMEOUT_MS: number = 60000;
const CLOUD_DOWNLOAD_RETRY_COUNT: number = 120;

export class GeoNestCloudLayerPackage {
  layerIndex: number = 0;
  packageRelativePath: string = '';
  sourceFilePaths: string[] = [];

  constructor(layerIndex: number, packageRelativePath: string, sourceFilePaths: string[]) {
    this.layerIndex = layerIndex;
    this.packageRelativePath = packageRelativePath;
    this.sourceFilePaths = sourceFilePaths;
  }
}

export class GeoNestCloudUploadRequest {
  projectName: string = '';
  projectRelativePath: string = '';
  projectText: string = '';
  layerPackages: GeoNestCloudLayerPackage[] = [];

  constructor(projectName: string, projectRelativePath: string, projectText: string,
    layerPackages: GeoNestCloudLayerPackage[]) {
    this.projectName = projectName;
    this.projectRelativePath = projectRelativePath;
    this.projectText = projectText;
    this.layerPackages = layerPackages;
  }
}

export class GeoNestCloudPullResult {
  projectName: string = '';
  localProjectPath: string = '';
  localProjectText: string = '';

  constructor(projectName: string, localProjectPath: string, localProjectText: string) {
    this.projectName = projectName;
    this.localProjectPath = localProjectPath;
    this.localProjectText = localProjectText;
  }
}

export class GeoNestCloudSyncStatus {
  supported: boolean = false;
  isLoggedIn: boolean = false;
  isWorking: boolean = false;
  lastAction: string = 'none';
  lastSyncTime: number = 0;
  errorMessage: string = '';
  cloudDir: string = '';
  projectName: string = '';
}

class GeoNestCloudPackageManifest {
  projectName: string = '';
  projectRelativePath: string = '';
  updatedAt: number = 0;
  assetPaths: string[] = [];
}

export class GeoNestCloudSyncManager {
  private static instance: GeoNestCloudSyncManager | null = null;

  private context: common.UIAbilityContext | null = null;
  private cloudDir: string = '';
  private fileSync: cloudSync.FileSync | null = null;
  private cloudFileCache: cloudSync.CloudFileCache | null = null;
  private logs: string[] = [];
  private status: GeoNestCloudSyncStatus = new GeoNestCloudSyncStatus();

  private constructor() {}

  public static getInstance(): GeoNestCloudSyncManager {
    if (GeoNestCloudSyncManager.instance === null) {
      GeoNestCloudSyncManager.instance = new GeoNestCloudSyncManager();
    }
    return GeoNestCloudSyncManager.instance;
  }

  public async init(context: common.UIAbilityContext): Promise<boolean> {
    this.context = context;
    if (!context.cloudFileDir || context.cloudFileDir.length === 0) {
      this.status.supported = false;
      this.status.isLoggedIn = false;
      this.status.cloudDir = '';
      this.status.errorMessage = '当前设备未启用云空间同步';
      this.logWarn('cloudFileDir unavailable');
      return false;
    }
    this.cloudDir = context.cloudFileDir;
    this.status.supported = true;
    this.status.isLoggedIn = true;
    this.status.cloudDir = this.cloudDir;
    this.status.errorMessage = '';
    this.ensureCloudClients();
    this.ensureDir(this.getCloudPackageRoot());
    this.ensureDir(this.parentPath(this.getCloudProjectPath()));
    return true;
  }

  public reset(): void {
    this.status.isWorking = false;
    this.status.errorMessage = '';
    this.fileSync = null;
    this.cloudFileCache = null;
    this.cloudDir = '';
    this.status.supported = false;
    this.status.isLoggedIn = false;
    this.logInfo('reset');
  }

  public getStatus(): GeoNestCloudSyncStatus {
    let copy: GeoNestCloudSyncStatus = new GeoNestCloudSyncStatus();
    copy.supported = this.status.supported;
    copy.isLoggedIn = this.status.isLoggedIn;
    copy.isWorking = this.status.isWorking;
    copy.lastAction = this.status.lastAction;
    copy.lastSyncTime = this.status.lastSyncTime;
    copy.errorMessage = this.status.errorMessage;
    copy.cloudDir = this.status.cloudDir;
    copy.projectName = this.status.projectName;
    return copy;
  }

  public getLogs(): string[] {
    return this.logs.slice();
  }

  public async refreshCloudState(): Promise<boolean> {
    if (this.context === null || !await this.init(this.context)) {
      this.status.lastAction = 'failed';
      return false;
    }
    this.setWorking(true);
    try {
      if (!await this.synchronizeCloudFiles()) {
        this.status.lastAction = 'failed';
        return false;
      }
      let manifestPath: string = this.getCloudManifestPath();
      if (!fs.accessSync(manifestPath)) {
        this.status.projectName = '';
        this.status.errorMessage = '';
        this.logInfo('cloud directory refreshed: no project package');
        return true;
      }
      if (!await this.ensureFileAvailable(manifestPath)) {
        this.status.errorMessage = '云空间清单下载失败';
        this.status.lastAction = 'failed';
        return false;
      }
      let manifest: GeoNestCloudPackageManifest | null = this.parseManifestText(this.readTextFile(manifestPath));
      if (manifest === null) {
        this.status.errorMessage = '云空间工程包清单无效';
        this.status.lastAction = 'failed';
        return false;
      }
      this.status.projectName = manifest.projectName;
      this.status.lastSyncTime = manifest.updatedAt;
      this.status.errorMessage = '';
      this.logInfo('cloud directory refreshed: ' + manifest.projectName);
      return true;
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.status.errorMessage = err.message;
      this.status.lastAction = 'failed';
      this.logError('refresh failed: ' + err.message);
      return false;
    } finally {
      this.setWorking(false);
    }
  }

  public async uploadProject(request: GeoNestCloudUploadRequest): Promise<boolean> {
    if (this.context === null) {
      this.status.errorMessage = '云空间上下文尚未初始化';
      this.status.lastAction = 'failed';
      return false;
    }
    if (!await this.init(this.context)) {
      this.status.lastAction = 'failed';
      return false;
    }
    this.setWorking(true);
    try {
      let cloudRoot: string = this.getCloudPackageRoot();
      let projectPath: string = cloudRoot + '/' + request.projectRelativePath;
      this.ensureDir(cloudRoot);
      this.ensureDir(this.parentPath(projectPath));

      let assetPaths: string[] = [];
      for (let i = 0; i < request.layerPackages.length; i++) {
        let layerPackage: GeoNestCloudLayerPackage = request.layerPackages[i];
        let layerDir: string = this.parentPath(layerPackage.packageRelativePath);
        for (let j = 0; j < layerPackage.sourceFilePaths.length; j++) {
          let sourcePath: string = layerPackage.sourceFilePaths[j];
          if (!fs.accessSync(sourcePath)) {
            this.status.errorMessage = '图层文件不存在：' + sourcePath;
            this.status.lastAction = 'failed';
            this.logError('missing source file: ' + sourcePath);
            return false;
          }
          let fileName: string = this.fileName(sourcePath);
          let relativePath: string = layerDir.length > 0 ? layerDir + '/' + fileName : fileName;
          let destinationPath: string = cloudRoot + '/' + relativePath;
          this.ensureDir(this.parentPath(destinationPath));
          if (!this.copyFile(sourcePath, destinationPath)) {
            this.status.errorMessage = '复制文件到云空间失败：' + fileName;
            this.status.lastAction = 'failed';
            return false;
          }
          assetPaths.push(relativePath);
        }
      }

      if (!this.writeTextFile(projectPath, request.projectText)) {
        this.status.errorMessage = '写入云空间工程文件失败';
        this.status.lastAction = 'failed';
        return false;
      }

      let manifest: GeoNestCloudPackageManifest = new GeoNestCloudPackageManifest();
      manifest.projectName = request.projectName;
      manifest.projectRelativePath = request.projectRelativePath;
      manifest.updatedAt = Date.now();
      manifest.assetPaths = this.uniquePaths(assetPaths);

      if (!this.writeTextFile(this.getCloudManifestPath(), this.buildManifestText(manifest))) {
        this.status.errorMessage = '写入云空间清单失败';
        this.status.lastAction = 'failed';
        return false;
      }

      if (!await this.synchronizeCloudFiles()) {
        this.status.lastAction = 'failed';
        return false;
      }
      this.status.lastAction = 'upload';
      this.status.lastSyncTime = manifest.updatedAt;
      this.status.projectName = request.projectName;
      this.status.errorMessage = '';
      this.logInfo('upload success: ' + request.projectName);
      return true;
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.status.errorMessage = err.message;
      this.status.lastAction = 'failed';
      this.logError('upload failed: ' + err.message);
      return false;
    } finally {
      this.setWorking(false);
    }
  }

  public async pullProject(): Promise<GeoNestCloudPullResult | null> {
    if (this.context === null) {
      this.status.errorMessage = '云空间上下文尚未初始化';
      this.status.lastAction = 'failed';
      return null;
    }
    if (!await this.init(this.context)) {
      this.status.lastAction = 'failed';
      return null;
    }
    this.setWorking(true);
    try {
      if (!await this.synchronizeCloudFiles()) {
        this.status.lastAction = 'failed';
        return null;
      }

      let manifestPath: string = this.getCloudManifestPath();
      if (!await this.ensureFileAvailable(manifestPath)) {
        this.status.errorMessage = '云空间中尚未找到工程包';
        this.status.lastAction = 'failed';
        return null;
      }

      let manifestText: string = this.readTextFile(manifestPath);
      let manifest: GeoNestCloudPackageManifest | null = this.parseManifestText(manifestText);
      if (manifest === null) {
        this.status.errorMessage = '云空间工程包清单无效';
        this.status.lastAction = 'failed';
        return null;
      }

      let cloudRoot: string = this.getCloudPackageRoot();
      let cloudProjectPath: string = cloudRoot + '/' + manifest.projectRelativePath;
      if (!await this.ensureFileAvailable(cloudProjectPath)) {
        this.status.errorMessage = '云空间工程文件不可用';
        this.status.lastAction = 'failed';
        return null;
      }

      for (let i = 0; i < manifest.assetPaths.length; i++) {
        let assetPath: string = cloudRoot + '/' + manifest.assetPaths[i];
        if (!await this.ensureFileAvailable(assetPath)) {
          this.status.errorMessage = '云空间资产不可用：' + manifest.assetPaths[i];
          this.status.lastAction = 'failed';
          return null;
        }
      }

      let localRoot: string = this.buildLocalImportRoot();
      this.ensureDir(localRoot);
      this.ensureDir(localRoot + '/project');
      this.ensureDir(localRoot + '/assets');

      let localProjectPath: string = localRoot + '/' + manifest.projectRelativePath;
      this.ensureDir(this.parentPath(localProjectPath));
      if (!this.copyFile(cloudProjectPath, localProjectPath)) {
        this.status.errorMessage = '复制工程文件到本地失败';
        this.status.lastAction = 'failed';
        return null;
      }

      for (let i = 0; i < manifest.assetPaths.length; i++) {
        let relativePath: string = manifest.assetPaths[i];
        let sourcePath: string = cloudRoot + '/' + relativePath;
        let destinationPath: string = localRoot + '/' + relativePath;
        this.ensureDir(this.parentPath(destinationPath));
        if (!this.copyFile(sourcePath, destinationPath)) {
          this.status.errorMessage = '复制云空间资产到本地失败：' + relativePath;
          this.status.lastAction = 'failed';
          return null;
        }
      }

      let localProjectText: string = this.readTextFile(localProjectPath);
      let resolvedProjectText: string = this.resolveProjectText(localProjectText, localRoot);
      if (!this.writeTextFile(localProjectPath, resolvedProjectText)) {
        this.status.errorMessage = '写入本地工程文件失败';
        this.status.lastAction = 'failed';
        return null;
      }

      this.status.lastAction = 'pull';
      this.status.lastSyncTime = Date.now();
      this.status.projectName = manifest.projectName;
      this.status.errorMessage = '';
      this.logInfo('pull success: ' + manifest.projectName);
      return new GeoNestCloudPullResult(manifest.projectName, localProjectPath, resolvedProjectText);
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.status.errorMessage = err.message;
      this.status.lastAction = 'failed';
      this.logError('pull failed: ' + err.message);
      return null;
    } finally {
      this.setWorking(false);
    }
  }

  private ensureCloudClients(): void {
    if (this.fileSync === null) {
      this.fileSync = new cloudSync.FileSync();
    }
    if (this.cloudFileCache === null) {
      this.cloudFileCache = new cloudSync.CloudFileCache();
    }
  }

  private setWorking(working: boolean): void {
    this.status.isWorking = working;
  }

  private getCloudPackageRoot(): string {
    return this.cloudDir + '/' + CLOUD_PACKAGE_DIR_NAME;
  }

  private getCloudManifestPath(): string {
    return this.getCloudPackageRoot() + '/' + CLOUD_MANIFEST_FILE_NAME;
  }

  private getCloudProjectPath(): string {
    return this.getCloudPackageRoot() + '/project/geonest_cloud_project.gnproj';
  }

  private buildLocalImportRoot(): string {
    if (this.context === null) {
      return '';
    }
    return this.context.filesDir + '/' + LOCAL_IMPORT_DIR_NAME + '/' + Date.now().toString();
  }

  private buildManifestText(manifest: GeoNestCloudPackageManifest): string {
    let text: string = CLOUD_MANIFEST_MAGIC + '\n';
    text += 'projectName=' + this.cleanValue(manifest.projectName) + '\n';
    text += 'projectRelativePath=' + this.cleanValue(manifest.projectRelativePath) + '\n';
    text += 'updatedAt=' + manifest.updatedAt.toString() + '\n';
    text += 'assetCount=' + manifest.assetPaths.length.toString() + '\n';
    for (let i = 0; i < manifest.assetPaths.length; i++) {
      text += 'asset.' + i.toString() + '=' + this.cleanValue(manifest.assetPaths[i]) + '\n';
    }
    return text;
  }

  private parseManifestText(text: string): GeoNestCloudPackageManifest | null {
    if (text.length === 0) {
      return null;
    }
    let lines: string[] = text.split('\n');
    if (lines.length === 0 || this.cleanLine(lines[0]) !== CLOUD_MANIFEST_MAGIC) {
      return null;
    }
    let manifest: GeoNestCloudPackageManifest = new GeoNestCloudPackageManifest();
    manifest.projectName = this.valueForKey(lines, 'projectName');
    manifest.projectRelativePath = this.valueForKey(lines, 'projectRelativePath');
    manifest.updatedAt = this.numberForKey(lines, 'updatedAt', 0);
    let assetCount: number = this.numberForKey(lines, 'assetCount', 0);
    if (assetCount < 0) {
      assetCount = 0;
    }
    for (let i = 0; i < assetCount; i++) {
      let relativePath: string = this.valueForKey(lines, 'asset.' + i.toString());
      if (relativePath.length > 0) {
        manifest.assetPaths.push(relativePath);
      }
    }
    if (manifest.projectRelativePath.length === 0) {
      return null;
    }
    return manifest;
  }

  private resolveProjectText(text: string, localRoot: string): string {
    let lines: string[] = text.split('\n');
    let result: string = '';
    for (let i = 0; i < lines.length; i++) {
      let line: string = this.cleanLine(lines[i]);
      let pathMarkerIndex: number = line.indexOf('.path=');
      if (pathMarkerIndex > 0) {
        let eqIndex: number = line.indexOf('=');
        if (eqIndex > 0) {
          let key: string = line.substring(0, eqIndex + 1);
          let value: string = line.substring(eqIndex + 1);
          if (!this.isAbsolutePath(value) && value.length > 0) {
            line = key + localRoot + '/' + value;
          }
        }
      }
      result += line;
      if (i < lines.length - 1) {
        result += '\n';
      }
    }
    return result;
  }

  private async ensureFileAvailable(filePath: string): Promise<boolean> {
    let stat: fs.Stat;
    try {
      if (!fs.accessSync(filePath)) {
        return false;
      }
      stat = fs.statSync(filePath);
    } catch (_error) {
      return false;
    }
    if (stat.location !== 2) {
      return true;
    }
    this.ensureCloudClients();
    if (this.cloudFileCache === null) {
      return false;
    }
    try {
      await this.cloudFileCache.start(fileUri.getUriFromPath(filePath));
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.logWarn('CloudFileCache start failed: ' + err.code.toString());
      return false;
    }
    for (let i = 0; i < CLOUD_DOWNLOAD_RETRY_COUNT; i++) {
      await this.sleep(500);
      try {
        stat = fs.statSync(filePath);
        if (stat.location === 1 || stat.location === 3) {
          return true;
        }
      } catch (_error) {
        return false;
      }
    }
    this.logWarn('download timeout: ' + filePath);
    return false;
  }

  private synchronizeCloudFiles(): Promise<boolean> {
    this.ensureCloudClients();
    if (this.fileSync === null) {
      this.status.errorMessage = '无法创建云空间同步任务';
      return Promise.resolve(false);
    }
    let client: cloudSync.FileSync = this.fileSync;
    return new Promise<boolean>((resolve: (value: boolean) => void): void => {
      let settled: boolean = false;
      let timer: number = 0;
      let callback = (progress: cloudSync.SyncProgress): void => {
        if (settled) {
          return;
        }
        if (progress.state === cloudSync.SyncState.COMPLETED) {
          settled = true;
          clearTimeout(timer);
          client.off('progress', callback);
          this.status.errorMessage = '';
          this.status.isLoggedIn = true;
          this.logInfo('FileSync completed');
          resolve(true);
        } else if (progress.state === cloudSync.SyncState.UPLOAD_FAILED ||
          progress.state === cloudSync.SyncState.DOWNLOAD_FAILED ||
          progress.state === cloudSync.SyncState.STOPPED) {
          settled = true;
          clearTimeout(timer);
          client.off('progress', callback);
          this.status.errorMessage = this.syncErrorMessage(progress.error);
          this.logError('FileSync failed: state=' + progress.state.toString() +
            ', error=' + progress.error.toString());
          resolve(false);
        }
      };
      timer = setTimeout((): void => {
        if (settled) {
          return;
        }
        settled = true;
        client.off('progress', callback);
        this.status.errorMessage = '云空间同步超时，请检查网络和云空间设置';
        this.logError('FileSync timeout');
        resolve(false);
      }, CLOUD_SYNC_TIMEOUT_MS);
      try {
        client.on('progress', callback);
        client.start().catch((error: BusinessError): void => {
          if (settled) {
            return;
          }
          settled = true;
          clearTimeout(timer);
          client.off('progress', callback);
          this.status.errorMessage = this.syncStartErrorMessage(error);
          if (error.code === 22400001) {
            this.status.isLoggedIn = false;
          }
          this.logError('FileSync start failed: ' + error.code.toString());
          resolve(false);
        });
      } catch (error) {
        let err: BusinessError = error as BusinessError;
        settled = true;
        clearTimeout(timer);
        this.status.errorMessage = this.syncStartErrorMessage(err);
        this.logError('FileSync start failed: ' + err.code.toString());
        resolve(false);
      }
    });
  }

  private syncStartErrorMessage(error: BusinessError): string {
    if (error.code === 22400001) {
      return '华为云空间未就绪，请在系统设置中登录账号并开启应用数据同步';
    }
    if (error.code === 22400002) {
      return '网络不可用，无法连接华为云空间';
    }
    if (error.code === 22400003) {
      return '设备电量过低，云空间同步暂不可用';
    }
    return error.message.length > 0 ? error.message : '启动华为云空间同步失败';
  }

  private syncErrorMessage(error: cloudSync.ErrorType): string {
    if (error === cloudSync.ErrorType.NETWORK_UNAVAILABLE) {
      return '网络不可用，云空间同步失败';
    }
    if (error === cloudSync.ErrorType.WIFI_UNAVAILABLE) {
      return '当前同步设置要求连接 WLAN';
    }
    if (error === cloudSync.ErrorType.BATTERY_LEVEL_LOW ||
      error === cloudSync.ErrorType.BATTERY_LEVEL_WARNING) {
      return '设备电量不足，云空间同步已暂停';
    }
    if (error === cloudSync.ErrorType.CLOUD_STORAGE_FULL) {
      return '华为云空间容量已满';
    }
    if (error === cloudSync.ErrorType.LOCAL_STORAGE_FULL) {
      return '设备本地存储空间不足';
    }
    if (error === cloudSync.ErrorType.DEVICE_TEMPERATURE_TOO_HIGH) {
      return '设备温度过高，云空间同步已暂停';
    }
    return '华为云空间同步未完成';
  }

  private copyFile(sourcePath: string, destinationPath: string): boolean {
    try {
      fs.copyFileSync(sourcePath, destinationPath);
      return true;
    } catch (_error) {
      try {
        let sourceFile: fs.File = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);
        let destinationFile: fs.File = fs.openSync(destinationPath,
          fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        let buffer: ArrayBuffer = new ArrayBuffer(16384);
        let length: number = fs.readSync(sourceFile.fd, buffer);
        while (length > 0) {
          fs.writeSync(destinationFile.fd, buffer, { length: length });
          length = fs.readSync(sourceFile.fd, buffer);
        }
        fs.fsyncSync(destinationFile.fd);
        fs.closeSync(sourceFile);
        fs.closeSync(destinationFile);
        return true;
      } catch (fallbackError) {
        let err: BusinessError = fallbackError as BusinessError;
        this.logError('copyFile failed: ' + err.message);
        return false;
      }
    }
  }

  private writeTextFile(path: string, content: string): boolean {
    try {
      let file: fs.File = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, content);
      fs.closeSync(file);
      return true;
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.logError('writeTextFile failed: ' + err.message);
      return false;
    }
  }

  private readTextFile(path: string): string {
    try {
      let file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      let stat: fs.Stat = fs.statSync(file.fd);
      if (stat.size <= 0) {
        fs.closeSync(file);
        return '';
      }
      let buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      let decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      return decoder.decodeWithStream(new Uint8Array(buffer));
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      this.logError('readTextFile failed: ' + err.message);
      return '';
    }
  }

  private ensureDir(path: string): void {
    if (path.length === 0) {
      return;
    }
    try {
      fs.statSync(path);
    } catch (_error) {
      try {
        fs.mkdirSync(path, true);
      } catch (_ignored) {}
    }
  }

  private uniquePaths(paths: string[]): string[] {
    let set: Set<string> = new Set<string>();
    let result: string[] = [];
    for (let i = 0; i < paths.length; i++) {
      let item: string = paths[i];
      if (!set.has(item)) {
        set.add(item);
        result.push(item);
      }
    }
    return result;
  }

  private parentPath(path: string): string {
    let index: number = path.lastIndexOf('/');
    if (index <= 0) {
      return '';
    }
    return path.substring(0, index);
  }

  private fileName(path: string): string {
    let slashIndex: number = path.lastIndexOf('/');
    if (slashIndex >= 0 && slashIndex < path.length - 1) {
      return path.substring(slashIndex + 1);
    }
    return path;
  }

  private isAbsolutePath(path: string): boolean {
    if (path.startsWith('/')) {
      return true;
    }
    if (path.startsWith('file://')) {
      return true;
    }
    if (path.length > 1 && path.charAt(1) === ':') {
      return true;
    }
    return false;
  }

  private cleanValue(value: string): string {
    let result: string = '';
    for (let i = 0; i < value.length; i++) {
      let ch: string = value.charAt(i);
      if (ch === '\r' || ch === '\n') {
        result += ' ';
      } else {
        result += ch;
      }
    }
    return result;
  }

  private cleanLine(value: string): string {
    if (value.endsWith('\r')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  private valueForKey(lines: string[], key: string): string {
    let prefix: string = key + '=';
    for (let i = 0; i < lines.length; i++) {
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

  private logInfo(message: string): void {
    this.appendLog('INFO ' + message);
    hilog.info(CLOUD_DOMAIN, CLOUD_TAG, message);
  }

  private logWarn(message: string): void {
    this.appendLog('WARN ' + message);
    hilog.warn(CLOUD_DOMAIN, CLOUD_TAG, message);
  }

  private logError(message: string): void {
    this.appendLog('ERROR ' + message);
    hilog.error(CLOUD_DOMAIN, CLOUD_TAG, message);
  }

  private appendLog(message: string): void {
    let timestamp: string = new Date().toLocaleTimeString();
    this.logs.push('[' + timestamp + '] ' + message);
    if (this.logs.length > MAX_LOG_COUNT) {
      this.logs.shift();
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: Function): void => {
      setTimeout((): void => {
        resolve();
      }, ms);
    });
  }
}
