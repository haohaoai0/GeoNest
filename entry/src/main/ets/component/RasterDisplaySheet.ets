import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '@geonest/common';
import { getGisService, GisLoadedLayer } from '../gis/GisService';

@Component
export struct RasterDisplaySheet {
  onRasterDisplayChanged: () => void = () => {};
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  @State private bandMode: number = 0;
  @State private stretchMode: number = 0;
  @State private colorRamp: number = 0;
  @State private opacityPercent: number = 100;
  @State private noDataValue: string = '';
  @State private transparentColor: string = '';
  @State private hillshade: boolean = false;
  @State private statusText: string = '栅格显示配置就绪';
  @State private uiRevision: number = 0;

  onTrigger(): void {
    this.loadActiveRasterStyle();
    this.isShow = true;
  }

  aboutToAppear(): void {
    this.loadActiveRasterStyle();
  }

  private getActiveLayer(): GisLoadedLayer | undefined {
    return getGisService().getActiveLayer();
  }

  private isRasterLayer(layer: GisLoadedLayer): boolean {
    return layer.info.geometryType === 0 && layer.info.fields.length === 0;
  }

  private loadActiveRasterStyle(): void {
    let layer = this.getActiveLayer();
    if (layer !== undefined) {
      this.bandMode = layer.style.rasterBandMode;
      this.stretchMode = layer.style.rasterStretchMode;
      this.colorRamp = layer.style.rasterColorRamp > 1 ? 0 : layer.style.rasterColorRamp;
      this.opacityPercent = Math.round(layer.style.rasterOpacity * 100.0);
      this.noDataValue = layer.style.rasterNoData;
      this.transparentColor = layer.style.rasterTransparentColor;
      this.hillshade = layer.style.rasterHillshade;
      this.statusText = '栅格显示配置就绪';
      this.refreshDialogUi();
    }
  }

  private refreshDialogUi(): void {
    this.uiRevision++;
  }

  private cleanPercent(value: number): number {
    if (value < 0) {
      return 0;
    }
    if (value > 100) {
      return 100;
    }
    return value;
  }

  private applyRasterConfig(): void {
    let layer = this.getActiveLayer();
    if (layer === undefined) {
      this.statusText = '没有活动图层';
      return;
    }
    if (!this.isRasterLayer(layer)) {
      this.statusText = '当前图层不是栅格图层';
      return;
    }
    let style = layer.style;
    style.rasterBandMode = this.bandMode;
    style.rasterStretchMode = this.stretchMode;
    style.rasterColorRamp = this.colorRamp;
    style.rasterOpacity = this.cleanPercent(this.opacityPercent) / 100.0;
    style.rasterNoData = this.noDataValue.trim();
    style.rasterTransparentColor = this.transparentColor.trim();
    style.rasterHillshade = this.hillshade;
    let result = getGisService().updateLayerStyle(getGisService().getActiveLayerIndex(), style);
    if (result.ok) {
      this.statusText = '栅格显示已应用到 QGIS raster renderer';
      this.onRasterDisplayChanged();
      this.refreshDialogUi();
    } else {
      this.statusText = '失败：' + result.message;
    }
  }

  private rendererName(): string {
    if (this.hillshade) {
      return '阴影地形';
    }
    if (this.bandMode === 1) {
      return 'RGB 多波段合成';
    }
    return '单波段灰度';
  }

  private bandModeDetail(): string {
    if (this.hillshade) {
      return '使用第 1 波段生成 QgsHillshadeRenderer';
    }
    if (this.bandMode === 1) {
      return '使用 1/2/3 波段生成 RGB，波段不足时回退灰度';
    }
    return '使用第 1 波段生成灰度渲染';
  }

  private stretchName(): string {
    if (this.stretchMode === 1) {
      return '最小最大拉伸';
    }
    if (this.stretchMode === 2) {
      return '标准差拉伸';
    }
    return '无拉伸';
  }

  private colorRampName(): string {
    if (this.colorRamp === 1) {
      return '白到黑';
    }
    return '黑到白';
  }

  private noDataText(): string {
    if (this.noDataValue.trim().length === 0) {
      return '未设置';
    }
    return this.noDataValue.trim();
  }

  private transparentColorText(): string {
    if (this.transparentColor.trim().length === 0) {
      return '未设置';
    }
    return this.transparentColor.trim();
  }

  private extentText(layer: GisLoadedLayer): string {
    return layer.info.envelope.minX.toFixed(2) + ', ' + layer.info.envelope.minY.toFixed(2) + ' - ' +
      layer.info.envelope.maxX.toFixed(2) + ', ' + layer.info.envelope.maxY.toFixed(2);
  }

  private referenceText(layer: GisLoadedLayer): string {
    if (layer.info.crsFriendlyName.length > 0) {
      return layer.info.crsFriendlyName;
    }
    if (layer.info.crsDescription.length > 0) {
      return layer.info.crsDescription;
    }
    if (layer.info.crs.length > 0) {
      return layer.info.crs;
    }
    return 'CRS 未声明';
  }

  private previewKey(layer: GisLoadedLayer): string {
    return layer.info.layerId + ':' + this.uiRevision.toString() + ':' + this.bandMode.toString() + ':' +
      this.stretchMode.toString() + ':' + this.colorRamp.toString() + ':' + this.opacityPercent.toString() + ':' +
      this.noDataValue + ':' + this.transparentColor + ':' + this.hillshade.toString();
  }

  @Builder
  panelTitle(title: string, desc: string) {
    Column({ space: 3 }) {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
      Text(desc)
        .fontSize(11)
        .fontColor($r('app.color.gn_text_muted'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.gn_text_muted'))
        .width(86)
      Text(value)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(24)
    .width('100%')
  }

  @Builder
  modeChip(label: string, active: boolean, mode: number, group: number) {
    Row({ space: 6 }) {
      SymbolGlyph(active ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.circle'))
        .fontSize(14)
        .fontColor([active ? $r('app.color.gn_blue_800') : $r('sys.color.icon_secondary')])
      Text(label)
        .fontSize(12)
        .fontColor(active ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(30)
    .padding({ left: 10, right: 10 })
    .backgroundColor(active ? $r('app.color.gn_blue_100') : Color.Transparent)
    .border({ width: 1, color: active ? $r('app.color.gn_blue_800') : $r('app.color.gn_line') })
    .borderRadius(5)
    .onClick(() => {
      if (group === 0) {
        this.bandMode = mode;
        this.hillshade = false;
      } else if (group === 1) {
        this.stretchMode = mode;
      } else if (group === 2) {
        this.colorRamp = mode;
      } else {
        this.hillshade = !this.hillshade;
      }
      this.refreshDialogUi();
    })
  }

  @Builder
  previewBand(colorValue: ResourceColor, weightValue: number) {
    Blank()
      .height('100%')
      .layoutWeight(weightValue)
      .backgroundColor(colorValue)
  }

  @Builder
  rasterPreview(layer: GisLoadedLayer) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.satellite_map'))
          .fontSize(28)
          .fontColor([$r('app.color.gn_blue_800')])
        Column() {
          Text(this.rendererName())
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.gn_text_primary'))
          Text(layer.info.name)
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
            .margin({ top: 3 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(this.opacityPercent.toString() + '%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_blue_800'))
      }
      Row() {
        if (this.hillshade) {
          this.previewBand($r('app.color.gn_text_muted'), 1)
          this.previewBand($r('app.color.gn_pane'), 1)
          this.previewBand($r('app.color.gn_text_primary'), 1)
        } else if (this.bandMode === 1) {
          this.previewBand('#C94535', 1)
          this.previewBand('#3D8F5A', 1)
          this.previewBand('#2563A8', 1)
        } else if (this.colorRamp === 1) {
          this.previewBand($r('app.color.gn_paper'), 1)
          this.previewBand($r('app.color.gn_text_muted'), 1)
          this.previewBand($r('app.color.gn_text_primary'), 1)
        } else {
          this.previewBand($r('app.color.gn_text_primary'), 1)
          this.previewBand($r('app.color.gn_text_muted'), 1)
          this.previewBand($r('app.color.gn_paper'), 1)
        }
      }
      .width('100%')
      .height(84)
      .borderRadius(6)
      .clip(true)
      this.infoRow('拉伸', this.stretchName())
      this.infoRow('色带', this.colorRampName())
    }
    .width('100%')
    .padding(14)
    .borderRadius(7)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  overviewPanel(layer: GisLoadedLayer) {
    Column({ space: 10 }) {
      this.panelTitle('栅格图层', '当前 QGIS raster layer')
      this.rasterPreview(layer)
      Column({ space: 6 }) {
        this.infoRow('范围', this.extentText(layer))
        this.infoRow('坐标系', this.referenceText(layer))
        this.infoRow('NoData', this.noDataText())
        this.infoRow('透明色', this.transparentColorText())
      }
      .width('100%')
      .padding(10)
      .borderRadius(6)
      .backgroundColor($r('app.color.gn_pane'))
    }
    .width(250)
    .padding(12)
    .borderRadius(7)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  rendererPanel() {
    Column({ space: 10 }) {
      this.panelTitle('渲染器', '选择单波段灰度、RGB 合成或阴影地形')
      Row({ space: 8 }) {
        this.modeChip('单波段灰度', !this.hillshade && this.bandMode === 0, 0, 0)
        this.modeChip('RGB 合成', !this.hillshade && this.bandMode === 1, 1, 0)
        this.modeChip('阴影地形', this.hillshade, 0, 3)
      }
      .width('100%')
      Column({ space: 6 }) {
        this.infoRow('当前渲染器', this.rendererName())
        this.infoRow('波段说明', this.bandModeDetail())
        this.infoRow('阴影参数', this.hillshade ? '方位 315 · 高度 45' : '未启用')
      }
      .width('100%')
      .padding(10)
      .borderRadius(6)
      .backgroundColor($r('app.color.gn_pane'))
    }
    .width('100%')
    .padding(12)
    .borderRadius(7)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  stretchPanel() {
    Column({ space: 10 }) {
      this.panelTitle('拉伸与色带', '控制对比度增强和灰度方向')
      Row({ space: 8 }) {
        this.modeChip('无拉伸', this.stretchMode === 0, 0, 1)
        this.modeChip('最小最大', this.stretchMode === 1, 1, 1)
        this.modeChip('标准差', this.stretchMode === 2, 2, 1)
      }
      .width('100%')
      Row({ space: 8 }) {
        this.modeChip('黑到白', this.colorRamp === 0, 0, 2)
        this.modeChip('白到黑', this.colorRamp === 1, 1, 2)
      }
      .width('100%')
      this.infoRow('当前设置', this.stretchName() + ' · ' + this.colorRampName())
    }
    .width('100%')
    .padding(12)
    .borderRadius(7)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  transparencyPanel() {
    Column({ space: 10 }) {
      this.panelTitle('透明度与 NoData', '设置图层不透明度、用户 NoData 和透明色')
      Row({ space: 10 }) {
        Text('透明度')
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
          .width(58)
        Slider({ value: this.opacityPercent, min: 0, max: 100, step: 5 })
          .layoutWeight(1)
          .onChange((value: number) => {
            this.opacityPercent = Math.round(value);
            this.refreshDialogUi();
          })
        Text(this.opacityPercent.toString() + '%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_blue_800'))
          .width(42)
      }
      .width('100%')
      Row({ space: 8 }) {
        TextInput({ text: this.noDataValue, placeholder: 'NoData 值，例如 -9999' })
          .height(34)
          .fontSize(12)
          .backgroundColor($r('app.color.gn_pane'))
          .layoutWeight(1)
          .onChange((value: string) => {
            this.noDataValue = value;
            this.refreshDialogUi();
          })
        TextInput({ text: this.transparentColor, placeholder: '透明色 #RRGGBB' })
          .height(34)
          .fontSize(12)
          .backgroundColor($r('app.color.gn_pane'))
          .layoutWeight(1)
          .onChange((value: string) => {
            this.transparentColor = value;
            this.refreshDialogUi();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .borderRadius(7)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  actionPanel() {
    Row({ space: 8 }) {
      Text('状态：' + this.statusText)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Button('应用栅格显示', { type: ButtonType.Capsule, stateEffect: true })
        .width(158)
        .height(38)
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.gn_blue_800'))
        .onClick(() => {
          this.applyRasterConfig();
        })
    }
    .width('100%')
    .padding(12)
    .borderRadius(7)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  rasterWorkspace(layer: GisLoadedLayer) {
    Column({ space: 12 }) {
      Text(this.previewKey(layer))
        .width(0)
        .height(0)
        .fontSize(0)
        .opacity(0)
      Row({ space: 12 }) {
        this.overviewPanel(layer)
        Column({ space: 12 }) {
          this.rendererPanel()
          this.stretchPanel()
          this.transparencyPanel()
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      this.actionPanel()
    }
    .width('100%')
  }

  @Builder
  emptyState(message: string, detail: string) {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.satellite_map'))
        .fontSize(34)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(message)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
      Text(detail)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(420)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  sheetContent() {
    Column() {
      HdsNavigation() {
        Scroll(this.scroller) {
          Column({ space: 12 }) {
            Blank().height(80).width('100%')
            if (this.getActiveLayer() === undefined) {
              this.emptyState('当前没有已加载图层', '先添加一个 GeoTIFF、MBTiles 或其他 GDAL 栅格数据。')
            } else if (!this.isRasterLayer(this.getActiveLayer() as GisLoadedLayer)) {
              this.emptyState('当前不是栅格图层', '请在内容或目录面板中选择一个栅格图层后再打开栅格显示。')
            } else {
              this.rasterWorkspace(this.getActiveLayer() as GisLoadedLayer)
            }
          }
          .padding(14)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
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
          title: { mainTitle: '栅格显示' },
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
  }

  build() {
    Column()
      .bindSheet($$this.isShow, this.sheetContent(), {
        width: 900,
        height: 690,
        detents: [690],
        preferType: SheetType.CENTER,
        dragBar: false,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.Regular,
        showClose: false,
        onDisappear: () => {
          this.isShow = false;
        }
      })
  }
}
