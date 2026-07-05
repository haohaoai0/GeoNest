import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '../utils/MaterialStyle';
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
    this.isShow = true;
  }

  aboutToAppear(): void {
    let layer = getGisService().getActiveLayer();
    if (layer !== undefined) {
      this.bandMode = layer.style.rasterBandMode;
      this.stretchMode = layer.style.rasterStretchMode;
      this.colorRamp = layer.style.rasterColorRamp;
      this.opacityPercent = Math.round(layer.style.rasterOpacity * 100.0);
      this.noDataValue = layer.style.rasterNoData;
      this.transparentColor = layer.style.rasterTransparentColor;
      this.hillshade = layer.style.rasterHillshade;
    }
  }

  private closeDialog(): void {
    this.isShow = false;
  }

  private refreshDialogUi(): void {
    this.uiRevision++;
  }

  private applyRasterConfig(): void {
    let layer = getGisService().getActiveLayer();
    if (layer === undefined) {
      this.statusText = '没有活动图层';
      return;
    }
    let style = layer.style;
    style.rasterBandMode = this.bandMode;
    style.rasterStretchMode = this.stretchMode;
    style.rasterColorRamp = this.colorRamp;
    style.rasterOpacity = this.opacityPercent / 100.0;
    style.rasterNoData = this.noDataValue;
    style.rasterTransparentColor = this.transparentColor;
    style.rasterHillshade = this.hillshade;
    let result = getGisService().updateLayerStyle(getGisService().getActiveLayerIndex(), style);
    if (result.ok) {
      this.statusText = '栅格显示已应用到 QGIS raster renderer';
      this.onRasterDisplayChanged();
    } else {
      this.statusText = '失败：' + result.message;
    }
  }

  @Builder
  chip(label: string, active: boolean, mode: number, group: number) {
    Text(label)
      .height(28)
      .padding({ left: 10, right: 10 })
      .fontSize(12)
      .fontColor(active ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .backgroundColor(active ? $r('app.color.gn_blue_100') : Color.Transparent)
      .borderRadius(4)
      .onClick(() => {
        if (group === 0) {
          this.bandMode = mode;
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
  sheetContent() {
    Column() {
      HdsNavigation() {
        Scroll(this.scroller) {
          Column({ space: 12 }) {
            Blank().height(80).width('100%')
            Text(this.uiRevision.toString())
              .width(0)
              .height(0)
              .fontSize(0)
              .opacity(0)
            Row({ space: 8 }) {
              this.chip('单波段', this.bandMode === 0, 0, 0)
              this.chip('RGB 合成', this.bandMode === 1, 1, 0)
              this.chip('色带渲染', this.bandMode === 2, 2, 0)
            }
            Row({ space: 8 }) {
              this.chip('无拉伸', this.stretchMode === 0, 0, 1)
              this.chip('最小最大', this.stretchMode === 1, 1, 1)
              this.chip('标准差', this.stretchMode === 2, 2, 1)
              this.chip('阴影地形', this.hillshade, 0, 3)
            }
            Row({ space: 8 }) {
              this.chip('蓝绿', this.colorRamp === 0, 0, 2)
              this.chip('暖色', this.colorRamp === 1, 1, 2)
              this.chip('高程', this.colorRamp === 2, 2, 2)
            }
            Row({ space: 8 }) {
              Text('透明度 ' + this.opacityPercent.toString() + '%')
                .fontSize(12)
                .fontColor($r('app.color.gn_text_muted'))
              Slider({ value: this.opacityPercent, min: 0, max: 100, step: 5 })
                .layoutWeight(1)
                .onChange((value: number) => {
                  this.opacityPercent = Math.round(value);
                  this.refreshDialogUi();
                })
            }
            Row({ space: 8 }) {
              TextInput({ text: this.noDataValue, placeholder: 'NoData 值' })
                .height(32)
                .fontSize(12)
                .backgroundColor($r('app.color.gn_pane'))
                .layoutWeight(1)
                .onChange((value: string) => {
                  this.noDataValue = value;
                })
              TextInput({ text: this.transparentColor, placeholder: '透明色 #RRGGBB' })
                .height(32)
                .fontSize(12)
                .backgroundColor($r('app.color.gn_pane'))
                .layoutWeight(1)
                .onChange((value: string) => {
                  this.transparentColor = value;
                })
            }
            Text('状态：' + this.statusText)
              .fontSize(12)
              .fontColor($r('app.color.gn_text_muted'))
              .width('100%')
            Button('应用栅格显示', { type: ButtonType.Capsule, stateEffect: true })
              .height(38)
              .fontSize(14)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.gn_blue_800'))
              .onClick(() => {
                this.applyRasterConfig();
              })
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
      .bindSheet(this.isShow, this.sheetContent(), {
        detents: [SheetSize.LARGE],
        preferType: SheetType.CENTER,
        dragBar: false,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.Thin,
        systemMaterial: MaterialStyle.nativeMaterial(this.materialEnabled),
        showClose: false,
        onDisappear: () => {
          this.isShow = false;
        }
      })
  }
}
