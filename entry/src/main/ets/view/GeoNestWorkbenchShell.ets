import { GisNativeBridgeStatus, queryGisNativeBridgeStatus } from '../gis/GisNativeBridge';
import { getGisService, GisLayerStyle, GisLoadedLayer } from '../gis/GisService';
import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { componentSnapshot, promptAction } from '@kit.ArkUI';
import {
  createCollaborationServiceMenuItems,
  CollaborationServiceStateDialog,
  CollaborationServiceFilter
} from '@kit.ServiceCollaborationKit';
import { isCollaborationCapable } from '@geonest/common';
import { HuaweiAuthManager } from '../utils/HuaweiAuthManager';
import {
  GeoNestCloudLayerPackage,
  GeoNestCloudPullResult,
  GeoNestCloudSyncManager,
  GeoNestCloudSyncStatus,
  GeoNestCloudUploadRequest
} from '../utils/GeoNestCloudSyncManager';
import { GeoNestFormState, GeoNestFormStateStore } from '../utils/GeoNestFormStateStore';
import { ProjectRecoveryManager, ProjectRecoverySnapshot } from '../utils/ProjectRecoveryManager';
import { TopologyRuleStore } from '../utils/TopologyRuleStore';
import { SnappingConfiguration } from '../model/TopologyModels';
import {
  MAP_COMMAND_FULL_EXTENT,
  MAP_COMMAND_NONE,
  MAP_COMMAND_ZOOM_PRIMARY,
  MAP_COMMAND_ZOOM_SELECTED,
  FEATURE_SELECTION_REPLACE,
  FEATURE_SELECTION_TOGGLE,
  MAP_TOOL_IDENTIFY,
  MAP_TOOL_MEASURE_ANGLE,
  MAP_TOOL_MEASURE_AREA,
  MAP_TOOL_MEASURE_DISTANCE,
  MAP_TOOL_PICK_COORDINATE,
  MAP_TOOL_SELECT_MULTIPLE,
  MAP_TOOL_SELECT_BOX,
  MAP_TOOL_SELECT_LASSO,
  MAP_TOOL_SELECT_POLYGON,
  MAP_TOOL_EDIT_ADD_POINT,
  MAP_TOOL_EDIT_ADD_LINE,
  MAP_TOOL_EDIT_ADD_POLYGON,
  MAP_TOOL_EDIT_MOVE_NODE,
  MAP_TOOL_EDIT_DELETE_NODE,
  MAP_TOOL_EDIT_CUT_SKETCH,
  MAP_TOOL_EDIT_TRACE,
  MAP_TOOL_EDIT_PARALLEL,
  MAP_TOOL_EDIT_PERPENDICULAR,
  MAP_TOOL_EDIT_ORTHOGONAL,
  MAP_COMMAND_ZOOM_IN,
  MAP_COMMAND_ZOOM_OUT,
  BASEMAP_VECTOR,
  BASEMAP_ONLINE_STANDARD,
  BASEMAP_TERRAIN,
  BASEMAP_IMAGERY,
  BASEMAP_HARMONY_STANDARD,
  BASEMAP_HARMONY_TERRAIN,
  BASEMAP_HARMONY_IMAGERY,
  BASEMAP_DATUM_AUTO,
  BASEMAP_DATUM_WGS84,
  BASEMAP_DATUM_GCJ02
} from '@geonest/common';
import { GisMapCanvas, MapViewport } from '../component/GisMapCanvas';
import { GisFeatureInfoPanel } from '../component/GisFeatureInfoPanel';
import { GisScene3D } from '../component/GisScene3D';
import { AppSettingsSheet } from '../component/AppSettingsSheet';
import { ProjectInfoSheet, NewProjectSheet } from '../component/ProjectSheet';
import { QgisCoreSheet } from '../component/QgisCoreSheet';
import { QgisProcessingBrowserSheet } from '../component/QgisProcessingBrowserSheet';
import { ExpressionWorkbenchSheet } from '../component/ExpressionWorkbenchSheet';
import { AttributeTableSheet } from '../component/AttributeTableSheet';
import { XYTableToPointSheet } from '../component/XYTableToPointSheet';
import { TopologyReviewSheet } from '../component/TopologyReviewSheet';
import { PortableProjectSheet, AtlasExportSheet } from '../component/ProjectDeliverySheet';
import { SymbologySheet, LabelingSheet } from '../component/SymbologySheet';
import { VectorEditSheet, AttributeEditSheet } from '../component/VectorEditSheet';
import { RasterDisplaySheet } from '../component/RasterDisplaySheet';
import { MapLayoutSheet, PrintSheet } from '../component/MapLayoutSheet';
import {
  ToolRunnerSheet,
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
  GIS_TOOL_MODE_QUALITY_CHECK
} from '../component/ToolRunnerSheet';
import {
  VECTOR_EDIT_COMMAND_COPY,
  VECTOR_EDIT_COMMAND_CUT,
  VECTOR_EDIT_COMMAND_DELETE_FEATURE,
  VECTOR_EDIT_COMMAND_BEGIN_SESSION,
  VECTOR_EDIT_COMMAND_COMMIT_SESSION,
  VECTOR_EDIT_COMMAND_ROLLBACK_SESSION,
  VECTOR_EDIT_COMMAND_MERGE,
  VECTOR_EDIT_COMMAND_REDO,
  VECTOR_EDIT_COMMAND_SNAP,
  VECTOR_EDIT_COMMAND_UNDO
} from '../component/VectorEditSheet';
import {
  GeoNestProjectParameters,
  GisAttributeValue,
  GisFeatureSummary,
  GisFieldInfo,
  GisCoordinate,
  GisCoordinateTransformResult,
  GisOperationResult,
  GisGeoProcessResult,
  GisProcessingTaskSnapshot,
  GisQgisProjectReadResult,
  GisLayerSelection
} from '../model/GeoNestModels';
import {
  APP_CACHE_STRATEGY_KEY,
  APP_FLOATING_TAB_MATERIAL_KEY,
  APP_FRAME_PACING_KEY,
  APP_INTERFACE_DENSITY_KEY,
  APP_MAP_RENDER_QUALITY_KEY,
  APP_MATERIAL_ENABLED_KEY,
  APP_MATERIAL_QUALITY_KEY,
  APP_MOUSE_SCROLL_OPTIMIZATION_KEY,
  APP_OPEN_SIDE_PANES_KEY,
  APP_POINTER_SMOOTHING_KEY,
  APP_PROGRESSIVE_LOADING_KEY,
  INTERFACE_DENSITY_COMFORTABLE,
  INTERFACE_DENSITY_COMPACT,
  MATERIAL_QUALITY_EFFICIENT,
  MATERIAL_QUALITY_REFINED
} from '../model/AppPreferences';
import { MaterialStyle } from '@geonest/common';
import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { systemShare } from '@kit.ShareKit';
import { GestureShareModel } from '../gis/GestureShareModel';
import { fileIo } from '@kit.CoreFileKit';
import { KeyCode } from '@kit.InputKit';
import { window } from '@kit.ArkUI';
import { fileUri } from '@kit.CoreFileKit';
import { unifiedDataChannel, uniformTypeDescriptor as utd } from '@kit.ArkData';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import {
  GN_LAYER_REVISION_KEY,
  GN_MULTI_MAP_LINK_ENABLED_KEY,
  GN_MULTI_MAP_VIEWPORT_CENTER_X_KEY,
  GN_MULTI_MAP_VIEWPORT_CENTER_Y_KEY,
  GN_MULTI_MAP_VIEWPORT_REVISION_KEY,
  GN_MULTI_MAP_VIEWPORT_SCALE_KEY,
  GN_MULTI_MAP_VIEWPORT_SOURCE_KEY
} from '../model/MultiMapState';
import fs from '@ohos.file.fs';
import hilog from '@ohos.hilog';
import util from '@ohos.util';
import { WorkbenchImportCoordinator, WorkbenchImportResult } from '../coordinator/WorkbenchImportCoordinator';
import { WorkbenchProjectTextWriter } from '../coordinator/WorkbenchProjectTextWriter';
import { WorkbenchSearchCoordinator } from '../coordinator/WorkbenchSearchCoordinator';
import { WorkbenchLayerPresentationCoordinator } from '../coordinator/WorkbenchLayerPresentationCoordinator';
import {
  ClipboardCoordinateCandidate,
  GlobalSearchCandidate,
  LayerDisplayItem,
  RecentProjectRecord,
  WorkbenchFieldItem
} from '@geonest/workbench';
import { WorkbenchTextService } from '@geonest/workbench';
import { WorkbenchFileService } from '@geonest/workbench';
import { WorkbenchRecentProjectService } from '@geonest/workbench';
import { WorkbenchMapStatusBar } from '@geonest/workbench';
import { WorkbenchBackstage } from '@geonest/workbench';
import { WorkbenchToolsPanel } from '@geonest/workbench';
import { WorkbenchCommandSearchPopup } from '@geonest/workbench';
import { WorkbenchCatalogPanel } from '@geonest/workbench';
import { WorkbenchContentsPanel } from '@geonest/workbench';
import { WorkbenchRibbonTabs } from '@geonest/workbench';
import { WorkbenchWindowTitleBar } from '@geonest/workbench';
import { WorkbenchTitleArea } from '@geonest/workbench';
import { WorkbenchRibbonPanel } from '@geonest/workbench';
import { WorkbenchCloudSyncSheet } from '@geonest/workbench';
import { WorkbenchMapToolbar } from '@geonest/workbench';
import { WorkbenchSearchViewModel } from '@geonest/workbench';
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
} from '@geonest/workbench';

const LOG_TAG: number = 0xFF00;
const LOG_DOMAIN: string = 'GeoNest';
const TRANSFERRED_SHANXI_SHP: string = '/data/local/tmp/GeoNestData/shanxi_boundary_140000/140000.shp';
const PROJECT_FILE_MAGIC: string = 'GEONEST_PROJECT_V1';
const PROJECT_FILE_SUFFIX_CHOICE: string = 'GeoNest Project|.gnproj';
const QGIS_QGS_PROJECT_FILE_SUFFIX_CHOICE: string = 'QGIS Project (.qgs)|.qgs';
const QGIS_QGZ_PROJECT_FILE_SUFFIX_CHOICE: string = 'QGIS Project (.qgz)|.qgz';
const RECENT_PROJECTS_FILE_NAME: string = 'geonest_recent_projects.txt';
const FORM_THUMBNAIL_FILE_NAME: string = 'geonest_form_thumbnail.jpg';
const MAP_THUMBNAIL_CAPTURE_ID: string = 'geonest_main_map_capture';
const MAP_THUMBNAIL_CAPTURE_DELAY_MS: number = 600;
const MAP_THUMBNAIL_CAPTURE_INTERVAL_MS: number = 7000;
const MAP_THUMBNAIL_CAPTURE_SCALE: number = 0.35;
const MAP_THUMBNAIL_JPEG_QUALITY: number = 72;
const RECENT_PROJECT_LIMIT: number = 8;
const ACTION_ATTRIBUTE_TABLE: number = 5;
const ACTION_ADD_DATA: number = 7;
const ACTION_ZOOM_IN: number = 8;
const ACTION_ZOOM_OUT: number = 9;
const ACTION_FULL_EXTENT: number = 10;
const ACTION_SYMBOLOGY: number = 11;
const ACTION_CLIP: number = 12;
const ACTION_BUFFER: number = 13;
const ACTION_REPAIR: number = 14;
const ACTION_LAYER_TOGGLE: number = 15;
const ACTION_LAYER_FILTER: number = 16;
const ACTION_LAYER_UP: number = 17;
const ACTION_LAYER_DOWN: number = 18;
const ACTION_LAYER_DELETE: number = 19;
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
const ACTION_SHOW_CONTENTS: number = 32;
const ACTION_SHOW_CATALOG: number = 33;
const ACTION_SHOW_TOOLBOX: number = 34;
const ACTION_EXPLORE: number = 35;
const ACTION_SIMPLIFY: number = 36;
const ACTION_DISSOLVE: number = 37;
const ACTION_CENTROID: number = 38;
const ACTION_HELP: number = 40;
const ACTION_ABOUT: number = 41;
const ACTION_SHARE: number = 42;
const ACTION_RECEIVE_FROM_DEVICE: number = 43;
const ACTION_CLOUD_MANAGE: number = 44;
const ACTION_CLOUD_PUSH: number = 45;
const ACTION_CLOUD_PULL: number = 46;
const ACTION_CONVEX_HULL: number = 47;
const ACTION_BOUNDING_BOXES: number = 48;
const ACTION_ORIENTED_MINIMUM_BOUNDING_BOX: number = 49;
const ACTION_MULTIPART_TO_SINGLEPARTS: number = 50;
const ACTION_EXTRACT_BY_EXPRESSION: number = 51;
const ACTION_DIFFERENCE: number = 52;
const ACTION_SYMMETRICAL_DIFFERENCE: number = 53;
const ACTION_MERGE_LAYERS: number = 54;
const ACTION_MULTI_RING_BUFFER: number = 55;
const ACTION_EXTRACT_BY_LOCATION: number = 56;
const ACTION_SPATIAL_JOIN_SUMMARY: number = 57;
const ACTION_INTERSECTION: number = 58;
const ACTION_NEAREST_NEIGHBOR: number = 59;
const ACTION_VORONOI: number = 60;
const ACTION_PROCESSING_BROWSER: number = 61;
const ACTION_KERNEL_DENSITY: number = 62;
const ACTION_POINT_DENSITY: number = 63;
const ACTION_LINE_DENSITY: number = 64;
const ACTION_IDW: number = 65;
const ACTION_EXPRESSION_WORKBENCH: number = 66;
const ACTION_RASTER_SLOPE: number = 67;
const ACTION_RASTER_ASPECT: number = 68;
const ACTION_RASTER_RECLASSIFY: number = 69;
const ACTION_QUALITY_CHECK: number = 70;
const ACTION_XY_TABLE_TO_POINT: number = 71;
const ACTION_TOPOLOGY_REVIEW: number = 72;
const ACTION_PORTABLE_PROJECT: number = 73;
const ACTION_LAYOUT_ATLAS: number = 74;
const ACTION_OPEN_SECOND_MAP: number = 75;
const ACTION_TOGGLE_LINKED_VIEW: number = 76;
const ACTION_COPY_MAP_CONTEXT: number = 77;
const ACTION_PASTE_CLIPBOARD: number = 78;
const CATALOG_PROJECT: number = 0;
const CATALOG_PORTAL: number = 1;
const CATALOG_COMPUTER: number = 2;
const CATALOG_FAVORITES: number = 3;
const CONTENTS_DRAWING_ORDER: number = 0;
const CONTENTS_SOURCE: number = 1;
const CONTENTS_SELECTION: number = 2;
const CONTENTS_LABELING: number = 3;
const CONTENTS_EDITING: number = 4;
const RIBBON_PROJECT: number = 0;
const RIBBON_MAP: number = 1;
const RIBBON_INSERT: number = 2;
const RIBBON_ANALYSIS: number = 3;
const RIBBON_VIEW: number = 4;
const RIBBON_EDIT: number = 5;
const RIBBON_IMAGERY: number = 6;
const RIBBON_SHARE: number = 7;
const MAP_VIEW_DATA: number = 0;
const MAP_VIEW_LAYOUT: number = 1;
const RIBBON_HELP: number = 8;
const WORK_AREA_GAP: number = 8;
const COMPACT_LAYOUT_MAX_WIDTH: number = 1000;
const COMPACT_LAYOUT_MAX_HEIGHT: number = 540;
const IMPORT_MAX_SELECT_NUMBER: number = 32;
const PROJECT_RECOVERY_INTERVAL_MS: number = 30000;
const IMMERSIVE_WINDOW_STATUS_KEY: string = 'gnImmersiveWindowStatus';
const EXTERNAL_FILE_URI_KEY: string = 'gnExternalFileUri';
const WINDOW_CLOSE_REQUEST_KEY: string = 'gnWindowCloseRequestRevision';
const SEARCH_CANDIDATE_KIND_COMMAND: number = 0;
const SEARCH_CANDIDATE_KIND_LAYER: number = 1;
const COMMAND_SEARCH_MAX_SUGGESTIONS: number = 8;
const COMMAND_SEARCH_MAX_LAYER_SUGGESTIONS: number = 4;
const LAYER_DRAG_TOKEN_PREFIX: string = 'geonest-layer-index:';

@Component
export struct GeoNestWorkbenchShell {
  @StorageLink(IMMERSIVE_WINDOW_STATUS_KEY) private immersiveWindowStatus: string = '沉浸窗口：等待窗口初始化';
  @StorageLink(EXTERNAL_FILE_URI_KEY) @Watch('onExternalFileUriChanged') private externalFileUri: string = '';
  @StorageLink(WINDOW_CLOSE_REQUEST_KEY) @Watch('onWindowCloseRequested') private windowCloseRequestRevision: number = 0;
  @State private rightPanelIndex: number = 0;
  @State private projectState: number = 1;
  @State @Watch('onProjectDirtyChanged') private projectDirty: boolean = false;
  @State private projectFileUri: string = '';
  @State private projectFileName: string = '未保存工程';
  @State private projectName: string = '未命名工程';
  @State private projectOwner: string = '';
  @State private projectCrs: string = '';
  @State private projectMapName: string = '地图';
  @State private projectWorkspaceName: string = '默认工作空间';
  @State private projectDescription: string = '';
  @State private recentProjects: RecentProjectRecord[] = [];
  @State private recentProjectRevision: number = 0;
  @State private selectedLayerIndex: number = -1;
  @State private activeLayerRevision: number = 0;
  @State private nativeBridgeAvailable: boolean = false;
  @State private nativeBridgeVersion: string = '';
  @State private nativeBridgeProfile: string = '';
  @State private selectedFeatureId: string = '';
  @State private selectedFeatureIds: string[] = [];
  @State private selectedFeatureAttrs: GisAttributeValue[] = [];
  @State private selectedFeatureLayerName: string = '';
  @State private selectedFeatureLayerIndex: number = -1;
  @State private selectedFeatureGeomType: number = 0;
  @State private selectedFeatureRevision: number = 0;
  @State private showFeaturePanel: boolean = false;
  @State private layerCount: number = 0;
  @State private totalFeatures: number = 0;
  @State private viewportCenterX: string = '0.5000';
  @State private viewportCenterY: string = '0.5000';
  @State private viewportCoordinateText: string = '0.5000, 0.5000';
  @State private viewportScale: string = 'CRS 未声明';
  @State private mapUnitsPerPixel: number = 1;
  @State private mapReferenceStatus: string = 'CRS 未声明';
  @State private renderKey: number = 0;
  @State private mapCommand: number = MAP_COMMAND_NONE;
  @State private mapCommandKey: number = 0;
  @State private mapToolMode: number = MAP_TOOL_IDENTIFY;
  @State private measurementStatus: string = '';
  @State private dataLoadStatus: string = '';
  @State private editStatus: string = '';
  @State private basemapStatus: string = '';
  @State private basemapMode: number = BASEMAP_VECTOR;
  @State private scene3DVisible: boolean = false;
  @State private basemapDatumMode: number = BASEMAP_DATUM_AUTO;
  @State private layerPanelVisible: boolean = true;
  @State private layerPanelCollapsed: boolean = false;
  @State private rightDockVisible: boolean = true;
  @State private rightDockCollapsed: boolean = false;
  @State private backstageVisible: boolean = false;
  @State private isWindowTopmost: boolean = false;
  @State private hoverLayerIndex: number = -1;
  @State private backstageSection: number = BACKSTAGE_INFO;
  @State private catalogSection: number = CATALOG_PROJECT;
  @State private contentsSection: number = CONTENTS_DRAWING_ORDER;
  @State private activeRibbonTab: number = RIBBON_MAP;
  @State private mapViewMode: number = MAP_VIEW_DATA;
  @State private compactLayout: boolean = false;
  @State private commandSearchText: string = '';
  @State private commandSearchSuggestionsVisible: boolean = false;
  @State private contentsSearchText: string = '';
  @State private catalogSearchText: string = '';
  @State private toolSearchText: string = '';
  @StorageLink(APP_MATERIAL_ENABLED_KEY) private materialEnabled: boolean = true;
  @StorageLink(APP_MATERIAL_QUALITY_KEY) private materialQuality: number = 1;
  @StorageLink(APP_INTERFACE_DENSITY_KEY) private interfaceDensity: number = 0;
  @StorageLink(APP_OPEN_SIDE_PANES_KEY) private openSidePanesOnStartup: boolean = true;
  @StorageLink(APP_MAP_RENDER_QUALITY_KEY) private mapRenderQuality: number = 1;
  @StorageLink(APP_FRAME_PACING_KEY) private framePacing: number = 1;
  @StorageLink(APP_CACHE_STRATEGY_KEY) private cacheStrategy: number = 1;
  @StorageLink(APP_PROGRESSIVE_LOADING_KEY) private progressiveLoading: boolean = true;
  @StorageLink(APP_POINTER_SMOOTHING_KEY) private pointerSmoothing: boolean = true;
  @StorageLink(APP_FLOATING_TAB_MATERIAL_KEY) private floatingTabMaterial: boolean = true;
  @StorageLink(APP_MOUSE_SCROLL_OPTIMIZATION_KEY) private mouseScrollOptimization: boolean = true;
  @StorageLink('userLoggedIn') private userLoggedIn: boolean = false;
  @StorageLink('userAvatarUri') private userAvatarUri: string = '';
  @StorageLink('userNickName') private userNickName: string = '';
  @StorageLink(GN_LAYER_REVISION_KEY) private sharedLayerRevision: number = 0;
  @StorageLink(GN_MULTI_MAP_LINK_ENABLED_KEY) private linkedMapViewEnabled: boolean = true;
  @StorageLink(GN_MULTI_MAP_VIEWPORT_REVISION_KEY) @Watch('onLinkedViewportStorageChanged')
  private linkedViewportRevision: number = 0;
  @StorageLink(GN_MULTI_MAP_VIEWPORT_CENTER_X_KEY) private linkedViewportCenterX: number = 0.5;
  @StorageLink(GN_MULTI_MAP_VIEWPORT_CENTER_Y_KEY) private linkedViewportCenterY: number = 0.5;
  @StorageLink(GN_MULTI_MAP_VIEWPORT_SCALE_KEY) private linkedViewportScale: number = 100.0;
  @StorageLink(GN_MULTI_MAP_VIEWPORT_SOURCE_KEY) private linkedViewportSource: string = '';
  @State private mapViewportApplyRevision: number = 0;
  @State private dragDropActive: boolean = false;

  private gisService = getGisService();
  private cloudSyncManager: GeoNestCloudSyncManager = GeoNestCloudSyncManager.getInstance();
  private searchViewModel: WorkbenchSearchViewModel = new WorkbenchSearchViewModel();
  private layerPresentationCoordinator: WorkbenchLayerPresentationCoordinator =
    new WorkbenchLayerPresentationCoordinator();
  private gestureShareModel: GestureShareModel | null = null;
  private secondaryMapWindow: window.Window | undefined = undefined;
  private localViewportSourceId: string = 'main';
  private mapThumbnailCapturePending: boolean = false;
  private mapThumbnailLastCaptureTime: number = 0;
  private mapThumbnailCaptureToken: number = 0;
  @State private projectInfoTrigger: boolean = false;
  @State private newProjectTrigger: boolean = false;
  @State private attributeTableTrigger: boolean = false;
  @State private symbologyTrigger: boolean = false;
  @State private vectorEditTrigger: boolean = false;
  @State private attributeEditTrigger: boolean = false;
  @State private labelingTrigger: boolean = false;
  @State private rasterDisplayTrigger: boolean = false;
  @State private mapLayoutTrigger: boolean = false;
  @State private printTrigger: boolean = false;
  @State private clipToolTrigger: boolean = false;
  @State private bufferToolTrigger: boolean = false;
  @State private repairToolTrigger: boolean = false;
  @State private exportToolTrigger: boolean = false;
  @State private defineProjectionTrigger: boolean = false;
  @State private projectLayerTrigger: boolean = false;
  @State private simplifyToolTrigger: boolean = false;
  @State private dissolveToolTrigger: boolean = false;
  @State private centroidToolTrigger: boolean = false;
  @State private advancedToolTrigger: boolean = false;
  @State private advancedToolMode: number = GIS_TOOL_MODE_CONVEX_HULL;
  @State private processingBrowserTrigger: boolean = false;
  @State private expressionWorkbenchTrigger: boolean = false;
  @State private xyTableToPointTrigger: boolean = false;
  @State private topologyReviewTrigger: boolean = false;
  @State private topologySourceLayerIndex: number = -1;
  @State private topologyErrorLayerIndex: number = -1;
  @State private topologyRequiredFields: string = '';
  @State private portableProjectTrigger: boolean = false;
  @State private layoutAtlasTrigger: boolean = false;
  @State private qgisCoreTrigger: boolean = false;
  @State private appSettingsTrigger: boolean = false;
  @State private cloudSyncSheetVisible: boolean = false;
  @State private cloudSyncStatusText: string = '云空间同步未初始化';
  @State private cloudSyncProjectText: string = '云空间中尚未找到工程包';
  @State private cloudSyncTimeText: string = '从未同步';
  @State private cloudSyncActionText: string = '未执行';
  @State private cloudSyncLogs: string[] = [];
  @State private openSourceNoticesExpanded: boolean = false;
  @State private openSourceNotices: string = '';
  @State private recoveryPointAvailable: boolean = false;

  private recoveryManager: ProjectRecoveryManager = new ProjectRecoveryManager();
  private recoveryTimer: number = -1;
  private recoveryInitialized: boolean = false;
  private startupWorkspaceHandled: boolean = false;
  private closeDialogShowing: boolean = false;
  private recoveryPromptActive: boolean = false;
  private handledWindowCloseRevision: number = 0;

  aboutToAppear(): void {
    this.layerPanelVisible = this.openSidePanesOnStartup;
    this.rightDockVisible = this.openSidePanesOnStartup;
    this.layerPanelCollapsed = false;
    this.rightDockCollapsed = false;
    this.loadRecentProjects();
    this.refreshNativeBridgeStatus();
    this.loadOpenSourceNotices();
    this.initializeRecoveryProtection();
    this.initializeGestureShare();
    if (this.windowCloseRequestRevision > this.handledWindowCloseRevision) {
      this.onWindowCloseRequested();
      return;
    }
    if (this.startupWorkspaceHandled) {
      return;
    }
    this.startupWorkspaceHandled = true;
    if (this.showRecoveryPromptIfNeeded()) {
      return;
    }
    if (this.consumeExternalFileUri()) {
      return;
    }
    this.loadDefaultStartupWorkspace();
  }

  aboutToDisappear(): void {
    this.stopRecoveryTimer();
    if (this.gestureShareModel !== null) {
      this.gestureShareModel.stopListening();
    }
  }

  private initializeGestureShare(): void {
    if (this.gestureShareModel !== null) {
      return;
    }
    this.gestureShareModel = GestureShareModel.getInstance(getContext(this) as common.UIAbilityContext);
    this.gestureShareModel.setLayerProvider(
      () => {
        let layer = this.gisService.getActiveLayer();
        return layer !== undefined ? layer.sourcePath : '';
      },
      () => {
        let layer = this.gisService.getActiveLayer();
        return layer !== undefined ? layer.info.name : '';
      }
    );
    this.gestureShareModel.startListening();
  }

  private loadDefaultStartupWorkspace(): void {
    if (!this.loadTransferredLayerIfAvailable()) {
      this.loadBundledShanxiLayer();
    }
  }

  private initializeRecoveryProtection(): void {
    if (!this.recoveryInitialized) {
      let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      this.recoveryManager.init(context);
      this.recoveryInitialized = true;
    }
    if (this.recoveryTimer < 0) {
      this.recoveryTimer = setInterval(() => {
        this.saveRecoverySnapshot();
      }, PROJECT_RECOVERY_INTERVAL_MS);
    }
  }

  private stopRecoveryTimer(): void {
    if (this.recoveryTimer >= 0) {
      clearInterval(this.recoveryTimer);
      this.recoveryTimer = -1;
    }
  }

  private onProjectDirtyChanged(): void {
    if (!this.recoveryInitialized) {
      return;
    }
    if (this.projectDirty) {
      this.saveRecoverySnapshot();
    } else {
      this.recoveryManager.clear();
      this.recoveryPointAvailable = false;
    }
  }

  private saveRecoverySnapshot(): void {
    if (!this.recoveryInitialized || !this.projectDirty) {
      return;
    }
    let saved: boolean = this.recoveryManager.save(
      this.buildProjectText(),
      this.projectFileUri,
      this.projectFileName,
      this.projectName,
      this.projectState,
      this.gisService.hasPendingEditChanges()
    );
    if (saved) {
      this.recoveryPointAvailable = true;
    }
  }

  private showRecoveryPromptIfNeeded(): boolean {
    if (!this.recoveryInitialized) {
      return false;
    }
    let snapshot: ProjectRecoverySnapshot | null = this.recoveryManager.load();
    if (snapshot === null) {
      return false;
    }
    this.recoveryPointAvailable = true;
    this.recoveryPromptActive = true;
    this.getUIContext().showAlertDialog({
      title: $r('app.string.gn_recovery_dialog_title'),
      message: $r('app.string.gn_recovery_dialog_message'),
      autoCancel: false,
      buttons: [
        {
          value: $r('app.string.gn_recovery_restore'),
          action: () => {
            this.recoveryPromptActive = false;
            this.externalFileUri = '';
            this.restoreRecoverySnapshot(snapshot as ProjectRecoverySnapshot);
          }
        },
        {
          value: $r('app.string.gn_recovery_discard'),
          action: () => {
            this.recoveryPromptActive = false;
            this.recoveryManager.clear();
            this.recoveryPointAvailable = false;
            if (!this.consumeExternalFileUri()) {
              this.loadDefaultStartupWorkspace();
            }
          }
        }
      ]
    });
    return true;
  }

  private restoreRecoverySnapshot(snapshot: ProjectRecoverySnapshot): void {
    let loadUri: string = snapshot.projectUri;
    if (loadUri.length === 0) {
      loadUri = this.recoveryManager.path();
    }
    this.loadProjectFromText(loadUri, snapshot.projectText, false);
    this.projectFileUri = snapshot.projectUri;
    if (snapshot.projectFileName.length > 0) {
      this.projectFileName = snapshot.projectFileName;
    }
    this.projectState = snapshot.projectState;
    this.projectDirty = true;
    this.recoveryPointAvailable = true;
    if (snapshot.hadPendingEdits) {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.gn_recovery_restored_pending_edits'), duration: 2600
      });
    } else {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.gn_recovery_restored'), duration: 1800
      });
    }
  }

  private loadOpenSourceNotices(): void {
    try {
      let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      let data: Uint8Array = context.resourceManager.getRawFileContentSync('OPEN_SOURCE_NOTICES.txt');
      let decoder = util.TextDecoder.create('utf-8');
      this.openSourceNotices = decoder.decodeToString(data);
    } catch (e) {
      this.openSourceNotices =
        '完整许可证和对应源码说明位于发布目录中的 COPYING、THIRD_PARTY_NOTICES.md、' +
          'SOURCE_OFFER.txt 与 SOURCE-MANIFEST.txt。';
      hilog.warn(LOG_TAG, LOG_DOMAIN, 'loadOpenSourceNotices: bundled notice unavailable');
    }
  }

  private onExternalFileUriChanged(): void {
    if (this.recoveryPromptActive) {
      return;
    }
    this.consumeExternalFileUri();
  }

  private onWindowCloseRequested(): void {
    if (this.windowCloseRequestRevision > this.handledWindowCloseRevision) {
      this.handledWindowCloseRevision = this.windowCloseRequestRevision;
      this.windowClose();
    }
  }

  private consumeExternalFileUri(): boolean {
    let uri = this.externalFileUri.trim();
    if (uri.length === 0) {
      return false;
    }
    this.externalFileUri = '';
    this.openExternalFileUri(uri);
    return true;
  }

  private openExternalFileUri(uri: string): void {
    if (uri.indexOf('\n') >= 0) {
      let uris: string[] = uri.split('\n');
      let filtered: string[] = [];
      for (let i: number = 0; i < uris.length; i++) {
        let trimmed: string = uris[i].trim();
        if (trimmed.length > 0) {
          filtered.push(trimmed);
        }
      }
      if (filtered.length > 0) {
        this.openFilesFromUris(filtered);
      }
      return;
    }

    let fileName = this.extractFileName(uri);
    let displayName = this.displayFileName(fileName);
    let ext = this.fileExtension(fileName);
    if ((ext === 'gnproj' || this.isQgisProjectExtension(ext)) && !this.canReplaceCurrentWorkspace()) {
      return;
    }
    if (ext === 'gnproj') {
      let content = this.readTextFromUri(uri);
      if (content.length > 0) {
        this.loadProjectFromText(uri, content);
        this.dataLoadStatus = '已打开工程：' + displayName;
      } else {
        this.dataLoadStatus = '工程文件无法读取：' + displayName;
      }
      return;
    }
    this.openFileFromUri(uri);
  }

  // Copy rawfile SHP data to sandbox on startup
  private prepareDemoData(): void {
    try {
      let ctx = getContext(this);
      let rm = ctx.resourceManager;
      let sandboxDir = ctx.filesDir + '/geonest_data';
      hilog.info(LOG_TAG, LOG_DOMAIN, 'prepareDemoData: sandboxDir=%{public}s', sandboxDir);
      try { fs.mkdirSync(sandboxDir); } catch (e) { /* exists */ }

      let files: string[] = [
        '140000.shp', '140000.shx', '140000.dbf', '140000.prj',
        '140800.shp', '140800.shx', '140800.dbf', '140800.prj',
        'landuse.shp', 'landuse.shx', 'landuse.dbf', 'landuse.prj', 'landuse.cpg',
        'road_centerline.shp', 'road_centerline.shx', 'road_centerline.dbf', 'road_centerline.prj',
        'check_points.shp', 'check_points.shx', 'check_points.dbf', 'check_points.prj'
      ];

      let copiedCount = 0;
      for (let i = 0; i < files.length; i++) {
        try {
          let data: Uint8Array = rm.getRawFileContentSync(files[i]);
          let outPath = sandboxDir + '/' + files[i];
          let fd = fs.openSync(outPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
          fs.writeSync(fd.fd, data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength));
          fs.closeSync(fd);
          copiedCount++;
        } catch (e) {
          hilog.warn(LOG_TAG, LOG_DOMAIN, 'prepareDemoData: skip %{public}s', files[i]);
        }
      }
      hilog.info(LOG_TAG, LOG_DOMAIN, 'prepareDemoData: copied %{public}d/%{public}d files', copiedCount, files.length);
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'prepareDemoData: EXCEPTION: %{public}s', String(e));
    }
  }

  private loadTransferredLayerIfAvailable(): boolean {
    let idx = this.gisService.openLayer(TRANSFERRED_SHANXI_SHP);
    hilog.info(LOG_TAG, LOG_DOMAIN, 'loadTransferredLayerIfAvailable: openLayer result=%{public}d', idx);
    if (idx >= 0) {
      this.selectedLayerIndex = idx;
      this.gisService.setActiveLayerIndex(idx);
      this.projectState = 1;
      this.projectDirty = true;
      this.refreshLayerState();
      return true;
    }
    return false;
  }

  private loadBundledShanxiLayer(): void {
    this.prepareDemoData();
    let ctx = getContext(this);
    let sandboxDir = ctx.filesDir + '/geonest_data';
    let shpPath = sandboxDir + '/140000.shp';
    let idx = this.gisService.openLayer(shpPath);
    hilog.info(LOG_TAG, LOG_DOMAIN, 'loadBundledShanxiLayer: openLayer result=%{public}d', idx);
    if (idx >= 0) {
      this.selectedLayerIndex = idx;
      this.gisService.setActiveLayerIndex(idx);
      this.projectState = 1;
      this.projectDirty = false;
      this.refreshLayerState();
    }
  }

  @Builder
  symbol(icon: Resource, color: ResourceColor, sizeValue: number) {
    SymbolGlyph(icon)
      .fontSize(sizeValue)
      .fontColor([color])
  }

  private openWorkspaceDialog(dialogId: number): void {
    if (dialogId === 1) {
      this.projectInfoTrigger = !this.projectInfoTrigger;
    } else if (dialogId === 2) {
      this.attributeTableTrigger = !this.attributeTableTrigger;
    } else if (dialogId === 3) {
      this.clipToolTrigger = !this.clipToolTrigger;
    } else if (dialogId === 4) {
      this.symbologyTrigger = !this.symbologyTrigger;
    } else if (dialogId === 5) {
      this.bufferToolTrigger = !this.bufferToolTrigger;
    } else if (dialogId === 6) {
      this.repairToolTrigger = !this.repairToolTrigger;
    } else if (dialogId === 7) {
      this.exportToolTrigger = !this.exportToolTrigger;
    } else if (dialogId === 8) {
      this.qgisCoreTrigger = !this.qgisCoreTrigger;
    } else if (dialogId === 9) {
      this.vectorEditTrigger = !this.vectorEditTrigger;
    } else if (dialogId === 10) {
      this.attributeEditTrigger = !this.attributeEditTrigger;
    } else if (dialogId === 11) {
      this.labelingTrigger = !this.labelingTrigger;
    } else if (dialogId === 12) {
      this.rasterDisplayTrigger = !this.rasterDisplayTrigger;
    } else if (dialogId === 13) {
      this.mapLayoutTrigger = !this.mapLayoutTrigger;
    } else if (dialogId === 14) {
      this.newProjectTrigger = !this.newProjectTrigger;
    } else if (dialogId === 15) {
      this.printTrigger = !this.printTrigger;
    } else if (dialogId === 16) {
      this.defineProjectionTrigger = !this.defineProjectionTrigger;
    } else if (dialogId === 17) {
      this.projectLayerTrigger = !this.projectLayerTrigger;
    } else if (dialogId === 18) {
      this.expressionWorkbenchTrigger = !this.expressionWorkbenchTrigger;
    }
  }

  private refreshNativeBridgeStatus(): void {
    let status: GisNativeBridgeStatus = queryGisNativeBridgeStatus();
    this.nativeBridgeAvailable = status.available;
    this.nativeBridgeVersion = status.version;
    this.nativeBridgeProfile = status.profile;
  }

  private refreshLayerState(): void {
    this.layerCount = this.gisService.getLayerCount();
    this.totalFeatures = this.gisService.getTotalFeatureCount();
    let first = this.firstVisibleLayer();
    if (this.projectCrs.length === 0 && first !== undefined && first.info.crs.length > 0) {
      this.projectCrs = first.info.crs;
    }
    this.mapReferenceStatus = this.currentMapReferenceText();
    this.activeLayerRevision++;
    this.renderKey++;
    let layerRevision: number | undefined = AppStorage.get<number>(GN_LAYER_REVISION_KEY);
    AppStorage.setOrCreate<number>(GN_LAYER_REVISION_KEY, layerRevision === undefined ? 1 : layerRevision + 1);
    if (this.selectedLayerIndex >= this.layerCount) {
      this.selectedLayerIndex = this.layerCount - 1;
    }
    this.refreshServiceWidgetState();
    this.scheduleMapThumbnailCapture(false);
  }

  private refreshServiceWidgetState(): void {
    try {
      let ctx: common.UIAbilityContext | null = this.currentAbilityContext();
      if (ctx === null) {
        return;
      }
      let previousState: GeoNestFormState = GeoNestFormStateStore.getInstance().readState(ctx.filesDir);
      let state: GeoNestFormState = new GeoNestFormState();
      state.projectName = this.projectName.length > 0 ? this.projectName : '未命名工程';
      state.projectFileName = this.projectFileName.length > 0 ? this.projectFileName : '未保存工程';
      if (this.layerCount > 0) {
        state.layerSummary = this.layerCount.toString() + ' 个图层 · ' + this.totalFeatures.toString() + ' 个要素';
        state.thumbnailUri = previousState.thumbnailUri;
      } else {
        state.layerSummary = '暂无图层';
        state.thumbnailUri = '';
      }
      state.cloudStatus = this.serviceWidgetCloudStatus();
      state.processingStatus = this.serviceWidgetProcessingStatus();
      state.actionHint = '打开工程 · 添加数据 · 继续上次工作';
      state.updatedAt = Date.now();
      GeoNestFormStateStore.getInstance().writeState(ctx.filesDir, state);
      GeoNestFormStateStore.getInstance().updateKnownForms(ctx.filesDir);
    } catch (e) {
      hilog.warn(LOG_TAG, LOG_DOMAIN, 'refresh service widget state failed: %{public}s', String(e));
    }
  }

  private currentAbilityContext(): common.UIAbilityContext | null {
    let hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      return null;
    }
    return hostContext as common.UIAbilityContext;
  }

  private scheduleMapThumbnailCapture(force: boolean): void {
    if (this.layerCount <= 0) {
      return;
    }
    let now: number = Date.now();
    if (!force && now - this.mapThumbnailLastCaptureTime < MAP_THUMBNAIL_CAPTURE_INTERVAL_MS) {
      return;
    }
    if (this.mapThumbnailCapturePending) {
      return;
    }
    this.mapThumbnailCapturePending = true;
    this.mapThumbnailCaptureToken++;
    let token: number = this.mapThumbnailCaptureToken;
    setTimeout(() => {
      if (token !== this.mapThumbnailCaptureToken) {
        return;
      }
      this.captureMapThumbnail(force);
    }, MAP_THUMBNAIL_CAPTURE_DELAY_MS);
  }

  private async captureMapThumbnail(force: boolean): Promise<void> {
    this.mapThumbnailCapturePending = false;
    if (this.layerCount <= 0) {
      return;
    }
    let now: number = Date.now();
    if (!force && now - this.mapThumbnailLastCaptureTime < MAP_THUMBNAIL_CAPTURE_INTERVAL_MS) {
      return;
    }

    let pixelMap: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;
    try {
      let ctx: common.UIAbilityContext | null = this.currentAbilityContext();
      if (ctx === null) {
        return;
      }
      let snapshotOptions: componentSnapshot.SnapshotOptions = {
        scale: MAP_THUMBNAIL_CAPTURE_SCALE,
        waitUntilRenderFinished: true
      };
      pixelMap = await this.getUIContext().getComponentSnapshot().get(MAP_THUMBNAIL_CAPTURE_ID, snapshotOptions);
      packer = image.createImagePacker();
      let packOptions: image.PackingOption = {
        format: 'image/jpeg',
        quality: MAP_THUMBNAIL_JPEG_QUALITY
      };
      let thumbnailPath: string = ctx.filesDir + '/' + FORM_THUMBNAIL_FILE_NAME;
      let data: ArrayBuffer = await packer.packToData(pixelMap, packOptions);
      if (!this.writeArrayBufferToFile(thumbnailPath, data)) {
        return;
      }
      GeoNestFormStateStore.getInstance().updateThumbnail(ctx.filesDir, fileUri.getUriFromPath(thumbnailPath));
      this.mapThumbnailLastCaptureTime = Date.now();
    } catch (e) {
      hilog.warn(LOG_TAG, LOG_DOMAIN, 'capture map thumbnail failed: %{public}s', String(e));
    } finally {
      if (packer !== null) {
        try {
          await packer.release();
        } catch (_packerError) {
        }
      }
      if (pixelMap !== null) {
        try {
          await pixelMap.release();
        } catch (_pixelMapError) {
        }
      }
    }
  }

  private writeArrayBufferToFile(path: string, data: ArrayBuffer): boolean {
    return WorkbenchFileService.writeArrayBufferAtomic(path, data);
  }

  private serviceWidgetCloudStatus(): string {
    let status: GeoNestCloudSyncStatus = this.cloudSyncManager.getStatus();
    if (!status.supported) {
      return '当前设备未启用云空间同步';
    }
    if (!status.isLoggedIn) {
      return '请先登录华为账号';
    }
    if (status.isWorking) {
      return '云空间同步中';
    }
    if (status.lastAction === 'upload') {
      return '已上传 · ' + this.formatCloudSyncTime(status.lastSyncTime);
    }
    if (status.lastAction === 'pull') {
      return '已拉取 · ' + this.formatCloudSyncTime(status.lastSyncTime);
    }
    if (status.lastAction === 'failed') {
      return status.errorMessage.length > 0 ? '同步失败 · ' + status.errorMessage : '同步失败';
    }
    return status.projectName.length > 0 ? '云端工程：' + status.projectName : '云空间目录已就绪';
  }

  private serviceWidgetProcessingStatus(): string {
    let tasks: GisProcessingTaskSnapshot[] = this.gisService.activeProcessingTasks();
    if (tasks.length === 0) {
      return '暂无处理任务';
    }
    let snapshot: GisProcessingTaskSnapshot = tasks[0];
    let progress: number = Math.max(0, Math.min(100, Math.floor(snapshot.progress)));
    if (snapshot.cancelRequested) {
      return '正在取消 · ' + progress.toString() + '%';
    }
    let stageText: string = snapshot.stage.length > 0 ? snapshot.stage : snapshot.algorithmId;
    if (stageText.length === 0) {
      stageText = '后台处理';
    }
    return stageText + ' · ' + progress.toString() + '%';
  }

  private fileExtension(fileName: string): string {
    return WorkbenchTextService.fileExtension(fileName);
  }

  private isVectorOrTableFormat(ext: string): boolean {
    return WorkbenchTextService.isVectorOrTableFormat(ext);
  }

  private isRasterOrTileFormat(ext: string): boolean {
    return WorkbenchTextService.isRasterOrTileFormat(ext);
  }

  private isArchiveFormat(ext: string): boolean {
    return WorkbenchTextService.isArchiveFormat(ext);
  }

  // File picker: open local file picker directly
  private importShapefile(): void {
    this.importFromLocal();
  }

  private importFromLocal(): void {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      let opts: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = IMPORT_MAX_SELECT_NUMBER;
      documentPicker.select(opts).then((result: Array<string>) => {
        if (result.length > 0) {
          hilog.info(LOG_TAG, LOG_DOMAIN, 'importFromLocal: selected %{public}d files', result.length);
          this.openFilesFromUris(result);
        }
      }).catch(() => {
        hilog.warn(LOG_TAG, LOG_DOMAIN, 'importFromLocal: picker cancelled');
      });
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'importFromLocal: EXCEPTION');
    }
  }

  async handleCollaborationFile(stateCode: number, bufferType: string, buffer: ArrayBuffer): Promise<void> {
    if (stateCode !== 0 || buffer.byteLength === 0) {
      return;
    }
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let dir: string = ctx.filesDir + '/collab_files';
      try { fs.mkdirSync(dir, true); } catch (_) {}
      let ext: string = 'bin';
      if (bufferType.indexOf('image') >= 0) { ext = 'png'; }
      else if (bufferType.indexOf('video') >= 0) { ext = 'mp4'; }
      else if (bufferType.indexOf('json') >= 0) { ext = 'json'; }
      else if (bufferType.indexOf('csv') >= 0) { ext = 'csv'; }
      else if (bufferType.indexOf('shape') >= 0 || bufferType.indexOf('octet') >= 0) { ext = 'shp'; }
      else if (bufferType.indexOf('pdf') >= 0) { ext = 'pdf'; }
      let path: string = dir + '/collab_' + Date.now().toString() + '.' + ext;
      let file: fs.File = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, buffer);
      fs.closeSync(file);
      let uri: string = fileUri.getUriFromPath(path);
      this.openFilesFromUris([uri]);
      this.dataLoadStatus = '已从其他设备接收文件 (' + bufferType + ')';
      hilog.info(LOG_TAG, LOG_DOMAIN, 'handleCollaborationFile: type=%{public}s size=%{public}d', bufferType, buffer.byteLength);
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'handleCollaborationFile failed: ' + String(e));
    }
  }

  private fileBaseName(fileName: string): string {
    return WorkbenchTextService.fileBaseName(fileName);
  }

  private displayFileName(fileName: string): string {
    return WorkbenchTextService.displayFileName(fileName);
  }

  private safeImportPathSegment(text: string): string {
    return WorkbenchTextService.safePathSegment(text);
  }

  private copyUriToFile(uri: string, destinationPath: string): boolean {
    return WorkbenchFileService.copyUriToFile(uri, destinationPath);
  }

  private copyFileToUri(sourcePath: string, uri: string): boolean {
    return WorkbenchFileService.copyFileToUri(sourcePath, uri);
  }

  private createProjectSandboxDir(): string {
    return WorkbenchFileService.createProjectSandboxDir(getContext(this).filesDir);
  }

  private sandboxProjectPathForUri(uri: string): string {
    return WorkbenchFileService.sandboxProjectPathForUri(getContext(this).filesDir, uri,
      this.defaultProjectFileName());
  }

  private openFilesFromUris(uris: string[]): string {
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let coordinator: WorkbenchImportCoordinator = new WorkbenchImportCoordinator(context.filesDir,
      this.defaultProjectFileName(), this.gisService);
    let result: WorkbenchImportResult = coordinator.openFilesFromUris(uris);
    this.dataLoadStatus = result.status;
    if (result.opened) {
      this.selectedLayerIndex = result.selectedLayerIndex;
      this.projectState = 1;
      this.projectDirty = true;
      this.refreshLayerState();
    }
    return result.activeLayerName;
  }

  // Copy file from content URI to sandbox, then open with native bridge
  private openFileFromUri(uri: string): void {
    let uris: string[] = [uri];
    this.openFilesFromUris(uris);
  }

  private createLayerDragToken(layerIndex: number): string {
    return LAYER_DRAG_TOKEN_PREFIX + layerIndex.toString();
  }

  private parseLayerDragIndex(text: string): number {
    let candidate: string = text.trim();
    if (candidate.indexOf(LAYER_DRAG_TOKEN_PREFIX) !== 0) {
      return -1;
    }
    let valueText: string = candidate.substring(LAYER_DRAG_TOKEN_PREFIX.length).trim();
    if (valueText.length === 0) {
      return -1;
    }
    let value: number = Number(valueText);
    if (value !== value || value < 0 || value >= this.gisService.getLayerCount()) {
      return -1;
    }
    if (Math.floor(value) !== value) {
      return -1;
    }
    return value;
  }

  private createLayerDragItemInfo(event: DragEvent, layerIndex: number): DragItemInfo {
    if (layerIndex >= 0) {
      let token: string = this.createLayerDragToken(layerIndex);
      let plainText: unifiedDataChannel.PlainText = new unifiedDataChannel.PlainText();
      plainText.textContent = token;
      let data: unifiedDataChannel.UnifiedData = new unifiedDataChannel.UnifiedData(plainText);
      event.setData(data);
      event.dragBehavior = DragBehavior.MOVE;
      let dragItemInfo: DragItemInfo = {
        extraInfo: token
      };
      return dragItemInfo;
    }
    let emptyInfo: DragItemInfo = {
      extraInfo: ''
    };
    return emptyInfo;
  }

  private droppedLayerIndex(event: DragEvent, extraParams: string): number {
    let extraIndex: number = this.parseLayerDragIndex(extraParams);
    if (extraIndex >= 0) {
      return extraIndex;
    }
    try {
      let data: unifiedDataChannel.UnifiedData = event.getData();
      let records: unifiedDataChannel.UnifiedRecord[] = data.getRecords();
      for (let i: number = 0; i < records.length; i++) {
        let record: unifiedDataChannel.UnifiedRecord = records[i];
        if (record instanceof unifiedDataChannel.PlainText) {
          let indexFromText: number = this.parseLayerDragIndex(record.textContent);
          if (indexFromText >= 0) {
            return indexFromText;
          }
        } else {
          let value: unifiedDataChannel.ValueType = record.getValue();
          if (typeof value === 'string') {
            let indexFromValue: number = this.parseLayerDragIndex(value);
            if (indexFromValue >= 0) {
              return indexFromValue;
            }
          }
        }
      }
    } catch (e) {
      hilog.warn(LOG_TAG, LOG_DOMAIN, 'droppedLayerIndex: no readable drag data');
    }
    return -1;
  }

  private moveDraggedLayer(sourceIndex: number, targetIndex: number): boolean {
    if (sourceIndex < 0 || targetIndex < 0) {
      return false;
    }
    if (sourceIndex >= this.gisService.getLayerCount() || targetIndex >= this.gisService.getLayerCount()) {
      return false;
    }
    let moved: boolean = this.gisService.moveLayer(sourceIndex, targetIndex);
    if (!moved) {
      return false;
    }
    this.selectedLayerIndex = targetIndex;
    this.projectDirty = true;
    this.refreshLayerState();
    let layer: GisLoadedLayer | undefined = this.gisService.getLayer(targetIndex);
    let layerName: string = layer === undefined ? '图层' : layer.info.name;
    this.dataLoadStatus = '已调整图层顺序：' + layerName;
    promptAction.showToast({ message: this.dataLoadStatus, duration: 1400 });
    return true;
  }

  private handleLayerDrop(event: DragEvent, extraParams: string, targetIndex: number): void {
    let sourceIndex: number = this.droppedLayerIndex(event, extraParams);
    if (sourceIndex >= 0 && targetIndex >= 0) {
      if (this.moveDraggedLayer(sourceIndex, targetIndex)) {
        event.setResult(DragResult.DRAG_SUCCESSFUL);
      } else {
        event.setResult(DragResult.DRAG_FAILED);
      }
      return;
    }
    this.handleWorkbenchDrop(event, extraParams);
  }

  private appendDropUriCandidate(uris: string[], candidate: string): void {
    let trimmed: string = candidate.trim();
    if (trimmed.length === 0) {
      return;
    }
    if (trimmed.indexOf(LAYER_DRAG_TOKEN_PREFIX) === 0) {
      return;
    }
    let normalized: string = '';
    if (trimmed.indexOf('file://') === 0 || trimmed.indexOf('datashare://') === 0 ||
      trimmed.indexOf('content://') === 0 || trimmed.indexOf('/') === 0) {
      normalized = trimmed;
    }
    if (normalized.length === 0) {
      return;
    }
    for (let i: number = 0; i < uris.length; i++) {
      if (uris[i] === normalized) {
        return;
      }
    }
    uris.push(normalized);
  }

  private appendDropUriCandidatesFromText(text: string, uris: string[]): void {
    let lines: string[] = text.split('\n');
    for (let i: number = 0; i < lines.length; i++) {
      this.appendDropUriCandidate(uris, lines[i]);
    }
  }

  private extractDropUris(event: DragEvent): string[] {
    let uris: string[] = [];
    try {
      let data: unifiedDataChannel.UnifiedData = event.getData();
      let records: unifiedDataChannel.UnifiedRecord[] = data.getRecords();
      for (let i: number = 0; i < records.length; i++) {
        let record: unifiedDataChannel.UnifiedRecord = records[i];
        if (record instanceof unifiedDataChannel.File) {
          this.appendDropUriCandidate(uris, record.uri);
        } else if (record instanceof unifiedDataChannel.PlainText) {
          this.appendDropUriCandidatesFromText(record.textContent, uris);
        } else {
          let value: unifiedDataChannel.ValueType = record.getValue();
          if (typeof value === 'string') {
            this.appendDropUriCandidate(uris, value);
          }
        }
      }
    } catch (e) {
      hilog.warn(LOG_TAG, LOG_DOMAIN, 'extractDropUris: no readable drag data');
    }
    return uris;
  }

  private handleWorkbenchDrop(event: DragEvent, extraParams: string): void {
    let layerIndex: number = this.droppedLayerIndex(event, extraParams);
    if (layerIndex >= 0) {
      event.setResult(DragResult.DRAG_SUCCESSFUL);
      return;
    }
    let uris: string[] = this.extractDropUris(event);
    if (uris.length === 0) {
      this.dataLoadStatus = '拖拽内容中没有可识别的 GIS 文件 URI';
      event.setResult(DragResult.DRAG_FAILED);
      return;
    }
    let layerName: string = this.openFilesFromUris(uris);
    if (layerName.length > 0) {
      this.dataLoadStatus = '已从拖拽导入：' + layerName;
      event.setResult(DragResult.DRAG_SUCCESSFUL);
      promptAction.showToast({ message: this.dataLoadStatus, duration: 1600 });
    } else {
      event.setResult(DragResult.DRAG_FAILED);
    }
  }

  private parseClipboardCoordinate(text: string): ClipboardCoordinateCandidate {
    return WorkbenchTextService.parseClipboardCoordinate(text);
  }

  private activeLayerSourceUri(): string {
    let layer: GisLoadedLayer | undefined = this.gisService.getActiveLayer();
    if (layer === undefined) {
      return '';
    }
    let sourcePath: string = this.gisService.tablePhysicalPath(layer.sourcePath);
    if (sourcePath.indexOf('file://') === 0 || sourcePath.indexOf('datashare://') === 0 ||
      sourcePath.indexOf('content://') === 0) {
      return sourcePath;
    }
    if (sourcePath.indexOf('/') === 0) {
      try {
        return fileUri.getUriFromPath(sourcePath);
      } catch (e) {
        hilog.warn(LOG_TAG, LOG_DOMAIN, 'activeLayerSourceUri: failed to convert file path');
      }
    }
    return '';
  }

  private mapClipboardText(): string {
    let text: string = 'GeoNest Map\n';
    text += 'Project: ' + this.projectName + '\n';
    text += 'Coordinate: ' + this.viewportCenterX + ', ' + this.viewportCenterY + '\n';
    text += 'Scale: ' + this.viewportScale + '\n';
    text += 'CRS: ' + (this.projectCrs.length > 0 ? this.projectCrs : this.mapReferenceStatus) + '\n';
    let layer: GisLoadedLayer | undefined = this.gisService.getActiveLayer();
    if (layer !== undefined) {
      text += 'Layer: ' + layer.info.name + '\n';
      text += 'Source: ' + layer.sourcePath + '\n';
    }
    return text;
  }

  private async copyMapContextToPasteboard(): Promise<void> {
    try {
      let text: string = this.mapClipboardText();
      let data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      let uri: string = this.activeLayerSourceUri();
      if (uri.length > 0) {
        data.addRecord(pasteboard.MIMETYPE_TEXT_URI, uri);
      }
      let systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(data);
      this.dataLoadStatus = '已复制地图坐标、比例尺和活动图层 URI 到剪贴板';
      promptAction.showToast({ message: '已复制 GeoNest 地图上下文', duration: 1500 });
    } catch (e) {
      this.dataLoadStatus = '复制到剪贴板失败';
      hilog.error(LOG_TAG, LOG_DOMAIN, 'copyMapContextToPasteboard failed: %{public}s', String(e));
    }
  }

  private collectPasteboardUris(data: pasteboard.PasteData): string[] {
    let uris: string[] = [];
    let primaryUri: string = data.getPrimaryUri();
    this.appendDropUriCandidate(uris, primaryUri);
    let recordCount: number = data.getRecordCount();
    for (let i: number = 0; i < recordCount; i++) {
      let record: pasteboard.PasteDataRecord = data.getRecord(i);
      this.appendDropUriCandidate(uris, record.uri);
      this.appendDropUriCandidate(uris, record.plainText);
      let recordText: string = record.toPlainText();
      this.appendDropUriCandidatesFromText(recordText, uris);
    }
    return uris;
  }

  private pasteClipboardCoordinate(candidate: ClipboardCoordinateCandidate): void {
    if (!candidate.found) {
      return;
    }
    let scale: number = this.mapUnitsPerPixel > 0.000000001 ? 1.0 / this.mapUnitsPerPixel : 100.0;
    AppStorage.setOrCreate<number>(GN_MULTI_MAP_VIEWPORT_CENTER_X_KEY, candidate.x);
    AppStorage.setOrCreate<number>(GN_MULTI_MAP_VIEWPORT_CENTER_Y_KEY, candidate.y);
    AppStorage.setOrCreate<number>(GN_MULTI_MAP_VIEWPORT_SCALE_KEY, scale);
    AppStorage.setOrCreate<string>(GN_MULTI_MAP_VIEWPORT_SOURCE_KEY, this.localViewportSourceId);
    let revision: number | undefined = AppStorage.get<number>(GN_MULTI_MAP_VIEWPORT_REVISION_KEY);
    AppStorage.setOrCreate<number>(GN_MULTI_MAP_VIEWPORT_REVISION_KEY, revision === undefined ? 1 : revision + 1);
    this.linkedViewportCenterX = candidate.x;
    this.linkedViewportCenterY = candidate.y;
    this.linkedViewportScale = scale;
    this.mapViewportApplyRevision++;
    this.dataLoadStatus = '已定位到剪贴板坐标：' + candidate.x.toFixed(6) + ', ' + candidate.y.toFixed(6);
    promptAction.showToast({ message: this.dataLoadStatus, duration: 1600 });
  }

  private async pasteFromSystemPasteboard(): Promise<void> {
    try {
      let systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      let data: pasteboard.PasteData = await systemPasteboard.getData();
      let uris: string[] = this.collectPasteboardUris(data);
      if (uris.length > 0) {
        let layerName: string = this.openFilesFromUris(uris);
        if (layerName.length > 0) {
          this.dataLoadStatus = '已从剪贴板导入：' + layerName;
          promptAction.showToast({ message: this.dataLoadStatus, duration: 1600 });
        }
        return;
      }
      let text: string = data.getPrimaryText();
      let coordinate: ClipboardCoordinateCandidate = this.parseClipboardCoordinate(text);
      if (coordinate.found) {
        this.pasteClipboardCoordinate(coordinate);
      } else {
        this.dataLoadStatus = '剪贴板没有可识别的 GIS 文件 URI 或坐标';
        promptAction.showToast({ message: this.dataLoadStatus, duration: 1500 });
      }
    } catch (e) {
      this.dataLoadStatus = '读取剪贴板失败，请确认已授权读取剪贴板';
      hilog.error(LOG_TAG, LOG_DOMAIN, 'pasteFromSystemPasteboard failed: %{public}s', String(e));
    }
  }

  private toggleLinkedMapView(): void {
    this.linkedMapViewEnabled = !this.linkedMapViewEnabled;
    AppStorage.setOrCreate<boolean>(GN_MULTI_MAP_LINK_ENABLED_KEY, this.linkedMapViewEnabled);
    this.dataLoadStatus = this.linkedMapViewEnabled ? '多地图视图联动已开启' : '多地图视图联动已关闭';
    promptAction.showToast({ message: this.dataLoadStatus, duration: 1400 });
  }

  private async openSecondaryMapWindow(): Promise<void> {
    try {
      if (this.secondaryMapWindow !== undefined) {
        await this.secondaryMapWindow.showWindow();
        this.dataLoadStatus = '第二地图窗口已打开';
        return;
      }
      let ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      let mapWindow: window.Window = await ctx.windowStage.createSubWindow('GeoNestSecondMap');
      this.secondaryMapWindow = mapWindow;
      try {
        await mapWindow.setReceiveDragEventEnabled(true);
      } catch (dragErr) {
        hilog.warn(LOG_TAG, LOG_DOMAIN, 'secondary map drag receive unavailable: %{public}s', String(dragErr));
      }
      mapWindow.on('subWindowClose', () => {
        this.secondaryMapWindow = undefined;
      });
      await mapWindow.setWindowTitle('GeoNest 第二地图');
      await mapWindow.resize(900, 640);
      await mapWindow.moveWindowTo(120, 120);
      await mapWindow.setUIContent('pages/MapCompare');
      await mapWindow.showWindow();
      this.dataLoadStatus = '第二地图窗口已打开，可与主地图联动浏览';
      promptAction.showToast({ message: '第二地图窗口已打开', duration: 1400 });
    } catch (e) {
      this.secondaryMapWindow = undefined;
      this.dataLoadStatus = '第二地图窗口打开失败';
      hilog.error(LOG_TAG, LOG_DOMAIN, 'openSecondaryMapWindow failed: %{public}s', String(e));
    }
  }

  private chooseLocalLayerForTool(fieldIndex: number, onSelected: (layerName: string) => void): void {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      let opts: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = IMPORT_MAX_SELECT_NUMBER;
      documentPicker.select(opts).then((result: Array<string>) => {
        if (result.length > 0) {
          let layerName = this.openFilesFromUris(result);
          if (layerName.length > 0) {
            onSelected(layerName);
            this.dataLoadStatus = (fieldIndex === 0 ? '已选择输入图层：' : '已选择裁剪图层：') + layerName;
          }
        }
      }).catch(() => {
        hilog.warn(LOG_TAG, LOG_DOMAIN, 'chooseLocalLayerForTool: picker cancelled');
      });
    } catch (e) {
      this.dataLoadStatus = '本地文件选择失败';
      hilog.error(LOG_TAG, LOG_DOMAIN, 'chooseLocalLayerForTool: EXCEPTION');
    }
  }

  // Reload data from sandbox (already copied by prepareDemoData)
  private reloadFromSandbox(): void {
    let ctx = getContext(this);
    let sandboxDir = ctx.filesDir + '/geonest_data';
    let idx = this.gisService.openLayer(sandboxDir + '/140800.shp');
    let idx2 = this.gisService.openLayer(sandboxDir + '/landuse.shp');
    if (idx >= 0) {
      this.selectedLayerIndex = idx;
      this.gisService.setActiveLayerIndex(idx);
    } else if (idx2 >= 0) {
      this.selectedLayerIndex = idx2;
      this.gisService.setActiveLayerIndex(idx2);
    }
    this.projectState = 1;
    this.projectDirty = true;
    this.refreshLayerState();
  }

  // Reload demo data from sandbox
  private loadDemoLayers(): void {
    this.prepareDemoData();
    this.reloadFromSandbox();
  }

  private async handleHuaweiLogin(): Promise<void> {
    if (this.userLoggedIn) {
      return;
    }
    try {
      let uiContext: UIContext = this.getUIContext();
      let ctx = uiContext.getHostContext() as common.UIAbilityContext;
      HuaweiAuthManager.getInstance().setContext(ctx);
      await HuaweiAuthManager.getInstance().login(uiContext);
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'Login failed: ' + String(e));
    }
  }

  private async handleHuaweiLogout(): Promise<void> {
    if (!this.userLoggedIn) {
      promptAction.showToast({ message: '当前未登录华为账号' });
      return;
    }
    try {
      let uiContext: UIContext = this.getUIContext();
      let ctx = uiContext.getHostContext() as common.UIAbilityContext;
      HuaweiAuthManager.getInstance().setContext(ctx);
      await HuaweiAuthManager.getInstance().logout();
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'Logout failed: ' + String(e));
    }
  }

  private formatCloudSyncTime(timestamp: number): string {
    if (timestamp <= 0) {
      return '从未同步';
    }
    let date: Date = new Date(timestamp);
    let year: number = date.getFullYear();
    let month: number = date.getMonth() + 1;
    let day: number = date.getDate();
    let hours: number = date.getHours();
    let minutes: number = date.getMinutes();
    let monthText: string = month < 10 ? '0' + month.toString() : month.toString();
    let dayText: string = day < 10 ? '0' + day.toString() : day.toString();
    let hourText: string = hours < 10 ? '0' + hours.toString() : hours.toString();
    let minuteText: string = minutes < 10 ? '0' + minutes.toString() : minutes.toString();
    return year.toString() + '-' + monthText + '-' + dayText + ' ' + hourText + ':' + minuteText;
  }

  private refreshCloudSyncSheetState(): void {
    let status: GeoNestCloudSyncStatus = this.cloudSyncManager.getStatus();
    if (!status.supported) {
      this.cloudSyncStatusText = '当前设备未启用云空间同步';
    } else if (!status.isLoggedIn) {
      this.cloudSyncStatusText = '请先登录华为账号';
    } else if (status.isWorking) {
      this.cloudSyncStatusText = '云空间同步正在执行';
    } else {
      this.cloudSyncStatusText = '云空间目录已就绪';
    }
    if (status.projectName.length > 0) {
      this.cloudSyncProjectText = '云端工程：' + status.projectName;
    } else {
      this.cloudSyncProjectText = '云空间中尚未找到工程包';
    }
    this.cloudSyncTimeText = this.formatCloudSyncTime(status.lastSyncTime);
    if (status.lastAction === 'upload') {
      this.cloudSyncActionText = '最近操作：上传到云空间';
    } else if (status.lastAction === 'pull') {
      this.cloudSyncActionText = '最近操作：从云空间拉取';
    } else if (status.lastAction === 'failed') {
      this.cloudSyncActionText = status.errorMessage.length > 0 ? '最近操作：失败 - ' + status.errorMessage : '最近操作：失败';
    } else {
      this.cloudSyncActionText = '最近操作：未执行';
    }
    this.cloudSyncLogs = this.cloudSyncManager.getLogs();
    this.refreshServiceWidgetState();
  }

  private async openCloudSyncSheet(): Promise<void> {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      await this.cloudSyncManager.init(ctx);
      await this.cloudSyncManager.refreshCloudState();
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'openCloudSyncSheet failed: ' + String(e));
    }
    this.refreshCloudSyncSheetState();
    this.cloudSyncSheetVisible = true;
  }

  private async uploadProjectToCloud(): Promise<void> {
    if (!this.commitPendingEditSessions()) {
      return;
    }
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      await this.cloudSyncManager.init(ctx);
      let request: GeoNestCloudUploadRequest | null = this.buildCloudUploadRequest();
      if (request === null) {
        this.refreshCloudSyncSheetState();
        return;
      }
      let ok: boolean = await this.cloudSyncManager.uploadProject(request);
      this.refreshCloudSyncSheetState();
      if (ok) {
        promptAction.showToast({ message: '已上传工程包到云空间', duration: 1800 });
      } else {
        let status: GeoNestCloudSyncStatus = this.cloudSyncManager.getStatus();
        promptAction.showToast({
          message: status.errorMessage.length > 0 ? status.errorMessage : '上传到云空间失败',
          duration: 2000
        });
      }
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'uploadProjectToCloud failed: ' + String(e));
      promptAction.showToast({ message: '上传到云空间失败', duration: 1800 });
    }
  }

  private async pullProjectFromCloud(): Promise<void> {
    if (this.projectDirty) {
      promptAction.showToast({ message: '请先保存当前工程后再从云空间拉取', duration: 1800 });
      return;
    }
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      await this.cloudSyncManager.init(ctx);
      let result: GeoNestCloudPullResult | null = await this.cloudSyncManager.pullProject();
      this.refreshCloudSyncSheetState();
      if (result === null) {
        let status: GeoNestCloudSyncStatus = this.cloudSyncManager.getStatus();
        promptAction.showToast({
          message: status.errorMessage.length > 0 ? status.errorMessage : '从云空间拉取失败',
          duration: 2000
        });
        return;
      }
      this.loadProjectFromText(result.localProjectPath, result.localProjectText);
      this.dataLoadStatus = '已从云空间拉取工程：' + result.projectName;
      promptAction.showToast({ message: '已从云空间拉取工程包', duration: 1800 });
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'pullProjectFromCloud failed: ' + String(e));
      promptAction.showToast({ message: '从云空间拉取失败', duration: 1800 });
    }
  }

  private openAdvancedAnalysisTool(toolMode: number): void {
    this.advancedToolMode = toolMode;
    this.advancedToolTrigger = !this.advancedToolTrigger;
  }

  private handleOperation(actionId: number): void {
    if (actionId === ACTION_NEW_PROJECT) {
      this.createProject();
    } else if (actionId === ACTION_OPEN_PROJECT) {
      this.openProject();
    } else if (actionId === ACTION_SAVE_PROJECT) {
      this.saveProject();
    } else if (actionId === ACTION_PROJECT_INFO) {
      this.openWorkspaceDialog(1);
    } else if (actionId === ACTION_ATTRIBUTE_TABLE) {
      this.openWorkspaceDialog(2);
    } else if (actionId === ACTION_ADD_DATA) {
      this.importShapefile();
    } else if (actionId === ACTION_ZOOM_IN) {
      this.runMapCommand(MAP_COMMAND_ZOOM_IN);
    } else if (actionId === ACTION_ZOOM_OUT) {
      this.runMapCommand(MAP_COMMAND_ZOOM_OUT);
    } else if (actionId === ACTION_FULL_EXTENT) {
      this.runMapCommand(MAP_COMMAND_FULL_EXTENT);
    } else if (actionId === ACTION_SYMBOLOGY) {
      this.openWorkspaceDialog(4);
    } else if (actionId === ACTION_CLIP) {
      this.openWorkspaceDialog(3);
    } else if (actionId === ACTION_BUFFER) {
      this.openWorkspaceDialog(5);
    } else if (actionId === ACTION_REPAIR) {
      this.openWorkspaceDialog(6);
    } else if (actionId === ACTION_LAYER_TOGGLE) {
      this.toggleSelectedLayerVisibility();
    } else if (actionId === ACTION_LAYER_FILTER) {
      this.toggleOnlySelectedLayer();
    } else if (actionId === ACTION_LAYER_UP) {
      this.moveSelectedLayer(-1);
    } else if (actionId === ACTION_LAYER_DOWN) {
      this.moveSelectedLayer(1);
    } else if (actionId === ACTION_LAYER_DELETE) {
      this.deleteSelectedLayer();
    } else if (actionId === ACTION_EXPORT) {
      this.openWorkspaceDialog(7);
    } else if (actionId === ACTION_QGIS_CORE) {
      this.openWorkspaceDialog(8);
    } else if (actionId === ACTION_VECTOR_EDIT) {
      if (this.ensureEditSession(this.selectedOperationalLayerIndex())) {
        this.openWorkspaceDialog(9);
      }
    } else if (actionId === ACTION_ATTRIBUTE_EDIT) {
      if (this.ensureEditSession(this.selectedOperationalLayerIndex())) {
        this.openWorkspaceDialog(10);
      }
    } else if (actionId === ACTION_LABELING) {
      this.openWorkspaceDialog(11);
    } else if (actionId === ACTION_RASTER_DISPLAY) {
      this.openWorkspaceDialog(12);
    } else if (actionId === ACTION_LAYOUT) {
      this.openWorkspaceDialog(13);
    } else if (actionId === ACTION_PRINT) {
      this.openWorkspaceDialog(15);
    } else if (actionId === ACTION_CLOUD_MANAGE) {
      this.openCloudSyncSheet();
    } else if (actionId === ACTION_CLOUD_PUSH) {
      this.uploadProjectToCloud();
    } else if (actionId === ACTION_CLOUD_PULL) {
      this.pullProjectFromCloud();
    } else if (actionId === ACTION_DEFINE_PROJECTION) {
      this.openWorkspaceDialog(16);
    } else if (actionId === ACTION_PROJECT_LAYER) {
      this.openWorkspaceDialog(17);
    } else if (actionId === ACTION_SIMPLIFY) {
      this.simplifyToolTrigger = !this.simplifyToolTrigger;
    } else if (actionId === ACTION_DISSOLVE) {
      this.dissolveToolTrigger = !this.dissolveToolTrigger;
    } else if (actionId === ACTION_CENTROID) {
      this.centroidToolTrigger = !this.centroidToolTrigger;
    } else if (actionId === ACTION_CONVEX_HULL) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_CONVEX_HULL);
    } else if (actionId === ACTION_BOUNDING_BOXES) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_BOUNDING_BOXES);
    } else if (actionId === ACTION_ORIENTED_MINIMUM_BOUNDING_BOX) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_ORIENTED_MINIMUM_BOUNDING_BOX);
    } else if (actionId === ACTION_MULTIPART_TO_SINGLEPARTS) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_MULTIPART_TO_SINGLEPARTS);
    } else if (actionId === ACTION_EXTRACT_BY_EXPRESSION) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_EXTRACT_BY_EXPRESSION);
    } else if (actionId === ACTION_DIFFERENCE) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_DIFFERENCE);
    } else if (actionId === ACTION_SYMMETRICAL_DIFFERENCE) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_SYMMETRICAL_DIFFERENCE);
    } else if (actionId === ACTION_MERGE_LAYERS) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_MERGE_LAYERS);
    } else if (actionId === ACTION_MULTI_RING_BUFFER) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_MULTI_RING_BUFFER);
    } else if (actionId === ACTION_EXTRACT_BY_LOCATION) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_EXTRACT_BY_LOCATION);
    } else if (actionId === ACTION_SPATIAL_JOIN_SUMMARY) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_SPATIAL_JOIN_SUMMARY);
    } else if (actionId === ACTION_INTERSECTION) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_INTERSECTION);
    } else if (actionId === ACTION_NEAREST_NEIGHBOR) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_NEAREST_NEIGHBOR);
    } else if (actionId === ACTION_VORONOI) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_VORONOI);
    } else if (actionId === ACTION_KERNEL_DENSITY) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_KERNEL_DENSITY);
    } else if (actionId === ACTION_POINT_DENSITY) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_POINT_DENSITY);
    } else if (actionId === ACTION_LINE_DENSITY) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_LINE_DENSITY);
    } else if (actionId === ACTION_IDW) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_IDW);
    } else if (actionId === ACTION_RASTER_SLOPE) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_RASTER_SLOPE);
    } else if (actionId === ACTION_RASTER_ASPECT) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_RASTER_ASPECT);
    } else if (actionId === ACTION_RASTER_RECLASSIFY) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_RASTER_RECLASSIFY);
    } else if (actionId === ACTION_QUALITY_CHECK) {
      this.openAdvancedAnalysisTool(GIS_TOOL_MODE_QUALITY_CHECK);
    } else if (actionId === ACTION_XY_TABLE_TO_POINT) {
      this.xyTableToPointTrigger = !this.xyTableToPointTrigger;
    } else if (actionId === ACTION_TOPOLOGY_REVIEW) {
      if (this.topologyErrorLayerIndex >= 0) {
        this.topologyReviewTrigger = !this.topologyReviewTrigger;
      } else {
        this.openAdvancedAnalysisTool(GIS_TOOL_MODE_QUALITY_CHECK);
      }
    } else if (actionId === ACTION_PORTABLE_PROJECT) {
      this.portableProjectTrigger = !this.portableProjectTrigger;
    } else if (actionId === ACTION_LAYOUT_ATLAS) {
      this.layoutAtlasTrigger = !this.layoutAtlasTrigger;
    } else if (actionId === ACTION_OPEN_SECOND_MAP) {
      this.openSecondaryMapWindow();
    } else if (actionId === ACTION_TOGGLE_LINKED_VIEW) {
      this.toggleLinkedMapView();
    } else if (actionId === ACTION_COPY_MAP_CONTEXT) {
      this.copyMapContextToPasteboard();
    } else if (actionId === ACTION_PASTE_CLIPBOARD) {
      this.pasteFromSystemPasteboard();
    } else if (actionId === ACTION_PROCESSING_BROWSER) {
      this.processingBrowserTrigger = !this.processingBrowserTrigger;
    } else if (actionId === ACTION_EXPRESSION_WORKBENCH) {
      this.openWorkspaceDialog(18);
    } else if (actionId === ACTION_ZOOM_SELECTED) {
      this.runMapCommand(MAP_COMMAND_ZOOM_SELECTED);
    } else if (actionId === ACTION_CLEAR_SELECTION) {
      this.clearFeatureSelection();
    } else if (actionId === ACTION_SHOW_CONTENTS) {
      this.restoreSidePanel(0);
    } else if (actionId === ACTION_SHOW_CATALOG) {
      this.rightPanelIndex = 0;
      this.restoreSidePanel(1);
    } else if (actionId === ACTION_SHOW_TOOLBOX) {
      this.rightPanelIndex = 1;
      this.restoreSidePanel(1);
    } else if (actionId === ACTION_EXPLORE) {
      this.setMapToolMode(MAP_TOOL_IDENTIFY);
    } else if (actionId === ACTION_SETTINGS) {
      this.openBackstage(BACKSTAGE_SETTINGS);
    } else if (actionId === ACTION_HELP) {
      this.openBackstage(BACKSTAGE_HELP);
    } else if (actionId === ACTION_ABOUT) {
      this.openBackstage(BACKSTAGE_ABOUT);
    } else if (actionId === ACTION_SHARE) {
      this.shareActiveLayerFiles();
    }
  }

  private clearFeatureSelection(): void {
    this.applyFeatureSelection('', -1, FEATURE_SELECTION_REPLACE);
  }

  private async shareActiveLayerFiles(): Promise<void> {
    if (!this.commitPendingEditSessions()) {
      return;
    }
    let activeLayer: GisLoadedLayer | undefined = this.gisService.getActiveLayer();
    if (activeLayer === undefined) {
      promptAction.showToast({ message: '请先加载一个图层', duration: 1500, bottom: 120 });
      return;
    }
    let shpPath: string = activeLayer.sourcePath;
    if (shpPath.length === 0 || !shpPath.endsWith('.shp')) {
      promptAction.showToast({ message: '当前图层不是 Shapefile 格式', duration: 1500, bottom: 120 });
      return;
    }
    try {
      let basePath: string = shpPath.substring(0, shpPath.length - 4);
      let extensions: string[] = ['.shp', '.shx', '.dbf', '.prj'];
      let shareUris: string[] = [];
      let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      for (let i = 0; i < extensions.length; i++) {
        let filePath: string = basePath + extensions[i];
        try {
          let stat = fs.statSync(filePath);
          if (stat.isFile()) {
            shareUris.push(fileUri.getUriFromPath(filePath));
          }
        } catch (e) {
          // file doesn't exist, skip
        }
      }
      if (shareUris.length === 0) {
        promptAction.showToast({ message: '未找到可分享的文件', duration: 1500, bottom: 120 });
        return;
      }
      let utdTypeId: string = utd.getUniformDataTypeByFilenameExtension('.shp',
        utd.UniformDataType.FILE);
      let shareData: systemShare.SharedData = new systemShare.SharedData({
        utd: utdTypeId,
        uri: shareUris[0],
        title: activeLayer.info.name,
        description: 'GeoNest Shapefile (' + shareUris.length + ' files)',
      });
      let controller: systemShare.ShareController = new systemShare.ShareController(shareData);
      await controller.show(context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
      }).catch((err: BusinessError): void => {
        promptAction.showToast({ message: '分享取消', duration: 1500, bottom: 120 });
      });
    } catch (e) {
      promptAction.showToast({ message: '分享失败: ' + String(e), duration: 1500, bottom: 120 });
    }
  }

  private runMapCommand(command: number): void {
    if (this.layerCount === 0) {
      return;
    }
    this.mapCommand = command;
    this.mapCommandKey++;
  }

  private isVectorEditToolMode(toolMode: number): boolean {
    return toolMode === MAP_TOOL_EDIT_ADD_POINT || toolMode === MAP_TOOL_EDIT_ADD_LINE ||
      toolMode === MAP_TOOL_EDIT_ADD_POLYGON || toolMode === MAP_TOOL_EDIT_MOVE_NODE ||
      toolMode === MAP_TOOL_EDIT_DELETE_NODE;
  }

  private showEditToast(message: string): void {
    if (message.length === 0) {
      return;
    }
    try {
      promptAction.showToast({ message: message, duration: 1800, bottom: 120 });
    } catch (e) {
      hilog.warn(LOG_TAG, LOG_DOMAIN, 'showEditToast failed: %{public}s', String(e));
    }
  }

  private editToolUnavailableMessage(toolMode: number): string {
    if (!this.isVectorEditToolMode(toolMode)) {
      return '';
    }
    let layerIndex = this.selectedOperationalLayerIndex();
    let layer = this.gisService.getLayer(layerIndex);
    if (layer === undefined) {
      return '请先选择一个可编辑矢量图层';
    }
    if (layer.info.geometryType === 0 && layer.info.fields.length === 0) {
      return '栅格图层不能执行矢量编辑';
    }
    if (toolMode === MAP_TOOL_EDIT_ADD_POINT && layer.info.geometryType !== 1) {
      return '当前图层是' + this.geometryName(layer.info.geometryType) + '图层，不能新增点要素';
    }
    if (toolMode === MAP_TOOL_EDIT_ADD_LINE && layer.info.geometryType !== 2) {
      return '当前图层是' + this.geometryName(layer.info.geometryType) + '图层，不能新增线要素';
    }
    if (toolMode === MAP_TOOL_EDIT_ADD_POLYGON && layer.info.geometryType !== 3) {
      return '当前图层是' + this.geometryName(layer.info.geometryType) + '图层，不能新增面要素';
    }
    if (toolMode === MAP_TOOL_EDIT_DELETE_NODE && layer.info.geometryType === 1) {
      return '点图层不能删节点，请使用删除所选要素';
    }
    return '';
  }

  private setMapToolMode(toolMode: number): boolean {
    let unavailableMessage = this.editToolUnavailableMessage(toolMode);
    if (unavailableMessage.length > 0) {
      this.editStatus = unavailableMessage;
      this.showEditToast(unavailableMessage);
      return false;
    }
    if (this.isTransactionalEditTool(toolMode) &&
      !this.ensureEditSession(this.selectedOperationalLayerIndex())) {
      return false;
    }
    this.mapToolMode = toolMode;
    this.measurementStatus = '';
    if (toolMode !== MAP_TOOL_IDENTIFY) {
      this.showFeaturePanel = false;
    }
    return true;
  }

  private isTransactionalEditTool(toolMode: number): boolean {
    return toolMode === MAP_TOOL_EDIT_ADD_POINT || toolMode === MAP_TOOL_EDIT_ADD_LINE ||
      toolMode === MAP_TOOL_EDIT_ADD_POLYGON || toolMode === MAP_TOOL_EDIT_MOVE_NODE ||
      toolMode === MAP_TOOL_EDIT_DELETE_NODE;
  }

  private ensureEditSession(layerIndex: number): boolean {
    if (this.gisService.isEditSessionActive(layerIndex)) {
      return true;
    }
    let result: GisOperationResult = this.gisService.beginEditSession(layerIndex);
    this.editStatus = result.message;
    if (!result.ok) {
      this.showEditToast(result.message);
      return false;
    }
    this.refreshLayerState();
    return true;
  }

  private onLayerPresentationChanged(status: string): void {
    this.editStatus = status;
    this.projectDirty = true;
    this.refreshLayerState();
  }

  private geometryName(geometryType: number): string {
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

  private applyEditResult(result: GisOperationResult): void {
    if (result.ok) {
      this.editStatus = result.message;
      this.projectDirty = true;
      this.refreshLayerState();
    } else {
      this.editStatus = result.message;
      this.showEditToast(result.message);
    }
  }

  private onSketchFeatureCreated(geometryType: number, points: GisCoordinate[]): void {
    let layerIndex = this.selectedOperationalLayerIndex();
    let layer = this.gisService.getLayer(layerIndex);
    if (layer === undefined) {
      this.editStatus = '没有可编辑图层';
      this.showEditToast(this.editStatus);
      return;
    }
    if (layer.info.geometryType !== geometryType) {
      this.editStatus = '当前图层是' + this.geometryName(layer.info.geometryType) + '图层，不能新增' +
        this.geometryName(geometryType) + '要素';
      this.showEditToast(this.editStatus);
      return;
    }
    this.applyEditResult(this.gisService.addSketchFeature(layerIndex, geometryType, points));
  }

  private onCutSketchCompleted(points: GisCoordinate[]): void {
    let layerIndex: number = this.selectedOperationalLayerIndex();
    if (!this.ensureEditSession(layerIndex)) {
      return;
    }
    this.applyEditResult(this.gisService.splitFeatureWithSketch(layerIndex, this.selectedFeatureId, points));
    this.clearFeatureSelection();
  }

  private onProviderSelectionCompleted(selectionWkt: string, crossLayers: boolean): void {
    if (crossLayers) {
      let selections: GisLayerSelection[] = this.gisService.selectProviderFeaturesAcrossLayers(selectionWkt, 0,
        true);
      let total: number = 0;
      for (let i = 0; i < selections.length; i++) {
        total += selections[i].featureIds.length;
      }
      if (selections.length > 0) {
        this.commitFeatureSelection(selections[0].featureIds,
          selections[0].featureIds.length > 0 ? selections[0].featureIds[0] : '', selections[0].layerIndex);
      } else {
        this.clearFeatureSelection();
      }
      this.editStatus = '跨图层全数据集选择：' + selections.length.toString() + ' 个图层，' +
        total.toString() + ' 个要素';
      return;
    }
    let layerIndex: number = this.selectedOperationalLayerIndex();
    let result = this.gisService.selectProviderFeaturesByGeometry(layerIndex, selectionWkt, 0);
    if (!result.ok) {
      this.editStatus = result.message;
      this.showEditToast(result.message);
      return;
    }
    this.commitFeatureSelection(result.featureIds, result.featureIds.length > 0 ? result.featureIds[0] : '',
      layerIndex);
    this.editStatus = '全数据集选择：' + result.matchedCount.toString() + ' 个要素';
  }

  private onNodeEditRequested(editMode: number, layerIndex: number, featureId: string, partIndex: number,
    pointIndex: number, mapX: number, mapY: number): void {
    let result: GisOperationResult = new GisOperationResult(false, 0, '未执行编辑');
    if (editMode === MAP_TOOL_EDIT_MOVE_NODE) {
      result = this.gisService.moveFeatureNode(layerIndex, featureId, partIndex, pointIndex, mapX, mapY);
    } else if (editMode === MAP_TOOL_EDIT_DELETE_NODE) {
      result = this.gisService.deleteFeatureNode(layerIndex, featureId, partIndex, pointIndex);
    }
    this.selectedLayerIndex = layerIndex;
    this.onFeatureSelected(featureId, layerIndex);
    this.applyEditResult(result);
  }

  private runVectorEditCommand(command: number): void {
    let layerIndex: number = this.selectedOperationalLayerIndex();
    if (command === VECTOR_EDIT_COMMAND_BEGIN_SESSION) {
      this.applyEditSessionResult(this.gisService.beginEditSession(layerIndex), false);
      return;
    }
    if (command === VECTOR_EDIT_COMMAND_COMMIT_SESSION) {
      this.applyEditSessionResult(this.gisService.commitEditSession(layerIndex), true);
      this.setMapToolMode(MAP_TOOL_IDENTIFY);
      this.clearFeatureSelection();
      return;
    }
    if (command === VECTOR_EDIT_COMMAND_ROLLBACK_SESSION) {
      this.applyEditSessionResult(this.gisService.rollbackEditSession(layerIndex), false);
      this.setMapToolMode(MAP_TOOL_IDENTIFY);
      this.clearFeatureSelection();
      return;
    }
    if (command !== VECTOR_EDIT_COMMAND_UNDO && command !== VECTOR_EDIT_COMMAND_REDO &&
      !this.ensureEditSession(layerIndex)) {
      return;
    }
    if (command === VECTOR_EDIT_COMMAND_DELETE_FEATURE) {
      this.applyEditResult(this.gisService.deleteFeature(layerIndex, this.selectedFeatureId));
      this.clearFeatureSelection();
      return;
    }
    if (command === VECTOR_EDIT_COMMAND_COPY) {
      this.applyEditResult(this.gisService.copyFeature(layerIndex, this.selectedFeatureId));
      return;
    }
    if (command === VECTOR_EDIT_COMMAND_UNDO) {
      this.applyEditResult(this.gisService.undoEdit());
      this.selectedLayerIndex = this.gisService.getActiveLayerIndex();
      this.clearFeatureSelection();
      return;
    }
    if (command === VECTOR_EDIT_COMMAND_REDO) {
      this.applyEditResult(this.gisService.redoEdit());
      this.selectedLayerIndex = this.gisService.getActiveLayerIndex();
      this.clearFeatureSelection();
      return;
    }
    if (command === VECTOR_EDIT_COMMAND_SNAP) {
      let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      let snapConfig: SnappingConfiguration = new TopologyRuleStore(context).loadSnappingConfiguration();
      if (!snapConfig.enabled) {
        this.editStatus = '吸附已关闭';
        return;
      }
      this.applyEditResult(this.gisService.snapLayer(this.selectedOperationalLayerIndex(),
        layerIndex, snapConfig.nativeTolerance(this.mapUnitsPerPixel)));
      return;
    }
    if (command === VECTOR_EDIT_COMMAND_CUT) {
      this.applyEditResult(this.gisService.splitSelectedFeature(this.selectedOperationalLayerIndex(),
        this.selectedFeatureId));
      this.clearFeatureSelection();
      return;
    }
    if (command === VECTOR_EDIT_COMMAND_MERGE) {
      this.applyEditResult(this.gisService.mergeFeatureWithNext(this.selectedOperationalLayerIndex(),
        this.selectedFeatureId));
      this.clearFeatureSelection();
    }
  }

  private applyEditSessionResult(result: GisOperationResult, markDirty: boolean): void {
    this.editStatus = result.message;
    if (!result.ok) {
      this.showEditToast(result.message);
      return;
    }
    if (markDirty) {
      this.projectDirty = true;
    }
    this.refreshLayerState();
  }

  private handleKeyEvent(event: KeyEvent): boolean {
    if (event.type !== KeyType.Down) {
      return false;
    }
    let keyCode: number = event.keyCode;
    let ctrl: boolean = event.getModifierKeyState !== undefined && event.getModifierKeyState(['ctrl']);
    let shift: boolean = event.getModifierKeyState !== undefined && event.getModifierKeyState(['shift']);
    let alt: boolean = event.getModifierKeyState !== undefined && event.getModifierKeyState(['alt']);

    if (ctrl && !shift && !alt) {
      switch (keyCode) {
        case KeyCode.KEYCODE_N:
          this.createProject();
          return true;
        case KeyCode.KEYCODE_O:
          this.openProject();
          return true;
        case KeyCode.KEYCODE_S:
          this.saveProject();
          return true;
        case KeyCode.KEYCODE_Z:
          this.runVectorEditCommand(VECTOR_EDIT_COMMAND_UNDO);
          return true;
        case KeyCode.KEYCODE_Y:
          this.runVectorEditCommand(VECTOR_EDIT_COMMAND_REDO);
          return true;
        case KeyCode.KEYCODE_M:
          this.runMapCommand(MAP_COMMAND_FULL_EXTENT);
          return true;
        case KeyCode.KEYCODE_L:
          this.toggleSelectedLayerVisibility();
          return true;
        case KeyCode.KEYCODE_T:
          this.toggleWindowTopmost();
          return true;
        case KeyCode.KEYCODE_1:
          this.runMapCommand(MAP_COMMAND_ZOOM_IN);
          return true;
        case KeyCode.KEYCODE_2:
          this.runMapCommand(MAP_COMMAND_ZOOM_OUT);
          return true;
        default:
          break;
      }
    }

    if (ctrl && shift && !alt) {
      switch (keyCode) {
        case KeyCode.KEYCODE_C:
          this.handleOperation(ACTION_COPY_MAP_CONTEXT);
          return true;
        case KeyCode.KEYCODE_V:
          this.handleOperation(ACTION_PASTE_CLIPBOARD);
          return true;
        case KeyCode.KEYCODE_M:
          this.handleOperation(ACTION_OPEN_SECOND_MAP);
          return true;
        case KeyCode.KEYCODE_L:
          this.handleOperation(ACTION_TOGGLE_LINKED_VIEW);
          return true;
        case KeyCode.KEYCODE_F:
          this.setMapToolMode(MAP_TOOL_IDENTIFY);
          return true;
        case KeyCode.KEYCODE_I:
          this.importShapefile();
          return true;
        default:
          break;
      }
    }

    if (!ctrl && !shift && !alt) {
      switch (keyCode) {
        case KeyCode.KEYCODE_DEL:
          if (this.selectedFeatureId.length > 0) {
            this.runVectorEditCommand(VECTOR_EDIT_COMMAND_DELETE_FEATURE);
          }
          return true;
        case KeyCode.KEYCODE_ESCAPE:
          if (this.showFeaturePanel) {
            this.clearFeatureSelection();
          } else if (this.mapToolMode !== MAP_TOOL_IDENTIFY) {
            this.setMapToolMode(MAP_TOOL_IDENTIFY);
          }
          return true;
        case KeyCode.KEYCODE_F1:
          this.openBackstage(BACKSTAGE_HELP);
          return true;
        case KeyCode.KEYCODE_F11:
          this.toggleSelectedLayerVisibility();
          return true;
        default:
          break;
      }
    }

    return false;
  }

  private normalizedProjectText(value: string, fallback: string): string {
    return WorkbenchTextService.normalizedText(value, fallback);
  }

  private applyProjectParameters(params: GeoNestProjectParameters): void {
    this.projectName = this.normalizedProjectText(params.name, '未命名工程');
    this.projectOwner = this.normalizedProjectText(params.owner, '');
    this.projectCrs = this.normalizedProjectText(params.crs, '');
    this.projectMapName = this.normalizedProjectText(params.mapName, '地图');
    this.projectWorkspaceName = this.normalizedProjectText(params.workspaceName, '默认工作空间');
    this.projectDescription = this.normalizedProjectText(params.description, '');
  }

  private safeProjectFileBaseName(source: string): string {
    return WorkbenchTextService.safeProjectFileBaseName(source);
  }

  private defaultProjectFileNameFromTitle(title: string): string {
    return WorkbenchTextService.defaultProjectFileName(title);
  }

  private defaultProjectFileName(): string {
    return this.defaultProjectFileNameFromTitle(this.projectName);
  }

  private isQgisProjectExtension(ext: string): boolean {
    return WorkbenchTextService.isQgisProjectExtension(ext);
  }

  private isQgisProjectUri(uri: string): boolean {
    return this.isQgisProjectExtension(this.fileExtension(this.extractFileName(uri)));
  }

  private projectDisplayName(): string {
    if (this.projectName.length > 0) {
      return this.projectName;
    }
    return this.projectFileName;
  }

  private projectStateLabel(): string {
    if (this.projectDirty) {
      return this.projectDisplayName() + ' · 未保存';
    }
    if (this.projectState === 2) {
      return this.projectDisplayName() + ' · 已保存';
    }
    if (this.projectState === 0) {
      return this.projectDisplayName() + ' · 新建';
    }
    return this.projectDisplayName() + ' · 已打开';
  }

  private extractFileName(uri: string): string {
    return WorkbenchTextService.extractFileName(uri, this.defaultProjectFileName());
  }

  private buildProjectSaveOptionsWithName(fileName: string): picker.DocumentSaveOptions {
    let opts: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    opts.newFileNames = [fileName];
    opts.fileSuffixChoices = [PROJECT_FILE_SUFFIX_CHOICE, QGIS_QGS_PROJECT_FILE_SUFFIX_CHOICE,
      QGIS_QGZ_PROJECT_FILE_SUFFIX_CHOICE];
    return opts;
  }

  private buildProjectSaveOptions(): picker.DocumentSaveOptions {
    return this.buildProjectSaveOptionsWithName(this.defaultProjectFileName());
  }

  private buildProjectSelectOptions(): picker.DocumentSelectOptions {
    let opts: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    opts.maxSelectNumber = 1;
    opts.fileSuffixFilters = [PROJECT_FILE_SUFFIX_CHOICE, QGIS_QGS_PROJECT_FILE_SUFFIX_CHOICE,
      QGIS_QGZ_PROJECT_FILE_SUFFIX_CHOICE];
    return opts;
  }

  private cleanProjectLine(value: string): string {
    return WorkbenchTextService.cleanProjectLine(value);
  }

  private projectValue(lines: string[], key: string): string {
    return WorkbenchTextService.projectValue(lines, key);
  }

  private projectNumberValue(lines: string[], key: string, fallback: number): number {
    return WorkbenchTextService.projectNumberValue(lines, key, fallback);
  }

  private projectBooleanValue(lines: string[], key: string, fallback: boolean): boolean {
    return WorkbenchTextService.projectBooleanValue(lines, key, fallback);
  }

  private buildProjectText(): string {
    return this.buildProjectTextWithLayerPaths([]);
  }

  private buildProjectTextWithLayerPaths(layerPaths: string[]): string {
    let writer: WorkbenchProjectTextWriter = new WorkbenchProjectTextWriter(this.gisService);
    return writer.write(PROJECT_FILE_MAGIC, this.projectName, this.projectOwner, this.projectCrs, this.projectMapName,
      this.projectWorkspaceName, this.projectDescription, this.basemapMode, this.basemapDatumMode, layerPaths);
  }

  private parentDirectoryFromPath(path: string): string {
    return WorkbenchTextService.parentDirectory(path);
  }

  private fileStem(fileName: string): string {
    return WorkbenchTextService.fileStem(fileName);
  }

  private pushUniquePath(result: string[], value: string): void {
    for (let i = 0; i < result.length; i++) {
      if (result[i] === value) {
        return;
      }
    }
    result.push(value);
  }

  private collectCloudAssetSourcePaths(sourcePath: string): string[] {
    let result: string[] = [];
    if (sourcePath.length === 0) {
      return result;
    }
    this.pushUniquePath(result, sourcePath);
    let directoryPath: string = this.parentDirectoryFromPath(sourcePath);
    if (directoryPath.length === 0) {
      return result;
    }
    let sourceFileName: string = this.extractFileName(sourcePath);
    let stem: string = this.fileStem(sourceFileName);
    if (stem.length === 0) {
      return result;
    }
    try {
      let fileNames: string[] = fileIo.listFileSync(directoryPath);
      for (let i = 0; i < fileNames.length; i++) {
        let candidateName: string = fileNames[i];
        if (candidateName === sourceFileName || !candidateName.startsWith(stem + '.')) {
          continue;
        }
        let candidatePath: string = directoryPath + '/' + candidateName;
        try {
          let stat = fs.statSync(candidatePath);
          if (stat.isFile()) {
            this.pushUniquePath(result, candidatePath);
          }
        } catch (_error) {}
      }
    } catch (_error) {}
    return result;
  }

  private buildCloudUploadRequest(): GeoNestCloudUploadRequest | null {
    let layerCount: number = this.gisService.getLayerCount();
    let layerRelativePaths: string[] = [];
    let layerPackages: GeoNestCloudLayerPackage[] = [];
    for (let i = 0; i < layerCount; i++) {
      let layer = this.gisService.getLayer(i);
      if (layer === undefined || layer.sourcePath.length === 0) {
        layerRelativePaths.push('');
        continue;
      }
      if (!fs.accessSync(layer.sourcePath)) {
        promptAction.showToast({ message: '图层源文件不存在：' + this.extractFileName(layer.sourcePath), duration: 1800 });
        return null;
      }
      let relativeDirectory: string = 'assets/layer_' + i.toString();
      let relativePath: string = relativeDirectory + '/' + this.extractFileName(layer.sourcePath);
      let assetSourcePaths: string[] = this.collectCloudAssetSourcePaths(layer.sourcePath);
      layerRelativePaths.push(relativePath);
      layerPackages.push(new GeoNestCloudLayerPackage(i, relativePath, assetSourcePaths));
    }
    let projectFileName: string = this.defaultProjectFileNameFromTitle(this.projectDisplayName());
    return new GeoNestCloudUploadRequest(
      this.projectDisplayName(),
      'project/' + projectFileName,
      this.buildProjectTextWithLayerPaths(layerRelativePaths),
      layerPackages
    );
  }

  private restoreProjectLayerStyle(lines: string[], projectLayerIndex: number, loadedLayerIndex: number): void {
    let prefix = 'layer.' + projectLayerIndex.toString() + '.';
    if (this.projectValue(lines, prefix + 'styleVersion').length === 0) {
      return;
    }
    let layer = this.gisService.getLayer(loadedLayerIndex);
    if (layer === undefined) {
      return;
    }
    let current = layer.style;
    let style = new GisLayerStyle(
      this.normalizedProjectText(this.projectValue(lines, prefix + 'pointColor'), current.pointColor),
      this.normalizedProjectText(this.projectValue(lines, prefix + 'lineColor'), current.lineColor),
      this.normalizedProjectText(this.projectValue(lines, prefix + 'fillColor'), current.fillColor),
      this.normalizedProjectText(this.projectValue(lines, prefix + 'strokeColor'), current.strokeColor),
      this.projectNumberValue(lines, prefix + 'lineWidth', current.lineWidth),
      this.projectNumberValue(lines, prefix + 'pointRadius', current.pointRadius)
    );
    style.rendererMode = Math.round(this.projectNumberValue(lines, prefix + 'rendererMode', current.rendererMode));
    style.rendererField = this.projectValue(lines, prefix + 'rendererField');
    style.colorRamp = Math.round(this.projectNumberValue(lines, prefix + 'colorRamp', current.colorRamp));
    style.linePattern = Math.round(this.projectNumberValue(lines, prefix + 'linePattern', current.linePattern));
    style.fillPattern = Math.round(this.projectNumberValue(lines, prefix + 'fillPattern', current.fillPattern));
    style.opacity = this.projectNumberValue(lines, prefix + 'opacity', current.opacity);
    style.symbolName = this.normalizedProjectText(this.projectValue(lines, prefix + 'symbolName'),
      current.symbolName);
    style.labelEnabled = this.projectBooleanValue(lines, prefix + 'labelEnabled', current.labelEnabled);
    style.labelField = this.projectValue(lines, prefix + 'labelField');
    style.labelSize = this.projectNumberValue(lines, prefix + 'labelSize', current.labelSize);
    style.labelColor = this.normalizedProjectText(this.projectValue(lines, prefix + 'labelColor'),
      current.labelColor);
    style.labelHalo = this.projectBooleanValue(lines, prefix + 'labelHalo', current.labelHalo);
    style.labelAvoidance = this.projectBooleanValue(lines, prefix + 'labelAvoidance', current.labelAvoidance);
    style.labelMinScale = this.projectNumberValue(lines, prefix + 'labelMinScale', current.labelMinScale);
    style.labelMaxScale = this.projectNumberValue(lines, prefix + 'labelMaxScale', current.labelMaxScale);
    style.rasterBandMode = Math.round(this.projectNumberValue(lines, prefix + 'rasterBandMode',
      current.rasterBandMode));
    style.rasterStretchMode = Math.round(this.projectNumberValue(lines, prefix + 'rasterStretchMode',
      current.rasterStretchMode));
    style.rasterColorRamp = Math.round(this.projectNumberValue(lines, prefix + 'rasterColorRamp',
      current.rasterColorRamp));
    style.rasterOpacity = this.projectNumberValue(lines, prefix + 'rasterOpacity', current.rasterOpacity);
    style.rasterNoData = this.projectValue(lines, prefix + 'rasterNoData');
    style.rasterTransparentColor = this.projectValue(lines, prefix + 'rasterTransparentColor');
    style.rasterHillshade = this.projectBooleanValue(lines, prefix + 'rasterHillshade',
      current.rasterHillshade);
    let result = this.gisService.updateLayerStyle(loadedLayerIndex, style);
    if (!result.ok) {
      hilog.warn(LOG_TAG, LOG_DOMAIN, 'restoreProjectLayerStyle: %{public}s', result.message);
    }
  }

  private restoreProjectBasemap(lines: string[]): void {
    let restoredMode = Math.round(this.projectNumberValue(lines, 'basemapMode', BASEMAP_VECTOR));
    if (restoredMode < BASEMAP_VECTOR || restoredMode > BASEMAP_HARMONY_IMAGERY) {
      restoredMode = BASEMAP_VECTOR;
    }
    let restoredDatumMode = Math.round(this.projectNumberValue(lines, 'basemapDatumMode', BASEMAP_DATUM_AUTO));
    if (restoredDatumMode < BASEMAP_DATUM_AUTO || restoredDatumMode > BASEMAP_DATUM_GCJ02) {
      restoredDatumMode = BASEMAP_DATUM_AUTO;
    }
    this.basemapMode = restoredMode;
    this.basemapDatumMode = restoredDatumMode;
    if (restoredMode === BASEMAP_VECTOR) {
      this.basemapStatus = '';
    } else if (this.isHarmonyBasemapMode(restoredMode)) {
      this.basemapStatus = '正在加载花瓣地图：' + this.basemapNameForMode(restoredMode);
    } else {
      this.basemapStatus = '正在加载底图：' + this.basemapNameForMode(restoredMode);
    }
  }

  private writeTextToUri(uri: string, content: string): boolean {
    return WorkbenchFileService.writeText(uri, content, false);
  }

  private readTextFromUri(uri: string): string {
    return WorkbenchFileService.readText(uri, false);
  }

  private recentProjectsFilePath(): string {
    let ctx = getContext(this);
    return ctx.filesDir + '/' + RECENT_PROJECTS_FILE_NAME;
  }

  private loadRecentProjects(): void {
    let content: string = WorkbenchFileService.readText(this.recentProjectsFilePath(), true);
    this.recentProjects = WorkbenchRecentProjectService.load(content, RECENT_PROJECT_LIMIT);
    this.recentProjectRevision++;
  }

  private saveRecentProjects(): void {
    let text: string = WorkbenchRecentProjectService.serialize(this.recentProjects, RECENT_PROJECT_LIMIT);
    WorkbenchFileService.writeText(this.recentProjectsFilePath(), text, true);
  }

  private rememberRecentProject(uri: string): void {
    if (uri.length === 0) {
      return;
    }
    let record: RecentProjectRecord = new RecentProjectRecord(uri, this.projectName, this.projectOwner,
      this.projectCrs, this.projectWorkspaceName);
    this.recentProjects = WorkbenchRecentProjectService.remember(this.recentProjects, record,
      RECENT_PROJECT_LIMIT);
    this.recentProjectRevision++;
    this.saveRecentProjects();
  }

  private applyLoadedQgisProject(uri: string, result: GisQgisProjectReadResult): void {
    let loadedProjectName = result.projectTitle;
    if (loadedProjectName.length === 0) {
      loadedProjectName = this.fileBaseName(this.displayFileName(this.extractFileName(uri)));
    }
    this.projectName = loadedProjectName;
    this.projectOwner = '';
    this.projectCrs = result.projectCrs;
    this.projectMapName = '地图';
    this.projectWorkspaceName = 'QGIS 工程';
    this.projectDescription = '由 QGIS .qgs/.qgz 工程导入';
    this.projectFileUri = uri;
    this.projectFileName = this.displayFileName(this.extractFileName(uri));
    this.projectState = 2;
    this.projectDirty = false;
    this.selectedLayerIndex = this.gisService.getActiveLayerIndex();
    this.clearFeatureSelection();
    this.refreshLayerState();
    this.runMapCommand(MAP_COMMAND_FULL_EXTENT);
    this.dataLoadStatus = result.message;
    this.rememberRecentProject(uri);
  }

  private loadQgisProjectFromUri(uri: string): void {
    let sandboxPath = this.sandboxProjectPathForUri(uri);
    if (!this.copyUriToFile(uri, sandboxPath)) {
      this.dataLoadStatus = 'QGIS 工程文件无法复制到应用沙箱';
      return;
    }
    this.resetProjectWorkspace();
    let result: GisQgisProjectReadResult = this.gisService.loadQgisProject(sandboxPath);
    if (!result.ok) {
      this.dataLoadStatus = result.message;
      this.refreshLayerState();
      return;
    }
    this.applyLoadedQgisProject(uri, result);
  }

  private saveQgisProjectToUri(uri: string): boolean {
    let sandboxPath = this.sandboxProjectPathForUri(uri);
    let result: GisOperationResult = this.gisService.saveQgisProject(sandboxPath, this.projectDisplayName(),
      this.projectCrs);
    if (!result.ok) {
      this.dataLoadStatus = result.message;
      this.projectDirty = true;
      return false;
    }
    if (!this.copyFileToUri(sandboxPath, uri)) {
      this.dataLoadStatus = 'QGIS 工程已生成，但写回目标位置失败';
      this.projectDirty = true;
      return false;
    }
    this.projectFileUri = uri;
    this.projectFileName = this.displayFileName(this.extractFileName(uri));
    this.projectState = 2;
    this.projectDirty = false;
    this.dataLoadStatus = '已保存 QGIS 工程：' + this.projectFileName;
    this.rememberRecentProject(uri);
    return true;
  }

  private saveProjectToUri(uri: string): boolean {
    if (this.isQgisProjectUri(uri)) {
      return this.saveQgisProjectToUri(uri);
    }
    if (this.writeTextToUri(uri, this.buildProjectText())) {
      this.projectFileUri = uri;
      this.projectFileName = this.displayFileName(this.extractFileName(uri));
      this.projectState = 2;
      this.projectDirty = false;
      this.rememberRecentProject(uri);
      return true;
    }
    this.projectDirty = true;
    return false;
  }

  private resetProjectWorkspace(): void {
    this.gisService.clearAll();
    this.selectedLayerIndex = -1;
    this.projectName = '未命名工程';
    this.projectOwner = '';
    this.projectCrs = '';
    this.projectMapName = '地图';
    this.projectWorkspaceName = '默认工作空间';
    this.projectDescription = '';
    this.basemapMode = BASEMAP_VECTOR;
    this.basemapDatumMode = BASEMAP_DATUM_AUTO;
    this.basemapStatus = '';
    this.editStatus = '';
    this.rightPanelIndex = 0;
    this.clearFeatureSelection();
    this.refreshLayerState();
  }

  private loadProjectFromText(uri: string, content: string, rememberProject: boolean = true): void {
    let lines = content.split('\n');
    if (lines.length === 0 || this.cleanProjectLine(lines[0]) !== PROJECT_FILE_MAGIC) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'loadProjectFromText: invalid project file');
      return;
    }

    let activeLayerIndex = Number(this.projectValue(lines, 'activeLayerIndex'));
    let layerCount = Number(this.projectValue(lines, 'layerCount'));
    if (layerCount < 0) {
      layerCount = 0;
    }
    if (layerCount > 500) {
      layerCount = 500;
    }

    this.resetProjectWorkspace();
    let loadedProjectName = this.projectValue(lines, 'projectName');
    if (loadedProjectName.length === 0) {
      loadedProjectName = this.displayFileName(this.extractFileName(uri));
    }
    this.applyProjectParameters(new GeoNestProjectParameters(
      loadedProjectName,
      this.projectValue(lines, 'projectOwner'),
      this.projectValue(lines, 'projectCrs'),
      this.projectValue(lines, 'projectMapName'),
      this.projectValue(lines, 'projectWorkspaceName'),
      this.projectValue(lines, 'projectDescription')
    ));
    this.restoreProjectBasemap(lines);
    for (let i = 0; i < layerCount; i++) {
      let path = this.projectValue(lines, 'layer.' + i.toString() + '.path');
      if (path.length > 0) {
        let idx = this.gisService.openLayer(path);
        if (idx >= 0) {
          let visibleText = this.projectValue(lines, 'layer.' + i.toString() + '.visible');
          this.gisService.setLayerVisibility(idx, visibleText !== 'false');
          this.restoreProjectLayerStyle(lines, i, idx);
        } else {
          hilog.warn(LOG_TAG, LOG_DOMAIN, 'loadProjectFromText: failed to open %{public}s', path);
        }
      }
    }

    let loadedLayerCount = this.gisService.getLayerCount();
    if (loadedLayerCount > 0) {
      if (activeLayerIndex < 0 || activeLayerIndex >= loadedLayerCount) {
        activeLayerIndex = loadedLayerCount - 1;
      }
      this.gisService.setActiveLayerIndex(activeLayerIndex);
      this.selectedLayerIndex = activeLayerIndex;
    } else {
      this.selectedLayerIndex = -1;
    }
    this.projectFileUri = uri;
    this.projectFileName = this.displayFileName(this.extractFileName(uri));
    this.projectState = 2;
    this.projectDirty = false;
    this.clearFeatureSelection();
    this.refreshLayerState();
    this.runMapCommand(MAP_COMMAND_FULL_EXTENT);
    if (rememberProject) {
      this.rememberRecentProject(uri);
    }
  }

  private createProject(): void {
    if (!this.canReplaceCurrentWorkspace()) {
      return;
    }
    this.openWorkspaceDialog(14);
  }

  private canReplaceCurrentWorkspace(): boolean {
    if (!this.projectDirty && !this.gisService.hasActiveEditSessions()) {
      return true;
    }
    this.getUIContext().getPromptAction().showToast({
      message: $r('app.string.gn_replace_unsaved_save_first'), duration: 2200
    });
    return false;
  }

  private createProjectWithParameters(params: GeoNestProjectParameters): void {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      let fileName = this.defaultProjectFileNameFromTitle(params.name);
      documentPicker.save(this.buildProjectSaveOptionsWithName(fileName)).then((result: Array<string>) => {
        if (result.length > 0) {
          let uri = result[0];
          this.resetProjectWorkspace();
          this.applyProjectParameters(params);
          this.projectFileUri = uri;
          this.projectFileName = this.displayFileName(this.extractFileName(uri));
          this.projectState = 0;
          this.projectDirty = false;
          this.saveProjectToUri(uri);
        }
      }).catch(() => {
        hilog.warn(LOG_TAG, LOG_DOMAIN, 'createProject: picker cancelled');
      });
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'createProject: EXCEPTION: %{public}s', String(e));
    }
  }

  private openRecentProject(uri: string): void {
    if (!this.canReplaceCurrentWorkspace()) {
      return;
    }
    if (this.isQgisProjectUri(uri)) {
      this.loadQgisProjectFromUri(uri);
      return;
    }
    let content = this.readTextFromUri(uri);
    if (content.length === 0) {
      this.dataLoadStatus = '最近工程无法读取，请使用打开重新选择文件';
      return;
    }
    this.loadProjectFromText(uri, content);
  }

  private openProject(): void {
    if (!this.canReplaceCurrentWorkspace()) {
      return;
    }
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      documentPicker.select(this.buildProjectSelectOptions()).then((result: Array<string>) => {
        if (result.length > 0) {
          let uri = result[0];
          if (this.isQgisProjectUri(uri)) {
            this.loadQgisProjectFromUri(uri);
            return;
          }
          let content = this.readTextFromUri(uri);
          this.loadProjectFromText(uri, content);
        }
      }).catch(() => {
        hilog.warn(LOG_TAG, LOG_DOMAIN, 'openProject: picker cancelled');
      });
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'openProject: EXCEPTION: %{public}s', String(e));
    }
  }

  private saveProject(): void {
    if (!this.commitPendingEditSessions()) {
      return;
    }
    if (this.projectFileUri.length > 0) {
      this.saveProjectToUri(this.projectFileUri);
      return;
    }
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      documentPicker.save(this.buildProjectSaveOptions()).then((result: Array<string>) => {
        if (result.length > 0) {
          this.saveProjectToUri(result[0]);
        }
      }).catch(() => {
        hilog.warn(LOG_TAG, LOG_DOMAIN, 'saveProject: picker cancelled');
      });
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'saveProject: EXCEPTION: %{public}s', String(e));
    }
  }

  private selectLayer(layerIndex: number): void {
    let previousLayerIndex = this.selectedOperationalLayerIndex();
    this.selectedLayerIndex = layerIndex;
    if (layerIndex >= 0 && layerIndex < this.gisService.getLayerCount()) {
      this.gisService.setActiveLayerIndex(layerIndex);
    }
    if (previousLayerIndex !== layerIndex) {
      this.projectDirty = true;
      this.clearFeatureSelection();
    }
    this.activeLayerRevision++;
    this.renderKey++;
  }

  private searchCoordinator(): WorkbenchSearchCoordinator {
    return new WorkbenchSearchCoordinator(this.gisService, this.searchViewModel,
      (layer: GisLoadedLayer): string => this.geometryName(layer.info.geometryType),
      (layer: GisLoadedLayer): string => this.layerReferenceText(layer),
      (layer: GisLoadedLayer): string => this.layerRendererText(layer),
      (layer: GisLoadedLayer): string => this.layerLabelText(layer));
  }

  private normalizedSearchText(value: string): string {
    return this.searchCoordinator().normalizedText(value);
  }

  private searchMatches(keyword: string, sourceText: string): boolean {
    return this.searchCoordinator().matches(keyword, sourceText);
  }

  private layerFieldSearchText(layer: GisLoadedLayer): string {
    return this.searchCoordinator().layerFieldSearchText(layer);
  }

  private layerSearchText(layer: GisLoadedLayer): string {
    return this.searchCoordinator().layerSearchText(layer);
  }

  private layerItemMatchesSearch(item: LayerDisplayItem, keyword: string): boolean {
    return this.searchCoordinator().matchesLayerItem(item, keyword);
  }

  private buildFilteredLayerDisplayList(searchText: string): LayerDisplayItem[] {
    return this.searchCoordinator().filterLayerItems(this.buildLayerDisplayList(), searchText);
  }

  private hasContentsSearchText(): boolean {
    return this.normalizedSearchText(this.contentsSearchText).length > 0;
  }

  private hasCatalogSearchText(): boolean {
    return this.normalizedSearchText(this.catalogSearchText).length > 0;
  }

  private buildLayerSearchCandidate(layer: GisLoadedLayer, layerIndex: number): GlobalSearchCandidate {
    return this.searchCoordinator().buildLayerCandidate(layer, layerIndex,
      this.renderKey.toString() + ':' + this.activeLayerRevision.toString());
  }

  private buildLayerSearchCandidates(keyword: string, maxCount: number): GlobalSearchCandidate[] {
    return this.searchCoordinator().buildLayerCandidates(keyword, maxCount,
      this.renderKey.toString() + ':' + this.activeLayerRevision.toString());
  }

  private buildGlobalSearchCandidates(searchText: string): GlobalSearchCandidate[] {
    return this.searchCoordinator().buildGlobalCandidates(searchText, COMMAND_SEARCH_MAX_SUGGESTIONS,
      COMMAND_SEARCH_MAX_LAYER_SUGGESTIONS,
      this.renderKey.toString() + ':' + this.activeLayerRevision.toString());
  }

  private shouldShowCommandSearchSuggestions(): boolean {
    return !this.isCompactLayout() && this.commandSearchSuggestionsVisible &&
      this.normalizedSearchText(this.commandSearchText).length > 0;
  }

  private executeSearchCandidate(item: GlobalSearchCandidate): void {
    this.commandSearchSuggestionsVisible = false;
    if (item.kind === SEARCH_CANDIDATE_KIND_LAYER) {
      let layer = this.gisService.getLayer(item.layerIndex);
      if (layer !== undefined) {
        this.selectLayer(item.layerIndex);
        this.restoreSidePanel(0);
        this.editStatus = '已定位图层：' + layer.info.name;
        promptAction.showToast({ message: this.editStatus, duration: 1500, bottom: 120 });
      }
      return;
    }
    if (item.actionId > 0) {
      this.handleOperation(item.actionId);
    }
  }

  private selectFirstLayerBySearch(keyword: string): boolean {
    let layerIndex: number = this.searchCoordinator().firstLayerIndex(keyword);
    if (layerIndex >= 0) {
      let layer: GisLoadedLayer | undefined = this.gisService.getLayer(layerIndex);
      if (layer !== undefined) {
        this.selectLayer(layerIndex);
        this.restoreSidePanel(0);
        this.editStatus = '已定位图层：' + layer.info.name;
        promptAction.showToast({ message: this.editStatus, duration: 1500, bottom: 120 });
        return true;
      }
    }
    return false;
  }

  private runGlobalSearch(rawValue: string): void {
    let keyword = this.normalizedSearchText(rawValue);
    this.commandSearchSuggestionsVisible = false;
    if (keyword.length === 0) {
      promptAction.showToast({ message: '请输入要搜索的命令、图层或工具', duration: 1500, bottom: 120 });
      return;
    }
    let candidates = this.buildGlobalSearchCandidates(rawValue);
    if (candidates.length > 0) {
      this.executeSearchCandidate(candidates[0]);
      return;
    }
    if (this.selectFirstLayerBySearch(keyword)) {
      return;
    }
    promptAction.showToast({ message: '未找到匹配项：' + rawValue, duration: 1800, bottom: 120 });
  }

  private selectedOperationalLayerIndex(): number {
    if (this.selectedLayerIndex >= 0 && this.selectedLayerIndex < this.gisService.getLayerCount()) {
      return this.selectedLayerIndex;
    }
    return this.gisService.getActiveLayerIndex();
  }

  private firstVisibleLayer(): GisLoadedLayer | undefined {
    for (let i = 0; i < this.gisService.getLayerCount(); i++) {
      let layer = this.gisService.getLayer(i);
      if (layer !== undefined && layer.visible) {
        return layer;
      }
    }
    return undefined;
  }

  private hasMixedVisibleReference(): boolean {
    let first = this.firstVisibleLayer();
    if (first === undefined) {
      return false;
    }
    for (let i = 0; i < this.gisService.getLayerCount(); i++) {
      let layer = this.gisService.getLayer(i);
      if (layer !== undefined && layer.visible) {
        if (layer.info.crs !== first.info.crs ||
          layer.info.coordinateUnitName !== first.info.coordinateUnitName ||
          layer.info.coordinateUnitType !== first.info.coordinateUnitType) {
          return true;
        }
      }
    }
    return false;
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

  private layerUnitText(layer: GisLoadedLayer): string {
    if (layer.info.coordinateUnitName.length > 0) {
      return layer.info.coordinateUnitName;
    }
    return '单位未声明';
  }

  private layerReferenceText(layer: GisLoadedLayer): string {
    if (layer.info.crs.length === 0 && layer.info.crsDescription.length === 0 &&
      layer.info.crsFriendlyName.length === 0) {
      return 'CRS 未声明';
    }
    let crsName = this.layerCrsName(layer);
    let unitText = this.layerUnitText(layer);
    if (layer.info.crsIsGeographic) {
      let ellipsoidText = layer.info.ellipsoidAcronym.length > 0 ? (' · 椭球 ' + layer.info.ellipsoidAcronym) : '';
      return '地理坐标系 ' + crsName + ellipsoidText + ' · 单位 ' + unitText;
    }
    let geographicText = layer.info.geographicCrsAuthId.length > 0 ? layer.info.geographicCrsAuthId : '地理坐标系未声明';
    let projectionText = layer.info.projectionAcronym.length > 0 ? layer.info.projectionAcronym : '投影方法未声明';
    return '投影坐标系 ' + crsName + ' · 地理坐标系 ' + geographicText + ' · ' + projectionText +
      ' · 单位 ' + unitText;
  }

  private currentMapReferenceText(): string {
    let first = this.firstVisibleLayer();
    if (this.projectCrs.length > 0 && first !== undefined) {
      if (first.info.crs === this.projectCrs || first.info.crs.length === 0) {
        return this.layerReferenceText(first);
      }
      return '工程 ' + this.projectCrs + ' · 图层 ' + this.layerReferenceText(first);
    }
    if (this.projectCrs.length > 0) {
      return '工程 ' + this.projectCrs;
    }
    if (first === undefined) {
      return '无可见图层';
    }
    if (this.hasMixedVisibleReference()) {
      return '可见图层 CRS 不一致';
    }
    return this.layerReferenceText(first);
  }

  private currentMapTitleText(): string {
    let visibleCount = 0;
    let firstName = '';
    let activeName = '';
    for (let i = 0; i < this.gisService.getLayerCount(); i++) {
      let layer = this.gisService.getLayer(i);
      if (layer !== undefined && layer.visible) {
        visibleCount++;
        if (firstName.length === 0) {
          firstName = layer.info.name;
        }
      }
      if (layer !== undefined && i === this.gisService.getActiveLayerIndex()) {
        activeName = layer.info.name;
      }
    }
    if (visibleCount === 0) {
      if (this.gisService.getLayerCount() > 0) {
        return '无可见图层';
      }
      return this.projectMapName;
    }
    if (activeName.length > 0) {
      return activeName + (visibleCount > 1 ? ' 等 ' + visibleCount.toString() + ' 个图层' : '');
    }
    if (visibleCount === 1) {
      return firstName;
    }
    return firstName + ' 等 ' + visibleCount.toString() + ' 个图层';
  }

  private currentMapDescriptionText(): string {
    if (this.gisService.getLayerCount() === 0) {
      return '当前工程没有图层 · ' + this.basemapLayerName();
    }
    if (this.firstVisibleLayer() === undefined) {
      return '所有图层已隐藏 · ' + this.basemapLayerName();
    }
    return this.currentMapTitleText() + ' · ' + this.currentMapReferenceText() + ' · ' + this.basemapLayerName();
  }

  private basemapStatusProblem(): boolean {
    return this.basemapStatus.indexOf('失败') >= 0 || this.basemapStatus.indexOf('错误') >= 0 ||
      this.basemapStatus.indexOf('停用') >= 0;
  }

  private basemapStatusColor(): ResourceColor {
    if (this.basemapStatusProblem()) {
      return $r('app.color.gn_orange_700');
    }
    return $r('app.color.gn_green_700');
  }

  private toggleLayerVisibility(layerIndex: number): void {
    if (layerIndex < 0 || layerIndex >= this.gisService.getLayerCount()) {
      return;
    }
    this.gisService.toggleLayerVisibility(layerIndex);
    this.projectDirty = true;
    this.refreshLayerState();
  }

  private toggleSelectedLayerVisibility(): void {
    let layerIndex = this.selectedOperationalLayerIndex();
    this.toggleLayerVisibility(layerIndex);
  }

  private toggleOnlySelectedLayer(): void {
    let layerIndex = this.selectedOperationalLayerIndex();
    if (layerIndex < 0) {
      return;
    }
    let shouldRestoreAll = true;
    for (let i = 0; i < this.gisService.getLayerCount(); i++) {
      let layer = this.gisService.getLayer(i);
      if (layer !== undefined) {
        if (i !== layerIndex && layer.visible) {
          shouldRestoreAll = false;
        }
      }
    }
    for (let j = 0; j < this.gisService.getLayerCount(); j++) {
      if (shouldRestoreAll) {
        this.gisService.setLayerVisibility(j, true);
      } else {
        this.gisService.setLayerVisibility(j, j === layerIndex);
      }
    }
    this.projectDirty = true;
    this.refreshLayerState();
  }

  private moveSelectedLayer(direction: number): void {
    let layerIndex = this.selectedOperationalLayerIndex();
    let targetIndex = layerIndex + direction;
    if (layerIndex < 0 || targetIndex < 0 || targetIndex >= this.gisService.getLayerCount()) {
      return;
    }
    if (this.gisService.moveLayer(layerIndex, targetIndex)) {
      this.selectedLayerIndex = targetIndex;
      this.projectDirty = true;
      this.refreshLayerState();
    }
  }

  private deleteSelectedLayer(): void {
    let layerIndex = this.selectedOperationalLayerIndex();
    if (layerIndex < 0) {
      return;
    }
    let result = this.gisService.closeLayerByIndex(layerIndex);
    if (result.ok) {
      this.selectedLayerIndex = this.gisService.getActiveLayerIndex();
      this.clearFeatureSelection();
      this.projectDirty = true;
      this.refreshLayerState();
    } else {
      this.editStatus = result.message;
      this.showEditToast(result.message);
    }
  }

  private featureIdArrayContains(featureIds: string[], featureId: string): boolean {
    for (let i = 0; i < featureIds.length; i++) {
      if (featureIds[i] === featureId) {
        return true;
      }
    }
    return false;
  }

  private copyFeatureIds(featureIds: string[]): string[] {
    let result: string[] = [];
    for (let i = 0; i < featureIds.length; i++) {
      result.push(featureIds[i]);
    }
    return result;
  }

  private layerContainsFeature(layer: GisLoadedLayer, featureId: string): boolean {
    for (let i = 0; i < layer.features.length; i++) {
      if (layer.features[i].featureId === featureId) {
        return true;
      }
    }
    return false;
  }

  private activateSelectionLayer(layerIndex: number): boolean {
    if (layerIndex < 0 || layerIndex >= this.gisService.getLayerCount()) {
      return false;
    }
    if (this.selectedLayerIndex !== layerIndex || this.gisService.getActiveLayerIndex() !== layerIndex) {
      this.selectedLayerIndex = layerIndex;
      this.gisService.setActiveLayerIndex(layerIndex);
      this.activeLayerRevision++;
      this.projectDirty = true;
    }
    return true;
  }

  private refreshSelectedFeatureDetails(): void {
    this.selectedFeatureAttrs = [];
    this.selectedFeatureLayerName = '';
    this.selectedFeatureGeomType = 0;
    this.showFeaturePanel = false;
    if (this.selectedFeatureId.length === 0 || this.selectedFeatureLayerIndex < 0) {
      return;
    }
    let layer = this.gisService.getLayer(this.selectedFeatureLayerIndex);
    if (layer === undefined) {
      return;
    }
    this.selectedFeatureLayerName = layer.info.name;
    this.selectedFeatureGeomType = layer.info.geometryType;
    for (let i = 0; i < layer.features.length; i++) {
      if (layer.features[i].featureId === this.selectedFeatureId) {
        this.selectedFeatureAttrs = layer.features[i].attributesPreview;
        this.showFeaturePanel = true;
        break;
      }
    }
    if (this.isCompactLayout() && this.showFeaturePanel) {
      this.layerPanelCollapsed = true;
    }
  }

  private commitFeatureSelection(featureIds: string[], primaryFeatureId: string, layerIndex: number): void {
    let nextIds = this.copyFeatureIds(featureIds);
    this.selectedFeatureIds = nextIds;
    if (nextIds.length === 0) {
      this.selectedFeatureId = '';
      this.selectedFeatureLayerIndex = -1;
    } else {
      this.selectedFeatureId = primaryFeatureId;
      this.selectedFeatureLayerIndex = layerIndex;
    }
    this.refreshSelectedFeatureDetails();
    this.selectedFeatureRevision++;
    this.renderKey++;
  }

  private applyFeatureSelection(featureId: string, layerIndex: number, operation: number): void {
    if (featureId.length === 0 || !this.activateSelectionLayer(layerIndex)) {
      this.commitFeatureSelection([], '', -1);
      return;
    }
    let layer = this.gisService.getLayer(layerIndex);
    if (layer === undefined || !this.layerContainsFeature(layer, featureId)) {
      this.commitFeatureSelection([], '', -1);
      return;
    }
    if (operation !== FEATURE_SELECTION_TOGGLE || this.selectedFeatureLayerIndex !== layerIndex) {
      let replacement: string[] = [];
      replacement.push(featureId);
      this.commitFeatureSelection(replacement, featureId, layerIndex);
      return;
    }
    let nextIds: string[] = [];
    let removed = false;
    for (let i = 0; i < this.selectedFeatureIds.length; i++) {
      let selectedId = this.selectedFeatureIds[i];
      if (selectedId === featureId) {
        removed = true;
      } else {
        nextIds.push(selectedId);
      }
    }
    let primaryFeatureId = '';
    if (!removed) {
      nextIds.push(featureId);
      primaryFeatureId = featureId;
    } else if (nextIds.length > 0) {
      primaryFeatureId = nextIds[nextIds.length - 1];
    }
    this.commitFeatureSelection(nextIds, primaryFeatureId, nextIds.length > 0 ? layerIndex : -1);
  }

  private replaceFeatureSelection(featureIds: string[], layerIndex: number): void {
    if (featureIds.length === 0 || !this.activateSelectionLayer(layerIndex)) {
      this.commitFeatureSelection([], '', -1);
      return;
    }
    let layer = this.gisService.getLayer(layerIndex);
    if (layer === undefined) {
      this.commitFeatureSelection([], '', -1);
      return;
    }
    let nextIds: string[] = [];
    for (let i = 0; i < featureIds.length; i++) {
      let featureId = featureIds[i];
      if (this.layerContainsFeature(layer, featureId) && !this.featureIdArrayContains(nextIds, featureId)) {
        nextIds.push(featureId);
      }
    }
    let primaryFeatureId = nextIds.length > 0 ? nextIds[nextIds.length - 1] : '';
    this.commitFeatureSelection(nextIds, primaryFeatureId, nextIds.length > 0 ? layerIndex : -1);
  }

  private makeFeaturePrimary(featureId: string, layerIndex: number): void {
    if (this.selectedFeatureLayerIndex === layerIndex &&
      this.featureIdArrayContains(this.selectedFeatureIds, featureId)) {
      this.commitFeatureSelection(this.selectedFeatureIds, featureId, layerIndex);
      return;
    }
    this.applyFeatureSelection(featureId, layerIndex, FEATURE_SELECTION_REPLACE);
  }

  private onFeatureSelected(featureId: string, layerIndex: number): void {
    this.applyFeatureSelection(featureId, layerIndex, FEATURE_SELECTION_REPLACE);
  }

  private onMapFeatureSelected(featureId: string, layerIndex: number, operation: number): void {
    this.applyFeatureSelection(featureId, layerIndex, operation);
  }

  private onAttributeFeatureLocated(featureId: string, layerIndex: number): void {
    this.setMapToolMode(MAP_TOOL_IDENTIFY);
    this.makeFeaturePrimary(featureId, layerIndex);
    this.runMapCommand(MAP_COMMAND_ZOOM_PRIMARY);
  }

  private batchAssignSelectedFeatureAttribute(fieldName: string, value: string): GisOperationResult {
    if (this.selectedFeatureIds.length === 0 || this.selectedFeatureLayerIndex < 0) {
      return new GisOperationResult(false, 4, '请先选择至少一个要素');
    }
    if (fieldName.length === 0) {
      return new GisOperationResult(false, 4, '请选择目标字段');
    }
    if (!this.ensureEditSession(this.selectedFeatureLayerIndex)) {
      return new GisOperationResult(false, 4, this.editStatus);
    }
    let selectedIds = this.copyFeatureIds(this.selectedFeatureIds);
    let result = this.gisService.batchAssignSelectedAttribute(this.selectedFeatureLayerIndex, selectedIds,
      fieldName, value);
    this.editStatus = result.message;
    if (result.ok) {
      this.projectDirty = true;
      this.refreshLayerState();
      this.refreshSelectedFeatureDetails();
      this.selectedFeatureRevision++;
      this.renderKey++;
    }
    return result;
  }

  private selectedFeaturePanelKey(): string {
    return 'feature:' + this.selectedFeatureLayerIndex.toString() + ':' + this.selectedFeatureLayerName + ':' +
      this.selectedFeatureId + ':' + this.selectedFeatureRevision.toString();
  }

  private lonLatText(lon: number, lat: number): string {
    let lonSuffix = lon >= 0.0 ? 'E' : 'W';
    let latSuffix = lat >= 0.0 ? 'N' : 'S';
    return Math.abs(lon).toFixed(6) + '°' + lonSuffix + ' ' + Math.abs(lat).toFixed(6) + '°' + latSuffix;
  }

  private viewportCoordinateStatus(viewport: MapViewport): string {
    if (this.isExternalBasemapMode(this.basemapMode)) {
      return this.lonLatText(viewport.displayLongitude, viewport.displayLatitude);
    }
    let first = this.firstVisibleLayer();
    if (first === undefined) {
      return viewport.centerX.toFixed(6) + ', ' + viewport.centerY.toFixed(6);
    }
    if (first.info.coordinateUnitType === 1) {
      return this.lonLatText(viewport.centerX, viewport.centerY);
    }
    if (first.info.coordinateUnitType === 2 && first.info.crs.length > 0) {
      let transformResult: GisCoordinateTransformResult =
        this.gisService.transformCoordinate(first.info.crs, 'EPSG:4326', viewport.centerX, viewport.centerY);
      if (transformResult.ok) {
        return viewport.centerX.toFixed(3) + ', ' + viewport.centerY.toFixed(3) + ' · ' +
          this.lonLatText(transformResult.x, transformResult.y);
      }
    }
    return viewport.centerX.toFixed(6) + ', ' + viewport.centerY.toFixed(6);
  }

  private onViewportChanged(viewport: MapViewport): void {
    this.mapUnitsPerPixel = viewport.getMapUnitsPerPixel();
    if (this.isExternalBasemapMode(this.basemapMode)) {
      this.viewportCenterX = viewport.displayLongitude.toFixed(6);
      this.viewportCenterY = viewport.displayLatitude.toFixed(6);
    } else {
      this.viewportCenterX = viewport.centerX.toFixed(6);
      this.viewportCenterY = viewport.centerY.toFixed(6);
    }
    this.viewportCoordinateText = this.viewportCoordinateStatus(viewport);
    this.viewportScale = viewport.scaleLabel;
    this.mapReferenceStatus = this.currentMapReferenceText();
    this.publishLinkedViewport(viewport);
    this.scheduleMapThumbnailCapture(false);
  }

  private publishLinkedViewport(viewport: MapViewport): void {
    if (!this.linkedMapViewEnabled) {
      return;
    }
    AppStorage.setOrCreate<number>(GN_MULTI_MAP_VIEWPORT_CENTER_X_KEY, viewport.centerX);
    AppStorage.setOrCreate<number>(GN_MULTI_MAP_VIEWPORT_CENTER_Y_KEY, viewport.centerY);
    AppStorage.setOrCreate<number>(GN_MULTI_MAP_VIEWPORT_SCALE_KEY, viewport.scale);
    AppStorage.setOrCreate<string>(GN_MULTI_MAP_VIEWPORT_SOURCE_KEY, this.localViewportSourceId);
    let revision: number | undefined = AppStorage.get<number>(GN_MULTI_MAP_VIEWPORT_REVISION_KEY);
    AppStorage.setOrCreate<number>(GN_MULTI_MAP_VIEWPORT_REVISION_KEY, revision === undefined ? 1 : revision + 1);
  }

  private onLinkedViewportStorageChanged(): void {
    if (!this.linkedMapViewEnabled) {
      return;
    }
    if (this.linkedViewportSource === this.localViewportSourceId) {
      return;
    }
    if (this.linkedViewportScale <= 0.000000001) {
      return;
    }
    this.mapViewportApplyRevision++;
  }

  private selectedFeatureStatusText(): string {
    if (this.selectedFeatureIds.length > 0) {
      return '已选要素: ' + this.selectedFeatureIds.length.toString();
    }
    return '已选要素: 0';
  }

  private selectedFeatureCountForLayer(layerIndex: number): number {
    if (this.selectedFeatureLayerIndex === layerIndex) {
      return this.selectedFeatureIds.length;
    }
    return 0;
  }

  private contentsSectionSummary(): string {
    if (this.contentsSection === CONTENTS_SOURCE) {
      return '数据源、坐标系、字段和单位';
    }
    if (this.contentsSection === CONTENTS_SELECTION) {
      return this.selectedFeatureStatusText();
    }
    if (this.contentsSection === CONTENTS_LABELING) {
      return '标注字段、避让和比例尺范围';
    }
    if (this.contentsSection === CONTENTS_EDITING) {
      return '当前编辑目标：' + this.activeEditLayerText();
    }
    return this.catalogSummaryText();
  }

  private activeEditLayerText(): string {
    let layerIndex = this.selectedOperationalLayerIndex();
    let layer = this.gisService.getLayer(layerIndex);
    if (layer === undefined) {
      return '未选择图层';
    }
    return layer.info.name + ' · ' + this.geometryName(layer.info.geometryType);
  }

  private layerRendererText(layer: GisLoadedLayer): string {
    return this.layerPresentationCoordinator.rendererText(layer);
  }

  private layerLabelText(layer: GisLoadedLayer): string {
    return this.layerPresentationCoordinator.labelText(layer);
  }

  private layerSourcePathText(path: string): string {
    return this.layerPresentationCoordinator.sourcePathText(path);
  }

  private catalogSummaryText(): string {
    return this.layerCount.toString() + ' 个图层 · ' + this.totalFeatures.toString() + ' 个要素';
  }

  private closeFeaturePanel(): void {
    this.clearFeatureSelection();
  }

  private updateCompactLayout(width: number, height: number): void {
    let nextCompactLayout: boolean = width <= COMPACT_LAYOUT_MAX_WIDTH || height <= COMPACT_LAYOUT_MAX_HEIGHT;
    if (nextCompactLayout === this.compactLayout) {
      return;
    }
    this.compactLayout = nextCompactLayout;
    if (this.isCompactLayout()) {
      this.layerPanelCollapsed = true;
      this.rightDockCollapsed = true;
    }
  }

  private isCompactLayout(): boolean {
    if (this.interfaceDensity === INTERFACE_DENSITY_COMPACT) {
      return true;
    }
    if (this.interfaceDensity === INTERFACE_DENSITY_COMFORTABLE) {
      return false;
    }
    return this.compactLayout;
  }

  private paneRadiusValue(): number {
    if (this.materialQuality === MATERIAL_QUALITY_EFFICIENT) {
      return 5;
    }
    if (this.materialQuality === MATERIAL_QUALITY_REFINED) {
      return 14;
    }
    return 10;
  }

  private itemRadiusValue(): number {
    if (this.materialQuality === MATERIAL_QUALITY_EFFICIENT) {
      return 2;
    }
    if (this.materialQuality === MATERIAL_QUALITY_REFINED) {
      return 10;
    }
    return 6;
  }

  private materialSurfaceColor(fallback: ResourceColor): ResourceColor {
    if (MaterialStyle.canUseSystemMaterial() && MaterialStyle.shouldUseNativeMaterial(this.materialEnabled)) {
      return Color.Transparent;
    }
    return fallback;
  }

  private toggleSidePanel(side: number): void {
    if (side === 0) {
      this.layerPanelVisible = true;
      this.layerPanelCollapsed = !this.layerPanelCollapsed;
      if (this.isCompactLayout() && !this.layerPanelCollapsed) {
        this.rightDockCollapsed = true;
        this.showFeaturePanel = false;
      }
    } else {
      this.rightDockVisible = true;
      this.rightDockCollapsed = !this.rightDockCollapsed;
      if (!this.rightDockCollapsed) {
        this.showFeaturePanel = false;
        if (this.isCompactLayout()) {
          this.layerPanelCollapsed = true;
        }
      }
    }
  }

  private closeSidePanel(side: number): void {
    if (side === 0) {
      this.layerPanelVisible = false;
      this.layerPanelCollapsed = false;
    } else {
      this.rightDockVisible = false;
      this.rightDockCollapsed = false;
      this.showFeaturePanel = false;
    }
    promptAction.showToast({
      message: '可在"视图"菜单中重新打开此面板',
      duration: 2500
    });
  }

  private restoreSidePanel(side: number): void {
    if (side === 0) {
      this.layerPanelVisible = true;
      this.layerPanelCollapsed = false;
      if (this.isCompactLayout()) {
        this.rightDockCollapsed = true;
        this.showFeaturePanel = false;
      }
    } else {
      this.rightDockVisible = true;
      this.rightDockCollapsed = false;
      this.showFeaturePanel = false;
      if (this.isCompactLayout()) {
        this.layerPanelCollapsed = true;
      }
    }
  }

  private onAnalysisToolCompleted(): void {
    this.selectedLayerIndex = this.gisService.getActiveLayerIndex();
    this.projectDirty = true;
    this.clearFeatureSelection();
    this.refreshLayerState();
    this.runMapCommand(MAP_COMMAND_FULL_EXTENT);
  }

  private onQgisCoreLayerMetadataRefreshed(): void {
    this.selectedLayerIndex = this.gisService.getActiveLayerIndex();
    this.refreshLayerState();
  }

  private backstageDialogTitle(): Resource {
    if (this.backstageSection === BACKSTAGE_ABOUT) {
      return $r('app.string.gn_backstage_about');
    } else if (this.backstageSection === BACKSTAGE_HELP) {
      return $r('app.string.gn_backstage_help');
    } else if (this.backstageSection === BACKSTAGE_SETTINGS) {
      return $r('app.string.gn_settings_title');
    }
    return $r('app.string.gn_backstage_file');
  }

  private openBackstage(section: number): void {
    if (section === BACKSTAGE_SETTINGS) {
      this.appSettingsTrigger = !this.appSettingsTrigger;
      return;
    }
    this.backstageSection = section;
    this.backstageVisible = true;
  }

  private closeBackstage(): void {
    this.backstageVisible = false;
  }

  private async toggleWindowTopmost(): Promise<void> {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let windowStage = ctx.windowStage;
      let mainWindow = windowStage.getMainWindowSync();
      let newState = !this.isWindowTopmost;
      await mainWindow.setWindowTopmost(newState);
      this.isWindowTopmost = newState;
      this.editStatus = newState ? '窗口已置顶' : '窗口已取消置顶';
    } catch (err) {
      hilog.error(0x0000, 'GeoNest', 'toggleWindowTopmost failed: %{public}s', String(err));
      this.editStatus = '置顶操作失败';
    }
  }

  private showStatusCommand(status: string): void {
    this.editStatus = status;
  }

  private runBackstageAction(actionId: number): void {
    this.closeBackstage();
    this.handleOperation(actionId);
  }

  private backstageMapStatusText(): string {
    if (this.basemapStatus.length > 0) {
      return this.basemapStatus;
    }
    return this.basemapLayerName();
  }

  private backstageNativeStatusText(): string {
    if (this.nativeBridgeAvailable) {
      return this.nativeBridgeVersion + ' · ' + this.nativeBridgeProfile;
    }
    return 'GIS 内核未连接';
  }

  private backstageProjectFileText(): string {
    if (this.projectFileName.length > 0) {
      return this.projectFileName;
    }
    return '未保存工程文件';
  }

  private backstageLayerStatsText(): string {
    return this.layerCount.toString() + ' 个图层 · ' + this.totalFeatures.toString() + ' 个要素';
  }
  @Builder
  backstageDialogContent() {
    WorkbenchBackstage({
      section: this.backstageSection,
      dialogTitle: this.backstageDialogTitle(),
      projectName: this.projectDisplayName(),
      projectFileText: this.backstageProjectFileText(),
      projectOwner: this.projectOwner.length > 0 ? this.projectOwner : '未设置',
      projectMapName: this.projectMapName,
      projectWorkspaceName: this.projectWorkspaceName,
      layerStatsText: this.backstageLayerStatsText(),
      mapReferenceStatus: this.mapReferenceStatus,
      mapStatusText: this.backstageMapStatusText(),
      nativeBridgeVersion: this.nativeBridgeVersion,
      openSourceNotices: this.openSourceNotices,
      noticesExpanded: this.openSourceNoticesExpanded,
      paneRadius: this.paneRadiusValue(),
      itemRadius: this.itemRadiusValue(),
      onAction: (actionId: number): void => {
        this.runBackstageAction(actionId);
      },
      onDismiss: (): void => {
        this.backstageVisible = false;
      },
      onNoticesExpandedChanged: (expanded: boolean): void => {
        this.openSourceNoticesExpanded = expanded;
      }
    })
  }


  @Builder
  customTitleBar() {
    WorkbenchWindowTitleBar({
      isWindowTopmost: this.isWindowTopmost,
      onMinimize: (): void => {
        this.windowMinimize();
      },
      onToggleTopmost: (): void => {
        this.toggleWindowTopmost();
      },
      onClose: (): void => {
        this.windowClose();
      },
      onStartDrag: (): void => {
        this.startWindowDrag();
      }
    })
  }

  private async startWindowDrag(): Promise<void> {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let mainWindow = ctx.windowStage.getMainWindowSync();
      await mainWindow.startMoving();
    } catch (err) {
      hilog.error(0x0000, 'GeoNest', 'startWindowDrag failed: %{public}s', String(err));
    }
  }

  private async windowMinimize(): Promise<void> {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let mainWindow = ctx.windowStage.getMainWindowSync();
      await mainWindow.minimize();
    } catch (err) {
      hilog.error(0x0000, 'GeoNest', 'windowMinimize failed: %{public}s', String(err));
    }
  }

  private windowClose(): void {
    if (!this.projectDirty && !this.hasPendingEditSessions()) {
      this.terminateWorkspace(true);
      return;
    }
    if (this.closeDialogShowing) {
      return;
    }
    this.closeDialogShowing = true;
    this.getUIContext().showAlertDialog({
      title: $r('app.string.gn_close_unsaved_title'),
      message: $r('app.string.gn_close_unsaved_message'),
      autoCancel: false,
      buttons: [
        {
          value: $r('app.string.gn_close_save_exit'),
          action: () => {
            this.closeDialogShowing = false;
            this.saveProjectAndExit();
          }
        },
        {
          value: $r('app.string.gn_close_discard_exit'),
          action: () => {
            this.closeDialogShowing = false;
            if (this.rollbackPendingEditSessions()) {
              this.terminateWorkspace(true);
            }
          }
        },
        {
          value: $r('app.string.gn_close_cancel'),
          action: () => {
            this.closeDialogShowing = false;
          }
        }
      ]
    });
  }

  private hasPendingEditSessions(): boolean {
    return this.gisService.hasActiveEditSessions();
  }

  private commitPendingEditSessions(): boolean {
    if (!this.gisService.hasActiveEditSessions()) {
      return true;
    }
    let result: GisOperationResult = this.gisService.commitAllEditSessions();
    this.editStatus = result.message;
    if (!result.ok) {
      this.showEditToast(result.message);
      return false;
    }
    this.projectDirty = true;
    this.refreshLayerState();
    return true;
  }

  private rollbackPendingEditSessions(): boolean {
    if (!this.gisService.hasActiveEditSessions()) {
      return true;
    }
    let result: GisOperationResult = this.gisService.rollbackAllEditSessions();
    this.editStatus = result.message;
    if (!result.ok) {
      this.showEditToast(result.message);
      return false;
    }
    this.refreshLayerState();
    return true;
  }

  private saveProjectAndExit(): void {
    if (this.projectFileUri.length > 0) {
      if (!this.commitPendingEditSessions()) {
        return;
      }
      if (this.saveProjectToUri(this.projectFileUri)) {
        this.terminateWorkspace(true);
      }
      return;
    }
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      documentPicker.save(this.buildProjectSaveOptions()).then((result: Array<string>) => {
        if (result.length > 0 && this.commitPendingEditSessions() && this.saveProjectToUri(result[0])) {
          this.terminateWorkspace(true);
        }
      }).catch(() => {
        hilog.warn(LOG_TAG, LOG_DOMAIN, 'saveProjectAndExit: picker cancelled');
      });
    } catch (error) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'saveProjectAndExit failed: %{public}s', String(error));
    }
  }

  private async terminateWorkspace(clearRecovery: boolean): Promise<void> {
    if (clearRecovery) {
      this.recoveryManager.clear();
      this.recoveryPointAvailable = false;
    }
    this.stopRecoveryTimer();
    if (this.gestureShareModel !== null) {
      this.gestureShareModel.stopListening();
    }
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      await ctx.terminateSelf();
    } catch (error) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'terminateWorkspace failed: %{public}s', String(error));
      this.initializeRecoveryProtection();
      if (this.projectDirty) {
        this.saveRecoverySnapshot();
      }
      if (this.gestureShareModel !== null) {
        this.gestureShareModel.startListening();
      }
    }
  }

  @Builder
  titleArea() {
    WorkbenchTitleArea({
      projectStateText: this.projectStateLabel(),
      searchText: this.commandSearchText,
      userLoggedIn: this.userLoggedIn,
      userAvatarUri: this.userAvatarUri,
      userNickName: this.userNickName,
      itemRadius: this.itemRadiusValue(),
      surfaceColor: this.materialSurfaceColor($r('app.color.gn_paper')),
      onOpenBackstage: (): void => {
        this.openBackstage(BACKSTAGE_INFO);
      },
      onOpenProjectInfo: (): void => {
        this.openWorkspaceDialog(1);
      },
      onOpenQgisCore: (): void => {
        this.openWorkspaceDialog(8);
      },
      onToggleSettings: (): void => {
        this.appSettingsTrigger = !this.appSettingsTrigger;
      },
      onSearchClick: (): void => {
        this.commandSearchSuggestionsVisible = this.normalizedSearchText(this.commandSearchText).length > 0;
      },
      onSearchChanged: (value: string): void => {
        this.commandSearchText = value;
        this.commandSearchSuggestionsVisible = this.normalizedSearchText(value).length > 0;
      },
      onSearchSubmit: (value: string): void => {
        this.runGlobalSearch(value);
      },
      onLogin: (): void => {
        this.handleHuaweiLogin();
      },
      onLogout: (): void => {
        this.handleHuaweiLogout();
      }
    })
  }

  @Builder
  commandSearchSuggestionsPopup() {
    WorkbenchCommandSearchPopup({
      searchText: this.commandSearchText,
      candidates: this.buildGlobalSearchCandidates(this.commandSearchText),
      itemRadius: this.itemRadiusValue(),
      paneRadius: this.paneRadiusValue(),
      surfaceColor: this.materialSurfaceColor($r('app.color.gn_paper')),
      resolveGeometryIcon: (geometryType: number): Resource => {
        return this.geometryIcon(geometryType);
      },
      onSelect: (item: GlobalSearchCandidate): void => {
        this.executeSearchCandidate(item);
      }
    })
  }

  @Builder
  ribbonTabBar() {
    WorkbenchRibbonTabs({
      activeTab: this.activeRibbonTab,
      compactLayout: this.isCompactLayout(),
      itemRadius: this.itemRadiusValue(),
      surfaceColor: this.materialSurfaceColor($r('app.color.gn_pane')),
      onTabChanged: (tabIndex: number): void => {
        this.activeRibbonTab = tabIndex;
      },
      onOpenBackstage: (): void => {
        this.openBackstage(BACKSTAGE_INFO);
      },
      onOperation: (actionId: number): void => {
        this.handleOperation(actionId);
      }
    })
  }

  private basemapName(): string {
    if (this.basemapMode === BASEMAP_ONLINE_STANDARD) {
      return '浅色在线地图';
    }
    if (this.basemapMode === BASEMAP_TERRAIN) {
      return '地形在线地图';
    }
    if (this.basemapMode === BASEMAP_IMAGERY) {
      return '影像在线地图';
    }
    if (this.basemapMode === BASEMAP_HARMONY_STANDARD) {
      return '花瓣标准地图';
    }
    if (this.basemapMode === BASEMAP_HARMONY_TERRAIN) {
      return '花瓣地形地图';
    }
    if (this.basemapMode === BASEMAP_HARMONY_IMAGERY) {
      return '花瓣影像地图';
    }
    return '本地矢量底图';
  }

  private basemapNameForMode(mode: number): string {
    if (mode === BASEMAP_ONLINE_STANDARD) {
      return '浅色在线地图';
    }
    if (mode === BASEMAP_TERRAIN) {
      return '地形在线地图';
    }
    if (mode === BASEMAP_IMAGERY) {
      return '影像在线地图';
    }
    if (mode === BASEMAP_HARMONY_STANDARD) {
      return '花瓣标准地图';
    }
    if (mode === BASEMAP_HARMONY_TERRAIN) {
      return '花瓣地形地图';
    }
    if (mode === BASEMAP_HARMONY_IMAGERY) {
      return '花瓣影像地图';
    }
    return '本地矢量底图';
  }

  private isHarmonyBasemapMode(mode: number): boolean {
    return mode === BASEMAP_HARMONY_STANDARD || mode === BASEMAP_HARMONY_TERRAIN ||
      mode === BASEMAP_HARMONY_IMAGERY;
  }

  private isExternalBasemapMode(mode: number): boolean {
    return mode !== BASEMAP_VECTOR;
  }

  private basemapLayerName(): string {
    if (this.isHarmonyBasemapMode(this.basemapMode)) {
      return '花瓣地图 · ' + this.basemapName();
    }
    if (this.basemapMode === BASEMAP_VECTOR) {
      return '本地底图 · ' + this.basemapName();
    }
    return '在线底图 · ' + this.basemapName();
  }

  private basemapDatumName(): string {
    if (this.basemapDatumMode === BASEMAP_DATUM_WGS84) {
      return '原始/WGS84';
    }
    if (this.basemapDatumMode === BASEMAP_DATUM_GCJ02) {
      return 'WGS84→GCJ-02';
    }
    return '自动坐标';
  }

  private setBasemapDatumMode(mode: number): void {
    this.basemapDatumMode = mode;
    this.editStatus = '底图坐标模式：' + this.basemapDatumName();
    this.projectDirty = true;
    this.renderKey++;
  }

  private setBasemapMode(mode: number): void {
    this.basemapMode = mode;
    if (mode === BASEMAP_VECTOR) {
      this.basemapStatus = '';
    } else if (this.isHarmonyBasemapMode(mode)) {
      this.basemapStatus = '正在加载花瓣地图：' + this.basemapNameForMode(mode);
    } else {
      this.basemapStatus = '正在加载底图：' + this.basemapName();
    }
    this.editStatus = '已切换底图：' + this.basemapName();
    this.projectDirty = true;
    this.renderKey++;
  }

  @Builder
  cloudSyncDialogContent() {
    WorkbenchCloudSyncSheet({
      statusText: this.cloudSyncStatusText,
      projectText: this.cloudSyncProjectText,
      timeText: this.cloudSyncTimeText,
      actionText: this.cloudSyncActionText,
      logs: this.cloudSyncLogs,
      paneRadius: this.paneRadiusValue(),
      surfaceColor: this.materialSurfaceColor($r('app.color.gn_pane')),
      onClose: (): void => {
        this.cloudSyncSheetVisible = false;
      },
      onManage: (): void => {
        this.openCloudSyncSheet();
      },
      onPush: (): void => {
        this.uploadProjectToCloud();
      },
      onPull: (): void => {
        this.pullProjectFromCloud();
      }
    })
  }

  @Builder
  operationArea() {
    Column() {
      if (!this.isCompactLayout()) {
        this.titleArea()
      }
      this.ribbonTabBar()
      WorkbenchRibbonPanel({
        activeTab: this.activeRibbonTab,
        mapToolMode: this.mapToolMode,
        basemapMode: this.basemapMode,
        basemapName: this.basemapName(),
        linkedMapViewEnabled: this.linkedMapViewEnabled,
        itemRadius: this.itemRadiusValue(),
        onOperation: (actionId: number): void => {
          this.handleOperation(actionId);
        },
        onSetMapToolMode: (toolMode: number): void => {
          this.setMapToolMode(toolMode);
        },
        onSetBasemapMode: (mode: number): void => {
          this.setBasemapMode(mode);
        },
        onSetBasemapDatumMode: (mode: number): void => {
          this.setBasemapDatumMode(mode);
        },
        onRestoreSidePanel: (side: number): void => {
          this.restoreSidePanel(side);
        },
        onOpenBackstage: (section: number): void => {
          this.openBackstage(section);
        },
        onImportFromLocal: (): void => {
          this.importFromLocal();
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .height(this.isCompactLayout() ? 116 : 168)
    .backgroundBlurStyle(MaterialStyle.toolbarBlurStyle())
    .backgroundColor(this.materialSurfaceColor($r('app.color.gn_pane')))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line_strong') })
  }

  @Builder
  panelHeaderAction(icon: Resource, side: number, actionKind: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      this.symbol(icon, $r('sys.color.icon_secondary'), 14)
    }
    .width(26)
    .height(26)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      if (actionKind === 0) {
        this.toggleSidePanel(side);
      } else {
        this.closeSidePanel(side);
      }
    })
  }

  @Builder
  panelHeader(title: ResourceStr, side: number, collapsed: boolean) {
    Row({ space: 6 }) {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
        .layoutWeight(1)
      if (side === 0) {
        this.panelHeaderAction(collapsed ? $r('sys.symbol.chevron_right') : $r('sys.symbol.chevron_left'), side, 0)
      } else {
        this.panelHeaderAction(collapsed ? $r('sys.symbol.chevron_left') : $r('sys.symbol.chevron_right'), side, 0)
      }
      this.panelHeaderAction($r('sys.symbol.xmark'), side, 1)
    }
    .height(36)
    .padding({ left: 10, right: 8 })
    .backgroundBlurStyle(MaterialStyle.toolbarBlurStyle())
    .backgroundColor(this.materialSurfaceColor($r('app.color.gn_paper')))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  panelRailButton(icon: Resource, side: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      this.symbol(icon, $r('sys.color.icon_secondary'), 15)
    }
    .width(30)
    .height(30)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.restoreSidePanel(side);
    })
  }

  @Builder
  panelRailCloseButton(side: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      this.symbol($r('sys.symbol.xmark'), $r('sys.color.icon_secondary'), 13)
    }
    .width(30)
    .height(30)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.closeSidePanel(side);
    })
  }

  @Builder
  contentsPanelBody() {
    WorkbenchContentsPanel({
      section: this.contentsSection,
      searchText: this.contentsSearchText,
      selectedLayerIndex: this.selectedLayerIndex,
      layerCount: this.layerCount,
      sectionSummary: this.contentsSectionSummary(),
      basemapLayerName: this.basemapLayerName(),
      items: this.buildFilteredLayerDisplayList(this.contentsSearchText),
      itemRadius: this.itemRadiusValue(),
      resolveGeometryIcon: (geometryType: number): Resource => {
        return this.geometryIcon(geometryType);
      },
      onAction: (actionId: number): void => {
        this.handleOperation(actionId);
      },
      onSectionChanged: (section: number): void => {
        this.contentsSection = section;
      },
      onSearchTextChanged: (value: string): void => {
        this.contentsSearchText = value;
      },
      onToggleVisibility: (layerIndex: number): void => {
        this.toggleLayerVisibility(layerIndex);
      },
      onSelectLayer: (layerIndex: number): void => {
        this.selectLayer(layerIndex);
      },
      onOpenLabeling: (): void => {
        this.openWorkspaceDialog(11);
      },
      onCreateDragItemInfo: (event: DragEvent, layerIndex: number): DragItemInfo => {
        return this.createLayerDragItemInfo(event, layerIndex);
      },
      onLayerDrop: (event: DragEvent, extraParams: string, layerIndex: number): void => {
        this.handleLayerDrop(event, extraParams, layerIndex);
      }
    })
  }

  private geometryIcon(geomType: number): Resource {
    if (geomType === 1) return $r('sys.symbol.location_up');
    if (geomType === 2) return $r('sys.symbol.road_lanes_badge_minus');
    return $r('sys.symbol.layer');
  }

  private layerDisplayColor(layer: GisLoadedLayer): string {
    return this.layerPresentationCoordinator.displayColor(layer);
  }

  private buildLayerDisplayList(): LayerDisplayItem[] {
    let items: LayerDisplayItem[] = [];
    for (let i = 0; i < this.gisService.getLayerCount(); i++) {
      let layer = this.gisService.getLayer(i);
      if (layer !== undefined) {
        let item = new LayerDisplayItem();
        item.index = i;
        item.id = layer.info.layerId;
        item.name = layer.info.name;
        item.geomType = layer.info.geometryType;
        item.visible = layer.visible;
        item.featureCount = layer.info.featureCount;
        item.fieldCount = layer.info.fields.length;
        item.crs = layer.info.crs;
        item.symbolColor = this.layerDisplayColor(layer);
        item.sourcePath = layer.sourcePath;
        item.sourceDisplayText = this.layerSourcePathText(layer.sourcePath);
        item.referenceText = this.layerReferenceText(layer);
        item.geometryText = this.geometryName(layer.info.geometryType);
        item.rendererText = this.layerRendererText(layer);
        item.labelText = this.layerLabelText(layer);
        item.fieldText = this.layerFieldSearchText(layer);
        item.selectedFeatureCount = this.selectedFeatureCountForLayer(i);
        item.activeEdit = this.selectedOperationalLayerIndex() === i;
        item.stateKey = item.id + ':' + (item.visible ? 'visible' : 'hidden') + ':' +
          this.renderKey.toString() + ':' + this.activeLayerRevision.toString() + ':' +
          (this.selectedLayerIndex === i ? 'selected' : 'idle') + ':' + item.selectedFeatureCount.toString() + ':' +
          (item.activeEdit ? 'editing' : 'inactive');
        items.push(item);
      }
    }
    return items;
  }

  @Builder
  layerPanel() {
    Column() {
      this.panelHeader($r('app.string.gn_workbench_layer_panel'), 0, this.layerPanelCollapsed)
      this.contentsPanelBody()
    }
    .width(306)
    .height('100%')
    .backgroundBlurStyle(MaterialStyle.panelBlurStyle())
    .backgroundColor(this.materialSurfaceColor($r('app.color.gn_pane')))
    .borderRadius(this.paneRadiusValue())
    .clip(true)
    .border({ width: 1, color: $r('app.color.gn_line_strong') })
  }

  @Builder
  layerPanelRail(closable: boolean) {
    Column({ space: 8 }) {
      this.panelRailButton($r('sys.symbol.chevron_right'), 0)
      Text('图层')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
        .textAlign(TextAlign.Center)
        .width('100%')
      if (closable) {
        this.panelRailCloseButton(0)
      }
      Blank()
    }
    .width(42)
    .height('100%')
    .padding({ top: 6 })
    .backgroundBlurStyle(MaterialStyle.panelBlurStyle())
    .backgroundColor(this.materialSurfaceColor($r('app.color.gn_pane')))
    .borderRadius(this.paneRadiusValue())
    .clip(true)
    .border({ width: 1, color: $r('app.color.gn_line_strong') })
  }

  @Builder
  mapTabBar() {
    WorkbenchMapToolbar({
      mapTitle: this.currentMapTitleText(),
      mapTitleRevision: this.activeLayerRevision,
      mapToolMode: this.mapToolMode,
      mapViewMode: this.mapViewMode,
      scene3DVisible: this.scene3DVisible,
      itemRadius: this.itemRadiusValue(),
      surfaceColor: this.materialSurfaceColor($r('app.color.gn_pane_alt')),
      onSelectTool: (toolMode: number): void => {
        this.setMapToolMode(toolMode);
      },
      onSelectViewMode: (mode: number): void => {
        this.mapViewMode = mode;
        if (mode === MAP_VIEW_LAYOUT) {
          this.activeRibbonTab = RIBBON_INSERT;
        }
      },
      onToggleScene3D: (): void => {
        this.scene3DVisible = !this.scene3DVisible;
      },
      onOpenLayoutProperties: (): void => {
        this.openWorkspaceDialog(13);
      }
    })
  }

  private buildLoadedLayers(): GisLoadedLayer[] {
    let result: GisLoadedLayer[] = [];
    for (let i = 0; i < this.gisService.getLayerCount(); i++) {
      let layer = this.gisService.getLayer(i);
      if (layer !== undefined) {
        result.push(layer);
      }
    }
    return result;
  }

  @Builder
  mapCanvas() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.scene3DVisible) {
        GisScene3D({
          onStatusChanged: (summary: string): void => {
            this.basemapStatus = summary;
          }
        })
          .layoutWeight(1)
      } else {
        GisMapCanvas({
        layers: this.buildLoadedLayers(),
        basemapMode: this.basemapMode,
        basemapDatumMode: this.basemapDatumMode,
        selectedFeatureId: this.selectedFeatureId,
        selectedFeatureIds: this.selectedFeatureIds,
        selectedFeatureLayerIndex: this.selectedFeatureLayerIndex,
        renderKey: this.renderKey,
        mapCommand: this.mapCommand,
        mapCommandKey: this.mapCommandKey,
        mapToolMode: this.mapToolMode,
        editLayerIndex: this.selectedOperationalLayerIndex(),
        renderQuality: this.mapRenderQuality,
        framePacing: this.framePacing,
        cacheStrategy: this.cacheStrategy,
        progressiveLoading: this.progressiveLoading,
        pointerSmoothing: this.pointerSmoothing,
        externalViewportKey: this.mapViewportApplyRevision,
        externalViewportCenterX: this.linkedViewportCenterX,
        externalViewportCenterY: this.linkedViewportCenterY,
        externalViewportScale: this.linkedViewportScale,
        onFeatureSelected: (featureId: string, layerIndex: number, operation: number) => {
          this.onMapFeatureSelected(featureId, layerIndex, operation);
        },
        onViewportChanged: (viewport: MapViewport) => {
          this.onViewportChanged(viewport);
        },
        onMeasurementChanged: (summary: string) => {
          this.measurementStatus = summary;
        },
        onEditFeedback: (summary: string, shouldToast: boolean) => {
          if (shouldToast) {
            this.showEditToast(summary);
          }
        },
        onBasemapStatusChanged: (summary: string) => {
          this.basemapStatus = summary;
        },
        onSketchFeatureCreated: (geometryType: number, points: GisCoordinate[]) => {
          this.onSketchFeatureCreated(geometryType, points);
        },
        onCutSketchCompleted: (points: GisCoordinate[]) => {
          this.onCutSketchCompleted(points);
        },
        onSelectionGeometryCompleted: (selectionWkt: string, crossLayers: boolean) => {
          this.onProviderSelectionCompleted(selectionWkt, crossLayers);
        },
        onNodeEditRequested: (editMode: number, layerIndex: number, featureId: string, partIndex: number,
          pointIndex: number, mapX: number, mapY: number) => {
          this.onNodeEditRequested(editMode, layerIndex, featureId, partIndex, pointIndex, mapX, mapY);
        }
        })
          .layoutWeight(1)
      }

      if (this.layerCount > 0 || this.basemapStatusProblem()) {
        Column() {
          if (this.layerCount > 0) {
            Column() {
              Text(this.layerCount.toString() + ' 个图层 · ' + this.totalFeatures.toString() + ' 个要素')
                .fontSize(12)
                .fontColor($r('app.color.gn_text_primary'))
              Text(this.currentMapDescriptionText())
                .fontSize(11)
                .fontColor($r('app.color.gn_text_muted'))
                .margin({ top: 2 })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding(10)
            .borderRadius(6)
            .backgroundColor($r('app.color.gn_paper'))
            .border({ width: 1, color: $r('app.color.gn_line') })
          }
          if (this.basemapStatusProblem()) {
            Row({ space: 6 }) {
              this.symbol($r('sys.symbol.exclamationmark_triangle'), $r('app.color.gn_orange_700'), 15)
              Text(this.basemapStatus)
                .fontSize(12)
                .fontColor($r('app.color.gn_orange_700'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .height(46)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .borderRadius(6)
            .backgroundColor($r('app.color.gn_paper'))
            .border({ width: 1, color: $r('app.color.gn_line') })
          }
        }
        .width('42%')
        .position({ x: '56%', y: 16 })
      } else {
        Column() {
          Text('地图工作区')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
          Text('点击"添加数据"导入 Shapefile，或加载示例数据')
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
            .margin({ top: 6 })
          Button('加载示例数据', { type: ButtonType.Capsule, stateEffect: true })
            .height(28)
            .fontSize(12)
            .margin({ top: 10 })
            .onClick(() => {
              this.loadDemoLayers();
            })
        }
        .padding(20)
        .borderRadius(8)
        .backgroundColor($r('app.color.gn_paper'))
        .border({ width: 1, color: $r('app.color.gn_line') })
        .position({ x: '35%', y: '35%' })
      }

    }
    .id(MAP_THUMBNAIL_CAPTURE_ID)
    .layoutWeight(1)
    .clip(true)
  }

  @Builder
  mapContextMenu() {
    Menu() {
      MenuItem({ content: '全图显示' })
        .onClick(() => {
          this.handleOperation(ACTION_FULL_EXTENT);
        })
      MenuItem({ content: '复制地图上下文' })
        .onClick(() => {
          this.handleOperation(ACTION_COPY_MAP_CONTEXT);
        })
      MenuItem({ content: '从剪贴板粘贴' })
        .onClick(() => {
          this.handleOperation(ACTION_PASTE_CLIPBOARD);
        })
      MenuItem({ content: '打开第二地图窗口' })
        .onClick(() => {
          this.handleOperation(ACTION_OPEN_SECOND_MAP);
        })
      MenuItem({ content: this.linkedMapViewEnabled ? '关闭多地图联动' : '开启多地图联动' })
        .onClick(() => {
          this.handleOperation(ACTION_TOGGLE_LINKED_VIEW);
        })
      MenuItem({ content: '添加数据' })
        .onClick(() => {
          this.handleOperation(ACTION_ADD_DATA);
        })
      MenuItem({ content: '处理任务与历史' })
        .onClick(() => {
          this.handleOperation(ACTION_PROCESSING_BROWSER);
        })
    }
  }

  @Builder
  layoutCanvas() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row({ space: 8 }) {
          Text(this.currentMapTitleText())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.gn_text_primary'))
            .layoutWeight(1)
          Text($r('app.string.gn_layout_live_map_frame'))
            .fontSize(11)
            .fontColor($r('app.color.gn_blue_800'))
        }
        .width('100%')
        .height(38)
        .padding({ left: 18, right: 18 })

        Column() {
          this.mapCanvas()
        }
        .layoutWeight(1)
        .width('100%')
        .border({ width: 1, color: $r('app.color.gn_line_strong') })

        Row({ space: 16 }) {
          Text('GeoNest')
            .fontSize(10)
            .fontColor($r('app.color.gn_text_muted'))
          Blank()
          Text(this.viewportScale)
            .fontSize(10)
            .fontColor($r('app.color.gn_text_muted'))
          Text('↑ N')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.gn_text_primary'))
        }
        .width('100%')
        .height(30)
        .padding({ left: 18, right: 18 })
      }
      .width('86%')
      .height('90%')
      .padding(14)
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line_strong') })
      .shadow({ radius: 18, color: '#33000000', offsetX: 0, offsetY: 5 })
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor($r('app.color.gn_arc_window'))
  }

  @Builder
  mapStatusBar() {
    WorkbenchMapStatusBar({
      viewportScale: this.viewportScale,
      viewportCoordinateText: this.viewportCoordinateText,
      mapReferenceStatus: this.mapReferenceStatus,
      catalogSummary: this.catalogSummaryText(),
      basemapName: this.basemapName(),
      basemapDatumName: this.basemapDatumName(),
      basemapStatus: this.basemapStatus,
      measurementStatus: this.measurementStatus,
      dataLoadStatus: this.dataLoadStatus,
      editStatus: this.editStatus,
      selectedFeatureStatus: this.selectedFeatureStatusText(),
      nativeBridgeVersion: this.nativeBridgeVersion,
      basemapActive: this.basemapMode !== BASEMAP_VECTOR,
      externalBasemap: this.isExternalBasemapMode(this.basemapMode),
      projectDirty: this.projectDirty,
      recoveryPointAvailable: this.recoveryPointAvailable,
      nativeBridgeAvailable: this.nativeBridgeAvailable,
      basemapStatusColor: this.basemapStatusColor(),
      surfaceColor: this.materialSurfaceColor($r('app.color.gn_paper')),
      itemRadius: this.itemRadiusValue()
    })
  }

  @Builder
  mapPanel() {
    Column() {
      this.mapTabBar()
      if (this.mapViewMode === MAP_VIEW_LAYOUT) {
        this.layoutCanvas()
      } else {
        this.mapCanvas()
      }
      this.mapStatusBar()
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundBlurStyle(MaterialStyle.panelBlurStyle())
    .backgroundColor(this.materialSurfaceColor($r('app.color.gn_paper')))
    .borderRadius(this.paneRadiusValue())
    .clip(true)
    .border({ width: 1, color: $r('app.color.gn_line_strong') })
    .bindContextMenu(this.mapContextMenu, ResponseType.RightClick)
  }

  @Builder
  rightTab(label: ResourceStr, index: number) {
    Text(label)
      .height(30)
      .padding({ left: 12, right: 12 })
      .fontSize(13)
      .fontWeight(this.rightPanelIndex === index ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.rightPanelIndex === index ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .border({
        width: { bottom: this.rightPanelIndex === index ? 2 : 0 },
        color: $r('app.color.gn_blue_800')
      })
      .onClick(() => {
        this.rightPanelIndex = index;
      })
  }

  @Builder
  rightPanelHeader() {
    Column() {
      this.panelHeader($r('app.string.gn_workbench_catalog_tools'), 1, this.rightDockCollapsed)
      Row() {
        this.rightTab($r('app.string.gn_workbench_catalog_tab'), 0)
        this.rightTab($r('app.string.gn_workbench_tools_tab'), 1)
        Blank()
      }
      .height(32)
      .backgroundColor($r('app.color.gn_pane'))
    }
  }

  private getCatalogLayer(): GisLoadedLayer | undefined {
    let layerIndex: number = this.selectedOperationalLayerIndex();
    if (layerIndex < 0) {
      return undefined;
    }
    return this.gisService.getLayer(layerIndex);
  }

  private catalogLayerKey(): string {
    let layer: GisLoadedLayer | undefined = this.getCatalogLayer();
    if (layer === undefined) {
      return 'catalog:none:' + this.activeLayerRevision.toString();
    }
    return 'catalog:' + this.selectedOperationalLayerIndex().toString() + ':' + layer.info.layerId + ':' +
      this.activeLayerRevision.toString();
  }

  private catalogFields(): WorkbenchFieldItem[] {
    let layer: GisLoadedLayer | undefined = this.getCatalogLayer();
    if (layer === undefined) {
      return [];
    }
    let result: WorkbenchFieldItem[] = [];
    for (let i: number = 0; i < layer.info.fields.length; i++) {
      let field: GisFieldInfo = layer.info.fields[i];
      result.push(new WorkbenchFieldItem(field.name, field.alias, field.typeName));
    }
    return result;
  }

  private cloudIdentityCatalogText(): string {
    if (this.userLoggedIn) {
      return this.userNickName.length > 0 ? '已登录：' + this.userNickName : '已登录华为账号';
    }
    return '未登录华为账号';
  }

  private cloudSyncCatalogText(): string {
    if (this.cloudSyncProjectText.length > 0 && this.cloudSyncTimeText.length > 0) {
      return this.cloudSyncProjectText + ' · ' + this.cloudSyncTimeText;
    }
    return this.cloudSyncProjectText.length > 0 ? this.cloudSyncProjectText : this.cloudSyncStatusText;
  }

  private currentProjectCatalogText(): string {
    return this.projectFileName.length > 0 ? this.projectFileName : '未保存工程';
  }

  private workspacePathCatalogText(): string {
    try {
      let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      return context.filesDir;
    } catch (error) {
      return '-';
    }
  }

  private activeLayerCatalogText(): string {
    let layer: GisLoadedLayer | undefined = this.gisService.getActiveLayer();
    if (layer === undefined) {
      return '未选择图层';
    }
    return layer.info.name + ' · ' + this.geometryName(layer.info.geometryType) + '图层';
  }

  private activeLayerSourceCatalogText(): string {
    let layer: GisLoadedLayer | undefined = this.gisService.getActiveLayer();
    if (layer === undefined) {
      return '添加数据后显示图层源路径';
    }
    return this.layerSourcePathText(layer.sourcePath);
  }

  @Builder
  catalogContent() {
    WorkbenchCatalogPanel({
      section: this.catalogSection,
      searchText: this.catalogSearchText,
      selectedLayerIndex: this.selectedLayerIndex,
      layerCount: this.layerCount,
      catalogKey: this.catalogLayerKey(),
      catalogSummary: this.catalogSummaryText(),
      filteredLayers: this.buildFilteredLayerDisplayList(this.catalogSearchText),
      layers: this.buildLayerDisplayList(),
      fields: this.catalogFields(),
      recentProjects: this.recentProjects,
      cloudIdentityText: this.cloudIdentityCatalogText(),
      cloudSyncText: this.cloudSyncCatalogText(),
      currentProjectText: this.currentProjectCatalogText(),
      workspacePathText: this.workspacePathCatalogText(),
      activeLayerText: this.activeLayerCatalogText(),
      activeLayerSourceText: this.activeLayerSourceCatalogText(),
      itemRadius: this.itemRadiusValue(),
      resolveGeometryIcon: (geometryType: number): Resource => {
        return this.geometryIcon(geometryType);
      },
      onSectionChanged: (section: number): void => {
        this.catalogSection = section;
      },
      onSearchTextChanged: (value: string): void => {
        this.catalogSearchText = value;
      },
      onRoute: (routeId: number): void => {
        this.openWorkspaceDialog(routeId);
      },
      onAction: (actionId: number): void => {
        this.handleOperation(actionId);
      },
      onUnavailableAction: (): void => {
        this.showStatusCommand('请先添加或选择一个图层');
      },
      onSelectLayer: (layerIndex: number): void => {
        this.selectLayer(layerIndex);
      },
      onOpenRecentProject: (uri: string): void => {
        this.openRecentProject(uri);
      }
    })
  }

  @Builder
  toolsContent() {
    WorkbenchToolsPanel({
      searchText: this.toolSearchText,
      itemRadius: this.itemRadiusValue(),
      onSearchTextChanged: (value: string): void => {
        this.toolSearchText = value;
      },
      onAction: (actionId: number): void => {
        this.handleOperation(actionId);
      }
    })
  }

  @Builder
  rightPanel() {
    Column() {
      this.rightPanelHeader()
      if (this.rightPanelIndex === 0) {
        this.catalogContent()
      } else {
        this.toolsContent()
      }
    }
    .width(318)
    .height('100%')
    .backgroundBlurStyle(MaterialStyle.panelBlurStyle())
    .backgroundColor(this.materialSurfaceColor($r('app.color.gn_pane')))
    .borderRadius(this.paneRadiusValue())
    .clip(true)
    .border({ width: 1, color: $r('app.color.gn_line_strong') })
  }

  @Builder
  rightPanelRail(closable: boolean) {
    Column({ space: 8 }) {
      this.panelRailButton($r('sys.symbol.chevron_left'), 1)
      Text('目录')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
        .textAlign(TextAlign.Center)
        .width('100%')
      Text('工具')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
        .textAlign(TextAlign.Center)
        .width('100%')
      if (closable) {
        this.panelRailCloseButton(1)
      }
      Blank()
    }
    .width(42)
    .height('100%')
    .padding({ top: 6 })
    .backgroundBlurStyle(MaterialStyle.panelBlurStyle())
    .backgroundColor(this.materialSurfaceColor($r('app.color.gn_pane')))
    .borderRadius(this.paneRadiusValue())
    .clip(true)
    .border({ width: 1, color: $r('app.color.gn_line_strong') })
  }

  @Builder
  workArea() {
    Row({ space: this.isCompactLayout() ? 4 : WORK_AREA_GAP }) {
      if (this.layerPanelVisible) {
        if (this.layerPanelCollapsed) {
          this.layerPanelRail(true)
        } else {
          this.layerPanel()
        }
      }
      this.mapPanel()

      if (this.showFeaturePanel) {
        GisFeatureInfoPanel({
          featureId: this.selectedFeatureId,
          featureKey: this.selectedFeaturePanelKey(),
          layerName: this.selectedFeatureLayerName,
          attributes: this.selectedFeatureAttrs,
          geometryType: this.selectedFeatureGeomType,
          featureCount: this.selectedFeatureIds.length,
          onPanelClose: () => {
            this.closeFeaturePanel();
          }
        })
      } else {
        if (this.rightDockVisible) {
          if (this.rightDockCollapsed) {
            this.rightPanelRail(true)
          } else {
            this.rightPanel()
          }
        }
      }
    }
    .layoutWeight(1)
    .width('100%')
    .padding(this.isCompactLayout() ? 4 : WORK_AREA_GAP)
    .backgroundColor($r('app.color.gn_arc_window'))
  }

  build() {
    Stack() {
      Column() {
        this.customTitleBar()
        this.operationArea()
        this.workArea()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.gn_arc_window'))
      .focusable(true)
      .focusOnTouch(true)
      .allowDrop([utd.UniformDataType.FILE, utd.UniformDataType.FILE_URI, utd.UniformDataType.FOLDER,
        utd.UniformDataType.PLAIN_TEXT])
      .onDragEnter((_event: DragEvent) => {
        this.dragDropActive = true;
      })
      .onDragLeave((_event: DragEvent) => {
        this.dragDropActive = false;
      })
      .onDrop((event: DragEvent, extraParams?: string) => {
        this.dragDropActive = false;
        this.handleWorkbenchDrop(event, extraParams === undefined ? '' : extraParams);
      })
      .onKeyEvent((event: KeyEvent): boolean => {
        return this.handleKeyEvent(event);
      })

      if (this.dragDropActive) {
        Text('释放以导入 GIS 数据或调整图层顺序')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_blue_800'))
          .padding({ left: 18, right: 18, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.gn_blue_100'))
          .borderRadius(16)
          .border({ width: 1, color: $r('app.color.gn_blue_800') })
          .position({ x: 24, y: 106 })
          .zIndex(20)
      }

      if (this.shouldShowCommandSearchSuggestions()) {
        this.commandSearchSuggestionsPopup()
      }

      Row().width(0).height(0)
        .bindSheet($$this.backstageVisible, this.backstageDialogContent(), {
          width: 900,
          height: 690,
          detents: [690],
          preferType: SheetType.CENTER,
          dragBar: false,
          backgroundColor: Color.Transparent,
          blurStyle: BlurStyle.Regular,
          showClose: false,
          onDisappear: (): void => { this.backstageVisible = false; }
        })

      Row().width(0).height(0)
        .bindSheet($$this.cloudSyncSheetVisible, this.cloudSyncDialogContent(), {
          width: 900,
          height: 690,
          detents: [690],
          preferType: SheetType.CENTER,
          dragBar: false,
          backgroundColor: Color.Transparent,
          blurStyle: BlurStyle.Regular,
          showClose: false,
          onDisappear: (): void => { this.cloudSyncSheetVisible = false; }
        })

      ProjectInfoSheet({
        trigger: this.projectInfoTrigger,
        projectName: this.projectName,
        projectOwner: this.projectOwner,
        projectCrs: this.projectCrs,
        projectMapName: this.projectMapName,
        projectWorkspaceName: this.projectWorkspaceName,
        projectDescription: this.projectDescription,
        projectFileName: this.projectFileName,
        projectFileUri: this.projectFileUri,
        onProjectInfoChanged: (params: GeoNestProjectParameters) => {
          this.applyProjectParameters(params);
          this.projectDirty = true;
          this.mapReferenceStatus = this.currentMapReferenceText();
        }
      })
      NewProjectSheet({
        trigger: this.newProjectTrigger,
        recentProjects: this.recentProjects,
        recentRevision: this.recentProjectRevision,
        onCreateProject: (params: GeoNestProjectParameters) => {
          this.createProjectWithParameters(params);
        },
        onOpenRecentProject: (uri: string) => {
          this.openRecentProject(uri);
        }
      })
      QgisCoreSheet({
        trigger: this.qgisCoreTrigger,
        onLayerMetadataRefreshed: () => {
          this.onQgisCoreLayerMetadataRefreshed();
        },
        onCreateProject: () => {
          this.handleOperation(ACTION_NEW_PROJECT);
        },
        onOpenProject: () => {
          this.handleOperation(ACTION_OPEN_PROJECT);
        },
        onSaveProject: () => {
          this.handleOperation(ACTION_SAVE_PROJECT);
        },
        onOpenProjectInfo: () => {
          this.handleOperation(ACTION_PROJECT_INFO);
        },
        onAddData: () => {
          this.handleOperation(ACTION_ADD_DATA);
        },
        onZoomIn: () => {
          this.handleOperation(ACTION_ZOOM_IN);
        },
        onZoomOut: () => {
          this.handleOperation(ACTION_ZOOM_OUT);
        },
        onFullExtent: () => {
          this.handleOperation(ACTION_FULL_EXTENT);
        },
        onToggleLayer: () => {
          this.handleOperation(ACTION_LAYER_TOGGLE);
        },
        onLayerUp: () => {
          this.handleOperation(ACTION_LAYER_UP);
        },
        onLayerDown: () => {
          this.handleOperation(ACTION_LAYER_DOWN);
        },
        onLayerDelete: () => {
          this.handleOperation(ACTION_LAYER_DELETE);
        },
        onOpenAttributeTable: () => {
          this.openWorkspaceDialog(2);
        },
        onOpenSymbology: () => {
          this.openWorkspaceDialog(4);
        },
        onOpenVectorEdit: () => {
          this.handleOperation(ACTION_VECTOR_EDIT);
        },
        onOpenAttributeEdit: () => {
          this.handleOperation(ACTION_ATTRIBUTE_EDIT);
        },
        onOpenLabeling: () => {
          this.openWorkspaceDialog(11);
        },
        onOpenRasterDisplay: () => {
          this.openWorkspaceDialog(12);
        },
        onOpenLayout: () => {
          this.openWorkspaceDialog(13);
        },
        onOpenClip: () => {
          this.openWorkspaceDialog(3);
        },
        onOpenBuffer: () => {
          this.openWorkspaceDialog(5);
        },
        onOpenRepair: () => {
          this.openWorkspaceDialog(6);
        },
        onOpenExport: () => {
          this.openWorkspaceDialog(7);
        },
        onOpenDefineProjection: () => {
          this.openWorkspaceDialog(16);
        },
        onOpenProjectLayer: () => {
          this.openWorkspaceDialog(17);
        },
        onOpenSimplify: () => {
          this.simplifyToolTrigger = !this.simplifyToolTrigger;
        },
        onOpenDissolve: () => {
          this.dissolveToolTrigger = !this.dissolveToolTrigger;
        },
        onOpenCentroid: () => {
          this.centroidToolTrigger = !this.centroidToolTrigger;
        },
        onOpenProcessingTool: (toolMode: number) => {
          this.openAdvancedAnalysisTool(toolMode);
        },
        onOpenProcessingBrowser: () => {
          this.handleOperation(ACTION_PROCESSING_BROWSER);
        }
      })
      QgisProcessingBrowserSheet({
        trigger: this.processingBrowserTrigger,
        onOpenProcessingTool: (toolMode: number) => {
          this.openAdvancedAnalysisTool(toolMode);
        },
        onOpenXYTableToPoints: () => {
          this.xyTableToPointTrigger = !this.xyTableToPointTrigger;
        },
        onOpenPortableProject: () => {
          this.portableProjectTrigger = !this.portableProjectTrigger;
        },
        onOpenLayoutAtlas: () => {
          this.layoutAtlasTrigger = !this.layoutAtlasTrigger;
        }
      })
      ExpressionWorkbenchSheet({
        trigger: this.expressionWorkbenchTrigger,
        activeLayerRevision: this.activeLayerRevision,
        onExpressionChanged: () => {
          this.onLayerPresentationChanged('表达式已执行');
        }
      })
      AttributeTableSheet({
        trigger: this.attributeTableTrigger,
        activeLayerRevision: this.activeLayerRevision,
        selectedFeatureIds: this.selectedFeatureIds,
        selectedFeatureLayerIndex: this.selectedFeatureLayerIndex,
        selectionRevision: this.selectedFeatureRevision,
        onToggleFeature: (featureId: string, layerIndex: number) => {
          this.applyFeatureSelection(featureId, layerIndex, FEATURE_SELECTION_TOGGLE);
        },
        onReplaceSelection: (featureIds: string[], layerIndex: number) => {
          this.replaceFeatureSelection(featureIds, layerIndex);
        },
        onLocateFeature: (featureId: string, layerIndex: number) => {
          this.onAttributeFeatureLocated(featureId, layerIndex);
        },
        onBatchAssignSelected: (fieldName: string, value: string): GisOperationResult => {
          return this.batchAssignSelectedFeatureAttribute(fieldName, value);
        }
      })
      XYTableToPointSheet({
        trigger: this.xyTableToPointTrigger,
        onCompleted: (_outputLayerIndex: number, result: GisGeoProcessResult) => {
          this.onAnalysisToolCompleted();
          this.dataLoadStatus = 'XY 表转点完成：' + result.featureCount.toString() + ' 个点';
        }
      })
      TopologyReviewSheet({
        trigger: this.topologyReviewTrigger,
        sourceLayerIndex: this.topologySourceLayerIndex,
        errorLayerIndex: this.topologyErrorLayerIndex,
        requiredFields: this.topologyRequiredFields,
        onLocateIssue: (featureId: string, layerIndex: number) => {
          this.onAttributeFeatureLocated(featureId, layerIndex);
        },
        onRepairAndRecheckCompleted: (repairedLayerIndex: number, errorLayerIndex: number, status: string) => {
          this.topologySourceLayerIndex = repairedLayerIndex;
          this.topologyErrorLayerIndex = errorLayerIndex;
          this.editStatus = status;
          this.onAnalysisToolCompleted();
        }
      })
      PortableProjectSheet({
        trigger: this.portableProjectTrigger,
        projectName: this.projectName,
        projectCrs: this.projectCrs,
        onCompleted: (result: GisGeoProcessResult) => {
          this.dataLoadStatus = '工程包已生成：' + result.featureCount.toString() + ' 个矢量图层';
        }
      })
      AtlasExportSheet({
        trigger: this.layoutAtlasTrigger,
        onGetBasemapMode: (): number => { return this.basemapMode; },
        onGetBasemapLabel: (): string => { return this.basemapLayerName(); },
        onCompleted: (result: GisGeoProcessResult) => {
          this.dataLoadStatus = '地图集已导出：' + result.featureCount.toString() + ' 页';
        }
      })
      SymbologySheet({
        trigger: this.symbologyTrigger,
        onStyleChanged: () => {
          this.onLayerPresentationChanged('样式已应用');
        }
      })
      VectorEditSheet({
        trigger: this.vectorEditTrigger,
        onEditToolSelected: (toolMode: number) => {
          if (this.setMapToolMode(toolMode)) {
            this.editStatus = '编辑工具已启用';
          }
        },
        onEditCommand: (command: number) => {
          this.runVectorEditCommand(command);
        }
      })
      AttributeEditSheet({
        trigger: this.attributeEditTrigger,
        onEnsureEditSession: (): boolean => {
          return this.ensureEditSession(this.selectedOperationalLayerIndex());
        },
        onEditSessionCommand: (command: number) => {
          this.runVectorEditCommand(command);
        },
        onAttributeEdited: () => {
          this.onLayerPresentationChanged('属性已更新');
        }
      })
      LabelingSheet({
        trigger: this.labelingTrigger,
        onLabelingChanged: () => {
          this.onLayerPresentationChanged('标注已应用');
        }
      })
      RasterDisplaySheet({
        trigger: this.rasterDisplayTrigger,
        onRasterDisplayChanged: () => {
          this.onLayerPresentationChanged('栅格显示参数已保存');
        }
      })
      MapLayoutSheet({
        trigger: this.mapLayoutTrigger,
        onGetBasemapMode: (): number => {
          return this.basemapMode;
        },
        onGetBasemapLabel: (): string => {
          return this.basemapLayerName();
        }
      })
      PrintSheet({
        trigger: this.printTrigger,
        onGetBasemapMode: (): number => {
          return this.basemapMode;
        },
        onGetBasemapLabel: (): string => {
          return this.basemapLayerName();
        }
      })
      ToolRunnerSheet({
        trigger: this.clipToolTrigger,
        toolMode: GIS_TOOL_MODE_CLIP,
        onChooseLocalLayer: (fieldIndex: number, onSelected: (layerName: string) => void) => {
          this.chooseLocalLayerForTool(fieldIndex, onSelected);
        },
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.bufferToolTrigger,
        toolMode: GIS_TOOL_MODE_BUFFER,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.repairToolTrigger,
        toolMode: GIS_TOOL_MODE_REPAIR,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.exportToolTrigger,
        toolMode: GIS_TOOL_MODE_EXPORT,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.defineProjectionTrigger,
        toolMode: GIS_TOOL_MODE_DEFINE_PROJECTION,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.projectLayerTrigger,
        toolMode: GIS_TOOL_MODE_PROJECT_LAYER,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.simplifyToolTrigger,
        toolMode: GIS_TOOL_MODE_SIMPLIFY,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.dissolveToolTrigger,
        toolMode: GIS_TOOL_MODE_DISSOLVE,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.centroidToolTrigger,
        toolMode: GIS_TOOL_MODE_CENTROID,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.advancedToolTrigger,
        toolMode: this.advancedToolMode,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        },
        onQualityCheckCompleted: (sourceLayerIndex: number, errorLayerIndex: number, requiredFields: string) => {
          this.topologySourceLayerIndex = sourceLayerIndex;
          this.topologyErrorLayerIndex = errorLayerIndex;
          this.topologyRequiredFields = requiredFields;
          this.topologyReviewTrigger = !this.topologyReviewTrigger;
        }
      })
      AppSettingsSheet({
        trigger: this.appSettingsTrigger
      })
      if (isCollaborationCapable()) {
        CollaborationServiceStateDialog({
          onState: (stateCode: number, bufferType: string, buffer: ArrayBuffer): void => {
            this.handleCollaborationFile(stateCode, bufferType, buffer);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.gn_arc_window'))
    .onAreaChange((_oldVal: Area, newVal: Area) => {
      this.updateCompactLayout(Number(newVal.width), Number(newVal.height));
    })
  }
}
