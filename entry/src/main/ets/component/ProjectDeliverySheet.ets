import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode } from '@kit.UIDesignKit';
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import { getGisService, GisLoadedLayer, GisService } from '../gis/GisService';
import { GisGeoProcessResult } from '../model/GeoNestModels';

class DeliveryLayerChoice {
  index: number = -1;
  name: string = '';
  key: string = '';

  constructor(index: number, name: string, key: string) {
    this.index = index;
    this.name = name;
    this.key = key;
  }
}

function copyDeliveryFile(sourcePath: string, targetUri: string): boolean {
  let source: fs.File | null = null;
  let target: fs.File | null = null;
  try {
    source = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);
    target = fs.openSync(targetUri, fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    fs.copyFileSync(source.fd, target.fd);
    fs.fsyncSync(target.fd);
    fs.closeSync(source);
    source = null;
    fs.closeSync(target);
    target = null;
    return true;
  } catch (_error) {
    if (source !== null) {
      try { fs.closeSync(source); } catch (_sourceCloseError) {}
    }
    if (target !== null) {
      try { fs.closeSync(target); } catch (_targetCloseError) {}
    }
    return false;
  }
}

@Component
export struct PortableProjectSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @Prop projectName: string = '';
  @Prop projectCrs: string = '';
  @State private isShow: boolean = false;
  @State private outputName: string = 'GeoNest_Portable_Project';
  @State private statusText: string = '';
  onCompleted: (result: GisGeoProcessResult) => void = (_result: GisGeoProcessResult): void => {};

  onTrigger(): void {
    this.outputName = this.safeName(this.projectName.length > 0 ? this.projectName : 'GeoNest_Portable_Project');
    this.statusText = '';
    this.isShow = true;
  }

  private safeName(value: string): string {
    let result: string = '';
    for (let i: number = 0; i < value.length; i++) {
      let ch: string = value.charAt(i);
      if (ch === '/' || ch === '\\' || ch === ':' || ch === '*' || ch === '?' || ch === '"' ||
        ch === '<' || ch === '>' || ch === '|') {
        result += '_';
      } else {
        result += ch;
      }
    }
    return result.trim().length > 0 ? result.trim() : 'GeoNest_Portable_Project';
  }

  private outputPath(fileName: string): string {
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let directory: string = getGisService().processingOutputDirectory();
    if (directory.length === 0) {
      directory = context.filesDir + '/geonest_outputs';
    }
    try { fs.mkdirSync(directory, true); } catch (_error) {}
    return directory + '/' + fileName + '_' + Date.now().toString() + '.gnpkg';
  }

  private saveOptions(fileName: string): picker.DocumentSaveOptions {
    let options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName + '.gnpkg'];
    options.fileSuffixChoices = ['GeoNest Portable Project|.gnpkg'];
    return options;
  }

  private runPackaging(): void {
    let fileName: string = this.safeName(this.outputName);
    let path: string = this.outputPath(fileName);
    let result: GisGeoProcessResult = getGisService().runPortableProject(path, fileName, this.projectCrs);
    if (!result.ok) {
      this.statusText = '打包失败：' + result.message;
      return;
    }
    this.statusText = '工程包已生成，正在选择保存位置…';
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    documentPicker.save(this.saveOptions(fileName)).then((uris: Array<string>) => {
      if (uris.length === 0) {
        this.statusText = '工程包保留在应用输出目录';
        return;
      }
      if (copyDeliveryFile(result.outputPath, uris[0])) {
        this.statusText = '可移动工程包已保存：' + result.featureCount.toString() + ' 个矢量图层';
        this.onCompleted(result);
      } else {
        this.statusText = '工程包已生成，但复制到目标位置失败';
      }
    }).catch(() => {
      this.statusText = '已取消外部保存，工程包保留在应用输出目录';
    });
  }

  @Builder
  private content() {
    Column() {
      HdsNavigation() {
        Column({ space: 16 }) {
          Blank().height(72)
          Text('矢量写入 GeoPackage，文件型栅格随包复制，并生成使用相对路径的 QGZ；工程资产清单统一封装为 .gnpkg。')
            .fontSize(13).fontColor($r('app.color.gn_text_muted')).width('100%')
          TextInput({ text: this.outputName, placeholder: '工程包名称' })
            .onChange((value: string) => { this.outputName = value; })
          Text('V2 工程包覆盖矢量、栅格、附件、字体、SVG、关系与表单清单；无法读取的远程栅格会在结果中提示。')
            .fontSize(12).fontColor($r('app.color.gn_text_muted')).width('100%')
          Button('生成并保存工程包', { type: ButtonType.Capsule })
            .fontColor(Color.White).backgroundColor($r('app.color.gn_blue_800')).width('100%')
            .onClick(() => { this.runPackaging(); })
          Text(this.statusText).fontSize(12).fontColor($r('app.color.gn_text_muted')).width('100%')
        }.padding(18).width('100%')
      }
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MODAL)
      .titleBar({ content: { title: { mainTitle: '可移动 GeoPackage / QGZ 工程包' }, menu: { value: [{
        content: { label: 'modal_cancel', isEnabled: true, type: IconStyleMode.SMALL,
          action: () => { this.isShow = false; } }
      }] } } })
    }.width('100%').height('100%')
  }

  build() {
    Row().width(0).height(0).bindSheet($$this.isShow, this.content(), {
      width: 700, height: 430, detents: [430], preferType: SheetType.CENTER, dragBar: false,
      backgroundColor: Color.Transparent, blurStyle: BlurStyle.Regular, showClose: false
    })
  }
}

@Component
export struct AtlasExportSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  onGetBasemapMode: () => number = (): number => 0;
  onGetBasemapLabel: () => string = (): string => '';
  onCompleted: (result: GisGeoProcessResult) => void = (_result: GisGeoProcessResult): void => {};
  @State private isShow: boolean = false;
  @State private coverageLayerIndex: number = -1;
  @State private formatMode: number = 0;
  @State private titleText: string = 'GeoNest 地图集';
  @State private filterExpression: string = '';
  @State private marginText: string = '0.10';
  @State private sortField: string = '';
  @State private groupField: string = '';
  @State private pageNameField: string = '';
  @State private dynamicTitle: string = '{title} · {group} · {name} · 第 {page}/{pages} 页';
  @State private sortAscending: boolean = true;
  @State private statusText: string = '';

  onTrigger(): void {
    this.selectDefaultCoverage();
    this.statusText = '';
    this.isShow = true;
  }

  private choices(): DeliveryLayerChoice[] {
    let result: DeliveryLayerChoice[] = [];
    let service: GisService = getGisService();
    for (let i: number = 0; i < service.getLayerCount(); i++) {
      let layer: GisLoadedLayer | undefined = service.getLayer(i);
      if (layer !== undefined && layer.info.fields.length > 0) {
        result.push(new DeliveryLayerChoice(i, layer.info.name, layer.info.layerId + ':' + i.toString()));
      }
    }
    return result;
  }

  private selectDefaultCoverage(): void {
    let active: number = getGisService().getActiveLayerIndex();
    let list: DeliveryLayerChoice[] = this.choices();
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].index === active) { this.coverageLayerIndex = active; return; }
    }
    this.coverageLayerIndex = list.length > 0 ? list[0].index : -1;
  }

  private coverageName(): string {
    let layer: GisLoadedLayer | undefined = getGisService().getLayer(this.coverageLayerIndex);
    return layer === undefined ? '请选择覆盖图层' : layer.info.name;
  }

  private formatCode(): string { return this.formatMode === 0 ? 'pdf' : (this.formatMode === 1 ? 'png' : 'svg'); }
  private suffix(): string { return this.formatMode === 0 ? '.pdf' : '.zip'; }

  private outputPath(baseName: string): string {
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let directory: string = getGisService().processingOutputDirectory();
    if (directory.length === 0) {
      directory = context.filesDir + '/geonest_outputs';
    }
    try { fs.mkdirSync(directory, true); } catch (_error) {}
    return directory + '/' + baseName + '_' + Date.now().toString() + this.suffix();
  }

  private runAtlas(): void {
    if (this.coverageLayerIndex < 0) { this.statusText = '请选择地图集覆盖图层'; return; }
    let margin: number = Number(this.marginText);
    if (margin !== margin || margin < 0) { this.statusText = '边距比例无效'; return; }
    let baseName: string = 'GeoNest_Atlas';
    let path: string = this.outputPath(baseName);
    let result: GisGeoProcessResult = getGisService().runLayoutAtlas(this.coverageLayerIndex, path,
      this.formatCode(), this.titleText, this.filterExpression, margin, 1600, 1100,
      this.onGetBasemapMode(), this.onGetBasemapLabel(), this.sortField, this.groupField,
      this.pageNameField, this.dynamicTitle, this.sortAscending);
    if (!result.ok) { this.statusText = '地图集导出失败：' + result.message; return; }
    this.statusText = '已生成 ' + result.featureCount.toString() + ' 页，正在选择保存位置…';
    let options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    options.newFileNames = [baseName + this.suffix()];
    options.fileSuffixChoices = [this.formatMode === 0 ? 'PDF|.pdf' : 'Atlas Batch ZIP|.zip'];
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    documentPicker.save(options).then((uris: Array<string>) => {
      if (uris.length > 0 && copyDeliveryFile(result.outputPath, uris[0])) {
        this.statusText = '地图集已保存：' + result.featureCount.toString() + ' 页';
        this.onCompleted(result);
      } else {
        this.statusText = '地图集保留在应用输出目录';
      }
    }).catch(() => { this.statusText = '已取消外部保存，地图集保留在应用输出目录'; });
  }

  @Builder
  private layerMenu() {
    Menu() {
      ForEach(this.choices(), (item: DeliveryLayerChoice) => {
        MenuItem({ content: item.name }).onClick(() => { this.coverageLayerIndex = item.index; })
      }, (item: DeliveryLayerChoice) => item.key)
    }
  }

  @Builder
  private content() {
    Column() {
      HdsNavigation() {
        Scroll() {
          Column({ space: 12 }) {
            Blank().height(72)
            Button(this.coverageName(), { type: ButtonType.Capsule }).width('100%').bindMenu(this.layerMenu)
            Row({ space: 8 }) {
              Button('多页 PDF').onClick(() => { this.formatMode = 0; })
              Button('PNG 批量包').onClick(() => { this.formatMode = 1; })
              Button('SVG 批量包').onClick(() => { this.formatMode = 2; })
            }.width('100%')
            TextInput({ text: this.titleText, placeholder: '地图集标题' })
              .onChange((value: string) => { this.titleText = value; })
            TextInput({ text: this.filterExpression, placeholder: '可选 QGIS 筛选表达式' })
              .onChange((value: string) => { this.filterExpression = value; })
            Row({ space: 8 }) {
              TextInput({ text: this.sortField, placeholder: '排序字段（可选）' })
                .layoutWeight(1).onChange((value: string) => { this.sortField = value; })
              TextInput({ text: this.groupField, placeholder: '分组字段（可选）' })
                .layoutWeight(1).onChange((value: string) => { this.groupField = value; })
            }.width('100%')
            Row({ space: 8 }) {
              TextInput({ text: this.pageNameField, placeholder: '页名字段（可选）' })
                .layoutWeight(1).onChange((value: string) => { this.pageNameField = value; })
              Button(this.sortAscending ? '升序' : '降序', { type: ButtonType.Capsule })
                .onClick(() => { this.sortAscending = !this.sortAscending; })
            }.width('100%')
            TextInput({ text: this.dynamicTitle, placeholder: '动态标题：{title} {group} {name} {page} {pages} {fid}' })
              .onChange((value: string) => { this.dynamicTitle = value; })
            TextInput({ text: this.marginText, placeholder: '范围边距比例，例如 0.10' })
              .type(InputType.Number).onChange((value: string) => { this.marginText = value; })
            Text('PDF 输出多页单文件；PNG/SVG 输出批量 ZIP。在线 XYZ 底图会按每页范围真实合成。')
              .fontSize(12).fontColor($r('app.color.gn_text_muted')).width('100%')
            Button('批量出图', { type: ButtonType.Capsule })
              .fontColor(Color.White).backgroundColor($r('app.color.gn_blue_800')).width('100%')
              .onClick(() => { this.runAtlas(); })
            Text(this.statusText).fontSize(12).fontColor($r('app.color.gn_text_muted')).width('100%')
          }.padding(18).width('100%')
        }
      }
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MODAL)
      .titleBar({ content: { title: { mainTitle: '布局地图集 / 批量出图' }, menu: { value: [{
        content: { label: 'modal_cancel', isEnabled: true, type: IconStyleMode.SMALL,
          action: () => { this.isShow = false; } }
      }] } } })
    }.width('100%').height('100%')
  }

  build() {
    Row().width(0).height(0).bindSheet($$this.isShow, this.content(), {
      width: 760, height: 620, detents: [620], preferType: SheetType.CENTER, dragBar: false,
      backgroundColor: Color.Transparent, blurStyle: BlurStyle.Regular, showClose: false
    })
  }
}
