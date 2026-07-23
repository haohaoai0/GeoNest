import {
  createCollaborationServiceMenuItems,
  CollaborationServiceFilter
} from '@kit.ServiceCollaborationKit';
import {
  BASEMAP_VECTOR,
  BASEMAP_ONLINE_STANDARD,
  BASEMAP_TERRAIN,
  BASEMAP_IMAGERY,
  BASEMAP_HARMONY_STANDARD,
  BASEMAP_HARMONY_TERRAIN,
  BASEMAP_HARMONY_IMAGERY,
  BASEMAP_DATUM_AUTO,
  BASEMAP_DATUM_WGS84,
  BASEMAP_DATUM_GCJ02,
  MAP_TOOL_IDENTIFY,
  MAP_TOOL_MEASURE_ANGLE,
  MAP_TOOL_MEASURE_AREA,
  MAP_TOOL_MEASURE_DISTANCE,
  MAP_TOOL_PICK_COORDINATE,
  MAP_TOOL_SELECT_MULTIPLE,
  MAP_TOOL_EDIT_ADD_POINT,
  MAP_TOOL_EDIT_ADD_LINE,
  MAP_TOOL_EDIT_ADD_POLYGON,
  MAP_TOOL_EDIT_MOVE_NODE,
  MAP_TOOL_EDIT_DELETE_NODE
} from '@geonest/common';
import { isCollaborationCapable, MaterialStyle } from '@geonest/common';
import {
  ACTION_EXPORT,
  ACTION_NEW_PROJECT,
  ACTION_OPEN_PROJECT,
  ACTION_PROJECT_INFO,
  ACTION_SAVE_PROJECT,
  ACTION_SETTINGS,
  BACKSTAGE_ABOUT,
  BACKSTAGE_HELP,
  BACKSTAGE_INFO,
  BACKSTAGE_SETTINGS
} from '../constants/WorkbenchConstants';

const ACTION_ATTRIBUTE_TABLE: number = 5;
const ACTION_ADD_DATA: number = 7;
const ACTION_ZOOM_IN: number = 8;
const ACTION_ZOOM_OUT: number = 9;
const ACTION_FULL_EXTENT: number = 10;
const ACTION_SYMBOLOGY: number = 11;
const ACTION_CLIP: number = 12;
const ACTION_BUFFER: number = 13;
const ACTION_REPAIR: number = 14;
const ACTION_QGIS_CORE: number = 21;
const ACTION_VECTOR_EDIT: number = 22;
const ACTION_ATTRIBUTE_EDIT: number = 23;
const ACTION_LABELING: number = 24;
const ACTION_RASTER_DISPLAY: number = 25;
const ACTION_LAYOUT: number = 26;
const ACTION_PRINT: number = 27;
const ACTION_DEFINE_PROJECTION: number = 28;
const ACTION_PROJECT_LAYER: number = 29;
const ACTION_ZOOM_SELECTED: number = 30;
const ACTION_CLEAR_SELECTION: number = 31;
const ACTION_SHOW_CATALOG: number = 33;
const ACTION_SHOW_TOOLBOX: number = 34;
const ACTION_EXPLORE: number = 35;
const ACTION_HELP: number = 40;
const ACTION_ABOUT: number = 41;
const ACTION_SHARE: number = 42;
const ACTION_CLOUD_MANAGE: number = 44;
const ACTION_CLOUD_PUSH: number = 45;
const ACTION_CLOUD_PULL: number = 46;
const ACTION_SPATIAL_JOIN_SUMMARY: number = 57;
const ACTION_EXPRESSION_WORKBENCH: number = 66;
const ACTION_QUALITY_CHECK: number = 70;
const ACTION_XY_TABLE_TO_POINT: number = 71;
const ACTION_TOPOLOGY_REVIEW: number = 72;
const ACTION_PORTABLE_PROJECT: number = 73;
const ACTION_LAYOUT_ATLAS: number = 74;
const ACTION_OPEN_SECOND_MAP: number = 75;
const ACTION_TOGGLE_LINKED_VIEW: number = 76;
const ACTION_COPY_MAP_CONTEXT: number = 77;
const ACTION_PASTE_CLIPBOARD: number = 78;

const RIBBON_PROJECT: number = 0;
const RIBBON_MAP: number = 1;
const RIBBON_INSERT: number = 2;
const RIBBON_ANALYSIS: number = 3;
const RIBBON_VIEW: number = 4;
const RIBBON_EDIT: number = 5;
const RIBBON_IMAGERY: number = 6;
const RIBBON_SHARE: number = 7;

@Component
export struct WorkbenchRibbonPanel {
  @Prop activeTab: number = RIBBON_MAP;
  @Prop mapToolMode: number = 0;
  @Prop basemapMode: number = BASEMAP_VECTOR;
  @Prop basemapName: string = '';
  @Prop linkedMapViewEnabled: boolean = false;
  @Prop itemRadius: number = 6;
  onOperation: (actionId: number) => void = (actionId: number): void => {};
  onSetMapToolMode: (toolMode: number) => void = (toolMode: number): void => {};
  onSetBasemapMode: (mode: number) => void = (mode: number): void => {};
  onSetBasemapDatumMode: (mode: number) => void = (mode: number): void => {};
  onRestoreSidePanel: (side: number) => void = (side: number): void => {};
  onOpenBackstage: (section: number) => void = (section: number): void => {};
  onImportFromLocal: () => void = (): void => {};

  @Builder
  symbol(icon: Resource, color: ResourceColor, sizeValue: number) {
    SymbolGlyph(icon).fontSize(sizeValue).fontColor([color])
  }

  @Builder
  operationButton(label: ResourceStr, icon: Resource, actionId: number, active: boolean) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 4 }) {
        this.symbol(icon, active ? $r('app.color.gn_blue_800') : $r('sys.color.icon_secondary'), 21)
        Text(label)
          .fontSize(11)
          .fontColor($r('app.color.gn_text_primary'))
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(68)
      .alignItems(HorizontalAlign.Center)
    }
    .width(72)
    .height(52)
    .padding(0)
    .borderRadius(this.itemRadius)
    .backgroundBlurStyle(MaterialStyle.componentBlurStyle())
    .backgroundColor(active ? $r('app.color.gn_arc_active') : Color.Transparent)
    .onClick(() => {
      this.onOperation(actionId);
    })
  }


  // ★ 跨设备互通菜单（添加数据：本机 + 远端设备）
  @Builder
  CollabAddDataMenu() {
    Menu() {
      MenuItem({ content: '从本机选择' })
        .onClick(() => { this.onImportFromLocal(); })
      createCollaborationServiceMenuItems([CollaborationServiceFilter.ALL])
    }
  }

  @Builder
  basemapMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.gn_workbench_basemap_osm') })
        .onClick(() => {
          this.onSetBasemapMode(BASEMAP_ONLINE_STANDARD);
        })
      MenuItem({ content: $r('app.string.gn_workbench_basemap_topo') })
        .onClick(() => {
          this.onSetBasemapMode(BASEMAP_TERRAIN);
        })
      MenuItem({ content: $r('app.string.gn_workbench_basemap_voyager') })
        .onClick(() => {
          this.onSetBasemapMode(BASEMAP_IMAGERY);
        })
      MenuItem({ content: $r('app.string.gn_workbench_basemap_harmony_standard') })
        .onClick(() => {
          this.onSetBasemapMode(BASEMAP_HARMONY_STANDARD);
        })
      MenuItem({ content: $r('app.string.gn_workbench_basemap_harmony_terrain') })
        .onClick(() => {
          this.onSetBasemapMode(BASEMAP_HARMONY_TERRAIN);
        })
      MenuItem({ content: $r('app.string.gn_workbench_basemap_harmony_imagery') })
        .onClick(() => {
          this.onSetBasemapMode(BASEMAP_HARMONY_IMAGERY);
        })
      MenuItem({ content: $r('app.string.gn_workbench_basemap_vector') })
        .onClick(() => {
          this.onSetBasemapMode(BASEMAP_VECTOR);
        })
      MenuItem({ content: '坐标模式：自动' })
        .onClick(() => {
          this.onSetBasemapDatumMode(BASEMAP_DATUM_AUTO);
        })
      MenuItem({ content: '坐标模式：原始/WGS84' })
        .onClick(() => {
          this.onSetBasemapDatumMode(BASEMAP_DATUM_WGS84);
        })
      MenuItem({ content: '坐标模式：转 GCJ-02' })
        .onClick(() => {
          this.onSetBasemapDatumMode(BASEMAP_DATUM_GCJ02);
        })
    }
  }


  @Builder
  basemapButton(label: ResourceStr, icon: Resource) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 4 }) {
        this.symbol(icon, this.basemapMode === BASEMAP_VECTOR ? $r('sys.color.icon_secondary') :
          $r('app.color.gn_blue_800'), 21)
        Text(label)
          .fontSize(11)
          .fontColor(this.basemapMode === BASEMAP_VECTOR ? $r('app.color.gn_text_primary') :
            $r('app.color.gn_blue_800'))
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.basemapName)
          .fontSize(9)
          .fontColor($r('app.color.gn_text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(68)
      .alignItems(HorizontalAlign.Center)
    }
    .width(72)
    .height(52)
    .padding(0)
    .borderRadius(5)
    .backgroundBlurStyle(MaterialStyle.componentBlurStyle())
    .backgroundColor(Color.Transparent)
    .bindMenu(this.basemapMenu)
  }

  @Builder
  compactButton(label: ResourceStr, icon: Resource, actionId: number) {
    Row({ space: 6 }) {
      this.symbol(icon, $r('sys.color.icon_secondary'), 15)
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(24)
    .width(106)
    .padding({ left: 4, right: 4 })
    .onClick(() => {
      if (actionId > 0) {
        this.onOperation(actionId);
      }
    })
  }

  @Builder
  compactToolButton(label: ResourceStr, icon: Resource, toolMode: number) {
    Row({ space: 6 }) {
      this.symbol(icon, this.mapToolMode === toolMode ? $r('app.color.gn_blue_800') :
        $r('sys.color.icon_secondary'), 15)
      Text(label)
        .fontSize(12)
        .fontColor(this.mapToolMode === toolMode ? $r('app.color.gn_blue_800') :
          $r('app.color.gn_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(24)
    .width(106)
    .padding({ left: 4, right: 4 })
    .borderRadius(this.itemRadius)
    .backgroundColor(this.mapToolMode === toolMode ? $r('app.color.gn_arc_active') : Color.Transparent)
    .onClick(() => {
      this.onSetMapToolMode(toolMode);
    })
  }

  @Builder
  ribbonToolModeButton(label: ResourceStr, icon: Resource, toolMode: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 4 }) {
        this.symbol(icon, this.mapToolMode === toolMode ? $r('app.color.gn_blue_800') :
          $r('sys.color.icon_secondary'), 21)
        Text(label)
          .fontSize(11)
          .fontColor(this.mapToolMode === toolMode ? $r('app.color.gn_blue_800') :
            $r('app.color.gn_text_primary'))
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(68)
      .alignItems(HorizontalAlign.Center)
    }
    .width(72)
    .height(52)
    .padding(0)
    .borderRadius(this.itemRadius)
    .backgroundBlurStyle(MaterialStyle.componentBlurStyle())
    .backgroundColor(this.mapToolMode === toolMode ? $r('app.color.gn_arc_active') : Color.Transparent)
    .onClick(() => {
      this.onSetMapToolMode(toolMode);
    })
  }

  @Builder
  ribbonPanelButton(label: ResourceStr, icon: Resource, side: number) {
    Row({ space: 6 }) {
      this.symbol(icon, $r('sys.color.icon_secondary'), 15)
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(24)
    .width(112)
    .padding({ left: 4, right: 4 })
    .onClick(() => {
      this.onRestoreSidePanel(side);
    })
  }

  @Builder
  ribbonBackstageButton(label: ResourceStr, icon: Resource, section: number) {
    Row({ space: 6 }) {
      this.symbol(icon, $r('sys.color.icon_secondary'), 15)
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(24)
    .width(112)
    .padding({ left: 4, right: 4 })
    .onClick(() => {
      this.onOpenBackstage(section);
    })
  }

  @Builder
  ribbonSectionDivider() {
    Blank()
      .width(1)
      .height(46)
      .margin({ left: 2, right: 2, top: 3, bottom: 3 })
      .backgroundColor($r('app.color.gn_line'))
  }


  @Builder
  operationGroup(title: ResourceStr, groupIndex: number, widthValue: number) {
    Column() {
      Row({ space: 4 }) {
        if (groupIndex === 0) {
          this.operationButton($r('app.string.gn_workbench_new'), $r('sys.symbol.doc_text'), ACTION_NEW_PROJECT, false)
          this.operationButton($r('app.string.gn_workbench_open'), $r('sys.symbol.folder'), ACTION_OPEN_PROJECT, false)
          this.operationButton($r('app.string.gn_workbench_save'), $r('sys.symbol.archivebox_fill'), ACTION_SAVE_PROJECT, false)
          this.operationButton($r('app.string.gn_project_info'), $r('sys.symbol.info_circle'), ACTION_PROJECT_INFO,
            false)
        } else if (groupIndex === 1) {
          this.operationButton($r('app.string.gn_cmd_explore'), $r('sys.symbol.hand_tap'), ACTION_EXPLORE, true)
          Column() {
            this.compactButton($r('app.string.gn_workbench_zoom_in'), $r('sys.symbol.plus_magnifyingglass'), ACTION_ZOOM_IN)
            this.compactButton($r('app.string.gn_workbench_zoom_out'), $r('sys.symbol.minus_magnifyingglass'), ACTION_ZOOM_OUT)
            this.compactButton($r('app.string.gn_workbench_full_extent'),
              $r('sys.symbol.arrow_up_left_and_arrow_down_right'), ACTION_FULL_EXTENT)
          }
        } else if (groupIndex === 2) {
          if (isCollaborationCapable()) {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Column({ space: 4 }) {
                this.symbol($r('sys.symbol.plus_layer'), $r('sys.color.icon_secondary'), 21)
                Text($r('app.string.gn_cmd_add_data'))
                  .fontSize(11)
                  .fontColor($r('app.color.gn_text_primary'))
                  .textAlign(TextAlign.Center)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width(68)
              .alignItems(HorizontalAlign.Center)
            }
            .width(72)
            .height(52)
            .padding(0)
            .borderRadius(this.itemRadius)
            .backgroundBlurStyle(MaterialStyle.componentBlurStyle())
            .backgroundColor(Color.Transparent)
            .bindMenu(this.CollabAddDataMenu)
          } else {
            this.operationButton($r('app.string.gn_cmd_add_data'), $r('sys.symbol.plus_layer'), ACTION_ADD_DATA, false)
          }
          this.basemapButton($r('app.string.gn_cmd_basemap'), $r('sys.symbol.map'))
          Column() {
            this.compactButton($r('app.string.gn_workbench_attribute_table'), $r('sys.symbol.doc_text'),
              ACTION_ATTRIBUTE_TABLE)
            this.compactButton($r('app.string.gn_symbology'), $r('sys.symbol.paintpalette'), ACTION_SYMBOLOGY)
          }
          Column() {
            this.compactButton('标注', $r('sys.symbol.doc_text'), ACTION_LABELING)
          }
        } else if (groupIndex === 3) {
          this.operationButton($r('app.string.gn_cmd_clip'), $r('sys.symbol.square_dashed_and_arrow_turn_up_right'),
            ACTION_CLIP, false)
          this.operationButton($r('app.string.gn_cmd_buffer'), $r('sys.symbol.circle_grid_2x2'), ACTION_BUFFER, false)
          this.operationButton($r('app.string.gn_cmd_repair'), $r('sys.symbol.wrench_arrow_counterclockwise'),
            ACTION_REPAIR, false)
          Column() {
            this.compactButton($r('app.string.gn_cmd_define_projection'), $r('sys.symbol.map'),
              ACTION_DEFINE_PROJECTION)
            this.compactButton($r('app.string.gn_cmd_project_layer'), $r('sys.symbol.arrow_right_and_square'),
              ACTION_PROJECT_LAYER)
          }
        } else if (groupIndex === 4) {
          this.operationButton($r('app.string.gn_qgis_core_title'), $r('sys.symbol.wrench_arrow_counterclockwise'),
            ACTION_QGIS_CORE,
            false)
          this.operationButton($r('app.string.gn_ribbon_layout'), $r('sys.symbol.doc_text'), ACTION_LAYOUT, false)
          this.operationButton($r('app.string.gn_cmd_export'), $r('sys.symbol.download'), ACTION_EXPORT, false)
          this.operationButton($r('app.string.gn_sync'), $r('sys.symbol.arrow_clockwise'), ACTION_SAVE_PROJECT, false)
        } else if (groupIndex === 5) {
          this.ribbonToolModeButton($r('app.string.gn_measure_distance'), $r('sys.symbol.plus_magnifyingglass'),
            MAP_TOOL_MEASURE_DISTANCE)
          this.ribbonToolModeButton($r('app.string.gn_measure_area'), $r('sys.symbol.layer'), MAP_TOOL_MEASURE_AREA)
          this.ribbonToolModeButton($r('app.string.gn_measure_angle'), $r('sys.symbol.map'), MAP_TOOL_MEASURE_ANGLE)
          this.ribbonToolModeButton($r('app.string.gn_pick_coordinate'), $r('sys.symbol.location_up'),
            MAP_TOOL_PICK_COORDINATE)
        } else if (groupIndex === 6) {
          Column() {
            this.ribbonPanelButton($r('app.string.gn_ribbon_contents_pane'), $r('sys.symbol.layer'), 0)
            this.ribbonPanelButton($r('app.string.gn_ribbon_catalog_pane'), $r('sys.symbol.folder_fill'), 1)
          }
          Column() {
            this.compactButton($r('app.string.gn_workbench_full_extent'),
              $r('sys.symbol.arrow_up_left_and_arrow_down_right'), ACTION_FULL_EXTENT)
            this.compactButton($r('app.string.gn_workbench_zoom_in'), $r('sys.symbol.plus_magnifyingglass'),
              ACTION_ZOOM_IN)
          }
        } else if (groupIndex === 7) {
          this.operationButton($r('app.string.gn_ribbon_vector_edit'), $r('sys.symbol.wrench_arrow_counterclockwise'),
            ACTION_VECTOR_EDIT, false)
          this.operationButton($r('app.string.gn_ribbon_attribute_edit'), $r('sys.symbol.doc_text'),
            ACTION_ATTRIBUTE_EDIT, false)
          this.ribbonToolModeButton($r('app.string.gn_ribbon_add_point'), $r('sys.symbol.location_up'),
            MAP_TOOL_EDIT_ADD_POINT)
          this.ribbonToolModeButton($r('app.string.gn_ribbon_add_line'), $r('sys.symbol.road_lanes_badge_minus'),
            MAP_TOOL_EDIT_ADD_LINE)
          this.ribbonToolModeButton($r('app.string.gn_ribbon_add_polygon'), $r('sys.symbol.layer'),
            MAP_TOOL_EDIT_ADD_POLYGON)
          this.ribbonToolModeButton($r('app.string.gn_ribbon_move_node'), $r('sys.symbol.hand_tap'),
            MAP_TOOL_EDIT_MOVE_NODE)
          this.ribbonToolModeButton($r('app.string.gn_ribbon_delete_node'), $r('sys.symbol.trash'),
            MAP_TOOL_EDIT_DELETE_NODE)
        } else if (groupIndex === 8) {
          this.operationButton($r('app.string.gn_ribbon_raster_display'), $r('sys.symbol.satellite_map'),
            ACTION_RASTER_DISPLAY, false)
        } else if (groupIndex === 9) {
          this.operationButton($r('app.string.gn_ribbon_layout'), $r('sys.symbol.doc_text'), ACTION_LAYOUT, false)
          this.operationButton($r('app.string.gn_workbench_print'), $r('sys.symbol.printer'), ACTION_PRINT, false)
          this.operationButton($r('app.string.gn_cmd_export'), $r('sys.symbol.download'), ACTION_EXPORT, false)
          this.operationButton($r('app.string.gn_workbench_save'), $r('sys.symbol.archivebox_fill'),
            ACTION_SAVE_PROJECT, false)
        } else if (groupIndex === 10) {
          this.operationButton($r('app.string.gn_settings_title'), $r('sys.symbol.gearshape'),
            ACTION_SETTINGS, false)
          this.operationButton($r('app.string.gn_backstage_help'), $r('sys.symbol.questionmark_circle'),
            ACTION_HELP, false)
          this.operationButton($r('app.string.gn_backstage_about'), $r('sys.symbol.info_shield'),
            ACTION_ABOUT, false)
        } else if (groupIndex === 11) {
          this.operationButton($r('app.string.gn_new_project_title'), $r('sys.symbol.doc_text'), ACTION_NEW_PROJECT,
            false)
          this.operationButton($r('app.string.gn_project_info'), $r('sys.symbol.info_circle'), ACTION_PROJECT_INFO,
            false)
        } else if (groupIndex === 12) {
          this.operationButton($r('app.string.gn_cmd_add_data'), $r('sys.symbol.plus_layer'), ACTION_ADD_DATA, false)
          this.operationButton($r('app.string.gn_workbench_catalog_tab'), $r('sys.symbol.folder_fill'),
            ACTION_SHOW_CATALOG, false)
        } else if (groupIndex === 13) {
          this.ribbonToolModeButton($r('app.string.gn_ribbon_add_point'), $r('sys.symbol.location_up'),
            MAP_TOOL_EDIT_ADD_POINT)
          this.ribbonToolModeButton($r('app.string.gn_ribbon_add_line'), $r('sys.symbol.road_lanes_badge_minus'),
            MAP_TOOL_EDIT_ADD_LINE)
          this.ribbonToolModeButton($r('app.string.gn_ribbon_add_polygon'), $r('sys.symbol.layer'),
            MAP_TOOL_EDIT_ADD_POLYGON)
          this.operationButton($r('app.string.gn_cmd_labeling'), $r('sys.symbol.doc_text'), ACTION_LABELING, false)
        } else if (groupIndex === 14) {
          this.operationButton($r('app.string.gn_qgis_core_title'), $r('sys.symbol.wrench_arrow_counterclockwise'),
            ACTION_QGIS_CORE, false)
          this.operationButton('模型构建器', $r('sys.symbol.list_checkmark'), ACTION_QGIS_CORE, false)
          this.operationButton($r('app.string.gn_arc_python'), $r('sys.symbol.doc_text'), ACTION_QGIS_CORE, false)
          Column() {
            this.compactButton('历史', $r('sys.symbol.doc_text_badge_clock'), ACTION_QGIS_CORE)
            this.compactButton('环境', $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_QGIS_CORE)
          }
        } else if (groupIndex === 15) {
          this.operationButton($r('app.string.gn_cmd_clip'), $r('sys.symbol.square_dashed_and_arrow_turn_up_right'),
            ACTION_CLIP, false)
          this.operationButton($r('app.string.gn_cmd_buffer'), $r('sys.symbol.circle_grid_2x2'), ACTION_BUFFER, false)
          this.operationButton('空间连接', $r('sys.symbol.plus_square_on_square'), ACTION_SPATIAL_JOIN_SUMMARY, false)
          Column() {
            this.compactButton($r('app.string.gn_cmd_repair'), $r('sys.symbol.wrench_arrow_counterclockwise'),
              ACTION_REPAIR)
            this.compactButton($r('app.string.gn_expression_workbench_title'), $r('sys.symbol.calculator'),
              ACTION_EXPRESSION_WORKBENCH)
          }
        } else if (groupIndex === 16) {
          Column() {
            this.ribbonPanelButton($r('app.string.gn_ribbon_contents_pane'), $r('sys.symbol.layer'), 0)
            this.ribbonPanelButton($r('app.string.gn_ribbon_catalog_pane'), $r('sys.symbol.folder_fill'), 1)
          }
          this.operationButton($r('app.string.gn_workbench_tools_tab'),
            $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_SHOW_TOOLBOX, false)
        } else if (groupIndex === 17) {
          this.operationButton($r('app.string.gn_cmd_define_projection'), $r('sys.symbol.map'),
            ACTION_DEFINE_PROJECTION, false)
          this.operationButton($r('app.string.gn_cmd_project_layer'), $r('sys.symbol.arrow_right_and_square'),
            ACTION_PROJECT_LAYER, false)
          Column() {
            this.compactButton($r('app.string.gn_arc_coordinate_conversion'), $r('sys.symbol.location_up'),
              ACTION_PROJECT_LAYER)
            this.compactToolButton($r('app.string.gn_arc_go_to_xy'), $r('sys.symbol.location_up'),
              MAP_TOOL_PICK_COORDINATE)
          }
        } else if (groupIndex === 18) {
          this.operationButton($r('app.string.gn_ribbon_raster_display'), $r('sys.symbol.satellite_map'),
            ACTION_RASTER_DISPLAY, false)
          this.operationButton('栅格函数', $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_QGIS_CORE, false)
          this.operationButton($r('app.string.gn_data_reviewer'), $r('sys.symbol.list_checkmark'), ACTION_QUALITY_CHECK,
            false)
          Column() {
            this.compactButton('色带', $r('sys.symbol.paintpalette'), ACTION_RASTER_DISPLAY)
            this.compactButton('阴影地形', $r('sys.symbol.map'), ACTION_RASTER_DISPLAY)
          }
        } else if (groupIndex === 19) {
          this.operationButton($r('app.string.gn_workbench_print'), $r('sys.symbol.printer'), ACTION_PRINT, false)
          this.ribbonSectionDivider()
          this.operationButton($r('app.string.gn_cmd_cloud_manage'), $r('sys.symbol.archivebox_fill'),
            ACTION_CLOUD_MANAGE, false)
          Column() {
            this.compactButton($r('app.string.gn_cmd_cloud_push'), $r('sys.symbol.arrow_clockwise'),
              ACTION_CLOUD_PUSH)
            this.compactButton($r('app.string.gn_cmd_cloud_pull'), $r('sys.symbol.download'), ACTION_CLOUD_PULL)
          }
          Column() {
            this.compactButton($r('app.string.gn_cmd_export'), $r('sys.symbol.download'), ACTION_EXPORT)
            this.compactButton($r('app.string.gn_cmd_share'), $r('sys.symbol.share'), ACTION_SHARE)
          }
        } else if (groupIndex === 20) {
          this.ribbonToolModeButton($r('app.string.gn_tool_identify'), $r('sys.symbol.hand_tap'), MAP_TOOL_IDENTIFY)
          this.operationButton('缩放至选中', $r('sys.symbol.plus_magnifyingglass'), ACTION_ZOOM_SELECTED, false)
          Column() {
            this.compactToolButton($r('app.string.gn_tool_select_multiple'), $r('sys.symbol.checkmark_square'),
              MAP_TOOL_SELECT_MULTIPLE)
            this.compactButton('清除选择', $r('sys.symbol.xmark'), ACTION_CLEAR_SELECTION)
          }
        } else if (groupIndex === 21) {
          this.operationButton($r('app.string.gn_cmd_explore'), $r('sys.symbol.hand_tap'), ACTION_EXPLORE, true)
          this.operationButton($r('app.string.gn_workbench_full_extent'),
            $r('sys.symbol.arrow_up_left_and_arrow_down_right'), ACTION_FULL_EXTENT, false)
          Column() {
            this.compactButton($r('app.string.gn_workbench_zoom_in'), $r('sys.symbol.plus_magnifyingglass'),
              ACTION_ZOOM_IN)
            this.compactButton($r('app.string.gn_workbench_zoom_out'), $r('sys.symbol.minus_magnifyingglass'),
              ACTION_ZOOM_OUT)
          }
        } else if (groupIndex === 22) {
          this.operationButton($r('app.string.gn_cmd_add_data'), $r('sys.symbol.plus_layer'), ACTION_ADD_DATA, false)
          this.operationButton($r('app.string.gn_cmd_export'), $r('sys.symbol.download'), ACTION_EXPORT, false)
          Column() {
            this.compactButton($r('app.string.gn_cmd_define_projection'), $r('sys.symbol.map'),
              ACTION_DEFINE_PROJECTION)
            this.compactButton($r('app.string.gn_cmd_project_layer'), $r('sys.symbol.arrow_right_and_square'),
              ACTION_PROJECT_LAYER)
          }
          Column() {
            this.compactButton('目录', $r('sys.symbol.folder_fill'), ACTION_SHOW_CATALOG)
          }
        } else if (groupIndex === 23) {
          this.operationButton($r('app.string.gn_ribbon_layout'), $r('sys.symbol.doc_text'), ACTION_LAYOUT, false)
          this.basemapButton($r('app.string.gn_cmd_basemap'), $r('sys.symbol.map'))
          Column() {
            this.compactButton('地图集', $r('sys.symbol.doc_text'), ACTION_LAYOUT_ATLAS)
            this.compactButton($r('app.string.gn_workbench_print'), $r('sys.symbol.printer'), ACTION_PRINT)
          }
        } else if (groupIndex === 24) {
          this.operationButton($r('app.string.gn_ribbon_vector_edit'), $r('sys.symbol.wrench_arrow_counterclockwise'),
            ACTION_VECTOR_EDIT, false)
          this.operationButton($r('app.string.gn_ribbon_attribute_edit'), $r('sys.symbol.doc_text'),
            ACTION_ATTRIBUTE_EDIT, false)
          this.operationButton($r('app.string.gn_expression_workbench_title'), $r('sys.symbol.calculator'),
            ACTION_EXPRESSION_WORKBENCH, false)
          Column() {
            this.compactButton('复制要素', $r('sys.symbol.doc_text'), ACTION_VECTOR_EDIT)
            this.compactButton('吸附设置', $r('sys.symbol.location_up'), ACTION_VECTOR_EDIT)
          }
        } else if (groupIndex === 25) {
          this.operationButton('栅格函数', $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_QGIS_CORE, false)
          this.operationButton('栅格裁剪', $r('sys.symbol.square_dashed_and_arrow_turn_up_right'), ACTION_CLIP, false)
          this.operationButton('重采样', $r('sys.symbol.map'), ACTION_RASTER_DISPLAY, false)
          Column() {
            this.compactButton('拉伸显示', $r('sys.symbol.paintpalette'), ACTION_RASTER_DISPLAY)
            this.compactButton('NoData', $r('sys.symbol.xmark'), ACTION_RASTER_DISPLAY)
          }
        } else if (groupIndex === 26) {
          this.basemapButton($r('app.string.gn_cmd_basemap'), $r('sys.symbol.map'))
          this.operationButton($r('app.string.gn_cmd_add_data'), $r('sys.symbol.plus_layer'), ACTION_ADD_DATA, false)
          Column() {
            this.compactButton($r('app.string.gn_arc_xy_table'), $r('sys.symbol.location_up'),
              ACTION_XY_TABLE_TO_POINT)
          }
        } else if (groupIndex === 27) {
          this.ribbonToolModeButton($r('app.string.gn_measure_distance'), $r('sys.symbol.plus_magnifyingglass'),
            MAP_TOOL_MEASURE_DISTANCE)
          this.ribbonToolModeButton($r('app.string.gn_measure_area'), $r('sys.symbol.layer'), MAP_TOOL_MEASURE_AREA)
          this.ribbonToolModeButton($r('app.string.gn_pick_coordinate'), $r('sys.symbol.location_up'),
            MAP_TOOL_PICK_COORDINATE)
          Column() {
            this.compactToolButton($r('app.string.gn_arc_go_to_xy'), $r('sys.symbol.location_up'),
              MAP_TOOL_PICK_COORDINATE)
          }
        } else if (groupIndex === 28) {
          this.operationButton('标注设置', $r('sys.symbol.doc_text'), ACTION_LABELING, false)
        } else if (groupIndex === 29) {
          this.operationButton($r('app.string.gn_workbench_save'), $r('sys.symbol.archivebox_fill'), ACTION_SAVE_PROJECT,
            false)
        } else if (groupIndex === 30) {
          this.operationButton('新建地图', $r('sys.symbol.map'), ACTION_NEW_PROJECT, false)
          this.operationButton('新建布局', $r('sys.symbol.doc_text'), ACTION_LAYOUT, false)
          Column() {
            this.compactButton('工具箱', $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_SHOW_TOOLBOX)
          }
        } else if (groupIndex === 31) {
          this.operationButton($r('app.string.gn_cmd_add_data'), $r('sys.symbol.plus_layer'), ACTION_ADD_DATA, false)
          this.operationButton($r('app.string.gn_workbench_catalog_tab'), $r('sys.symbol.folder_fill'),
            ACTION_SHOW_CATALOG, false)
          Column() {
            this.compactButton($r('app.string.gn_arc_xy_table'), $r('sys.symbol.location_up'),
              ACTION_XY_TABLE_TO_POINT)
          }
        } else if (groupIndex === 32) {
          this.ribbonToolModeButton('点笔记', $r('sys.symbol.location_up'), MAP_TOOL_EDIT_ADD_POINT)
          this.ribbonToolModeButton('线笔记', $r('sys.symbol.road_lanes_badge_minus'), MAP_TOOL_EDIT_ADD_LINE)
          this.ribbonToolModeButton('面笔记', $r('sys.symbol.layer'), MAP_TOOL_EDIT_ADD_POLYGON)
          this.operationButton('文本笔记', $r('sys.symbol.doc_text'), ACTION_LABELING, false)
          Column() {
            this.compactToolButton('距离方向', $r('sys.symbol.plus_magnifyingglass'), MAP_TOOL_MEASURE_DISTANCE)
          }
        } else if (groupIndex === 33) {
          this.operationButton('模型构建器', $r('sys.symbol.list_checkmark'), ACTION_QGIS_CORE, false)
          this.operationButton($r('app.string.gn_arc_python'), $r('sys.symbol.doc_text'), ACTION_QGIS_CORE, false)
          this.operationButton('栅格函数', $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_QGIS_CORE, false)
        } else if (groupIndex === 34) {
          this.operationButton($r('app.string.gn_cmd_second_map'), $r('sys.symbol.map'), ACTION_OPEN_SECOND_MAP, false)
          this.operationButton($r('app.string.gn_cmd_link_view'), $r('sys.symbol.location_up'),
            ACTION_TOGGLE_LINKED_VIEW, this.linkedMapViewEnabled)
        } else if (groupIndex === 35) {
          this.operationButton($r('app.string.gn_cmd_copy_clipboard'), $r('sys.symbol.doc_text'),
            ACTION_COPY_MAP_CONTEXT, false)
          this.operationButton($r('app.string.gn_cmd_paste_clipboard'), $r('sys.symbol.doc_text'),
            ACTION_PASTE_CLIPBOARD, false)
          this.operationButton('保存编辑', $r('sys.symbol.archivebox_fill'), ACTION_SAVE_PROJECT, false)
          Column() {
            this.compactButton('拓扑质检', $r('sys.symbol.layer'), ACTION_QUALITY_CHECK)
            this.compactButton('错误检查器', $r('sys.symbol.exclamationmark_triangle'), ACTION_TOPOLOGY_REVIEW)
          }
          Column() {
            this.compactButton('吸附设置', $r('sys.symbol.location_up'), ACTION_VECTOR_EDIT)
            this.compactButton($r('app.string.gn_data_reviewer'), $r('sys.symbol.list_checkmark'), ACTION_QUALITY_CHECK)
          }
        } else if (groupIndex === 36) {
          this.operationButton('栅格函数', $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_QGIS_CORE, false)
        } else if (groupIndex === 37) {
          this.operationButton('工程包', $r('sys.symbol.archivebox_fill'), ACTION_PORTABLE_PROJECT, false)
          this.operationButton('地图包', $r('sys.symbol.map'), ACTION_EXPORT, false)
          this.operationButton('移动地图', $r('sys.symbol.map'), ACTION_EXPORT, false)
          Column() {
            this.compactButton('工程模板', $r('sys.symbol.doc_text'), ACTION_SAVE_PROJECT)
            this.compactButton('导出地图', $r('sys.symbol.download'), ACTION_EXPORT)
          }
        } else if (groupIndex === 38) {
          this.operationButton($r('app.string.gn_settings_title'), $r('sys.symbol.gearshape'),
            ACTION_SETTINGS, false)
          this.operationButton($r('app.string.gn_backstage_help'), $r('sys.symbol.questionmark_circle'),
            ACTION_HELP, false)
          this.operationButton($r('app.string.gn_backstage_about'), $r('sys.symbol.info_circle'), ACTION_ABOUT, false)
        } else {
          this.operationButton($r('app.string.gn_project_info'), $r('sys.symbol.info_circle'), ACTION_PROJECT_INFO,
            false)
          this.operationButton($r('app.string.gn_qgis_core_title'), $r('sys.symbol.wrench_arrow_counterclockwise'),
            ACTION_QGIS_CORE, false)
          Column() {
            this.operationButton($r('app.string.gn_backstage_help'), $r('sys.symbol.questionmark_circle'),
              ACTION_HELP, false)
            this.operationButton($r('app.string.gn_backstage_about'), $r('sys.symbol.info_shield'),
              ACTION_ABOUT, false)
          }
        }
      }
      .height(58)
      .alignItems(VerticalAlign.Center)

      Text(title)
        .height(16)
        .fontSize(10)
        .fontColor($r('app.color.gn_text_muted'))
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width(widthValue)
    .height(74)
    .padding({ left: 8, right: 8 })
    .border({ width: { right: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  ribbonContent() {
    Row() {
      if (this.activeTab === RIBBON_PROJECT) {
        this.operationGroup($r('app.string.gn_workbench_group_project'), 0, 316)
      } else if (this.activeTab === RIBBON_MAP) {
        this.operationGroup('导航', 21, 430)
        this.operationGroup('图层', 2, 390)
        this.operationGroup('选择', 20, 330)
        this.operationGroup('量算', 5, 360)
      } else if (this.activeTab === RIBBON_INSERT) {
        this.operationGroup($r('app.string.gn_ribbon_group_insert_new'), 30, 286)
        this.operationGroup($r('app.string.gn_workbench_data_sources'), 31, 286)
        this.operationGroup($r('app.string.gn_ribbon_group_insert_graphics'), 32, 310)
        this.operationGroup($r('app.string.gn_ribbon_group_insert_map_elements'), 23, 270)
      } else if (this.activeTab === RIBBON_ANALYSIS) {
        this.operationGroup($r('app.string.gn_workbench_group_analysis'), 3, 390)
        this.operationGroup('建模与高级分析', 33, 256)
      } else if (this.activeTab === RIBBON_VIEW) {
        this.operationGroup('窗格', 16, 260)
        this.operationGroup('多地图与辅助视图', 34, 188)
      } else if (this.activeTab === RIBBON_EDIT) {
        this.operationGroup($r('app.string.gn_workbench_group_edit_tools'), 7, 540)
        this.operationGroup('编辑事务与检查', 35, 430)
      } else if (this.activeTab === RIBBON_IMAGERY) {
        this.operationGroup($r('app.string.gn_workbench_group_imagery'), 8, 180)
        this.operationGroup('影像处理', 36, 120)
      } else if (this.activeTab === RIBBON_SHARE) {
        this.operationGroup($r('app.string.gn_workbench_group_share'), 19, 430)
        this.operationGroup('打包与发布', 37, 370)
      } else {
        this.operationGroup($r('app.string.gn_workbench_group_help'), 10, 268)
      }
    }
    .height(74)
  }


  build() {
    Scroll() {
      this.ribbonContent()
    }
    .width('100%')
    .height(76)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Auto)
    .scrollBarWidth(5)
    .backgroundColor($r('app.color.gn_pane'))
  }
}
