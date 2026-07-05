import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '../utils/MaterialStyle';
import { getGisService, GisLoadedLayer } from '../gis/GisService';
import { GisOperationResult, GisCrsInfo, GisGeoProcessResult } from '../model/GeoNestModels';
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import { CoordinateSystemPicker } from './CoordinateSystemPicker';

class DialogLayerChoice {
  name: string = '';
  meta: string = '';
  key: string = '';
}

class ShapefileSidecar {
  extension: string = '';
  suffixChoice: string = '';

  constructor(extension: string, suffixChoice: string) {
    this.extension = extension;
    this.suffixChoice = suffixChoice;
  }
}

@Component
export struct ToolRunnerSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  toolMode: number = 1;
  onToolCompleted: () => void = () => {};
  onChooseLocalLayer: (fieldIndex: number, onSelected: (layerName: string) => void) => void =
    (_fieldIndex: number, _onSelected: (layerName: string) => void) => {};
  @State private inputName: string = '';
  @State private clipName: string = '';
  @State private outputName: string = '';
  @State private runStatus: string = '待运行';
  @State private inputFieldRevision: number = 0;
  @State private clipFieldRevision: number = 0;
  @State private outputFieldRevision: number = 0;
  @State private uiRevision: number = 0;
  @State private crsPickerTrigger: boolean = false;

  onTrigger(): void {
    this.isShow = true;
  }

  private getActiveLayer(): GisLoadedLayer | undefined {
    return getGisService().getActiveLayer();
  }

  private activeLayerName(): string {
    let layer = this.getActiveLayer();
    if (layer !== undefined) {
      return layer.info.name;
    }
    return '未选择图层';
  }

  private inputLayerIndex(): number {
    let service = getGisService();
    let index = service.findLayerIndexByName(this.inputValue());
    if (index >= 0) {
      return index;
    }
    return service.getActiveLayerIndex();
  }

  private defaultClipLayerName(): string {
    let service = getGisService();
    let otherIndex = service.firstOtherLayerIndex(this.inputLayerIndex());
    let layer = service.getLayer(otherIndex);
    if (layer !== undefined) {
      return layer.info.name;
    }
    return '请选择另一个图层';
  }

  private requiresTargetCrs(): boolean {
    return this.toolMode === 5 || this.toolMode === 6;
  }

  private shouldOfferLocalShapefileSave(): boolean {
    return this.toolMode >= 4 && this.toolMode <= 9;
  }

  private requiresSecondaryInput(): boolean {
    return this.toolMode !== 4 && this.toolMode !== 8 && this.toolMode !== 9;
  }

  private defaultTargetCrs(): string {
    return 'EPSG:4490';
  }

  private targetCrsValidationText(): string {
    if (!this.requiresTargetCrs()) {
      return '';
    }
    let definition = this.secondaryValue().trim();
    if (definition.length === 0) {
      return '目标坐标系：未填写';
    }
    let info: GisCrsInfo = getGisService().describeCoordinateReferenceSystem(definition);
    if (!info.ok || !info.isValid) {
      return '目标坐标系：无法识别';
    }
    let typeText = info.isGeographic ? '地理坐标系' : '投影坐标系';
    let unitText = info.unitName.length > 0 ? info.unitName : '未知单位';
    let authText = info.authId.length > 0 ? info.authId : definition;
    if (info.isGeographic) {
      let ellipsoidText = info.ellipsoidAcronym.length > 0 ? ' · 椭球 ' + info.ellipsoidAcronym : '';
      return '目标坐标系：' + authText + ' · ' + typeText + ellipsoidText + ' · 单位 ' + unitText;
    }
    let geographicText = info.geographicCrsAuthId.length > 0 ? info.geographicCrsAuthId : '地理坐标系未声明';
    let projectionText = info.projectionAcronym.length > 0 ? info.projectionAcronym : '投影方法未声明';
    return '目标坐标系：' + authText + ' · ' + typeText + ' · 地理坐标系 ' + geographicText + ' · ' +
      projectionText + ' · 单位 ' + unitText;
  }

  private toolTitle(): string {
    if (this.toolMode === 2) {
      return '缓冲区';
    }
    if (this.toolMode === 3) {
      return '修复几何';
    }
    if (this.toolMode === 4) {
      return '导出 Shapefile';
    }
    if (this.toolMode === 5) {
      return '定义投影';
    }
    if (this.toolMode === 6) {
      return '投影转换';
    }
    if (this.toolMode === 7) {
      return '简化几何';
    }
    if (this.toolMode === 8) {
      return '融合全部';
    }
    if (this.toolMode === 9) {
      return '生成质心';
    }
    return '裁剪';
  }

  private toolDescription(): string {
    if (this.toolMode === 2) {
      return '使用当前图层生成缓冲分析参数。';
    }
    if (this.toolMode === 3) {
      return '检查当前图层几何并准备修复任务。';
    }
    if (this.toolMode === 4) {
      return '将当前图层写出为新的 Shapefile 成果。';
    }
    if (this.toolMode === 5) {
      return '为当前图层写入新的 CRS 定义，不改变坐标。';
    }
    if (this.toolMode === 6) {
      return '把当前图层几何转换到目标 CRS 并输出成果。';
    }
    if (this.toolMode === 7) {
      return '使用 QgsGeometry::simplify 按坐标单位容差简化几何。';
    }
    if (this.toolMode === 8) {
      return '使用 QgsGeometry::unaryUnion 将全部要素融合为一个要素。';
    }
    if (this.toolMode === 9) {
      return '使用 QgsGeometry::centroid 为每个要素生成质心点。';
    }
    return '使用当前图层配置裁剪输入和输出。';
  }

  private toolIcon(): Resource {
    if (this.toolMode === 2) {
      return $r('sys.symbol.circle_grid_2x2');
    }
    if (this.toolMode === 3) {
      return $r('sys.symbol.wrench_arrow_counterclockwise');
    }
    if (this.toolMode === 4) {
      return $r('sys.symbol.download');
    }
    if (this.toolMode === 5) {
      return $r('sys.symbol.map');
    }
    if (this.toolMode === 6) {
      return $r('sys.symbol.arrow_right_and_square');
    }
    if (this.toolMode === 7) {
      return $r('sys.symbol.arrow_down_right_and_arrow_up_left');
    }
    if (this.toolMode === 8) {
      return $r('sys.symbol.square_and_square');
    }
    if (this.toolMode === 9) {
      return $r('sys.symbol.location_up');
    }
    return $r('sys.symbol.square_dashed_and_arrow_turn_up_right');
  }

  private secondaryLabel(): string {
    if (this.toolMode === 2) {
      return '缓冲距离';
    }
    if (this.toolMode === 3) {
      return '修复规则';
    }
    if (this.toolMode === 4) {
      return '导出格式';
    }
    if (this.requiresTargetCrs()) {
      return '目标坐标系';
    }
    if (this.toolMode === 7) {
      return '简化容差';
    }
    return '裁剪要素';
  }

  private secondaryValue(): string {
    if (this.clipName.length > 0) {
      return this.clipName;
    }
    if (this.toolMode === 2) {
      return '0';
    }
    if (this.toolMode === 3) {
      return '自相交、空几何、重复节点';
    }
    if (this.toolMode === 4) {
      return 'ESRI Shapefile';
    }
    if (this.requiresTargetCrs()) {
      return this.defaultTargetCrs();
    }
    if (this.toolMode === 7) {
      return '1';
    }
    return this.defaultClipLayerName();
  }

  private outputValue(): string {
    if (this.outputName.length > 0) {
      return this.outputName;
    }
    let baseName = this.inputValue();
    if (this.toolMode === 2) {
      return baseName + '_buffer';
    }
    if (this.toolMode === 3) {
      return baseName + '_repaired';
    }
    if (this.toolMode === 4) {
      return baseName + '_export';
    }
    if (this.toolMode === 5) {
      return baseName + '_defined_crs';
    }
    if (this.toolMode === 6) {
      return baseName + '_projected';
    }
    if (this.toolMode === 7) {
      return baseName + '_simplified';
    }
    if (this.toolMode === 8) {
      return baseName + '_dissolved';
    }
    if (this.toolMode === 9) {
      return baseName + '_centroids';
    }
    return baseName + '_clip';
  }

  private inputValue(): string {
    if (this.inputName.length > 0) {
      return this.inputName;
    }
    return this.activeLayerName();
  }

  private isInvalidFileChar(value: string): boolean {
    return value === '/' || value === '\\' || value === ':' || value === '*' || value === '?' ||
      value === '"' || value === '<' || value === '>' || value === '|';
  }

  private safeOutputLayerName(): string {
    let source = this.outputValue();
    if (source.toLowerCase().endsWith('.shp')) {
      source = source.substring(0, source.length - 4);
    }
    let result = '';
    for (let i = 0; i < source.length; i++) {
      let ch = source.charAt(i);
      if (this.isInvalidFileChar(ch)) {
        result += '_';
      } else {
        result += ch;
      }
    }
    if (result.length === 0) {
      return 'geonest_output';
    }
    return result;
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

  private shapefileSidecars(): ShapefileSidecar[] {
    return [
      new ShapefileSidecar('.shp', 'Shapefile 主文件|.shp'),
      new ShapefileSidecar('.shx', 'Shapefile 索引|.shx'),
      new ShapefileSidecar('.dbf', 'Shapefile 属性表|.dbf'),
      new ShapefileSidecar('.prj', '坐标系定义|.prj'),
      new ShapefileSidecar('.cpg', '字符编码|.cpg')
    ];
  }

  private outputBasePath(outputPath: string): string {
    if (outputPath.toLowerCase().endsWith('.shp')) {
      return outputPath.substring(0, outputPath.length - 4);
    }
    return outputPath;
  }

  private sourceFileExists(sourcePath: string): boolean {
    try {
      let sourceFile = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);
      fs.closeSync(sourceFile.fd);
      return true;
    } catch (e) {
      return false;
    }
  }

  private copySourceToUri(sourcePath: string, targetUri: string): boolean {
    let sourceFd: number = -1;
    let targetFd: number = -1;
    try {
      let sourceFile = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);
      sourceFd = sourceFile.fd;
      let targetFile = fs.openSync(targetUri, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      targetFd = targetFile.fd;
      fs.copyFileSync(sourceFd, targetFd);
      return true;
    } catch (e) {
      this.runStatus = '本地保存失败：' + String(e);
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

  private buildShapefileSaveOptions(outputPath: string, outputLayerName: string): picker.DocumentSaveOptions {
    let options = new picker.DocumentSaveOptions();
    let names: string[] = [];
    let suffixChoices: string[] = [];
    let basePath = this.outputBasePath(outputPath);
    let sidecars = this.shapefileSidecars();
    for (let i = 0; i < sidecars.length; i++) {
      let item = sidecars[i];
      let sourcePath = basePath + item.extension;
      if (this.sourceFileExists(sourcePath)) {
        names.push(outputLayerName + item.extension);
        suffixChoices.push(item.suffixChoice);
      }
    }
    options.newFileNames = names;
    options.fileSuffixChoices = suffixChoices;
    return options;
  }

  private exportedShapefileFileCount(outputPath: string): number {
    let count = 0;
    let basePath = this.outputBasePath(outputPath);
    let sidecars = this.shapefileSidecars();
    for (let i = 0; i < sidecars.length; i++) {
      if (this.sourceFileExists(basePath + sidecars[i].extension)) {
        count++;
      }
    }
    return count;
  }

  private exportedShapefileExtensionSummary(outputPath: string): string {
    let summary = '';
    let basePath = this.outputBasePath(outputPath);
    let sidecars = this.shapefileSidecars();
    for (let i = 0; i < sidecars.length; i++) {
      let item = sidecars[i];
      if (this.sourceFileExists(basePath + item.extension)) {
        if (summary.length > 0) {
          summary += '、';
        }
        summary += item.extension;
      }
    }
    return summary;
  }

  private appendShapefileExtensionSummary(summary: string, extension: string): string {
    if (summary.length > 0) {
      return summary + '、' + extension;
    }
    return extension;
  }

  private saveExportedShapefileToFiles(outputPath: string, outputLayerName: string): void {
    let expectedCount = this.exportedShapefileFileCount(outputPath);
    if (expectedCount === 0) {
      this.runStatus = '成果已加载结果图层，但未找到可保存的 Shapefile 文件组';
      return;
    }
    let expectedExtensions = this.exportedShapefileExtensionSummary(outputPath);
    try {
      let options = this.buildShapefileSaveOptions(outputPath, outputLayerName);
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      documentPicker.save(options).then((uris: Array<string>) => {
        let basePath = this.outputBasePath(outputPath);
        let sidecars = this.shapefileSidecars();
        let uriIndex = 0;
        let copiedCount = 0;
        let copiedExtensions = '';
        for (let i = 0; i < sidecars.length; i++) {
          let item = sidecars[i];
          let sourcePath = basePath + item.extension;
          if (!this.sourceFileExists(sourcePath)) {
            continue;
          }
          if (uriIndex >= uris.length) {
            break;
          }
          if (this.copySourceToUri(sourcePath, uris[uriIndex])) {
            copiedCount++;
            copiedExtensions = this.appendShapefileExtensionSummary(copiedExtensions, item.extension);
          }
          uriIndex++;
        }
        if (copiedCount === expectedCount) {
          this.runStatus = '完成：已加载结果图层，并保存 ' + copiedCount.toString() + '/' +
            expectedCount.toString() + ' 个 Shapefile 文件到本地（' + copiedExtensions + '）';
        } else if (copiedCount > 0) {
          this.runStatus = '本地保存不完整：已保存 ' + copiedCount.toString() + '/' +
            expectedCount.toString() + ' 个（' + copiedExtensions + '），应包含 ' + expectedExtensions;
        } else {
          this.runStatus = '成果已加载结果图层，但本地文件未写入；应保存 ' + expectedCount.toString() +
            ' 个文件（' + expectedExtensions + '）';
        }
      }).catch(() => {
        this.runStatus = '完成：已加载结果图层；已取消本地文件保存';
      });
    } catch (e) {
      this.runStatus = '成果已加载结果图层，本地保存失败：' + String(e);
    }
  }

  private buildLayerChoiceList(): DialogLayerChoice[] {
    let result: DialogLayerChoice[] = [];
    let service = getGisService();
    for (let i = 0; i < service.getLayerCount(); i++) {
      let layer = service.getLayer(i);
      if (layer !== undefined) {
        let choice = new DialogLayerChoice();
        choice.name = layer.info.name;
        choice.meta = layer.info.featureCount.toString() + ' 要素 · ' + layer.info.fields.length.toString() +
          ' 字段 · ' + (layer.visible ? '可见' : '隐藏');
        choice.key = i.toString() + ':' + layer.info.layerId + ':' + layer.info.name;
        result.push(choice);
      }
    }
    return result;
  }

  private refreshInputLayerChoice(layerName: string): void {
    this.inputName = layerName;
    this.inputFieldRevision++;
    if (this.clipName.length === 0) {
      this.clipFieldRevision++;
    }
    if (this.outputName.length === 0) {
      this.outputFieldRevision++;
    }
    this.uiRevision++;
  }

  private refreshClipLayerChoice(layerName: string): void {
    this.clipName = layerName;
    this.clipFieldRevision++;
    this.uiRevision++;
  }

  private chooseLocalLayer(fieldIndex: number): void {
    this.onChooseLocalLayer(fieldIndex, (layerName: string) => {
      if (fieldIndex === 0) {
        this.refreshInputLayerChoice(layerName);
      } else {
        this.refreshClipLayerChoice(layerName);
      }
    });
  }

  private chooseCoordinateSystem(definition: string): void {
    this.clipName = definition;
    this.clipFieldRevision++;
    this.runStatus = '已选择目标坐标系：' + definition;
    this.uiRevision++;
  }

  private fieldValue(fieldIndex: number): string {
    if (fieldIndex === 0) {
      return this.inputValue();
    }
    if (fieldIndex === 1) {
      return this.secondaryValue();
    }
    return this.outputValue();
  }

  private fieldRenderKey(fieldIndex: number): string {
    if (fieldIndex === 0) {
      return 'input:' + this.inputFieldRevision.toString() + ':' + this.inputValue();
    }
    if (fieldIndex === 1) {
      return 'secondary:' + this.clipFieldRevision.toString() + ':' + this.secondaryValue();
    }
    return 'output:' + this.outputFieldRevision.toString() + ':' + this.outputValue();
  }

  private fieldRenderKeys(fieldIndex: number): string[] {
    let result: string[] = [];
    result.push(this.fieldRenderKey(fieldIndex));
    return result;
  }

  private runTool(): void {
    let service = getGisService();
    let inputIndex = this.inputLayerIndex();
    if (service.getLayer(inputIndex) === undefined || inputIndex < 0) {
      this.runStatus = '未选择图层，无法运行';
      return;
    }
    let outputLayerName = this.safeOutputLayerName();
    let outputPath = this.buildOutputPath(outputLayerName);
    let result: GisGeoProcessResult = new GisGeoProcessResult(false, 0, '', outputPath, outputLayerName, 0);
    if (this.toolMode === 2) {
      let distance = Number(this.secondaryValue());
      if (distance <= 0) {
        this.runStatus = '请输入大于 0 的缓冲距离；单位为当前图层坐标单位';
        return;
      }
      result = service.runBuffer(inputIndex, distance, outputPath, outputLayerName);
    } else if (this.toolMode === 3) {
      result = service.runRepair(inputIndex, outputPath, outputLayerName);
    } else if (this.toolMode === 4) {
      result = service.runExport(inputIndex, outputPath, outputLayerName);
    } else if (this.toolMode === 7) {
      let tolerance = Number(this.secondaryValue());
      if (tolerance <= 0) {
        this.runStatus = '请输入大于 0 的简化容差；单位为当前图层坐标单位';
        return;
      }
      result = service.runSimplify(inputIndex, tolerance, outputPath, outputLayerName);
    } else if (this.toolMode === 8) {
      result = service.runDissolve(inputIndex, outputPath, outputLayerName);
    } else if (this.toolMode === 9) {
      result = service.runCentroid(inputIndex, outputPath, outputLayerName);
    } else if (this.toolMode === 5 || this.toolMode === 6) {
      let targetDefinition = this.secondaryValue().trim();
      if (targetDefinition.length === 0) {
        this.runStatus = '请输入目标坐标系，例如 EPSG:4490';
        return;
      }
      let targetInfo: GisCrsInfo = service.describeCoordinateReferenceSystem(targetDefinition);
      if (!targetInfo.ok || !targetInfo.isValid) {
        this.runStatus = '目标坐标系无法识别，请输入 EPSG、WKT 或 PROJ 定义';
        return;
      }
      if (this.toolMode === 5) {
        result = service.runDefineProjection(inputIndex, targetDefinition, outputPath, outputLayerName);
      } else {
        result = service.runProjectLayer(inputIndex, targetDefinition, outputPath, outputLayerName);
      }
    } else {
      let clipLayerName = this.secondaryValue();
      let clipIndex = service.findLayerIndexByName(clipLayerName);
      if (clipIndex < 0 || clipIndex === inputIndex) {
        clipIndex = service.firstOtherLayerIndex(inputIndex);
      }
      if (clipIndex < 0 || clipIndex === inputIndex) {
        this.runStatus = '裁剪需要另一个真实图层作为裁剪范围';
        return;
      }
      result = service.runClip(inputIndex, clipIndex, outputPath, outputLayerName);
    }
    if (result.ok) {
      this.runStatus = '完成：输出 ' + result.featureCount.toString() + ' 个要素，已加载结果图层';
      this.onToolCompleted();
      if (this.shouldOfferLocalShapefileSave()) {
        this.runStatus = '完成：输出 ' + result.featureCount.toString() + ' 个要素，正在选择本地保存位置';
        this.saveExportedShapefileToFiles(result.outputPath, outputLayerName);
      }
    } else {
      this.runStatus = '失败：' + result.message;
    }
  }

  @Builder
  inputLayerPickerMenu() {
    Menu() {
      ForEach(this.buildLayerChoiceList(), (item: DialogLayerChoice) => {
        MenuItem({ content: item.name + ' · ' + item.meta })
          .onClick(() => {
            this.refreshInputLayerChoice(item.name);
          })
      }, (item: DialogLayerChoice) => 'input:' + item.key)
    }
  }

  @Builder
  clipLayerPickerMenu() {
    Menu() {
      ForEach(this.buildLayerChoiceList(), (item: DialogLayerChoice) => {
        MenuItem({ content: item.name + ' · ' + item.meta })
          .onClick(() => {
            this.refreshClipLayerChoice(item.name);
          })
      }, (item: DialogLayerChoice) => 'clip:' + item.key)
    }
  }

  @Builder
  layerPickButton(fieldIndex: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.layer'))
          .fontSize(15)
          .fontColor([$r('app.color.gn_blue_800')])
        Text('图层')
          .fontSize(12)
          .fontColor($r('app.color.gn_blue_800'))
      }
      .justifyContent(FlexAlign.Center)
    }
    .width(76)
    .height(38)
    .padding({ left: 6, right: 6 })
    .backgroundColor($r('app.color.gn_blue_100'))
    .borderRadius(6)
    .bindMenu(fieldIndex === 0 ? this.inputLayerPickerMenu : this.clipLayerPickerMenu)
  }

  @Builder
  localFileButton(fieldIndex: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.folder'))
          .fontSize(15)
          .fontColor([$r('app.color.gn_blue_800')])
        Text('本地文件')
          .fontSize(12)
          .fontColor($r('app.color.gn_blue_800'))
      }
      .justifyContent(FlexAlign.Center)
    }
    .width(94)
    .height(38)
    .padding({ left: 6, right: 6 })
    .backgroundColor($r('app.color.gn_blue_100'))
    .borderRadius(6)
    .onClick(() => {
      this.chooseLocalLayer(fieldIndex);
    })
  }

  @Builder
  coordinateSystemButton() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.map'))
          .fontSize(15)
          .fontColor([$r('app.color.gn_blue_800')])
        Text('选择坐标系')
          .fontSize(12)
          .fontColor($r('app.color.gn_blue_800'))
      }
      .justifyContent(FlexAlign.Center)
    }
    .width(106)
    .height(38)
    .padding({ left: 6, right: 6 })
    .backgroundColor($r('app.color.gn_blue_100'))
    .borderRadius(6)
    .onClick(() => {
      this.crsPickerTrigger = !this.crsPickerTrigger;
    })
  }

  @Builder
  inputField(label: string, value: string, fieldIndex: number) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
      Row({ space: 8 }) {
        ForEach(this.fieldRenderKeys(fieldIndex), (renderKey: string) => {
          TextInput({ text: this.fieldValue(fieldIndex) })
            .height(38)
            .fontSize(14)
            .backgroundColor($r('app.color.gn_pane'))
            .layoutWeight(1)
            .onChange((textValue: string) => {
              if (fieldIndex === 0) {
                this.inputName = textValue;
              } else if (fieldIndex === 1) {
                this.clipName = textValue;
              } else {
                this.outputName = textValue;
              }
              this.uiRevision++;
            })
        }, (renderKey: string) => renderKey)
        if (fieldIndex === 0 || (fieldIndex === 1 && this.toolMode === 1)) {
          this.layerPickButton(fieldIndex)
        }
        if (this.toolMode === 1 && (fieldIndex === 0 || fieldIndex === 1)) {
          this.localFileButton(fieldIndex)
        }
        if (fieldIndex === 1 && this.requiresTargetCrs()) {
          this.coordinateSystemButton()
        }
      }
      .margin({ top: 6 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  runnerPanel() {
    Column({ space: 12 }) {
      Row() {
        SymbolGlyph(this.toolIcon())
          .fontSize(30)
          .fontColor([$r('app.color.gn_blue_800')])
          .margin({ right: 12 })
        Column() {
          Text(this.toolTitle())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.gn_text_primary'))
          Text(this.toolDescription())
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }

      this.inputField('输入图层', this.inputValue(), 0)
      if (this.requiresSecondaryInput()) {
        this.inputField(this.secondaryLabel(), this.secondaryValue(), 1)
        if (this.requiresTargetCrs()) {
          Text(this.targetCrsValidationText())
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      this.inputField('输出图层', this.outputValue(), 2)

      Text('状态：' + this.runStatus)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')

      Button($r('app.string.gn_run'), { type: ButtonType.Capsule, stateEffect: true })
        .width('100%')
        .height(40)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.gn_blue_800'))
        .margin({ top: 2 })
        .onClick(() => {
          this.runTool();
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
            this.runnerPanel()
            Column({ space: 8 }) {
              Text($r('app.string.gn_tool_notes'))
                .width('100%')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.gn_text_primary'))
              Text($r('app.string.gn_tool_notes_desc'))
                .fontSize(12)
                .fontColor($r('app.color.gn_text_muted'))
                .width('100%')
            }
            .padding(14)
            .borderRadius(6)
            .backgroundColor($r('app.color.gn_paper'))
            .border({ width: 1, color: $r('app.color.gn_line') })
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
          title: { mainTitle: $r('app.string.gn_tool_runner_title') },
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
        currentDefinition: this.secondaryValue(),
        onSelected: (definition: string) => {
          this.chooseCoordinateSystem(definition);
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
