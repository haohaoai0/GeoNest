import fs from '@ohos.file.fs';
import hilog from '@ohos.hilog';
import { fileIo } from '@kit.CoreFileKit';
import { bridgeExtractZipArchive } from '../gis/GisNativeBridge';
import { GisService } from '../gis/GisService';
import { GisOperationResult } from '../model/GeoNestModels';
import {
  ImportedDataFile,
  WorkbenchFileService,
  WorkbenchTextService
} from '@geonest/workbench';

const LOG_TAG: number = 0xFF00;
const LOG_DOMAIN: string = 'GeoNest';

export class WorkbenchImportResult {
  activeLayerName: string = '';
  selectedLayerIndex: number = -1;
  status: string = '';
  opened: boolean = false;
}

export class WorkbenchImportCoordinator {
  private filesDir: string = '';
  private fallbackFileName: string = '';
  private gisService: GisService;

  constructor(filesDir: string, fallbackFileName: string, gisService: GisService) {
    this.filesDir = filesDir;
    this.fallbackFileName = fallbackFileName;
    this.gisService = gisService;
  }

  private extractFileName(uri: string): string {
    return WorkbenchTextService.extractFileName(uri, this.fallbackFileName);
  }

  private isShapefileSidecarExtension(extension: string): boolean {
    return extension === 'shx' || extension === 'dbf' || extension === 'prj' || extension === 'cpg' ||
      extension === 'qpj' || extension === 'sbn' || extension === 'sbx';
  }

  private shouldCopySelectedDataFile(extension: string): boolean {
    return extension === 'shp' || this.isShapefileSidecarExtension(extension) ||
      WorkbenchTextService.isVectorOrTableFormat(extension) ||
      WorkbenchTextService.isRasterOrTileFormat(extension) || WorkbenchTextService.isArchiveFormat(extension);
  }

  private copyUriToImportDir(uri: string, importDir: string): ImportedDataFile | undefined {
    let fileName: string = this.extractFileName(uri);
    let displayName: string = WorkbenchTextService.displayFileName(fileName);
    let extension: string = WorkbenchTextService.fileExtension(fileName);
    let baseName: string = WorkbenchTextService.fileBaseName(fileName);
    let displayBaseName: string = WorkbenchTextService.fileBaseName(displayName);
    let targetDir: string = importDir;
    if (extension === 'shp' || this.isShapefileSidecarExtension(extension)) {
      targetDir = WorkbenchFileService.createShapefileGroupDir(this.filesDir, baseName);
    }
    let destinationPath: string = targetDir + '/' + fileName;
    if (WorkbenchFileService.copyUriToFile(uri, destinationPath)) {
      hilog.info(LOG_TAG, LOG_DOMAIN, 'copyUriToImportDir: copied %{public}s to %{public}s', fileName,
        destinationPath);
      return new ImportedDataFile(uri, fileName, displayName, extension, destinationPath, targetDir, baseName,
        displayBaseName);
    }
    return undefined;
  }

  private existingShapefileMemberPath(destinationDir: string, baseName: string, extension: string): string {
    return WorkbenchFileService.existingShapefileMemberPath(destinationDir, baseName, extension);
  }

  private hasRequiredShapefileMembers(file: ImportedDataFile): boolean {
    if (file.extension !== 'shp' && !this.isShapefileSidecarExtension(file.extension)) {
      return false;
    }
    let shpPath: string = this.existingShapefileMemberPath(file.destinationDir, file.baseName, 'shp');
    let shxPath: string = this.existingShapefileMemberPath(file.destinationDir, file.baseName, 'shx');
    let dbfPath: string = this.existingShapefileMemberPath(file.destinationDir, file.baseName, 'dbf');
    return shpPath.length > 0 && shxPath.length > 0 && dbfPath.length > 0;
  }

  private canOpenImportedFile(file: ImportedDataFile): boolean {
    if (file.extension === 'shp') {
      return true;
    }
    if (this.isShapefileSidecarExtension(file.extension)) {
      return false;
    }
    return WorkbenchTextService.isVectorOrTableFormat(file.extension) ||
      WorkbenchTextService.isRasterOrTileFormat(file.extension);
  }

  private openCopiedDataFile(file: ImportedDataFile): number {
    let layerIndex: number = this.gisService.openLayer(file.destinationPath);
    hilog.info(LOG_TAG, LOG_DOMAIN, 'openCopiedDataFile: %{public}s result=%{public}d', file.displayName, layerIndex);
    if (layerIndex >= 0) {
      let layer = this.gisService.getLayer(layerIndex);
      if (layer !== undefined && file.displayBaseName.length > 0) {
        layer.info.name = file.displayBaseName;
      }
      this.gisService.setActiveLayerIndex(layerIndex);
    }
    return layerIndex;
  }

  private appendOpenCandidate(candidates: ImportedDataFile[], candidate: ImportedDataFile): void {
    for (let i: number = 0; i < candidates.length; i++) {
      if (candidates[i].destinationPath === candidate.destinationPath) {
        return;
      }
    }
    candidates.push(candidate);
  }

  private appendExistingShapefileCandidate(candidates: ImportedDataFile[], file: ImportedDataFile): void {
    if (file.extension !== 'shp' && !this.isShapefileSidecarExtension(file.extension)) {
      return;
    }
    if (!this.hasRequiredShapefileMembers(file)) {
      return;
    }
    let shpPath: string = this.existingShapefileMemberPath(file.destinationDir, file.baseName, 'shp');
    if (shpPath.length > 0) {
      this.appendOpenCandidate(candidates, new ImportedDataFile(file.uri, file.baseName + '.shp',
        file.displayBaseName + '.shp', 'shp', shpPath, file.destinationDir, file.baseName, file.displayBaseName));
    }
  }

  private limitedNameList(names: string[], fallback: string): string {
    if (names.length === 0) {
      return fallback;
    }
    let text: string = '';
    let limit: number = names.length < 3 ? names.length : 3;
    for (let i: number = 0; i < limit; i++) {
      if (i > 0) {
        text += '、';
      }
      text += names[i];
    }
    if (names.length > limit) {
      text += ' 等';
    }
    return text;
  }

  private importStatusText(openedCount: number, failedCount: number, unsupportedCount: number,
    sidecarCount: number): string {
    let text: string = '已加载 ' + openedCount.toString() + ' 个图层';
    if (sidecarCount > 0) {
      text += '，附属文件 ' + sidecarCount.toString() + ' 个';
    }
    if (failedCount > 0) {
      text += '，失败 ' + failedCount.toString() + ' 个';
    }
    if (unsupportedCount > 0) {
      text += '，跳过 ' + unsupportedCount.toString() + ' 个';
    }
    return text;
  }

  private appendExtractedDataFiles(directoryPath: string, copiedFiles: ImportedDataFile[]): number {
    let unsupportedCount: number = 0;
    try {
      let fileNames: string[] = fileIo.listFileSync(directoryPath);
      for (let i: number = 0; i < fileNames.length; i++) {
        let candidatePath: string = directoryPath + '/' + fileNames[i];
        try {
          let stat = fs.statSync(candidatePath);
          if (stat.isDirectory()) {
            unsupportedCount += this.appendExtractedDataFiles(candidatePath, copiedFiles);
          } else if (stat.isFile()) {
            let fileName: string = this.extractFileName(candidatePath);
            let displayName: string = WorkbenchTextService.displayFileName(fileName);
            let extension: string = WorkbenchTextService.fileExtension(fileName);
            if (this.shouldCopySelectedDataFile(extension) && !WorkbenchTextService.isArchiveFormat(extension)) {
              let baseName: string = WorkbenchTextService.fileBaseName(fileName);
              let displayBaseName: string = WorkbenchTextService.fileBaseName(displayName);
              copiedFiles.push(new ImportedDataFile(candidatePath, fileName, displayName, extension, candidatePath,
                directoryPath, baseName, displayBaseName));
            } else {
              unsupportedCount++;
            }
          }
        } catch (error) {
          unsupportedCount++;
        }
      }
    } catch (error) {
      hilog.warn(LOG_TAG, LOG_DOMAIN, 'appendExtractedDataFiles: failed to scan %{public}s', directoryPath);
    }
    return unsupportedCount;
  }

  openFilesFromUris(uris: string[]): WorkbenchImportResult {
    let importResult: WorkbenchImportResult = new WorkbenchImportResult();
    try {
      let importDir: string = WorkbenchFileService.createImportBatchDir(this.filesDir);
      let copiedFiles: ImportedDataFile[] = [];
      let unsupportedCount: number = 0;
      let importFailedCount: number = 0;
      for (let i: number = 0; i < uris.length; i++) {
        let fileName: string = this.extractFileName(uris[i]);
        let extension: string = WorkbenchTextService.fileExtension(fileName);
        if (!this.shouldCopySelectedDataFile(extension)) {
          unsupportedCount++;
          hilog.warn(LOG_TAG, LOG_DOMAIN, 'openFilesFromUris: skip unsupported %{public}s',
            WorkbenchTextService.displayFileName(fileName));
          continue;
        }
        let copied: ImportedDataFile | undefined = this.copyUriToImportDir(uris[i], importDir);
        if (copied !== undefined) {
          if (WorkbenchTextService.isArchiveFormat(copied.extension)) {
            let archiveDir: string = WorkbenchFileService.createArchiveExtractDir(importDir, copied.baseName);
            let archiveResult: GisOperationResult = bridgeExtractZipArchive(copied.destinationPath, archiveDir);
            if (archiveResult.ok) {
              unsupportedCount += this.appendExtractedDataFiles(archiveDir, copiedFiles);
            } else {
              importFailedCount++;
              hilog.warn(LOG_TAG, LOG_DOMAIN, 'openFilesFromUris: extract ZIP failed %{public}s',
                copied.displayName);
            }
          } else {
            copiedFiles.push(copied);
          }
        } else {
          importFailedCount++;
        }
      }

      if (copiedFiles.length === 0) {
        if (importFailedCount > 0) {
          importResult.status = '压缩包解压或数据复制失败';
        } else if (unsupportedCount > 0) {
          importResult.status = '不支持所选文件类型';
        } else {
          importResult.status = '数据复制失败';
        }
        return importResult;
      }

      let openCandidates: ImportedDataFile[] = [];
      for (let i: number = 0; i < copiedFiles.length; i++) {
        let file: ImportedDataFile = copiedFiles[i];
        if (file.extension === 'shp' || this.isShapefileSidecarExtension(file.extension)) {
          this.appendExistingShapefileCandidate(openCandidates, file);
        } else if (this.canOpenImportedFile(file)) {
          this.appendOpenCandidate(openCandidates, file);
        }
      }

      let openedCount: number = 0;
      let failedCount: number = importFailedCount;
      let sidecarCount: number = 0;
      let shapefilePartCount: number = 0;
      let failedNames: string[] = [];
      for (let i: number = 0; i < copiedFiles.length; i++) {
        let copiedFile: ImportedDataFile = copiedFiles[i];
        if (copiedFile.extension === 'shp' || this.isShapefileSidecarExtension(copiedFile.extension)) {
          shapefilePartCount++;
        }
        if (this.isShapefileSidecarExtension(copiedFile.extension)) {
          sidecarCount++;
        } else if (copiedFile.extension !== 'shp' && !this.canOpenImportedFile(copiedFile)) {
          unsupportedCount++;
        }
      }

      for (let i: number = 0; i < openCandidates.length; i++) {
        let file: ImportedDataFile = openCandidates[i];
        let layerIndex: number = this.openCopiedDataFile(file);
        if (layerIndex >= 0) {
          openedCount++;
          importResult.selectedLayerIndex = layerIndex;
        } else {
          failedCount++;
          failedNames.push(file.displayName);
        }
      }

      if (openedCount > 0) {
        importResult.opened = true;
        importResult.status = this.importStatusText(openedCount, failedCount, unsupportedCount, sidecarCount);
        let activeLayer = this.gisService.getActiveLayer();
        if (activeLayer !== undefined) {
          importResult.activeLayerName = activeLayer.info.name;
        }
      } else if (failedCount > 0) {
        importResult.status = 'QGIS 未能打开：' + this.limitedNameList(failedNames, '所选数据') +
          '。Shapefile 请同时选择 .shp/.shx/.dbf/.prj/.cpg';
      } else if (shapefilePartCount > 0) {
        importResult.status = '已缓存 Shapefile 文件，请同时选择同名 .shp/.shx/.dbf 后再打开';
      } else {
        importResult.status = '不支持所选文件类型';
      }
    } catch (error) {
      importResult.status = '数据加载失败';
      hilog.error(LOG_TAG, LOG_DOMAIN, 'openFilesFromUris: EXCEPTION: %{public}s', String(error));
    }
    return importResult;
  }
}
