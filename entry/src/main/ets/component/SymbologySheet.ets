import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '@geonest/common';
import { getGisService, GisLayerStyle, GisLoadedLayer, qgisCategoryTotal, qgisRampColor } from '../gis/GisService';
import { GisFieldInfo, GisOperationResult } from '../model/GeoNestModels';
import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';

const QML_STYLE_SUFFIX_CHOICE: string = 'QGIS QML Style|.qml';

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
    this.loadActiveLayerStyle();
    this.isShow = true;
  }

  aboutToAppear(): void {
    this.loadActiveLayerStyle();
  }

  private loadActiveLayerStyle(): void {
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
      this.statusText = '样式就绪';
      this.refreshDialogUi();
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
    if (this.rendererMode === 3) {
      return '表达式规则';
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

  private extractFileName(uri: string): string {
    let fileName = uri;
    let lastSlash = uri.lastIndexOf('/');
    if (lastSlash >= 0 && lastSlash < uri.length - 1) {
      fileName = uri.substring(lastSlash + 1);
    }
    let lastBackSlash = fileName.lastIndexOf('\\');
    if (lastBackSlash >= 0 && lastBackSlash < fileName.length - 1) {
      fileName = fileName.substring(lastBackSlash + 1);
    }
    if (fileName.length === 0) {
      return 'style.qml';
    }
    return fileName;
  }

  private fileExtension(fileName: string): string {
    let idx = fileName.lastIndexOf('.');
    if (idx < 0 || idx >= fileName.length - 1) {
      return '';
    }
    return fileName.substring(idx + 1).toLowerCase();
  }

  private fileBaseName(fileName: string): string {
    let idx = fileName.lastIndexOf('.');
    if (idx <= 0) {
      return fileName;
    }
    return fileName.substring(0, idx);
  }

  private safePathSegment(text: string): string {
    let result = '';
    for (let i = 0; i < text.length; i++) {
      let ch = text.charAt(i);
      if ((ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
        ch === '-' || ch === '_') {
        result += ch;
      } else {
        result += '_';
      }
    }
    if (result.length === 0) {
      return 'style';
    }
    return result;
  }

  private qmlSandboxDir(): string {
    let ctx = getContext(this);
    let sandboxDir = ctx.filesDir + '/qml_styles';
    try { fs.mkdirSync(sandboxDir); } catch (e) { /* exists */ }
    return sandboxDir;
  }

  private qmlSandboxPath(fileName: string): string {
    let ext = this.fileExtension(fileName);
    if (ext.length === 0) {
      ext = 'qml';
    }
    return this.qmlSandboxDir() + '/' + new Date().getTime().toString() + '_' +
      this.safePathSegment(this.fileBaseName(fileName)) + '.' + ext;
  }

  private copyUriToFile(uri: string, destinationPath: string): boolean {
    try {
      let srcFd = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(srcFd.fd);
      let buf = new ArrayBuffer(stat.size);
      fs.readSync(srcFd.fd, buf);
      fs.closeSync(srcFd);

      let destFd = fs.openSync(destinationPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(destFd.fd, buf);
      fs.closeSync(destFd);
      return true;
    } catch (e) {
      this.statusText = 'QML 文件复制失败';
    }
    return false;
  }

  private copyFileToUri(sourcePath: string, uri: string): boolean {
    try {
      let srcFd = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(srcFd.fd);
      let buf = new ArrayBuffer(stat.size);
      fs.readSync(srcFd.fd, buf);
      fs.closeSync(srcFd);

      let destFd = fs.openSync(uri, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(destFd.fd, buf);
      fs.closeSync(destFd);
      return true;
    } catch (e) {
      this.statusText = 'QML 文件写出失败';
    }
    return false;
  }

  private buildQmlSelectOptions(): picker.DocumentSelectOptions {
    let opts: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    opts.maxSelectNumber = 1;
    opts.fileSuffixFilters = [QML_STYLE_SUFFIX_CHOICE];
    return opts;
  }

  private buildQmlSaveOptions(fileName: string): picker.DocumentSaveOptions {
    let opts: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    opts.newFileNames = [fileName];
    opts.fileSuffixChoices = [QML_STYLE_SUFFIX_CHOICE];
    return opts;
  }

  private importQmlStyle(): void {
    let layer = this.getActiveLayer();
    if (layer === undefined) {
      this.statusText = '没有活动图层';
      return;
    }
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      documentPicker.select(this.buildQmlSelectOptions()).then((result: Array<string>) => {
        if (result.length === 0) {
          return;
        }
        let uri = result[0];
        let sandboxPath = this.qmlSandboxPath(this.extractFileName(uri));
        if (!this.copyUriToFile(uri, sandboxPath)) {
          return;
        }
        let operation: GisOperationResult = getGisService().importQmlStyle(getGisService().getActiveLayerIndex(),
          sandboxPath);
        if (operation.ok) {
          this.loadActiveLayerStyle();
          this.statusText = '已导入 QML 样式';
          this.onStyleChanged();
        } else {
          this.statusText = '导入失败：' + operation.message;
        }
      }).catch(() => {
        this.statusText = '已取消导入 QML 样式';
      });
    } catch (e) {
      this.statusText = '导入 QML 样式失败';
    }
  }

  private exportQmlStyle(): void {
    let layer = this.getActiveLayer();
    if (layer === undefined) {
      this.statusText = '没有活动图层';
      return;
    }
    let fileName = this.safePathSegment(layer.info.name) + '.qml';
    let sandboxPath = this.qmlSandboxPath(fileName);
    let operation: GisOperationResult = getGisService().exportQmlStyle(getGisService().getActiveLayerIndex(),
      sandboxPath);
    if (!operation.ok) {
      this.statusText = '导出失败：' + operation.message;
      return;
    }
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      documentPicker.save(this.buildQmlSaveOptions(fileName)).then((result: Array<string>) => {
        if (result.length === 0) {
          return;
        }
        if (this.copyFileToUri(sandboxPath, result[0])) {
          this.statusText = '已导出 QML 样式';
        }
      }).catch(() => {
        this.statusText = '已取消导出 QML 样式';
      });
    } catch (e) {
      this.statusText = '导出 QML 样式失败';
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

  private colorSwatchRenderKeys(fieldIndex: number): string[] {
    let result: string[] = [];
    result.push('swatch:' + fieldIndex.toString() + ':' + this.colorFieldValue(fieldIndex) + ':' +
      this.uiRevision.toString());
    return result;
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
      ForEach(this.colorSwatchRenderKeys(fieldIndex), (renderKey: string) => {
        this.colorSwatch(this.colorFieldValue(fieldIndex))
      }, (renderKey: string) => renderKey)
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
          this.modeChip('表达式规则', 3)
          Blank()
          Text(this.rampName())
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
        }
        .height(32)
        if (this.rendererMode !== 0) {
          Text(this.rendererMode === 3 ? 'QGIS 表达式' : '渲染字段')
            .width('100%')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
          if (this.rendererMode === 3) {
            TextInput({ text: this.rendererField, placeholder: '例如 "type" IS NOT NULL' })
              .height(36)
              .fontSize(12)
              .backgroundColor($r('app.color.gn_pane'))
              .onChange((value: string) => {
                this.rendererField = value;
              })
          } else {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(layer.info.fields, (field: GisFieldInfo) => {
                this.fieldChip(field)
              }, (field: GisFieldInfo) => 'sym-field:' + field.name)
            }
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
    if (this.rendererMode === 3) {
      return 2;
    }
    return 1;
  }

  private previewSymbolColor(layer: GisLoadedLayer): string {
    if (this.rendererMode === 1 || this.rendererMode === 2 || this.rendererMode === 3) {
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
    if (this.rendererMode === 3) {
      return '表达式规则';
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
    if (this.rendererMode === 1 || this.rendererMode === 2 || this.rendererMode === 3) {
      let fallbackText = this.rendererMode === 3 ? '未填写表达式' : '未选择字段';
      let rendererSource = this.rendererField.length > 0 ? this.rendererField : fallbackText;
      return this.rendererModeName() + ' · ' + rendererSource;
    }
    if (layer.info.geometryType === 1) {
      return '半径 ' + this.pointRadiusText + ' px';
    }
    if (layer.info.geometryType === 2) {
      return '线宽 ' + this.lineWidthText + ' px';
    }
    return this.rendererModeName();
  }

  private symbolPreviewKey(layer: GisLoadedLayer): string {
    return layer.info.layerId + ':' + this.uiRevision.toString() + ':' + this.rendererMode.toString() + ':' +
      this.rendererField + ':' + this.colorRamp.toString() + ':' + this.pointColor + ':' + this.lineColor + ':' +
      this.fillColor + ':' + this.strokeColor + ':' + this.lineWidthText + ':' + this.pointRadiusText + ':' +
      this.opacityPercent.toString();
  }

  @Builder
  symbolPanel(layer: GisLoadedLayer) {
    Column({ space: 12 }) {
      Text(this.symbolPreviewKey(layer))
        .width(0)
        .height(0)
        .fontSize(0)
        .opacity(0)
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
                  Row({ space: 8 }) {
                    Button('导入 QML', { type: ButtonType.Normal, stateEffect: true })
                      .layoutWeight(1)
                      .height(36)
                      .fontSize(13)
                      .fontColor($r('app.color.gn_blue_800'))
                      .backgroundColor($r('app.color.gn_blue_100'))
                      .borderRadius(6)
                      .onClick(() => {
                        this.importQmlStyle();
                      })
                    Button('导出 QML', { type: ButtonType.Normal, stateEffect: true })
                      .layoutWeight(1)
                      .height(36)
                      .fontSize(13)
                      .fontColor($r('app.color.gn_blue_800'))
                      .backgroundColor($r('app.color.gn_blue_100'))
                      .borderRadius(6)
                      .onClick(() => {
                        this.exportQmlStyle();
                      })
                  }
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
        width: 900,
        height: 690,
        detents: [690],
        preferType: SheetType.CENTER,
        dragBar: false,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.Regular,
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
    this.loadActiveLabelStyle();
    this.isShow = true;
  }

  aboutToAppear(): void {
    this.loadActiveLabelStyle();
  }

  private loadActiveLabelStyle(): void {
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
      this.statusText = '标注就绪';
      this.refreshDialogUi();
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

  private activeLabelSourceText(): string {
    let activeField = this.activeFieldName();
    if (activeField.startsWith('expr:')) {
      let expressionText = activeField.substring(5).trim();
      if (expressionText.length > 0) {
        return '表达式 · ' + expressionText;
      }
      return '表达式';
    }
    if (activeField.length > 0) {
      return activeField;
    }
    return '未选择字段';
  }

  private labelExpressionText(): string {
    let activeField = this.activeFieldName();
    if (activeField.length === 0) {
      return '未选择标注字段';
    }
    if (activeField.startsWith('expr:')) {
      let expressionText = activeField.substring(5).trim();
      if (expressionText.length > 0) {
        return expressionText;
      }
      return '未填写表达式';
    }
    return '[' + activeField + ']';
  }

  private labelScaleText(): string {
    let minScale = this.safeNumberText(this.minScaleText, 0, 0, 1000000000);
    let maxScale = this.safeNumberText(this.maxScaleText, 0, 0, 1000000000);
    if (minScale <= 0 && maxScale <= 0) {
      return '所有比例尺';
    }
    if (minScale > 0 && maxScale > 0) {
      return '1:' + minScale.toString() + ' - 1:' + maxScale.toString();
    }
    if (minScale > 0) {
      return '大于 1:' + minScale.toString();
    }
    return '小于 1:' + maxScale.toString();
  }

  private placementText(layer: GisLoadedLayer): string {
    if (layer.info.geometryType === 2) {
      return '沿线放置';
    }
    if (layer.info.geometryType === 3) {
      return '面内/周围放置';
    }
    return '点周围放置';
  }

  private placementDetail(layer: GisLoadedLayer): string {
    if (layer.info.geometryType === 2) {
      return 'QGIS PAL 会沿线要素计算候选位置';
    }
    if (layer.info.geometryType === 3) {
      return 'QGIS PAL 按面要素代表位置生成候选标注';
    }
    return 'QGIS PAL 在点要素周围生成候选标注';
  }

  private conflictText(): string {
    if (this.avoidance) {
      return '避让要素，减少重叠';
    }
    return '允许更密集的标注结果';
  }

  private previewText(layer: GisLoadedLayer): string {
    let labelSource = this.activeLabelSourceText();
    if (labelSource.length > 0) {
      return layer.info.name + ' · ' + labelSource;
    }
    return layer.info.name;
  }

  private labelPreviewKey(layer: GisLoadedLayer): string {
    return layer.info.layerId + ':' + this.uiRevision.toString() + ':' + this.labelEnabled.toString() + ':' +
      this.activeFieldName() + ':' + this.labelSizeText + ':' + this.labelColor + ':' + this.halo.toString() + ':' +
      this.avoidance.toString() + ':' + this.minScaleText + ':' + this.maxScaleText;
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
      this.refreshDialogUi();
    } else {
      this.statusText = '失败：' + result.message;
    }
  }

  @Builder
  fieldChip(field: GisFieldInfo) {
    Row({ space: 6 }) {
      SymbolGlyph(this.activeFieldName() === field.name ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.doc_text'))
        .fontSize(13)
        .fontColor([this.activeFieldName() === field.name ? $r('app.color.gn_blue_800') :
          $r('sys.color.icon_secondary')])
      Column() {
        Text(field.name)
          .fontSize(12)
          .fontWeight(this.activeFieldName() === field.name ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.activeFieldName() === field.name ? $r('app.color.gn_blue_800') :
            $r('app.color.gn_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(field.typeName)
          .fontSize(10)
          .fontColor($r('app.color.gn_text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .height(38)
    .padding({ left: 9, right: 9 })
    .margin({ right: 6, bottom: 6 })
    .borderRadius(5)
    .backgroundColor(this.activeFieldName() === field.name ? $r('app.color.gn_blue_100') : $r('app.color.gn_pane'))
    .border({ width: 1, color: this.activeFieldName() === field.name ? $r('app.color.gn_blue_800') :
      $r('app.color.gn_line') })
      .onClick(() => {
        this.labelField = field.name;
        this.labelEnabled = true;
        this.labelToggleTouched = true;
        this.refreshDialogUi();
      })
  }

  @Builder
  toggleChip(label: string, active: boolean, mode: number) {
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
        .width(88)
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
  classRow(layer: GisLoadedLayer) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        SymbolGlyph(this.labelEnabled ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.circle'))
          .fontSize(17)
          .fontColor([this.labelEnabled ? $r('app.color.gn_blue_800') : $r('sys.color.icon_secondary')])
        Column() {
          Text('默认标注类')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
          Text(this.labelEnabled ? '打开 · ' + this.activeLabelSourceText() : '关闭')
            .fontSize(11)
            .fontColor($r('app.color.gn_text_muted'))
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      this.infoRow('SQL 查询', '所有要素')
      this.infoRow('比例尺', this.labelScaleText())
      this.infoRow('位置', this.placementText(layer))
    }
    .width('100%')
    .padding(10)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_blue_100'))
    .border({ width: 1, color: $r('app.color.gn_blue_800') })
    .onClick(() => {
      this.labelEnabled = true;
      this.labelToggleTouched = true;
      this.refreshDialogUi();
    })
  }

  @Builder
  classPanel(layer: GisLoadedLayer) {
    Column({ space: 10 }) {
      this.panelTitle('标注类', '按图层组织标注规则')
      this.classRow(layer)
      Button('新建类', { type: ButtonType.Normal, stateEffect: true })
        .width('100%')
        .height(34)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .backgroundColor($r('app.color.gn_pane'))
        .borderRadius(6)
        .onClick(() => {
          this.statusText = '当前底层先支持默认标注类';
        })
      this.infoRow('引擎', 'QGIS PAL')
      this.infoRow('优先级', '标准')
      this.infoRow('冲突', this.conflictText())
    }
    .width(238)
    .padding(12)
    .borderRadius(7)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  expressionPanel(layer: GisLoadedLayer) {
    Column({ space: 10 }) {
      this.panelTitle('表达式', '选择字段并生成标注文本')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(layer.info.fields, (field: GisFieldInfo) => {
          this.fieldChip(field)
        }, (field: GisFieldInfo) => 'label-field:' + field.name)
      }
      .width('100%')
      Column({ space: 6 }) {
        this.infoRow('表达式', this.labelExpressionText())
        this.infoRow('SQL 查询', '所有要素')
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
  symbolPreview(layer: GisLoadedLayer) {
    Row({ space: 12 }) {
      Text(this.previewText(layer))
        .fontSize(this.safeNumberText(this.labelSizeText, 12, 8, 48))
        .fontColor(this.labelColor)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.labelEnabled ? 'ON' : 'OFF')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.labelEnabled ? $r('app.color.gn_green_700') : $r('app.color.gn_text_muted'))
    }
    .width('100%')
    .height(54)
    .padding(12)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_pane'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  symbolPanel(layer: GisLoadedLayer) {
    Column({ space: 10 }) {
      this.panelTitle('文字符号', '控制字体大小、颜色和光晕')
      this.symbolPreview(layer)
      Row({ space: 8 }) {
        TextInput({ text: this.labelSizeText, placeholder: '字号' })
          .height(34)
          .fontSize(12)
          .backgroundColor($r('app.color.gn_pane'))
          .width(96)
          .onChange((value: string) => {
            this.labelSizeText = value;
            this.refreshDialogUi();
          })
        TextInput({ text: this.labelColor, placeholder: '颜色，如 #17201D' })
          .height(34)
          .fontSize(12)
          .backgroundColor($r('app.color.gn_pane'))
          .layoutWeight(1)
          .onChange((value: string) => {
            this.labelColor = value;
            this.refreshDialogUi();
          })
      }
      .width('100%')
      Row({ space: 8 }) {
        this.toggleChip('启用标注', this.labelEnabled, 0)
        this.toggleChip('白色光晕', this.halo, 1)
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
  placementPanel(layer: GisLoadedLayer) {
    Column({ space: 10 }) {
      this.panelTitle('位置与冲突', '控制放置方式、比例尺范围和避让')
      Column({ space: 6 }) {
        this.infoRow('位置', this.placementText(layer))
        this.infoRow('说明', this.placementDetail(layer))
        this.infoRow('冲突策略', this.conflictText())
        this.infoRow('显示比例尺', this.labelScaleText())
      }
      .width('100%')
      .padding(10)
      .borderRadius(6)
      .backgroundColor($r('app.color.gn_pane'))
      Row({ space: 8 }) {
        this.toggleChip('要素避让', this.avoidance, 2)
        TextInput({ text: this.minScaleText, placeholder: '最小比例尺，0 不限制' })
          .height(34)
          .fontSize(12)
          .backgroundColor($r('app.color.gn_pane'))
          .layoutWeight(1)
          .onChange((value: string) => {
            this.minScaleText = value;
            this.refreshDialogUi();
          })
        TextInput({ text: this.maxScaleText, placeholder: '最大比例尺，0 不限制' })
          .height(34)
          .fontSize(12)
          .backgroundColor($r('app.color.gn_pane'))
          .layoutWeight(1)
          .onChange((value: string) => {
            this.maxScaleText = value;
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
  headerPanel(layer: GisLoadedLayer) {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.doc_text'))
        .fontSize(30)
        .fontColor([$r('app.color.gn_blue_800')])
      Column() {
        Text(layer.info.name)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.gn_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.geometryTypeName(layer.info.geometryType) + '图层 · ' + layer.info.featureCount.toString() +
          ' 要素 · ' + layer.info.fields.length.toString() + ' 字段')
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      this.toggleChip(this.labelEnabled ? '标注开' : '标注关', this.labelEnabled, 0)
    }
    .width('100%')
    .padding(14)
    .borderRadius(7)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  labelingWorkspace(layer: GisLoadedLayer) {
    Column({ space: 12 }) {
      Text(this.labelPreviewKey(layer))
        .width(0)
        .height(0)
        .fontSize(0)
        .opacity(0)
      this.headerPanel(layer)
      Row({ space: 12 }) {
        this.classPanel(layer)
        Column({ space: 12 }) {
          this.expressionPanel(layer)
          this.symbolPanel(layer)
          this.placementPanel(layer)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      Row({ space: 8 }) {
        Text('状态：' + this.statusText)
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Button('应用标注', { type: ButtonType.Capsule, stateEffect: true })
          .width(148)
          .height(38)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.gn_blue_800'))
          .onClick(() => {
            this.applyLabeling();
          })
      }
      .width('100%')
      .padding(12)
      .borderRadius(7)
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
    }
    .width('100%')
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
              this.labelingWorkspace(this.getActiveLayer() as GisLoadedLayer)
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
        width: 900,
        height: 690,
        detents: [690],
        preferType: SheetType.CENTER,
        dragBar: false,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.Regular,
        showClose: false,
        onDisappear: (): void => { this.isShow = false; }
      })
  }
}
