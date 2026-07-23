import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import { MaterialStyle } from '@geonest/common';
import { CoordinateSystemPicker } from './CoordinateSystemPicker';
import { getGisService, GisLoadedLayer, GisService } from '../gis/GisService';
import {
  GisAttributeValue,
  GisCrsInfo,
  GisFeatureSummary,
  GisFieldInfo,
  GisGeoProcessResult,
  GisVectorSublayerInfo
} from '../model/GeoNestModels';

class XYTableLayerChoice {
  layerIndex: number = -1;
  name: string = '';
  meta: string = '';
  key: string = '';
  legacyXls: boolean = false;

  constructor(layerIndex: number, name: string, meta: string, key: string, legacyXls: boolean) {
    this.layerIndex = layerIndex;
    this.name = name;
    this.meta = meta;
    this.key = key;
    this.legacyXls = legacyXls;
  }
}

class XYTableFieldChoice {
  fieldIndex: number = -1;
  name: string = '';
  meta: string = '';
  key: string = '';

  constructor(fieldIndex: number, name: string, meta: string, key: string) {
    this.fieldIndex = fieldIndex;
    this.name = name;
    this.meta = meta;
    this.key = key;
  }
}

@Component
export struct XYTableToPointSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State private isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  onCompleted: (outputLayerIndex: number, result: GisGeoProcessResult) => void =
    (_outputLayerIndex: number, _result: GisGeoProcessResult): void => {};
  @State private sourceLayerIndex: number = -1;
  @State private xFieldIndex: number = -1;
  @State private yFieldIndex: number = -1;
  @State private zFieldIndex: number = -1;
  @State private mFieldIndex: number = -1;
  @State private worksheetChoices: GisVectorSublayerInfo[] = [];
  @State private worksheetUri: string = '';
  @State private separator: string = 'AUTO';
  @State private crsDefinition: string = 'EPSG:4326';
  @State private outputLayerName: string = '';
  @State private runStatus: string = '';
  @State private crsPickerTrigger: boolean = false;
  @State private uiRevision: number = 0;

  onTrigger(): void {
    this.prepareSelection();
    this.isShow = true;
  }

  private isTablePath(sourcePath: string): boolean {
    let lowerPath: string = sourcePath.toLowerCase();
    return lowerPath.endsWith('.csv') || lowerPath.endsWith('.xlsx') || lowerPath.endsWith('.xls') ||
      lowerPath.indexOf('.xlsx|') >= 0 || lowerPath.indexOf('.csv|') >= 0;
  }

  private isLegacyXlsPath(sourcePath: string): boolean {
    let lowerPath: string = sourcePath.toLowerCase();
    return lowerPath.endsWith('.xls') || lowerPath.indexOf('.xls|') >= 0;
  }

  private isCsvPath(sourcePath: string): boolean {
    return getGisService().tablePhysicalPath(sourcePath).toLowerCase().endsWith('.csv');
  }

  private isSpreadsheetPath(sourcePath: string): boolean {
    let lowerPath: string = getGisService().tablePhysicalPath(sourcePath).toLowerCase();
    return lowerPath.endsWith('.xlsx') || lowerPath.endsWith('.xls');
  }

  private isTableCandidate(layer: GisLoadedLayer): boolean {
    return layer.info.fields.length >= 2 && this.isTablePath(layer.sourcePath);
  }

  private buildLayerChoices(): XYTableLayerChoice[] {
    let choices: XYTableLayerChoice[] = [];
    let service: GisService = getGisService();
    for (let i = 0; i < service.getLayerCount(); i++) {
      let layer: GisLoadedLayer | undefined = service.getLayer(i);
      if (layer === undefined || !this.isTableCandidate(layer)) {
        continue;
      }
      let meta: string = layer.info.fields.length.toString() + ' 个字段 · ' +
        layer.info.featureCount.toString() + ' 行';
      let legacyXls: boolean = this.isLegacyXlsPath(layer.sourcePath);
      choices.push(new XYTableLayerChoice(i, layer.info.name, meta,
        layer.info.layerId + ':' + i.toString(), legacyXls));
    }
    return choices;
  }

  private currentLayer(): GisLoadedLayer | undefined {
    return getGisService().getLayer(this.sourceLayerIndex);
  }

  private currentLayerName(): string {
    let layer: GisLoadedLayer | undefined = this.currentLayer();
    if (layer === undefined) {
      return '';
    }
    return layer.info.name;
  }

  private currentWorksheetName(): string {
    for (let i = 0; i < this.worksheetChoices.length; i++) {
      if (this.worksheetChoices[i].uri === this.worksheetUri) {
        return this.worksheetChoices[i].name;
      }
    }
    return this.currentLayerName();
  }

  private refreshWorksheetChoices(layer: GisLoadedLayer): void {
    let service: GisService = getGisService();
    this.worksheetChoices = service.listVectorSublayers(layer.sourcePath);
    this.worksheetUri = layer.sourcePath;
    for (let i = 0; i < this.worksheetChoices.length; i++) {
      let candidate: GisVectorSublayerInfo = this.worksheetChoices[i];
      if (candidate.uri === layer.sourcePath || candidate.name === layer.info.name) {
        this.worksheetUri = candidate.uri;
        return;
      }
    }
    if (this.worksheetChoices.length > 0) {
      this.worksheetUri = this.worksheetChoices[0].uri;
    }
  }

  private currentFieldName(fieldIndex: number): string {
    let layer: GisLoadedLayer | undefined = this.currentLayer();
    if (layer === undefined || fieldIndex < 0 || fieldIndex >= layer.info.fields.length) {
      return '';
    }
    return layer.info.fields[fieldIndex].name;
  }

  private currentOptionalFieldName(fieldIndex: number): string {
    if (fieldIndex < 0) {
      return '不使用';
    }
    return this.currentFieldName(fieldIndex);
  }

  private separatorDisplayName(): string {
    if (this.separator === 'COMMA') return '逗号 (,)';
    if (this.separator === 'SEMICOLON') return '分号 (;)';
    if (this.separator === 'TAB') return '制表符 (Tab)';
    if (this.separator === 'PIPE') return '竖线 (|)';
    if (this.separator === 'SPACE') return '空格';
    return '自动检测';
  }

  private previewHeaderText(): string {
    let layer: GisLoadedLayer | undefined = this.currentLayer();
    if (layer === undefined) return '';
    let text: string = '';
    let count: number = layer.info.fields.length < 6 ? layer.info.fields.length : 6;
    for (let i = 0; i < count; i++) {
      if (i > 0) text += '  |  ';
      text += layer.info.fields[i].name;
    }
    return text;
  }

  private previewRowText(row: GisFeatureSummary): string {
    let text: string = '';
    let count: number = row.attributesPreview.length < 6 ? row.attributesPreview.length : 6;
    for (let i = 0; i < count; i++) {
      let attribute: GisAttributeValue = row.attributesPreview[i];
      if (i > 0) text += '  |  ';
      text += attribute.isNull ? 'NULL' : attribute.textValue;
    }
    return text;
  }

  private previewRows(): GisFeatureSummary[] {
    let rows: GisFeatureSummary[] = [];
    let layer: GisLoadedLayer | undefined = this.currentLayer();
    if (layer === undefined) return rows;
    let count: number = layer.features.length < 5 ? layer.features.length : 5;
    for (let i = 0; i < count; i++) rows.push(layer.features[i]);
    return rows;
  }

  private buildFieldChoices(): XYTableFieldChoice[] {
    let choices: XYTableFieldChoice[] = [];
    let layer: GisLoadedLayer | undefined = this.currentLayer();
    if (layer === undefined) {
      return choices;
    }
    for (let i = 0; i < layer.info.fields.length; i++) {
      let field: GisFieldInfo = layer.info.fields[i];
      let meta: string = field.typeName.length > 0 ? field.typeName : '字段';
      choices.push(new XYTableFieldChoice(i, field.name, meta,
        layer.info.layerId + ':' + i.toString() + ':' + field.name));
    }
    return choices;
  }

  private normalizedFieldName(field: GisFieldInfo): string {
    let text: string = field.name.toLowerCase();
    if (field.alias.length > 0) {
      text += ' ' + field.alias.toLowerCase();
    }
    return text;
  }

  private isLikelyXField(field: GisFieldInfo): boolean {
    let text: string = this.normalizedFieldName(field);
    return text === 'x' || text === 'lon' || text === 'lng' || text === 'longitude' ||
      text.indexOf('经度') >= 0 || text.indexOf('easting') >= 0 || text.indexOf('coord_x') >= 0;
  }

  private isLikelyYField(field: GisFieldInfo): boolean {
    let text: string = this.normalizedFieldName(field);
    return text === 'y' || text === 'lat' || text === 'latitude' || text.indexOf('纬度') >= 0 ||
      text.indexOf('northing') >= 0 || text.indexOf('coord_y') >= 0;
  }

  private isLikelyZField(field: GisFieldInfo): boolean {
    let text: string = this.normalizedFieldName(field);
    return text === 'z' || text === 'elevation' || text === 'height' || text.indexOf('高程') >= 0 ||
      text.indexOf('海拔') >= 0 || text.indexOf('coord_z') >= 0;
  }

  private isLikelyMField(field: GisFieldInfo): boolean {
    let text: string = this.normalizedFieldName(field);
    return text === 'm' || text === 'measure' || text.indexOf('里程') >= 0 || text.indexOf('coord_m') >= 0;
  }

  private autoSelectFields(layer: GisLoadedLayer): void {
    this.xFieldIndex = -1;
    this.yFieldIndex = -1;
    this.zFieldIndex = -1;
    this.mFieldIndex = -1;
    for (let i = 0; i < layer.info.fields.length; i++) {
      let field: GisFieldInfo = layer.info.fields[i];
      if (this.xFieldIndex < 0 && this.isLikelyXField(field)) {
        this.xFieldIndex = i;
      }
      if (this.yFieldIndex < 0 && this.isLikelyYField(field)) {
        this.yFieldIndex = i;
      }
      if (this.zFieldIndex < 0 && this.isLikelyZField(field)) {
        this.zFieldIndex = i;
      }
      if (this.mFieldIndex < 0 && this.isLikelyMField(field)) {
        this.mFieldIndex = i;
      }
    }
    if (this.xFieldIndex < 0 && layer.info.fields.length > 0) {
      this.xFieldIndex = 0;
    }
    if (this.yFieldIndex < 0 && layer.info.fields.length > 1) {
      this.yFieldIndex = this.xFieldIndex === 0 ? 1 : 0;
    }
  }

  private safeOutputName(source: string): string {
    let result: string = '';
    for (let i = 0; i < source.length; i++) {
      let ch: string = source.charAt(i);
      if (ch === '/' || ch === '\\' || ch === ':' || ch === '*' || ch === '?' || ch === '"' ||
        ch === '<' || ch === '>' || ch === '|') {
        result += '_';
      } else {
        result += ch;
      }
    }
    if (result.trim().length === 0) {
      return 'xy_points';
    }
    return result.trim();
  }

  private selectLayer(layerIndex: number): void {
    this.sourceLayerIndex = layerIndex;
    let layer: GisLoadedLayer | undefined = this.currentLayer();
    if (layer === undefined) {
      this.xFieldIndex = -1;
      this.yFieldIndex = -1;
      this.zFieldIndex = -1;
      this.mFieldIndex = -1;
      this.worksheetChoices = [];
      this.worksheetUri = '';
      this.outputLayerName = '';
      this.runStatus = '';
      this.uiRevision++;
      return;
    }
    this.refreshWorksheetChoices(layer);
    this.autoSelectFields(layer);
    this.outputLayerName = this.safeOutputName(layer.info.name + '_points');
    this.runStatus = '';
    this.uiRevision++;
  }

  private reopenConfiguredTable(sourceUri: string, separator: string): void {
    let service: GisService = getGisService();
    let newLayerIndex: number = service.openConfiguredTableLayer(sourceUri, separator);
    if (newLayerIndex < 0) {
      this.runStatus = '无法按所选工作表或分隔符读取数据';
      return;
    }
    this.selectLayer(newLayerIndex);
  }

  private selectWorksheet(item: GisVectorSublayerInfo): void {
    this.worksheetUri = item.uri;
    this.reopenConfiguredTable(item.uri, 'AUTO');
  }

  private selectSeparator(value: string): void {
    this.separator = value;
    let layer: GisLoadedLayer | undefined = this.currentLayer();
    if (layer === undefined) {
      return;
    }
    let sourceUri: string = getGisService().tablePhysicalPath(layer.sourcePath);
    this.reopenConfiguredTable(sourceUri, value);
  }

  private prepareSelection(): void {
    let service: GisService = getGisService();
    let activeIndex: number = service.getActiveLayerIndex();
    let activeLayer: GisLoadedLayer | undefined = service.getLayer(activeIndex);
    if (activeLayer !== undefined && this.isTableCandidate(activeLayer)) {
      this.selectLayer(activeIndex);
      return;
    }
    let choices: XYTableLayerChoice[] = this.buildLayerChoices();
    if (choices.length > 0) {
      this.selectLayer(choices[0].layerIndex);
      return;
    }
    this.selectLayer(-1);
  }

  private canRun(): boolean {
    let layer: GisLoadedLayer | undefined = this.currentLayer();
    if (layer === undefined) {
      return false;
    }
    let zValid: boolean = this.zFieldIndex < 0 || (this.zFieldIndex !== this.xFieldIndex &&
      this.zFieldIndex !== this.yFieldIndex);
    let mValid: boolean = this.mFieldIndex < 0 || (this.mFieldIndex !== this.xFieldIndex &&
      this.mFieldIndex !== this.yFieldIndex && this.mFieldIndex !== this.zFieldIndex);
    return this.xFieldIndex >= 0 && this.yFieldIndex >= 0 && this.xFieldIndex !== this.yFieldIndex && zValid && mValid &&
      this.outputLayerName.trim().length > 0 && this.crsDefinition.trim().length > 0;
  }

  private buildOutputPath(outputLayerName: string): string {
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let outputDirectory: string = getGisService().processingOutputDirectory();
    if (outputDirectory.length === 0) {
      outputDirectory = context.filesDir + '/geonest_outputs';
    }
    try {
      fs.mkdirSync(outputDirectory, true);
    } catch (e) {
    }
    return outputDirectory + '/' + outputLayerName + '_' + Date.now().toString() + '.gpkg';
  }

  private runConversion(): void {
    if (!this.canRun()) {
      this.runStatus = '请选择不同的 X/Y 字段、有效坐标系和输出名称';
      return;
    }
    let service: GisService = getGisService();
    let crsInfo: GisCrsInfo = service.describeCoordinateReferenceSystem(this.crsDefinition.trim());
    if (!crsInfo.ok || !crsInfo.isValid) {
      this.runStatus = '坐标系无法识别，请重新选择';
      return;
    }
    let outputName: string = this.safeOutputName(this.outputLayerName);
    let outputPath: string = this.buildOutputPath(outputName);
    let result: GisGeoProcessResult = service.runXYTableToPoints(this.sourceLayerIndex, this.xFieldIndex,
      this.yFieldIndex, this.zFieldIndex, this.mFieldIndex, this.crsDefinition.trim(), outputPath, outputName);
    if (!result.ok) {
      this.runStatus = '转换失败：' + result.message;
      return;
    }
    if (result.outputLoaded) {
      this.runStatus = '转换完成：已生成并加载 ' + result.featureCount.toString() + ' 个点；' + result.message;
      this.onCompleted(service.getActiveLayerIndex(), result);
    } else {
      this.runStatus = '转换完成：已生成 ' + result.featureCount.toString() + ' 个点，未自动加载；' + result.message;
    }
  }

  @Builder
  layerPickerMenu() {
    Menu() {
      ForEach(this.buildLayerChoices(), (item: XYTableLayerChoice) => {
        MenuItem({ content: item.name + ' · ' + item.meta })
          .onClick(() => {
            this.selectLayer(item.layerIndex);
          })
      }, (item: XYTableLayerChoice) => 'xy-layer:' + item.key)
    }
  }

  @Builder
  xFieldMenu() {
    Menu() {
      ForEach(this.buildFieldChoices(), (item: XYTableFieldChoice) => {
        MenuItem({ content: item.name + ' · ' + item.meta })
          .onClick(() => {
            this.xFieldIndex = item.fieldIndex;
            this.uiRevision++;
          })
      }, (item: XYTableFieldChoice) => 'xy-x:' + item.key)
    }
  }

  @Builder
  yFieldMenu() {
    Menu() {
      ForEach(this.buildFieldChoices(), (item: XYTableFieldChoice) => {
        MenuItem({ content: item.name + ' · ' + item.meta })
          .onClick(() => {
            this.yFieldIndex = item.fieldIndex;
            this.uiRevision++;
          })
      }, (item: XYTableFieldChoice) => 'xy-y:' + item.key)
    }
  }

  @Builder
  zFieldMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.gn_xy_table_none') })
        .onClick(() => {
          this.zFieldIndex = -1;
          this.uiRevision++;
        })
      ForEach(this.buildFieldChoices(), (item: XYTableFieldChoice) => {
        MenuItem({ content: item.name + ' · ' + item.meta })
          .onClick(() => {
            this.zFieldIndex = item.fieldIndex;
            this.uiRevision++;
          })
      }, (item: XYTableFieldChoice) => 'xy-z:' + item.key)
    }
  }

  @Builder
  mFieldMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.gn_xy_table_none') })
        .onClick(() => {
          this.mFieldIndex = -1;
          this.uiRevision++;
        })
      ForEach(this.buildFieldChoices(), (item: XYTableFieldChoice) => {
        MenuItem({ content: item.name + ' · ' + item.meta })
          .onClick(() => {
            this.mFieldIndex = item.fieldIndex;
            this.uiRevision++;
          })
      }, (item: XYTableFieldChoice) => 'xy-m:' + item.key)
    }
  }

  @Builder
  worksheetMenu() {
    Menu() {
      ForEach(this.worksheetChoices, (item: GisVectorSublayerInfo) => {
        MenuItem({ content: item.name })
          .onClick(() => {
            this.selectWorksheet(item);
          })
      }, (item: GisVectorSublayerInfo) => 'xy-sheet:' + item.uri)
    }
  }

  @Builder
  separatorMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.gn_xy_table_separator_auto') }).onClick(() => { this.selectSeparator('AUTO'); })
      MenuItem({ content: $r('app.string.gn_xy_table_separator_comma') }).onClick(() => { this.selectSeparator('COMMA'); })
      MenuItem({ content: $r('app.string.gn_xy_table_separator_semicolon') }).onClick(() => { this.selectSeparator('SEMICOLON'); })
      MenuItem({ content: $r('app.string.gn_xy_table_separator_tab') }).onClick(() => { this.selectSeparator('TAB'); })
      MenuItem({ content: $r('app.string.gn_xy_table_separator_pipe') }).onClick(() => { this.selectSeparator('PIPE'); })
      MenuItem({ content: $r('app.string.gn_xy_table_separator_space') }).onClick(() => { this.selectSeparator('SPACE'); })
    }
  }

  @Builder
  pickerButton(value: string, menuMode: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 8 }) {
        Text(value.length > 0 ? value : '请选择')
          .fontSize(13)
          .fontColor(value.length > 0 ? $r('app.color.gn_text_primary') : $r('app.color.gn_text_muted'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(13)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .width('100%')
    }
    .height(38)
    .padding({ left: 10, right: 10 })
    .backgroundColor($r('app.color.gn_pane'))
    .borderRadius(6)
    .bindMenu(menuMode === 0 ? this.layerPickerMenu : (menuMode === 1 ? this.xFieldMenu :
      (menuMode === 2 ? this.yFieldMenu : (menuMode === 3 ? this.zFieldMenu : this.mFieldMenu))))
  }

  @Builder
  labeledPicker(label: ResourceStr, value: string, menuMode: number) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
      this.pickerButton(value, menuMode)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  worksheetPicker() {
    Column({ space: 6 }) {
      Text($r('app.string.gn_xy_table_worksheet')).fontSize(12).fontColor($r('app.color.gn_text_muted')).width('100%')
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 8 }) {
          Text(this.currentWorksheetName()).fontSize(13).fontColor($r('app.color.gn_text_primary'))
            .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(13).fontColor([$r('sys.color.icon_secondary')])
        }.width('100%')
      }
      .height(38).padding({ left: 10, right: 10 }).backgroundColor($r('app.color.gn_pane')).borderRadius(6)
      .bindMenu(this.worksheetMenu)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  separatorPicker() {
    Column({ space: 6 }) {
      Text($r('app.string.gn_xy_table_separator')).fontSize(12).fontColor($r('app.color.gn_text_muted')).width('100%')
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 8 }) {
          Text(this.separatorDisplayName()).fontSize(13).fontColor($r('app.color.gn_text_primary')).layoutWeight(1)
          SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(13).fontColor([$r('sys.color.icon_secondary')])
        }.width('100%')
      }
      .height(38).padding({ left: 10, right: 10 }).backgroundColor($r('app.color.gn_pane')).borderRadius(6)
      .bindMenu(this.separatorMenu)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  previewPanel() {
    Column({ space: 7 }) {
      Row() {
        Text($r('app.string.gn_xy_table_preview')).fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary')).layoutWeight(1)
        Text(this.previewRows().length.toString() + ' / ' +
          ((this.currentLayer() as GisLoadedLayer).info.featureCount.toString()))
          .fontSize(11).fontColor($r('app.color.gn_text_muted'))
      }.width('100%')
      Text(this.previewHeaderText()).fontSize(11).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_blue_800')).width('100%').maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.previewRows().length === 0) {
        Text($r('app.string.gn_xy_table_preview_empty')).fontSize(11)
          .fontColor($r('app.color.gn_text_muted')).width('100%')
      } else {
        ForEach(this.previewRows(), (row: GisFeatureSummary) => {
          Text(this.previewRowText(row)).fontSize(11).fontColor($r('app.color.gn_text_primary'))
            .width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }, (row: GisFeatureSummary) => 'xy-preview:' + row.featureId)
      }
    }
    .width('100%').padding(10).borderRadius(6).backgroundColor($r('app.color.gn_pane_alt'))
  }

  @Builder
  configurationPanel() {
    Column({ space: 12 }) {
      Text($r('app.string.gn_xy_table_desc'))
        .fontSize(13)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')

      this.labeledPicker($r('app.string.gn_xy_table_source'), this.currentLayerName(), 0)
      Text($r('app.string.gn_xy_table_source_hint'))
        .fontSize(11)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')

      if (this.currentLayer() !== undefined &&
        this.isSpreadsheetPath((this.currentLayer() as GisLoadedLayer).sourcePath)) {
        this.worksheetPicker()
      }

      if (this.currentLayer() !== undefined && this.isCsvPath((this.currentLayer() as GisLoadedLayer).sourcePath)) {
        this.separatorPicker()
      }

      Row({ space: 10 }) {
        this.labeledPicker($r('app.string.gn_xy_table_x_field'), this.currentFieldName(this.xFieldIndex), 1)
        this.labeledPicker($r('app.string.gn_xy_table_y_field'), this.currentFieldName(this.yFieldIndex), 2)
      }
      .width('100%')

      Row({ space: 10 }) {
        this.labeledPicker($r('app.string.gn_xy_table_z_field'), this.currentOptionalFieldName(this.zFieldIndex), 3)
        this.labeledPicker($r('app.string.gn_xy_table_m_field'), this.currentOptionalFieldName(this.mFieldIndex), 4)
      }
      .width('100%')

      this.previewPanel()

      Column({ space: 6 }) {
        Text($r('app.string.gn_xy_table_crs'))
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.map'))
              .fontSize(16)
              .fontColor([$r('app.color.gn_blue_800')])
            Text(this.crsDefinition)
              .fontSize(13)
              .fontColor($r('app.color.gn_text_primary'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(13)
              .fontColor([$r('sys.color.icon_secondary')])
          }
          .width('100%')
        }
        .height(38)
        .padding({ left: 10, right: 10 })
        .backgroundColor($r('app.color.gn_pane'))
        .borderRadius(6)
        .onClick(() => {
          this.crsPickerTrigger = !this.crsPickerTrigger;
        })
      }
      .width('100%')

      Column({ space: 6 }) {
        Text($r('app.string.gn_xy_table_output'))
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
        TextInput({ text: this.outputLayerName, placeholder: 'xy_points' })
          .height(38)
          .fontSize(13)
          .backgroundColor($r('app.color.gn_pane'))
          .onChange((value: string) => {
            this.outputLayerName = value;
          })
      }
      .width('100%')

      Text($r('app.string.gn_xy_table_gpkg_hint'))
        .fontSize(11)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')

      if (this.runStatus.length > 0) {
        Text(this.runStatus)
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
      }

      Button($r('app.string.gn_xy_table_generate'), { type: ButtonType.Capsule, stateEffect: true })
        .width('100%')
        .height(42)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(this.canRun() ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
        .enabled(this.canRun())
        .onClick(() => {
          this.runConversion();
        })
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
            Text(this.uiRevision.toString())
              .width(0)
              .height(0)
              .fontSize(0)
              .opacity(0)
            if (this.buildLayerChoices().length === 0) {
              Column({ space: 10 }) {
                SymbolGlyph($r('sys.symbol.location_up'))
                  .fontSize(32)
                  .fontColor([$r('sys.color.icon_secondary')])
                Text($r('app.string.gn_xy_table_empty'))
                  .fontSize(14)
                  .fontColor($r('app.color.gn_text_muted'))
                  .textAlign(TextAlign.Center)
              }
              .height(360)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            } else {
              this.configurationPanel()
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
          title: { mainTitle: $r('app.string.gn_xy_table_title') },
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
      CoordinateSystemPicker({
        trigger: this.crsPickerTrigger,
        currentDefinition: this.crsDefinition,
        onSelected: (definition: string) => {
          this.crsDefinition = definition;
          this.uiRevision++;
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Row().width(0).height(0)
      .bindSheet($$this.isShow, this.sheetContent(), {
        width: 760,
        height: 650,
        detents: [650],
        preferType: SheetType.CENTER,
        dragBar: false,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.Regular,
        showClose: false,
        onDisappear: (): void => { this.isShow = false; }
      })
  }
}
