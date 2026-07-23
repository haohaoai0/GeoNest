import fs from '@ohos.file.fs';
import hilog from '@ohos.hilog';
import util from '@ohos.util';
import { WorkbenchTextService } from './WorkbenchTextService';

const LOG_TAG: number = 0xFF00;
const LOG_DOMAIN: string = 'GeoNestFile';

export class WorkbenchFileService {
  static writeArrayBufferAtomic(path: string, data: ArrayBuffer): boolean {
    let file: fs.File | null = null;
    try {
      let temporaryPath: string = path + '.tmp';
      file = fs.openSync(temporaryPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, data);
      fs.fsyncSync(file.fd);
      fs.closeSync(file);
      file = null;
      fs.renameSync(temporaryPath, path);
      return true;
    } catch (error) {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (closeError) {
        }
      }
      hilog.warn(LOG_TAG, LOG_DOMAIN, 'atomic write failed: %{public}s', String(error));
      return false;
    }
  }

  static createImportBatchDir(filesDir: string): string {
    let sandboxDir: string = filesDir + '/geonest_data';
    try {
      fs.mkdirSync(sandboxDir);
    } catch (error) {
    }
    let batchDir: string = sandboxDir + '/import_' + new Date().getTime().toString();
    try {
      fs.mkdirSync(batchDir);
    } catch (error) {
    }
    return batchDir;
  }

  static createArchiveExtractDir(importDir: string, baseName: string): string {
    let archiveDir: string = importDir + '/archive_' + WorkbenchTextService.safePathSegment(baseName);
    try {
      fs.mkdirSync(archiveDir, true);
    } catch (error) {
    }
    return archiveDir;
  }

  static createShapefileGroupDir(filesDir: string, baseName: string): string {
    let sandboxDir: string = filesDir + '/geonest_data';
    try {
      fs.mkdirSync(sandboxDir);
    } catch (error) {
    }
    let groupDir: string = sandboxDir + '/shapefile_' + WorkbenchTextService.safePathSegment(baseName);
    try {
      fs.mkdirSync(groupDir);
    } catch (error) {
    }
    return groupDir;
  }

  static copyUriToFile(uri: string, destinationPath: string): boolean {
    try {
      let sourceFile: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(sourceFile.fd);
      let buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(sourceFile.fd, buffer);
      fs.closeSync(sourceFile);
      let destinationFile: fs.File = fs.openSync(destinationPath,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(destinationFile.fd, buffer);
      fs.closeSync(destinationFile);
      return true;
    } catch (error) {
      hilog.warn(LOG_TAG, LOG_DOMAIN, 'copy URI failed: %{public}s', uri);
      return false;
    }
  }

  static copyFileToUri(sourcePath: string, uri: string): boolean {
    try {
      let sourceFile: fs.File = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(sourceFile.fd);
      let buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(sourceFile.fd, buffer);
      fs.closeSync(sourceFile);
      let destinationFile: fs.File = fs.openSync(uri,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(destinationFile.fd, buffer);
      fs.closeSync(destinationFile);
      return true;
    } catch (error) {
      hilog.warn(LOG_TAG, LOG_DOMAIN, 'copy file to URI failed: %{public}s', uri);
      return false;
    }
  }

  static createProjectSandboxDir(filesDir: string): string {
    let sandboxDir: string = filesDir + '/geonest_projects';
    try {
      fs.mkdirSync(sandboxDir);
    } catch (error) {
    }
    return sandboxDir;
  }

  static sandboxProjectPathForUri(filesDir: string, uri: string, fallbackFileName: string): string {
    let fileName: string = WorkbenchTextService.extractFileName(uri, fallbackFileName);
    let extension: string = WorkbenchTextService.fileExtension(fileName);
    let baseName: string = WorkbenchTextService.safePathSegment(WorkbenchTextService.fileBaseName(fileName));
    if (extension.length === 0) {
      extension = 'qgs';
    }
    return WorkbenchFileService.createProjectSandboxDir(filesDir) + '/' + new Date().getTime().toString() + '_' +
      baseName + '.' + extension;
  }

  static fileExists(path: string): boolean {
    try {
      let file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      fs.closeSync(file.fd);
      return true;
    } catch (error) {
      return false;
    }
  }

  static existingShapefileMemberPath(destinationDir: string, baseName: string, extension: string): string {
    let lowerPath: string = destinationDir + '/' + baseName + '.' + extension;
    if (WorkbenchFileService.fileExists(lowerPath)) {
      return lowerPath;
    }
    let upperPath: string = destinationDir + '/' + baseName + '.' + extension.toUpperCase();
    return WorkbenchFileService.fileExists(upperPath) ? upperPath : '';
  }

  static writeText(pathOrUri: string, content: string, quiet: boolean): boolean {
    try {
      let file: fs.File = fs.openSync(pathOrUri,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, content);
      fs.closeSync(file);
      return true;
    } catch (error) {
      if (!quiet) {
        hilog.error(LOG_TAG, LOG_DOMAIN, 'write text failed: %{public}s', String(error));
      }
      return false;
    }
  }

  static readText(pathOrUri: string, quiet: boolean): string {
    try {
      let file: fs.File = fs.openSync(pathOrUri, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(file.fd);
      let buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      let decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(new Uint8Array(buffer));
    } catch (error) {
      if (!quiet) {
        hilog.error(LOG_TAG, LOG_DOMAIN, 'read text failed: %{public}s', String(error));
      }
      return '';
    }
  }
}
