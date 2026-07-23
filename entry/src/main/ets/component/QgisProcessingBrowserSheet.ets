import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '@geonest/common';
import { getGisService } from '../gis/GisService';
import {
  GIS_PROCESSING_TASK_CANCEL_REQUESTED,
  GIS_PROCESSING_TASK_QUEUED,
  GIS_PROCESSING_TASK_RUNNING,
  GisProcessingAlgorithm,
  GisProcessingCatalog,
  GisProcessingTaskSnapshot
} from '../model/GeoNestModels';
import {
  PROCESSING_TASK_REVISION_KEY,
  PROCESSING_TASK_STATUS_CANCELED,
  PROCESSING_TASK_STATUS_FAILED,
  PROCESSING_TASK_STATUS_SUCCEEDED,
  ProcessingTaskRecord
} from '../utils/ProcessingHistoryManager';
import {
  GIS_TOOL_MODE_CLIP,
  GIS_TOOL_MODE_BUFFER,
  GIS_TOOL_MODE_REPAIR,
  GIS_TOOL_MODE_EXPORT,
  GIS_TOOL_MODE_DEFINE_PROJECTION,
  GIS_TOOL_MODE_PROJECT_LAYER,
  GIS_TOOL_MODE_SIMPLIFY,
  GIS_TOOL_MODE_DISSOLVE,
  GIS_TOOL_MODE_CENTROID,
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
  GIS_TOOL_MODE_CHM,
  GIS_TOOL_MODE_EARTHWORK,
  GIS_TOOL_MODE_SURFACE_AREA,
  GIS_TOOL_MODE_TIN,
  GIS_TOOL_MODE_TERRAIN_PROFILE,
  GIS_TOOL_MODE_LINE_OF_SIGHT,
  GIS_TOOL_MODE_VIEWSHED,
  GIS_TOOL_MODE_SKYLINE,
  GIS_TOOL_MODE_QUALITY_CHECK,
  GIS_TOOL_MODE_UNION,
  GIS_TOOL_MODE_IDENTITY,
  GIS_TOOL_MODE_UPDATE,
  GIS_TOOL_MODE_FEATURE_TO_POINT,
  GIS_TOOL_MODE_POLYGON_TO_LINE,
  GIS_TOOL_MODE_FEATURE_TO_POLYGON,
  GIS_TOOL_MODE_VERTICES_TO_POINTS,
  GIS_TOOL_MODE_POINTS_TO_LINE,
  GIS_TOOL_MODE_DENSIFY,
  GIS_TOOL_MODE_SMOOTH,
  GIS_TOOL_MODE_REMOVE_HOLES,
  GIS_TOOL_MODE_SELECT,
  GIS_TOOL_MODE_TABLE_SELECT,
  GIS_TOOL_MODE_SPLIT,
  GIS_TOOL_MODE_SPLIT_BY_ATTRIBUTES,
  GIS_TOOL_MODE_EXTRACT_BY_EXTENT,
  GIS_TOOL_MODE_EXTRACT_BY_TIME,
  GIS_TOOL_MODE_EXTRACT_BY_MASK,
  GIS_TOOL_MODE_TABULATE_INTERSECTION,
  GIS_TOOL_MODE_SUMMARIZE_WITHIN,
  GIS_TOOL_MODE_NEAR,
  GIS_TOOL_MODE_GENERATE_NEAR_TABLE,
  GIS_TOOL_MODE_POINT_DISTANCE,
  GIS_TOOL_MODE_DISTANCE_MATRIX,
  GIS_TOOL_MODE_SHORTEST_CONNECTION,
  GIS_TOOL_MODE_SUMMARY_STATISTICS,
  GIS_TOOL_MODE_FREQUENCY,
  GIS_TOOL_MODE_UNIQUE_VALUES,
  GIS_TOOL_MODE_GROUP_STATISTICS,
  GIS_TOOL_MODE_CROSSTAB_PIVOT,
  GIS_TOOL_MODE_STATISTICS_CHART,
  GIS_TOOL_MODE_POLYGON_NEIGHBORS,
  GIS_TOOL_MODE_SNAP_OUTPUT,
  GIS_TOOL_MODE_INTEGRATE,
  GIS_TOOL_MODE_EXTEND_TRIM_LINE,
  GIS_TOOL_MODE_AGGREGATE_POLYGONS,
  GIS_TOOL_MODE_ELIMINATE,
  GIS_TOOL_MODE_REMOVE_FRAGMENTS,
  GIS_TOOL_MODE_UNIFY_DIRECTION,
  GIS_TOOL_MODE_CENTERLINE,
  GIS_TOOL_MODE_FISHNET,
  GIS_TOOL_MODE_HEXAGON_GRID,
  GIS_TOOL_MODE_RANDOM_POINTS,
  GIS_TOOL_MODE_REGULAR_POINTS,
  GIS_TOOL_MODE_ADVANCED_BUFFER,
  GIS_TOOL_MODE_SPATIAL_JOIN,
  GIS_TOOL_MODE_ADVANCED_CLIP,
  GIS_TOOL_MODE_SPLIT_LINE_AT_POINT,
  advancedSpatialToolModeForAlgorithmId
} from './ToolRunnerSheet';

@Component
export struct QgisProcessingBrowserSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  onOpenProcessingTool: (toolMode: number) => void = (_toolMode: number) => {};
  onOpenXYTableToPoints: () => void = (): void => {};
  onOpenPortableProject: () => void = (): void => {};
  onOpenLayoutAtlas: () => void = (): void => {};
  @State private backendName: string = '';
  @State private algorithms: GisProcessingAlgorithm[] = [];
  @State private searchText: string = '';
  @State private runStatus: string = '';
  @State private showHistory: boolean = false;
  @State private historyRecords: ProcessingTaskRecord[] = [];
  @State private activeTasks: GisProcessingTaskSnapshot[] = [];
  @StorageLink(PROCESSING_TASK_REVISION_KEY) @Watch('onProcessingTaskRevisionChanged')
  private processingTaskRevision: number = 0;

  onTrigger(): void {
    this.refreshCatalog();
    this.refreshHistory();
    this.refreshActiveTasks();
    this.isShow = true;
  }

  aboutToAppear(): void {
    this.refreshCatalog();
    this.refreshHistory();
    this.refreshActiveTasks();
  }

  onProcessingTaskRevisionChanged(): void {
    this.refreshActiveTasks();
    this.refreshHistory();
  }

  private refreshCatalog(): void {
    let catalog: GisProcessingCatalog = getGisService().processingCatalog();
    this.backendName = catalog.backend;
    this.algorithms = catalog.algorithms;
    this.runStatus = '已加载 ' + this.algorithms.length.toString() + ' 个 Processing 算法';
  }

  private refreshHistory(): void {
    this.historyRecords = getGisService().processingHistory();
  }

  private refreshActiveTasks(): void {
    this.activeTasks = getGisService().activeProcessingTasks();
  }

  private setHistoryVisible(visible: boolean): void {
    this.showHistory = visible;
    if (visible) {
      this.refreshHistory();
      this.runStatus = '已加载 ' + this.historyRecords.length.toString() + ' 条处理历史';
    } else {
      this.runStatus = '已加载 ' + this.algorithms.length.toString() + ' 个 Processing 算法';
    }
  }

  private clearHistory(): void {
    getGisService().clearProcessingHistory();
    this.refreshHistory();
    this.runStatus = '处理历史已清空';
  }

  private normalizedText(value: string): string {
    return value.trim().toLowerCase();
  }

  private algorithmSearchText(item: GisProcessingAlgorithm): string {
    return item.id + ' ' + item.name + ' ' + item.category + ' ' + this.categoryLabel(item.category);
  }

  private filteredAlgorithms(): GisProcessingAlgorithm[] {
    let keyword = this.normalizedText(this.searchText);
    if (keyword.length === 0) {
      return this.algorithms;
    }
    let result: GisProcessingAlgorithm[] = [];
    for (let i = 0; i < this.algorithms.length; i++) {
      let item = this.algorithms[i];
      if (this.normalizedText(this.algorithmSearchText(item)).indexOf(keyword) >= 0) {
        result.push(item);
      }
    }
    return result;
  }

  private historySearchText(item: ProcessingTaskRecord): string {
    return item.algorithmId + ' ' + item.inputLabel + ' ' + item.overlayLabel + ' ' + item.outputLayerName +
      ' ' + item.outputPath + ' ' + item.message;
  }

  private filteredHistory(): ProcessingTaskRecord[] {
    let keyword: string = this.normalizedText(this.searchText);
    if (keyword.length === 0) {
      return this.historyRecords;
    }
    let result: ProcessingTaskRecord[] = [];
    for (let i: number = 0; i < this.historyRecords.length; i++) {
      let item: ProcessingTaskRecord = this.historyRecords[i];
      if (this.normalizedText(this.historySearchText(item)).indexOf(keyword) >= 0) {
        result.push(item);
      }
    }
    return result;
  }

  private historyStatusText(item: ProcessingTaskRecord): ResourceStr {
    if (item.status === PROCESSING_TASK_STATUS_SUCCEEDED) {
      return $r('app.string.gn_processing_history_succeeded');
    }
    if (item.status === PROCESSING_TASK_STATUS_FAILED) {
      return $r('app.string.gn_processing_history_failed');
    }
    if (item.status === PROCESSING_TASK_STATUS_CANCELED) {
      return $r('app.string.gn_processing_history_canceled');
    }
    return $r('app.string.gn_processing_history_running');
  }

  private historyStatusColor(item: ProcessingTaskRecord): ResourceColor {
    if (item.status === PROCESSING_TASK_STATUS_SUCCEEDED) {
      return $r('app.color.gn_green_700');
    }
    if (item.status === PROCESSING_TASK_STATUS_FAILED) {
      return $r('app.color.gn_red_700');
    }
    if (item.status === PROCESSING_TASK_STATUS_CANCELED) {
      return $r('app.color.gn_text_muted');
    }
    return $r('app.color.gn_blue_800');
  }

  private activeTaskStatusText(item: GisProcessingTaskSnapshot): ResourceStr {
    if (item.state === GIS_PROCESSING_TASK_QUEUED) {
      return $r('app.string.gn_queued');
    }
    if (item.state === GIS_PROCESSING_TASK_CANCEL_REQUESTED || item.cancelRequested) {
      return $r('app.string.gn_processing_task_canceling');
    }
    return $r('app.string.gn_running');
  }

  private activeTaskStageText(item: GisProcessingTaskSnapshot): ResourceStr {
    if (item.state === GIS_PROCESSING_TASK_CANCEL_REQUESTED || item.cancelRequested) {
      return $r('app.string.gn_processing_task_canceling');
    }
    if (item.stage === 'prepare') {
      return $r('app.string.gn_processing_stage_prepare');
    }
    if (item.stage === 'read') {
      return $r('app.string.gn_processing_stage_read');
    }
    if (item.stage === 'compute') {
      return $r('app.string.gn_processing_stage_compute');
    }
    if (item.stage === 'write') {
      return $r('app.string.gn_processing_stage_write');
    }
    if (item.stage === 'finalize') {
      return $r('app.string.gn_processing_stage_finalize');
    }
    if (item.stage === 'complete') {
      return $r('app.string.gn_processing_stage_complete');
    }
    return $r('app.string.gn_processing_stage_queued');
  }

  private activeTaskCancelText(item: GisProcessingTaskSnapshot): ResourceStr {
    if (item.state === GIS_PROCESSING_TASK_CANCEL_REQUESTED || item.cancelRequested) {
      return $r('app.string.gn_processing_task_canceling');
    }
    return $r('app.string.gn_processing_cancel_task');
  }

  private activeTaskStatusColor(item: GisProcessingTaskSnapshot): ResourceColor {
    if (item.state === GIS_PROCESSING_TASK_CANCEL_REQUESTED || item.cancelRequested) {
      return $r('app.color.gn_red_700');
    }
    if (item.state === GIS_PROCESSING_TASK_QUEUED) {
      return $r('app.color.gn_text_muted');
    }
    return $r('app.color.gn_blue_800');
  }

  private activeTaskProgressText(item: GisProcessingTaskSnapshot): string {
    let progress: number = item.progress;
    if (progress < 0) {
      progress = 0;
    }
    if (progress > 100) {
      progress = 100;
    }
    return Math.round(progress).toString() + '%';
  }

  private activeTaskCanCancel(item: GisProcessingTaskSnapshot): boolean {
    if (item.cancelRequested || item.state === GIS_PROCESSING_TASK_CANCEL_REQUESTED) {
      return false;
    }
    return item.state === GIS_PROCESSING_TASK_QUEUED || item.state === GIS_PROCESSING_TASK_RUNNING;
  }

  private cancelActiveTask(item: GisProcessingTaskSnapshot): void {
    let snapshot: GisProcessingTaskSnapshot | undefined = getGisService().cancelProcessingTask(item.taskId);
    if (snapshot !== undefined) {
      this.runStatus = snapshot.message;
    }
    this.refreshActiveTasks();
    this.refreshHistory();
  }

  private historyTimeText(item: ProcessingTaskRecord): string {
    if (item.startedAt <= 0) {
      return '';
    }
    return new Date(item.startedAt).toLocaleString();
  }

  private historyDurationText(item: ProcessingTaskRecord): string {
    if (item.durationMs < 1000) {
      return item.durationMs.toString() + ' ms';
    }
    return (item.durationMs / 1000.0).toFixed(2) + ' s';
  }

  private categoryLabel(category: string): string {
    if (category === 'geometry') {
      return '几何处理';
    }
    if (category === 'overlay') {
      return '叠加分析';
    }
    if (category === 'selection') {
      return '选择提取';
    }
    if (category === 'analysis') {
      return '空间分析';
    }
    if (category === 'raster') {
      return '栅格分析';
    }
    if (category === 'quality') {
      return '数据质量';
    }
    if (category === 'data') {
      return '数据管理';
    }
    if (category === 'crs') {
      return '坐标系';
    }
    if (category.length > 0) {
      return category;
    }
    return '未分类';
  }

  private parameterSummary(item: GisProcessingAlgorithm): string {
    let summary = item.inputCount.toString() + ' 个输入图层';
    if (item.numericParameter) {
      summary += ' · 数值参数';
    }
    if (item.textParameter) {
      summary += ' · 文本参数';
    }
    if (!item.numericParameter && !item.textParameter) {
      summary += ' · 无额外参数';
    }
    return summary;
  }

  private toolModeForAlgorithmId(algorithmId: string): number {
    let advancedMode: number = advancedSpatialToolModeForAlgorithmId(algorithmId);
    if (advancedMode > 0) {
      return advancedMode;
    }
    if (algorithmId === 'building_simplify') return GIS_TOOL_MODE_SIMPLIFY;
    if (algorithmId === 'road_merge') return GIS_TOOL_MODE_DISSOLVE;
    if (algorithmId === 'road_conflict') return GIS_TOOL_MODE_DIFFERENCE;
    if (algorithmId === 'symbol_conflict') return GIS_TOOL_MODE_NEAREST_NEIGHBOR;
    if (algorithmId === 'cartographic_mask' || algorithmId === 'cartogram') return GIS_TOOL_MODE_ADVANCED_BUFFER;
    if (algorithmId === 'feature_stroke') return GIS_TOOL_MODE_POLYGON_TO_LINE;
    if (algorithmId === 'label_to_annotation' || algorithmId === 'tile_annotation') {
      return GIS_TOOL_MODE_FEATURE_TO_POINT;
    }
    if (algorithmId === 'clip') {
      return GIS_TOOL_MODE_CLIP;
    }
    if (algorithmId === 'buffer') {
      return GIS_TOOL_MODE_BUFFER;
    }
    if (algorithmId === 'repair') {
      return GIS_TOOL_MODE_REPAIR;
    }
    if (algorithmId === 'export') {
      return GIS_TOOL_MODE_EXPORT;
    }
    if (algorithmId === 'define_projection') {
      return GIS_TOOL_MODE_DEFINE_PROJECTION;
    }
    if (algorithmId === 'project') {
      return GIS_TOOL_MODE_PROJECT_LAYER;
    }
    if (algorithmId === 'simplify') {
      return GIS_TOOL_MODE_SIMPLIFY;
    }
    if (algorithmId === 'dissolve') {
      return GIS_TOOL_MODE_DISSOLVE;
    }
    if (algorithmId === 'centroid') {
      return GIS_TOOL_MODE_CENTROID;
    }
    if (algorithmId === 'convex_hull') {
      return GIS_TOOL_MODE_CONVEX_HULL;
    }
    if (algorithmId === 'bounding_boxes') {
      return GIS_TOOL_MODE_BOUNDING_BOXES;
    }
    if (algorithmId === 'oriented_minimum_bounding_box') {
      return GIS_TOOL_MODE_ORIENTED_MINIMUM_BOUNDING_BOX;
    }
    if (algorithmId === 'multipart_to_singleparts') {
      return GIS_TOOL_MODE_MULTIPART_TO_SINGLEPARTS;
    }
    if (algorithmId === 'feature_to_point') {
      return GIS_TOOL_MODE_FEATURE_TO_POINT;
    }
    if (algorithmId === 'polygon_to_line') {
      return GIS_TOOL_MODE_POLYGON_TO_LINE;
    }
    if (algorithmId === 'feature_to_polygon') {
      return GIS_TOOL_MODE_FEATURE_TO_POLYGON;
    }
    if (algorithmId === 'vertices_to_points') {
      return GIS_TOOL_MODE_VERTICES_TO_POINTS;
    }
    if (algorithmId === 'points_to_line') {
      return GIS_TOOL_MODE_POINTS_TO_LINE;
    }
    if (algorithmId === 'densify') {
      return GIS_TOOL_MODE_DENSIFY;
    }
    if (algorithmId === 'smooth') {
      return GIS_TOOL_MODE_SMOOTH;
    }
    if (algorithmId === 'remove_holes') {
      return GIS_TOOL_MODE_REMOVE_HOLES;
    }
    if (algorithmId === 'select') {
      return GIS_TOOL_MODE_SELECT;
    }
    if (algorithmId === 'table_select') {
      return GIS_TOOL_MODE_TABLE_SELECT;
    }
    if (algorithmId === 'split') {
      return GIS_TOOL_MODE_SPLIT;
    }
    if (algorithmId === 'split_by_attributes') {
      return GIS_TOOL_MODE_SPLIT_BY_ATTRIBUTES;
    }
    if (algorithmId === 'extract_by_extent') {
      return GIS_TOOL_MODE_EXTRACT_BY_EXTENT;
    }
    if (algorithmId === 'extract_by_time') {
      return GIS_TOOL_MODE_EXTRACT_BY_TIME;
    }
    if (algorithmId === 'extract_by_mask') {
      return GIS_TOOL_MODE_EXTRACT_BY_MASK;
    }
    if (algorithmId === 'tabulate_intersection') {
      return GIS_TOOL_MODE_TABULATE_INTERSECTION;
    }
    if (algorithmId === 'summarize_within') {
      return GIS_TOOL_MODE_SUMMARIZE_WITHIN;
    }
    if (algorithmId === 'near') {
      return GIS_TOOL_MODE_NEAR;
    }
    if (algorithmId === 'generate_near_table') {
      return GIS_TOOL_MODE_GENERATE_NEAR_TABLE;
    }
    if (algorithmId === 'point_distance') {
      return GIS_TOOL_MODE_POINT_DISTANCE;
    }
    if (algorithmId === 'distance_matrix') {
      return GIS_TOOL_MODE_DISTANCE_MATRIX;
    }
    if (algorithmId === 'shortest_connection') {
      return GIS_TOOL_MODE_SHORTEST_CONNECTION;
    }
    if (algorithmId === 'summary_statistics') {
      return GIS_TOOL_MODE_SUMMARY_STATISTICS;
    }
    if (algorithmId === 'frequency') {
      return GIS_TOOL_MODE_FREQUENCY;
    }
    if (algorithmId === 'unique_values') {
      return GIS_TOOL_MODE_UNIQUE_VALUES;
    }
    if (algorithmId === 'group_statistics') {
      return GIS_TOOL_MODE_GROUP_STATISTICS;
    }
    if (algorithmId === 'crosstab_pivot') {
      return GIS_TOOL_MODE_CROSSTAB_PIVOT;
    }
    if (algorithmId === 'statistics_chart') {
      return GIS_TOOL_MODE_STATISTICS_CHART;
    }
    if (algorithmId === 'polygon_neighbors') {
      return GIS_TOOL_MODE_POLYGON_NEIGHBORS;
    }
    if (algorithmId === 'feature_to_line') return GIS_TOOL_MODE_POLYGON_TO_LINE;
    if (algorithmId === 'snap') return GIS_TOOL_MODE_SNAP_OUTPUT;
    if (algorithmId === 'integrate' || algorithmId === 'pairwise_integrate') return GIS_TOOL_MODE_INTEGRATE;
    if (algorithmId === 'extend_trim_line') return GIS_TOOL_MODE_EXTEND_TRIM_LINE;
    if (algorithmId === 'aggregate_polygons') return GIS_TOOL_MODE_AGGREGATE_POLYGONS;
    if (algorithmId === 'eliminate') return GIS_TOOL_MODE_ELIMINATE;
    if (algorithmId === 'remove_fragments') return GIS_TOOL_MODE_REMOVE_FRAGMENTS;
    if (algorithmId === 'unify_direction') return GIS_TOOL_MODE_UNIFY_DIRECTION;
    if (algorithmId === 'centerline') return GIS_TOOL_MODE_CENTERLINE;
    if (algorithmId === 'fishnet') return GIS_TOOL_MODE_FISHNET;
    if (algorithmId === 'hexagon_grid') return GIS_TOOL_MODE_HEXAGON_GRID;
    if (algorithmId === 'random_points') return GIS_TOOL_MODE_RANDOM_POINTS;
    if (algorithmId === 'regular_points') return GIS_TOOL_MODE_REGULAR_POINTS;
    if (algorithmId === 'advanced_buffer') return GIS_TOOL_MODE_ADVANCED_BUFFER;
    if (algorithmId === 'spatial_join') return GIS_TOOL_MODE_SPATIAL_JOIN;
    if (algorithmId === 'advanced_clip') return GIS_TOOL_MODE_ADVANCED_CLIP;
    if (algorithmId === 'split_line_at_point') return GIS_TOOL_MODE_SPLIT_LINE_AT_POINT;
    if (algorithmId === 'pairwise_clip') {
      return GIS_TOOL_MODE_CLIP;
    }
    if (algorithmId === 'pairwise_buffer') {
      return GIS_TOOL_MODE_BUFFER;
    }
    if (algorithmId === 'pairwise_dissolve') {
      return GIS_TOOL_MODE_DISSOLVE;
    }
    if (algorithmId === 'pairwise_intersect') {
      return GIS_TOOL_MODE_INTERSECTION;
    }
    if (algorithmId === 'pairwise_erase') {
      return GIS_TOOL_MODE_DIFFERENCE;
    }
    if (algorithmId === 'extract_by_expression') {
      return GIS_TOOL_MODE_EXTRACT_BY_EXPRESSION;
    }
    if (algorithmId === 'difference') {
      return GIS_TOOL_MODE_DIFFERENCE;
    }
    if (algorithmId === 'symmetrical_difference') {
      return GIS_TOOL_MODE_SYMMETRICAL_DIFFERENCE;
    }
    if (algorithmId === 'union') {
      return GIS_TOOL_MODE_UNION;
    }
    if (algorithmId === 'identity') {
      return GIS_TOOL_MODE_IDENTITY;
    }
    if (algorithmId === 'update') {
      return GIS_TOOL_MODE_UPDATE;
    }
    if (algorithmId === 'merge_layers') {
      return GIS_TOOL_MODE_MERGE_LAYERS;
    }
    if (algorithmId === 'multi_ring_buffer') {
      return GIS_TOOL_MODE_MULTI_RING_BUFFER;
    }
    if (algorithmId === 'extract_by_location') {
      return GIS_TOOL_MODE_EXTRACT_BY_LOCATION;
    }
    if (algorithmId === 'spatial_join_summary') {
      return GIS_TOOL_MODE_SPATIAL_JOIN_SUMMARY;
    }
    if (algorithmId === 'intersection') {
      return GIS_TOOL_MODE_INTERSECTION;
    }
    if (algorithmId === 'nearest_neighbor') {
      return GIS_TOOL_MODE_NEAREST_NEIGHBOR;
    }
    if (algorithmId === 'voronoi') {
      return GIS_TOOL_MODE_VORONOI;
    }
    if (algorithmId === 'tin') return GIS_TOOL_MODE_TIN;
    if (algorithmId === 'terrain_profile') return GIS_TOOL_MODE_TERRAIN_PROFILE;
    if (algorithmId === 'line_of_sight') return GIS_TOOL_MODE_LINE_OF_SIGHT;
    if (algorithmId === 'viewshed') return GIS_TOOL_MODE_VIEWSHED;
    if (algorithmId === 'skyline') return GIS_TOOL_MODE_SKYLINE;
    if (algorithmId === 'kernel_density') {
      return GIS_TOOL_MODE_KERNEL_DENSITY;
    }
    if (algorithmId === 'point_density') {
      return GIS_TOOL_MODE_POINT_DENSITY;
    }
    if (algorithmId === 'line_density') {
      return GIS_TOOL_MODE_LINE_DENSITY;
    }
    if (algorithmId === 'idw' || algorithmId === 'dsm' || algorithmId === 'dtm') {
      return GIS_TOOL_MODE_IDW;
    }
    if (algorithmId === 'raster_slope') {
      return GIS_TOOL_MODE_RASTER_SLOPE;
    }
    if (algorithmId === 'raster_aspect') {
      return GIS_TOOL_MODE_RASTER_ASPECT;
    }
    if (algorithmId === 'raster_reclassify') {
      return GIS_TOOL_MODE_RASTER_RECLASSIFY;
    }
    if (algorithmId === 'chm') return GIS_TOOL_MODE_CHM;
    if (algorithmId === 'earthwork') return GIS_TOOL_MODE_EARTHWORK;
    if (algorithmId === 'surface_area') return GIS_TOOL_MODE_SURFACE_AREA;
    if (algorithmId === 'quality_check') {
      return GIS_TOOL_MODE_QUALITY_CHECK;
    }
    return 0;
  }

  private statusText(item: GisProcessingAlgorithm): string {
    if (this.algorithmHasEntry(item.id)) {
      return '已接入口';
    }
    return '仅浏览';
  }

  private statusColor(item: GisProcessingAlgorithm): ResourceColor {
    if (this.algorithmHasEntry(item.id)) {
      return $r('app.color.gn_green_700');
    }
    return $r('app.color.gn_text_muted');
  }

  private openAlgorithm(item: GisProcessingAlgorithm): void {
    if (item.id === 'xy_table_to_points') {
      this.isShow = false;
      this.onOpenXYTableToPoints();
      return;
    }
    if (item.id === 'portable_project') {
      this.isShow = false;
      this.onOpenPortableProject();
      return;
    }
    if (item.id === 'layout_atlas') {
      this.isShow = false;
      this.onOpenLayoutAtlas();
      return;
    }
    let toolMode = this.toolModeForAlgorithmId(item.id);
    if (toolMode <= 0) {
      this.runStatus = '算法 ' + item.id + ' 当前只显示目录，尚未接入参数表单';
      return;
    }
    this.isShow = false;
    this.onOpenProcessingTool(toolMode);
  }

  private algorithmHasEntry(algorithmId: string): boolean {
    if (algorithmId === 'xy_table_to_points' || algorithmId === 'portable_project' ||
      algorithmId === 'layout_atlas') {
      return true;
    }
    return this.toolModeForAlgorithmId(algorithmId) > 0;
  }

  @Builder
  metaChip(icon: Resource, text: string, color: ResourceColor) {
    Row({ space: 4 }) {
      SymbolGlyph(icon)
        .fontSize(13)
        .fontColor([color])
      Text(text)
        .fontSize(11)
        .fontColor(color)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(24)
    .padding({ left: 8, right: 8 })
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_pane'))
  }

  @Builder
  algorithmRow(item: GisProcessingAlgorithm) {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.wrench_arrow_counterclockwise'))
        .fontSize(20)
        .fontColor([$r('app.color.gn_blue_800')])
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text(item.name)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.statusText(item))
            .fontSize(11)
            .fontColor(this.statusColor(item))
            .maxLines(1)
        }
        Text(item.id)
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          this.metaChip($r('sys.symbol.folder'), this.categoryLabel(item.category), $r('app.color.gn_blue_800'))
          this.metaChip($r('sys.symbol.list_bullet'), this.parameterSummary(item), $r('app.color.gn_text_muted'))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Button($r('app.string.gn_processing_open'), { type: ButtonType.Normal, stateEffect: true })
        .height(32)
        .width(72)
        .fontSize(12)
        .fontColor($r('app.color.gn_blue_800'))
        .backgroundColor($r('app.color.gn_blue_100'))
        .borderRadius(6)
        .enabled(this.algorithmHasEntry(item.id))
        .onClick(() => {
          this.openAlgorithm(item);
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  activeTaskRow(item: GisProcessingTaskSnapshot) {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.wrench_arrow_counterclockwise'))
        .fontSize(20)
        .fontColor([this.activeTaskStatusColor(item)])
      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(item.algorithmId)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.activeTaskStatusText(item))
            .fontSize(11)
            .fontColor(this.activeTaskStatusColor(item))
          Text(this.activeTaskProgressText(item))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_blue_800'))
        }
        if (item.stage.length > 0) {
          Text(this.activeTaskStageText(item))
            .fontSize(11)
            .fontColor($r('app.color.gn_text_muted'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (item.message.length > 0) {
          Text(item.message)
            .fontSize(11)
            .fontColor(this.activeTaskStatusColor(item))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Button(this.activeTaskCancelText(item), { type: ButtonType.Normal, stateEffect: true })
        .height(32)
        .width(72)
        .fontSize(12)
        .fontColor($r('app.color.gn_red_700'))
        .backgroundColor($r('app.color.gn_pane'))
        .borderRadius(6)
        .enabled(this.activeTaskCanCancel(item))
        .onClick(() => {
          this.cancelActiveTask(item);
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  historyRow(item: ProcessingTaskRecord) {
    Row({ space: 10 }) {
      SymbolGlyph(item.status === PROCESSING_TASK_STATUS_SUCCEEDED ? $r('sys.symbol.checkmark_circle') :
        $r('sys.symbol.exclamationmark_circle'))
        .fontSize(20)
        .fontColor([this.historyStatusColor(item)])
      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(item.algorithmId)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.historyStatusText(item))
            .fontSize(11)
            .fontColor(this.historyStatusColor(item))
        }
        Text(this.historyTimeText(item) + ' · ' + this.historyDurationText(item) +
          ' · code ' + item.code.toString())
          .fontSize(10)
          .fontColor($r('app.color.gn_text_muted'))
        Row({ space: 6 }) {
          Text($r('app.string.gn_processing_history_input'))
            .fontSize(10)
            .fontColor($r('app.color.gn_text_muted'))
          Text(item.inputLabel.length > 0 ? item.inputLabel : '-')
            .fontSize(11)
            .fontColor($r('app.color.gn_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        Row({ space: 6 }) {
          Text($r('app.string.gn_processing_history_output'))
            .fontSize(10)
            .fontColor($r('app.color.gn_text_muted'))
          Text(item.outputPath.length > 0 ? item.outputPath : '-')
            .fontSize(11)
            .fontColor($r('app.color.gn_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        if (item.parameterSummary.length > 0) {
          Text(item.parameterSummary)
            .fontSize(10)
            .fontColor($r('app.color.gn_text_muted'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (item.message.length > 0) {
          Text(item.message)
            .fontSize(11)
            .fontColor(this.historyStatusColor(item))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  browserPanel() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.list_bullet_square'))
          .fontSize(30)
          .fontColor([$r('app.color.gn_blue_800')])
        Column({ space: 3 }) {
          Text($r('app.string.gn_processing_browser_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.gn_text_primary'))
          Text($r('app.string.gn_processing_browser_desc'))
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      Text(this.backendName.length > 0 ? this.backendName : 'backend: none')
        .width('100%')
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
      Row({ space: 8 }) {
        Button($r('app.string.gn_processing_catalog_tab'), { type: ButtonType.Normal, stateEffect: true })
          .height(34)
          .fontSize(12)
          .fontColor(!this.showHistory ? Color.White : $r('app.color.gn_text_primary'))
          .backgroundColor(!this.showHistory ? $r('app.color.gn_blue_800') : $r('app.color.gn_pane'))
          .borderRadius(6)
          .onClick(() => {
            this.setHistoryVisible(false);
          })
        Button($r('app.string.gn_processing_history'), { type: ButtonType.Normal, stateEffect: true })
          .height(34)
          .fontSize(12)
          .fontColor(this.showHistory ? Color.White : $r('app.color.gn_text_primary'))
          .backgroundColor(this.showHistory ? $r('app.color.gn_blue_800') : $r('app.color.gn_pane'))
          .borderRadius(6)
          .onClick(() => {
            this.setHistoryVisible(true);
          })
        Blank()
        if (this.showHistory && this.historyRecords.length > 0) {
          Button($r('app.string.gn_processing_clear_history'), { type: ButtonType.Normal, stateEffect: true })
            .height(34)
            .fontSize(12)
            .fontColor($r('app.color.gn_red_700'))
            .backgroundColor($r('app.color.gn_pane'))
            .borderRadius(6)
            .onClick(() => {
              this.clearHistory();
            })
        }
      }
      .width('100%')
      Search({ placeholder: this.showHistory ? $r('app.string.gn_processing_history_search') :
        $r('app.string.gn_processing_search') })
        .height(36)
        .backgroundColor($r('app.color.gn_pane'))
        .onChange((value: string) => {
          this.searchText = value;
        })
      Text(this.runStatus)
        .width('100%')
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
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
            this.browserPanel()
            if (this.activeTasks.length > 0) {
              Column() {
                Row() {
                  Text($r('app.string.gn_processing_active_tasks'))
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.gn_text_primary'))
                  Blank()
                  Text(this.activeTasks.length.toString())
                    .fontSize(12)
                    .fontColor($r('app.color.gn_text_muted'))
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 10, bottom: 8 })
                ForEach(this.activeTasks, (item: GisProcessingTaskSnapshot) => {
                  this.activeTaskRow(item)
                }, (item: GisProcessingTaskSnapshot) => item.taskId)
              }
              .borderRadius(6)
              .clip(true)
              .backgroundColor($r('app.color.gn_paper'))
              .border({ width: 1, color: $r('app.color.gn_line') })
            }
            Column() {
              if (this.showHistory) {
                if (this.filteredHistory().length === 0) {
                  Text($r('app.string.gn_processing_history_empty'))
                    .width('100%')
                    .fontSize(12)
                    .fontColor($r('app.color.gn_text_muted'))
                    .padding(14)
                } else {
                  ForEach(this.filteredHistory(), (item: ProcessingTaskRecord) => {
                    this.historyRow(item)
                  }, (item: ProcessingTaskRecord) => item.taskId)
                }
              } else {
                if (this.filteredAlgorithms().length === 0) {
                  Text($r('app.string.gn_processing_empty'))
                    .width('100%')
                    .fontSize(12)
                    .fontColor($r('app.color.gn_text_muted'))
                    .padding(14)
                } else {
                  ForEach(this.filteredAlgorithms(), (item: GisProcessingAlgorithm) => {
                    this.algorithmRow(item)
                  }, (item: GisProcessingAlgorithm) => item.id)
                }
              }
            }
            .borderRadius(6)
            .clip(true)
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
          title: { mainTitle: $r('app.string.gn_processing_browser_title') },
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
