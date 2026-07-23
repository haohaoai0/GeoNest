import { WorkbenchCatalogAction, WorkbenchCatalogSection } from '../constants/WorkbenchConstants';
import { LayerDisplayItem, RecentProjectRecord, WorkbenchFieldItem } from '../model/WorkbenchModels';
import { WorkbenchTextService } from '../service/WorkbenchTextService';

@Component
export struct WorkbenchCatalogPanel {
  @Prop section: number = WorkbenchCatalogSection.PROJECT;
  @Prop searchText: string = '';
  @Prop selectedLayerIndex: number = -1;
  @Prop layerCount: number = 0;
  @Prop catalogKey: string = '';
  @Prop catalogSummary: string = '';
  @Prop filteredLayers: LayerDisplayItem[] = [];
  @Prop layers: LayerDisplayItem[] = [];
  @Prop fields: WorkbenchFieldItem[] = [];
  @Prop recentProjects: RecentProjectRecord[] = [];
  @Prop cloudIdentityText: string = '';
  @Prop cloudSyncText: string = '';
  @Prop currentProjectText: string = '';
  @Prop workspacePathText: string = '';
  @Prop activeLayerText: string = '';
  @Prop activeLayerSourceText: string = '';
  @Prop itemRadius: number = 6;
  resolveGeometryIcon: (geometryType: number) => Resource = (geometryType: number): Resource => {
    return $r('sys.symbol.layer');
  };
  onSectionChanged: (section: number) => void = (section: number): void => {};
  onSearchTextChanged: (value: string) => void = (value: string): void => {};
  onRoute: (routeId: number) => void = (routeId: number): void => {};
  onAction: (actionId: number) => void = (actionId: number): void => {};
  onUnavailableAction: () => void = (): void => {};
  onSelectLayer: (layerIndex: number) => void = (layerIndex: number): void => {};
  onOpenRecentProject: (uri: string) => void = (uri: string): void => {};

  private layerMeta(item: LayerDisplayItem): string {
    let visibleText: string = item.visible ? '可见' : '隐藏';
    let crsText: string = item.referenceText.length > 0 ? item.referenceText : 'CRS 未声明';
    return item.featureCount.toString() + ' 要素 · ' + item.fieldCount.toString() + ' 字段 · ' + crsText +
      ' · ' + visibleText;
  }

  private recentProjectMeta(record: RecentProjectRecord): string {
    let text: string = record.workspaceName.length > 0 ? record.workspaceName : record.name;
    if (record.crs.length > 0) {
      text += ' · ' + record.crs;
    }
    if (text.length === 0) {
      return WorkbenchTextService.displayFileName(
        WorkbenchTextService.extractFileName(record.uri, this.currentProjectText));
    }
    return text;
  }

  private recentProjectDisplayName(record: RecentProjectRecord): string {
    if (record.name.length > 0) {
      return record.name;
    }
    return WorkbenchTextService.displayFileName(
      WorkbenchTextService.extractFileName(record.uri, this.currentProjectText));
  }

  private limitedRecentProjects(limit: number): RecentProjectRecord[] {
    let result: RecentProjectRecord[] = [];
    for (let i: number = 0; i < this.recentProjects.length && i < limit; i++) {
      result.push(this.recentProjects[i]);
    }
    return result;
  }

  @Builder
  symbol(icon: Resource, color: ResourceColor, sizeValue: number) {
    SymbolGlyph(icon)
      .fontSize(sizeValue)
      .fontColor([color])
  }

  @Builder
  scopeTab(label: ResourceStr, section: number) {
    Text(label)
      .height(28)
      .padding({ left: 8, right: 8 })
      .fontSize(13)
      .fontWeight(this.section === section ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.section === section ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .border({
        width: { bottom: this.section === section ? 2 : 0 },
        color: $r('app.color.gn_blue_800')
      })
      .onClick(() => {
        this.onSectionChanged(section);
      })
  }

  @Builder
  scopeTabs() {
    Row() {
      this.scopeTab($r('app.string.gn_project'), WorkbenchCatalogSection.PROJECT)
      this.scopeTab($r('app.string.gn_arc_portal'), WorkbenchCatalogSection.PORTAL)
      this.scopeTab($r('app.string.gn_arc_computer'), WorkbenchCatalogSection.COMPUTER)
      this.scopeTab($r('app.string.gn_arc_favorites'), WorkbenchCatalogSection.FAVORITES)
      Blank()
      this.symbol($r('sys.symbol.line_3_horizontal'), $r('sys.color.icon_secondary'), 16)
    }
    .height(30)
    .padding({ left: 8, right: 10 })
    .backgroundColor($r('app.color.gn_pane'))
  }

  @Builder
  navigationButton(icon: Resource, enabledValue: boolean) {
    Button({ type: ButtonType.Normal, stateEffect: enabledValue }) {
      this.symbol(icon, $r('sys.color.icon_secondary'), 14)
    }
    .width(26)
    .height(26)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .opacity(enabledValue ? 1.0 : 0.42)
    .enabled(enabledValue)
    .onClick(() => {
      this.onSectionChanged(WorkbenchCatalogSection.PROJECT);
    })
  }

  @Builder
  navigationRow() {
    Row({ space: 4 }) {
      this.navigationButton($r('sys.symbol.chevron_left'), false)
      this.navigationButton($r('sys.symbol.folder_fill'), true)
      this.symbol($r('sys.symbol.funnel'), $r('sys.color.icon_secondary'), 15)
      Search({ placeholder: $r('app.string.gn_arc_search_project') })
        .height(30)
        .layoutWeight(1)
        .backgroundColor($r('app.color.gn_paper'))
        .onChange((value: string) => {
          this.onSearchTextChanged(value);
        })
    }
    .height(36)
    .padding({ left: 8, right: 8, bottom: 4 })
    .backgroundColor($r('app.color.gn_pane'))
  }

  @Builder
  catalogItem(label: ResourceStr, icon: Resource, level: number, routeId: number) {
    Row({ space: 6 }) {
      Blank().width(level * 14)
      this.symbol(level === 0 ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right'),
        $r('sys.color.icon_secondary'), 11)
      this.symbol(icon, $r('sys.color.icon_secondary'), 16)
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.gn_text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(28)
    .padding({ left: 8, right: 8 })
    .margin({ left: 6, right: 6, top: 1, bottom: 1 })
    .borderRadius(this.itemRadius)
    .onClick(() => {
      this.onRoute(routeId);
    })
  }

  @Builder
  groupHeader(title: ResourceStr, description: ResourceStr) {
    Column({ space: 3 }) {
      Text(title).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.gn_text_primary'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(description).fontSize(10).fontColor($r('app.color.gn_text_muted'))
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 10, bottom: 4 })
  }

  @Builder
  infoItem(label: ResourceStr, value: string, icon: Resource) {
    Row({ space: 8 }) {
      this.symbol(icon, $r('sys.color.icon_secondary'), 16)
      Column({ space: 2 }) {
        Text(label).fontSize(11).fontColor($r('app.color.gn_text_muted'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(value).fontSize(12).fontColor($r('app.color.gn_text_primary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .height(46)
    .padding({ left: 10, right: 10 })
    .margin({ left: 8, right: 8, top: 3 })
    .borderRadius(this.itemRadius)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  actionItem(label: ResourceStr, description: ResourceStr, icon: Resource, actionId: number,
    enabledValue: boolean) {
    Row({ space: 8 }) {
      this.symbol(icon, enabledValue ? $r('app.color.gn_blue_800') : $r('sys.color.icon_secondary'), 17)
      Column({ space: 2 }) {
        Text(label).fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor(enabledValue ? $r('app.color.gn_text_primary') : $r('app.color.gn_text_muted'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(description).fontSize(10).fontColor($r('app.color.gn_text_muted'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      this.symbol($r('sys.symbol.chevron_right'), $r('sys.color.icon_secondary'), 11)
    }
    .height(48)
    .padding({ left: 10, right: 8 })
    .margin({ left: 8, right: 8, top: 3 })
    .borderRadius(this.itemRadius)
    .backgroundColor($r('app.color.gn_paper'))
    .opacity(enabledValue ? 1.0 : 0.48)
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
    .onClick(() => {
      if (enabledValue) {
        this.onAction(actionId);
      } else {
        this.onUnavailableAction();
      }
    })
  }

  @Builder
  recentProjectItem(record: RecentProjectRecord) {
    Row({ space: 8 }) {
      this.symbol($r('sys.symbol.doc_text_badge_clock'), $r('app.color.gn_blue_800'), 16)
      Column({ space: 2 }) {
        Text(this.recentProjectDisplayName(record)).fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary')).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.recentProjectMeta(record)).fontSize(10).fontColor($r('app.color.gn_text_muted'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      this.symbol($r('sys.symbol.chevron_right'), $r('sys.color.icon_secondary'), 11)
    }
    .height(46)
    .padding({ left: 10, right: 8 })
    .margin({ left: 8, right: 8, top: 3 })
    .borderRadius(this.itemRadius)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
    .onClick(() => {
      this.onOpenRecentProject(record.uri);
    })
  }

  @Builder
  recentProjectsSection(limit: number) {
    this.groupHeader($r('app.string.gn_catalog_recent_projects'),
      $r('app.string.gn_catalog_recent_projects_desc'))
    if (this.recentProjects.length === 0) {
      this.infoItem($r('app.string.gn_catalog_recent_empty'), this.currentProjectText,
        $r('sys.symbol.doc_text_badge_clock'))
    } else {
      ForEach(this.limitedRecentProjects(limit), (record: RecentProjectRecord) => {
        this.recentProjectItem(record)
      }, (record: RecentProjectRecord) => 'recent:' + record.uri + ':' + record.name)
    }
  }

  @Builder
  portalContent() {
    Column() {
      this.groupHeader($r('app.string.gn_catalog_portal_title'), $r('app.string.gn_catalog_portal_desc'))
      this.infoItem($r('app.string.gn_catalog_portal_account'), this.cloudIdentityText,
        $r('sys.symbol.person_crop_circle_fill'))
      this.infoItem($r('app.string.gn_catalog_portal_cloud'), this.cloudSyncText, $r('sys.symbol.cloud'))
      this.actionItem($r('app.string.gn_cmd_cloud_manage'), $r('app.string.gn_catalog_portal_manage_desc'),
        $r('sys.symbol.archivebox_fill'), WorkbenchCatalogAction.CLOUD_MANAGE, true)
      this.actionItem($r('app.string.gn_cmd_cloud_push'), $r('app.string.gn_catalog_portal_push_desc'),
        $r('sys.symbol.arrow_clockwise'), WorkbenchCatalogAction.CLOUD_PUSH, true)
      this.actionItem($r('app.string.gn_cmd_cloud_pull'), $r('app.string.gn_catalog_portal_pull_desc'),
        $r('sys.symbol.download'), WorkbenchCatalogAction.CLOUD_PULL, true)
      this.actionItem($r('app.string.gn_cmd_share'), $r('app.string.gn_catalog_portal_share_desc'),
        $r('sys.symbol.share'), WorkbenchCatalogAction.SHARE, this.layerCount > 0)
    }
    .width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  computerContent() {
    Column() {
      this.groupHeader($r('app.string.gn_catalog_computer_title'), $r('app.string.gn_catalog_computer_desc'))
      this.actionItem($r('app.string.gn_cmd_add_data'), $r('app.string.gn_catalog_computer_add_data_desc'),
        $r('sys.symbol.plus_layer'), WorkbenchCatalogAction.ADD_DATA, true)
      this.actionItem($r('app.string.gn_workbench_open'),
        $r('app.string.gn_catalog_computer_open_project_desc'), $r('sys.symbol.folder'),
        WorkbenchCatalogAction.OPEN_PROJECT, true)
      this.actionItem($r('app.string.gn_workbench_save'),
        $r('app.string.gn_catalog_computer_save_project_desc'), $r('sys.symbol.archivebox_fill'),
        WorkbenchCatalogAction.SAVE_PROJECT, true)
      this.infoItem($r('app.string.gn_catalog_computer_current_project'), this.currentProjectText,
        $r('sys.symbol.doc_text'))
      this.infoItem($r('app.string.gn_catalog_computer_workspace'), this.workspacePathText,
        $r('sys.symbol.externaldrive'))
      this.infoItem($r('app.string.gn_catalog_computer_active_layer'), this.activeLayerSourceText,
        $r('sys.symbol.folder_fill'))
      this.recentProjectsSection(4)
    }
    .width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  favoritesContent() {
    Column() {
      this.groupHeader($r('app.string.gn_catalog_favorites_title'), $r('app.string.gn_catalog_favorites_desc'))
      this.groupHeader($r('app.string.gn_catalog_favorites_analysis'),
        $r('app.string.gn_catalog_favorites_analysis_desc'))
      this.actionItem($r('app.string.gn_cmd_clip'), $r('app.string.gn_workbench_clip_desc'),
        $r('sys.symbol.square_dashed_and_arrow_turn_up_right'), WorkbenchCatalogAction.CLIP, this.layerCount > 1)
      this.actionItem($r('app.string.gn_cmd_buffer'), $r('app.string.gn_workbench_buffer_desc'),
        $r('sys.symbol.circle_grid_2x2'), WorkbenchCatalogAction.BUFFER, this.layerCount > 0)
      this.actionItem($r('app.string.gn_cmd_quality_check'), $r('app.string.gn_workbench_quality_check_desc'),
        $r('sys.symbol.list_checkmark'), WorkbenchCatalogAction.QUALITY_CHECK, this.layerCount > 0)
      this.actionItem($r('app.string.gn_cmd_spatial_join_summary'),
        $r('app.string.gn_workbench_spatial_join_summary_desc'), $r('sys.symbol.plus_square_on_square'),
        WorkbenchCatalogAction.SPATIAL_JOIN_SUMMARY, this.layerCount > 1)
      this.actionItem($r('app.string.gn_cmd_intersection'), $r('app.string.gn_workbench_intersection_desc'),
        $r('sys.symbol.square_and_cut'), WorkbenchCatalogAction.INTERSECTION, this.layerCount > 1)
      this.groupHeader($r('app.string.gn_catalog_favorites_presentation'),
        $r('app.string.gn_catalog_favorites_presentation_desc'))
      this.actionItem($r('app.string.gn_symbology'), $r('app.string.gn_cap_symbology_desc'),
        $r('sys.symbol.paintpalette'), WorkbenchCatalogAction.SYMBOLOGY, this.layerCount > 0)
      this.actionItem($r('app.string.gn_cap_labeling_title'), $r('app.string.gn_cap_labeling_desc'),
        $r('sys.symbol.doc_text'), WorkbenchCatalogAction.LABELING, this.layerCount > 0)
      this.actionItem($r('app.string.gn_ribbon_layout'), $r('app.string.gn_cap_map_layout_desc'),
        $r('sys.symbol.doc_text'), WorkbenchCatalogAction.LAYOUT, true)
      this.groupHeader($r('app.string.gn_catalog_favorites_layer'),
        $r('app.string.gn_catalog_favorites_layer_desc'))
      this.infoItem($r('app.string.gn_catalog_computer_active_layer'), this.activeLayerText, $r('sys.symbol.layer'))
      this.actionItem($r('app.string.gn_workbench_attribute_table'), $r('app.string.gn_cap_attribute_table_desc'),
        $r('sys.symbol.doc_text'), WorkbenchCatalogAction.ATTRIBUTE_TABLE, this.layerCount > 0)
      this.actionItem($r('app.string.gn_cmd_export'), $r('app.string.gn_workbench_export_desc'),
        $r('sys.symbol.download'), WorkbenchCatalogAction.EXPORT, this.layerCount > 0)
      this.recentProjectsSection(3)
    }
    .width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  searchEmptyState() {
    Column({ space: 6 }) {
      this.symbol($r('sys.symbol.magnifyingglass'), $r('sys.color.icon_secondary'), 22)
      Text('未找到匹配工程内容').fontSize(12).fontColor($r('app.color.gn_text_primary'))
      Text(this.searchText).fontSize(11).fontColor($r('app.color.gn_text_muted'))
        .textAlign(TextAlign.Center).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%').padding({ left: 18, right: 18, top: 24, bottom: 24 })
  }

  @Builder
  layerItem(item: LayerDisplayItem) {
    Row({ space: 6 }) {
      Blank().width(14)
      this.symbol($r('sys.symbol.chevron_right'), $r('sys.color.icon_secondary'), 11)
      this.symbol(this.resolveGeometryIcon(item.geomType),
        item.visible ? item.symbolColor : $r('sys.color.icon_secondary'), 16)
      Column() {
        Text(item.name).fontSize(13)
          .fontColor(item.visible ? $r('app.color.gn_text_primary') : $r('app.color.gn_text_muted'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.layerMeta(item)).fontSize(10).fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 2 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .height(42)
    .padding({ left: 8, right: 8 })
    .margin({ left: 6, right: 6, top: 1, bottom: 1 })
    .borderRadius(this.itemRadius)
    .backgroundColor(this.selectedLayerIndex === item.index ? $r('app.color.gn_arc_selected') : Color.Transparent)
    .onClick(() => {
      this.onSelectLayer(item.index);
    })
  }

  @Builder
  fieldItem(field: WorkbenchFieldItem) {
    Row({ space: 6 }) {
      Blank().width(32)
      this.symbol($r('sys.symbol.doc_text'), $r('sys.color.icon_secondary'), 13)
      Text(field.name).fontSize(12).fontColor($r('app.color.gn_text_primary')).layoutWeight(1)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(field.typeName).fontSize(10).fontColor($r('app.color.gn_text_muted'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(26).padding({ left: 8, right: 8 })
  }

  @Builder
  projectContent() {
    if (this.searchText.trim().length > 0) {
      if (this.filteredLayers.length === 0) {
        this.searchEmptyState()
      } else {
        ForEach(this.filteredLayers, (item: LayerDisplayItem) => {
          this.layerItem(item)
        }, (item: LayerDisplayItem) => 'catalog-search:' + item.stateKey)
      }
    } else {
      this.catalogItem($r('app.string.gn_workbench_project_catalog'), $r('sys.symbol.folder_fill'), 0, 1)
      this.catalogItem($r('app.string.gn_arc_maps'), $r('sys.symbol.map'), 0, 1)
      this.catalogItem($r('app.string.gn_map_section'), $r('sys.symbol.map'), 1, 1)
      Text(this.catalogSummary).fontSize(11).fontColor($r('app.color.gn_text_muted')).width('100%')
        .padding({ left: 38, top: 2, bottom: 4 })
      if (this.layerCount === 0) {
        Column() {
          Text($r('app.string.gn_catalog_no_layers_title')).fontSize(12).fontColor($r('app.color.gn_text_muted'))
          Text($r('app.string.gn_catalog_no_layers_desc')).fontSize(11)
            .fontColor($r('app.color.gn_text_muted')).margin({ top: 4 })
        }
        .width('100%').padding(12).alignItems(HorizontalAlign.Start)
      } else {
        ForEach(this.layers, (item: LayerDisplayItem) => {
          this.layerItem(item)
        }, (item: LayerDisplayItem) => 'catalog:' + item.stateKey)
        if (this.fields.length > 0) {
          Text($r('app.string.gn_catalog_fields')).fontSize(12).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_muted')).width('100%')
            .padding({ left: 12, top: 8, bottom: 4 })
          ForEach(this.fields, (field: WorkbenchFieldItem) => {
            this.fieldItem(field)
          }, (field: WorkbenchFieldItem) => this.catalogKey + ':field:' + field.name)
        }
      }
      this.catalogItem($r('app.string.gn_arc_toolboxes'), $r('sys.symbol.wrench_arrow_counterclockwise'), 0, 3)
      this.catalogItem($r('app.string.gn_arc_databases'), $r('sys.symbol.folder_fill'), 0, 1)
      this.catalogItem($r('app.string.gn_arc_styles'), $r('sys.symbol.paintpalette'), 0, 5)
      this.catalogItem($r('app.string.gn_arc_folders'), $r('sys.symbol.folder'), 0, 1)
      this.catalogItem($r('app.string.gn_arc_locators'), $r('sys.symbol.location_up'), 0, 1)
    }
  }

  build() {
    Column() {
      Text(this.catalogKey).width(0).height(0).fontSize(0).opacity(0)
      this.scopeTabs()
      this.navigationRow()
      Scroll() {
        Column() {
          if (this.section === WorkbenchCatalogSection.PROJECT) {
            this.projectContent()
          } else if (this.section === WorkbenchCatalogSection.PORTAL) {
            this.portalContent()
          } else if (this.section === WorkbenchCatalogSection.COMPUTER) {
            this.computerContent()
          } else {
            this.favoritesContent()
          }
          Blank()
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .layoutWeight(1)
  }
}
