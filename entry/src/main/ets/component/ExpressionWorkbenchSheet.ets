import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '@geonest/common';
import { getGisService, GisLayerStyle, GisLoadedLayer } from '../gis/GisService';
import { GisAttributeValue, GisFeatureSummary, GisFieldInfo, GisGeoProcessResult, GisOperationResult } from '../model/GeoNestModels';
import fs from '@ohos.file.fs';

const EXPRESSION_TASK_EXTRACT: number = 0;
const EXPRESSION_TASK_CALCULATE: number = 1;
const EXPRESSION_TASK_BATCH_ASSIGN: number = 2;
const EXPRESSION_TASK_RENDER: number = 3;
const EXPRESSION_TASK_LABEL: number = 4;

class ExpressionLayerChoice {
  name: string = '';
  meta: string = '';
  key: string = '';
}

@Component
export struct ExpressionWorkbenchSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  activeLayerRevision: number = 0;
  onExpressionChanged: () => void = () => {};
  private scroller: Scroller = new Scroller();
  @State private selectedTask: number = EXPRESSION_TASK_EXTRACT;
  @State private inputName: string = '';
  @State private fieldName: string = '';
  @State private expressionText: string = '';
  @State private assignmentValue: string = '';
  @State private outputName: string = '';
  @State private statusText: string = '表达式工作台就绪';
  @State private uiRevision: number = 0;

  onTrigger(): void {
    this.prepareDefaults();
    this.isShow = true;
  }

  private prepareDefaults(): void {
    let layer = getGisService().getActiveLayer();
    if (layer !== undefined) {
      this.inputName = layer.info.name;
      if (this.fieldName.length === 0 && layer.info.fields.length > 0) {
        this.fieldName = layer.info.fields[0].name;
      }
      if (this.expressionText.length === 0) {
        this.expressionText = this.defaultExpression(layer);
      }
      if (this.outputName.length === 0) {
        this.outputName = layer.info.name + '_expression';
      }
    }
    if (this.assignmentValue.length === 0) {
      this.assignmentValue = '已处理';
    }
    this.statusText = '表达式工作台就绪';
    this.uiRevision++;
  }

  private refreshUi(): void {
    this.uiRevision++;
  }

  private activeLayerIndex(): number {
    let service = getGisService();
    if (this.inputName.length > 0) {
      let index = service.findLayerIndexByName(this.inputName);
      if (index >= 0) {
        return index;
      }
    }
    return service.getActiveLayerIndex();
  }

  private activeLayer(): GisLoadedLayer | undefined {
    return getGisService().getLayer(this.activeLayerIndex());
  }

  private activeLayerKey(): string {
    let layer = this.activeLayer();
    if (layer === undefined) {
      return 'expression:none:' + this.activeLayerRevision.toString() + ':' + this.uiRevision.toString();
    }
    return 'expression:' + this.activeLayerIndex().toString() + ':' + layer.info.layerId + ':' +
      this.activeLayerRevision.toString() + ':' + this.uiRevision.toString();
  }

  private isVectorLayer(layer: GisLoadedLayer): boolean {
    return layer.info.geometryType > 0;
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
    if (this.fieldName.length > 0) {
      return this.fieldName;
    }
    let layer = this.activeLayer();
    if (layer !== undefined && layer.info.fields.length > 0) {
      return layer.info.fields[0].name;
    }
    return '';
  }

  private quoteFieldName(field: string): string {
    let result = '"';
    for (let i = 0; i < field.length; i++) {
      let c = field.charAt(i);
      if (c === '"') {
        result += '""';
      } else {
        result += c;
      }
    }
    return result + '"';
  }

  private defaultExpression(layer: GisLoadedLayer): string {
    let field = this.activeFieldName();
    if (field.length > 0) {
      return this.quoteFieldName(field) + ' IS NOT NULL';
    }
    if (layer.info.geometryType === 2) {
      return '$length > 0';
    }
    if (layer.info.geometryType === 3) {
      return '$area > 0';
    }
    return '1 = 1';
  }

  private outputLayerName(layer: GisLoadedLayer): string {
    if (this.outputName.trim().length > 0) {
      return this.outputName.trim();
    }
    return layer.info.name + '_expression';
  }

  private buildOutputPath(outputLayerName: string): string {
    let ctx = getContext(this);
    let outputDir = ctx.filesDir + '/geonest_outputs';
    try {
      fs.mkdirSync(outputDir);
    } catch (e) {
    }
    return outputDir + '/' + outputLayerName + '.shp';
  }

  private buildLayerChoiceList(): ExpressionLayerChoice[] {
    let result: ExpressionLayerChoice[] = [];
    let service = getGisService();
    for (let i = 0; i < service.getLayerCount(); i++) {
      let layer = service.getLayer(i);
      if (layer === undefined) {
        continue;
      }
      let item = new ExpressionLayerChoice();
      item.name = layer.info.name;
      item.meta = this.geometryTypeName(layer.info.geometryType) + ' · ' + layer.info.featureCount.toString() +
        ' 要素';
      item.key = i.toString() + ':' + layer.info.layerId;
      result.push(item);
    }
    return result;
  }

  private selectLayer(layerName: string): void {
    this.inputName = layerName;
    let layer = this.activeLayer();
    if (layer !== undefined) {
      getGisService().setActiveLayerIndex(this.activeLayerIndex());
      this.fieldName = layer.info.fields.length > 0 ? layer.info.fields[0].name : '';
      this.expressionText = this.defaultExpression(layer);
      this.outputName = layer.info.name + '_expression';
    }
    this.refreshUi();
  }

  private insertTemplate(expression: string): void {
    this.expressionText = expression;
    this.refreshUi();
  }

  private applyOperationResult(result: GisOperationResult): void {
    if (result.ok) {
      this.statusText = result.message.length > 0 ? result.message : '表达式已执行';
      this.onExpressionChanged();
    } else {
      this.statusText = '失败：' + result.message;
    }
    this.refreshUi();
  }

  private applyGeoProcessResult(result: GisGeoProcessResult): void {
    if (result.ok) {
      this.statusText = '完成：筛选 ' + result.featureCount.toString() + ' 个要素，结果已加载';
      this.onExpressionChanged();
    } else {
      this.statusText = '失败：' + result.message;
    }
    this.refreshUi();
  }

  private runExpression(): void {
    let layerIndex = this.activeLayerIndex();
    let layer = getGisService().getLayer(layerIndex);
    if (layer === undefined) {
      this.statusText = '请先选择图层';
      return;
    }
    if (!this.isVectorLayer(layer)) {
      this.statusText = '表达式工作台当前仅支持矢量图层';
      return;
    }
    let expression = this.expressionText.trim();
    if (expression.length === 0) {
      this.statusText = '请输入 QGIS 表达式';
      return;
    }
    if (this.selectedTask === EXPRESSION_TASK_EXTRACT) {
      let outputLayerName = this.outputLayerName(layer);
      let outputPath = this.buildOutputPath(outputLayerName);
      this.applyGeoProcessResult(getGisService().runExtractByExpression(layerIndex, expression, outputPath,
        outputLayerName));
      return;
    }
    if (this.selectedTask === EXPRESSION_TASK_RENDER) {
      let style: GisLayerStyle = layer.style;
      style.rendererMode = 3;
      style.rendererField = expression;
      if (style.colorRamp < 1) {
        style.colorRamp = 2;
      }
      this.applyOperationResult(getGisService().updateLayerStyle(layerIndex, style));
      return;
    }
    if (this.selectedTask === EXPRESSION_TASK_LABEL) {
      let labelStyle: GisLayerStyle = layer.style;
      labelStyle.labelEnabled = true;
      labelStyle.labelField = 'expr:' + expression;
      this.applyOperationResult(getGisService().updateLayerStyle(layerIndex, labelStyle));
      return;
    }
    let targetField = this.activeFieldName();
    if (targetField.length === 0) {
      this.statusText = '请选择目标字段';
      return;
    }
    if (this.selectedTask === EXPRESSION_TASK_CALCULATE) {
      this.applyOperationResult(getGisService().calculateField(layerIndex, targetField, 4, expression));
      return;
    }
    this.applyOperationResult(getGisService().batchAssignAttribute(layerIndex, targetField, 'qgis:' + expression,
      this.assignmentValue));
  }

  private taskTitle(): string {
    if (this.selectedTask === EXPRESSION_TASK_CALCULATE) {
      return '字段计算';
    }
    if (this.selectedTask === EXPRESSION_TASK_BATCH_ASSIGN) {
      return '批量赋值';
    }
    if (this.selectedTask === EXPRESSION_TASK_RENDER) {
      return '表达式渲染';
    }
    if (this.selectedTask === EXPRESSION_TASK_LABEL) {
      return '表达式标注';
    }
    return '筛选提取';
  }

  private actionTitle(): string {
    if (this.selectedTask === EXPRESSION_TASK_CALCULATE) {
      return '计算字段';
    }
    if (this.selectedTask === EXPRESSION_TASK_BATCH_ASSIGN) {
      return '批量赋值';
    }
    if (this.selectedTask === EXPRESSION_TASK_RENDER) {
      return '应用规则渲染';
    }
    if (this.selectedTask === EXPRESSION_TASK_LABEL) {
      return '应用表达式标注';
    }
    return '输出筛选结果';
  }

  private expressionPlaceholder(): string {
    if (this.selectedTask === EXPRESSION_TASK_CALCULATE) {
      return 'round($area, 2)';
    }
    if (this.selectedTask === EXPRESSION_TASK_LABEL) {
      return this.activeFieldName().length > 0 ? this.quoteFieldName(this.activeFieldName()) : '$id';
    }
    return this.activeFieldName().length > 0 ? this.quoteFieldName(this.activeFieldName()) + ' IS NOT NULL' : '1 = 1';
  }

  private taskRequiresField(): boolean {
    return this.selectedTask === EXPRESSION_TASK_CALCULATE ||
      this.selectedTask === EXPRESSION_TASK_BATCH_ASSIGN;
  }

  private attrText(attr: GisAttributeValue): string {
    if (attr.isNull) {
      return '(空)';
    }
    if (attr.textValue.length > 0) {
      return attr.textValue;
    }
    return attr.numberValue.toString();
  }

  private attrByName(row: GisFeatureSummary, fieldName: string): string {
    for (let i = 0; i < row.attributesPreview.length; i++) {
      let attr = row.attributesPreview[i];
      if (attr.name === fieldName) {
        return this.attrText(attr);
      }
    }
    return '';
  }

  private previewRows(layer: GisLoadedLayer): GisFeatureSummary[] {
    let rows: GisFeatureSummary[] = [];
    let maxCount = layer.features.length;
    if (maxCount > 5) {
      maxCount = 5;
    }
    for (let i = 0; i < maxCount; i++) {
      rows.push(layer.features[i]);
    }
    return rows;
  }

  @Builder
  layerPickerMenu() {
    Menu() {
      ForEach(this.buildLayerChoiceList(), (item: ExpressionLayerChoice) => {
        MenuItem({ content: item.name + ' · ' + item.meta })
          .onClick(() => {
            this.selectLayer(item.name);
          })
      }, (item: ExpressionLayerChoice) => 'expression-layer:' + item.key)
    }
  }

  @Builder
  layerButton(layer: GisLoadedLayer) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.layer'))
          .fontSize(16)
          .fontColor([$r('app.color.gn_blue_800')])
        Text(layer.info.name)
          .fontSize(12)
          .fontColor($r('app.color.gn_blue_800'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .justifyContent(FlexAlign.Center)
    }
    .height(34)
    .padding({ left: 10, right: 10 })
    .backgroundColor($r('app.color.gn_blue_100'))
    .borderRadius(6)
    .bindMenu(this.layerPickerMenu)
  }

  @Builder
  taskButton(label: string, detail: string, task: number, icon: Resource) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([this.selectedTask === task ? $r('app.color.gn_blue_800') :
            $r('sys.color.icon_secondary')])
        Column({ space: 2 }) {
          Text(label)
            .fontSize(12)
            .fontWeight(this.selectedTask === task ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.selectedTask === task ? $r('app.color.gn_blue_800') :
              $r('app.color.gn_text_primary'))
          Text(detail)
            .fontSize(9)
            .fontColor($r('app.color.gn_text_muted'))
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .layoutWeight(1)
    .height(54)
    .padding({ left: 10, right: 10 })
    .backgroundColor(this.selectedTask === task ? $r('app.color.gn_blue_100') : $r('app.color.gn_paper'))
    .borderRadius(6)
    .border({
      width: 1,
      color: this.selectedTask === task ? $r('app.color.gn_blue_800') : $r('app.color.gn_line')
    })
    .onClick(() => {
      this.selectedTask = task;
      this.refreshUi();
    })
  }

  @Builder
  fieldChip(field: GisFieldInfo) {
    Text(field.name)
      .height(26)
      .padding({ left: 9, right: 9 })
      .fontSize(12)
      .fontColor(this.activeFieldName() === field.name ? $r('app.color.gn_blue_800') :
        $r('app.color.gn_text_muted'))
      .backgroundColor(this.activeFieldName() === field.name ? $r('app.color.gn_blue_100') :
        $r('app.color.gn_pane'))
      .borderRadius(4)
      .margin({ right: 6, bottom: 6 })
      .onClick(() => {
        this.fieldName = field.name;
        if (this.expressionText.length === 0 || this.expressionText === '1 = 1') {
          this.expressionText = this.quoteFieldName(field.name) + ' IS NOT NULL';
        }
        this.refreshUi();
      })
  }

  @Builder
  templateChip(label: string, expression: string) {
    Text(label)
      .height(28)
      .padding({ left: 10, right: 10 })
      .fontSize(12)
      .fontColor($r('app.color.gn_blue_800'))
      .backgroundColor($r('app.color.gn_blue_100'))
      .borderRadius(5)
      .margin({ right: 6, bottom: 6 })
      .onClick(() => {
        this.insertTemplate(expression);
      })
  }

  @Builder
  overviewPanel(layer: GisLoadedLayer) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calculator'))
          .fontSize(30)
          .fontColor([$r('app.color.gn_blue_800')])
        Column({ space: 3 }) {
          Text($r('app.string.gn_expression_workbench_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.gn_text_primary'))
          Text($r('app.string.gn_expression_workbench_desc'))
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        this.layerButton(layer)
      }
      Row() {
        this.metricText('要素', layer.info.featureCount.toString())
        this.metricText('字段', layer.info.fields.length.toString())
        this.metricText('任务', this.taskTitle())
      }
    }
    .padding(14)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  metricText(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.gn_text_primary'))
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.gn_text_muted'))
        .margin({ top: 3 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  expressionPanel(layer: GisLoadedLayer) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        this.taskButton('筛选提取', '输出新图层', EXPRESSION_TASK_EXTRACT, $r('sys.symbol.funnel'))
        this.taskButton('字段计算', '表达式写入', EXPRESSION_TASK_CALCULATE, $r('sys.symbol.calculator'))
        this.taskButton('批量赋值', '条件更新', EXPRESSION_TASK_BATCH_ASSIGN, $r('sys.symbol.list_bullet'))
      }
      .width('100%')
      Row({ space: 8 }) {
        this.taskButton('表达式渲染', '规则符号', EXPRESSION_TASK_RENDER, $r('sys.symbol.paintpalette'))
        this.taskButton('表达式标注', 'PAL 标注', EXPRESSION_TASK_LABEL, $r('sys.symbol.doc_text'))
      }
      .width('100%')

      Column({ space: 5 }) {
        Text('QGIS 表达式')
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
        TextInput({ text: this.expressionText, placeholder: this.expressionPlaceholder() })
          .height(38)
          .fontSize(13)
          .backgroundColor($r('app.color.gn_pane'))
          .onChange((value: string) => {
            this.expressionText = value;
          })
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        this.templateChip('全部要素', '1 = 1')
        this.templateChip('非空字段', this.activeFieldName().length > 0 ?
          this.quoteFieldName(this.activeFieldName()) + ' IS NOT NULL' : '1 = 1')
        this.templateChip('面积大于 0', '$area > 0')
        this.templateChip('长度大于 0', '$length > 0')
      }

      if (this.taskRequiresField()) {
        Column({ space: 6 }) {
          Text('目标字段：' + this.activeFieldName())
            .fontSize(11)
            .fontColor($r('app.color.gn_text_muted'))
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(layer.info.fields, (field: GisFieldInfo) => {
              this.fieldChip(field)
            }, (field: GisFieldInfo) => this.activeLayerKey() + ':field:' + field.name)
          }
        }
      }

      if (this.selectedTask === EXPRESSION_TASK_BATCH_ASSIGN) {
        TextInput({ text: this.assignmentValue, placeholder: '写入值' })
          .height(38)
          .fontSize(13)
          .backgroundColor($r('app.color.gn_pane'))
          .onChange((value: string) => {
            this.assignmentValue = value;
          })
      }

      if (this.selectedTask === EXPRESSION_TASK_EXTRACT) {
        TextInput({ text: this.outputLayerName(layer), placeholder: '输出图层名' })
          .height(38)
          .fontSize(13)
          .backgroundColor($r('app.color.gn_pane'))
          .onChange((value: string) => {
            this.outputName = value;
          })
      }

      Button(this.actionTitle(), { type: ButtonType.Capsule, stateEffect: true })
        .height(40)
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.gn_blue_800'))
        .onClick(() => {
          this.runExpression();
        })

      Text('状态：' + this.statusText)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
    }
    .padding(14)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  previewRow(row: GisFeatureSummary) {
    Row({ space: 8 }) {
      Text('FID ' + row.featureId)
        .width(82)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.activeFieldName().length > 0 ? this.attrByName(row, this.activeFieldName()) :
        row.envelope.minX.toFixed(4) + ', ' + row.envelope.minY.toFixed(4))
        .layoutWeight(1)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(30)
    .padding({ left: 10, right: 10 })
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  previewPanel(layer: GisLoadedLayer) {
    Column() {
      Row() {
        Text('字段与样例')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .layoutWeight(1)
        Text(this.activeFieldName())
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 12, right: 12, top: 12, bottom: 8 })
      if (layer.info.fields.length > 0 && !this.taskRequiresField()) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(layer.info.fields, (field: GisFieldInfo) => {
            this.fieldChip(field)
          }, (field: GisFieldInfo) => this.activeLayerKey() + ':preview-field:' + field.name)
        }
        .padding({ left: 12, right: 12, bottom: 8 })
      }
      ForEach(this.previewRows(layer), (row: GisFeatureSummary) => {
        this.previewRow(row)
      }, (row: GisFeatureSummary) => this.activeLayerKey() + ':preview-row:' + row.featureId)
    }
    .borderRadius(6)
    .clip(true)
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
            Text(this.activeLayerKey())
              .width(0)
              .height(0)
              .fontSize(0)
              .opacity(0)
            if (this.activeLayer() === undefined) {
              Column({ space: 8 }) {
                Text('当前没有已加载图层')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.gn_text_primary'))
                Text('先添加矢量数据后再打开表达式工作台。')
                  .fontSize(12)
                  .fontColor($r('app.color.gn_text_muted'))
              }
              .height(420)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            } else {
              this.overviewPanel(this.activeLayer() as GisLoadedLayer)
              this.expressionPanel(this.activeLayer() as GisLoadedLayer)
              this.previewPanel(this.activeLayer() as GisLoadedLayer)
            }
          }
          .padding(14)
        }
        .width('100%').height('100%')
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
          title: { mainTitle: $r('app.string.gn_expression_workbench_title') },
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
