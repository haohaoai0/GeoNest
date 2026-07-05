import { harmonyShare, systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { fileUri } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import fs from '@ohos.file.fs';

const TAG: string = 'GeoNestShare';

export class GestureShareModel {
  private static instance: GestureShareModel | null = null;
  private context: common.UIAbilityContext;
  private listening: boolean = false;
  private getActiveLayerPath: (() => string) | null = null;
  private getActiveLayerName: (() => string) | null = null;

  private constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  static getInstance(context: common.UIAbilityContext): GestureShareModel {
    if (!GestureShareModel.instance) {
      GestureShareModel.instance = new GestureShareModel(context);
    }
    return GestureShareModel.instance;
  }

  public setLayerProvider(
    pathProvider: () => string,
    nameProvider: () => string
  ): void {
    this.getActiveLayerPath = pathProvider;
    this.getActiveLayerName = nameProvider;
  }

  public startListening(): void {
    if (this.listening) { return; }
    if (!canIUse('SystemCapability.Collaboration.HarmonyShare')) { return; }
    window.getLastWindow(this.context).then((win) => {
      try {
        const windowId: number = win.getWindowProperties().id;
        harmonyShare.on('gesturesShare', { windowId: windowId },
          (target: harmonyShare.SharableTarget) => {
            this.onGestureShare(target);
          });
        this.listening = true;
        hilog.info(0x0000, TAG, 'Gesture share listening started');
      } catch (err) {
        hilog.error(0x0000, TAG, 'startListening error: ' + (err as BusinessError).message);
      }
    }).catch((_: BusinessError) => {});
  }

  public stopListening(): void {
    if (!this.listening) { return; }
    this.listening = false;
    if (!canIUse('SystemCapability.Collaboration.HarmonyShare')) { return; }
    window.getLastWindow(this.context).then((win) => {
      try {
        const windowId: number = win.getWindowProperties().id;
        harmonyShare.off('gesturesShare', { windowId: windowId });
      } catch (_) {}
    }).catch((_: BusinessError) => {});
  }

  private async onGestureShare(target: harmonyShare.SharableTarget): Promise<void> {
    try {
      const shareData: systemShare.SharedData = await this.generateShareData();
      target.share(shareData);
      hilog.info(0x0000, TAG, 'Gesture share success');
    } catch (err) {
      hilog.error(0x0000, TAG, 'onGestureShare error: ' + (err as BusinessError).message);
    }
  }

  private async generateShareData(): Promise<systemShare.SharedData> {
    if (!this.getActiveLayerPath || !this.getActiveLayerName) {
      throw new Error('Layer provider not set');
    }
    const shpPath: string = this.getActiveLayerPath();
    if (shpPath.length === 0 || !shpPath.endsWith('.shp')) {
      throw new Error('No SHP layer loaded');
    }
    const basePath: string = shpPath.substring(0, shpPath.length - 4);
    const extensions: string[] = ['.shp', '.shx', '.dbf', '.prj'];
    const shareUris: string[] = [];
    for (let i = 0; i < extensions.length; i++) {
      const filePath: string = basePath + extensions[i];
      try {
        const stat = fs.statSync(filePath);
        if (stat.isFile()) {
          shareUris.push(fileUri.getUriFromPath(filePath));
        }
      } catch (e) {
        // skip
      }
    }
    if (shareUris.length === 0) {
      throw new Error('No SHP files found');
    }
    const utdTypeId: string = utd.getUniformDataTypeByFilenameExtension('.shp',
      utd.UniformDataType.FILE);
    const layerName: string = this.getActiveLayerName();
    return new systemShare.SharedData({
      utd: utdTypeId,
      uri: shareUris[0],
      title: layerName,
      description: 'GeoNest Shapefile (' + shareUris.length + ' files)',
    });
  }
}
