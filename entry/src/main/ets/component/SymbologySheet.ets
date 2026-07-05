import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '../utils/MaterialStyle';
import { getGisService, GisLayerStyle, GisLoadedLayer, qgisCategoryTotal, qgisRampColor } from '../gis/GisService';
import { GisFieldInfo } from '../model/GeoNestModels';

@Component
export struct SymbologySheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  onStyleChanged: () => void = () => {};
  @State private rendererMode: number = 0;
  @State private rendererField: string = '';
  @State private colorRamp: number = 0;
  @State private pointColor: string = '#BD6B16';
  @State private lineColor: string = '#5B8DB8';
  @State private fillColor: string = '#B8D7C9';
  @State private strokeColor: string = '#4A8B6F';
  @State private labelColor: string = '#17201D';
  @State private activeColorFieldIndex: number = 2;
  @State private lineWidthText: string = '2.5';
  @State private pointRadiusText: string = '6';
  @State private opacityPercent: number = 100;
  @State private symbolName: string = '默认符号';
  @State private statusText: string = '样式就绪';
  @State private uiRevision: number = 0;

  onTrigger(): void {
    this.isShow = true;
  }

  aboutToAppear(): void {
    let layer = this.getActiveLayer();
    if (layer !== undefined) {
      this.rendererMode = layer.style.rendererMode;
      this.rendererField = layer.style.rendererField;
      this.colorRamp = layer.style.colorRamp;
      this.pointColor = layer.style.pointColor;
      this.lineColor = layer.style.lineColor;
      this.fillColor = layer.style.fillColor;
      this.strokeColor = layer.style.strokeColor;
      this.labelColor = layer.style.labelColor;
      this.activeColorFieldIndex = this.defaultColorFieldIndex(layer.info.geometryType);
      this.lineWidthText = layer.style.lineWidth.toString();
      this.pointRadiusText = layer.style.pointRadius.toString();
      this.opacityPercent = Math.round(layer.style.opacity * 100.0);
      this.symbolName = layer.style.symbolName;
    }
  }

  private refreshDialogUi(): void {
    this.uiRevision++;
  }

  private getActiveLayer(): GisLoadedLayer | undefined {
    return getGisService().getActiveLayer();
  }

  private geometryTypeName(geometryType: number): string {
    if (geometryType === 1) {
      return '点';
    }
    if (geometryType === 2) {
      return '线';
    }
    if (geometryType === 3) {
      return '面';
    }
    return '未知';
  }

  private rendererModeName(): string {
    if (this.rendererMode === 1) {
      return '分类渲染';
    }
    if (this.rendererMode === 2) {
      return '分级渲染';
    }
    return '单一符号';
  }

  private rampName(): string {
    if (this.colorRamp === 1) {
      return '暖色带';
    }
    if (this.colorRamp === 2) {
      return '综合色带';
    }
    return '蓝绿色带';
  }

  private crsText(layer: GisLoadedLayer): string {
    if (layer.info.crs.length > 0) {
      return layer.info.crs;
    }
    return 'CRS 未声明';
  }

  private normalizePercent(value: number): number {
    if (value < 0) {
      return 0;
    }
    if (value > 100) {
      return 100;
    }
    return value;
  }

  private paletteColors(): string[] {
    return [
      '#111827', '#374151', '#6B7280', '#9CA3AF', '#D1D5DB', '#F9FAFB',
      '#7F1D1D', '#991B1B', '#DC2626', '#EF4444', '#FCA5A5', '#FEE2E2',
      '#7C2D12', '#C2410C', '#EA580C', '#F97316', '#FDBA74', '#FFEDD5',
      '#78350F', '#B45309', '#D97706', '#F59E0B', '#FCD34D', '#FEF3C7',
      '#365314', '#4D7C0F', '#65A30D', '#84CC16', '#BEF264', '#ECFCCB',
      '#14532D', '#15803D', '#16A34A', '#22C55E', '#86EFAC', '#DCFCE7',
      '#134E4A', '#0F766E', '#14B8A6', '#2DD4BF', '#99F6E4', '#CCFBF1',
      '#164E63', '#0891B2', '#06B6D4', '#22D3EE', '#A5F3FC', '#CFFAFE',
      '#1E3A8A', '#1D4ED8', '#2563EB', '#3B82F6', '#93C5FD', '#DBEAFE',
      '#312E81', '#4338CA', '#4F46E5', '#6366F1', '#A5B4FC', '#E0E7FF',
      '#581C87', '#7E22CE', '#9333EA', '#A855F7', '#D8B4FE', '#F3E8FF',
      '#831843', '#BE185D', '#DB2777', '#EC4899', '#F9A8D4', '#FCE7F3',
      '#3F2A1D', '#6B4423', '#8B5E34', '#A47148', '#D6AD8F', '#F3E3D3'
    ];
  }

  private defaultColorFieldIndex(geometryType: number): number {
    if (geometryType === 1) {
      return 0;
    }
    if (geometryType === 2) {
      return 1;
    }
    return 2;
  }

  private normalizeColorText(value: string): string {
    let trimmed = value.trim();
    if (trimmed.length === 0) {
      return value;
    }
    return trimmed.toUpperCase();
  }

  private setSymbolColor(fieldIndex: number, colorValue: string): void {
    let normalized = this.normalizeColorText(colorValue);
    if (fieldIndex === 0) {
      this.pointColor = normalized;
    } else if (fieldIndex === 1) {
      this.lineColor = normalized;
    } else if (fieldIndex === 2) {
      this.fillColor = normalized;
    } else if (fieldIndex === 3) {
      this.strokeColor = normalized;
    } else {
      this.labelColor = normalized;
    }
    this.refreshDialogUi();
  }

  private isSameColor(left: string, right: string): boolean {
    return this.normalizeColorText(left) === this.normalizeColorText(right);
  }

  private colorFieldValue(fieldIndex: number): string {
    if (fieldIndex === 0) {
      return this.pointColor;
    }
    if (fieldIndex === 1) {
      return this.lineColor;
    }
    if (fieldIndex === 2) {
      return this.fillColor;
    }
    if (fieldIndex === 3) {
      return this.strokeColor;
    }
    return this.labelColor;
  }

  private colorFieldDetail(fieldIndex: number): string {
    if (fieldIndex === 0) {
      return '点符号颜色';
    }
    if (fieldIndex === 1) {
      return '线符号颜色';
    }
    if (fieldIndex === 2) {
      return '面填充颜色';
    }
    if (fieldIndex === 3) {
      return '面边界和描边颜色';
    }
    return '标注文字颜色';
  }

  private activeColorValue(): string {
    return this.colorFieldValue(this.activeColorFieldIndex);
  }

  private applySymbology(): void {
    let layer = this.getActiveLayer();
    if (layer === undefined) {
      this.statusText = '没有活动图层';
      return;
    }
    let style: GisLayerStyle = layer.style;
    style.rendererMode = this.rendererMode;
    style.rendererField = this.rendererField;
    style.colorRamp = this.colorRamp;
    style.pointColor = this.pointColor;
    style.lineColor = this.lineColor;
    style.fillColor = this.fillColor;
    style.strokeColor = this.strokeColor;
    style.labelColor = this.labelColor;
    style.lineWidth = Number(this.lineWidthText);
    style.pointRadius = Number(this.pointRadiusText);
    style.opacity = this.normalizePercent(this.opacityPercent) / 100.0;
    style.symbolName = this.symbolName;
    let result = getGisService().updateLayerStyle(getGisService().getActiveLayerIndex(), style);
    if (result.ok) {
      this.statusText = '已应用：' + this.rendererModeName() + ' · ' + this.rampName();
      this.onStyleChanged();
    } else {
      this.statusText = '失败：' + result.message;
    }
  }

  @Builder
  colorSwatch(colorValue: string) {
    Text('')
      .width(54)
      .height(24)
      .borderRadius(4)
      .backgroundColor(colorValue)
      .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  paletteColorButton(colorValue: string, selected: boolean) {
    Text('')
      .width(24)
      .height(24)
      .borderRadius(4)
      .backgroundColor(colorValue)
      .border({
        width: selected ? 2 : 1,
        color: selected ? $r('app.color.gn_blue_800') : $r('app.color.gn_line')
      })
      .margin({ right: 6, bottom: 6 })
      .onClick(() => {
        this.setSymbolColor(this.activeColorFieldIndex, colorValue);
      })
  }

  @Builder
  colorPalette() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.paletteColors(), (colorValue: string) => {
        this.paletteColorButton(colorValue, this.isSameColor(this.activeColorValue(), colorValue))
      }, (colorValue: string) => 'sym-palette:' + this.activeColorFieldIndex.toString() + ':' + colorValue)
    }
    .width('100%')
  }

  @Builder
  colorTargetRow(label: string, fieldIndex: number) {
    Row({ space: 8 }) {
      this.colorSwatch(this.colorFieldValue(fieldIndex))
      Column() {
        Text(label)
          .fontSize(12)
          .fontWeight(this.activeColorFieldIndex === fieldIndex ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.activeColorFieldIndex === fieldIndex ? $r('app.color.gn_blue_800') :
            $r('app.color.gn_text_primary'))
          .width('100%')
        Text(this.colorFieldDetail(fieldIndex))
          .fontSize(10)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      TextInput({ text: this.colorFieldValue(fieldIndex) })
        .height(30)
        .width(108)
        .fontSize(11)
        .backgroundColor($r('app.color.gn_pane'))
        .onChange((textValue: string) => {
          this.activeColorFieldIndex = fieldIndex;
          this.setSymbolColor(fieldIndex, textValue);
        })
    }
    .height(46)
    .padding({ left: 8, right: 8 })
    .backgroundColor(this.activeColorFieldIndex === fieldIndex ? $r('app.color.gn_blue_100') :
      $r('app.color.gn_pane'))
    .borderRadius(6)
    .border({
      width: 1,
      color: this.activeColorFieldIndex === fieldIndex ? $r('app.color.gn_blue_800') : $r('app.color.gn_line')
    })
    .onClick(() => {
      this.activeColorFieldIndex = fieldIndex;
      this.refreshDialogUi();
    })
  }

  @Builder
  modeChip(label: string, mode: number) {
    Text(label)
      .height(28)
      .padding({ left: 10, right: 10 })
      .fontSize(12)
      .fontWeight(this.rendererMode === mode ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.rendererMode === mode ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .backgroundColor(this.rendererMode === mode ? $r('app.color.gn_blue_100') : Color.Transparent)
      .borderRadius(4)
      .onClick(() => {
        this.rendererMode = mode;
        this.refreshDialogUi();
      })
  }

  @Builder
  rampChip(label: string, ramp: number) {
    Text(label)
      .height(28)
      .padding({ left: 10, right: 10 })
      .fontSize(12)
      .fontWeight(this.colorRamp === ramp ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.colorRamp === ramp ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .backgroundColor(this.colorRamp === ramp ? $r('app.color.gn_blue_100') : Color.Transparent)
      .borderRadius(4)
      .onClick(() => {
        this.colorRamp = ramp;
        this.refreshDialogUi();
      })
  }

  @Builder
  fieldChip(field: GisFieldInfo) {
    Text(field.name)
      .height(26)
      .padding({ left: 9, right: 9 })
      .fontSize(12)
      .fontWeight(this.rendererField === field.name ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.rendererField === field.name ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .backgroundColor(this.rendererField === field.name ? $r('app.color.gn_blue_100') : $r('app.color.gn_pane'))
      .borderRadius(4)
      .margin({ right: 6, bottom: 6 })
      .onClick(() => {
        this.rendererField = field.name;
        this.refreshDialogUi();
      })
  }

  @Builder
  colorStylePanel() {
    Column({ space: 8 }) {
      Text('颜色样式')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
      if ((this.getActiveLayer() as GisLoadedLayer).info.geometryType === 1) {
        this.colorTargetRow('点符号', 0)
      } else if ((this.getActiveLayer() as GisLoadedLayer).info.geometryType === 2) {
        this.colorTargetRow('线符号', 1)
      } else {
        this.colorTargetRow('面填充', 2)
        this.colorTargetRow('面边界', 3)
      }
      this.colorTargetRow('标注文字', 4)
      Text('调色盘：' + this.colorFieldDetail(this.activeColorFieldIndex))
        .width('100%')
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .margin({ top: 4 })
      this.colorPalette()
    }
    .width('100%')
  }

  @Builder
  styleControlsPanel(layer: GisLoadedLayer) {
    Column({ space: 14 }) {
      Column({ space: 9 }) {
        Text('渲染方式')
          .width('100%')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
        Text('先选择渲染方式，再选择用于分类或分级的字段。')
          .width('100%')
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
        Row({ space: 8 }) {
          this.modeChip('单一符号', 0)
          this.modeChip('分类渲染', 1)
          this.modeChip('分级渲染', 2)
          Blank()
          Text(this.rampName())
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
        }
        .height(32)
        if (this.rendererMode !== 0) {
          Text('渲染字段')
            .width('100%')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(layer.info.fields, (field: GisFieldInfo) => {
              this.fieldChip(field)
            }, (field: GisFieldInfo) => 'sym-field:' + field.name)
          }
          Text('色带')
            .width('100%')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
          Row({ space: 8 }) {
            this.rampChip('蓝绿', 0)
            this.rampChip('暖色', 1)
            this.rampChip('综合', 2)
            Blank()
          }
        }
      }
      .padding(14)
      .borderRadius(7)
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })

      Column({ space: 12 }) {
        this.colorStylePanel()
        Row({ space: 10 }) {
          if (layer.info.geometryType === 1) {
            Column({ space: 5 }) {
              Text('点半径')
                .fontSize(11)
                .fontColor($r('app.color.gn_text_muted'))
                .width('100%')
              TextInput({ text: this.pointRadiusText, placeholder: '点半径' })
                .height(34)
                .fontSize(12)
                .backgroundColor($r('app.color.gn_pane'))
                .onChange((value: string) => {
                  this.pointRadiusText = value;
                  this.refreshDialogUi();
                })
            }
            .layoutWeight(1)
          } else {
            Column({ space: 5 }) {
              Text('线宽')
                .fontSize(11)
                .fontColor($r('app.color.gn_text_muted'))
                .width('100%')
              TextInput({ text: this.lineWidthText, placeholder: '线宽' })
                .height(34)
                .fontSize(12)
                .backgroundColor($r('app.color.gn_pane'))
                .onChange((value: string) => {
                  this.lineWidthText = value;
                  this.refreshDialogUi();
                })
            }
            .layoutWeight(1)
          }
          Column({ space: 5 }) {
            Text('符号名称')
              .fontSize(11)
              .fontColor($r('app.color.gn_text_muted'))
              .width('100%')
            TextInput({ text: this.symbolName, placeholder: '符号库名称' })
              .height(34)
              .fontSize(12)
              .backgroundColor($r('app.color.gn_pane'))
              .onChange((value: string) => {
                this.symbolName = value;
                this.refreshDialogUi();
              })
          }
          .layoutWeight(2)
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
      }
      .padding(14)
      .borderRadius(7)
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
    }
  }

  @Builder
  symbolRow(label: string, colorValue: string, detail: string) {
    Row({ space: 12 }) {
      this.colorSwatch(colorValue)
      Column() {
        Text(label)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
        Text(detail)
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .height(48)
  }

  private activeRampTotal(layer: GisLoadedLayer): number {
    if (this.rendererMode === 1) {
      return qgisCategoryTotal(layer, this.rendererField);
    }
    if (this.rendererMode === 2) {
      return 5;
    }
    return 1;
  }

  private previewSymbolColor(layer: GisLoadedLayer): string {
    if (this.rendererMode === 1 || this.rendererMode === 2) {
      return qgisRampColor(this.colorRamp, 0, this.activeRampTotal(layer));
    }
    if (layer.info.geometryType === 1) {
      return this.pointColor;
    }
    if (layer.info.geometryType === 2) {
      return this.lineColor;
    }
    return this.fillColor;
  }

  private previewSymbolLabel(layer: GisLoadedLayer): string {
    if (this.rendererMode === 1 || this.rendererMode === 2) {
      return 'QGIS 色带';
    }
    if (layer.info.geometryType === 1) {
      return '点符号';
    }
    if (layer.info.geometryType === 2) {
      return '线符号';
    }
    return '面填充';
  }

  private previewSymbolDetail(layer: GisLoadedLayer): string {
    if (this.rendererMode === 1 || this.rendererMode === 2) {
      let fieldName = this.rendererField.length > 0 ? this.rendererField : '未选择字段';
      return this.rendererModeName() + ' · ' + fieldName;
    }
    if (layer.info.geometryType === 1) {
      return '半径 ' + this.pointRadiusText + ' px';
    }
    if (layer.info.geometryType === 2) {
      return '线宽 ' + this.lineWidthText + ' px';
    }
    return this.rendererModeName();
  }

  @Builder
  symbolPanel(layer: GisLoadedLayer) {
    Column({ space: 12 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.paintpalette'))
          .fontSize(30)
          .fontColor([$r('app.color.gn_blue_800')])
          .margin({ right: 12 })
        Column() {
          Text(layer.info.name)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.gn_text_primary'))
          Text(this.geometryTypeName(layer.info.geometryType) + '图层 · ' + this.crsText(layer))
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }

      this.symbolRow(this.previewSymbolLabel(layer), this.previewSymbolColor(layer), this.previewSymbolDetail(layer))
      if (layer.info.geometryType === 3) {
        this.symbolRow('边界线', this.strokeColor, '线宽 ' + this.lineWidthText + ' px')
      }
    }
    .padding(14)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  sheetContent() {
    Column() {
      HdsNavigation() {
        Scroll(this.scroller) {
          Column({ space: 12 }) {
            Blank().height(80).width('100%')
            if (this.getActiveLayer() === undefined) {
              Column({ space: 8 }) {
                Text('当前没有已加载图层')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.gn_text_primary'))
                Text('先选择一个图层，再打开符号系统。')
                  .fontSize(12)
                  .fontColor($r('app.color.gn_text_muted'))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            } else {
              Text(this.uiRevision.toString())
                .width(0)
                .height(0)
                .fontSize(0)
                .opacity(0)
              
              Column({ space: 12 }) {
                this.symbolPanel(this.getActiveLayer() as GisLoadedLayer)
                this.styleControlsPanel(this.getActiveLayer() as GisLoadedLayer)
                Column({ space: 8 }) {
                  Text('状态：' + this.statusText)
                    .fontSize(12)
                    .fontColor($r('app.color.gn_text_muted'))
                    .width('100%')
                  Button('应用样式', { type: ButtonType.Capsule, stateEffect: true })
                    .width('100%')
                    .height(40)
                    .fontSize(14)
                    .fontColor(Color.White)
                    .backgroundColor($r('app.color.gn_blue_800'))
                    .onClick(() => {
                      this.applySymbology();
                    })
                }
                .padding(12)
                .borderRadius(7)
                .backgroundColor($r('app.color.gn_paper'))
                .border({ width: 1, color: $r('app.color.gn_line') })
              }
              .width('100%')
            }
          }
          .padding(14)
        }.width('100%').height('100%')
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
          title: { mainTitle: $r('app.string.gn_symbology') },
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

@Component
export struct LabelingSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  onLabelingChanged: () => void = () => {};
  @State private labelEnabled: boolean = false;
  @State private labelField: string = '';
  @State private labelSizeText: string = '12';
  @State private labelColor: string = '#17201D';
  @State private halo: boolean = true;
  @State private avoidance: boolean = true;
  @State private minScaleText: string = '0';
  @State private maxScaleText: string = '0';
  @State private statusText: string = '标注就绪';
  @State private uiRevision: number = 0;
  @State private labelToggleTouched: boolean = false;

  onTrigger(): void {
    this.isShow = true;
  }

  aboutToAppear(): void {
    let layer = getGisService().getActiveLayer();
    this.labelToggleTouched = false;
    if (layer !== undefined) {
      this.labelEnabled = layer.style.labelEnabled;
      this.labelField = layer.style.labelField;
      this.labelSizeText = layer.style.labelSize.toString();
      this.labelColor = layer.style.labelColor;
      this.halo = layer.style.labelHalo;
      this.avoidance = layer.style.labelAvoidance;
      this.minScaleText = layer.style.labelMinScale.toString();
      this.maxScaleText = layer.style.labelMaxScale.toString();
    }
  }

  private refreshDialogUi(): void {
    this.uiRevision++;
  }

  private activeFieldName(): string {
    if (this.labelField.length > 0) {
      return this.labelField;
    }
    let layer = getGisService().getActiveLayer();
    if (layer !== undefined && layer.info.fields.length > 0) {
      return layer.info.fields[0].name;
    }
    return '';
  }

  private safeNumberText(text: string, fallback: number, minValue: number, maxValue: number): number {
    let value = Number(text);
    if (value !== value) {
      return fallback;
    }
    if (value < minValue) {
      return minValue;
    }
    if (value > maxValue) {
      return maxValue;
    }
    return value;
  }

  private applyLabeling(): void {
    let layer = getGisService().getActiveLayer();
    if (layer === undefined) {
      this.statusText = '没有活动图层';
      return;
    }
    let activeField = this.activeFieldName();
    let shouldEnable = this.labelEnabled;
    if (!this.labelToggleTouched && activeField.length > 0) {
      shouldEnable = true;
      this.labelEnabled = true;
    }
    if (shouldEnable && activeField.length === 0) {
      this.statusText = '没有可用标注字段';
      return;
    }
    let style = layer.style;
    style.labelEnabled = shouldEnable;
    style.labelField = activeField;
    style.labelSize = this.safeNumberText(this.labelSizeText, layer.style.labelSize, 8, 48);
    style.labelColor = this.labelColor;
    style.labelHalo = this.halo;
    style.labelAvoidance = this.avoidance;
    style.labelMinScale = this.safeNumberText(this.minScaleText, 0, 0, 1000000000);
    style.labelMaxScale = this.safeNumberText(this.maxScaleText, 0, 0, 1000000000);
    let result = getGisService().updateLayerStyle(getGisService().getActiveLayerIndex(), style);
    if (result.ok) {
      this.statusText = shouldEnable ? '标注已应用：' + activeField : '标注已关闭';
      this.onLabelingChanged();
    } else {
      this.statusText = '失败：' + result.message;
    }
  }

  @Builder
  fieldChip(field: GisFieldInfo) {
    Text(field.name)
      .height(26)
      .padding({ left: 9, right: 9 })
      .fontSize(12)
      .fontColor(this.activeFieldName() === field.name ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .backgroundColor(this.activeFieldName() === field.name ? $r('app.color.gn_blue_100') : $r('app.color.gn_pane'))
      .borderRadius(4)
      .margin({ right: 6, bottom: 6 })
      .onClick(() => {
        this.labelField = field.name;
        this.labelEnabled = true;
        this.labelToggleTouched = true;
        this.refreshDialogUi();
      })
  }

  @Builder
  toggleChip(label: string, active: boolean, mode: number) {
    Text(label)
      .height(28)
      .padding({ left: 10, right: 10 })
      .fontSize(12)
      .fontColor(active ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .backgroundColor(active ? $r('app.color.gn_blue_100') : Color.Transparent)
      .borderRadius(4)
      .onClick(() => {
        if (mode === 0) {
          this.labelEnabled = !this.labelEnabled;
          this.labelToggleTouched = true;
        } else if (mode === 1) {
          this.halo = !this.halo;
        } else {
          this.avoidance = !this.avoidance;
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
            if (getGisService().getActiveLayer() === undefined) {
              Text('当前没有已加载图层')
                .fontSize(16)
                .fontColor($r('app.color.gn_text_primary'))
            } else {
              Text(this.uiRevision.toString())
                .width(0)
                .height(0)
                .fontSize(0)
                .opacity(0)
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach((getGisService().getActiveLayer() as GisLoadedLayer).info.fields, (field: GisFieldInfo) => {
                  this.fieldChip(field)
                }, (field: GisFieldInfo) => 'label-field:' + field.name)
              }
              Row({ space: 8 }) {
                this.toggleChip(this.labelEnabled ? '标注开' : '标注关', this.labelEnabled, 0)
                this.toggleChip('描边', this.halo, 1)
                this.toggleChip('避让', this.avoidance, 2)
                TextInput({ text: this.labelSizeText, placeholder: '字号' })
                  .height(30)
                  .fontSize(12)
                  .backgroundColor($r('app.color.gn_pane'))
                  .width(82)
                  .onChange((value: string) => {
                    this.labelSizeText = value;
                  })
                TextInput({ text: this.labelColor, placeholder: '颜色' })
                  .height(30)
                  .fontSize(12)
                  .backgroundColor($r('app.color.gn_pane'))
                  .layoutWeight(1)
                  .onChange((value: string) => {
                    this.labelColor = value;
                  })
              }
              Row({ space: 8 }) {
                TextInput({ text: this.minScaleText, placeholder: '最小比例尺，0 不限制' })
                  .height(30)
                  .fontSize(12)
                  .backgroundColor($r('app.color.gn_pane'))
                  .layoutWeight(1)
                  .onChange((value: string) => {
                    this.minScaleText = value;
                  })
                TextInput({ text: this.maxScaleText, placeholder: '最大比例尺，0 不限制' })
                  .height(30)
                  .fontSize(12)
                  .backgroundColor($r('app.color.gn_pane'))
                  .layoutWeight(1)
                  .onChange((value: string) => {
                    this.maxScaleText = value;
                  })
              }
              Text('状态：' + this.statusText)
                .fontSize(12)
                .fontColor($r('app.color.gn_text_muted'))
                .width('100%')
              Button('应用标注', { type: ButtonType.Capsule, stateEffect: true })
                .height(38)
                .fontSize(14)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.gn_blue_800'))
                .onClick(() => {
                  this.applyLabeling();
                })
            }
          }
          .padding(14)
        }.width('100%').height('100%')
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
          title: { mainTitle: '标注系统' },
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
