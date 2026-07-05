import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '../utils/MaterialStyle';
import { getGisService, GisLoadedLayer } from '../gis/GisService';
import { print } from '@kit.BasicServicesKit';
import { fileUri, picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import fs from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';
import { GisGeoProcessResult } from '../model/GeoNestModels';
import {
  BASEMAP_HARMONY_IMAGERY,
  BASEMAP_HARMONY_TERRAIN,
  BASEMAP_IMAGERY,
  BASEMAP_TERRAIN,
  BASEMAP_VECTOR
} from './GisMapCanvas';

const MAP_EXPORT_BASE_NAME: string = 'GeoNestMap';
const MAP_EXPORT_PNG_SUFFIX: string = 'PNG 图像|.png';
const MAP_EXPORT_PDF_SUFFIX: string = 'PDF 文档|.pdf';
const MAP_EXPORT_SVG_SUFFIX: string = 'SVG 矢量图|.svg';
const MAP_PRINT_BASE_NAME: string = 'GeoNestPrint';

class GeoNestPrintDocumentAdapter implements print.PrintDocumentAdapter {
  sourcePath: string = '';

  constructor(sourcePath: string) {
    this.sourcePath = sourcePath;
  }

  onStartLayoutWrite(jobId: string, oldAttrs: print.PrintAttributes, newAttrs: print.PrintAttributes, fd: number,
    writeResultCallback: (jobId: string, writeResult: print.PrintFileCreationState) => void): void {
    let sourceFd: number = -1;
    try {
      let sourceFile = fs.openSync(this.sourcePath, fs.OpenMode.READ_ONLY);
      sourceFd = sourceFile.fd;
      fs.copyFileSync(sourceFd, fd);
      writeResultCallback(jobId, print.PrintFileCreationState.PRINT_FILE_CREATED);
    } catch (e) {
      writeResultCallback(jobId, print.PrintFileCreationState.PRINT_FILE_CREATION_FAILED);
    } finally {
      if (sourceFd >= 0) {
        try {
          fs.closeSync(sourceFd);
        } catch (e) {
        }
      }
    }
  }

  onJobStateChanged(jobId: string, state: print.PrintDocumentAdapterState): void {
  }
}

@Component
export struct MapLayoutSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  onGetBasemapMode: () => number = () => BASEMAP_VECTOR;
  onGetBasemapLabel: () => string = () => '本地矢量底图';
  @State private layoutTitle: string = 'GeoNest 地图';
  @State private legendTitle: string = '图例';
  @State private scaleText: string = '比例尺';
  @State private footerText: string = 'GeoNest QGIS 地图出图';
  @State private pageWidthText: string = '1600';
  @State private pageHeightText: string = '1100';
  @State private exportFormat: number = 0;
  @State private showLegend: boolean = true;
  @State private showScale: boolean = true;
  @State private showNorth: boolean = true;
  @State private showGrid: boolean = true;
  @State private statusText: string = '布局设计就绪';
  @State private lastExportPath: string = '';
  @State private lastExportName: string = '';
  @State private uiRevision: number = 0;

  onTrigger(): void {
    this.isShow = true;
  }

  private refreshDialogUi(): void {
    this.uiRevision++;
  }

  private formatName(): string {
    if (this.exportFormat === 1) {
      return 'PDF';
    }
    if (this.exportFormat === 2) {
      return 'SVG';
    }
    return 'PNG';
  }

  private formatCode(): string {
    if (this.exportFormat === 1) {
      return 'pdf';
    }
    if (this.exportFormat === 2) {
      return 'svg';
    }
    return 'png';
  }

  private suffixChoice(): string {
    if (this.exportFormat === 1) {
      return MAP_EXPORT_PDF_SUFFIX;
    }
    if (this.exportFormat === 2) {
      return MAP_EXPORT_SVG_SUFFIX;
    }
    return MAP_EXPORT_PNG_SUFFIX;
  }

  private nextOutputFileName(): string {
    return MAP_EXPORT_BASE_NAME + '_' + new Date().getTime().toString() + '.' + this.formatCode();
  }

  private buildSaveOptions(fileName: string): picker.DocumentSaveOptions {
    let opts: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    opts.newFileNames = [fileName];
    opts.fileSuffixChoices = [this.suffixChoice()];
    return opts;
  }

  private updateStatus(): void {
    this.statusText = '已配置 ' + this.formatName() + ' 出图参数';
  }

  private cleanOutputDimension(valueText: string, fallback: number): number {
    let value = Number(valueText);
    if (value !== value) {
      return fallback;
    }
    if (value < 800) {
      return fallback;
    }
    if (value > 6000) {
      return fallback;
    }
    return Math.round(value);
  }

  private outputWidth(): number {
    return this.cleanOutputDimension(this.pageWidthText, 1600);
  }

  private outputHeight(): number {
    return this.cleanOutputDimension(this.pageHeightText, 1100);
  }

  private currentBasemapMode(): number {
    return this.onGetBasemapMode();
  }

  private currentBasemapLabel(): string {
    let label = this.onGetBasemapLabel();
    if (label.length === 0) {
      return '本地矢量底图';
    }
    return label;
  }

  private exportFooterText(): string {
    return this.footerText + ' · ' + this.currentBasemapLabel();
  }

  private isPreviewTerrainBasemap(): boolean {
    let mode = this.currentBasemapMode();
    return mode === BASEMAP_TERRAIN || mode === BASEMAP_HARMONY_TERRAIN;
  }

  private isPreviewImageryBasemap(): boolean {
    let mode = this.currentBasemapMode();
    return mode === BASEMAP_IMAGERY || mode === BASEMAP_HARMONY_IMAGERY;
  }

  private copyExportToUri(sourcePath: string, targetUri: string, targetOpenMode: number): boolean {
    let sourceFd: number = -1;
    let targetFd: number = -1;
    try {
      let sourceFile = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);
      sourceFd = sourceFile.fd;
      let targetFile = fs.openSync(targetUri, targetOpenMode);
      targetFd = targetFile.fd;
      fs.copyFileSync(sourceFd, targetFd);
      return true;
    } catch (e) {
      this.statusText = '保存失败：' + String(e);
    } finally {
      if (sourceFd >= 0) {
        try {
          fs.closeSync(sourceFd);
        } catch (e) {
        }
      }
      if (targetFd >= 0) {
        try {
          fs.closeSync(targetFd);
        } catch (e) {
        }
      }
    }
    return false;
  }

  private exportLayoutToSandbox(): GisGeoProcessResult {
    let ctx = getContext(this) as common.UIAbilityContext;
    let exportDir = ctx.filesDir + '/geonest_exports';
    try {
      fs.mkdirSync(exportDir);
    } catch (e) {
    }
    let fileName = this.nextOutputFileName();
    let outputPath = exportDir + '/' + fileName;
    let result: GisGeoProcessResult = getGisService().exportMapLayout(this.layoutTitle, outputPath,
      this.formatCode(), this.showLegend, this.showScale, this.showNorth, this.showGrid,
      this.outputWidth(), this.outputHeight(), this.legendTitle, this.scaleText, this.exportFooterText(),
      this.currentBasemapMode(), this.currentBasemapLabel());
    if (result.ok) {
      this.lastExportPath = result.outputPath;
      this.lastExportName = fileName;
      this.statusText = '已生成出图文件：' + fileName;
    } else {
      this.statusText = '失败：' + result.message;
    }
    return result;
  }

  private saveLayoutToFile(): void {
    let result = this.exportLayoutToSandbox();
    if (!result.ok) {
      return;
    }
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      documentPicker.save(this.buildSaveOptions(this.lastExportName)).then((uris: Array<string>) => {
        if (uris.length > 0) {
          let targetUri = uris[0];
          let openMode = fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC;
          if (this.copyExportToUri(result.outputPath, targetUri, openMode)) {
            this.statusText = '已安全保存到文件：' + this.lastExportName;
          }
        }
      }).catch(() => {
        this.statusText = '已取消文件保存';
      });
    } catch (e) {
      this.statusText = '保存失败：' + String(e);
    }
  }

  private saveLayoutToAlbum(): void {
    if (this.exportFormat !== 0) {
      this.statusText = '相册仅支持 PNG 图片，请先切换 PNG';
      return;
    }
    let result = this.exportLayoutToSandbox();
    if (!result.ok) {
      return;
    }
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let helper = photoAccessHelper.getPhotoAccessHelper(ctx);
      let sourceUri = fileUri.getUriFromPath(result.outputPath);
      let sourceUris: Array<string> = [sourceUri];
      let photoConfig: photoAccessHelper.PhotoCreationConfig = {
        title: this.layoutTitle,
        fileNameExtension: 'png',
        photoType: photoAccessHelper.PhotoType.IMAGE,
        subtype: photoAccessHelper.PhotoSubtype.DEFAULT
      };
      let photoConfigs: Array<photoAccessHelper.PhotoCreationConfig> = [photoConfig];
      helper.showAssetsCreationDialog(sourceUris, photoConfigs).then((targetUris: Array<string>) => {
        if (targetUris.length > 0) {
          if (this.copyExportToUri(result.outputPath, targetUris[0], fs.OpenMode.WRITE_ONLY)) {
            this.statusText = '已安全保存到相册：' + this.lastExportName;
          }
        }
      }).catch(() => {
        this.statusText = '已取消相册保存';
      });
    } catch (e) {
      this.statusText = '保存到相册失败：' + String(e);
    }
  }

  @Builder
  layoutBasemapPreview() {
    Stack() {
      if (this.isPreviewImageryBasemap()) {
        Column() {
          Row() {
            Blank().layoutWeight(1).height(28).backgroundColor('#36464A')
            Blank().layoutWeight(1).height(28).backgroundColor('#253237')
            Blank().layoutWeight(1).height(28).backgroundColor('#44513F')
          }
          Row() {
            Blank().layoutWeight(1).height(28).backgroundColor('#2B3A3E')
            Blank().layoutWeight(1).height(28).backgroundColor('#36464A')
            Blank().layoutWeight(1).height(28).backgroundColor('#253237')
          }
          Row() {
            Blank().layoutWeight(1).height(28).backgroundColor('#44513F')
            Blank().layoutWeight(1).height(28).backgroundColor('#2B3A3E')
            Blank().layoutWeight(1).height(28).backgroundColor('#36464A')
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#2F3B42')
      } else if (this.isPreviewTerrainBasemap()) {
        Column() {
          Blank().height(18)
          Blank().height(1).width('100%').backgroundColor('#C7B98A')
          Blank().height(18)
          Blank().height(1).width('100%').backgroundColor('#AFC4A2')
          Blank().height(18)
          Blank().height(1).width('100%').backgroundColor('#C7B98A')
          Blank().layoutWeight(1).width('100%').backgroundColor('#DDE7C9')
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#F4F1E8')
      } else {
        Column() {
          Blank().layoutWeight(3).width('100%').backgroundColor('#F6FAF7')
          Blank().layoutWeight(1).width('100%').backgroundColor('#DCEFEB')
          Blank().layoutWeight(2).width('100%').backgroundColor('#F6FAF7')
        }
        .width('100%')
        .height('100%')
      }
      Text(this.currentBasemapLabel())
        .fontSize(10)
        .fontColor(this.isPreviewImageryBasemap() ? Color.White : $r('app.color.gn_text_muted'))
        .backgroundColor(this.isPreviewImageryBasemap() ? '#00000066' : '#FFFFFFCC')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .borderRadius(4)
        .position({ x: 10, y: 8 })
    }
    .width('100%')
    .height(70)
    .clip(true)
    .border({ width: 1, color: $r('app.color.gn_line_strong') })
  }

  @Builder
  chip(label: string, mode: number, group: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 5 }) {
        if (this.isChipActive(mode, group)) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(11)
            .fontColor([$r('app.color.gn_blue_800')])
        }
        Text(label)
          .fontSize(12)
          .fontWeight(this.isChipActive(mode, group) ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.isChipActive(mode, group) ? $r('app.color.gn_blue_800') :
            $r('app.color.gn_text_muted'))
      }
      .justifyContent(FlexAlign.Center)
    }
      .height(30)
      .padding({ left: 10, right: 10 })
      .backgroundColor(this.isChipActive(mode, group) ? $r('app.color.gn_blue_100') : Color.Transparent)
      .borderRadius(5)
      .border({
        width: 1,
        color: this.isChipActive(mode, group) ? $r('app.color.gn_blue_800') : $r('app.color.gn_line')
      })
      .onClick(() => {
        if (group === 0) {
          this.exportFormat = mode;
        } else if (group === 1) {
          this.showLegend = !this.showLegend;
        } else if (group === 2) {
          this.showScale = !this.showScale;
        } else if (group === 3) {
          this.showNorth = !this.showNorth;
        } else {
          this.showGrid = !this.showGrid;
        }
        this.updateStatus();
        this.refreshDialogUi();
      })
  }

  private isChipActive(mode: number, group: number): boolean {
    if (group === 0) {
      return this.exportFormat === mode;
    }
    if (group === 1) {
      return this.showLegend;
    }
    if (group === 2) {
      return this.showScale;
    }
    if (group === 3) {
      return this.showNorth;
    }
    return this.showGrid;
  }

  @Builder
  layoutSettingsPanel() {
    Column({ space: 14 }) {
      Column({ space: 9 }) {
        Text('版面文字')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        TextInput({ text: this.layoutTitle, placeholder: '地图标题' })
          .height(36)
          .fontSize(13)
          .backgroundColor($r('app.color.gn_pane'))
          .onChange((value: string) => {
            this.layoutTitle = value;
            this.refreshDialogUi();
          })
        Row({ space: 8 }) {
          TextInput({ text: this.legendTitle, placeholder: '图例标题' })
            .height(36)
            .fontSize(13)
            .backgroundColor($r('app.color.gn_pane'))
            .layoutWeight(1)
            .onChange((value: string) => {
              this.legendTitle = value;
              this.refreshDialogUi();
            })
          TextInput({ text: this.scaleText, placeholder: '比例尺文字' })
            .height(36)
            .fontSize(13)
            .backgroundColor($r('app.color.gn_pane'))
            .layoutWeight(1)
            .onChange((value: string) => {
              this.scaleText = value;
              this.refreshDialogUi();
            })
        }
        TextInput({ text: this.footerText, placeholder: '页脚说明' })
          .height(36)
          .fontSize(13)
          .backgroundColor($r('app.color.gn_pane'))
          .onChange((value: string) => {
            this.footerText = value;
            this.refreshDialogUi();
          })
      }
      .padding(14)
      .borderRadius(7)
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })

      Column({ space: 10 }) {
        Text('输出格式')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        Row({ space: 8 }) {
          this.chip('PNG', 0, 0)
          this.chip('PDF', 1, 0)
          this.chip('SVG', 2, 0)
        }
        Text('像素尺寸')
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
        Row({ space: 8 }) {
          TextInput({ text: this.pageWidthText, placeholder: '宽 px' })
            .height(34)
            .fontSize(12)
            .backgroundColor($r('app.color.gn_pane'))
            .layoutWeight(1)
            .onChange((value: string) => {
              this.pageWidthText = value;
              this.refreshDialogUi();
            })
          Text('×')
            .fontSize(14)
            .fontColor($r('app.color.gn_text_muted'))
          TextInput({ text: this.pageHeightText, placeholder: '高 px' })
            .height(34)
            .fontSize(12)
            .backgroundColor($r('app.color.gn_pane'))
            .layoutWeight(1)
            .onChange((value: string) => {
              this.pageHeightText = value;
              this.refreshDialogUi();
            })
        }
      }
      .padding(14)
      .borderRadius(7)
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })

      Column({ space: 10 }) {
        Text('地图要素')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        Text('出图仅包含工作区中当前显示的图层。')
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
        Row({ space: 8 }) {
          this.chip('图例', 0, 1)
          this.chip('比例尺', 0, 2)
          this.chip('指北针', 0, 3)
          this.chip('坐标网', 0, 4)
        }
      }
      .padding(14)
      .borderRadius(7)
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
    }
    .width('100%')
  }

  @Builder
  layoutPreviewPanel() {
    Column({ space: 10 }) {
      Text('实时预览')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
        .width('100%')
      Column({ space: 7 }) {
        Text(this.layoutTitle)
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.gn_text_primary'))
        this.layoutBasemapPreview()
        Text(this.formatName() + ' · ' + this.outputWidth().toString() + ' × ' +
          this.outputHeight().toString())
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
        Text(getGisService().getVisibleLayerCount().toString() + ' 个当前显示图层')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_blue_800'))
        Text((this.showLegend ? this.legendTitle + ' ' : '') + (this.showScale ? this.scaleText + ' ' : '') +
          (this.showNorth ? '指北针 ' : '') + (this.showGrid ? '坐标网' : ''))
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
        Text(this.exportFooterText())
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding(12)
      .borderRadius(6)
      .backgroundColor($r('app.color.gn_pane'))
      .border({ width: 1, color: $r('app.color.gn_line') })
      Text('状态：' + this.statusText)
        .fontSize(11)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Button('保存到文件 ' + this.formatName(), { type: ButtonType.Capsule, stateEffect: true })
        .height(40)
        .width('100%')
        .fontSize(13)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.gn_blue_800'))
        .onClick(() => {
          this.saveLayoutToFile();
        })
      Button('保存到相册', { type: ButtonType.Capsule, stateEffect: true })
        .height(38)
        .width('100%')
        .fontSize(13)
        .fontColor(this.exportFormat === 0 ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
        .backgroundColor($r('app.color.gn_pane'))
        .enabled(this.exportFormat === 0)
        .onClick(() => {
          this.saveLayoutToAlbum();
        })
    }
    .width(220)
    .padding(12)
    .borderRadius(7)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  sheetContent() {
    Column() {
      HdsNavigation() {
        Row({ space: 12 }) {
          Scroll(this.scroller) {
            Column() {
              Blank().height(80).width('100%')
              this.layoutSettingsPanel()
            }
          }
          .layoutWeight(1)
          .height('100%')
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
          this.layoutPreviewPanel()
        }
        .width('100%')
        .height('100%')
        .padding(14)
      }
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MODAL)
      .titleBar({
        style: MaterialStyle.isHigh() && this.materialEnabled ? {
          scrollEffectOpts: { scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
          }
        } : undefined,
        content: {
          title: { mainTitle: '地图出图设置' },
          menu: {
            value: [{
              content: {
                label: 'modal_cancel', isEnabled: true,
                type: IconStyleMode.SMALL,
                action: () => { this.isShow = false; }
              }
            }]
          }
        }
      })
      .bindToScrollable([this.scroller])
    }
    .width('100%').height('100%')
  }

  build() {
    Row().width(0).height(0)
      .bindSheet($$this.isShow, this.sheetContent(), {
        detents: [SheetSize.LARGE],
        preferType: SheetType.CENTER,
        dragBar: false,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.Thin,
        systemMaterial: MaterialStyle.nativeMaterial(this.materialEnabled),
        showClose: false,
        onDisappear: (): void => { this.isShow = false; }
      })
  }
}

@Component
export struct PrintSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  onGetBasemapMode: () => number = () => BASEMAP_VECTOR;
  onGetBasemapLabel: () => string = () => '本地矢量底图';
  @State private mapTitle: string = 'GeoNest 地图';
  @State private paperMode: number = 1;
  @State private orientationMode: number = 0;
  @State private qualityMode: number = 1;
  @State private colorMode: number = 0;
  @State private duplexMode: number = 0;
  @State private copyCountText: string = '1';
  @State private scaleDenominatorText: string = '8000';
  @State private fitToPaper: boolean = true;
  @State private showLegend: boolean = true;
  @State private showScale: boolean = true;
  @State private showNorth: boolean = true;
  @State private showGrid: boolean = true;
  @State private printerName: string = '系统默认打印机';
  @State private printerStatus: string = '由系统打印面板选择';
  @State private printerType: string = 'HarmonyOS 打印服务';
  @State private printerLocation: string = '-';
  @State private statusText: string = '打印参数就绪';
  @State private uiRevision: number = 0;

  onTrigger(): void {
    this.isShow = true;
  }

  aboutToAppear(): void {
    this.refreshPrinterInfo();
  }

  private refreshDialogUi(): void {
    this.uiRevision++;
  }

  private refreshPrinterInfo(): void {
    this.printerName = '系统默认打印机';
    this.printerStatus = '由系统打印面板选择';
    this.printerType = 'HarmonyOS 打印服务';
    this.printerLocation = '-';
    print.getAddedPrinters().then((printerIds: Array<string>) => {
      if (printerIds.length === 0) {
        this.printerStatus = '未查询到已添加打印机';
        return;
      }
      let printerId = printerIds[0];
      print.getPrinterInformationById(printerId).then((info: print.PrinterInformation) => {
        this.printerName = info.printerName;
        this.printerStatus = this.printerStatusName(info.printerStatus);
        if (info.printerMake !== undefined && info.printerMake.length > 0) {
          this.printerType = info.printerMake;
        } else if (info.description !== undefined && info.description.length > 0) {
          this.printerType = info.description;
        } else {
          this.printerType = 'HarmonyOS 打印机';
        }
        if (info.uri !== undefined && info.uri.length > 0) {
          this.printerLocation = info.uri;
        } else {
          this.printerLocation = printerId;
        }
      }).catch(() => {
        this.printerStatus = '打印机信息读取失败';
      });
    }).catch(() => {
      this.printerStatus = '未能读取打印机列表';
    });
  }

  private printerStatusName(status: print.PrinterStatus): string {
    if (status === print.PrinterStatus.PRINTER_IDLE) {
      return '就绪';
    }
    if (status === print.PrinterStatus.PRINTER_BUSY) {
      return '忙碌';
    }
    if (status === print.PrinterStatus.PRINTER_UNAVAILABLE) {
      return '不可用';
    }
    return '未知';
  }

  private cleanInteger(valueText: string, fallback: number, minValue: number, maxValue: number): number {
    let value = Number(valueText);
    if (value !== value) {
      return fallback;
    }
    value = Math.round(value);
    if (value < minValue) {
      return minValue;
    }
    if (value > maxValue) {
      return maxValue;
    }
    return value;
  }

  private copyCount(): number {
    return this.cleanInteger(this.copyCountText, 1, 1, 99);
  }

  private scaleDenominator(): number {
    return this.cleanInteger(this.scaleDenominatorText, 8000, 1, 1000000000);
  }

  private paperName(): string {
    if (this.paperMode === 0) {
      return 'A3';
    }
    if (this.paperMode === 2) {
      return 'A5';
    }
    if (this.paperMode === 3) {
      return 'Letter';
    }
    return 'A4';
  }

  private paperWidthCm(): number {
    if (this.paperMode === 0) {
      return 29.7;
    }
    if (this.paperMode === 2) {
      return 14.8;
    }
    if (this.paperMode === 3) {
      return 21.6;
    }
    return 21.0;
  }

  private paperHeightCm(): number {
    if (this.paperMode === 0) {
      return 42.0;
    }
    if (this.paperMode === 2) {
      return 21.0;
    }
    if (this.paperMode === 3) {
      return 27.9;
    }
    return 29.7;
  }

  private basePageWidthPx(): number {
    if (this.paperMode === 0) {
      return 1684;
    }
    if (this.paperMode === 2) {
      return 839;
    }
    if (this.paperMode === 3) {
      return 1224;
    }
    return 1191;
  }

  private basePageHeightPx(): number {
    if (this.paperMode === 0) {
      return 2381;
    }
    if (this.paperMode === 2) {
      return 1191;
    }
    if (this.paperMode === 3) {
      return 1584;
    }
    return 1684;
  }

  private layoutWidth(): number {
    if (this.orientationMode === 1) {
      return this.basePageHeightPx();
    }
    return this.basePageWidthPx();
  }

  private layoutHeight(): number {
    if (this.orientationMode === 1) {
      return this.basePageWidthPx();
    }
    return this.basePageHeightPx();
  }

  private pageDimensionText(): string {
    let widthCm = this.paperWidthCm();
    let heightCm = this.paperHeightCm();
    if (this.orientationMode === 1) {
      let temp = widthCm;
      widthCm = heightCm;
      heightCm = temp;
    }
    return this.paperName() + ' · ' + widthCm.toFixed(1) + ' × ' + heightCm.toFixed(1) + ' cm';
  }

  private qualityName(): string {
    if (this.qualityMode === 0) {
      return '快速';
    }
    if (this.qualityMode === 2) {
      return '最佳';
    }
    return '常规';
  }

  private scaleLabel(): string {
    return '比例尺 1:' + this.scaleDenominator().toString();
  }

  private footerLabel(): string {
    return 'GeoNest 打印输出 · ' + this.paperName() + ' · ' + this.qualityName() + ' · ' +
      this.currentBasemapLabel();
  }

  private currentBasemapMode(): number {
    return this.onGetBasemapMode();
  }

  private currentBasemapLabel(): string {
    let label = this.onGetBasemapLabel();
    if (label.length === 0) {
      return '本地矢量底图';
    }
    return label;
  }

  private isPreviewTerrainBasemap(): boolean {
    let mode = this.currentBasemapMode();
    return mode === BASEMAP_TERRAIN || mode === BASEMAP_HARMONY_TERRAIN;
  }

  private isPreviewImageryBasemap(): boolean {
    let mode = this.currentBasemapMode();
    return mode === BASEMAP_IMAGERY || mode === BASEMAP_HARMONY_IMAGERY;
  }

  private printPageType(): print.PrintPageType {
    if (this.paperMode === 0) {
      return print.PrintPageType.PAGE_ISO_A3;
    }
    if (this.paperMode === 2) {
      return print.PrintPageType.PAGE_ISO_A5;
    }
    if (this.paperMode === 3) {
      return print.PrintPageType.PAGE_LETTER;
    }
    return print.PrintPageType.PAGE_ISO_A4;
  }

  private printDirectionMode(): print.PrintDirectionMode {
    if (this.orientationMode === 1) {
      return print.PrintDirectionMode.DIRECTION_MODE_LANDSCAPE;
    }
    return print.PrintDirectionMode.DIRECTION_MODE_PORTRAIT;
  }

  private printColorMode(): print.PrintColorMode {
    if (this.colorMode === 1) {
      return print.PrintColorMode.COLOR_MODE_MONOCHROME;
    }
    return print.PrintColorMode.COLOR_MODE_COLOR;
  }

  private printDuplexMode(): print.PrintDuplexMode {
    if (this.duplexMode === 1) {
      return print.PrintDuplexMode.DUPLEX_MODE_LONG_EDGE;
    }
    if (this.duplexMode === 2) {
      return print.PrintDuplexMode.DUPLEX_MODE_SHORT_EDGE;
    }
    return print.PrintDuplexMode.DUPLEX_MODE_NONE;
  }

  private buildPrintAttributes(): print.PrintAttributes {
    let pageRange: print.PrintPageRange = {
      startPage: 1,
      endPage: 1
    };
    let attributes: print.PrintAttributes = {
      copyNumber: this.copyCount(),
      pageRange: pageRange,
      pageSize: this.printPageType(),
      directionMode: this.printDirectionMode(),
      colorMode: this.printColorMode(),
      duplexMode: this.printDuplexMode()
    };
    return attributes;
  }

  private nextPrintFileName(): string {
    return MAP_PRINT_BASE_NAME + '_' + new Date().getTime().toString() + '.pdf';
  }

  private exportPrintPdf(): GisGeoProcessResult {
    let ctx = getContext(this) as common.UIAbilityContext;
    let exportDir = ctx.filesDir + '/geonest_print';
    try {
      fs.mkdirSync(exportDir);
    } catch (e) {
    }
    let fileName = this.nextPrintFileName();
    let outputPath = exportDir + '/' + fileName;
    let result: GisGeoProcessResult = getGisService().exportMapLayout(this.mapTitle, outputPath, 'pdf',
      this.showLegend, this.showScale, this.showNorth, this.showGrid, this.layoutWidth(), this.layoutHeight(),
      '图例', this.scaleLabel(), this.footerLabel(), this.currentBasemapMode(), this.currentBasemapLabel());
    if (result.ok) {
      this.statusText = '已生成打印 PDF：' + fileName;
    } else {
      this.statusText = '打印 PDF 生成失败：' + result.message;
    }
    return result;
  }

  private startSystemPrint(): void {
    if (getGisService().getVisibleLayerCount() === 0) {
      this.statusText = '当前没有可打印图层';
      return;
    }
    this.statusText = '正在生成打印 PDF';
    let result = this.exportPrintPdf();
    if (!result.ok) {
      return;
    }
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let adapter = new GeoNestPrintDocumentAdapter(result.outputPath);
      let attributes = this.buildPrintAttributes();
      print.print(this.mapTitle, adapter, attributes, ctx).then((task: print.PrintTask) => {
        this.statusText = '已调用系统打印面板';
        task.on('succeed', () => {
          this.statusText = '打印任务完成';
        });
        task.on('fail', () => {
          this.statusText = '打印任务失败';
        });
        task.on('cancel', () => {
          this.statusText = '已取消打印';
        });
        task.on('block', () => {
          this.statusText = '打印任务被阻塞';
        });
      }).catch(() => {
        this.statusText = '系统打印调用失败';
      });
    } catch (e) {
      this.statusText = '系统打印调用失败：' + String(e);
    }
  }

  private toggleOption(optionId: number): void {
    if (optionId === 0) {
      this.fitToPaper = !this.fitToPaper;
    } else if (optionId === 1) {
      this.showLegend = !this.showLegend;
    } else if (optionId === 2) {
      this.showScale = !this.showScale;
    } else if (optionId === 3) {
      this.showNorth = !this.showNorth;
    } else if (optionId === 4) {
      this.showGrid = !this.showGrid;
    }
    this.refreshDialogUi();
  }

  private updateChip(mode: number, group: number): void {
    if (group === 0) {
      this.paperMode = mode;
    } else if (group === 1) {
      this.orientationMode = mode;
    } else if (group === 2) {
      this.qualityMode = mode;
    } else if (group === 3) {
      this.colorMode = mode;
    } else if (group === 4) {
      this.duplexMode = mode;
    }
    this.statusText = '已更新打印参数';
    this.refreshDialogUi();
  }

  private previewPaperWidth(): number {
    if (this.orientationMode === 1) {
      return 210;
    }
    return 148;
  }

  private previewPaperHeight(): number {
    if (this.orientationMode === 1) {
      return 148;
    }
    return 210;
  }

  @Builder
  sectionTitle(label: ResourceStr) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.gn_text_primary'))
      .width('100%')
  }

  @Builder
  metaRow(label: ResourceStr, value: string) {
    Row() {
      Text(label)
        .width(72)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
      Text(value)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(25)
  }

  @Builder
  chip(label: ResourceStr, mode: number, group: number) {
    Button(label, { type: ButtonType.Normal, stateEffect: true })
      .height(30)
      .padding({ left: 10, right: 10 })
      .fontSize(12)
      .fontWeight(this.printOptionActive(mode, group) ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.printOptionActive(mode, group) ? $r('app.color.gn_blue_800') :
        $r('app.color.gn_text_muted'))
      .backgroundColor(this.printOptionActive(mode, group) ? $r('app.color.gn_blue_100') : Color.Transparent)
      .borderRadius(5)
      .border({
        width: 1,
        color: this.printOptionActive(mode, group) ? $r('app.color.gn_blue_800') : $r('app.color.gn_line')
      })
      .onClick(() => {
        this.updateChip(mode, group);
      })
  }

  private printOptionActive(mode: number, group: number): boolean {
    if (group === 0) {
      return this.paperMode === mode;
    }
    if (group === 1) {
      return this.orientationMode === mode;
    }
    if (group === 2) {
      return this.qualityMode === mode;
    }
    if (group === 3) {
      return this.colorMode === mode;
    }
    return this.duplexMode === mode;
  }

  @Builder
  checkOption(label: ResourceStr, active: boolean, optionId: number) {
    Row({ space: 6 }) {
      Stack() {
        if (active) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(12)
            .fontColor([Color.White])
        }
      }
      .width(16)
      .height(16)
      .borderRadius(2)
      .backgroundColor(active ? $r('app.color.gn_blue_800') : Color.Transparent)
      .border({ width: 1, color: active ? $r('app.color.gn_blue_800') : $r('app.color.gn_line_strong') })
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(26)
    .onClick(() => {
      this.toggleOption(optionId);
    })
  }

  @Builder
  printerPanel() {
    Column({ space: 6 }) {
      Row() {
        Text($r('app.string.gn_print_printer_settings'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .layoutWeight(1)
        Button($r('app.string.gn_print_settings_button'), { type: ButtonType.Capsule, stateEffect: true })
          .height(26)
          .fontSize(11)
          .backgroundColor($r('app.color.gn_pane'))
          .onClick(() => {
            this.refreshPrinterInfo();
          })
      }
      .width('100%')
      this.metaRow($r('app.string.gn_print_printer_name'), this.printerName)
      this.metaRow($r('app.string.gn_print_printer_status'), this.printerStatus)
      this.metaRow($r('app.string.gn_print_printer_type'), this.printerType)
      this.metaRow($r('app.string.gn_print_printer_location'), this.printerLocation)
    }
    .padding(10)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  paperPanel() {
    Column({ space: 10 }) {
      this.sectionTitle($r('app.string.gn_print_paper'))
      Row({ space: 8 }) {
        this.chip('A3', 0, 0)
        this.chip('A4', 1, 0)
        this.chip('A5', 2, 0)
        this.chip('Letter', 3, 0)
      }
      Row({ space: 8 }) {
        this.chip($r('app.string.gn_print_portrait'), 0, 1)
        this.chip($r('app.string.gn_print_landscape'), 1, 1)
      }
      Text(this.pageDimensionText())
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
      this.checkOption($r('app.string.gn_print_fit_paper'), this.fitToPaper, 0)
    }
    .padding(10)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  printParameterPanel() {
    Column({ space: 10 }) {
      this.sectionTitle($r('app.string.gn_print_output_quality'))
      Row({ space: 8 }) {
        this.chip($r('app.string.gn_print_quality_fast'), 0, 2)
        this.chip($r('app.string.gn_print_quality_normal'), 1, 2)
        this.chip($r('app.string.gn_print_quality_best'), 2, 2)
      }
      Row({ space: 8 }) {
        this.chip($r('app.string.gn_print_color'), 0, 3)
        this.chip($r('app.string.gn_print_monochrome'), 1, 3)
      }
      Row({ space: 8 }) {
        this.chip($r('app.string.gn_print_duplex_single'), 0, 4)
        this.chip($r('app.string.gn_print_duplex_long'), 1, 4)
        this.chip($r('app.string.gn_print_duplex_short'), 2, 4)
      }
      Row({ space: 8 }) {
        Text($r('app.string.gn_print_copies'))
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
        TextInput({ text: this.copyCountText, placeholder: '1' })
          .height(30)
          .width(80)
          .fontSize(12)
          .backgroundColor($r('app.color.gn_pane'))
          .onChange((value: string) => {
            this.copyCountText = value;
            this.refreshDialogUi();
          })
        Text($r('app.string.gn_print_scale_denominator'))
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
        TextInput({ text: this.scaleDenominatorText, placeholder: '8000' })
          .height(30)
          .layoutWeight(1)
          .fontSize(12)
          .backgroundColor($r('app.color.gn_pane'))
          .onChange((value: string) => {
            this.scaleDenominatorText = value;
            this.refreshDialogUi();
          })
      }
    }
    .padding(10)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  mapOptionsPanel() {
    Column({ space: 8 }) {
      this.sectionTitle($r('app.string.gn_print_map_page_size'))
      TextInput({ text: this.mapTitle, placeholder: $r('app.string.gn_print_map_title_placeholder') })
        .height(32)
        .fontSize(12)
        .backgroundColor($r('app.color.gn_pane'))
        .onChange((value: string) => {
          this.mapTitle = value;
          this.refreshDialogUi();
        })
      Row({ space: 12 }) {
        this.checkOption($r('app.string.gn_print_show_legend'), this.showLegend, 1)
        this.checkOption($r('app.string.gn_print_show_scale'), this.showScale, 2)
      }
      Row({ space: 12 }) {
        this.checkOption($r('app.string.gn_print_show_north'), this.showNorth, 3)
        this.checkOption($r('app.string.gn_print_show_grid'), this.showGrid, 4)
      }
    }
    .padding(10)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  printBasemapPreview() {
    Stack() {
      if (this.isPreviewImageryBasemap()) {
        Column() {
          Row() {
            Blank().layoutWeight(1).height(28).backgroundColor('#36464A')
            Blank().layoutWeight(1).height(28).backgroundColor('#253237')
          }
          Row() {
            Blank().layoutWeight(1).height(28).backgroundColor('#44513F')
            Blank().layoutWeight(1).height(28).backgroundColor('#2B3A3E')
          }
          Row() {
            Blank().layoutWeight(1).height(28).backgroundColor('#253237')
            Blank().layoutWeight(1).height(28).backgroundColor('#36464A')
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#2F3B42')
      } else if (this.isPreviewTerrainBasemap()) {
        Column() {
          Blank().height(20)
          Blank().height(1).width('100%').backgroundColor('#C7B98A')
          Blank().height(20)
          Blank().height(1).width('100%').backgroundColor('#AFC4A2')
          Blank().height(20)
          Blank().height(1).width('100%').backgroundColor('#C7B98A')
          Blank().layoutWeight(1).width('100%').backgroundColor('#DDE7C9')
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#F4F1E8')
      } else {
        Column() {
          Blank().layoutWeight(3).width('100%').backgroundColor('#F6FAF7')
          Blank().layoutWeight(1).width('100%').backgroundColor('#DCEFEB')
          Blank().layoutWeight(2).width('100%').backgroundColor('#F6FAF7')
        }
        .width('100%')
        .height('100%')
      }
      Text(this.currentBasemapLabel())
        .fontSize(8)
        .fontColor(this.isPreviewImageryBasemap() ? Color.White : $r('app.color.gn_text_muted'))
        .backgroundColor(this.isPreviewImageryBasemap() ? '#00000066' : '#FFFFFFCC')
        .padding({ left: 5, right: 5, top: 2, bottom: 2 })
        .borderRadius(3)
        .position({ x: 6, y: 6 })
    }
    .height(84)
    .border({ width: 1, color: $r('app.color.gn_line_strong') })
  }

  @Builder
  mapPreviewGraphic() {
    Column({ space: 4 }) {
      Text(this.mapTitle)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      this.printBasemapPreview()
      if (this.showLegend) {
        Text('图例 · ' + getGisService().getVisibleLayerCount().toString() + ' 当前显示图层')
          .fontSize(9)
          .fontColor($r('app.color.gn_text_muted'))
      }
      Row() {
        if (this.showScale) {
          Text(this.scaleLabel())
            .fontSize(9)
            .fontColor($r('app.color.gn_text_muted'))
            .layoutWeight(1)
        } else {
          Blank()
            .layoutWeight(1)
        }
        if (this.showNorth) {
          Text('N')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.gn_blue_800'))
        }
      }
      .height(16)
      if (this.showGrid) {
        Text($r('app.string.gn_print_show_grid'))
          .fontSize(9)
          .fontColor($r('app.color.gn_text_muted'))
      }
    }
    .padding(8)
    .width(this.previewPaperWidth())
    .height(this.previewPaperHeight())
    .backgroundColor(Color.White)
    .border({ width: 1, color: $r('app.color.gn_line_strong') })
  }

  @Builder
  previewPanel() {
    Column({ space: 10 }) {
      this.sectionTitle($r('app.string.gn_print_preview'))
      Row() {
        Blank()
          .layoutWeight(1)
        this.mapPreviewGraphic()
        Blank()
          .layoutWeight(1)
      }
      .height(230)
      .alignItems(VerticalAlign.Center)
      Text(this.paperName() + ' · ' + (this.orientationMode === 1 ? '横向' : '纵向') + ' · ' +
        this.copyCount().toString() + ' 份')
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
      Text('状态：' + this.statusText)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 10 }) {
        Button($r('app.string.gn_print_confirm'), { type: ButtonType.Capsule, stateEffect: true })
          .height(34)
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.gn_blue_800'))
          .layoutWeight(1)
          .onClick(() => {
            this.startSystemPrint();
          })
        Button($r('app.string.gn_print_cancel'), { type: ButtonType.Capsule, stateEffect: true })
          .height(34)
          .fontSize(13)
          .backgroundColor($r('app.color.gn_pane'))
          .layoutWeight(1)
          .onClick(() => {
            this.isShow = false;
          })
      }
      .width('100%')
    }
    .padding(10)
    .width(200)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  sheetContent() {
    Column() {
      HdsNavigation() {
        Row({ space: 12 }) {
          Scroll() {
            Column({ space: 10 }) {
              Blank().height(80).width('100%')
              Text(this.uiRevision.toString())
                .width(0)
                .height(0)
                .fontSize(0)
                .opacity(0)
              this.printerPanel()
              this.paperPanel()
              this.printParameterPanel()
              this.mapOptionsPanel()
            }
          }
          .layoutWeight(1)
          .height('100%')
          .scrollBar(BarState.Auto)
          this.previewPanel()
        }
        .padding(14)
        .layoutWeight(1)
      }
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MODAL)
      .titleBar({
        style: MaterialStyle.isHigh() && this.materialEnabled ? {
          scrollEffectOpts: { scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
          }
        } : undefined,
        content: {
          title: { mainTitle: $r('app.string.gn_print_title') },
          menu: {
            value: [{
              content: {
                label: 'modal_cancel', isEnabled: true,
                type: IconStyleMode.SMALL,
                action: () => { this.isShow = false; }
              }
            }]
          }
        }
      })
    }
    .width('100%').height('100%')
  }

  build() {
    Row().width(0).height(0)
      .bindSheet($$this.isShow, this.sheetContent(), {
        detents: [SheetSize.LARGE],
        preferType: SheetType.CENTER,
        dragBar: false,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.Thin,
        systemMaterial: MaterialStyle.nativeMaterial(this.materialEnabled),
        showClose: false,
        onDisappear: (): void => { this.isShow = false; }
      })
  }
}
