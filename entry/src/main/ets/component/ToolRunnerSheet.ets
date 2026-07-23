import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '@geonest/common';
import { getGisService, GisLoadedLayer, GisService } from '../gis/GisService';
import {
  GIS_PROCESSING_TASK_CANCEL_REQUESTED,
  GIS_PROCESSING_TASK_CANCELED,
  GIS_PROCESSING_TASK_FAILED,
  GIS_PROCESSING_TASK_QUEUED,
  GIS_PROCESSING_TASK_SUCCEEDED,
  GisOperationResult,
  GisCrsInfo,
  GisGeoProcessResult,
  GisProcessingTaskRequest,
  GisProcessingTaskSnapshot
} from '../model/GeoNestModels';
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import { CoordinateSystemPicker } from './CoordinateSystemPicker';
import { GeoNestFormStateStore } from '../utils/GeoNestFormStateStore';
import { PROCESSING_TASK_REVISION_KEY } from '../utils/ProcessingHistoryManager';
import { ProcessingNotificationManager } from '../utils/ProcessingNotificationManager';

export const GIS_TOOL_MODE_CLIP: number = 1;
export const GIS_TOOL_MODE_BUFFER: number = 2;
export const GIS_TOOL_MODE_REPAIR: number = 3;
export const GIS_TOOL_MODE_EXPORT: number = 4;
export const GIS_TOOL_MODE_DEFINE_PROJECTION: number = 5;
export const GIS_TOOL_MODE_PROJECT_LAYER: number = 6;
export const GIS_TOOL_MODE_SIMPLIFY: number = 7;
export const GIS_TOOL_MODE_DISSOLVE: number = 8;
export const GIS_TOOL_MODE_CENTROID: number = 9;
export const GIS_TOOL_MODE_CONVEX_HULL: number = 10;
export const GIS_TOOL_MODE_BOUNDING_BOXES: number = 11;
export const GIS_TOOL_MODE_ORIENTED_MINIMUM_BOUNDING_BOX: number = 12;
export const GIS_TOOL_MODE_MULTIPART_TO_SINGLEPARTS: number = 13;
export const GIS_TOOL_MODE_EXTRACT_BY_EXPRESSION: number = 14;
export const GIS_TOOL_MODE_DIFFERENCE: number = 15;
export const GIS_TOOL_MODE_SYMMETRICAL_DIFFERENCE: number = 16;
export const GIS_TOOL_MODE_MERGE_LAYERS: number = 17;
export const GIS_TOOL_MODE_MULTI_RING_BUFFER: number = 18;
export const GIS_TOOL_MODE_EXTRACT_BY_LOCATION: number = 19;
export const GIS_TOOL_MODE_SPATIAL_JOIN_SUMMARY: number = 20;
export const GIS_TOOL_MODE_INTERSECTION: number = 21;
export const GIS_TOOL_MODE_NEAREST_NEIGHBOR: number = 22;
export const GIS_TOOL_MODE_VORONOI: number = 23;
export const GIS_TOOL_MODE_KERNEL_DENSITY: number = 24;
export const GIS_TOOL_MODE_POINT_DENSITY: number = 25;
export const GIS_TOOL_MODE_LINE_DENSITY: number = 26;
export const GIS_TOOL_MODE_IDW: number = 27;
export const GIS_TOOL_MODE_RASTER_SLOPE: number = 28;
export const GIS_TOOL_MODE_RASTER_ASPECT: number = 29;
export const GIS_TOOL_MODE_RASTER_RECLASSIFY: number = 30;
export const GIS_TOOL_MODE_QUALITY_CHECK: number = 31;
export const GIS_TOOL_MODE_UNION: number = 32;
export const GIS_TOOL_MODE_IDENTITY: number = 33;
export const GIS_TOOL_MODE_UPDATE: number = 34;
export const GIS_TOOL_MODE_FEATURE_TO_POINT: number = 35;
export const GIS_TOOL_MODE_POLYGON_TO_LINE: number = 36;
export const GIS_TOOL_MODE_FEATURE_TO_POLYGON: number = 37;
export const GIS_TOOL_MODE_VERTICES_TO_POINTS: number = 38;
export const GIS_TOOL_MODE_POINTS_TO_LINE: number = 39;
export const GIS_TOOL_MODE_DENSIFY: number = 40;
export const GIS_TOOL_MODE_SMOOTH: number = 41;
export const GIS_TOOL_MODE_REMOVE_HOLES: number = 42;
export const GIS_TOOL_MODE_SELECT: number = 43;
export const GIS_TOOL_MODE_TABLE_SELECT: number = 44;
export const GIS_TOOL_MODE_SPLIT: number = 45;
export const GIS_TOOL_MODE_SPLIT_BY_ATTRIBUTES: number = 46;
export const GIS_TOOL_MODE_EXTRACT_BY_EXTENT: number = 47;
export const GIS_TOOL_MODE_EXTRACT_BY_TIME: number = 48;
export const GIS_TOOL_MODE_EXTRACT_BY_MASK: number = 49;
export const GIS_TOOL_MODE_TABULATE_INTERSECTION: number = 50;
export const GIS_TOOL_MODE_SUMMARIZE_WITHIN: number = 51;
export const GIS_TOOL_MODE_NEAR: number = 52;
export const GIS_TOOL_MODE_GENERATE_NEAR_TABLE: number = 53;
export const GIS_TOOL_MODE_POINT_DISTANCE: number = 54;
export const GIS_TOOL_MODE_DISTANCE_MATRIX: number = 55;
export const GIS_TOOL_MODE_SHORTEST_CONNECTION: number = 56;
export const GIS_TOOL_MODE_SUMMARY_STATISTICS: number = 57;
export const GIS_TOOL_MODE_FREQUENCY: number = 58;
export const GIS_TOOL_MODE_UNIQUE_VALUES: number = 59;
export const GIS_TOOL_MODE_GROUP_STATISTICS: number = 60;
export const GIS_TOOL_MODE_CROSSTAB_PIVOT: number = 61;
export const GIS_TOOL_MODE_STATISTICS_CHART: number = 62;
export const GIS_TOOL_MODE_POLYGON_NEIGHBORS: number = 63;
export const GIS_TOOL_MODE_SNAP_OUTPUT: number = 64;
export const GIS_TOOL_MODE_INTEGRATE: number = 65;
export const GIS_TOOL_MODE_EXTEND_TRIM_LINE: number = 66;
export const GIS_TOOL_MODE_AGGREGATE_POLYGONS: number = 67;
export const GIS_TOOL_MODE_ELIMINATE: number = 68;
export const GIS_TOOL_MODE_REMOVE_FRAGMENTS: number = 69;
export const GIS_TOOL_MODE_UNIFY_DIRECTION: number = 70;
export const GIS_TOOL_MODE_CENTERLINE: number = 71;
export const GIS_TOOL_MODE_FISHNET: number = 72;
export const GIS_TOOL_MODE_HEXAGON_GRID: number = 73;
export const GIS_TOOL_MODE_RANDOM_POINTS: number = 74;
export const GIS_TOOL_MODE_REGULAR_POINTS: number = 75;
export const GIS_TOOL_MODE_ADVANCED_BUFFER: number = 76;
export const GIS_TOOL_MODE_SPATIAL_JOIN: number = 77;
export const GIS_TOOL_MODE_ADVANCED_CLIP: number = 78;
export const GIS_TOOL_MODE_SPLIT_LINE_AT_POINT: number = 79;
export const GIS_TOOL_MODE_SPATIAL_ANALYSIS_FIRST: number = 80;
export const GIS_TOOL_MODE_SPATIAL_ANALYSIS_LAST: number = 108;
export const GIS_TOOL_MODE_CHM: number = 109;
export const GIS_TOOL_MODE_EARTHWORK: number = 110;
export const GIS_TOOL_MODE_SURFACE_AREA: number = 111;
export const GIS_TOOL_MODE_TIN: number = 112;
export const GIS_TOOL_MODE_TERRAIN_PROFILE: number = 113;
export const GIS_TOOL_MODE_LINE_OF_SIGHT: number = 114;
export const GIS_TOOL_MODE_VIEWSHED: number = 115;
export const GIS_TOOL_MODE_SKYLINE: number = 116;

export function advancedSpatialToolModeForAlgorithmId(algorithmId: string): number {
  if (algorithmId === 'mean_center') return 80;
  if (algorithmId === 'median_center') return 81;
  if (algorithmId === 'central_feature') return 82;
  if (algorithmId === 'standard_distance') return 83;
  if (algorithmId === 'directional_distribution') return 84;
  if (algorithmId === 'global_moran') return 85;
  if (algorithmId === 'geary_c') return 86;
  if (algorithmId === 'local_moran') return 87;
  if (algorithmId === 'general_g') return 88;
  if (algorithmId === 'gi_star') return 89;
  if (algorithmId === 'ripley_k') return 90;
  if (algorithmId === 'spatial_weights') return 91;
  if (algorithmId === 'weights_convert') return 92;
  if (algorithmId === 'weights_visualize') return 93;
  if (algorithmId === 'cluster_outlier') return 94;
  if (algorithmId === 'ols') return 95;
  if (algorithmId === 'gwr') return 96;
  if (algorithmId === 'mgwr') return 97;
  if (algorithmId === 'interpolation_cv') return 98;
  if (algorithmId === 'forest') return 99;
  if (algorithmId === 'boosted_trees') return 100;
  if (algorithmId === 'maxent') return 101;
  if (algorithmId === 'space_time_cube') return 102;
  if (algorithmId === 'emerging_hotspot') return 103;
  if (algorithmId === 'spatiotemporal_cluster') return 104;
  if (algorithmId === 'trajectory_cluster') return 105;
  if (algorithmId === 'time_series_forecast') return 106;
  if (algorithmId === 'change_point') return 107;
  if (algorithmId === 'time_series_anomaly') return 108;
  return 0;
}

function advancedSpatialAlgorithmId(toolMode: number): string {
  if (toolMode === 80) return 'mean_center';
  if (toolMode === 81) return 'median_center';
  if (toolMode === 82) return 'central_feature';
  if (toolMode === 83) return 'standard_distance';
  if (toolMode === 84) return 'directional_distribution';
  if (toolMode === 85) return 'global_moran';
  if (toolMode === 86) return 'geary_c';
  if (toolMode === 87) return 'local_moran';
  if (toolMode === 88) return 'general_g';
  if (toolMode === 89) return 'gi_star';
  if (toolMode === 90) return 'ripley_k';
  if (toolMode === 91) return 'spatial_weights';
  if (toolMode === 92) return 'weights_convert';
  if (toolMode === 93) return 'weights_visualize';
  if (toolMode === 94) return 'cluster_outlier';
  if (toolMode === 95) return 'ols';
  if (toolMode === 96) return 'gwr';
  if (toolMode === 97) return 'mgwr';
  if (toolMode === 98) return 'interpolation_cv';
  if (toolMode === 99) return 'forest';
  if (toolMode === 100) return 'boosted_trees';
  if (toolMode === 101) return 'maxent';
  if (toolMode === 102) return 'space_time_cube';
  if (toolMode === 103) return 'emerging_hotspot';
  if (toolMode === 104) return 'spatiotemporal_cluster';
  if (toolMode === 105) return 'trajectory_cluster';
  if (toolMode === 106) return 'time_series_forecast';
  if (toolMode === 107) return 'change_point';
  if (toolMode === 108) return 'time_series_anomaly';
  return '';
}

function advancedSpatialTitle(toolMode: number): string {
  if (toolMode === 80) return '平均中心';
  if (toolMode === 81) return '中位数中心';
  if (toolMode === 82) return '中心要素';
  if (toolMode === 83) return '标准距离';
  if (toolMode === 84) return '方向分布（标准差椭圆）';
  if (toolMode === 85) return '全局 Moran’s I';
  if (toolMode === 86) return 'Geary’s C';
  if (toolMode === 87) return '局部 Moran’s I';
  if (toolMode === 88) return 'Getis-Ord General G';
  if (toolMode === 89) return 'Gi* 热点分析';
  if (toolMode === 90) return 'Ripley’s K';
  if (toolMode === 91) return '创建空间权重矩阵';
  if (toolMode === 92) return '转换空间权重矩阵';
  if (toolMode === 93) return '可视化空间权重';
  if (toolMode === 94) return '聚类与异常值分析';
  if (toolMode === 95) return '普通最小二乘 OLS';
  if (toolMode === 96) return '地理加权回归 GWR';
  if (toolMode === 97) return '多尺度地理加权回归 MGWR';
  if (toolMode === 98) return '空间插值交叉验证';
  if (toolMode === 99) return 'Forest 空间预测';
  if (toolMode === 100) return 'Boosted Trees 空间预测';
  if (toolMode === 101) return 'MaxEnt 空间预测';
  if (toolMode === 102) return '时空立方体';
  if (toolMode === 103) return '新兴热点分析';
  if (toolMode === 104) return '时空聚类';
  if (toolMode === 105) return '轨迹聚类';
  if (toolMode === 106) return '时间序列预测';
  if (toolMode === 107) return '变化点检测';
  if (toolMode === 108) return '时间序列异常检测';
  return '高级空间分析';
}

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
  @Prop @Watch('onToolModeChanged') toolMode: number = GIS_TOOL_MODE_CLIP;
  onToolCompleted: () => void = () => {};
  onQualityCheckCompleted: (sourceLayerIndex: number, errorLayerIndex: number, requiredFields: string) => void =
    (_sourceLayerIndex: number, _errorLayerIndex: number, _requiredFields: string): void => {};
  onChooseLocalLayer: (fieldIndex: number, onSelected: (layerName: string) => void) => void =
    (_fieldIndex: number, _onSelected: (layerName: string) => void) => {};
  @State private inputName: string = '';
  @State private clipName: string = '';
  @State private parameterName: string = '';
  @State private populationFieldName: string = '';
  @State private areaUnitName: string = '';
  @State private outputName: string = '';
  @State private runStatus: string = '待运行';
  @State private uiRevision: number = 0;
  @State private crsPickerTrigger: boolean = false;
  @State private preparedToolMode: number = -1;
  @StorageLink(PROCESSING_TASK_REVISION_KEY) @Watch('onProcessingTaskRevisionChanged')
  private processingTaskRevision: number = 0;
  @State private activeTaskId: string = '';
  @State private taskProgress: number = 0;
  @State private taskStage: string = '';
  @State private taskState: string = '';
  @State private taskRunning: boolean = false;
  private taskCompletionHandled: boolean = false;
  private pendingInputIndex: number = -1;
  private pendingOutputLayerName: string = '';
  private pendingToolMode: number = -1;
  private pendingQualityFields: string = '';
  private lastWidgetTaskId: string = '';
  private lastWidgetProgressBucket: number = -1;
  private lastWidgetTaskState: string = '';

  private prepareToolMode(): void {
    if (this.preparedToolMode !== this.toolMode) {
      this.inputName = '';
      this.clipName = '';
      this.parameterName = '';
      this.populationFieldName = '';
      this.areaUnitName = '';
      this.outputName = '';
      this.runStatus = '待运行';
      this.preparedToolMode = this.toolMode;
      this.uiRevision++;
    }
  }

  onToolModeChanged(): void {
    this.prepareToolMode();
  }

  onTrigger(): void {
    this.prepareToolMode();
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

  private defaultRasterLineText(includeHeights: boolean): string {
    let layer: GisLoadedLayer | undefined = this.getActiveLayer();
    if (layer === undefined) {
      return includeHeights ? '0,0,1,1,1.7,0' : '0,0,1,1';
    }
    let value: string = layer.info.envelope.minX.toString() + ',' + layer.info.envelope.minY.toString() + ',' +
      layer.info.envelope.maxX.toString() + ',' + layer.info.envelope.maxY.toString();
    if (includeHeights) {
      value += ',1.7,0';
    }
    return value;
  }

  private defaultVisibilityText(): string {
    let layer: GisLoadedLayer | undefined = this.getActiveLayer();
    if (layer === undefined) {
      return '0.5,0.5,1.7,720,0';
    }
    let centerX: number = (layer.info.envelope.minX + layer.info.envelope.maxX) / 2;
    let centerY: number = (layer.info.envelope.minY + layer.info.envelope.maxY) / 2;
    return centerX.toString() + ',' + centerY.toString() + ',1.7,720,0';
  }

  private isDensityRasterTool(): boolean {
    return this.toolMode === GIS_TOOL_MODE_KERNEL_DENSITY || this.toolMode === GIS_TOOL_MODE_POINT_DENSITY ||
      this.toolMode === GIS_TOOL_MODE_LINE_DENSITY;
  }

  private isRasterInterpolationTool(): boolean {
    return this.isDensityRasterTool() || this.toolMode === GIS_TOOL_MODE_IDW;
  }

  private isRasterTerrainTool(): boolean {
    return this.toolMode === GIS_TOOL_MODE_RASTER_SLOPE || this.toolMode === GIS_TOOL_MODE_RASTER_ASPECT;
  }

  private isRasterOutputTool(): boolean {
    return this.isRasterInterpolationTool() || this.isRasterTerrainTool() ||
      this.toolMode === GIS_TOOL_MODE_RASTER_RECLASSIFY || this.toolMode === GIS_TOOL_MODE_CHM ||
      this.toolMode === GIS_TOOL_MODE_EARTHWORK || this.toolMode === GIS_TOOL_MODE_SURFACE_AREA ||
      this.toolMode === GIS_TOOL_MODE_LINE_OF_SIGHT || this.toolMode === GIS_TOOL_MODE_VIEWSHED;
  }

  private isRasterOutputMode(toolMode: number): boolean {
    return toolMode === GIS_TOOL_MODE_KERNEL_DENSITY || toolMode === GIS_TOOL_MODE_POINT_DENSITY ||
      toolMode === GIS_TOOL_MODE_LINE_DENSITY || toolMode === GIS_TOOL_MODE_IDW ||
      toolMode === GIS_TOOL_MODE_RASTER_SLOPE || toolMode === GIS_TOOL_MODE_RASTER_ASPECT ||
      toolMode === GIS_TOOL_MODE_RASTER_RECLASSIFY || toolMode === GIS_TOOL_MODE_CHM ||
      toolMode === GIS_TOOL_MODE_EARTHWORK || toolMode === GIS_TOOL_MODE_SURFACE_AREA ||
      toolMode === GIS_TOOL_MODE_LINE_OF_SIGHT || toolMode === GIS_TOOL_MODE_VIEWSHED;
  }

  private isAdvancedSpatialTool(): boolean {
    return this.toolMode >= GIS_TOOL_MODE_SPATIAL_ANALYSIS_FIRST &&
      this.toolMode <= GIS_TOOL_MODE_SPATIAL_ANALYSIS_LAST;
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
    return this.toolMode === GIS_TOOL_MODE_DEFINE_PROJECTION || this.toolMode === GIS_TOOL_MODE_PROJECT_LAYER;
  }

  private shouldOfferLocalShapefileSave(): boolean {
    return this.isAdvancedSpatialTool() ||
      (this.toolMode >= GIS_TOOL_MODE_EXPORT && this.toolMode <= GIS_TOOL_MODE_CENTROID) ||
      (this.toolMode >= GIS_TOOL_MODE_CONVEX_HULL && this.toolMode <= GIS_TOOL_MODE_VORONOI) ||
      this.isRasterOutputTool() || this.toolMode === GIS_TOOL_MODE_QUALITY_CHECK ||
      this.toolMode === GIS_TOOL_MODE_UNION || this.toolMode === GIS_TOOL_MODE_IDENTITY ||
      this.toolMode === GIS_TOOL_MODE_UPDATE ||
      (this.toolMode >= GIS_TOOL_MODE_FEATURE_TO_POINT && this.toolMode <= GIS_TOOL_MODE_SPLIT_LINE_AT_POINT) ||
      this.toolMode === GIS_TOOL_MODE_TIN || this.toolMode === GIS_TOOL_MODE_TERRAIN_PROFILE ||
      this.toolMode === GIS_TOOL_MODE_SKYLINE;
  }

  private shouldOfferLocalSaveForMode(toolMode: number): boolean {
    return (toolMode >= GIS_TOOL_MODE_SPATIAL_ANALYSIS_FIRST && toolMode <= GIS_TOOL_MODE_SPATIAL_ANALYSIS_LAST) ||
      (toolMode >= GIS_TOOL_MODE_EXPORT && toolMode <= GIS_TOOL_MODE_CENTROID) ||
      (toolMode >= GIS_TOOL_MODE_CONVEX_HULL && toolMode <= GIS_TOOL_MODE_VORONOI) ||
      this.isRasterOutputMode(toolMode) || toolMode === GIS_TOOL_MODE_QUALITY_CHECK ||
      toolMode === GIS_TOOL_MODE_UNION || toolMode === GIS_TOOL_MODE_IDENTITY ||
      toolMode === GIS_TOOL_MODE_UPDATE ||
      (toolMode >= GIS_TOOL_MODE_FEATURE_TO_POINT && toolMode <= GIS_TOOL_MODE_SPLIT_LINE_AT_POINT) ||
      toolMode === GIS_TOOL_MODE_SKYLINE;
  }

  private requiresLayerSecondaryInput(): boolean {
    return this.toolMode === GIS_TOOL_MODE_CLIP || this.toolMode === GIS_TOOL_MODE_DIFFERENCE ||
      this.toolMode === GIS_TOOL_MODE_SYMMETRICAL_DIFFERENCE || this.toolMode === GIS_TOOL_MODE_MERGE_LAYERS ||
      this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_LOCATION || this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN_SUMMARY ||
      this.toolMode === GIS_TOOL_MODE_INTERSECTION || this.toolMode === GIS_TOOL_MODE_NEAREST_NEIGHBOR ||
      this.toolMode === GIS_TOOL_MODE_UNION || this.toolMode === GIS_TOOL_MODE_IDENTITY ||
      this.toolMode === GIS_TOOL_MODE_UPDATE || this.toolMode === GIS_TOOL_MODE_SPLIT ||
      this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_MASK ||
      this.toolMode === GIS_TOOL_MODE_TABULATE_INTERSECTION ||
      this.toolMode === GIS_TOOL_MODE_SUMMARIZE_WITHIN ||
      (this.toolMode >= GIS_TOOL_MODE_NEAR && this.toolMode <= GIS_TOOL_MODE_SHORTEST_CONNECTION) ||
      this.toolMode === GIS_TOOL_MODE_SNAP_OUTPUT || this.toolMode === GIS_TOOL_MODE_INTEGRATE ||
      this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN || this.toolMode === GIS_TOOL_MODE_ADVANCED_CLIP ||
      this.toolMode === GIS_TOOL_MODE_SPLIT_LINE_AT_POINT || this.toolMode === GIS_TOOL_MODE_CHM;
  }

  private requiresSecondaryInput(): boolean {
    return this.toolMode !== GIS_TOOL_MODE_EXPORT && this.toolMode !== GIS_TOOL_MODE_DISSOLVE &&
      this.toolMode !== GIS_TOOL_MODE_CENTROID && this.toolMode !== GIS_TOOL_MODE_REPAIR &&
      this.toolMode !== GIS_TOOL_MODE_CONVEX_HULL && this.toolMode !== GIS_TOOL_MODE_BOUNDING_BOXES &&
      this.toolMode !== GIS_TOOL_MODE_ORIENTED_MINIMUM_BOUNDING_BOX &&
      this.toolMode !== GIS_TOOL_MODE_MULTIPART_TO_SINGLEPARTS &&
      this.toolMode !== GIS_TOOL_MODE_POLYGON_TO_LINE &&
      this.toolMode !== GIS_TOOL_MODE_FEATURE_TO_POLYGON &&
      this.toolMode !== GIS_TOOL_MODE_VERTICES_TO_POINTS &&
      this.toolMode !== GIS_TOOL_MODE_POLYGON_NEIGHBORS &&
      this.toolMode !== GIS_TOOL_MODE_UNIFY_DIRECTION &&
      this.toolMode !== GIS_TOOL_MODE_CENTERLINE && this.toolMode !== GIS_TOOL_MODE_SURFACE_AREA;
  }

  private requiresTertiaryInput(): boolean {
    return this.isAdvancedSpatialTool() || this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_LOCATION ||
      this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN_SUMMARY ||
      this.toolMode === GIS_TOOL_MODE_SUMMARIZE_WITHIN ||
      this.toolMode === GIS_TOOL_MODE_GENERATE_NEAR_TABLE ||
      this.toolMode === GIS_TOOL_MODE_POINT_DISTANCE ||
      this.toolMode === GIS_TOOL_MODE_DISTANCE_MATRIX ||
      this.toolMode === GIS_TOOL_MODE_SNAP_OUTPUT || this.toolMode === GIS_TOOL_MODE_INTEGRATE ||
      this.toolMode === GIS_TOOL_MODE_EXTEND_TRIM_LINE ||
      this.toolMode === GIS_TOOL_MODE_RANDOM_POINTS ||
      this.toolMode === GIS_TOOL_MODE_ADVANCED_BUFFER || this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN ||
      this.toolMode === GIS_TOOL_MODE_ADVANCED_CLIP ||
      this.toolMode === GIS_TOOL_MODE_SPLIT_LINE_AT_POINT ||
      this.toolMode === GIS_TOOL_MODE_TERRAIN_PROFILE || this.isRasterInterpolationTool();
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
    if (this.isAdvancedSpatialTool()) {
      return advancedSpatialTitle(this.toolMode);
    }
    if (this.toolMode === GIS_TOOL_MODE_BUFFER) {
      return '缓冲区';
    }
    if (this.toolMode === GIS_TOOL_MODE_REPAIR) {
      return '修复几何';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXPORT) {
      return '导出 Shapefile';
    }
    if (this.toolMode === GIS_TOOL_MODE_DEFINE_PROJECTION) {
      return '定义投影';
    }
    if (this.toolMode === GIS_TOOL_MODE_PROJECT_LAYER) {
      return '投影转换';
    }
    if (this.toolMode === GIS_TOOL_MODE_SIMPLIFY) {
      return '简化几何';
    }
    if (this.toolMode === GIS_TOOL_MODE_DISSOLVE) {
      return '融合全部';
    }
    if (this.toolMode === GIS_TOOL_MODE_CENTROID) {
      return '生成质心';
    }
    if (this.toolMode === GIS_TOOL_MODE_CONVEX_HULL) {
      return '凸包';
    }
    if (this.toolMode === GIS_TOOL_MODE_BOUNDING_BOXES) {
      return '外包框';
    }
    if (this.toolMode === GIS_TOOL_MODE_ORIENTED_MINIMUM_BOUNDING_BOX) {
      return '最小旋转外包框';
    }
    if (this.toolMode === GIS_TOOL_MODE_MULTIPART_TO_SINGLEPARTS) {
      return '多部件转单部件';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_EXPRESSION) {
      return '按表达式提取';
    }
    if (this.toolMode === GIS_TOOL_MODE_DIFFERENCE) {
      return '差集';
    }
    if (this.toolMode === GIS_TOOL_MODE_SYMMETRICAL_DIFFERENCE) {
      return '对称差集';
    }
    if (this.toolMode === GIS_TOOL_MODE_UNION) {
      return '联合';
    }
    if (this.toolMode === GIS_TOOL_MODE_IDENTITY) {
      return '标识叠加';
    }
    if (this.toolMode === GIS_TOOL_MODE_UPDATE) {
      return '更新叠加';
    }
    if (this.toolMode === GIS_TOOL_MODE_FEATURE_TO_POINT) {
      return '要素转点';
    }
    if (this.toolMode === GIS_TOOL_MODE_POLYGON_TO_LINE) {
      return '面转线';
    }
    if (this.toolMode === GIS_TOOL_MODE_FEATURE_TO_POLYGON) {
      return '要素构面';
    }
    if (this.toolMode === GIS_TOOL_MODE_VERTICES_TO_POINTS) {
      return '节点转点';
    }
    if (this.toolMode === GIS_TOOL_MODE_POINTS_TO_LINE) {
      return '点集转线';
    }
    if (this.toolMode === GIS_TOOL_MODE_DENSIFY) {
      return '几何加密';
    }
    if (this.toolMode === GIS_TOOL_MODE_SMOOTH) {
      return '平滑几何';
    }
    if (this.toolMode === GIS_TOOL_MODE_REMOVE_HOLES) {
      return '删除洞';
    }
    if (this.toolMode === GIS_TOOL_MODE_SELECT) {
      return 'Select';
    }
    if (this.toolMode === GIS_TOOL_MODE_TABLE_SELECT) {
      return 'Table Select';
    }
    if (this.toolMode === GIS_TOOL_MODE_SPLIT) {
      return '按叠加要素分割';
    }
    if (this.toolMode === GIS_TOOL_MODE_SPLIT_BY_ATTRIBUTES) {
      return '按属性拆分';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_EXTENT) {
      return '按范围提取';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_TIME) {
      return '按时间提取';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_MASK) {
      return '按掩膜提取';
    }
    if (this.toolMode === GIS_TOOL_MODE_TABULATE_INTERSECTION) {
      return '交集制表';
    }
    if (this.toolMode === GIS_TOOL_MODE_SUMMARIZE_WITHIN) {
      return '范围内汇总';
    }
    if (this.toolMode === GIS_TOOL_MODE_NEAR) {
      return 'Near';
    }
    if (this.toolMode === GIS_TOOL_MODE_GENERATE_NEAR_TABLE) {
      return '生成邻近表';
    }
    if (this.toolMode === GIS_TOOL_MODE_POINT_DISTANCE) {
      return '点距离';
    }
    if (this.toolMode === GIS_TOOL_MODE_DISTANCE_MATRIX) {
      return '距离矩阵';
    }
    if (this.toolMode === GIS_TOOL_MODE_SHORTEST_CONNECTION) {
      return '最短连接线';
    }
    if (this.toolMode === GIS_TOOL_MODE_SUMMARY_STATISTICS) {
      return '汇总统计';
    }
    if (this.toolMode === GIS_TOOL_MODE_FREQUENCY) {
      return '频数统计';
    }
    if (this.toolMode === GIS_TOOL_MODE_UNIQUE_VALUES) {
      return '字段唯一值';
    }
    if (this.toolMode === GIS_TOOL_MODE_GROUP_STATISTICS) {
      return '分组统计';
    }
    if (this.toolMode === GIS_TOOL_MODE_CROSSTAB_PIVOT) {
      return '交叉表与透视';
    }
    if (this.toolMode === GIS_TOOL_MODE_STATISTICS_CHART) {
      return '统计结果图表';
    }
    if (this.toolMode === GIS_TOOL_MODE_POLYGON_NEIGHBORS) {
      return '面邻接关系';
    }
    if (this.toolMode === GIS_TOOL_MODE_SNAP_OUTPUT) return '捕捉';
    if (this.toolMode === GIS_TOOL_MODE_INTEGRATE) return '整合';
    if (this.toolMode === GIS_TOOL_MODE_EXTEND_TRIM_LINE) return '延伸/修剪线';
    if (this.toolMode === GIS_TOOL_MODE_AGGREGATE_POLYGONS) return '聚合面';
    if (this.toolMode === GIS_TOOL_MODE_ELIMINATE) return '消除面界线';
    if (this.toolMode === GIS_TOOL_MODE_REMOVE_FRAGMENTS) return '修剪碎片';
    if (this.toolMode === GIS_TOOL_MODE_UNIFY_DIRECTION) return '方向统一';
    if (this.toolMode === GIS_TOOL_MODE_CENTERLINE) return '生成中心线';
    if (this.toolMode === GIS_TOOL_MODE_FISHNET) return '渔网';
    if (this.toolMode === GIS_TOOL_MODE_HEXAGON_GRID) return '六边形网格';
    if (this.toolMode === GIS_TOOL_MODE_RANDOM_POINTS) return '随机点';
    if (this.toolMode === GIS_TOOL_MODE_REGULAR_POINTS) return '规则采样点';
    if (this.toolMode === GIS_TOOL_MODE_ADVANCED_BUFFER) return '高级缓冲区';
    if (this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN) return '空间连接';
    if (this.toolMode === GIS_TOOL_MODE_ADVANCED_CLIP) return '高级裁剪';
    if (this.toolMode === GIS_TOOL_MODE_SPLIT_LINE_AT_POINT) return '在线点处分割线';
    if (this.toolMode === GIS_TOOL_MODE_MERGE_LAYERS) {
      return '合并图层';
    }
    if (this.toolMode === GIS_TOOL_MODE_MULTI_RING_BUFFER) {
      return '多环缓冲';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_LOCATION) {
      return '按位置提取';
    }
    if (this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN_SUMMARY) {
      return '空间连接汇总';
    }
    if (this.toolMode === GIS_TOOL_MODE_INTERSECTION) {
      return '相交';
    }
    if (this.toolMode === GIS_TOOL_MODE_NEAREST_NEIGHBOR) {
      return '最近邻';
    }
    if (this.toolMode === GIS_TOOL_MODE_VORONOI) {
      return '泰森多边形';
    }
    if (this.toolMode === GIS_TOOL_MODE_TIN) return 'TIN 三角网';
    if (this.toolMode === GIS_TOOL_MODE_TERRAIN_PROFILE) return '地形剖面';
    if (this.toolMode === GIS_TOOL_MODE_LINE_OF_SIGHT) return '视线分析';
    if (this.toolMode === GIS_TOOL_MODE_VIEWSHED) return '视域分析';
    if (this.toolMode === GIS_TOOL_MODE_SKYLINE) return '天际线分析';
    if (this.toolMode === GIS_TOOL_MODE_KERNEL_DENSITY) {
      return '核密度';
    }
    if (this.toolMode === GIS_TOOL_MODE_POINT_DENSITY) {
      return '点密度';
    }
    if (this.toolMode === GIS_TOOL_MODE_LINE_DENSITY) {
      return '线密度';
    }
    if (this.toolMode === GIS_TOOL_MODE_IDW) {
      return 'IDW 插值';
    }
    if (this.toolMode === GIS_TOOL_MODE_RASTER_SLOPE) {
      return '坡度';
    }
    if (this.toolMode === GIS_TOOL_MODE_RASTER_ASPECT) {
      return '坡向';
    }
    if (this.toolMode === GIS_TOOL_MODE_RASTER_RECLASSIFY) {
      return '栅格重分类';
    }
    if (this.toolMode === GIS_TOOL_MODE_CHM) return '冠层高度模型';
    if (this.toolMode === GIS_TOOL_MODE_EARTHWORK) return '挖填方计算';
    if (this.toolMode === GIS_TOOL_MODE_SURFACE_AREA) return '地表面积';
    if (this.toolMode === GIS_TOOL_MODE_QUALITY_CHECK) {
      return '数据质检';
    }
    return '裁剪';
  }

  private toolDescription(): string {
    if (this.isAdvancedSpatialTool()) {
      return '在 QGIS 原生后台任务中执行统计推断并生成可制图的诊断字段。';
    }
    if (this.toolMode === GIS_TOOL_MODE_BUFFER) {
      return '使用当前图层生成缓冲分析参数。';
    }
    if (this.toolMode === GIS_TOOL_MODE_REPAIR) {
      return '检查当前图层几何并准备修复任务。';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXPORT) {
      return '将当前图层写出为 Shapefile、GeoPackage、GeoJSON、KML、CSV 或 FlatGeobuf。';
    }
    if (this.toolMode === GIS_TOOL_MODE_DEFINE_PROJECTION) {
      return '为当前图层写入新的 CRS 定义，不改变坐标。';
    }
    if (this.toolMode === GIS_TOOL_MODE_PROJECT_LAYER) {
      return '把当前图层几何转换到目标 CRS 并输出成果。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SIMPLIFY) {
      return '使用 QgsGeometry::simplify 按坐标单位容差简化几何。';
    }
    if (this.toolMode === GIS_TOOL_MODE_DISSOLVE) {
      return '使用 QgsGeometry::unaryUnion 将全部要素融合为一个要素。';
    }
    if (this.toolMode === GIS_TOOL_MODE_CENTROID) {
      return '使用 QgsGeometry::centroid 为每个要素生成质心点。';
    }
    if (this.toolMode === GIS_TOOL_MODE_CONVEX_HULL) {
      return '将输入图层全部几何合并后生成整体凸包面。';
    }
    if (this.toolMode === GIS_TOOL_MODE_BOUNDING_BOXES) {
      return '为每个要素生成轴向外包矩形并保留属性。';
    }
    if (this.toolMode === GIS_TOOL_MODE_ORIENTED_MINIMUM_BOUNDING_BOX) {
      return '为每个要素生成旋转最小外包矩形并写入面积、角度、宽高。';
    }
    if (this.toolMode === GIS_TOOL_MODE_MULTIPART_TO_SINGLEPARTS) {
      return '把多部件几何拆分为单部件要素并保留属性。';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_EXPRESSION) {
      return '使用 QGIS 表达式筛选要素并输出新图层。';
    }
    if (this.toolMode === GIS_TOOL_MODE_DIFFERENCE) {
      return '从输入图层几何中擦除叠加图层范围。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SYMMETRICAL_DIFFERENCE) {
      return '逐要素输出两个图层中不重叠的部分，保留双方属性和来源 FID。';
    }
    if (this.toolMode === GIS_TOOL_MODE_UNION) {
      return '对两个面图层做联合叠加，输出相交区和双方独有区并保留全部字段。';
    }
    if (this.toolMode === GIS_TOOL_MODE_IDENTITY) {
      return '保留全部输入要素，并把标识图层属性写入重叠部分。';
    }
    if (this.toolMode === GIS_TOOL_MODE_UPDATE) {
      return '用更新面图层替换输入重叠区域，并按同名字段写入更新属性。';
    }
    if (this.toolMode === GIS_TOOL_MODE_FEATURE_TO_POINT) {
      return '为每个要素生成质心或保证位于要素内部的代表点，并保留来源属性。';
    }
    if (this.toolMode === GIS_TOOL_MODE_POLYGON_TO_LINE) {
      return '将面要素的外环和内环转换为线要素并保留来源属性。';
    }
    if (this.toolMode === GIS_TOOL_MODE_FEATURE_TO_POLYGON) {
      return '将线网或面边界节点化并构建闭合多边形。';
    }
    if (this.toolMode === GIS_TOOL_MODE_VERTICES_TO_POINTS) {
      return '把所有几何节点输出为点，记录来源 FID 和节点序号。';
    }
    if (this.toolMode === GIS_TOOL_MODE_POINTS_TO_LINE) {
      return '按分组字段和排序字段连接点，可选择闭合；格式：分组字段;排序字段;是否闭合。';
    }
    if (this.toolMode === GIS_TOOL_MODE_DENSIFY) {
      return '按最大节点间距在线和面边界上插入节点。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SMOOTH) {
      return '使用迭代平滑处理线或面；主参数为迭代次数，偏移量默认为 0.25。';
    }
    if (this.toolMode === GIS_TOOL_MODE_REMOVE_HOLES) {
      return '删除面内环；阈值为 0 时删除全部洞，否则仅删除小于阈值的洞。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SELECT || this.toolMode === GIS_TOOL_MODE_TABLE_SELECT) {
      return '使用 QGIS 表达式筛选要素或表记录，输出独立结果。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SPLIT) {
      return '使用叠加图层逐要素切分输入几何，并保留输入与分割要素字段。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SPLIT_BY_ATTRIBUTES) {
      return '按指定字段的唯一值生成多个独立 Shapefile 分片。';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_EXTENT) {
      return '按 minX,minY,maxX,maxY 范围批量提取相交要素。';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_TIME) {
      return '按字段;开始值;结束值筛选时间区间内的记录。';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_MASK) {
      return '将掩膜图层转换到输入 CRS 后提取掩膜范围内的几何。';
    }
    if (this.toolMode === GIS_TOOL_MODE_TABULATE_INTERSECTION) {
      return '逐分区、逐类别计算相交面积或长度及其占分区面积百分比。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SUMMARIZE_WITHIN) {
      return '在输入面范围内统计要素数量、数值字段合计、相交面积和相交长度。';
    }
    if (this.toolMode === GIS_TOOL_MODE_NEAR) {
      return '为输入要素写入最近目标 FID 和真实几何最短距离。';
    }
    if (this.toolMode === GIS_TOOL_MODE_GENERATE_NEAR_TABLE) {
      return '为每个输入要素输出按距离排序的 K 个邻近目标及真实最短连接线。';
    }
    if (this.toolMode === GIS_TOOL_MODE_POINT_DISTANCE) {
      return '计算输入点与目标点的逐对距离；K 为 0 时输出全部组合。';
    }
    if (this.toolMode === GIS_TOOL_MODE_DISTANCE_MATRIX) {
      return '生成带来源、目标、排名和距离字段的空间距离矩阵。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SHORTEST_CONNECTION) {
      return '为每个输入要素生成到最近目标几何的最短连接线。';
    }
    if (this.toolMode >= GIS_TOOL_MODE_SUMMARY_STATISTICS &&
      this.toolMode <= GIS_TOOL_MODE_STATISTICS_CHART) {
      return '按 分组字段;类别字段;数值字段 生成频数、合计、最小、最大、均值和标准差。';
    }
    if (this.toolMode === GIS_TOOL_MODE_POLYGON_NEIGHBORS) {
      return '输出相邻面之间的关系线、共享边长度和重叠面积。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SNAP_OUTPUT || this.toolMode === GIS_TOOL_MODE_INTEGRATE) {
      return '在指定容差内将输入节点捕捉到目标图层节点，并输出新图层，不修改源数据。';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTEND_TRIM_LINE) return '按起点和终点距离延伸或修剪线。';
    if (this.toolMode === GIS_TOOL_MODE_AGGREGATE_POLYGONS) return '通过外扩、融合和回缩聚合邻近面。';
    if (this.toolMode === GIS_TOOL_MODE_ELIMINATE) return '融合面要素并消除内部界线。';
    if (this.toolMode === GIS_TOOL_MODE_REMOVE_FRAGMENTS) return '按面积或长度阈值移除细小碎片。';
    if (this.toolMode === GIS_TOOL_MODE_UNIFY_DIRECTION) return '将面环方向统一为右手规则。';
    if (this.toolMode === GIS_TOOL_MODE_CENTERLINE) return '按面要素主轴生成并裁剪中心线。';
    if (this.toolMode === GIS_TOOL_MODE_FISHNET) return '按输入图层范围和网格尺寸生成矩形渔网。';
    if (this.toolMode === GIS_TOOL_MODE_HEXAGON_GRID) return '按输入图层范围和边长生成六边形网格。';
    if (this.toolMode === GIS_TOOL_MODE_RANDOM_POINTS) return '在输入图层范围内按数量和随机种子生成点。';
    if (this.toolMode === GIS_TOOL_MODE_REGULAR_POINTS) return '按固定间距生成规则采样点。';
    if (this.toolMode === GIS_TOOL_MODE_ADVANCED_BUFFER) {
      return '支持字段距离、端点、连接、单侧、融合和局部等距投影测地线缓冲。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN) {
      return '支持 one-to-one、one-to-many、空间谓词和数值字段合计。';
    }
    if (this.toolMode === GIS_TOOL_MODE_ADVANCED_CLIP) {
      return '支持跨 CRS、几何修复、安全容差网格和全图层批量裁剪。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SPLIT_LINE_AT_POINT) {
      return '将点图层转换到线图层 CRS，在容差范围内把线切分为多个要素。';
    }
    if (this.toolMode === GIS_TOOL_MODE_MERGE_LAYERS) {
      return '合并两个相同几何类型图层的要素和字段。';
    }
    if (this.toolMode === GIS_TOOL_MODE_MULTI_RING_BUFFER) {
      return '按逗号分隔距离生成多环缓冲区。';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_LOCATION) {
      return '按空间谓词从输入图层提取与叠加图层匹配的要素。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN_SUMMARY) {
      return '统计每个输入要素匹配的连接要素数量和首个 FID。';
    }
    if (this.toolMode === GIS_TOOL_MODE_INTERSECTION) {
      return '输出两个图层相交部分，并携带双方属性字段。';
    }
    if (this.toolMode === GIS_TOOL_MODE_NEAREST_NEIGHBOR) {
      return '为输入要素生成到目标图层最近要素的连线。';
    }
    if (this.toolMode === GIS_TOOL_MODE_VORONOI) {
      return '用要素质心生成泰森多边形，可设置容差。';
    }
    if (this.toolMode === GIS_TOOL_MODE_TIN) {
      return '使用高程点执行 Delaunay 三角剖分，输出带最小、最大和平均高程的 TIN 三角面。';
    }
    if (this.toolMode === GIS_TOOL_MODE_TERRAIN_PROFILE) {
      return '沿指定起止坐标采样 DEM，输出带里程和高程字段的三维剖面点。';
    }
    if (this.toolMode === GIS_TOOL_MODE_LINE_OF_SIGHT) {
      return '沿观察点到目标点采样 DEM，输出可见/遮挡栅格并计算最小净空。';
    }
    if (this.toolMode === GIS_TOOL_MODE_VIEWSHED) {
      return '以观察点为中心扫描 DEM，输出可见与遮挡像元；支持方位角精度和最大距离。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SKYLINE) {
      return '按方位角提取最高地平线，输出包含方位角、仰角、距离和高程的三维点。';
    }
    if (this.toolMode === GIS_TOOL_MODE_KERNEL_DENSITY) {
      return '对标 ArcToolbox Kernel Density：基于点要素生成连续密度栅格。';
    }
    if (this.toolMode === GIS_TOOL_MODE_POINT_DENSITY) {
      return '对标 ArcToolbox Point Density：统计圆形邻域内点权重并生成密度栅格。';
    }
    if (this.toolMode === GIS_TOOL_MODE_LINE_DENSITY) {
      return '对标 ArcToolbox Line Density：统计圆形邻域内线段长度并生成密度栅格。';
    }
    if (this.toolMode === GIS_TOOL_MODE_IDW) {
      return '对标 ArcToolbox IDW：用点要素数值字段生成反距离权重插值栅格。';
    }
    if (this.toolMode === GIS_TOOL_MODE_RASTER_SLOPE) {
      return '读取 DEM 第一波段，用 Horn 梯度生成坡度栅格，单位为度。';
    }
    if (this.toolMode === GIS_TOOL_MODE_RASTER_ASPECT) {
      return '读取 DEM 第一波段，生成 0-360 度坡向栅格，平坦像元为 0。';
    }
    if (this.toolMode === GIS_TOOL_MODE_RASTER_RECLASSIFY) {
      return '按 min:max=value 规则把连续栅格值重分类为离散等级。';
    }
    if (this.toolMode === GIS_TOOL_MODE_CHM) {
      return '逐像元计算 DSM-DTM，负值归零，输出冠层高度模型。';
    }
    if (this.toolMode === GIS_TOOL_MODE_EARTHWORK) {
      return '按设计基准高程计算挖方、填方和净体积，并输出高差栅格。';
    }
    if (this.toolMode === GIS_TOOL_MODE_SURFACE_AREA) {
      return '根据相邻像元高程梯度计算每个像元的三维表面积及总表面积。';
    }
    if (this.toolMode === GIS_TOOL_MODE_QUALITY_CHECK) {
      return '生成错误点图层，检查无效几何、重复点、面重叠、悬挂线端点和必填字段缺失。';
    }
    return '使用当前图层配置裁剪输入和输出。';
  }

  private toolIcon(): Resource {
    if (this.toolMode === GIS_TOOL_MODE_BUFFER || this.toolMode === GIS_TOOL_MODE_MULTI_RING_BUFFER) {
      return $r('sys.symbol.circle_grid_2x2');
    }
    if (this.toolMode === GIS_TOOL_MODE_REPAIR) {
      return $r('sys.symbol.wrench_arrow_counterclockwise');
    }
    if (this.toolMode === GIS_TOOL_MODE_QUALITY_CHECK) {
      return $r('sys.symbol.list_checkmark');
    }
    if (this.toolMode === GIS_TOOL_MODE_EXPORT) {
      return $r('sys.symbol.download');
    }
    if (this.toolMode === GIS_TOOL_MODE_DEFINE_PROJECTION) {
      return $r('sys.symbol.map');
    }
    if (this.toolMode === GIS_TOOL_MODE_PROJECT_LAYER) {
      return $r('sys.symbol.arrow_right_and_square');
    }
    if (this.toolMode === GIS_TOOL_MODE_SIMPLIFY) {
      return $r('sys.symbol.arrow_down_right_and_arrow_up_left');
    }
    if (this.toolMode === GIS_TOOL_MODE_DISSOLVE || this.toolMode === GIS_TOOL_MODE_INTERSECTION ||
      this.toolMode === GIS_TOOL_MODE_SYMMETRICAL_DIFFERENCE || this.toolMode === GIS_TOOL_MODE_UNION ||
      this.toolMode === GIS_TOOL_MODE_IDENTITY || this.toolMode === GIS_TOOL_MODE_UPDATE) {
      return $r('sys.symbol.square_and_square');
    }
    if (this.toolMode === GIS_TOOL_MODE_CENTROID || this.toolMode === GIS_TOOL_MODE_NEAREST_NEIGHBOR ||
      this.toolMode === GIS_TOOL_MODE_VORONOI || this.isRasterOutputTool()) {
      return $r('sys.symbol.location_up');
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_EXPRESSION) {
      return $r('sys.symbol.funnel');
    }
    if (this.toolMode === GIS_TOOL_MODE_DIFFERENCE) {
      return $r('sys.symbol.square_and_cut');
    }
    if (this.toolMode === GIS_TOOL_MODE_MERGE_LAYERS || this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN_SUMMARY) {
      return $r('sys.symbol.plus_square_on_square');
    }
    if (this.toolMode === GIS_TOOL_MODE_MULTIPART_TO_SINGLEPARTS) {
      return $r('sys.symbol.square_stack_3d');
    }
    if (this.toolMode === GIS_TOOL_MODE_CONVEX_HULL || this.toolMode === GIS_TOOL_MODE_BOUNDING_BOXES ||
      this.toolMode === GIS_TOOL_MODE_ORIENTED_MINIMUM_BOUNDING_BOX) {
      return $r('sys.symbol.layer');
    }
    return $r('sys.symbol.square_dashed_and_arrow_turn_up_right');
  }

  private secondaryLabel(): string {
    if (this.isAdvancedSpatialTool()) {
      return '邻居数 / 距离 / 带宽（0 自动）';
    }
    if (this.toolMode === GIS_TOOL_MODE_BUFFER) {
      return '缓冲距离';
    }
    if (this.toolMode === GIS_TOOL_MODE_REPAIR) {
      return '修复规则';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXPORT) {
      return '导出格式';
    }
    if (this.requiresTargetCrs()) {
      return '目标坐标系';
    }
    if (this.toolMode === GIS_TOOL_MODE_SIMPLIFY) {
      return '简化容差';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_EXPRESSION) {
      return 'QGIS 表达式';
    }
    if (this.toolMode === GIS_TOOL_MODE_MULTI_RING_BUFFER) {
      return '缓冲距离列表';
    }
    if (this.toolMode === GIS_TOOL_MODE_VORONOI) {
      return '生成容差';
    }
    if (this.toolMode === GIS_TOOL_MODE_TIN) return '三角剖分容差';
    if (this.toolMode === GIS_TOOL_MODE_TERRAIN_PROFILE) return '起点X,起点Y,终点X,终点Y';
    if (this.toolMode === GIS_TOOL_MODE_LINE_OF_SIGHT) return '起点X,起点Y,终点X,终点Y,观察高,目标高';
    if (this.toolMode === GIS_TOOL_MODE_VIEWSHED || this.toolMode === GIS_TOOL_MODE_SKYLINE) {
      return '观察点X,观察点Y,观察高,方位角分箱,最大距离';
    }
    if (this.isRasterTerrainTool()) {
      return 'Z 因子';
    }
    if (this.toolMode === GIS_TOOL_MODE_EARTHWORK) return '设计基准高程';
    if (this.toolMode === GIS_TOOL_MODE_RASTER_RECLASSIFY) {
      return '重分类规则';
    }
    if (this.toolMode === GIS_TOOL_MODE_QUALITY_CHECK) {
      return '必填字段';
    }
    if (this.toolMode === GIS_TOOL_MODE_FEATURE_TO_POINT) {
      return '内部点模式（1 是 / 0 否）';
    }
    if (this.toolMode === GIS_TOOL_MODE_POINTS_TO_LINE) {
      return '分组;排序;闭合';
    }
    if (this.toolMode === GIS_TOOL_MODE_DENSIFY) {
      return '最大节点间距';
    }
    if (this.toolMode === GIS_TOOL_MODE_SMOOTH) {
      return '迭代次数';
    }
    if (this.toolMode === GIS_TOOL_MODE_REMOVE_HOLES) {
      return '最小保留洞面积';
    }
    if (this.toolMode === GIS_TOOL_MODE_SELECT || this.toolMode === GIS_TOOL_MODE_TABLE_SELECT) {
      return '筛选表达式';
    }
    if (this.toolMode === GIS_TOOL_MODE_SPLIT_BY_ATTRIBUTES) {
      return '拆分字段';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_EXTENT) {
      return '范围 minX,minY,maxX,maxY';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_TIME) {
      return '字段;开始值;结束值';
    }
    if (this.toolMode >= GIS_TOOL_MODE_SUMMARY_STATISTICS &&
      this.toolMode <= GIS_TOOL_MODE_STATISTICS_CHART) {
      return '分组;类别;数值字段';
    }
    if (this.toolMode === GIS_TOOL_MODE_AGGREGATE_POLYGONS) return '聚合距离';
    if (this.toolMode === GIS_TOOL_MODE_ELIMINATE) return '消除面积阈值';
    if (this.toolMode === GIS_TOOL_MODE_REMOVE_FRAGMENTS) return '最小面积/长度';
    if (this.toolMode === GIS_TOOL_MODE_EXTEND_TRIM_LINE) return '起点距离';
    if (this.toolMode === GIS_TOOL_MODE_FISHNET || this.toolMode === GIS_TOOL_MODE_HEXAGON_GRID ||
      this.toolMode === GIS_TOOL_MODE_REGULAR_POINTS) return '网格/采样间距';
    if (this.toolMode === GIS_TOOL_MODE_RANDOM_POINTS) return '随机点数量';
    if (this.toolMode === GIS_TOOL_MODE_ADVANCED_BUFFER) return '默认缓冲距离';
    if (this.isRasterInterpolationTool()) {
      return '搜索半径';
    }
    if (this.requiresLayerSecondaryInput()) {
      return '叠加图层';
    }
    return '裁剪要素';
  }

  private tertiaryLabel(): string {
    if (this.isAdvancedSpatialTool()) {
      return '分析参数';
    }
    if (this.isRasterInterpolationTool()) {
      return '像元大小';
    }
    if (this.toolMode === GIS_TOOL_MODE_TERRAIN_PROFILE) return '采样点数（0 自动）';
    if (this.toolMode === GIS_TOOL_MODE_SUMMARIZE_WITHIN) {
      return '汇总数值字段';
    }
    if (this.toolMode === GIS_TOOL_MODE_GENERATE_NEAR_TABLE ||
      this.toolMode === GIS_TOOL_MODE_POINT_DISTANCE || this.toolMode === GIS_TOOL_MODE_DISTANCE_MATRIX) {
      return 'K 邻近数;最大距离';
    }
    if (this.toolMode === GIS_TOOL_MODE_SNAP_OUTPUT || this.toolMode === GIS_TOOL_MODE_INTEGRATE) {
      return '捕捉容差';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTEND_TRIM_LINE) return '终点距离';
    if (this.toolMode === GIS_TOOL_MODE_RANDOM_POINTS) return '随机种子';
    if (this.toolMode === GIS_TOOL_MODE_ADVANCED_BUFFER) return '字段;段数;端点;连接;侧别;融合;测地线';
    if (this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN) return '模式;谓词;合计字段';
    if (this.toolMode === GIS_TOOL_MODE_ADVANCED_CLIP) return '安全容差';
    if (this.toolMode === GIS_TOOL_MODE_SPLIT_LINE_AT_POINT) return '分割容差';
    return '空间谓词模式';
  }

  private secondaryValue(): string {
    if (this.clipName.length > 0) {
      return this.clipName;
    }
    if (this.isAdvancedSpatialTool()) {
      return '8';
    }
    if (this.toolMode === GIS_TOOL_MODE_BUFFER) {
      return '0';
    }
    if (this.toolMode === GIS_TOOL_MODE_REPAIR) {
      return '自相交、空几何、重复节点';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXPORT) {
      return 'ESRI Shapefile';
    }
    if (this.requiresTargetCrs()) {
      return this.defaultTargetCrs();
    }
    if (this.toolMode === GIS_TOOL_MODE_SIMPLIFY) {
      return '1';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_EXPRESSION) {
      return '1 = 1';
    }
    if (this.toolMode === GIS_TOOL_MODE_MULTI_RING_BUFFER) {
      return '100,500,1000';
    }
    if (this.toolMode === GIS_TOOL_MODE_VORONOI) {
      return '0';
    }
    if (this.toolMode === GIS_TOOL_MODE_TIN) return '0';
    if (this.toolMode === GIS_TOOL_MODE_TERRAIN_PROFILE) return this.defaultRasterLineText(false);
    if (this.toolMode === GIS_TOOL_MODE_LINE_OF_SIGHT) return this.defaultRasterLineText(true);
    if (this.toolMode === GIS_TOOL_MODE_VIEWSHED || this.toolMode === GIS_TOOL_MODE_SKYLINE) {
      return this.defaultVisibilityText();
    }
    if (this.isRasterTerrainTool()) {
      return '1';
    }
    if (this.toolMode === GIS_TOOL_MODE_EARTHWORK) return '0';
    if (this.toolMode === GIS_TOOL_MODE_RASTER_RECLASSIFY) {
      return '0:10=1;10:30=2;30:*=3';
    }
    if (this.toolMode === GIS_TOOL_MODE_QUALITY_CHECK) {
      return '';
    }
    if (this.toolMode === GIS_TOOL_MODE_FEATURE_TO_POINT) {
      return '1';
    }
    if (this.toolMode === GIS_TOOL_MODE_POINTS_TO_LINE) {
      return 'NONE;NONE;0';
    }
    if (this.toolMode === GIS_TOOL_MODE_DENSIFY) {
      return '10';
    }
    if (this.toolMode === GIS_TOOL_MODE_SMOOTH) {
      return '1';
    }
    if (this.toolMode === GIS_TOOL_MODE_REMOVE_HOLES) {
      return '0';
    }
    if (this.toolMode === GIS_TOOL_MODE_SELECT || this.toolMode === GIS_TOOL_MODE_TABLE_SELECT) {
      return '1 = 1';
    }
    if (this.toolMode === GIS_TOOL_MODE_SPLIT_BY_ATTRIBUTES) {
      return '请填写字段名';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_EXTENT) {
      return '0,0,100,100';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_TIME) {
      return 'date;2020-01-01;2030-12-31';
    }
    if (this.toolMode >= GIS_TOOL_MODE_SUMMARY_STATISTICS &&
      this.toolMode <= GIS_TOOL_MODE_STATISTICS_CHART) {
      return 'NONE;NONE;NONE';
    }
    if (this.toolMode === GIS_TOOL_MODE_AGGREGATE_POLYGONS) return '10';
    if (this.toolMode === GIS_TOOL_MODE_ELIMINATE) return '1';
    if (this.toolMode === GIS_TOOL_MODE_REMOVE_FRAGMENTS) return '1';
    if (this.toolMode === GIS_TOOL_MODE_EXTEND_TRIM_LINE) return '0';
    if (this.toolMode === GIS_TOOL_MODE_FISHNET || this.toolMode === GIS_TOOL_MODE_HEXAGON_GRID ||
      this.toolMode === GIS_TOOL_MODE_REGULAR_POINTS) return '100';
    if (this.toolMode === GIS_TOOL_MODE_RANDOM_POINTS) return '100';
    if (this.toolMode === GIS_TOOL_MODE_ADVANCED_BUFFER) return '100';
    if (this.isRasterInterpolationTool()) {
      return '0';
    }
    if (this.toolMode === GIS_TOOL_MODE_NEAREST_NEIGHBOR) {
      return this.inputValue();
    }
    if (this.requiresLayerSecondaryInput()) {
      return this.defaultClipLayerName();
    }
    return this.defaultClipLayerName();
  }

  private tertiaryValue(): string {
    if (this.parameterName.length > 0) {
      return this.parameterName;
    }
    if (this.isAdvancedSpatialTool()) {
      return 'valueField=;weightMethod=knn;k=8;dependentField=;predictors=;timeField=;timeBins=10';
    }
    if (this.toolMode === GIS_TOOL_MODE_TERRAIN_PROFILE) return '0';
    if (this.isRasterInterpolationTool()) {
      return '0';
    }
    if (this.toolMode === GIS_TOOL_MODE_SUMMARIZE_WITHIN) return 'NONE';
    if (this.toolMode === GIS_TOOL_MODE_GENERATE_NEAR_TABLE) return '5;0';
    if (this.toolMode === GIS_TOOL_MODE_POINT_DISTANCE || this.toolMode === GIS_TOOL_MODE_DISTANCE_MATRIX) {
      return '0;0';
    }
    if (this.toolMode === GIS_TOOL_MODE_SNAP_OUTPUT || this.toolMode === GIS_TOOL_MODE_INTEGRATE) return '1';
    if (this.toolMode === GIS_TOOL_MODE_EXTEND_TRIM_LINE) return '0';
    if (this.toolMode === GIS_TOOL_MODE_RANDOM_POINTS) return '1';
    if (this.toolMode === GIS_TOOL_MODE_ADVANCED_BUFFER) return 'NONE;16;1;1;-1;0;0';
    if (this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN) return '0;0;NONE';
    if (this.toolMode === GIS_TOOL_MODE_ADVANCED_CLIP) return '0';
    if (this.toolMode === GIS_TOOL_MODE_SPLIT_LINE_AT_POINT) return '0';
    return '0';
  }

  private populationFieldValue(): string {
    if (this.populationFieldName.length > 0) {
      return this.populationFieldName;
    }
    return 'NONE';
  }

  private areaUnitValue(): string {
    if (this.areaUnitName.length > 0) {
      return this.areaUnitName;
    }
    if (this.toolMode === GIS_TOOL_MODE_IDW) {
      return '2';
    }
    return 'SQUARE_MAP_UNITS';
  }

  private outputValue(): string {
    if (this.outputName.length > 0) {
      return this.outputName;
    }
    let baseName = this.inputValue();
    if (this.isAdvancedSpatialTool()) {
      return baseName + '_' + advancedSpatialAlgorithmId(this.toolMode);
    }
    if (this.toolMode === GIS_TOOL_MODE_BUFFER) {
      return baseName + '_buffer';
    }
    if (this.toolMode === GIS_TOOL_MODE_REPAIR) {
      return baseName + '_repaired';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXPORT) {
      return baseName + '_export';
    }
    if (this.toolMode === GIS_TOOL_MODE_DEFINE_PROJECTION) {
      return baseName + '_defined_crs';
    }
    if (this.toolMode === GIS_TOOL_MODE_PROJECT_LAYER) {
      return baseName + '_projected';
    }
    if (this.toolMode === GIS_TOOL_MODE_SIMPLIFY) {
      return baseName + '_simplified';
    }
    if (this.toolMode === GIS_TOOL_MODE_DISSOLVE) {
      return baseName + '_dissolved';
    }
    if (this.toolMode === GIS_TOOL_MODE_CENTROID) {
      return baseName + '_centroids';
    }
    if (this.toolMode === GIS_TOOL_MODE_CONVEX_HULL) {
      return baseName + '_convex_hull';
    }
    if (this.toolMode === GIS_TOOL_MODE_BOUNDING_BOXES) {
      return baseName + '_boxes';
    }
    if (this.toolMode === GIS_TOOL_MODE_ORIENTED_MINIMUM_BOUNDING_BOX) {
      return baseName + '_ombb';
    }
    if (this.toolMode === GIS_TOOL_MODE_MULTIPART_TO_SINGLEPARTS) {
      return baseName + '_singleparts';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_EXPRESSION) {
      return baseName + '_expression';
    }
    if (this.toolMode === GIS_TOOL_MODE_DIFFERENCE) {
      return baseName + '_difference';
    }
    if (this.toolMode === GIS_TOOL_MODE_SYMMETRICAL_DIFFERENCE) {
      return baseName + '_symdiff';
    }
    if (this.toolMode === GIS_TOOL_MODE_UNION) {
      return baseName + '_union';
    }
    if (this.toolMode === GIS_TOOL_MODE_IDENTITY) {
      return baseName + '_identity';
    }
    if (this.toolMode === GIS_TOOL_MODE_UPDATE) {
      return baseName + '_updated';
    }
    if (this.toolMode === GIS_TOOL_MODE_FEATURE_TO_POINT) {
      return baseName + '_points';
    }
    if (this.toolMode === GIS_TOOL_MODE_POLYGON_TO_LINE) {
      return baseName + '_lines';
    }
    if (this.toolMode === GIS_TOOL_MODE_FEATURE_TO_POLYGON) {
      return baseName + '_polygons';
    }
    if (this.toolMode === GIS_TOOL_MODE_VERTICES_TO_POINTS) {
      return baseName + '_vertices';
    }
    if (this.toolMode === GIS_TOOL_MODE_POINTS_TO_LINE) {
      return baseName + '_point_lines';
    }
    if (this.toolMode === GIS_TOOL_MODE_DENSIFY) {
      return baseName + '_densified';
    }
    if (this.toolMode === GIS_TOOL_MODE_SMOOTH) {
      return baseName + '_smoothed';
    }
    if (this.toolMode === GIS_TOOL_MODE_REMOVE_HOLES) {
      return baseName + '_no_holes';
    }
    if (this.toolMode === GIS_TOOL_MODE_SELECT) {
      return baseName + '_selected';
    }
    if (this.toolMode === GIS_TOOL_MODE_TABLE_SELECT) {
      return baseName + '_table_selected';
    }
    if (this.toolMode === GIS_TOOL_MODE_SPLIT) {
      return baseName + '_split';
    }
    if (this.toolMode === GIS_TOOL_MODE_SPLIT_BY_ATTRIBUTES) {
      return baseName + '_split_groups';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_EXTENT) {
      return baseName + '_extent';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_TIME) {
      return baseName + '_time';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_MASK) {
      return baseName + '_mask';
    }
    if (this.toolMode === GIS_TOOL_MODE_TABULATE_INTERSECTION) {
      return baseName + '_tabulate';
    }
    if (this.toolMode === GIS_TOOL_MODE_SUMMARIZE_WITHIN) {
      return baseName + '_within_summary';
    }
    if (this.toolMode === GIS_TOOL_MODE_NEAR) {
      return baseName + '_near';
    }
    if (this.toolMode === GIS_TOOL_MODE_GENERATE_NEAR_TABLE) {
      return baseName + '_near_table';
    }
    if (this.toolMode === GIS_TOOL_MODE_POINT_DISTANCE) {
      return baseName + '_point_distance';
    }
    if (this.toolMode === GIS_TOOL_MODE_DISTANCE_MATRIX) {
      return baseName + '_distance_matrix';
    }
    if (this.toolMode === GIS_TOOL_MODE_SHORTEST_CONNECTION) {
      return baseName + '_shortest_links';
    }
    if (this.toolMode === GIS_TOOL_MODE_SUMMARY_STATISTICS) {
      return baseName + '_statistics';
    }
    if (this.toolMode === GIS_TOOL_MODE_FREQUENCY) {
      return baseName + '_frequency';
    }
    if (this.toolMode === GIS_TOOL_MODE_UNIQUE_VALUES) {
      return baseName + '_unique';
    }
    if (this.toolMode === GIS_TOOL_MODE_GROUP_STATISTICS) {
      return baseName + '_group_stats';
    }
    if (this.toolMode === GIS_TOOL_MODE_CROSSTAB_PIVOT) {
      return baseName + '_pivot';
    }
    if (this.toolMode === GIS_TOOL_MODE_STATISTICS_CHART) {
      return baseName + '_stats_chart';
    }
    if (this.toolMode === GIS_TOOL_MODE_POLYGON_NEIGHBORS) {
      return baseName + '_neighbors';
    }
    if (this.toolMode === GIS_TOOL_MODE_SNAP_OUTPUT) return baseName + '_snapped';
    if (this.toolMode === GIS_TOOL_MODE_INTEGRATE) return baseName + '_integrated';
    if (this.toolMode === GIS_TOOL_MODE_EXTEND_TRIM_LINE) return baseName + '_extended';
    if (this.toolMode === GIS_TOOL_MODE_AGGREGATE_POLYGONS) return baseName + '_aggregated';
    if (this.toolMode === GIS_TOOL_MODE_ELIMINATE) return baseName + '_eliminated';
    if (this.toolMode === GIS_TOOL_MODE_REMOVE_FRAGMENTS) return baseName + '_trimmed';
    if (this.toolMode === GIS_TOOL_MODE_UNIFY_DIRECTION) return baseName + '_oriented';
    if (this.toolMode === GIS_TOOL_MODE_CENTERLINE) return baseName + '_centerline';
    if (this.toolMode === GIS_TOOL_MODE_FISHNET) return baseName + '_fishnet';
    if (this.toolMode === GIS_TOOL_MODE_HEXAGON_GRID) return baseName + '_hexgrid';
    if (this.toolMode === GIS_TOOL_MODE_RANDOM_POINTS) return baseName + '_random';
    if (this.toolMode === GIS_TOOL_MODE_REGULAR_POINTS) return baseName + '_regular';
    if (this.toolMode === GIS_TOOL_MODE_ADVANCED_BUFFER) return baseName + '_advanced_buffer';
    if (this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN) return baseName + '_spatial_join';
    if (this.toolMode === GIS_TOOL_MODE_ADVANCED_CLIP) return baseName + '_advanced_clip';
    if (this.toolMode === GIS_TOOL_MODE_SPLIT_LINE_AT_POINT) return baseName + '_split_at_points';
    if (this.toolMode === GIS_TOOL_MODE_MERGE_LAYERS) {
      return baseName + '_merged';
    }
    if (this.toolMode === GIS_TOOL_MODE_MULTI_RING_BUFFER) {
      return baseName + '_rings';
    }
    if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_LOCATION) {
      return baseName + '_by_location';
    }
    if (this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN_SUMMARY) {
      return baseName + '_join_summary';
    }
    if (this.toolMode === GIS_TOOL_MODE_INTERSECTION) {
      return baseName + '_intersection';
    }
    if (this.toolMode === GIS_TOOL_MODE_NEAREST_NEIGHBOR) {
      return baseName + '_nearest';
    }
    if (this.toolMode === GIS_TOOL_MODE_VORONOI) {
      return baseName + '_voronoi';
    }
    if (this.toolMode === GIS_TOOL_MODE_TIN) return baseName + '_tin';
    if (this.toolMode === GIS_TOOL_MODE_TERRAIN_PROFILE) return baseName + '_profile';
    if (this.toolMode === GIS_TOOL_MODE_KERNEL_DENSITY) {
      return baseName + '_kernel_density';
    }
    if (this.toolMode === GIS_TOOL_MODE_POINT_DENSITY) {
      return baseName + '_point_density';
    }
    if (this.toolMode === GIS_TOOL_MODE_LINE_DENSITY) {
      return baseName + '_line_density';
    }
    if (this.toolMode === GIS_TOOL_MODE_IDW) {
      return baseName + '_idw';
    }
    if (this.toolMode === GIS_TOOL_MODE_RASTER_SLOPE) {
      return baseName + '_slope';
    }
    if (this.toolMode === GIS_TOOL_MODE_RASTER_ASPECT) {
      return baseName + '_aspect';
    }
    if (this.toolMode === GIS_TOOL_MODE_RASTER_RECLASSIFY) {
      return baseName + '_reclass';
    }
    if (this.toolMode === GIS_TOOL_MODE_CHM) return baseName + '_chm';
    if (this.toolMode === GIS_TOOL_MODE_EARTHWORK) return baseName + '_earthwork';
    if (this.toolMode === GIS_TOOL_MODE_SURFACE_AREA) return baseName + '_surface_area';
    if (this.toolMode === GIS_TOOL_MODE_LINE_OF_SIGHT) return baseName + '_line_of_sight';
    if (this.toolMode === GIS_TOOL_MODE_VIEWSHED) return baseName + '_viewshed';
    if (this.toolMode === GIS_TOOL_MODE_SKYLINE) return baseName + '_skyline';
    if (this.toolMode === GIS_TOOL_MODE_QUALITY_CHECK) {
      return baseName + '_quality_errors';
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
    } else if (source.toLowerCase().endsWith('.gpkg')) {
      source = source.substring(0, source.length - 5);
    } else if (source.toLowerCase().endsWith('.geojson')) {
      source = source.substring(0, source.length - 8);
    } else if (source.toLowerCase().endsWith('.json')) {
      source = source.substring(0, source.length - 5);
    } else if (source.toLowerCase().endsWith('.kml')) {
      source = source.substring(0, source.length - 4);
    } else if (source.toLowerCase().endsWith('.csv')) {
      source = source.substring(0, source.length - 4);
    } else if (source.toLowerCase().endsWith('.fgb')) {
      source = source.substring(0, source.length - 4);
    } else if (source.toLowerCase().endsWith('.asc')) {
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

  private exportDriverName(): string {
    let format = this.secondaryValue().trim().toLowerCase();
    if (format === 'gpkg' || format.indexOf('geopackage') >= 0 || format.indexOf('geo package') >= 0) {
      return 'GPKG';
    }
    if (format.indexOf('geojson') >= 0 || format === 'json') {
      return 'GeoJSON';
    }
    if (format === 'kml') {
      return 'KML';
    }
    if (format === 'csv') {
      return 'CSV';
    }
    if (format === 'fgb' || format.indexOf('flatgeobuf') >= 0) {
      return 'FlatGeobuf';
    }
    return 'ESRI Shapefile';
  }

  private exportExtension(): string {
    let driverName = this.exportDriverName();
    if (driverName === 'GPKG') {
      return '.gpkg';
    }
    if (driverName === 'GeoJSON') {
      return '.geojson';
    }
    if (driverName === 'KML') {
      return '.kml';
    }
    if (driverName === 'CSV') {
      return '.csv';
    }
    if (driverName === 'FlatGeobuf') {
      return '.fgb';
    }
    return '.shp';
  }

  private exportSuffixChoice(extension: string): string {
    if (extension === '.gpkg') {
      return 'GeoPackage|.gpkg';
    }
    if (extension === '.geojson') {
      return 'GeoJSON|.geojson';
    }
    if (extension === '.kml') {
      return 'KML|.kml';
    }
    if (extension === '.csv') {
      return 'CSV|.csv';
    }
    if (extension === '.fgb') {
      return 'FlatGeobuf|.fgb';
    }
    if (extension === '.asc') {
      return 'ESRI ASCII Grid|.asc';
    }
    return 'Shapefile 主文件|.shp';
  }

  private buildOutputPath(outputLayerName: string): string {
    let ctx = getContext(this);
    let outputDir = getGisService().processingOutputDirectory();
    if (outputDir.length === 0) {
      outputDir = ctx.filesDir + '/geonest_outputs';
    }
    try {
      fs.mkdirSync(outputDir, true);
    } catch (e) {
    }
    let extension = '.shp';
    if (this.toolMode === GIS_TOOL_MODE_EXPORT) {
      extension = this.exportExtension();
    } else if (this.isRasterOutputTool()) {
      extension = '.asc';
    }
    return outputDir + '/' + outputLayerName + extension;
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

  private asciiGridSidecars(): ShapefileSidecar[] {
    return [
      new ShapefileSidecar('.asc', 'ESRI ASCII Grid|.asc'),
      new ShapefileSidecar('.prj', '坐标系定义|.prj')
    ];
  }

  private outputBasePath(outputPath: string): string {
    if (outputPath.toLowerCase().endsWith('.shp')) {
      return outputPath.substring(0, outputPath.length - 4);
    }
    if (outputPath.toLowerCase().endsWith('.asc')) {
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

  private buildAsciiGridSaveOptions(outputPath: string, outputLayerName: string): picker.DocumentSaveOptions {
    let options = new picker.DocumentSaveOptions();
    let names: string[] = [];
    let suffixChoices: string[] = [];
    let basePath = this.outputBasePath(outputPath);
    let sidecars = this.asciiGridSidecars();
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

  private buildSingleFileSaveOptions(outputPath: string, outputLayerName: string): picker.DocumentSaveOptions {
    let options = new picker.DocumentSaveOptions();
    let extension = '';
    let dotIndex = outputPath.lastIndexOf('.');
    if (dotIndex >= 0 && dotIndex < outputPath.length - 1) {
      extension = outputPath.substring(dotIndex).toLowerCase();
    }
    if (extension.length === 0) {
      extension = '.dat';
    }
    options.newFileNames = [outputLayerName + extension];
    options.fileSuffixChoices = [this.exportSuffixChoice(extension)];
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

  private exportedAsciiGridFileCount(outputPath: string): number {
    let count = 0;
    let basePath = this.outputBasePath(outputPath);
    let sidecars = this.asciiGridSidecars();
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

  private saveExportedSingleFileToFiles(outputPath: string, outputLayerName: string): void {
    if (!this.sourceFileExists(outputPath)) {
      this.runStatus = '成果已生成，但未找到可保存的输出文件';
      return;
    }
    try {
      let options = this.buildSingleFileSaveOptions(outputPath, outputLayerName);
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      documentPicker.save(options).then((uris: Array<string>) => {
        if (uris.length === 0) {
          this.runStatus = '成果保留在应用输出目录，本地保存已取消';
          return;
        }
        if (this.copySourceToUri(outputPath, uris[0])) {
          this.runStatus = '完成：成果已生成，并已保存本地文件';
        }
      }).catch(() => {
        this.runStatus = '成果保留在应用输出目录，本地保存已取消';
      });
    } catch (e) {
      this.runStatus = '成果已生成，但无法打开本地保存器';
    }
  }

  private saveExportedResultToFiles(outputPath: string, outputLayerName: string): void {
    if (outputPath.toLowerCase().endsWith('.shp')) {
      this.saveExportedShapefileToFiles(outputPath, outputLayerName);
    } else if (outputPath.toLowerCase().endsWith('.asc')) {
      this.saveExportedAsciiGridToFiles(outputPath, outputLayerName);
    } else {
      this.saveExportedSingleFileToFiles(outputPath, outputLayerName);
    }
  }

  private saveExportedAsciiGridToFiles(outputPath: string, outputLayerName: string): void {
    let expectedCount = this.exportedAsciiGridFileCount(outputPath);
    if (expectedCount === 0) {
      this.runStatus = '栅格成果已生成，但未找到可保存的 ASCII Grid 文件组';
      return;
    }
    try {
      let options = this.buildAsciiGridSaveOptions(outputPath, outputLayerName);
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      documentPicker.save(options).then((uris: Array<string>) => {
        let basePath = this.outputBasePath(outputPath);
        let sidecars = this.asciiGridSidecars();
        let uriIndex = 0;
        let copiedCount = 0;
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
          }
          uriIndex++;
        }
        if (copiedCount === expectedCount) {
          this.runStatus = '完成：栅格成果已生成，并保存 ASCII Grid 文件组到本地';
        } else if (copiedCount > 0) {
          this.runStatus = '本地保存不完整：已保存 ' + copiedCount.toString() + '/' +
            expectedCount.toString() + ' 个 ASCII Grid 文件';
        } else {
          this.runStatus = '栅格成果已生成，但本地文件未写入';
        }
      }).catch(() => {
        this.runStatus = '完成：栅格成果保留在应用输出目录；已取消本地文件保存';
      });
    } catch (e) {
      this.runStatus = '栅格成果已生成，本地保存失败：' + String(e);
    }
  }

  private saveExportedShapefileToFiles(outputPath: string, outputLayerName: string): void {
    let expectedCount = this.exportedShapefileFileCount(outputPath);
    if (expectedCount === 0) {
      this.runStatus = '成果已生成，但未找到可保存的 Shapefile 文件组';
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
          this.runStatus = '完成：成果已生成，并保存 ' + copiedCount.toString() + '/' +
            expectedCount.toString() + ' 个 Shapefile 文件到本地（' + copiedExtensions + '）';
        } else if (copiedCount > 0) {
          this.runStatus = '本地保存不完整：已保存 ' + copiedCount.toString() + '/' +
            expectedCount.toString() + ' 个（' + copiedExtensions + '），应包含 ' + expectedExtensions;
        } else {
          this.runStatus = '成果已生成，但本地文件未写入；应保存 ' + expectedCount.toString() +
            ' 个文件（' + expectedExtensions + '）';
        }
      }).catch(() => {
        this.runStatus = '完成：成果保留在应用输出目录；已取消本地文件保存';
      });
    } catch (e) {
      this.runStatus = '成果已生成，本地保存失败：' + String(e);
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
    this.uiRevision++;
  }

  private refreshClipLayerChoice(layerName: string): void {
    this.clipName = layerName;
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
    if (fieldIndex === 3) {
      return this.tertiaryValue();
    }
    if (fieldIndex === 4) {
      return this.populationFieldValue();
    }
    if (fieldIndex === 5) {
      return this.areaUnitValue();
    }
    return this.outputValue();
  }

  private secondaryLayerIndex(service: GisService, inputIndex: number, actionName: string,
    allowSameLayer: boolean): number {
    let layerName = this.secondaryValue();
    let layerIndex = service.findLayerIndexByName(layerName);
    if (layerIndex < 0) {
      if (allowSameLayer) {
        layerIndex = inputIndex;
      } else {
        layerIndex = service.firstOtherLayerIndex(inputIndex);
      }
    }
    if (layerIndex < 0) {
      this.runStatus = actionName + '需要选择一个叠加图层';
      return -1;
    }
    if (!allowSameLayer && layerIndex === inputIndex) {
      this.runStatus = actionName + '需要另一个真实图层';
      return -1;
    }
    return layerIndex;
  }

  private predicateModeValue(): number {
    let mode = Number(this.tertiaryValue());
    if (mode !== mode || mode < 0 || mode > 6) {
      return -1;
    }
    return mode;
  }

  private densityProcessingText(cellSize: number, populationField: string, areaUnit: string): string {
    let cleanPopulationField: string = populationField.trim();
    if (cleanPopulationField.length === 0) {
      cleanPopulationField = 'NONE';
    }
    let cleanAreaUnit: string = areaUnit.trim();
    if (cleanAreaUnit.length === 0) {
      cleanAreaUnit = 'SQUARE_MAP_UNITS';
    }
    return 'cellSize=' + cellSize.toString() + ';populationField=' + cleanPopulationField +
      ';areaUnit=' + cleanAreaUnit;
  }

  private idwProcessingText(cellSize: number, valueField: string, power: string): string {
    let cleanValueField: string = valueField.trim();
    if (cleanValueField.length === 0) {
      cleanValueField = 'NONE';
    }
    let cleanPower: string = power.trim();
    if (cleanPower.length === 0) {
      cleanPower = '2';
    }
    return 'cellSize=' + cellSize.toString() + ';valueField=' + cleanValueField + ';power=' + cleanPower;
  }

  private notifyProcessingIntegrations(snapshot: GisProcessingTaskSnapshot, force: boolean = false): void {
    let ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    ProcessingNotificationManager.getInstance().notifySnapshot(ctx, snapshot, this.toolTitle(), force);
    let progressBucket: number = Math.floor(Math.max(0, Math.min(100, snapshot.progress)) / 10) * 10;
    let shouldUpdateWidget: boolean = force || snapshot.done || snapshot.taskId !== this.lastWidgetTaskId ||
      snapshot.state !== this.lastWidgetTaskState || progressBucket !== this.lastWidgetProgressBucket;
    if (!shouldUpdateWidget) {
      return;
    }
    this.lastWidgetTaskId = snapshot.taskId;
    this.lastWidgetProgressBucket = progressBucket;
    this.lastWidgetTaskState = snapshot.state;
    GeoNestFormStateStore.getInstance().updateProcessingStatus(ctx.filesDir,
      this.widgetProcessingStatus(snapshot));
  }

  private widgetProcessingStatus(snapshot: GisProcessingTaskSnapshot): string {
    let progress: number = Math.max(0, Math.min(100, Math.floor(snapshot.progress)));
    if (snapshot.cancelRequested || snapshot.state === GIS_PROCESSING_TASK_CANCEL_REQUESTED) {
      return this.toolTitle() + ' · 正在取消 · ' + progress.toString() + '%';
    }
    if (snapshot.state === GIS_PROCESSING_TASK_QUEUED) {
      return this.toolTitle() + ' · 排队中';
    }
    if (snapshot.state === GIS_PROCESSING_TASK_SUCCEEDED) {
      return this.toolTitle() + ' · 已完成';
    }
    if (snapshot.state === GIS_PROCESSING_TASK_CANCELED) {
      return this.toolTitle() + ' · 已取消';
    }
    if (snapshot.state === GIS_PROCESSING_TASK_FAILED) {
      return this.toolTitle() + ' · 失败';
    }
    let stageText: string = snapshot.stage.length > 0 ? snapshot.stage : '正在处理';
    return this.toolTitle() + ' · ' + stageText + ' · ' + progress.toString() + '%';
  }

  private updateTaskPresentation(snapshot: GisProcessingTaskSnapshot): void {
    this.taskProgress = Math.max(0, Math.min(100, snapshot.progress));
    this.taskStage = snapshot.stage;
    this.taskState = snapshot.state;
    this.taskRunning = !snapshot.done;
    this.notifyProcessingIntegrations(snapshot, false);
    if (!snapshot.done) {
      if (snapshot.cancelRequested || snapshot.state === GIS_PROCESSING_TASK_CANCEL_REQUESTED) {
        this.runStatus = '正在取消后台任务…';
      } else if (snapshot.state === GIS_PROCESSING_TASK_QUEUED) {
        this.runStatus = '已加入后台处理队列';
      } else {
        this.runStatus = '正在后台处理，可关闭此窗口继续使用地图';
      }
    }
  }

  private handleToolResult(result: GisGeoProcessResult): void {
    let service: GisService = getGisService();
    if (result.ok) {
      let outputLoaded: boolean = result.outputLoaded;
      let completedLayerIndex: number = outputLoaded ? service.getActiveLayerIndex() : -1;
      let rasterOutput: boolean = this.isRasterOutputMode(this.pendingToolMode);
      if (rasterOutput && outputLoaded) {
        this.runStatus = '完成：栅格已加载结果图层 · ' + result.elapsedMs.toString() + ' ms';
      } else if (rasterOutput) {
        this.runStatus = '完成：栅格已生成，未加载到地图 · ' + result.elapsedMs.toString() + ' ms · ' +
          result.message;
      } else if (outputLoaded) {
        this.runStatus = '完成：输出 ' + result.featureCount.toString() + ' 个要素，已加载结果图层 · ' +
          result.elapsedMs.toString() + ' ms';
      } else {
        this.runStatus = '完成：输出 ' + result.featureCount.toString() + ' 个要素，未加载到地图 · ' +
          result.elapsedMs.toString() + ' ms · ' + result.message;
      }
      if (outputLoaded) {
        this.onToolCompleted();
      }
      if (this.pendingToolMode === GIS_TOOL_MODE_QUALITY_CHECK && completedLayerIndex >= 0) {
        this.onQualityCheckCompleted(this.pendingInputIndex, completedLayerIndex, this.pendingQualityFields);
      }
      if (this.shouldOfferLocalSaveForMode(this.pendingToolMode)) {
        if (rasterOutput) {
          this.runStatus = '完成：栅格已生成，正在选择本地保存位置';
        } else {
          this.runStatus = '完成：输出 ' + result.featureCount.toString() + ' 个要素，正在选择本地保存位置';
        }
        this.saveExportedResultToFiles(result.outputPath, this.pendingOutputLayerName);
      }
    } else if (result.code === 8) {
      this.runStatus = '已取消：未完成的临时成果已清理';
    } else {
      this.runStatus = '失败：' + result.message;
    }
  }

  private completeProcessingTask(snapshot: GisProcessingTaskSnapshot): void {
    if (!snapshot.done || this.taskCompletionHandled) {
      return;
    }
    this.taskCompletionHandled = true;
    this.taskRunning = false;
    this.activeTaskId = '';
    this.updateTaskPresentation(snapshot);
    if (snapshot.result !== null) {
      this.handleToolResult(snapshot.result);
    } else if (snapshot.state === GIS_PROCESSING_TASK_CANCELED) {
      this.runStatus = '已取消：未完成的临时成果已清理';
    } else {
      this.runStatus = '失败：' + snapshot.message;
    }
  }

  private onProcessingTaskRevisionChanged(): void {
    if (this.activeTaskId.length === 0) {
      return;
    }
    let snapshot: GisProcessingTaskSnapshot | undefined =
      getGisService().processingTask(this.activeTaskId);
    if (snapshot === undefined) {
      return;
    }
    this.updateTaskPresentation(snapshot);
    if (snapshot.done) {
      this.completeProcessingTask(snapshot);
    }
  }

  private cancelActiveTask(): void {
    if (!this.taskRunning || this.activeTaskId.length === 0) {
      return;
    }
    let ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    ProcessingNotificationManager.getInstance().notifyCancelRequested(ctx, this.activeTaskId, this.toolTitle());
    let snapshot: GisProcessingTaskSnapshot | undefined =
      getGisService().cancelProcessingTask(this.activeTaskId);
    if (snapshot === undefined) {
      this.runStatus = '取消失败：任务状态不存在';
      return;
    }
    this.updateTaskPresentation(snapshot);
    if (snapshot.done) {
      this.completeProcessingTask(snapshot);
    }
  }

  private runTool(): void {
    if (this.taskRunning) {
      this.runStatus = '已有后台任务正在运行，请先等待或取消';
      return;
    }
    let service: GisService = getGisService();
    let inputIndex: number = this.inputLayerIndex();
    if (service.getLayer(inputIndex) === undefined || inputIndex < 0) {
      this.runStatus = '未选择图层，无法运行';
      return;
    }
    let outputLayerName: string = this.safeOutputLayerName();
    let outputPath: string = this.buildOutputPath(outputLayerName);
    let algorithmId: string = 'clip';
    let overlayIndex: number = -1;
    let numericValue: number = 0;
    let textValue: string = '';

    if (this.isAdvancedSpatialTool()) {
      algorithmId = advancedSpatialAlgorithmId(this.toolMode);
      numericValue = Number(this.secondaryValue());
      if (numericValue !== numericValue || numericValue < 0) {
        this.runStatus = '邻居数、距离或带宽不能小于 0';
        return;
      }
      textValue = this.tertiaryValue().trim();
    } else if (this.toolMode === GIS_TOOL_MODE_BUFFER) {
      let distance: number = Number(this.secondaryValue());
      if (distance !== distance || distance <= 0) {
        this.runStatus = '请输入大于 0 的缓冲距离；单位为当前图层坐标单位';
        return;
      }
      algorithmId = 'buffer';
      numericValue = distance;
    } else if (this.toolMode === GIS_TOOL_MODE_REPAIR) {
      algorithmId = 'repair';
    } else if (this.toolMode === GIS_TOOL_MODE_EXPORT) {
      let driverName: string = this.exportDriverName();
      if (driverName === 'ESRI Shapefile') {
        algorithmId = 'export';
      } else {
        algorithmId = 'export_format';
        textValue = driverName;
      }
    } else if (this.toolMode === GIS_TOOL_MODE_SIMPLIFY) {
      let tolerance: number = Number(this.secondaryValue());
      if (tolerance !== tolerance || tolerance <= 0) {
        this.runStatus = '请输入大于 0 的简化容差；单位为当前图层坐标单位';
        return;
      }
      algorithmId = 'simplify';
      numericValue = tolerance;
    } else if (this.toolMode === GIS_TOOL_MODE_DISSOLVE) {
      algorithmId = 'dissolve';
    } else if (this.toolMode === GIS_TOOL_MODE_CENTROID) {
      algorithmId = 'centroid';
    } else if (this.toolMode === GIS_TOOL_MODE_CONVEX_HULL) {
      algorithmId = 'convex_hull';
    } else if (this.toolMode === GIS_TOOL_MODE_BOUNDING_BOXES) {
      algorithmId = 'bounding_boxes';
    } else if (this.toolMode === GIS_TOOL_MODE_ORIENTED_MINIMUM_BOUNDING_BOX) {
      algorithmId = 'oriented_minimum_bounding_box';
    } else if (this.toolMode === GIS_TOOL_MODE_MULTIPART_TO_SINGLEPARTS) {
      algorithmId = 'multipart_to_singleparts';
    } else if (this.toolMode === GIS_TOOL_MODE_FEATURE_TO_POINT) {
      algorithmId = 'feature_to_point';
      numericValue = this.secondaryValue().trim() === '0' ? 0 : 1;
    } else if (this.toolMode === GIS_TOOL_MODE_POLYGON_TO_LINE) {
      algorithmId = 'polygon_to_line';
    } else if (this.toolMode === GIS_TOOL_MODE_FEATURE_TO_POLYGON) {
      algorithmId = 'feature_to_polygon';
    } else if (this.toolMode === GIS_TOOL_MODE_VERTICES_TO_POINTS) {
      algorithmId = 'vertices_to_points';
    } else if (this.toolMode === GIS_TOOL_MODE_POINTS_TO_LINE) {
      algorithmId = 'points_to_line';
      textValue = this.secondaryValue().trim();
    } else if (this.toolMode === GIS_TOOL_MODE_DENSIFY) {
      let densifyDistance: number = Number(this.secondaryValue());
      if (densifyDistance !== densifyDistance || densifyDistance <= 0) {
        this.runStatus = '请输入大于 0 的最大节点间距';
        return;
      }
      algorithmId = 'densify';
      numericValue = densifyDistance;
    } else if (this.toolMode === GIS_TOOL_MODE_SMOOTH) {
      let smoothIterations: number = Number(this.secondaryValue());
      if (smoothIterations !== smoothIterations || smoothIterations < 1) {
        this.runStatus = '请输入大于等于 1 的平滑迭代次数';
        return;
      }
      algorithmId = 'smooth';
      numericValue = smoothIterations;
      textValue = '0.25';
    } else if (this.toolMode === GIS_TOOL_MODE_REMOVE_HOLES) {
      let minimumHoleArea: number = Number(this.secondaryValue());
      if (minimumHoleArea !== minimumHoleArea || minimumHoleArea < 0) {
        this.runStatus = '最小保留洞面积不能小于 0';
        return;
      }
      algorithmId = 'remove_holes';
      numericValue = minimumHoleArea;
    } else if (this.toolMode === GIS_TOOL_MODE_SELECT || this.toolMode === GIS_TOOL_MODE_TABLE_SELECT) {
      let selectExpression: string = this.secondaryValue().trim();
      if (selectExpression.length === 0) {
        this.runStatus = '请输入筛选表达式';
        return;
      }
      algorithmId = this.toolMode === GIS_TOOL_MODE_SELECT ? 'select' : 'table_select';
      textValue = selectExpression;
    } else if (this.toolMode === GIS_TOOL_MODE_SPLIT) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '按叠加要素分割', false);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'split';
    } else if (this.toolMode === GIS_TOOL_MODE_SPLIT_BY_ATTRIBUTES) {
      let splitField: string = this.secondaryValue().trim();
      if (splitField.length === 0 || splitField === '请填写字段名') {
        this.runStatus = '请输入有效的拆分字段名';
        return;
      }
      algorithmId = 'split_by_attributes';
      textValue = splitField;
    } else if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_EXTENT) {
      algorithmId = 'extract_by_extent';
      textValue = this.secondaryValue().trim();
    } else if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_TIME) {
      algorithmId = 'extract_by_time';
      textValue = this.secondaryValue().trim();
    } else if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_MASK) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '按掩膜提取', false);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'extract_by_mask';
    } else if (this.toolMode === GIS_TOOL_MODE_TABULATE_INTERSECTION) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '交集制表', false);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'tabulate_intersection';
    } else if (this.toolMode === GIS_TOOL_MODE_SUMMARIZE_WITHIN) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '范围内汇总', false);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'summarize_within';
      textValue = this.tertiaryValue().trim();
    } else if (this.toolMode >= GIS_TOOL_MODE_NEAR &&
      this.toolMode <= GIS_TOOL_MODE_SHORTEST_CONNECTION) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '邻近目标', true);
      if (overlayIndex < 0) {
        return;
      }
      if (this.toolMode === GIS_TOOL_MODE_NEAR) {
        algorithmId = 'near';
      } else if (this.toolMode === GIS_TOOL_MODE_SHORTEST_CONNECTION) {
        algorithmId = 'shortest_connection';
      } else {
        let nearOptions: string[] = this.tertiaryValue().trim().split(';');
        let nearCount: number = Number(nearOptions[0]);
        let nearDistance: string = nearOptions.length > 1 ? nearOptions[1] : '0';
        if (nearCount !== nearCount || nearCount < 0) {
          this.runStatus = 'K 邻近数必须是大于等于 0 的整数';
          return;
        }
        numericValue = nearCount;
        textValue = nearDistance;
        if (this.toolMode === GIS_TOOL_MODE_GENERATE_NEAR_TABLE) {
          algorithmId = 'generate_near_table';
        } else if (this.toolMode === GIS_TOOL_MODE_POINT_DISTANCE) {
          algorithmId = 'point_distance';
        } else {
          algorithmId = 'distance_matrix';
        }
      }
    } else if (this.toolMode >= GIS_TOOL_MODE_SUMMARY_STATISTICS &&
      this.toolMode <= GIS_TOOL_MODE_STATISTICS_CHART) {
      textValue = this.secondaryValue().trim();
      if (this.toolMode === GIS_TOOL_MODE_SUMMARY_STATISTICS) {
        algorithmId = 'summary_statistics';
      } else if (this.toolMode === GIS_TOOL_MODE_FREQUENCY) {
        algorithmId = 'frequency';
      } else if (this.toolMode === GIS_TOOL_MODE_UNIQUE_VALUES) {
        algorithmId = 'unique_values';
      } else if (this.toolMode === GIS_TOOL_MODE_GROUP_STATISTICS) {
        algorithmId = 'group_statistics';
      } else if (this.toolMode === GIS_TOOL_MODE_CROSSTAB_PIVOT) {
        algorithmId = 'crosstab_pivot';
      } else {
        algorithmId = 'statistics_chart';
      }
    } else if (this.toolMode === GIS_TOOL_MODE_POLYGON_NEIGHBORS) {
      algorithmId = 'polygon_neighbors';
    } else if (this.toolMode === GIS_TOOL_MODE_SNAP_OUTPUT || this.toolMode === GIS_TOOL_MODE_INTEGRATE) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '捕捉目标', true);
      if (overlayIndex < 0) return;
      let snapTolerance: number = Number(this.tertiaryValue());
      if (snapTolerance !== snapTolerance || snapTolerance <= 0) {
        this.runStatus = '捕捉容差必须大于 0';
        return;
      }
      algorithmId = this.toolMode === GIS_TOOL_MODE_SNAP_OUTPUT ? 'snap' : 'integrate';
      numericValue = snapTolerance;
    } else if (this.toolMode === GIS_TOOL_MODE_EXTEND_TRIM_LINE) {
      algorithmId = 'extend_trim_line';
      numericValue = Number(this.secondaryValue());
      textValue = this.tertiaryValue().trim();
    } else if (this.toolMode === GIS_TOOL_MODE_AGGREGATE_POLYGONS) {
      algorithmId = 'aggregate_polygons';
      numericValue = Number(this.secondaryValue());
    } else if (this.toolMode === GIS_TOOL_MODE_ELIMINATE) {
      algorithmId = 'eliminate';
      numericValue = Number(this.secondaryValue());
      if (numericValue !== numericValue || numericValue <= 0) {
        this.runStatus = '消除面积阈值必须大于 0';
        return;
      }
    } else if (this.toolMode === GIS_TOOL_MODE_REMOVE_FRAGMENTS) {
      algorithmId = 'remove_fragments';
      numericValue = Number(this.secondaryValue());
    } else if (this.toolMode === GIS_TOOL_MODE_UNIFY_DIRECTION) {
      algorithmId = 'unify_direction';
    } else if (this.toolMode === GIS_TOOL_MODE_CENTERLINE) {
      algorithmId = 'centerline';
    } else if (this.toolMode >= GIS_TOOL_MODE_FISHNET && this.toolMode <= GIS_TOOL_MODE_REGULAR_POINTS) {
      numericValue = Number(this.secondaryValue());
      if (numericValue !== numericValue || numericValue <= 0) {
        this.runStatus = '网格间距或点数量必须大于 0';
        return;
      }
      if (this.toolMode === GIS_TOOL_MODE_FISHNET) algorithmId = 'fishnet';
      else if (this.toolMode === GIS_TOOL_MODE_HEXAGON_GRID) algorithmId = 'hexagon_grid';
      else if (this.toolMode === GIS_TOOL_MODE_RANDOM_POINTS) {
        algorithmId = 'random_points';
        textValue = this.tertiaryValue().trim();
      } else algorithmId = 'regular_points';
    } else if (this.toolMode === GIS_TOOL_MODE_ADVANCED_BUFFER) {
      let advancedDistance: number = Number(this.secondaryValue());
      if (advancedDistance !== advancedDistance || advancedDistance < 0) {
        this.runStatus = '默认缓冲距离不能小于 0';
        return;
      }
      algorithmId = 'advanced_buffer';
      numericValue = advancedDistance;
      textValue = this.tertiaryValue().trim();
    } else if (this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '空间连接', false);
      if (overlayIndex < 0) return;
      algorithmId = 'spatial_join';
      textValue = this.tertiaryValue().trim();
    } else if (this.toolMode === GIS_TOOL_MODE_ADVANCED_CLIP) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '高级裁剪', false);
      if (overlayIndex < 0) return;
      let clipTolerance: number = Number(this.tertiaryValue());
      if (clipTolerance !== clipTolerance || clipTolerance < 0) {
        this.runStatus = '安全容差不能小于 0';
        return;
      }
      algorithmId = 'advanced_clip';
      numericValue = clipTolerance;
    } else if (this.toolMode === GIS_TOOL_MODE_SPLIT_LINE_AT_POINT) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '分割点图层', false);
      if (overlayIndex < 0) return;
      let splitTolerance: number = Number(this.tertiaryValue());
      if (splitTolerance !== splitTolerance || splitTolerance < 0) {
        this.runStatus = '分割容差不能小于 0';
        return;
      }
      algorithmId = 'split_line_at_point';
      numericValue = splitTolerance;
    } else if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_EXPRESSION) {
      let expression: string = this.secondaryValue().trim();
      if (expression.length === 0) {
        this.runStatus = '请输入 QGIS 表达式';
        return;
      }
      algorithmId = 'extract_by_expression';
      textValue = expression;
    } else if (this.toolMode === GIS_TOOL_MODE_DIFFERENCE) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '差集', false);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'difference';
    } else if (this.toolMode === GIS_TOOL_MODE_SYMMETRICAL_DIFFERENCE) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '对称差集', false);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'symmetrical_difference';
    } else if (this.toolMode === GIS_TOOL_MODE_UNION) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '联合', false);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'union';
    } else if (this.toolMode === GIS_TOOL_MODE_IDENTITY) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '标识叠加', false);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'identity';
    } else if (this.toolMode === GIS_TOOL_MODE_UPDATE) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '更新叠加', false);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'update';
    } else if (this.toolMode === GIS_TOOL_MODE_MERGE_LAYERS) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '合并图层', false);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'merge_layers';
    } else if (this.toolMode === GIS_TOOL_MODE_MULTI_RING_BUFFER) {
      let distanceList: string = this.secondaryValue().trim();
      if (distanceList.length === 0) {
        this.runStatus = '请输入逗号分隔的多环缓冲距离，例如 100,500,1000';
        return;
      }
      algorithmId = 'multi_ring_buffer';
      textValue = distanceList;
    } else if (this.toolMode === GIS_TOOL_MODE_EXTRACT_BY_LOCATION) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '按位置提取', false);
      if (overlayIndex < 0) {
        return;
      }
      let predicateMode: number = this.predicateModeValue();
      if (predicateMode < 0) {
        this.runStatus = '空间谓词模式请输入 0-6：0 相交、1 包含、2 位于、3 接触、4 重叠、5 穿越、6 不相交';
        return;
      }
      algorithmId = 'extract_by_location';
      numericValue = predicateMode;
    } else if (this.toolMode === GIS_TOOL_MODE_SPATIAL_JOIN_SUMMARY) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '空间连接汇总', false);
      if (overlayIndex < 0) {
        return;
      }
      let predicateMode: number = this.predicateModeValue();
      if (predicateMode < 0) {
        this.runStatus = '空间谓词模式请输入 0-6：0 相交、1 包含、2 位于、3 接触、4 重叠、5 穿越、6 不相交';
        return;
      }
      algorithmId = 'spatial_join_summary';
      numericValue = predicateMode;
    } else if (this.toolMode === GIS_TOOL_MODE_INTERSECTION) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '相交', false);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'intersection';
    } else if (this.toolMode === GIS_TOOL_MODE_NEAREST_NEIGHBOR) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '最近邻', true);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'nearest_neighbor';
    } else if (this.toolMode === GIS_TOOL_MODE_VORONOI) {
      let tolerance: number = Number(this.secondaryValue());
      if (tolerance !== tolerance || tolerance < 0) {
        this.runStatus = '请输入大于或等于 0 的泰森多边形容差';
        return;
      }
      algorithmId = 'voronoi';
      numericValue = tolerance;
    } else if (this.toolMode === GIS_TOOL_MODE_KERNEL_DENSITY ||
      this.toolMode === GIS_TOOL_MODE_POINT_DENSITY ||
      this.toolMode === GIS_TOOL_MODE_LINE_DENSITY) {
      let searchRadius: number = Number(this.secondaryValue());
      if (searchRadius !== searchRadius || searchRadius < 0) {
        this.runStatus = '搜索半径请输入大于或等于 0 的数值；0 表示自动估算';
        return;
      }
      let cellSize: number = Number(this.tertiaryValue());
      if (cellSize !== cellSize || cellSize < 0) {
        this.runStatus = '像元大小请输入大于或等于 0 的数值；0 表示自动估算';
        return;
      }
      if (this.toolMode === GIS_TOOL_MODE_KERNEL_DENSITY) {
        algorithmId = 'kernel_density';
      } else if (this.toolMode === GIS_TOOL_MODE_POINT_DENSITY) {
        algorithmId = 'point_density';
      } else {
        algorithmId = 'line_density';
      }
      numericValue = searchRadius;
      textValue = this.densityProcessingText(cellSize, this.populationFieldValue(), this.areaUnitValue());
    } else if (this.toolMode === GIS_TOOL_MODE_IDW) {
      let searchRadius: number = Number(this.secondaryValue());
      if (searchRadius !== searchRadius || searchRadius < 0) {
        this.runStatus = '搜索半径请输入大于或等于 0 的数值；0 表示使用全部采样点';
        return;
      }
      let cellSize: number = Number(this.tertiaryValue());
      if (cellSize !== cellSize || cellSize < 0) {
        this.runStatus = '像元大小请输入大于或等于 0 的数值；0 表示自动估算';
        return;
      }
      let powerValue: number = Number(this.areaUnitValue());
      if (powerValue !== powerValue || powerValue <= 0) {
        this.runStatus = 'Power 幂次请输入大于 0 的数值';
        return;
      }
      algorithmId = 'idw';
      numericValue = searchRadius;
      textValue = this.idwProcessingText(cellSize, this.populationFieldValue(), this.areaUnitValue());
    } else if (this.toolMode === GIS_TOOL_MODE_RASTER_SLOPE ||
      this.toolMode === GIS_TOOL_MODE_RASTER_ASPECT) {
      let zFactor: number = Number(this.secondaryValue());
      if (zFactor !== zFactor || zFactor <= 0) {
        this.runStatus = 'Z 因子请输入大于 0 的数值';
        return;
      }
      algorithmId = this.toolMode === GIS_TOOL_MODE_RASTER_SLOPE ? 'raster_slope' : 'raster_aspect';
      numericValue = zFactor;
    } else if (this.toolMode === GIS_TOOL_MODE_TIN) {
      let tinTolerance: number = Number(this.secondaryValue());
      if (tinTolerance !== tinTolerance || tinTolerance < 0) {
        this.runStatus = '三角剖分容差必须大于或等于 0';
        return;
      }
      algorithmId = 'tin';
      numericValue = tinTolerance;
    } else if (this.toolMode === GIS_TOOL_MODE_TERRAIN_PROFILE) {
      let profileSamples: number = Number(this.tertiaryValue());
      if (profileSamples !== profileSamples || profileSamples < 0) {
        this.runStatus = '采样点数必须大于或等于 0；0 表示按像元大小自动计算';
        return;
      }
      algorithmId = 'terrain_profile';
      numericValue = profileSamples;
      textValue = this.secondaryValue().trim();
    } else if (this.toolMode === GIS_TOOL_MODE_LINE_OF_SIGHT) {
      algorithmId = 'line_of_sight';
      textValue = this.secondaryValue().trim();
    } else if (this.toolMode === GIS_TOOL_MODE_VIEWSHED) {
      algorithmId = 'viewshed';
      textValue = this.secondaryValue().trim();
    } else if (this.toolMode === GIS_TOOL_MODE_SKYLINE) {
      algorithmId = 'skyline';
      textValue = this.secondaryValue().trim();
    } else if (this.toolMode === GIS_TOOL_MODE_RASTER_RECLASSIFY) {
      let reclassRules: string = this.secondaryValue().trim();
      if (reclassRules.length === 0) {
        this.runStatus = '请输入重分类规则，例如 0:10=1;10:30=2;30:*=3';
        return;
      }
      algorithmId = 'raster_reclassify';
      textValue = reclassRules;
    } else if (this.toolMode === GIS_TOOL_MODE_CHM) {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '冠层高度模型', false);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'chm';
    } else if (this.toolMode === GIS_TOOL_MODE_EARTHWORK) {
      let referenceElevation: number = Number(this.secondaryValue());
      if (referenceElevation !== referenceElevation) {
        this.runStatus = '设计基准高程必须是有效数值';
        return;
      }
      algorithmId = 'earthwork';
      numericValue = referenceElevation;
    } else if (this.toolMode === GIS_TOOL_MODE_SURFACE_AREA) {
      algorithmId = 'surface_area';
    } else if (this.toolMode === GIS_TOOL_MODE_QUALITY_CHECK) {
      algorithmId = 'quality_check';
      textValue = this.secondaryValue().trim();
    } else if (this.toolMode === GIS_TOOL_MODE_DEFINE_PROJECTION ||
      this.toolMode === GIS_TOOL_MODE_PROJECT_LAYER) {
      let targetDefinition: string = this.secondaryValue().trim();
      if (targetDefinition.length === 0) {
        this.runStatus = '请输入目标坐标系，例如 EPSG:4490';
        return;
      }
      let targetInfo: GisCrsInfo = service.describeCoordinateReferenceSystem(targetDefinition);
      if (!targetInfo.ok || !targetInfo.isValid) {
        this.runStatus = '目标坐标系无法识别，请输入 EPSG、WKT 或 PROJ 定义';
        return;
      }
      algorithmId = this.toolMode === GIS_TOOL_MODE_DEFINE_PROJECTION ? 'define_projection' : 'project';
      textValue = targetDefinition;
    } else {
      overlayIndex = this.secondaryLayerIndex(service, inputIndex, '裁剪', false);
      if (overlayIndex < 0) {
        return;
      }
      algorithmId = 'clip';
    }

    this.pendingInputIndex = inputIndex;
    this.pendingOutputLayerName = outputLayerName;
    this.pendingToolMode = this.toolMode;
    this.pendingQualityFields = this.toolMode === GIS_TOOL_MODE_QUALITY_CHECK ? textValue : '';
    this.taskCompletionHandled = false;
    this.taskProgress = 0;
    this.taskStage = 'queued';
    this.taskState = GIS_PROCESSING_TASK_QUEUED;
    this.runStatus = '正在提交后台任务…';

    let request: GisProcessingTaskRequest = new GisProcessingTaskRequest(algorithmId, inputIndex,
      overlayIndex, numericValue, textValue, outputPath, outputLayerName);
    let snapshot: GisProcessingTaskSnapshot = service.startProcessingAlgorithmTask(request);
    this.activeTaskId = snapshot.done ? '' : snapshot.taskId;
    this.updateTaskPresentation(snapshot);
    if (snapshot.done) {
      this.completeProcessingTask(snapshot);
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
        TextInput({ text: value })
          .height(38)
          .fontSize(14)
          .backgroundColor($r('app.color.gn_pane'))
          .layoutWeight(1)
          .onChange((textValue: string) => {
            if (fieldIndex === 0) {
              this.inputName = textValue;
            } else if (fieldIndex === 1) {
              this.clipName = textValue;
            } else if (fieldIndex === 3) {
              this.parameterName = textValue;
            } else if (fieldIndex === 4) {
              this.populationFieldName = textValue;
            } else if (fieldIndex === 5) {
              this.areaUnitName = textValue;
            } else {
              this.outputName = textValue;
            }
            this.uiRevision++;
          })
        if (fieldIndex === 0 || (fieldIndex === 1 && this.requiresLayerSecondaryInput())) {
          this.layerPickButton(fieldIndex)
        }
        if (this.toolMode === GIS_TOOL_MODE_CLIP && (fieldIndex === 0 || fieldIndex === 1)) {
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
  processingStageLabel() {
    if (this.taskState === GIS_PROCESSING_TASK_CANCEL_REQUESTED) {
      Text($r('app.string.gn_processing_task_canceling'))
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
    } else if (this.taskStage === 'prepare') {
      Text($r('app.string.gn_processing_stage_prepare'))
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
    } else if (this.taskStage === 'read') {
      Text($r('app.string.gn_processing_stage_read'))
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
    } else if (this.taskStage === 'compute') {
      Text($r('app.string.gn_processing_stage_compute'))
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
    } else if (this.taskStage === 'write') {
      Text($r('app.string.gn_processing_stage_write'))
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
    } else if (this.taskStage === 'finalize') {
      Text($r('app.string.gn_processing_stage_finalize'))
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
    } else if (this.taskStage === 'complete') {
      Text($r('app.string.gn_processing_stage_complete'))
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
    } else {
      Text($r('app.string.gn_processing_stage_queued'))
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
    }
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
        if (this.toolMode === GIS_TOOL_MODE_QUALITY_CHECK) {
          Text($r('app.string.gn_quality_check_fields_hint'))
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (this.requiresTertiaryInput()) {
          this.inputField(this.tertiaryLabel(), this.tertiaryValue(), 3)
          if (this.isDensityRasterTool()) {
            this.inputField('Population 字段', this.populationFieldValue(), 4)
            this.inputField('面积单位', this.areaUnitValue(), 5)
            Text('0 表示自动；Population 字段填 NONE 表示每个要素权重为 1；面积单位支持 SQUARE_MAP_UNITS、SQUARE_METERS、SQUARE_KILOMETERS、HECTARES、SQUARE_MILES、ACRES')
              .fontSize(12)
              .fontColor($r('app.color.gn_text_muted'))
              .width('100%')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else if (this.toolMode === GIS_TOOL_MODE_IDW) {
            this.inputField('Z 值字段', this.populationFieldValue(), 4)
            this.inputField('Power 幂次', this.areaUnitValue(), 5)
            Text('搜索半径 0 表示使用全部采样点；像元大小 0 表示自动；Z 值字段必须是数值字段')
              .fontSize(12)
              .fontColor($r('app.color.gn_text_muted'))
              .width('100%')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else {
            Text('0 相交 · 1 包含 · 2 位于 · 3 接触 · 4 重叠 · 5 穿越 · 6 不相交')
              .fontSize(12)
              .fontColor($r('app.color.gn_text_muted'))
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
      }
      this.inputField('输出图层', this.outputValue(), 2)

      Text('状态：' + this.runStatus)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')

      if (this.taskRunning) {
        Column({ space: 8 }) {
          Row() {
            Text($r('app.string.gn_processing_background_active'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.gn_text_primary'))
            Blank()
            Text(Math.floor(this.taskProgress).toString() + '%')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.gn_blue_800'))
          }
          .width('100%')
          this.processingStageLabel()
          Text($r('app.string.gn_processing_background_hint'))
            .fontSize(11)
            .fontColor($r('app.color.gn_text_muted'))
            .width('100%')
          if (this.taskState === GIS_PROCESSING_TASK_CANCEL_REQUESTED) {
            Button($r('app.string.gn_processing_task_canceling'), { type: ButtonType.Capsule })
              .width('100%')
              .height(34)
              .enabled(false)
          } else {
            Button($r('app.string.gn_processing_cancel_task'), { type: ButtonType.Capsule, stateEffect: true })
              .width('100%')
              .height(34)
              .fontColor($r('app.color.gn_blue_800'))
              .backgroundColor($r('app.color.gn_blue_100'))
              .onClick(() => {
                this.cancelActiveTask();
              })
          }
        }
        .padding(10)
        .borderRadius(6)
        .backgroundColor($r('app.color.gn_pane'))
        .width('100%')
      }

      Button($r('app.string.gn_run'), { type: ButtonType.Capsule, stateEffect: true })
        .width('100%')
        .height(40)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.gn_blue_800'))
        .margin({ top: 2 })
        .enabled(!this.taskRunning)
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
            Text((this.uiRevision + this.processingTaskRevision).toString())
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
