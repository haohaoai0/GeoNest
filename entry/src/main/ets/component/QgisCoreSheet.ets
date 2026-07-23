import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '@geonest/common';
import { getGisService, GisLoadedLayer } from '../gis/GisService';
import { GisNativeBridgeStatus, queryGisNativeBridgeStatus } from '../gis/GisNativeBridge';
import { GisOperationResult } from '../model/GeoNestModels';
import {
  GIS_TOOL_MODE_CONVEX_HULL,
  GIS_TOOL_MODE_BOUNDING_BOXES,
  GIS_TOOL_MODE_ORIENTED_MINIMUM_BOUNDING_BOX,
  GIS_TOOL_MODE_MULTIPART_TO_SINGLEPARTS,
  GIS_TOOL_MODE_EXTRACT_BY_EXPRESSION,
  GIS_TOOL_MODE_DIFFERENCE,
  GIS_TOOL_MODE_SYMMETRICAL_DIFFERENCE,
  GIS_TOOL_MODE_MERGE_LAYERS,
  GIS_TOOL_MODE_MULTI_RING_BUFFER,
  GIS_TOOL_MODE_EXTRACT_BY_LOCATION,
  GIS_TOOL_MODE_SPATIAL_JOIN_SUMMARY,
  GIS_TOOL_MODE_INTERSECTION,
  GIS_TOOL_MODE_NEAREST_NEIGHBOR,
  GIS_TOOL_MODE_VORONOI,
  GIS_TOOL_MODE_KERNEL_DENSITY,
  GIS_TOOL_MODE_POINT_DENSITY,
  GIS_TOOL_MODE_LINE_DENSITY,
  GIS_TOOL_MODE_IDW,
  GIS_TOOL_MODE_RASTER_SLOPE,
  GIS_TOOL_MODE_RASTER_ASPECT,
  GIS_TOOL_MODE_RASTER_RECLASSIFY,
  GIS_TOOL_MODE_QUALITY_CHECK,
  GIS_TOOL_MODE_UNION,
  GIS_TOOL_MODE_IDENTITY,
  GIS_TOOL_MODE_UPDATE
} from './ToolRunnerSheet';

const QGIS_DIALOG_ACTION_REFRESH: number = 1;
const QGIS_DIALOG_ACTION_ATTRIBUTE: number = 2;
const QGIS_DIALOG_ACTION_SYMBOLOGY: number = 3;
const QGIS_DIALOG_ACTION_CLIP: number = 4;
const QGIS_DIALOG_ACTION_BUFFER: number = 5;
const QGIS_DIALOG_ACTION_REPAIR: number = 6;
const QGIS_DIALOG_ACTION_EXPORT: number = 7;
const QGIS_DIALOG_ACTION_NEW_PROJECT: number = 8;
const QGIS_DIALOG_ACTION_OPEN_PROJECT: number = 9;
const QGIS_DIALOG_ACTION_SAVE_PROJECT: number = 10;
const QGIS_DIALOG_ACTION_PROJECT_INFO: number = 11;
const QGIS_DIALOG_ACTION_ADD_DATA: number = 12;
const QGIS_DIALOG_ACTION_ZOOM_IN: number = 13;
const QGIS_DIALOG_ACTION_ZOOM_OUT: number = 14;
const QGIS_DIALOG_ACTION_FULL_EXTENT: number = 15;
const QGIS_DIALOG_ACTION_LAYER_TOGGLE: number = 16;
const QGIS_DIALOG_ACTION_LAYER_UP: number = 17;
const QGIS_DIALOG_ACTION_LAYER_DOWN: number = 18;
const QGIS_DIALOG_ACTION_LAYER_DELETE: number = 19;
const QGIS_DIALOG_ACTION_VECTOR_EDIT: number = 20;
const QGIS_DIALOG_ACTION_ATTRIBUTE_EDIT: number = 21;
const QGIS_DIALOG_ACTION_LABELING: number = 22;
const QGIS_DIALOG_ACTION_RASTER_DISPLAY: number = 23;
const QGIS_DIALOG_ACTION_LAYOUT: number = 24;
const QGIS_DIALOG_ACTION_DEFINE_PROJECTION: number = 25;
const QGIS_DIALOG_ACTION_PROJECT_LAYER: number = 26;
const QGIS_DIALOG_ACTION_SIMPLIFY: number = 27;
const QGIS_DIALOG_ACTION_DISSOLVE: number = 28;
const QGIS_DIALOG_ACTION_CENTROID: number = 29;
const QGIS_DIALOG_ACTION_CONVEX_HULL: number = 30;
const QGIS_DIALOG_ACTION_BOUNDING_BOXES: number = 31;
const QGIS_DIALOG_ACTION_ORIENTED_MINIMUM_BOUNDING_BOX: number = 32;
const QGIS_DIALOG_ACTION_MULTIPART_TO_SINGLEPARTS: number = 33;
const QGIS_DIALOG_ACTION_EXTRACT_BY_EXPRESSION: number = 34;
const QGIS_DIALOG_ACTION_DIFFERENCE: number = 35;
const QGIS_DIALOG_ACTION_SYMMETRICAL_DIFFERENCE: number = 36;
const QGIS_DIALOG_ACTION_MERGE_LAYERS: number = 37;
const QGIS_DIALOG_ACTION_MULTI_RING_BUFFER: number = 38;
const QGIS_DIALOG_ACTION_EXTRACT_BY_LOCATION: number = 39;
const QGIS_DIALOG_ACTION_SPATIAL_JOIN_SUMMARY: number = 40;
const QGIS_DIALOG_ACTION_INTERSECTION: number = 41;
const QGIS_DIALOG_ACTION_NEAREST_NEIGHBOR: number = 42;
const QGIS_DIALOG_ACTION_VORONOI: number = 43;
const QGIS_DIALOG_ACTION_PROCESSING_BROWSER: number = 44;
const QGIS_DIALOG_ACTION_KERNEL_DENSITY: number = 45;
const QGIS_DIALOG_ACTION_POINT_DENSITY: number = 46;
const QGIS_DIALOG_ACTION_LINE_DENSITY: number = 47;
const QGIS_DIALOG_ACTION_IDW: number = 48;
const QGIS_DIALOG_ACTION_RASTER_SLOPE: number = 49;
const QGIS_DIALOG_ACTION_RASTER_ASPECT: number = 50;
const QGIS_DIALOG_ACTION_RASTER_RECLASSIFY: number = 51;
const QGIS_DIALOG_ACTION_QUALITY_CHECK: number = 52;
const QGIS_DIALOG_ACTION_UNION: number = 53;
const QGIS_DIALOG_ACTION_IDENTITY: number = 54;
const QGIS_DIALOG_ACTION_UPDATE: number = 55;

class DesktopGisCapability {
  key: string = '';
  title: ResourceStr = '';
  description: ResourceStr = '';
  statusLabel: ResourceStr = '';
  buttonLabel: ResourceStr = '';
  actionId: number = 0;
  enabled: boolean = false;
  statusKind: number = 0;

  constructor(key: string, title: ResourceStr, description: ResourceStr, statusLabel: ResourceStr,
    buttonLabel: ResourceStr, actionId: number, enabled: boolean, statusKind: number) {
    this.key = key;
    this.title = title;
    this.description = description;
    this.statusLabel = statusLabel;
    this.buttonLabel = buttonLabel;
    this.actionId = actionId;
    this.enabled = enabled;
    this.statusKind = statusKind;
  }
}

@Component
export struct QgisCoreSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  onLayerMetadataRefreshed: () => void = () => {};
  onCreateProject: () => void = () => {};
  onOpenProject: () => void = () => {};
  onSaveProject: () => void = () => {};
  onOpenProjectInfo: () => void = () => {};
  onAddData: () => void = () => {};
  onZoomIn: () => void = () => {};
  onZoomOut: () => void = () => {};
  onFullExtent: () => void = () => {};
  onToggleLayer: () => void = () => {};
  onLayerUp: () => void = () => {};
  onLayerDown: () => void = () => {};
  onLayerDelete: () => void = () => {};
  onOpenAttributeTable: () => void = () => {};
  onOpenSymbology: () => void = () => {};
  onOpenVectorEdit: () => void = () => {};
  onOpenAttributeEdit: () => void = () => {};
  onOpenLabeling: () => void = () => {};
  onOpenRasterDisplay: () => void = () => {};
  onOpenLayout: () => void = () => {};
  onOpenClip: () => void = () => {};
  onOpenBuffer: () => void = () => {};
  onOpenRepair: () => void = () => {};
  onOpenExport: () => void = () => {};
  onOpenDefineProjection: () => void = () => {};
  onOpenProjectLayer: () => void = () => {};
  onOpenSimplify: () => void = () => {};
  onOpenDissolve: () => void = () => {};
  onOpenCentroid: () => void = () => {};
  onOpenProcessingTool: (toolMode: number) => void = (_toolMode: number) => {};
  onOpenProcessingBrowser: () => void = () => {};
  @State private bridgeAvailable: boolean = false;
  @State private bridgeVersion: string = '';
  @State private bridgeProfile: string = '';
  @State private runStatus: string = '';

  onTrigger(): void {
    this.isShow = true;
  }

  aboutToAppear(): void {
    this.refreshBridgeStatus();
    this.runStatus = '等待 QGIS Core 操作';
  }

  private refreshBridgeStatus(): void {
    let status: GisNativeBridgeStatus = queryGisNativeBridgeStatus();
    this.bridgeAvailable = status.available;
    this.bridgeVersion = status.version;
    this.bridgeProfile = status.profile;
  }

  private getActiveLayer(): GisLoadedLayer | undefined {
    return getGisService().getActiveLayer();
  }

  private bridgeStateText(): string {
    if (this.bridgeAvailable) {
      return 'QGIS Core 已连接';
    }
    return 'QGIS Core 不可用';
  }

  private bridgeVersionText(): string {
    if (this.bridgeVersion.length > 0) {
      return this.bridgeVersion;
    }
    return '-';
  }

  private bridgeProfileText(): string {
    if (this.bridgeProfile.length > 0) {
      return this.bridgeProfile;
    }
    return '-';
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

  private activeLayerName(): string {
    let layer = this.getActiveLayer();
    if (layer !== undefined) {
      return layer.info.name;
    }
    return '当前没有活动图层';
  }

  private layerCrsName(layer: GisLoadedLayer): string {
    if (layer.info.crsFriendlyName.length > 0) {
      return layer.info.crsFriendlyName;
    }
    if (layer.info.crsDescription.length > 0) {
      return layer.info.crsDescription;
    }
    if (layer.info.crs.length > 0) {
      return layer.info.crs;
    }
    return 'CRS 未声明';
  }

  private layerReferenceText(layer: GisLoadedLayer): string {
    if (layer.info.crs.length === 0 && layer.info.crsDescription.length === 0 &&
      layer.info.crsFriendlyName.length === 0) {
      return 'CRS 未声明';
    }
    let unitText = layer.info.coordinateUnitName.length > 0 ? layer.info.coordinateUnitName : '单位未声明';
    let crsName = this.layerCrsName(layer);
    if (layer.info.crsIsGeographic) {
      let ellipsoidText = layer.info.ellipsoidAcronym.length > 0 ? ' · 椭球 ' + layer.info.ellipsoidAcronym : '';
      return '地理坐标系 ' + crsName + ellipsoidText + ' · 单位 ' + unitText;
    }
    let geographicText = layer.info.geographicCrsAuthId.length > 0 ? layer.info.geographicCrsAuthId : '地理坐标系未声明';
    let projectionText = layer.info.projectionAcronym.length > 0 ? layer.info.projectionAcronym : '投影方法未声明';
    return '投影坐标系 ' + crsName + ' · 地理坐标系 ' + geographicText + ' · ' + projectionText +
      ' · 单位 ' + unitText;
  }

  private activeLayerMeta(): string {
    let layer = this.getActiveLayer();
    if (layer === undefined) {
      return '先添加 Shapefile 或打开已有工程';
    }
    let crsText = this.layerReferenceText(layer);
    return this.geometryTypeName(layer.info.geometryType) + '图层 · ' + layer.info.featureCount.toString() +
      ' 要素 · ' + layer.info.fields.length.toString() + ' 字段 · ' + crsText;
  }

  private activeLayerExtent(): string {
    let layer = this.getActiveLayer();
    if (layer === undefined) {
      return '-';
    }
    return layer.info.envelope.minX.toFixed(6) + ', ' + layer.info.envelope.minY.toFixed(6) + ' - ' +
      layer.info.envelope.maxX.toFixed(6) + ', ' + layer.info.envelope.maxY.toFixed(6);
  }

  private buildDesktopCapabilityList(): DesktopGisCapability[] {
    let result: DesktopGisCapability[] = [];
    let hasLayer = this.getActiveLayer() !== undefined;
    let hasTwoLayers = getGisService().getLayerCount() > 1;

    result.push(new DesktopGisCapability('project-management', $r('app.string.gn_cap_project_management_title'),
      $r('app.string.gn_cap_project_management_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_cap_action_manage'), QGIS_DIALOG_ACTION_PROJECT_INFO, true, 1));
    result.push(new DesktopGisCapability('map-browse', $r('app.string.gn_cap_map_browse_title'),
      $r('app.string.gn_cap_map_browse_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_workbench_full_extent'), QGIS_DIALOG_ACTION_FULL_EXTENT, hasLayer, 1));
    result.push(new DesktopGisCapability('layer-management', $r('app.string.gn_cap_layer_management_title'),
      $r('app.string.gn_cap_layer_management_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_cap_action_toggle'), QGIS_DIALOG_ACTION_LAYER_TOGGLE, hasLayer, 1));
    result.push(new DesktopGisCapability('data-loading', $r('app.string.gn_cap_data_loading_title'),
      $r('app.string.gn_cap_data_loading_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_cap_action_add'), QGIS_DIALOG_ACTION_ADD_DATA, true, 1));
    result.push(new DesktopGisCapability('crs-management', $r('app.string.gn_cap_crs_management_title'),
      $r('app.string.gn_cap_crs_management_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_cmd_define_projection'), QGIS_DIALOG_ACTION_DEFINE_PROJECTION, hasLayer, 1));
    result.push(new DesktopGisCapability('attribute-table', $r('app.string.gn_cap_attribute_table_title'),
      $r('app.string.gn_cap_attribute_table_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_workbench_attribute_table'), QGIS_DIALOG_ACTION_ATTRIBUTE, hasLayer, 1));
    result.push(new DesktopGisCapability('feature-query', $r('app.string.gn_cap_feature_query_title'),
      $r('app.string.gn_cap_feature_query_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_cap_action_map_click'), 0, false, 1));
    result.push(new DesktopGisCapability('measurement', $r('app.string.gn_cap_measurement_title'),
      $r('app.string.gn_cap_measurement_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_cap_action_map_click'), 0, false, 1));
    result.push(new DesktopGisCapability('vector-editing', $r('app.string.gn_cap_vector_editing_title'),
      $r('app.string.gn_cap_vector_editing_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_cap_action_manage'), QGIS_DIALOG_ACTION_VECTOR_EDIT, hasLayer, 1));
    result.push(new DesktopGisCapability('attribute-editing', $r('app.string.gn_cap_attribute_editing_title'),
      $r('app.string.gn_cap_attribute_editing_desc'), $r('app.string.gn_cap_status_partial'),
      $r('app.string.gn_cap_action_manage'), QGIS_DIALOG_ACTION_ATTRIBUTE_EDIT, hasLayer, 2));
    result.push(new DesktopGisCapability('symbology', $r('app.string.gn_cap_symbology_title'),
      $r('app.string.gn_cap_symbology_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_symbology'), QGIS_DIALOG_ACTION_SYMBOLOGY, hasLayer, 1));
    result.push(new DesktopGisCapability('labeling', $r('app.string.gn_cap_labeling_title'),
      $r('app.string.gn_cap_labeling_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_cap_action_manage'), QGIS_DIALOG_ACTION_LABELING, hasLayer, 1));
    result.push(new DesktopGisCapability('raster-display', $r('app.string.gn_cap_raster_display_title'),
      $r('app.string.gn_cap_raster_display_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_cap_action_manage'), QGIS_DIALOG_ACTION_RASTER_DISPLAY, true, 1));
    result.push(new DesktopGisCapability('map-layout', $r('app.string.gn_cap_map_layout_title'),
      $r('app.string.gn_cap_map_layout_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_cap_action_manage'), QGIS_DIALOG_ACTION_LAYOUT, true, 1));
    result.push(new DesktopGisCapability('spatial-analysis', $r('app.string.gn_cap_spatial_analysis_title'),
      $r('app.string.gn_cap_spatial_analysis_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_cmd_clip'), QGIS_DIALOG_ACTION_CLIP, hasTwoLayers, 1));
    result.push(new DesktopGisCapability('geometry-processing', $r('app.string.gn_cap_geometry_processing_title'),
      $r('app.string.gn_cap_geometry_processing_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_cmd_simplify'), QGIS_DIALOG_ACTION_SIMPLIFY, hasLayer, 1));
    result.push(new DesktopGisCapability('raster-analysis', $r('app.string.gn_cap_raster_analysis_title'),
      $r('app.string.gn_cap_raster_analysis_desc'), $r('app.string.gn_cap_status_ready'),
      '核密度', QGIS_DIALOG_ACTION_KERNEL_DENSITY, hasLayer, 1));
    result.push(new DesktopGisCapability('terrain-analysis', $r('app.string.gn_cap_terrain_analysis_title'),
      $r('app.string.gn_cap_terrain_analysis_desc'), $r('app.string.gn_cap_status_pending'),
      $r('app.string.gn_cap_action_pending'), 0, false, 3));
    result.push(new DesktopGisCapability('network-analysis', $r('app.string.gn_cap_network_analysis_title'),
      $r('app.string.gn_cap_network_analysis_desc'), $r('app.string.gn_cap_status_pending'),
      $r('app.string.gn_cap_action_pending'), 0, false, 3));
    result.push(new DesktopGisCapability('statistics', $r('app.string.gn_cap_statistics_title'),
      $r('app.string.gn_cap_statistics_desc'), $r('app.string.gn_cap_status_partial'),
      $r('app.string.gn_workbench_attribute_table'), QGIS_DIALOG_ACTION_ATTRIBUTE, hasLayer, 2));
    result.push(new DesktopGisCapability('database', $r('app.string.gn_cap_database_title'),
      $r('app.string.gn_cap_database_desc'), $r('app.string.gn_cap_status_partial'),
      $r('app.string.gn_cmd_export'), QGIS_DIALOG_ACTION_EXPORT, hasLayer, 2));
    result.push(new DesktopGisCapability('online-services', $r('app.string.gn_cap_online_services_title'),
      $r('app.string.gn_cap_online_services_desc'), $r('app.string.gn_cap_status_pending'),
      $r('app.string.gn_cap_action_pending'), 0, false, 3));
    result.push(new DesktopGisCapability('data-conversion', $r('app.string.gn_cap_data_conversion_title'),
      $r('app.string.gn_cap_data_conversion_desc'), $r('app.string.gn_cap_status_ready'),
      $r('app.string.gn_cmd_project_layer'), QGIS_DIALOG_ACTION_PROJECT_LAYER, hasLayer, 1));
    result.push(new DesktopGisCapability('plugin-system', $r('app.string.gn_cap_plugin_system_title'),
      $r('app.string.gn_cap_plugin_system_desc'), $r('app.string.gn_cap_status_pending'),
      $r('app.string.gn_cap_action_pending'), 0, false, 3));
    result.push(new DesktopGisCapability('task-processing', $r('app.string.gn_cap_task_processing_title'),
      $r('app.string.gn_cap_task_processing_desc'), $r('app.string.gn_cap_status_partial'),
      $r('app.string.gn_processing_open'), QGIS_DIALOG_ACTION_PROCESSING_BROWSER, true, 2));
    result.push(new DesktopGisCapability('settings', $r('app.string.gn_cap_settings_title'),
      $r('app.string.gn_cap_settings_desc'), $r('app.string.gn_cap_status_partial'),
      $r('app.string.gn_project_info'), QGIS_DIALOG_ACTION_PROJECT_INFO, true, 2));
    result.push(new DesktopGisCapability('three-d', $r('app.string.gn_cap_three_d_title'),
      $r('app.string.gn_cap_three_d_desc'), $r('app.string.gn_cap_status_pending'),
      $r('app.string.gn_cap_action_pending'), 0, false, 3));
    result.push(new DesktopGisCapability('point-cloud', $r('app.string.gn_cap_point_cloud_title'),
      $r('app.string.gn_cap_point_cloud_desc'), $r('app.string.gn_cap_status_pending'),
      $r('app.string.gn_cap_action_pending'), 0, false, 3));
    result.push(new DesktopGisCapability('remote-sensing', $r('app.string.gn_cap_remote_sensing_title'),
      $r('app.string.gn_cap_remote_sensing_desc'), $r('app.string.gn_cap_status_pending'),
      $r('app.string.gn_cap_action_pending'), 0, false, 3));
    result.push(new DesktopGisCapability('cad-interop', $r('app.string.gn_cap_cad_interop_title'),
      $r('app.string.gn_cap_cad_interop_desc'), $r('app.string.gn_cap_status_pending'),
      $r('app.string.gn_cap_action_pending'), 0, false, 3));
    result.push(new DesktopGisCapability('temporal', $r('app.string.gn_cap_temporal_title'),
      $r('app.string.gn_cap_temporal_desc'), $r('app.string.gn_cap_status_pending'),
      $r('app.string.gn_cap_action_pending'), 0, false, 3));
    result.push(new DesktopGisCapability('automation', $r('app.string.gn_cap_automation_title'),
      $r('app.string.gn_cap_automation_desc'), $r('app.string.gn_cap_status_pending'),
      $r('app.string.gn_cap_action_pending'), 0, false, 3));

    return result;
  }

  private refreshActiveLayerMetadata(): void {
    this.refreshBridgeStatus();
    let service = getGisService();
    let layerIndex = service.getActiveLayerIndex();
    if (layerIndex < 0) {
      this.runStatus = '没有活动图层可刷新';
      return;
    }
    let result: GisOperationResult = service.refreshLayerInfo(layerIndex);
    if (result.ok) {
      this.runStatus = '完成：已调用 getLayerInfo 刷新活动图层';
      this.onLayerMetadataRefreshed();
    } else {
      this.runStatus = '失败：' + result.message;
    }
  }

  private runLinkedAction(actionId: number): void {
    if (actionId === QGIS_DIALOG_ACTION_REFRESH) {
      this.refreshActiveLayerMetadata();
      return;
    }
    this.isShow = false;
    if (actionId === QGIS_DIALOG_ACTION_NEW_PROJECT) {
      this.onCreateProject();
    } else if (actionId === QGIS_DIALOG_ACTION_OPEN_PROJECT) {
      this.onOpenProject();
    } else if (actionId === QGIS_DIALOG_ACTION_SAVE_PROJECT) {
      this.onSaveProject();
    } else if (actionId === QGIS_DIALOG_ACTION_PROJECT_INFO) {
      this.onOpenProjectInfo();
    } else if (actionId === QGIS_DIALOG_ACTION_ADD_DATA) {
      this.onAddData();
    } else if (actionId === QGIS_DIALOG_ACTION_ZOOM_IN) {
      this.onZoomIn();
    } else if (actionId === QGIS_DIALOG_ACTION_ZOOM_OUT) {
      this.onZoomOut();
    } else if (actionId === QGIS_DIALOG_ACTION_FULL_EXTENT) {
      this.onFullExtent();
    } else if (actionId === QGIS_DIALOG_ACTION_LAYER_TOGGLE) {
      this.onToggleLayer();
    } else if (actionId === QGIS_DIALOG_ACTION_LAYER_UP) {
      this.onLayerUp();
    } else if (actionId === QGIS_DIALOG_ACTION_LAYER_DOWN) {
      this.onLayerDown();
    } else if (actionId === QGIS_DIALOG_ACTION_LAYER_DELETE) {
      this.onLayerDelete();
    } else if (actionId === QGIS_DIALOG_ACTION_ATTRIBUTE) {
      this.onOpenAttributeTable();
    } else if (actionId === QGIS_DIALOG_ACTION_SYMBOLOGY) {
      this.onOpenSymbology();
    } else if (actionId === QGIS_DIALOG_ACTION_VECTOR_EDIT) {
      this.onOpenVectorEdit();
    } else if (actionId === QGIS_DIALOG_ACTION_ATTRIBUTE_EDIT) {
      this.onOpenAttributeEdit();
    } else if (actionId === QGIS_DIALOG_ACTION_LABELING) {
      this.onOpenLabeling();
    } else if (actionId === QGIS_DIALOG_ACTION_RASTER_DISPLAY) {
      this.onOpenRasterDisplay();
    } else if (actionId === QGIS_DIALOG_ACTION_LAYOUT) {
      this.onOpenLayout();
    } else if (actionId === QGIS_DIALOG_ACTION_CLIP) {
      this.onOpenClip();
    } else if (actionId === QGIS_DIALOG_ACTION_BUFFER) {
      this.onOpenBuffer();
    } else if (actionId === QGIS_DIALOG_ACTION_REPAIR) {
      this.onOpenRepair();
    } else if (actionId === QGIS_DIALOG_ACTION_EXPORT) {
      this.onOpenExport();
    } else if (actionId === QGIS_DIALOG_ACTION_DEFINE_PROJECTION) {
      this.onOpenDefineProjection();
    } else if (actionId === QGIS_DIALOG_ACTION_PROJECT_LAYER) {
      this.onOpenProjectLayer();
    } else if (actionId === QGIS_DIALOG_ACTION_SIMPLIFY) {
      this.onOpenSimplify();
    } else if (actionId === QGIS_DIALOG_ACTION_DISSOLVE) {
      this.onOpenDissolve();
    } else if (actionId === QGIS_DIALOG_ACTION_CENTROID) {
      this.onOpenCentroid();
    } else if (actionId === QGIS_DIALOG_ACTION_CONVEX_HULL) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_CONVEX_HULL);
    } else if (actionId === QGIS_DIALOG_ACTION_BOUNDING_BOXES) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_BOUNDING_BOXES);
    } else if (actionId === QGIS_DIALOG_ACTION_ORIENTED_MINIMUM_BOUNDING_BOX) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_ORIENTED_MINIMUM_BOUNDING_BOX);
    } else if (actionId === QGIS_DIALOG_ACTION_MULTIPART_TO_SINGLEPARTS) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_MULTIPART_TO_SINGLEPARTS);
    } else if (actionId === QGIS_DIALOG_ACTION_EXTRACT_BY_EXPRESSION) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_EXTRACT_BY_EXPRESSION);
    } else if (actionId === QGIS_DIALOG_ACTION_DIFFERENCE) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_DIFFERENCE);
    } else if (actionId === QGIS_DIALOG_ACTION_SYMMETRICAL_DIFFERENCE) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_SYMMETRICAL_DIFFERENCE);
    } else if (actionId === QGIS_DIALOG_ACTION_UNION) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_UNION);
    } else if (actionId === QGIS_DIALOG_ACTION_IDENTITY) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_IDENTITY);
    } else if (actionId === QGIS_DIALOG_ACTION_UPDATE) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_UPDATE);
    } else if (actionId === QGIS_DIALOG_ACTION_MERGE_LAYERS) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_MERGE_LAYERS);
    } else if (actionId === QGIS_DIALOG_ACTION_MULTI_RING_BUFFER) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_MULTI_RING_BUFFER);
    } else if (actionId === QGIS_DIALOG_ACTION_EXTRACT_BY_LOCATION) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_EXTRACT_BY_LOCATION);
    } else if (actionId === QGIS_DIALOG_ACTION_SPATIAL_JOIN_SUMMARY) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_SPATIAL_JOIN_SUMMARY);
    } else if (actionId === QGIS_DIALOG_ACTION_INTERSECTION) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_INTERSECTION);
    } else if (actionId === QGIS_DIALOG_ACTION_NEAREST_NEIGHBOR) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_NEAREST_NEIGHBOR);
    } else if (actionId === QGIS_DIALOG_ACTION_VORONOI) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_VORONOI);
    } else if (actionId === QGIS_DIALOG_ACTION_KERNEL_DENSITY) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_KERNEL_DENSITY);
    } else if (actionId === QGIS_DIALOG_ACTION_POINT_DENSITY) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_POINT_DENSITY);
    } else if (actionId === QGIS_DIALOG_ACTION_LINE_DENSITY) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_LINE_DENSITY);
    } else if (actionId === QGIS_DIALOG_ACTION_IDW) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_IDW);
    } else if (actionId === QGIS_DIALOG_ACTION_RASTER_SLOPE) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_RASTER_SLOPE);
    } else if (actionId === QGIS_DIALOG_ACTION_RASTER_ASPECT) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_RASTER_ASPECT);
    } else if (actionId === QGIS_DIALOG_ACTION_RASTER_RECLASSIFY) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_RASTER_RECLASSIFY);
    } else if (actionId === QGIS_DIALOG_ACTION_QUALITY_CHECK) {
      this.onOpenProcessingTool(GIS_TOOL_MODE_QUALITY_CHECK);
    } else if (actionId === QGIS_DIALOG_ACTION_PROCESSING_BROWSER) {
      this.onOpenProcessingBrowser();
    }
  }

  @Builder
  metaRow(label: ResourceStr, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .width(112)
      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(30)
  }

  @Builder
  statusPanel() {
    Column({ space: 8 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.wrench_arrow_counterclockwise'))
          .fontSize(30)
          .fontColor([this.bridgeAvailable ? $r('app.color.gn_green_700') : $r('app.color.gn_orange_700')])
          .margin({ right: 12 })
        Column() {
          Text(this.bridgeStateText())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.gn_text_primary'))
          Text($r('app.string.gn_qgis_core_desc'))
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
            .margin({ top: 4 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      this.metaRow($r('app.string.gn_qgis_core_version'), this.bridgeVersionText())
      this.metaRow($r('app.string.gn_qgis_core_profile'), this.bridgeProfileText())
    }
    .padding(14)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  activeLayerPanel() {
    Column({ space: 8 }) {
      Text($r('app.string.gn_qgis_core_active_layer'))
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
      Text(this.activeLayerName())
        .width('100%')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.gn_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.activeLayerMeta())
        .width('100%')
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      this.metaRow($r('app.string.gn_qgis_core_extent'), this.activeLayerExtent())
      Text('状态：' + this.runStatus)
        .width('100%')
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding(14)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  capabilityRow(title: ResourceStr, desc: ResourceStr, icon: Resource, buttonLabel: ResourceStr, actionId: number) {
    Row({ space: 10 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([$r('app.color.gn_blue_800')])
      Column() {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
        Text(desc)
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 3 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Button(buttonLabel, { type: ButtonType.Capsule, stateEffect: true })
        .height(30)
        .fontSize(12)
        .fontColor($r('app.color.gn_blue_800'))
        .backgroundColor($r('app.color.gn_blue_100'))
        .onClick(() => {
          this.runLinkedAction(actionId);
        })
    }
    .height(54)
    .padding({ left: 12, right: 12 })
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  capabilityPanel() {
    Column() {
      Text($r('app.string.gn_qgis_core_supported_tools'))
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
        .padding({ left: 12, top: 12, bottom: 6 })
      this.capabilityRow($r('app.string.gn_qgis_core_refresh_metadata'),
        $r('app.string.gn_qgis_core_refresh_desc'), $r('sys.symbol.arrow_clockwise'),
        $r('app.string.gn_qgis_core_refresh_metadata'), QGIS_DIALOG_ACTION_REFRESH)
      this.capabilityRow($r('app.string.gn_processing_browser_title'), $r('app.string.gn_processing_browser_desc'),
        $r('sys.symbol.list_bullet_square'), $r('app.string.gn_processing_open'),
        QGIS_DIALOG_ACTION_PROCESSING_BROWSER)
      this.capabilityRow('核密度', '按 ArcToolbox Kernel Density 生成点密度栅格',
        $r('sys.symbol.location_up'), '核密度', QGIS_DIALOG_ACTION_KERNEL_DENSITY)
      this.capabilityRow('点密度', '按 ArcToolbox Point Density 统计圆形邻域密度',
        $r('sys.symbol.location_up'), '点密度', QGIS_DIALOG_ACTION_POINT_DENSITY)
      this.capabilityRow('线密度', '按 ArcToolbox Line Density 统计邻域线段长度',
        $r('sys.symbol.location_up'), '线密度', QGIS_DIALOG_ACTION_LINE_DENSITY)
      this.capabilityRow('IDW 插值', '按 ArcToolbox IDW 从点数值字段生成插值栅格',
        $r('sys.symbol.location_up'), 'IDW', QGIS_DIALOG_ACTION_IDW)
      this.capabilityRow('坡度', '从 DEM 第一波段生成坡度栅格',
        $r('sys.symbol.map'), '坡度', QGIS_DIALOG_ACTION_RASTER_SLOPE)
      this.capabilityRow('坡向', '从 DEM 第一波段生成坡向栅格',
        $r('sys.symbol.location_up'), '坡向', QGIS_DIALOG_ACTION_RASTER_ASPECT)
      this.capabilityRow('栅格重分类', '按 min:max=value 规则重分类栅格值',
        $r('sys.symbol.square_stack_3d'), '重分类', QGIS_DIALOG_ACTION_RASTER_RECLASSIFY)
      this.capabilityRow($r('app.string.gn_workbench_attribute_table'),
        $r('app.string.gn_qgis_core_attribute_desc'), $r('sys.symbol.doc_text'),
        $r('app.string.gn_workbench_attribute_table'), QGIS_DIALOG_ACTION_ATTRIBUTE)
      this.capabilityRow($r('app.string.gn_symbology'), $r('app.string.gn_qgis_core_symbology_desc'),
        $r('sys.symbol.paintpalette'), $r('app.string.gn_symbology'), QGIS_DIALOG_ACTION_SYMBOLOGY)
      this.capabilityRow($r('app.string.gn_cmd_clip'), $r('app.string.gn_qgis_core_clip_desc'),
        $r('sys.symbol.square_dashed_and_arrow_turn_up_right'), $r('app.string.gn_cmd_clip'),
        QGIS_DIALOG_ACTION_CLIP)
      this.capabilityRow($r('app.string.gn_cmd_buffer'), $r('app.string.gn_qgis_core_buffer_desc'),
        $r('sys.symbol.circle_grid_2x2'), $r('app.string.gn_cmd_buffer'), QGIS_DIALOG_ACTION_BUFFER)
      this.capabilityRow($r('app.string.gn_cmd_repair'), $r('app.string.gn_qgis_core_repair_desc'),
        $r('sys.symbol.wrench_arrow_counterclockwise'), $r('app.string.gn_cmd_repair'), QGIS_DIALOG_ACTION_REPAIR)
      this.capabilityRow($r('app.string.gn_cmd_quality_check'), $r('app.string.gn_tool_quality_check_desc'),
        $r('sys.symbol.list_checkmark'), $r('app.string.gn_cmd_quality_check'), QGIS_DIALOG_ACTION_QUALITY_CHECK)
      this.capabilityRow($r('app.string.gn_cmd_export'), $r('app.string.gn_qgis_core_export_desc'),
        $r('sys.symbol.download'), $r('app.string.gn_cmd_export'), QGIS_DIALOG_ACTION_EXPORT)
      this.capabilityRow($r('app.string.gn_cmd_define_projection'),
        $r('app.string.gn_qgis_core_define_projection_desc'), $r('sys.symbol.map'),
        $r('app.string.gn_cmd_define_projection'), QGIS_DIALOG_ACTION_DEFINE_PROJECTION)
      this.capabilityRow($r('app.string.gn_cmd_project_layer'),
        $r('app.string.gn_qgis_core_project_layer_desc'), $r('sys.symbol.arrow_right_and_square'),
        $r('app.string.gn_cmd_project_layer'), QGIS_DIALOG_ACTION_PROJECT_LAYER)
      this.capabilityRow($r('app.string.gn_cmd_simplify'), $r('app.string.gn_workbench_simplify_desc'),
        $r('sys.symbol.arrow_down_right_and_arrow_up_left'), $r('app.string.gn_cmd_simplify'),
        QGIS_DIALOG_ACTION_SIMPLIFY)
      this.capabilityRow($r('app.string.gn_cmd_dissolve'), $r('app.string.gn_workbench_dissolve_desc'),
        $r('sys.symbol.square_and_square'), $r('app.string.gn_cmd_dissolve'), QGIS_DIALOG_ACTION_DISSOLVE)
      this.capabilityRow($r('app.string.gn_cmd_centroid'), $r('app.string.gn_workbench_centroid_desc'),
        $r('sys.symbol.location_up'), $r('app.string.gn_cmd_centroid'), QGIS_DIALOG_ACTION_CENTROID)
      this.capabilityRow($r('app.string.gn_cmd_convex_hull'), $r('app.string.gn_workbench_convex_hull_desc'),
        $r('sys.symbol.layer'), $r('app.string.gn_cmd_convex_hull'), QGIS_DIALOG_ACTION_CONVEX_HULL)
      this.capabilityRow($r('app.string.gn_cmd_bounding_boxes'),
        $r('app.string.gn_workbench_bounding_boxes_desc'), $r('sys.symbol.layer'),
        $r('app.string.gn_cmd_bounding_boxes'), QGIS_DIALOG_ACTION_BOUNDING_BOXES)
      this.capabilityRow($r('app.string.gn_cmd_oriented_minimum_bounding_box'),
        $r('app.string.gn_workbench_oriented_minimum_bounding_box_desc'), $r('sys.symbol.layer'),
        $r('app.string.gn_cmd_oriented_minimum_bounding_box'), QGIS_DIALOG_ACTION_ORIENTED_MINIMUM_BOUNDING_BOX)
      this.capabilityRow($r('app.string.gn_cmd_multipart_to_singleparts'),
        $r('app.string.gn_workbench_multipart_to_singleparts_desc'), $r('sys.symbol.square_stack_3d'),
        $r('app.string.gn_cmd_multipart_to_singleparts'), QGIS_DIALOG_ACTION_MULTIPART_TO_SINGLEPARTS)
      this.capabilityRow($r('app.string.gn_cmd_extract_by_expression'),
        $r('app.string.gn_workbench_extract_by_expression_desc'), $r('sys.symbol.funnel'),
        $r('app.string.gn_cmd_extract_by_expression'), QGIS_DIALOG_ACTION_EXTRACT_BY_EXPRESSION)
      this.capabilityRow($r('app.string.gn_cmd_difference'), $r('app.string.gn_workbench_difference_desc'),
        $r('sys.symbol.square_and_cut'), $r('app.string.gn_cmd_difference'), QGIS_DIALOG_ACTION_DIFFERENCE)
      this.capabilityRow($r('app.string.gn_cmd_symmetrical_difference'),
        $r('app.string.gn_workbench_symmetrical_difference_desc'), $r('sys.symbol.square_and_square'),
        $r('app.string.gn_cmd_symmetrical_difference'), QGIS_DIALOG_ACTION_SYMMETRICAL_DIFFERENCE)
      this.capabilityRow($r('app.string.gn_cmd_union'), $r('app.string.gn_workbench_union_desc'),
        $r('sys.symbol.square_and_square'), $r('app.string.gn_cmd_union'), QGIS_DIALOG_ACTION_UNION)
      this.capabilityRow($r('app.string.gn_cmd_identity'), $r('app.string.gn_workbench_identity_desc'),
        $r('sys.symbol.square_and_square'), $r('app.string.gn_cmd_identity'), QGIS_DIALOG_ACTION_IDENTITY)
      this.capabilityRow($r('app.string.gn_cmd_update_overlay'), $r('app.string.gn_workbench_update_overlay_desc'),
        $r('sys.symbol.square_and_square'), $r('app.string.gn_cmd_update_overlay'), QGIS_DIALOG_ACTION_UPDATE)
      this.capabilityRow($r('app.string.gn_cmd_merge_layers'), $r('app.string.gn_workbench_merge_layers_desc'),
        $r('sys.symbol.plus_square_on_square'), $r('app.string.gn_cmd_merge_layers'), QGIS_DIALOG_ACTION_MERGE_LAYERS)
      this.capabilityRow($r('app.string.gn_cmd_multi_ring_buffer'),
        $r('app.string.gn_workbench_multi_ring_buffer_desc'), $r('sys.symbol.circle_grid_2x2'),
        $r('app.string.gn_cmd_multi_ring_buffer'), QGIS_DIALOG_ACTION_MULTI_RING_BUFFER)
      this.capabilityRow($r('app.string.gn_cmd_extract_by_location'),
        $r('app.string.gn_workbench_extract_by_location_desc'), $r('sys.symbol.location_up'),
        $r('app.string.gn_cmd_extract_by_location'), QGIS_DIALOG_ACTION_EXTRACT_BY_LOCATION)
      this.capabilityRow($r('app.string.gn_cmd_spatial_join_summary'),
        $r('app.string.gn_workbench_spatial_join_summary_desc'), $r('sys.symbol.plus_square_on_square'),
        $r('app.string.gn_cmd_spatial_join_summary'), QGIS_DIALOG_ACTION_SPATIAL_JOIN_SUMMARY)
      this.capabilityRow($r('app.string.gn_cmd_intersection'), $r('app.string.gn_workbench_intersection_desc'),
        $r('sys.symbol.square_and_square'), $r('app.string.gn_cmd_intersection'), QGIS_DIALOG_ACTION_INTERSECTION)
      this.capabilityRow($r('app.string.gn_cmd_nearest_neighbor'),
        $r('app.string.gn_workbench_nearest_neighbor_desc'), $r('sys.symbol.location_up'),
        $r('app.string.gn_cmd_nearest_neighbor'), QGIS_DIALOG_ACTION_NEAREST_NEIGHBOR)
      this.capabilityRow($r('app.string.gn_cmd_voronoi'), $r('app.string.gn_workbench_voronoi_desc'),
        $r('sys.symbol.circle_grid_2x2'), $r('app.string.gn_cmd_voronoi'), QGIS_DIALOG_ACTION_VORONOI)
    }
    .borderRadius(6)
    .clip(true)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  private capabilityStatusColor(kind: number): ResourceColor {
    if (kind === 1) {
      return $r('app.color.gn_green_700');
    }
    if (kind === 2) {
      return $r('app.color.gn_orange_700');
    }
    return $r('app.color.gn_text_muted');
  }

  private capabilityStatusBg(kind: number): ResourceColor {
    if (kind === 1) {
      return $r('app.color.gn_selected_row');
    }
    if (kind === 2) {
      return $r('app.color.gn_warning_bg');
    }
    return $r('app.color.gn_pane_alt');
  }

  private capabilityCanRun(item: DesktopGisCapability): boolean {
    return item.enabled && item.actionId > 0;
  }

  @Builder
  capabilityStatusBadge(item: DesktopGisCapability) {
    Text(item.statusLabel)
      .height(22)
      .padding({ left: 8, right: 8 })
      .borderRadius(4)
      .fontSize(11)
      .fontColor(this.capabilityStatusColor(item.statusKind))
      .backgroundColor(this.capabilityStatusBg(item.statusKind))
  }

  @Builder
  desktopCapabilityRow(item: DesktopGisCapability) {
    Row({ space: 10 }) {
      Column() {
        Row({ space: 8 }) {
          Text(item.title)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          this.capabilityStatusBadge(item)
        }
        .width('100%')
        Text(item.description)
          .width('100%')
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 5 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Button(item.buttonLabel, { type: ButtonType.Capsule, stateEffect: true })
        .width(86)
        .height(30)
        .fontSize(12)
        .fontColor(this.capabilityCanRun(item) ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
        .backgroundColor(this.capabilityCanRun(item) ? $r('app.color.gn_blue_100') : $r('app.color.gn_pane_alt'))
        .enabled(this.capabilityCanRun(item))
        .onClick(() => {
          this.runLinkedAction(item.actionId);
        })
    }
    .height(68)
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  desktopCapabilityPanel() {
    Column() {
      Row() {
        Text($r('app.string.gn_desktop_gis_capability_title'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .layoutWeight(1)
        Text($r('app.string.gn_desktop_gis_capability_total'))
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
      }
      .height(38)
      .padding({ left: 12, right: 12 })
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
      ForEach(this.buildDesktopCapabilityList(), (item: DesktopGisCapability) => {
        this.desktopCapabilityRow(item)
      }, (item: DesktopGisCapability) => item.key)
    }
    .borderRadius(6)
    .clip(true)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder sheetContent() {
    Column() {
      HdsNavigation() {
        Scroll(this.scroller) {
          Column({ space: 12 }) {
            Blank().height(80).width('100%')
            this.statusPanel()
            this.activeLayerPanel()
            this.desktopCapabilityPanel()
          }
          .padding(14)
          .width('100%')
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
          title: { mainTitle: $r('app.string.gn_qgis_core_title') },
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
