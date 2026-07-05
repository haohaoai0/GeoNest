import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '../utils/MaterialStyle';
import { getGisService, GisLoadedLayer } from '../gis/GisService';
import { GeoNestProjectParameters, RecentProjectRecord, GisCrsInfo } from '../model/GeoNestModels';

@Component
export struct ProjectInfoSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  projectName: string = '';
  projectOwner: string = '';
  projectCrs: string = '';
  projectMapName: string = '';
  projectWorkspaceName: string = '';
  projectDescription: string = '';
  projectFileName: string = '';
  projectFileUri: string = '';
  onProjectInfoChanged: (params: GeoNestProjectParameters) => void = () => {};
  @State private nameInput: string = '';
  @State private ownerInput: string = '';
  @State private crsInput: string = '';
  @State private mapNameInput: string = '';
  @State private workspaceNameInput: string = '';
  @State private descriptionInput: string = '';

  onTrigger(): void {
    this.isShow = true;
  }

  aboutToAppear(): void {
    this.nameInput = this.projectNameText();
    this.ownerInput = this.projectOwnerText();
    this.crsInput = this.crsInputText();
    this.mapNameInput = this.projectMapNameText();
    this.workspaceNameInput = this.projectWorkspaceNameText();
    this.descriptionInput = this.projectDescriptionText();
  }

  @Builder
  infoTextRow(label: ResourceStr, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.gn_text_muted'))
        .layoutWeight(1)
      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(36)
  }

  @Builder
  inputField(label: ResourceStr, value: string, placeholder: ResourceStr, fieldIndex: number) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
      TextInput({ text: value, placeholder: placeholder })
        .height(36)
        .fontSize(13)
        .backgroundColor($r('app.color.gn_pane'))
        .margin({ top: 6 })
        .onChange((textValue: string) => {
          this.setFieldValue(fieldIndex, textValue);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  structureRow(title: ResourceStr, desc: string, icon: Resource) {
    Row() {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([$r('app.color.gn_blue_800')])
        .margin({ right: 12 })
      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
        Text(desc)
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 4 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .height(68)
    .padding({ left: 12, right: 12 })
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_pane'))
  }

  private normalizedText(value: string, fallback: string): string {
    let trimmed = value.trim();
    if (trimmed.length > 0) {
      return trimmed;
    }
    return fallback;
  }

  private projectNameText(): string {
    return this.normalizedText(this.projectName, '未命名工程');
  }

  private projectOwnerText(): string {
    return this.normalizedText(this.projectOwner, '未设置');
  }

  private projectMapNameText(): string {
    return this.normalizedText(this.projectMapName, '地图');
  }

  private projectWorkspaceNameText(): string {
    return this.normalizedText(this.projectWorkspaceName, '默认工作空间');
  }

  private projectDescriptionText(): string {
    return this.normalizedText(this.projectDescription, '未填写');
  }

  private getPrimaryLayer(): GisLoadedLayer | undefined {
    let service = getGisService();
    let activeLayer = service.getActiveLayer();
    if (activeLayer !== undefined) {
      return activeLayer;
    }
    if (service.getLayerCount() > 0) {
      return service.getLayer(0);
    }
    return undefined;
  }

  private crsText(): string {
    if (this.projectCrs.length > 0) {
      return this.projectCrs;
    }
    let layer = this.getPrimaryLayer();
    if (layer === undefined || layer.info.crs.length === 0) {
      return 'CRS 未声明';
    }
    if (layer.info.coordinateUnitName.length > 0) {
      return layer.info.crs + ' · ' + layer.info.coordinateUnitName;
    }
    return layer.info.crs;
  }

  private crsInputText(): string {
    if (this.projectCrs.length > 0) {
      return this.projectCrs;
    }
    let layer = this.getPrimaryLayer();
    if (layer === undefined || layer.info.crs.length === 0) {
      return '';
    }
    return layer.info.crs;
  }

  private crsValidationText(): string {
    let definition = this.crsInput.trim();
    if (definition.length === 0 || definition === 'CRS 未声明') {
      return '坐标系未定义，可输入 EPSG:4490、EPSG:4326 或 WKT/PROJ 定义。';
    }
    let info: GisCrsInfo = getGisService().describeCoordinateReferenceSystem(definition);
    if (!info.isValid) {
      return '坐标系无法识别：' + info.message;
    }
    let name = info.friendlyName.length > 0 ? info.friendlyName : info.description;
    if (name.length === 0) {
      name = info.authId;
    }
    let unitText = info.unitName.length > 0 ? info.unitName : '单位未声明';
    if (info.isGeographic) {
      let ellipsoidText = info.ellipsoidAcronym.length > 0 ? ' · 椭球 ' + info.ellipsoidAcronym : '';
      return '有效地理坐标系：' + name + ellipsoidText + ' · 单位 ' + unitText;
    }
    let geographicText = info.geographicCrsAuthId.length > 0 ? info.geographicCrsAuthId : '地理坐标系未声明';
    let projectionText = info.projectionAcronym.length > 0 ? info.projectionAcronym : '投影方法未声明';
    return '有效投影坐标系：' + name + ' · 地理坐标系 ' + geographicText + ' · ' + projectionText +
      ' · 单位 ' + unitText;
  }

  private extentText(): string {
    let layer = this.getPrimaryLayer();
    if (layer === undefined) {
      return '-';
    }
    return layer.info.envelope.minX.toFixed(6) + ', ' + layer.info.envelope.minY.toFixed(6) + ' - ' +
      layer.info.envelope.maxX.toFixed(6) + ', ' + layer.info.envelope.maxY.toFixed(6);
  }

  private savedLocationText(): string {
    if (this.projectFileUri.length > 0) {
      return this.projectFileUri;
    }
    if (this.projectFileName.length > 0) {
      return this.projectFileName;
    }
    return '尚未选择保存位置';
  }

  private layerSummaryText(): string {
    let layerCount = getGisService().getLayerCount();
    let featureCount = getGisService().getTotalFeatureCount();
    return layerCount.toString() + ' 个图层 · ' + featureCount.toString() + ' 个要素';
  }

  private mapStructureText(): string {
    return this.projectMapNameText() + ' · ' + this.crsText();
  }

  private workspaceStructureText(): string {
    return this.projectWorkspaceNameText() + ' · ' + this.savedLocationText();
  }

  private outputStructureText(): string {
    return '成果、工具运行输出和后续制图文件归属当前 GIS 工程，不对应应用代码目录。';
  }

  private setFieldValue(fieldIndex: number, value: string): void {
    if (fieldIndex === 0) {
      this.nameInput = value;
    } else if (fieldIndex === 1) {
      this.ownerInput = value;
    } else if (fieldIndex === 2) {
      this.crsInput = value;
    } else if (fieldIndex === 3) {
      this.mapNameInput = value;
    } else if (fieldIndex === 4) {
      this.workspaceNameInput = value;
    } else {
      this.descriptionInput = value;
    }
  }

  private buildEditedParameters(): GeoNestProjectParameters {
    return new GeoNestProjectParameters(
      this.normalizedText(this.nameInput, '未命名工程'),
      this.normalizedText(this.ownerInput, ''),
      this.normalizedText(this.crsInput, ''),
      this.normalizedText(this.mapNameInput, '地图'),
      this.normalizedText(this.workspaceNameInput, '默认工作空间'),
      this.normalizedText(this.descriptionInput, '')
    );
  }

  private applyProjectInfo(): void {
    this.onProjectInfoChanged(this.buildEditedParameters());
  }

  @Builder
  sheetContent() {
    Column() {
      HdsNavigation() {
        Scroll(this.scroller) {
          Column({ space: 12 }) {
            Blank().height(80).width('100%')
            Column({ space: 2 }) {
              Text(this.projectNameText())
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.gn_text_primary'))
                .width('100%')
              this.infoTextRow($r('app.string.gn_project_owner_label'), this.projectOwnerText())
              this.infoTextRow($r('app.string.gn_project_description_label'), this.projectDescriptionText())
              this.infoTextRow($r('app.string.gn_project_file_label'), this.savedLocationText())
              this.infoTextRow($r('app.string.gn_project_layer_count_label'), this.layerSummaryText())
              this.infoTextRow($r('app.string.gn_project_extent_label'), this.extentText())
            }
            .padding(14)
            .borderRadius(6)
            .backgroundColor($r('app.color.gn_paper'))
            .border({ width: 1, color: $r('app.color.gn_line') })

            Column({ space: 10 }) {
              Text($r('app.string.gn_project_parameters_title'))
                .width('100%')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.gn_text_primary'))
              this.inputField($r('app.string.gn_project_name_label'), this.nameInput,
                $r('app.string.gn_project_name_placeholder'), 0)
              this.inputField($r('app.string.gn_project_owner_label'), this.ownerInput,
                $r('app.string.gn_project_owner_placeholder'), 1)
              this.inputField($r('app.string.gn_project_crs_editor'), this.crsInput,
                $r('app.string.gn_project_crs_placeholder'), 2)
              Text(this.crsValidationText())
                .width('100%')
                .fontSize(11)
                .fontColor($r('app.color.gn_text_muted'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              this.inputField($r('app.string.gn_project_map_name_label'), this.mapNameInput,
                $r('app.string.gn_project_map_name_placeholder'), 3)
              this.inputField($r('app.string.gn_project_workspace_label'), this.workspaceNameInput,
                $r('app.string.gn_project_workspace_placeholder'), 4)
              this.inputField($r('app.string.gn_project_description_label'), this.descriptionInput,
                $r('app.string.gn_project_description_placeholder'), 5)
              Row({ space: 8 }) {
                Button($r('app.string.gn_apply_project_info'), { type: ButtonType.Capsule, stateEffect: true })
                  .height(32)
                  .fontSize(13)
                  .fontColor(Color.White)
                  .backgroundColor($r('app.color.gn_blue_800'))
                  .onClick(() => {
                    this.applyProjectInfo();
                  })
                Text($r('app.string.gn_project_crs_note'))
                  .fontSize(11)
                  .fontColor($r('app.color.gn_text_muted'))
                  .layoutWeight(1)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .padding(14)
            .borderRadius(6)
            .backgroundColor($r('app.color.gn_paper'))
            .border({ width: 1, color: $r('app.color.gn_line') })

            Text($r('app.string.gn_structure_title'))
              .width('100%')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.gn_text_primary'))

            this.structureRow($r('app.string.gn_structure_map'), this.mapStructureText(),
              $r('sys.symbol.map'))
            this.structureRow($r('app.string.gn_structure_layers'), this.layerSummaryText(),
              $r('sys.symbol.doc_text'))
            this.structureRow($r('app.string.gn_structure_workspace'), this.workspaceStructureText(),
              $r('sys.symbol.folder_fill'))
            this.structureRow($r('app.string.gn_structure_outputs'), this.outputStructureText(),
              $r('sys.symbol.arrow_right_and_square'))
          }
          .width('100%')
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
          title: { mainTitle: $r('app.string.gn_project_info') },
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
export struct NewProjectSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  recentProjects: RecentProjectRecord[] = [];
  recentRevision: number = 0;
  onCreateProject: (params: GeoNestProjectParameters) => void = () => {};
  onOpenRecentProject: (uri: string) => void = () => {};
  @State private projectNameInput: string = '未命名工程';
  @State private ownerInput: string = '';
  @State private crsInput: string = 'EPSG:4326';
  @State private mapNameInput: string = '地图';
  @State private workspaceInput: string = '默认工作空间';
  @State private descriptionInput: string = '';

  onTrigger(): void {
    this.isShow = true;
  }

  private normalizedText(value: string, fallback: string): string {
    let trimmed = value.trim();
    if (trimmed.length > 0) {
      return trimmed;
    }
    return fallback;
  }

  private fieldValue(fieldIndex: number): string {
    if (fieldIndex === 0) {
      return this.projectNameInput;
    }
    if (fieldIndex === 1) {
      return this.ownerInput;
    }
    if (fieldIndex === 2) {
      return this.crsInput;
    }
    if (fieldIndex === 3) {
      return this.mapNameInput;
    }
    if (fieldIndex === 4) {
      return this.workspaceInput;
    }
    return this.descriptionInput;
  }

  private setFieldValue(fieldIndex: number, value: string): void {
    if (fieldIndex === 0) {
      this.projectNameInput = value;
    } else if (fieldIndex === 1) {
      this.ownerInput = value;
    } else if (fieldIndex === 2) {
      this.crsInput = value;
    } else if (fieldIndex === 3) {
      this.mapNameInput = value;
    } else if (fieldIndex === 4) {
      this.workspaceInput = value;
    } else {
      this.descriptionInput = value;
    }
  }

  private buildParameters(): GeoNestProjectParameters {
    return new GeoNestProjectParameters(
      this.normalizedText(this.projectNameInput, '未命名工程'),
      this.normalizedText(this.ownerInput, ''),
      this.normalizedText(this.crsInput, ''),
      this.normalizedText(this.mapNameInput, '地图'),
      this.normalizedText(this.workspaceInput, '默认工作空间'),
      this.normalizedText(this.descriptionInput, '')
    );
  }

  private createProject(): void {
    let params = this.buildParameters();
    this.isShow = false;
    this.onCreateProject(params);
  }

  private openRecentProject(uri: string): void {
    this.isShow = false;
    this.onOpenRecentProject(uri);
  }

  private fileNameFromUri(uri: string): string {
    let fileName = uri;
    let lastSlash = uri.lastIndexOf('/');
    if (lastSlash >= 0 && lastSlash < fileName.length - 1) {
      fileName = fileName.substring(lastSlash + 1);
    }
    let lastBackSlash = fileName.lastIndexOf('\\');
    if (lastBackSlash >= 0 && lastBackSlash < fileName.length - 1) {
      fileName = fileName.substring(lastBackSlash + 1);
    }
    if (fileName.length === 0) {
      return 'GeoNestProject.gnproj';
    }
    return fileName;
  }

  private recentProjectName(record: RecentProjectRecord): string {
    if (record.name.length > 0) {
      return record.name;
    }
    return this.fileNameFromUri(record.uri);
  }

  private recentProjectMeta(record: RecentProjectRecord): string {
    let meta = '';
    if (record.owner.length > 0) {
      meta = record.owner;
    }
    if (record.crs.length > 0) {
      if (meta.length > 0) {
        meta += ' · ';
      }
      meta += record.crs;
    }
    if (record.workspaceName.length > 0) {
      if (meta.length > 0) {
        meta += ' · ';
      }
      meta += record.workspaceName;
    }
    if (meta.length === 0) {
      return 'GeoNest 工程文件';
    }
    return meta;
  }

  @Builder
  inputField(label: ResourceStr, placeholder: ResourceStr, fieldIndex: number) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
      TextInput({ text: this.fieldValue(fieldIndex), placeholder: placeholder })
        .height(38)
        .fontSize(13)
        .backgroundColor($r('app.color.gn_pane'))
        .margin({ top: 6 })
        .onChange((textValue: string) => {
          this.setFieldValue(fieldIndex, textValue);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  templatePanel() {
    Column({ space: 8 }) {
      Text($r('app.string.gn_project_templates_label'))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
        .width('100%')
      Row() {
        SymbolGlyph($r('sys.symbol.doc_text'))
          .fontSize(22)
          .fontColor([$r('app.color.gn_blue_800')])
          .margin({ right: 10 })
        Column() {
          Text($r('app.string.gn_new_project_template_blank'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
          Text($r('app.string.gn_new_project_template_desc'))
            .fontSize(11)
            .fontColor($r('app.color.gn_text_muted'))
            .margin({ top: 4 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .height(68)
      .padding({ left: 10, right: 10 })
      .backgroundColor($r('app.color.gn_blue_100'))
      .borderRadius(6)
      .border({ width: 1, color: $r('app.color.gn_blue_800') })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
    .borderRadius(6)
  }

  @Builder
  recentProjectItem(record: RecentProjectRecord) {
    Column() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.folder_fill'))
          .fontSize(17)
          .fontColor([$r('sys.color.icon_secondary')])
        Text(this.recentProjectName(record))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Text(this.recentProjectMeta(record))
        .fontSize(10)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
        .margin({ top: 4 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(record.uri)
        .fontSize(10)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
        .margin({ top: 2 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(10)
    .backgroundColor($r('app.color.gn_pane'))
    .borderRadius(6)
    .onClick(() => {
      this.openRecentProject(record.uri);
    })
  }

  @Builder
  recentPanel() {
    Column({ space: 8 }) {
      Text($r('app.string.gn_qgis_recent_projects'))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
        .width('100%')
      if (this.recentProjects.length === 0) {
        Column() {
          Text($r('app.string.gn_recent_empty'))
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
          Text($r('app.string.gn_recent_open_tip'))
            .fontSize(11)
            .fontColor($r('app.color.gn_text_muted'))
            .margin({ top: 4 })
        }
        .width('100%')
        .height(92)
        .justifyContent(FlexAlign.Center)
      } else {
        ForEach(this.recentProjects, (record: RecentProjectRecord) => {
          this.recentProjectItem(record)
        }, (record: RecentProjectRecord) => this.recentRevision.toString() + ':' + record.uri)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
    .borderRadius(6)
  }

  @Builder
  parameterPanel() {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.plus_square_fill'))
          .fontSize(28)
          .fontColor([$r('app.color.gn_blue_800')])
        Column({ space: 3 }) {
          Text($r('app.string.gn_project_parameters'))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
          Text($r('app.string.gn_new_project_subtitle'))
            .fontSize(11)
            .fontColor($r('app.color.gn_text_muted'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      Scroll() {
        Column({ space: 12 }) {
          Text('基本信息')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_blue_800'))
            .width('100%')
          this.inputField($r('app.string.gn_project_name_label'), $r('app.string.gn_project_name_placeholder'), 0)
          this.inputField($r('app.string.gn_project_owner_label'), $r('app.string.gn_project_owner_placeholder'), 1)
          Divider()
            .color($r('app.color.gn_line'))
          Text('空间参考与地图')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_blue_800'))
            .width('100%')
          this.inputField($r('app.string.gn_project_crs_editor'), $r('app.string.gn_project_crs_placeholder'), 2)
          this.inputField($r('app.string.gn_project_map_name_label'), $r('app.string.gn_project_map_name_placeholder'), 3)
          Divider()
            .color($r('app.color.gn_line'))
          Text('工作空间')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_blue_800'))
            .width('100%')
          this.inputField($r('app.string.gn_project_workspace_label'), $r('app.string.gn_project_workspace_placeholder'), 4)
          this.inputField($r('app.string.gn_project_description_label'),
            $r('app.string.gn_project_description_placeholder'), 5)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      Button($r('app.string.gn_new_project_create'), { type: ButtonType.Capsule, stateEffect: true })
        .height(40)
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.gn_blue_800'))
        .onClick(() => {
          this.createProject();
        })
    }
    .layoutWeight(1)
    .height('100%')
    .padding(14)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
    .borderRadius(6)
  }

  @Builder
  sheetContent() {
    Column() {
      HdsNavigation() {
        Row({ space: 14 }) {
          Column({ space: 12 }) {
            Scroll() {
              Column({ space: 12 }) {
                Blank().height(80).width('100%')
                this.templatePanel()
                this.recentPanel()
              }
            }
            .layoutWeight(1)
            .scrollBar(BarState.Auto)
          }
          .width(280)
          .height('100%')
          Column() {
            Blank().height(80).width('100%')
            this.parameterPanel()
          }
          .layoutWeight(1)
          .height('100%')
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 16 })
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
          title: { mainTitle: $r('app.string.gn_new_project_title') },
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
