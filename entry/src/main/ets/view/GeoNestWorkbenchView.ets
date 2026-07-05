import { GisNativeBridgeStatus, queryGisNativeBridgeStatus } from '../gis/GisNativeBridge';
import { getGisService, GisLayerStyle, GisLoadedLayer, qgisCategoryTotal, qgisRampColor } from '../gis/GisService';
import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { promptAction } from '@kit.ArkUI';
import {
  GisMapCanvas,
  MAP_COMMAND_FULL_EXTENT,
  MAP_COMMAND_NONE,
  MAP_COMMAND_ZOOM_SELECTED,
  MAP_TOOL_IDENTIFY,
  MAP_TOOL_MEASURE_ANGLE,
  MAP_TOOL_MEASURE_AREA,
  MAP_TOOL_MEASURE_DISTANCE,
  MAP_TOOL_PICK_COORDINATE,
  MAP_TOOL_EDIT_ADD_POINT,
  MAP_TOOL_EDIT_ADD_LINE,
  MAP_TOOL_EDIT_ADD_POLYGON,
  MAP_TOOL_EDIT_MOVE_NODE,
  MAP_TOOL_EDIT_DELETE_NODE,
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
  BASEMAP_DATUM_GCJ02,
  MapViewport
} from '../component/GisMapCanvas';
import { GisFeatureInfoPanel } from '../component/GisFeatureInfoPanel';
import { AppSettingsSheet } from '../component/AppSettingsSheet';
import { ProjectInfoSheet, NewProjectSheet } from '../component/ProjectSheet';
import { QgisCoreSheet } from '../component/QgisCoreSheet';
import { AttributeTableSheet } from '../component/AttributeTableSheet';
import { SymbologySheet, LabelingSheet } from '../component/SymbologySheet';
import { VectorEditSheet, AttributeEditSheet } from '../component/VectorEditSheet';
import { RasterDisplaySheet } from '../component/RasterDisplaySheet';
import { MapLayoutSheet, PrintSheet } from '../component/MapLayoutSheet';
import { ToolRunnerSheet } from '../component/ToolRunnerSheet';
import {
  VECTOR_EDIT_COMMAND_COPY,
  VECTOR_EDIT_COMMAND_CUT,
  VECTOR_EDIT_COMMAND_DELETE_FEATURE,
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
  RecentProjectRecord
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
import { MaterialStyle } from '../utils/MaterialStyle';
import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { GestureShareModel } from '../gis/GestureShareModel';
import { fileIo } from '@kit.CoreFileKit';
import { fileUri } from '@kit.CoreFileKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';
import hilog from '@ohos.hilog';
import util from '@ohos.util';

const LOG_TAG: number = 0xFF00;
const LOG_DOMAIN: string = 'GeoNest';
const TRANSFERRED_SHANXI_SHP: string = '/data/local/tmp/GeoNestData/shanxi_boundary_140000/140000.shp';
const PROJECT_FILE_MAGIC: string = 'GEONEST_PROJECT_V1';
const PROJECT_FILE_SUFFIX_CHOICE: string = 'GeoNest Project|.gnproj';
const RECENT_PROJECTS_FILE_NAME: string = 'geonest_recent_projects.txt';
const RECENT_PROJECT_LIMIT: number = 8;
const ACTION_NEW_PROJECT: number = 1;
const ACTION_OPEN_PROJECT: number = 2;
const ACTION_SAVE_PROJECT: number = 3;
const ACTION_PROJECT_INFO: number = 4;
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
const ACTION_EXPORT: number = 20;
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
const ACTION_SETTINGS: number = 39;
const ACTION_HELP: number = 40;
const ACTION_ABOUT: number = 41;
const ACTION_SHARE: number = 42;
const BACKSTAGE_INFO: number = 0;
const BACKSTAGE_ABOUT: number = 1;
const BACKSTAGE_HELP: number = 2;
const BACKSTAGE_SETTINGS: number = 3;
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
const RIBBON_HELP: number = 8;
const WORK_AREA_GAP: number = 8;
const COMPACT_LAYOUT_MAX_WIDTH: number = 1000;
const COMPACT_LAYOUT_MAX_HEIGHT: number = 540;
const IMPORT_MAX_SELECT_NUMBER: number = 32;
const IMMERSIVE_WINDOW_STATUS_KEY: string = 'gnImmersiveWindowStatus';
const EXTERNAL_FILE_URI_KEY: string = 'gnExternalFileUri';

class ImportedDataFile {
  uri: string = '';
  fileName: string = '';
  displayName: string = '';
  extension: string = '';
  destinationPath: string = '';
  destinationDir: string = '';
  baseName: string = '';
  displayBaseName: string = '';

  constructor(uri: string, fileName: string, displayName: string, extension: string, destinationPath: string,
    destinationDir: string, baseName: string, displayBaseName: string) {
    this.uri = uri;
    this.fileName = fileName;
    this.displayName = displayName;
    this.extension = extension;
    this.destinationPath = destinationPath;
    this.destinationDir = destinationDir;
    this.baseName = baseName;
    this.displayBaseName = displayBaseName;
  }
}

@Component
export struct GeoNestWorkbenchView {
  @StorageLink(IMMERSIVE_WINDOW_STATUS_KEY) private immersiveWindowStatus: string = '沉浸窗口：等待窗口初始化';
  @StorageLink(EXTERNAL_FILE_URI_KEY) @Watch('onExternalFileUriChanged') private externalFileUri: string = '';
  @State private rightPanelIndex: number = 0;
  @State private projectState: number = 1;
  @State private projectDirty: boolean = false;
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
  @State private basemapDatumMode: number = BASEMAP_DATUM_AUTO;
  @State private layerPanelVisible: boolean = true;
  @State private layerPanelCollapsed: boolean = false;
  @State private rightDockVisible: boolean = true;
  @State private rightDockCollapsed: boolean = false;
  @State private backstageVisible: boolean = false;
  @State private backstageSection: number = BACKSTAGE_INFO;
  @State private catalogSection: number = CATALOG_PROJECT;
  @State private contentsSection: number = CONTENTS_DRAWING_ORDER;
  @State private activeRibbonTab: number = RIBBON_MAP;
  @State private compactLayout: boolean = false;
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

  private gisService = getGisService();
  private gestureShareModel: GestureShareModel | null = null;
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
  @State private qgisCoreTrigger: boolean = false;
  @State private appSettingsTrigger: boolean = false;
  @State private openSourceNoticesExpanded: boolean = false;
  @State private openSourceNotices: string = '';

  aboutToAppear(): void {
    this.layerPanelVisible = this.openSidePanesOnStartup;
    this.rightDockVisible = this.openSidePanesOnStartup;
    this.layerPanelCollapsed = false;
    this.rightDockCollapsed = false;
    this.loadRecentProjects();
    this.refreshNativeBridgeStatus();
    this.loadOpenSourceNotices();
    if (this.consumeExternalFileUri()) {
      return;
    }
    if (!this.loadTransferredLayerIfAvailable()) {
      this.loadBundledShanxiLayer();
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

  private loadOpenSourceNotices(): void {
    try {
      let context = getContext(this);
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
    this.consumeExternalFileUri();
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
    let fileName = this.extractFileName(uri);
    let displayName = this.displayFileName(fileName);
    let ext = this.fileExtension(fileName);
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
      this.projectDirty = true;
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
    if (this.selectedLayerIndex >= this.layerCount) {
      this.selectedLayerIndex = this.layerCount - 1;
    }
  }

  private fileExtension(fileName: string): string {
    let dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex >= fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  private isVectorOrTableFormat(ext: string): boolean {
    return ext === 'shp' || ext === 'geojson' || ext === 'json' || ext === 'gpkg' || ext === 'kml' ||
      ext === 'csv' || ext === 'xlsx' || ext === 'xls';
  }

  private isRasterOrTileFormat(ext: string): boolean {
    return ext === 'tif' || ext === 'tiff' || ext === 'mbtiles';
  }

  // File picker: select one or more GIS files that QGIS OGR/GDAL can open.
  private importShapefile(): void {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      let opts: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = IMPORT_MAX_SELECT_NUMBER;
      documentPicker.select(opts).then((result: Array<string>) => {
        if (result.length > 0) {
          hilog.info(LOG_TAG, LOG_DOMAIN, 'importDataFile: selected %{public}d files', result.length);
          this.openFilesFromUris(result);
        }
      }).catch(() => {
        hilog.warn(LOG_TAG, LOG_DOMAIN, 'importDataFile: picker cancelled');
      });
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'importDataFile: EXCEPTION');
    }
  }

  private fileBaseName(fileName: string): string {
    let dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }

  private hexDigitValue(ch: string): number {
    if (ch >= '0' && ch <= '9') {
      return ch.charCodeAt(0) - '0'.charCodeAt(0);
    }
    if (ch >= 'A' && ch <= 'F') {
      return ch.charCodeAt(0) - 'A'.charCodeAt(0) + 10;
    }
    if (ch >= 'a' && ch <= 'f') {
      return ch.charCodeAt(0) - 'a'.charCodeAt(0) + 10;
    }
    return -1;
  }

  private encodeByteFallback(bytes: number[]): string {
    let result = '';
    for (let i = 0; i < bytes.length; i++) {
      let hex = bytes[i].toString(16).toUpperCase();
      if (hex.length < 2) {
        result += '%0' + hex;
      } else {
        result += '%' + hex;
      }
    }
    return result;
  }

  private decodeUtf8Bytes(bytes: number[]): string {
    if (bytes.length === 0) {
      return '';
    }
    try {
      let data = new Uint8Array(bytes.length);
      for (let i = 0; i < bytes.length; i++) {
        data[i] = bytes[i];
      }
      let decoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(data);
    } catch (e) {
      return this.encodeByteFallback(bytes);
    }
  }

  private decodePercentEncodedText(text: string): string {
    let result = '';
    let bytes: number[] = [];
    let i = 0;
    while (i < text.length) {
      let ch = text.charAt(i);
      if (ch === '%' && i + 2 < text.length) {
        let hi = this.hexDigitValue(text.charAt(i + 1));
        let lo = this.hexDigitValue(text.charAt(i + 2));
        if (hi >= 0 && lo >= 0) {
          bytes.push(hi * 16 + lo);
          i += 3;
          continue;
        }
      }
      if (bytes.length > 0) {
        result += this.decodeUtf8Bytes(bytes);
        bytes = [];
      }
      result += ch;
      i++;
    }
    if (bytes.length > 0) {
      result += this.decodeUtf8Bytes(bytes);
    }
    return result;
  }

  private displayFileName(fileName: string): string {
    let decoded = this.decodePercentEncodedText(fileName);
    if (decoded.length > 0) {
      return decoded;
    }
    return fileName;
  }

  private safeImportPathSegment(text: string): string {
    let result = '';
    for (let i = 0; i < text.length; i++) {
      let ch = text.charAt(i);
      if ((ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
        ch === '-' || ch === '_') {
        result += ch;
      } else {
        result += '_';
      }
    }
    if (result.length === 0) {
      return 'dataset';
    }
    return result;
  }

  private createImportBatchDir(): string {
    let ctx = getContext(this);
    let sandboxDir = ctx.filesDir + '/geonest_data';
    try { fs.mkdirSync(sandboxDir); } catch (e) { /* exists */ }
    let batchDir = sandboxDir + '/import_' + new Date().getTime().toString();
    try { fs.mkdirSync(batchDir); } catch (e) { /* exists */ }
    return batchDir;
  }

  private createShapefileGroupDir(baseName: string): string {
    let ctx = getContext(this);
    let sandboxDir = ctx.filesDir + '/geonest_data';
    try { fs.mkdirSync(sandboxDir); } catch (e) { /* exists */ }
    let groupDir = sandboxDir + '/shapefile_' + this.safeImportPathSegment(baseName);
    try { fs.mkdirSync(groupDir); } catch (e) { /* exists */ }
    return groupDir;
  }

  private copyUriToFile(uri: string, destinationPath: string): boolean {
    try {
      let srcFd = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(srcFd.fd);
      let buf = new ArrayBuffer(stat.size);
      fs.readSync(srcFd.fd, buf);
      fs.closeSync(srcFd);

      let destFd = fs.openSync(destinationPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(destFd.fd, buf);
      fs.closeSync(destFd);
      return true;
    } catch (e) {
      hilog.warn(LOG_TAG, LOG_DOMAIN, 'copyUriToFile: failed for %{public}s', uri);
    }
    return false;
  }

  private copyUriToImportDir(uri: string, importDir: string): ImportedDataFile | undefined {
    let fileName = this.extractFileName(uri);
    let displayName = this.displayFileName(fileName);
    let ext = this.fileExtension(fileName);
    let baseName = this.fileBaseName(fileName);
    let displayBaseName = this.fileBaseName(displayName);
    let targetDir = importDir;
    if (ext === 'shp' || this.isShapefileSidecarExtension(ext)) {
      targetDir = this.createShapefileGroupDir(baseName);
    }
    let destPath = targetDir + '/' + fileName;
    if (this.copyUriToFile(uri, destPath)) {
      hilog.info(LOG_TAG, LOG_DOMAIN, 'copyUriToImportDir: copied %{public}s to %{public}s', fileName, destPath);
      return new ImportedDataFile(uri, fileName, displayName, ext, destPath, targetDir, baseName, displayBaseName);
    }
    return undefined;
  }

  private isShapefileSidecarExtension(ext: string): boolean {
    return ext === 'shx' || ext === 'dbf' || ext === 'prj' || ext === 'cpg' || ext === 'qpj' ||
      ext === 'sbn' || ext === 'sbx';
  }

  private shouldCopySelectedDataFile(ext: string): boolean {
    return ext === 'shp' || this.isShapefileSidecarExtension(ext) || this.isVectorOrTableFormat(ext) ||
      this.isRasterOrTileFormat(ext);
  }

  private fileExists(path: string): boolean {
    try {
      let file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      fs.closeSync(file.fd);
      return true;
    } catch (e) {
      return false;
    }
  }

  private existingShapefileMemberPath(destinationDir: string, baseName: string, ext: string): string {
    let lowerPath = destinationDir + '/' + baseName + '.' + ext;
    if (this.fileExists(lowerPath)) {
      return lowerPath;
    }
    let upperPath = destinationDir + '/' + baseName + '.' + ext.toUpperCase();
    if (this.fileExists(upperPath)) {
      return upperPath;
    }
    return '';
  }

  private hasRequiredShapefileMembers(file: ImportedDataFile): boolean {
    if (file.extension !== 'shp' && !this.isShapefileSidecarExtension(file.extension)) {
      return false;
    }
    let shpPath = this.existingShapefileMemberPath(file.destinationDir, file.baseName, 'shp');
    let shxPath = this.existingShapefileMemberPath(file.destinationDir, file.baseName, 'shx');
    let dbfPath = this.existingShapefileMemberPath(file.destinationDir, file.baseName, 'dbf');
    return shpPath.length > 0 && shxPath.length > 0 && dbfPath.length > 0;
  }

  private canOpenImportedFile(file: ImportedDataFile): boolean {
    if (file.extension === 'shp') {
      return true;
    }
    if (this.isShapefileSidecarExtension(file.extension)) {
      return false;
    }
    return this.isVectorOrTableFormat(file.extension) || this.isRasterOrTileFormat(file.extension);
  }

  private openCopiedDataFile(file: ImportedDataFile): boolean {
    let idx = this.gisService.openLayer(file.destinationPath);
    hilog.info(LOG_TAG, LOG_DOMAIN, 'openCopiedDataFile: %{public}s result=%{public}d', file.displayName, idx);
    if (idx >= 0) {
      let layer = this.gisService.getLayer(idx);
      if (layer !== undefined && file.displayBaseName.length > 0) {
        layer.info.name = file.displayBaseName;
      }
      this.selectedLayerIndex = idx;
      this.gisService.setActiveLayerIndex(idx);
      return true;
    }
    return false;
  }

  private appendOpenCandidate(candidates: ImportedDataFile[], candidate: ImportedDataFile): void {
    for (let i = 0; i < candidates.length; i++) {
      if (candidates[i].destinationPath === candidate.destinationPath) {
        return;
      }
    }
    candidates.push(candidate);
  }

  private appendExistingShapefileCandidate(candidates: ImportedDataFile[], file: ImportedDataFile): void {
    if (file.extension !== 'shp' && !this.isShapefileSidecarExtension(file.extension)) {
      return;
    }
    if (!this.hasRequiredShapefileMembers(file)) {
      return;
    }
    let shpPath = this.existingShapefileMemberPath(file.destinationDir, file.baseName, 'shp');
    if (shpPath.length > 0) {
      this.appendOpenCandidate(candidates, new ImportedDataFile(file.uri, file.baseName + '.shp',
        file.displayBaseName + '.shp', 'shp', shpPath, file.destinationDir, file.baseName, file.displayBaseName));
    }
  }

  private limitedNameList(names: string[], fallback: string): string {
    if (names.length === 0) {
      return fallback;
    }
    let text = '';
    let limit = names.length < 3 ? names.length : 3;
    for (let i = 0; i < limit; i++) {
      if (i > 0) {
        text += '、';
      }
      text += names[i];
    }
    if (names.length > limit) {
      text += ' 等';
    }
    return text;
  }

  private importStatusText(openedCount: number, failedCount: number, unsupportedCount: number,
    sidecarCount: number): string {
    let text = '已加载 ' + openedCount.toString() + ' 个图层';
    if (sidecarCount > 0) {
      text += '，附属文件 ' + sidecarCount.toString() + ' 个';
    }
    if (failedCount > 0) {
      text += '，失败 ' + failedCount.toString() + ' 个';
    }
    if (unsupportedCount > 0) {
      text += '，跳过 ' + unsupportedCount.toString() + ' 个';
    }
    return text;
  }

  private openFilesFromUris(uris: string[]): string {
    try {
      let importDir = this.createImportBatchDir();
      let copiedFiles: ImportedDataFile[] = [];
      let unsupportedCount = 0;
      for (let i = 0; i < uris.length; i++) {
        let fileName = this.extractFileName(uris[i]);
        let ext = this.fileExtension(fileName);
        if (!this.shouldCopySelectedDataFile(ext)) {
          unsupportedCount++;
          hilog.warn(LOG_TAG, LOG_DOMAIN, 'openFilesFromUris: skip unsupported %{public}s',
            this.displayFileName(fileName));
          continue;
        }
        let copied = this.copyUriToImportDir(uris[i], importDir);
        if (copied !== undefined) {
          copiedFiles.push(copied);
        }
      }

      if (copiedFiles.length === 0) {
        if (unsupportedCount > 0) {
          this.dataLoadStatus = '不支持所选文件类型';
        } else {
          this.dataLoadStatus = '数据复制失败';
        }
        return '';
      }

      let openCandidates: ImportedDataFile[] = [];
      for (let i = 0; i < copiedFiles.length; i++) {
        let file = copiedFiles[i];
        if (file.extension === 'shp' || this.isShapefileSidecarExtension(file.extension)) {
          this.appendExistingShapefileCandidate(openCandidates, file);
        } else if (this.canOpenImportedFile(file)) {
          this.appendOpenCandidate(openCandidates, file);
        }
      }

      let openedCount = 0;
      let failedCount = 0;
      let sidecarCount = 0;
      let shapefilePartCount = 0;
      let failedNames: string[] = [];

      for (let i = 0; i < copiedFiles.length; i++) {
        let copiedFile = copiedFiles[i];
        if (copiedFile.extension === 'shp' || this.isShapefileSidecarExtension(copiedFile.extension)) {
          shapefilePartCount++;
        }
        if (this.isShapefileSidecarExtension(copiedFile.extension)) {
          sidecarCount++;
        } else if (copiedFile.extension !== 'shp' && !this.canOpenImportedFile(copiedFile)) {
          unsupportedCount++;
        }
      }

      for (let i = 0; i < openCandidates.length; i++) {
        let file = openCandidates[i];
        if (this.openCopiedDataFile(file)) {
          openedCount++;
        } else {
          failedCount++;
          failedNames.push(file.displayName);
        }
      }

      if (openedCount > 0) {
        this.projectState = 1;
        this.projectDirty = true;
        this.dataLoadStatus = this.importStatusText(openedCount, failedCount, unsupportedCount, sidecarCount);
        this.refreshLayerState();
        let activeLayer = this.gisService.getActiveLayer();
        if (activeLayer !== undefined) {
          return activeLayer.info.name;
        }
      } else if (failedCount > 0) {
        this.dataLoadStatus = 'QGIS 未能打开：' + this.limitedNameList(failedNames, '所选数据') +
          '。Shapefile 请同时选择 .shp/.shx/.dbf/.prj/.cpg';
      } else if (shapefilePartCount > 0) {
        this.dataLoadStatus = '已缓存 Shapefile 文件，请同时选择同名 .shp/.shx/.dbf 后再打开';
      } else {
        this.dataLoadStatus = '不支持所选文件类型';
      }
    } catch (e) {
      this.dataLoadStatus = '数据加载失败';
      hilog.error(LOG_TAG, LOG_DOMAIN, 'openFilesFromUris: EXCEPTION: %{public}s', String(e));
    }
    return '';
  }

  // Copy file from content URI to sandbox, then open with native bridge
  private openFileFromUri(uri: string): void {
    let uris: string[] = [uri];
    this.openFilesFromUris(uris);
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
      this.openWorkspaceDialog(9);
    } else if (actionId === ACTION_ATTRIBUTE_EDIT) {
      this.openWorkspaceDialog(10);
    } else if (actionId === ACTION_LABELING) {
      this.openWorkspaceDialog(11);
    } else if (actionId === ACTION_RASTER_DISPLAY) {
      this.openWorkspaceDialog(12);
    } else if (actionId === ACTION_LAYOUT) {
      this.openWorkspaceDialog(13);
    } else if (actionId === ACTION_PRINT) {
      this.openWorkspaceDialog(15);
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
    this.selectedFeatureId = '';
    this.selectedFeatureAttrs = [];
    this.selectedFeatureLayerName = '';
    this.selectedFeatureLayerIndex = -1;
    this.selectedFeatureGeomType = 0;
    this.showFeaturePanel = false;
    this.selectedFeatureRevision++;
  }

  private async shareActiveLayerFiles(): Promise<void> {
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

  private setMapToolMode(toolMode: number): void {
    this.mapToolMode = toolMode;
    this.measurementStatus = '';
    if (toolMode !== MAP_TOOL_IDENTIFY) {
      this.showFeaturePanel = false;
    }
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
    }
  }

  private onSketchFeatureCreated(geometryType: number, points: GisCoordinate[]): void {
    let layerIndex = this.selectedOperationalLayerIndex();
    let layer = this.gisService.getLayer(layerIndex);
    if (layer === undefined) {
      this.editStatus = '没有可编辑图层';
      return;
    }
    if (layer.info.geometryType !== geometryType) {
      this.editStatus = '当前图层是' + this.geometryName(layer.info.geometryType) + '图层，不能新增' +
        this.geometryName(geometryType) + '要素';
      return;
    }
    this.applyEditResult(this.gisService.addSketchFeature(layerIndex, geometryType, points));
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
    if (command === VECTOR_EDIT_COMMAND_DELETE_FEATURE) {
      this.applyEditResult(this.gisService.deleteFeature(this.selectedOperationalLayerIndex(),
        this.selectedFeatureId));
      this.clearFeatureSelection();
      return;
    }
    if (command === VECTOR_EDIT_COMMAND_COPY) {
      this.applyEditResult(this.gisService.copyFeature(this.selectedOperationalLayerIndex(), this.selectedFeatureId));
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
      this.applyEditResult(this.gisService.snapLayer(this.selectedOperationalLayerIndex(),
        this.selectedOperationalLayerIndex(), 0));
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

  private normalizedProjectText(value: string, fallback: string): string {
    let trimmed = value.trim();
    if (trimmed.length > 0) {
      return trimmed;
    }
    return fallback;
  }

  private applyProjectParameters(params: GeoNestProjectParameters): void {
    this.projectName = this.normalizedProjectText(params.name, '未命名工程');
    this.projectOwner = this.normalizedProjectText(params.owner, '');
    this.projectCrs = this.normalizedProjectText(params.crs, '');
    this.projectMapName = this.normalizedProjectText(params.mapName, '地图');
    this.projectWorkspaceName = this.normalizedProjectText(params.workspaceName, '默认工作空间');
    this.projectDescription = this.normalizedProjectText(params.description, '');
  }

  private isInvalidFileChar(value: string): boolean {
    return value === '/' || value === '\\' || value === ':' || value === '*' || value === '?' ||
      value === '"' || value === '<' || value === '>' || value === '|';
  }

  private safeProjectFileBaseName(source: string): string {
    let result = '';
    for (let i = 0; i < source.length; i++) {
      let ch = source.charAt(i);
      if (this.isInvalidFileChar(ch) || ch === '\r' || ch === '\n' || ch === '\t') {
        result += '_';
      } else {
        result += ch;
      }
    }
    result = result.trim();
    if (result.length === 0) {
      return 'GeoNestProject';
    }
    return result;
  }

  private defaultProjectFileNameFromTitle(title: string): string {
    let baseName = this.safeProjectFileBaseName(title);
    if (baseName.toLowerCase().endsWith('.gnproj')) {
      return baseName;
    }
    return baseName + '.gnproj';
  }

  private defaultProjectFileName(): string {
    return this.defaultProjectFileNameFromTitle(this.projectName);
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
    let fileName = uri;
    let lastSlash = uri.lastIndexOf('/');
    if (lastSlash >= 0 && lastSlash < uri.length - 1) {
      fileName = uri.substring(lastSlash + 1);
    }
    let lastBackSlash = fileName.lastIndexOf('\\');
    if (lastBackSlash >= 0 && lastBackSlash < fileName.length - 1) {
      fileName = fileName.substring(lastBackSlash + 1);
    }
    if (fileName.length === 0) {
      return this.defaultProjectFileName();
    }
    return fileName;
  }

  private buildProjectSaveOptionsWithName(fileName: string): picker.DocumentSaveOptions {
    let opts: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    opts.newFileNames = [fileName];
    opts.fileSuffixChoices = [PROJECT_FILE_SUFFIX_CHOICE];
    return opts;
  }

  private buildProjectSaveOptions(): picker.DocumentSaveOptions {
    return this.buildProjectSaveOptionsWithName(this.defaultProjectFileName());
  }

  private buildProjectSelectOptions(): picker.DocumentSelectOptions {
    let opts: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    opts.maxSelectNumber = 1;
    opts.fileSuffixFilters = [PROJECT_FILE_SUFFIX_CHOICE];
    return opts;
  }

  private cleanProjectLine(value: string): string {
    if (value.endsWith('\r')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  private projectValue(lines: string[], key: string): string {
    let prefix = key + '=';
    for (let i = 0; i < lines.length; i++) {
      let line = this.cleanProjectLine(lines[i]);
      if (line.startsWith(prefix)) {
        return line.substring(prefix.length);
      }
    }
    return '';
  }

  private projectNumberValue(lines: string[], key: string, fallback: number): number {
    let text = this.projectValue(lines, key);
    if (text.length === 0) {
      return fallback;
    }
    let value = Number(text);
    if (value !== value) {
      return fallback;
    }
    return value;
  }

  private projectBooleanValue(lines: string[], key: string, fallback: boolean): boolean {
    let text = this.projectValue(lines, key);
    if (text === 'true') {
      return true;
    }
    if (text === 'false') {
      return false;
    }
    return fallback;
  }

  private sanitizeProjectValue(value: string): string {
    let result = '';
    for (let i = 0; i < value.length; i++) {
      let ch = value.charAt(i);
      if (ch === '\r' || ch === '\n') {
        result += ' ';
      } else {
        result += ch;
      }
    }
    return result;
  }

  private buildProjectText(): string {
    let text = PROJECT_FILE_MAGIC + '\n';
    text += 'projectFormatVersion=2\n';
    text += 'projectName=' + this.sanitizeProjectValue(this.projectName) + '\n';
    text += 'projectOwner=' + this.sanitizeProjectValue(this.projectOwner) + '\n';
    text += 'projectCrs=' + this.sanitizeProjectValue(this.projectCrs) + '\n';
    text += 'projectMapName=' + this.sanitizeProjectValue(this.projectMapName) + '\n';
    text += 'projectWorkspaceName=' + this.sanitizeProjectValue(this.projectWorkspaceName) + '\n';
    text += 'projectDescription=' + this.sanitizeProjectValue(this.projectDescription) + '\n';
    text += 'basemapMode=' + this.basemapMode.toString() + '\n';
    text += 'basemapDatumMode=' + this.basemapDatumMode.toString() + '\n';
    text += 'activeLayerIndex=' + this.gisService.getActiveLayerIndex().toString() + '\n';
    text += 'layerCount=' + this.gisService.getLayerCount().toString() + '\n';
    for (let i = 0; i < this.gisService.getLayerCount(); i++) {
      let layer = this.gisService.getLayer(i);
      if (layer !== undefined) {
        let prefix = 'layer.' + i.toString() + '.';
        let style = layer.style;
        text += prefix + 'path=' + this.sanitizeProjectValue(layer.sourcePath) + '\n';
        text += 'layer.' + i.toString() + '.visible=' + (layer.visible ? 'true' : 'false') + '\n';
        text += prefix + 'styleVersion=1\n';
        text += prefix + 'pointColor=' + this.sanitizeProjectValue(style.pointColor) + '\n';
        text += prefix + 'lineColor=' + this.sanitizeProjectValue(style.lineColor) + '\n';
        text += prefix + 'fillColor=' + this.sanitizeProjectValue(style.fillColor) + '\n';
        text += prefix + 'strokeColor=' + this.sanitizeProjectValue(style.strokeColor) + '\n';
        text += prefix + 'lineWidth=' + style.lineWidth.toString() + '\n';
        text += prefix + 'pointRadius=' + style.pointRadius.toString() + '\n';
        text += prefix + 'rendererMode=' + style.rendererMode.toString() + '\n';
        text += prefix + 'rendererField=' + this.sanitizeProjectValue(style.rendererField) + '\n';
        text += prefix + 'colorRamp=' + style.colorRamp.toString() + '\n';
        text += prefix + 'linePattern=' + style.linePattern.toString() + '\n';
        text += prefix + 'fillPattern=' + style.fillPattern.toString() + '\n';
        text += prefix + 'opacity=' + style.opacity.toString() + '\n';
        text += prefix + 'symbolName=' + this.sanitizeProjectValue(style.symbolName) + '\n';
        text += prefix + 'labelEnabled=' + (style.labelEnabled ? 'true' : 'false') + '\n';
        text += prefix + 'labelField=' + this.sanitizeProjectValue(style.labelField) + '\n';
        text += prefix + 'labelSize=' + style.labelSize.toString() + '\n';
        text += prefix + 'labelColor=' + this.sanitizeProjectValue(style.labelColor) + '\n';
        text += prefix + 'labelHalo=' + (style.labelHalo ? 'true' : 'false') + '\n';
        text += prefix + 'labelAvoidance=' + (style.labelAvoidance ? 'true' : 'false') + '\n';
        text += prefix + 'labelMinScale=' + style.labelMinScale.toString() + '\n';
        text += prefix + 'labelMaxScale=' + style.labelMaxScale.toString() + '\n';
        text += prefix + 'rasterBandMode=' + style.rasterBandMode.toString() + '\n';
        text += prefix + 'rasterStretchMode=' + style.rasterStretchMode.toString() + '\n';
        text += prefix + 'rasterColorRamp=' + style.rasterColorRamp.toString() + '\n';
        text += prefix + 'rasterOpacity=' + style.rasterOpacity.toString() + '\n';
        text += prefix + 'rasterNoData=' + this.sanitizeProjectValue(style.rasterNoData) + '\n';
        text += prefix + 'rasterTransparentColor=' +
          this.sanitizeProjectValue(style.rasterTransparentColor) + '\n';
        text += prefix + 'rasterHillshade=' + (style.rasterHillshade ? 'true' : 'false') + '\n';
      }
    }
    return text;
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
    try {
      let fd = fs.openSync(uri, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(fd.fd, content);
      fs.closeSync(fd);
      return true;
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'writeTextToUri: EXCEPTION: %{public}s', String(e));
    }
    return false;
  }

  private readTextFromUri(uri: string): string {
    try {
      let fd = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(fd.fd);
      let buf = new ArrayBuffer(stat.size);
      fs.readSync(fd.fd, buf);
      fs.closeSync(fd);
      let decoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(new Uint8Array(buf));
    } catch (e) {
      hilog.error(LOG_TAG, LOG_DOMAIN, 'readTextFromUri: EXCEPTION: %{public}s', String(e));
    }
    return '';
  }

  private recentProjectsFilePath(): string {
    let ctx = getContext(this);
    return ctx.filesDir + '/' + RECENT_PROJECTS_FILE_NAME;
  }

  private readTextQuiet(path: string): string {
    try {
      let fd = fs.openSync(path, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(fd.fd);
      let buf = new ArrayBuffer(stat.size);
      fs.readSync(fd.fd, buf);
      fs.closeSync(fd);
      let decoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(new Uint8Array(buf));
    } catch (e) {
      return '';
    }
  }

  private writeTextQuiet(path: string, content: string): boolean {
    try {
      let fd = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(fd.fd, content);
      fs.closeSync(fd);
      return true;
    } catch (e) {
      hilog.warn(LOG_TAG, LOG_DOMAIN, 'writeTextQuiet: failed');
    }
    return false;
  }

  private sanitizeRecentValue(value: string): string {
    let result = '';
    for (let i = 0; i < value.length; i++) {
      let ch = value.charAt(i);
      if (ch === '\r' || ch === '\n' || ch === '\t') {
        result += ' ';
      } else {
        result += ch;
      }
    }
    return result;
  }

  private parseRecentProjectLine(line: string): RecentProjectRecord | undefined {
    let cleanLine = this.cleanProjectLine(line);
    if (cleanLine.length === 0) {
      return undefined;
    }
    let parts = cleanLine.split('\t');
    if (parts.length === 0 || parts[0].length === 0) {
      return undefined;
    }
    let name = '';
    let owner = '';
    let crs = '';
    let workspaceName = '';
    if (parts.length > 1) {
      name = parts[1];
    }
    if (parts.length > 2) {
      owner = parts[2];
    }
    if (parts.length > 3) {
      crs = parts[3];
    }
    if (parts.length > 4) {
      workspaceName = parts[4];
    }
    return new RecentProjectRecord(parts[0], name, owner, crs, workspaceName);
  }

  private loadRecentProjects(): void {
    let content = this.readTextQuiet(this.recentProjectsFilePath());
    let result: RecentProjectRecord[] = [];
    if (content.length > 0) {
      let lines = content.split('\n');
      for (let i = 0; i < lines.length; i++) {
        if (result.length >= RECENT_PROJECT_LIMIT) {
          break;
        }
        let record = this.parseRecentProjectLine(lines[i]);
        if (record !== undefined) {
          result.push(record);
        }
      }
    }
    this.recentProjects = result;
    this.recentProjectRevision++;
  }

  private saveRecentProjects(): void {
    let text = '';
    for (let i = 0; i < this.recentProjects.length && i < RECENT_PROJECT_LIMIT; i++) {
      let record = this.recentProjects[i];
      text += this.sanitizeRecentValue(record.uri) + '\t' + this.sanitizeRecentValue(record.name) + '\t' +
        this.sanitizeRecentValue(record.owner) + '\t' + this.sanitizeRecentValue(record.crs) + '\t' +
        this.sanitizeRecentValue(record.workspaceName) + '\n';
    }
    this.writeTextQuiet(this.recentProjectsFilePath(), text);
  }

  private rememberRecentProject(uri: string): void {
    if (uri.length === 0) {
      return;
    }
    let result: RecentProjectRecord[] = [];
    result.push(new RecentProjectRecord(uri, this.projectName, this.projectOwner, this.projectCrs,
      this.projectWorkspaceName));
    for (let i = 0; i < this.recentProjects.length; i++) {
      if (result.length >= RECENT_PROJECT_LIMIT) {
        break;
      }
      let record = this.recentProjects[i];
      if (record.uri !== uri) {
        result.push(record);
      }
    }
    this.recentProjects = result;
    this.recentProjectRevision++;
    this.saveRecentProjects();
  }

  private saveProjectToUri(uri: string): boolean {
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

  private loadProjectFromText(uri: string, content: string): void {
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
    this.rememberRecentProject(uri);
  }

  private createProject(): void {
    this.openWorkspaceDialog(14);
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
    let content = this.readTextFromUri(uri);
    if (content.length === 0) {
      this.dataLoadStatus = '最近工程无法读取，请使用打开重新选择文件';
      return;
    }
    this.loadProjectFromText(uri, content);
  }

  private openProject(): void {
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      let documentPicker = new picker.DocumentViewPicker(ctx);
      documentPicker.select(this.buildProjectSelectOptions()).then((result: Array<string>) => {
        if (result.length > 0) {
          let uri = result[0];
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
      this.clearFeatureSelection();
    }
    this.activeLayerRevision++;
    this.renderKey++;
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
    }
  }

  private onFeatureSelected(featureId: string, layerIndex: number): void {
    if (layerIndex >= 0 && layerIndex < this.gisService.getLayerCount()) {
      if (this.selectedLayerIndex !== layerIndex || this.gisService.getActiveLayerIndex() !== layerIndex) {
        this.selectedLayerIndex = layerIndex;
        this.gisService.setActiveLayerIndex(layerIndex);
        this.activeLayerRevision++;
      }
    }
    this.selectedFeatureId = featureId;
    this.selectedFeatureAttrs = [];
    this.selectedFeatureLayerName = '';
    this.selectedFeatureLayerIndex = -1;
    this.selectedFeatureGeomType = 0;
    this.selectedFeatureRevision++;
    if (featureId.length > 0 && layerIndex >= 0) {
      let layer = this.gisService.getLayer(layerIndex);
      let foundFeature = false;
      if (layer !== undefined) {
        this.selectedFeatureLayerName = layer.info.name;
        this.selectedFeatureLayerIndex = layerIndex;
        this.selectedFeatureGeomType = layer.info.geometryType;
        for (let i = 0; i < layer.features.length; i++) {
          if (layer.features[i].featureId === featureId) {
            this.selectedFeatureAttrs = layer.features[i].attributesPreview;
            foundFeature = true;
            break;
          }
        }
      }
      this.showFeaturePanel = foundFeature;
      if (this.isCompactLayout() && foundFeature) {
        this.layerPanelCollapsed = true;
      }
      this.projectDirty = true;
      this.renderKey++;
    } else {
      this.selectedFeatureAttrs = [];
      this.selectedFeatureLayerName = '';
      this.selectedFeatureLayerIndex = -1;
      this.selectedFeatureGeomType = 0;
      this.showFeaturePanel = false;
    }
  }

  private onAttributeFeatureLocated(featureId: string, layerIndex: number): void {
    this.setMapToolMode(MAP_TOOL_IDENTIFY);
    this.onFeatureSelected(featureId, layerIndex);
    this.runMapCommand(MAP_COMMAND_ZOOM_SELECTED);
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
  }

  private selectedFeatureStatusText(): string {
    if (this.selectedFeatureId.length > 0) {
      return '已选要素: #' + this.selectedFeatureId;
    }
    return '已选要素: 0';
  }

  private selectedFeatureCountForLayer(layerIndex: number): number {
    if (this.selectedFeatureId.length > 0 && this.selectedFeatureLayerIndex === layerIndex) {
      return 1;
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
    if (layer.style.rendererMode === 1) {
      if (layer.style.rendererField.length > 0) {
        return '唯一值：' + layer.style.rendererField;
      }
      return '唯一值渲染';
    }
    if (layer.style.rendererMode === 2) {
      if (layer.style.rendererField.length > 0) {
        return '分级色带：' + layer.style.rendererField;
      }
      return '分级色带';
    }
    return layer.style.symbolName;
  }

  private layerLabelText(layer: GisLoadedLayer): string {
    if (!layer.style.labelEnabled) {
      return '标注关闭';
    }
    if (layer.style.labelField.length > 0) {
      return '标注字段：' + layer.style.labelField;
    }
    return '标注开启 · 未选择字段';
  }

  private layerSourcePathText(path: string): string {
    if (path.length === 0) {
      return '工程内图层';
    }
    return path;
  }

  private catalogSummaryText(): string {
    return this.layerCount.toString() + ' 个图层 · ' + this.totalFeatures.toString() + ' 个要素';
  }

  private closeFeaturePanel(): void {
    this.showFeaturePanel = false;
    this.selectedFeatureId = '';
    this.selectedFeatureAttrs = [];
    this.selectedFeatureLayerName = '';
    this.selectedFeatureLayerIndex = -1;
    this.selectedFeatureGeomType = 0;
    this.selectedFeatureRevision++;
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
    this.projectDirty = true;
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

  private showStatusCommand(status: string): void {
    this.editStatus = status;
  }

  private runBackstageAction(actionId: number): void {
    this.closeBackstage();
    this.handleOperation(actionId);
  }

  private runBackstageStatus(status: string): void {
    this.closeBackstage();
    this.showStatusCommand(status);
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
  backstageMenuCommand(label: ResourceStr, icon: Resource, actionId: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 10 }) {
        this.symbol(icon, $r('sys.color.icon_secondary'), 18)
        Text(label)
          .fontSize(14)
          .fontColor($r('app.color.gn_text_primary'))
          .layoutWeight(1)
      }
      .padding({ left: 18, right: 14 })
      .width('100%')
      .height(48)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(48)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .borderRadius(0)
    .onClick(() => {
      this.runBackstageAction(actionId);
    })
  }

  @Builder
  backstageMenuStatus(label: ResourceStr, icon: Resource, status: string) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 10 }) {
        this.symbol(icon, $r('sys.color.icon_secondary'), 18)
        Text(label)
          .fontSize(14)
          .fontColor($r('app.color.gn_text_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 18, right: 14 })
      .width('100%')
      .height(48)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(48)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .borderRadius(0)
    .onClick(() => {
      this.runBackstageStatus(status);
    })
  }

  @Builder
  backstageInfoRow(label: ResourceStr, value: ResourceStr) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.gn_text_muted'))
        .width(116)
      Text(value)
        .fontSize(13)
        .fontColor($r('app.color.gn_text_primary'))
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  backstageActionButton(label: ResourceStr, icon: Resource, actionId: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 8 }) {
        this.symbol(icon, $r('app.color.gn_blue_800'), 17)
        Text(label)
          .fontSize(13)
          .fontColor($r('app.color.gn_blue_800'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
    }
    .height(36)
    .padding({ left: 12, right: 12 })
    .borderRadius(this.itemRadiusValue())
    .backgroundColor($r('app.color.gn_blue_100'))
    .onClick(() => {
      this.runBackstageAction(actionId);
    })
  }

  @Builder
  backstageInfoPanel() {
    Column({ space: 16 }) {
      Text($r('app.string.gn_backstage_project_summary'))
        .fontSize(28)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_blue_800'))
        .width('100%')
      Column({ space: 8 }) {
        this.backstageInfoRow($r('app.string.gn_project_name_label'), this.projectDisplayName())
        this.backstageInfoRow($r('app.string.gn_project_file_label'), this.backstageProjectFileText())
        this.backstageInfoRow($r('app.string.gn_project_owner_label'), this.projectOwner.length > 0 ?
          this.projectOwner : '未设置')
        this.backstageInfoRow($r('app.string.gn_project_map_name_label'), this.projectMapName)
        this.backstageInfoRow($r('app.string.gn_project_workspace_label'), this.projectWorkspaceName)
        this.backstageInfoRow($r('app.string.gn_project_layer_count_label'), this.backstageLayerStatsText())
        this.backstageInfoRow($r('app.string.gn_backstage_reference_status'), this.mapReferenceStatus)
        this.backstageInfoRow($r('app.string.gn_backstage_map_status'), this.backstageMapStatusText())
      }
      .padding(18)
      .borderRadius(this.paneRadiusValue())
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })

      Row({ space: 10 }) {
        this.backstageActionButton($r('app.string.gn_project_info'), $r('sys.symbol.info_circle'), ACTION_PROJECT_INFO)
        this.backstageActionButton($r('app.string.gn_workbench_save'), $r('sys.symbol.archivebox_fill'),
          ACTION_SAVE_PROJECT)
        this.backstageActionButton($r('app.string.gn_cmd_export'), $r('sys.symbol.download'), ACTION_EXPORT)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  backstageAboutPanel() {
    Column({ space: 16 }) {
      Text($r('app.string.gn_backstage_product_title'))
        .fontSize(30)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_blue_800'))
        .width('100%')
      Text($r('app.string.gn_backstage_product_desc'))
        .fontSize(14)
        .fontColor($r('app.color.gn_text_primary'))
        .width('100%')

      Column({ space: 8 }) {
        Text($r('app.string.gn_open_source_license_title'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        Text($r('app.string.gn_open_source_copyright'))
          .fontSize(13)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        Text($r('app.string.gn_open_source_rights'))
          .fontSize(13)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
        Text($r('app.string.gn_open_source_no_warranty'))
          .fontSize(13)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
        Text($r('app.string.gn_open_source_source_entry'))
          .fontSize(13)
          .fontColor($r('app.color.gn_blue_800'))
          .width('100%')
        this.backstageInfoRow('GeoNest', 'GPL-2.0-or-later')
        this.backstageInfoRow('QGIS Core', 'GPL-2.0-or-later')
        this.backstageInfoRow('Qt', 'LGPL-3.0-only / GPL')
        this.backstageInfoRow('GDAL/OGR', 'MIT License')
        this.backstageInfoRow('GEOS', 'LGPL-2.1-or-later')
        this.backstageInfoRow('PROJ', 'MIT License')
        this.backstageInfoRow('SQLite', 'Public Domain')
        this.backstageInfoRow('Expat', 'MIT License')
        this.backstageInfoRow('Protobuf', 'BSD-3-Clause')
        this.backstageInfoRow('Zstd', 'BSD-3-Clause')
        this.backstageInfoRow('Libzip', 'BSD-3-Clause')
        this.backstageInfoRow('QtKeychain', 'BSD-3-Clause')
        Button(this.openSourceNoticesExpanded ? $r('app.string.gn_open_source_hide_licenses') :
          $r('app.string.gn_open_source_show_licenses'), { type: ButtonType.Normal, stateEffect: true })
          .height(36)
          .fontSize(13)
          .fontColor($r('app.color.gn_blue_800'))
          .backgroundColor($r('app.color.gn_blue_100'))
          .borderRadius(this.itemRadiusValue())
          .onClick(() => {
            this.openSourceNoticesExpanded = !this.openSourceNoticesExpanded;
          })
        if (this.openSourceNoticesExpanded) {
          Text(this.openSourceNotices)
            .fontSize(11)
            .fontColor($r('app.color.gn_text_primary'))
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.gn_pane'))
            .borderRadius(this.itemRadiusValue())
            .border({ width: 1, color: $r('app.color.gn_line') })
        }
      }
      .padding(18)
      .borderRadius(this.paneRadiusValue())
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })

      Column({ space: 8 }) {
        Text($r('app.string.gn_open_source_qgis_title'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        Text($r('app.string.gn_open_source_qgis_desc'))
          .fontSize(13)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
      }
      .padding(18)
      .borderRadius(this.paneRadiusValue())
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })

      Text('GeoNest 版本 ' + this.nativeBridgeVersion)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  backstageHelpPanel() {
    Column({ space: 14 }) {
      Text($r('app.string.gn_backstage_help'))
        .fontSize(28)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_blue_800'))
        .width('100%')

      Column({ space: 8 }) {
        Text('快速入门')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        this.backstageInfoRow('添加数据', '点击"添加数据"按钮，选择 Shapefile、GeoJSON、GeoPackage 或栅格文件')
        this.backstageInfoRow('切换底图', '在状态栏点击底图名称，可切换在线地图或本地矢量底图')
        this.backstageInfoRow('图层管理', '在左侧图层面板控制图层显示、顺序和样式')
        this.backstageInfoRow('地图浏览', '拖拽平移，双指缩放，点击要素查看属性')
      }
      .padding(18)
      .borderRadius(this.paneRadiusValue())
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })

      Column({ space: 8 }) {
        Text('常用工具')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        this.backstageInfoRow('矢量编辑', '新增点/线/面、移动节点、删除节点、切割、合并')
        this.backstageInfoRow('属性编辑', '查看和编辑要素属性表，支持字段计算')
        this.backstageInfoRow('空间分析', '裁剪、缓冲区、修复几何、投影转换')
        this.backstageInfoRow('地图出图', '设置布局、比例尺、图例，导出为图片或打印')
      }
      .padding(18)
      .borderRadius(this.paneRadiusValue())
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })

      Column({ space: 8 }) {
        Text('键盘快捷键')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        this.backstageInfoRow('Ctrl+N', '新建工程')
        this.backstageInfoRow('Ctrl+O', '打开工程')
        this.backstageInfoRow('Ctrl+S', '保存工程')
        this.backstageInfoRow('Ctrl+Z', '撤销编辑')
        this.backstageInfoRow('Ctrl+Y', '重做编辑')
        this.backstageInfoRow('Delete', '删除选中要素')
        this.backstageInfoRow('Esc', '取消当前操作')
      }
      .padding(18)
      .borderRadius(this.paneRadiusValue())
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  backstageSettingsPanel() {
    Column({ space: 16 }) {
      Text($r('app.string.gn_settings_title'))
        .fontSize(28)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_blue_800'))
        .width('100%')
      Column({ space: 8 }) {
        this.backstageInfoRow($r('app.string.gn_settings_appearance'), '外观主题、材质效果')
        this.backstageInfoRow($r('app.string.gn_settings_workspace'), '启动面板、自动保存')
        this.backstageInfoRow($r('app.string.gn_settings_map_performance'), '底图、渲染质量')
        this.backstageInfoRow($r('app.string.gn_settings_input'), '手势与交互')
        this.backstageInfoRow($r('app.string.gn_settings_accessibility'), '字体大小、对比度')
      }
      .padding(18)
      .borderRadius(this.paneRadiusValue())
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  backstageContent() {
    if (this.backstageSection === BACKSTAGE_ABOUT) {
      this.backstageAboutPanel()
    } else if (this.backstageSection === BACKSTAGE_HELP) {
      this.backstageHelpPanel()
    } else if (this.backstageSection === BACKSTAGE_SETTINGS) {
      this.backstageSettingsPanel()
    } else {
      this.backstageInfoPanel()
    }
  }

  @Builder
  backstageDialogHeader() {
    Row({ space: 10 }) {
      if (this.backstageSection === BACKSTAGE_ABOUT) {
        this.symbol($r('sys.symbol.info_shield'), $r('app.color.gn_blue_800'), 20)
        Text($r('app.string.gn_backstage_about'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
      } else if (this.backstageSection === BACKSTAGE_HELP) {
        this.symbol($r('sys.symbol.questionmark_circle'), $r('app.color.gn_blue_800'), 20)
        Text($r('app.string.gn_backstage_help'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
      } else {
        this.symbol($r('sys.symbol.folder'), $r('app.color.gn_blue_800'), 20)
        Text($r('app.string.gn_backstage_file'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
      }
      Blank()
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(13)
            .fontColor([$r('app.color.gn_text_primary')])
          Text($r('app.string.gn_dialog_close'))
            .fontSize(12)
            .fontColor($r('app.color.gn_text_primary'))
        }
      }
      .height(28)
      .padding({ left: 8, right: 8 })
      .backgroundColor($r('app.color.gn_pane'))
      .borderRadius(this.itemRadiusValue())
      .border({ width: 1, color: $r('app.color.gn_line') })
      .onClick(() => {
        this.closeBackstage();
      })
    }
    .width('100%')
    .height(52)
    .padding({ left: 18, right: 12 })
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  backstageFileActions() {
    Scroll() {
      Column() {
        Blank().height(80).width('100%')
        this.backstageMenuCommand($r('app.string.gn_workbench_new'), $r('sys.symbol.doc_text'), ACTION_NEW_PROJECT)
        this.backstageMenuCommand($r('app.string.gn_workbench_open'), $r('sys.symbol.folder'), ACTION_OPEN_PROJECT)
        this.backstageMenuCommand($r('app.string.gn_workbench_save'), $r('sys.symbol.archivebox_fill'),
          ACTION_SAVE_PROJECT)
        this.backstageMenuCommand('另存工程', $r('sys.symbol.archivebox_fill'), ACTION_SAVE_PROJECT)
        Column()
          .width('82%')
          .height(1)
          .backgroundColor($r('app.color.gn_line_strong'))
          .margin({ top: 12, bottom: 12 })
        this.backstageMenuCommand($r('app.string.gn_settings_title'), $r('sys.symbol.gearshape'),
          ACTION_SETTINGS)
        this.backstageMenuStatus('授权', $r('sys.symbol.info_shield'),
          '授权信息：当前使用本地 GIS 能力和设备签名配置')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width(210)
    .height('100%')
    .scrollBar(BarState.Auto)
    .backgroundColor($r('app.color.gn_pane_alt'))
    .border({ width: { right: 1 }, color: $r('app.color.gn_line_strong') })
  }

  @Builder
  backstageDialogBody() {
    if (this.backstageSection === BACKSTAGE_INFO) {
      Row() {
        this.backstageFileActions()
        Scroll() {
          Column() {
            this.backstageInfoPanel()
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 22, bottom: 22 })
        }
        .layoutWeight(1)
        .height('100%')
        .scrollBar(BarState.Auto)
        .backgroundColor($r('app.color.gn_arc_window'))
      }
      .layoutWeight(1)
      .width('100%')
    } else {
      Scroll() {
        Column() {
          this.backstageContent()
        }
        .width('100%')
        .padding({ left: 28, right: 28, top: 24, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)
      .backgroundColor($r('app.color.gn_arc_window'))
    }
  }

  @Builder
  backstageDialogContent() {
    Column() {
      HdsNavigation() {
        if (this.backstageSection === BACKSTAGE_INFO) {
          Row() {
            this.backstageFileActions()
            Scroll() {
              Column() {
                Blank().height(80).width('100%')
                this.backstageInfoPanel()
              }
              .width('100%')
              .padding({ left: 24, right: 24, top: 14, bottom: 22 })
            }
            .layoutWeight(1)
            .height('100%')
            .scrollBar(BarState.Auto)
          }
          .layoutWeight(1)
          .width('100%')
        } else {
          Scroll() {
            Column() {
              Blank().height(80).width('100%')
              this.backstageContent()
            }
            .width('100%')
            .padding({ left: 28, right: 28, top: 14, bottom: 24 })
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Auto)
        }
      }
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MODAL)
      .titleBar({
        style: MaterialStyle.isHigh() ? {
          scrollEffectOpts: { scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
          }
        } : undefined,
        content: {
          title: { mainTitle: this.backstageDialogTitle() },
          menu: {
            value: [{
              content: {
                label: 'modal_cancel', isEnabled: true,
                type: IconStyleMode.SMALL,
                action: () => { this.backstageVisible = false; }
              }
            }]
          }
        }
      })
    }
    .width('100%').height('100%')
  }

  @Builder
  titleArea() {
    Row({ space: 10 }) {
      Button($r('app.string.gn_backstage_file'), { type: ButtonType.Capsule, stateEffect: true })
        .height(32)
        .fontSize(13)
        .fontColor($r('app.color.gn_text_primary'))
        .backgroundColor($r('app.color.gn_pane_alt'))
        .onClick(() => {
          this.openBackstage(BACKSTAGE_INFO);
        })
      this.symbol($r('sys.symbol.map'), $r('app.color.gn_green_700'), 22)
      Column() {
        Text($r('app.string.gn_workbench_title'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
        Text(this.projectStateLabel())
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .width(250)

      Search({ placeholder: $r('app.string.gn_workbench_command_search') })
        .height(34)
        .width(420)
        .backgroundColor($r('app.color.gn_paper'))
        .borderRadius(this.itemRadiusValue())

      Blank()
      Button($r('app.string.gn_project_info'), { type: ButtonType.Capsule, stateEffect: true })
        .height(32)
        .fontSize(13)
        .fontColor($r('app.color.gn_blue_800'))
        .backgroundColor($r('app.color.gn_blue_100'))
        .onClick(() => {
          this.openWorkspaceDialog(1);
        })
      Button($r('app.string.gn_qgis_core_title'), { type: ButtonType.Capsule, stateEffect: true })
        .height(32)
        .fontSize(13)
        .fontColor($r('app.color.gn_green_700'))
        .backgroundColor($r('app.color.gn_pane_alt'))
        .onClick(() => {
          this.openWorkspaceDialog(8);
        })
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        this.symbol($r('sys.symbol.gearshape'), $r('sys.color.icon_secondary'), 18)
      }
      .width(34)
      .height(34)
      .padding(0)
      .backgroundColor($r('app.color.gn_pane_alt'))
      .borderRadius(this.itemRadiusValue())
      .onClick(() => {
        this.appSettingsTrigger = !this.appSettingsTrigger;
      })
    }
    .width('100%')
    .height(54)
    .padding({ left: 14, right: 14 })
    .justifyContent(FlexAlign.Start)
    .backgroundBlurStyle(MaterialStyle.toolbarBlurStyle())
    .backgroundColor(this.materialSurfaceColor($r('app.color.gn_paper')))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  ribbonTab(label: ResourceStr, tabIndex: number) {
    Text(label)
      .height(30)
      .padding({ left: 12, right: 12 })
      .fontSize(14)
      .fontWeight(this.activeRibbonTab === tabIndex ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.activeRibbonTab === tabIndex ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_primary'))
      .border({
        width: { bottom: this.activeRibbonTab === tabIndex ? 3 : 0 },
        color: $r('app.color.gn_arc_focus')
      })
      .onClick(() => {
        this.activeRibbonTab = tabIndex;
      })
  }

  @Builder
  ribbonTabBar() {
    Scroll() {
      Row() {
        if (this.isCompactLayout()) {
          Button($r('app.string.gn_backstage_file'), { type: ButtonType.Capsule, stateEffect: true })
            .height(28)
            .fontSize(13)
            .fontColor($r('app.color.gn_text_primary'))
            .backgroundColor($r('app.color.gn_pane_alt'))
            .margin({ right: 4 })
            .onClick(() => {
              this.openBackstage(BACKSTAGE_INFO);
            })
        }
        this.ribbonTab($r('app.string.gn_ribbon_tab_project'), RIBBON_PROJECT)
        this.ribbonTab($r('app.string.gn_ribbon_tab_map'), RIBBON_MAP)
        this.ribbonTab($r('app.string.gn_ribbon_tab_insert'), RIBBON_INSERT)
        this.ribbonTab($r('app.string.gn_ribbon_tab_analysis'), RIBBON_ANALYSIS)
        this.ribbonTab($r('app.string.gn_ribbon_tab_view'), RIBBON_VIEW)
        this.ribbonTab($r('app.string.gn_ribbon_tab_edit'), RIBBON_EDIT)
        this.ribbonTab($r('app.string.gn_ribbon_tab_imagery'), RIBBON_IMAGERY)
        this.ribbonTab($r('app.string.gn_ribbon_tab_share'), RIBBON_SHARE)
        this.ribbonTab($r('app.string.gn_ribbon_tab_help'), RIBBON_HELP)
        Blank()
      }
      .width('100%')
      .height(32)
      .padding({ left: 12, right: 12 })
    }
    .width('100%')
    .height(38)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .backgroundBlurStyle(MaterialStyle.toolbarBlurStyle())
    .backgroundColor(this.materialSurfaceColor($r('app.color.gn_pane')))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
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
    .borderRadius(this.itemRadiusValue())
    .backgroundBlurStyle(MaterialStyle.componentBlurStyle())
    .backgroundColor(active ? $r('app.color.gn_arc_active') : Color.Transparent)
    .onClick(() => {
      this.handleOperation(actionId);
    })
  }

  @Builder
  operationStatusButton(label: ResourceStr, icon: Resource, status: string) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 4 }) {
        this.symbol(icon, $r('sys.color.icon_secondary'), 21)
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
    .borderRadius(this.itemRadiusValue())
    .backgroundBlurStyle(MaterialStyle.componentBlurStyle())
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.showStatusCommand(status);
    })
  }

  @Builder
  basemapMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.gn_workbench_basemap_osm') })
        .onClick(() => {
          this.setBasemapMode(BASEMAP_ONLINE_STANDARD);
        })
      MenuItem({ content: $r('app.string.gn_workbench_basemap_topo') })
        .onClick(() => {
          this.setBasemapMode(BASEMAP_TERRAIN);
        })
      MenuItem({ content: $r('app.string.gn_workbench_basemap_voyager') })
        .onClick(() => {
          this.setBasemapMode(BASEMAP_IMAGERY);
        })
      MenuItem({ content: $r('app.string.gn_workbench_basemap_harmony_standard') })
        .onClick(() => {
          this.setBasemapMode(BASEMAP_HARMONY_STANDARD);
        })
      MenuItem({ content: $r('app.string.gn_workbench_basemap_harmony_terrain') })
        .onClick(() => {
          this.setBasemapMode(BASEMAP_HARMONY_TERRAIN);
        })
      MenuItem({ content: $r('app.string.gn_workbench_basemap_harmony_imagery') })
        .onClick(() => {
          this.setBasemapMode(BASEMAP_HARMONY_IMAGERY);
        })
      MenuItem({ content: $r('app.string.gn_workbench_basemap_vector') })
        .onClick(() => {
          this.setBasemapMode(BASEMAP_VECTOR);
        })
      MenuItem({ content: '坐标模式：自动' })
        .onClick(() => {
          this.setBasemapDatumMode(BASEMAP_DATUM_AUTO);
        })
      MenuItem({ content: '坐标模式：原始/WGS84' })
        .onClick(() => {
          this.setBasemapDatumMode(BASEMAP_DATUM_WGS84);
        })
      MenuItem({ content: '坐标模式：转 GCJ-02' })
        .onClick(() => {
          this.setBasemapDatumMode(BASEMAP_DATUM_GCJ02);
        })
    }
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
        Text(this.basemapName())
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
        this.handleOperation(actionId);
      }
    })
  }

  @Builder
  compactStatusButton(label: ResourceStr, icon: Resource, status: string) {
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
      this.showStatusCommand(status);
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
    .borderRadius(this.itemRadiusValue())
    .backgroundColor(this.mapToolMode === toolMode ? $r('app.color.gn_arc_active') : Color.Transparent)
    .onClick(() => {
      this.setMapToolMode(toolMode);
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
    .borderRadius(this.itemRadiusValue())
    .backgroundBlurStyle(MaterialStyle.componentBlurStyle())
    .backgroundColor(this.mapToolMode === toolMode ? $r('app.color.gn_arc_active') : Color.Transparent)
    .onClick(() => {
      this.setMapToolMode(toolMode);
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
      this.restoreSidePanel(side);
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
      this.openBackstage(section);
    })
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
          this.operationButton($r('app.string.gn_cmd_add_data'), $r('sys.symbol.plus_layer'), ACTION_ADD_DATA, false)
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
          this.operationButton('新建地图', $r('sys.symbol.map'), ACTION_NEW_PROJECT, false)
          this.operationButton('新建布局', $r('sys.symbol.doc_text'), ACTION_LAYOUT, false)
          this.operationButton('新建报表', $r('sys.symbol.doc_text'), ACTION_LAYOUT, false)
          Column() {
            this.compactButton('地图模板', $r('sys.symbol.doc_text'), ACTION_NEW_PROJECT)
            this.compactButton($r('app.string.gn_project_info'), $r('sys.symbol.info_circle'), ACTION_PROJECT_INFO)
          }
        } else if (groupIndex === 12) {
          this.operationButton($r('app.string.gn_cmd_add_data'), $r('sys.symbol.plus_layer'), ACTION_ADD_DATA, false)
          this.operationButton($r('app.string.gn_arc_xy_table'), $r('sys.symbol.location_up'), ACTION_ADD_DATA, false)
          Column() {
            this.compactButton($r('app.string.gn_arc_add_data_from_path'), $r('sys.symbol.folder'), ACTION_ADD_DATA)
            this.compactButton($r('app.string.gn_arc_folders'), $r('sys.symbol.folder_fill'), ACTION_OPEN_PROJECT)
          }
          Column() {
            this.compactButton('连接', $r('sys.symbol.folder'), ACTION_SHOW_CATALOG)
            this.compactButton($r('app.string.gn_arc_favorites'), $r('sys.symbol.star_folder_fill'),
              ACTION_SHOW_CATALOG)
          }
        } else if (groupIndex === 13) {
          this.ribbonToolModeButton('点笔记', $r('sys.symbol.location_up'), MAP_TOOL_EDIT_ADD_POINT)
          this.ribbonToolModeButton('线笔记', $r('sys.symbol.road_lanes_badge_minus'), MAP_TOOL_EDIT_ADD_LINE)
          this.ribbonToolModeButton('面笔记', $r('sys.symbol.layer'), MAP_TOOL_EDIT_ADD_POLYGON)
          this.operationButton('文字标注', $r('sys.symbol.doc_text'), ACTION_LABELING, false)
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
          this.operationButton('空间连接', $r('sys.symbol.plus_square_on_square'), ACTION_CLIP, false)
          Column() {
            this.compactButton($r('app.string.gn_cmd_repair'), $r('sys.symbol.wrench_arrow_counterclockwise'),
              ACTION_REPAIR)
            this.compactButton('字段计算器', $r('sys.symbol.doc_text'), ACTION_ATTRIBUTE_EDIT)
          }
        } else if (groupIndex === 16) {
          Column() {
            this.ribbonPanelButton($r('app.string.gn_ribbon_contents_pane'), $r('sys.symbol.layer'), 0)
            this.ribbonPanelButton($r('app.string.gn_ribbon_catalog_pane'), $r('sys.symbol.folder_fill'), 1)
          }
          Column() {
            this.compactButton('工具箱', $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_SHOW_TOOLBOX)
          }
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
          this.operationButton($r('app.string.gn_data_reviewer'), $r('sys.symbol.list_checkmark'), ACTION_REPAIR,
            false)
          Column() {
            this.compactButton('色带', $r('sys.symbol.paintpalette'), ACTION_RASTER_DISPLAY)
            this.compactButton('阴影地形', $r('sys.symbol.map'), ACTION_RASTER_DISPLAY)
          }
        } else if (groupIndex === 19) {
          this.operationButton($r('app.string.gn_workbench_print'), $r('sys.symbol.printer'), ACTION_PRINT, false)
          this.operationButton($r('app.string.gn_cmd_export'), $r('sys.symbol.download'), ACTION_EXPORT, false)
          this.operationButton($r('app.string.gn_cmd_share'), $r('sys.symbol.share'), ACTION_SHARE, false)
        } else if (groupIndex === 20) {
          this.ribbonToolModeButton($r('app.string.gn_tool_identify'), $r('sys.symbol.hand_tap'), MAP_TOOL_IDENTIFY)
          this.operationButton('缩放至选中', $r('sys.symbol.plus_magnifyingglass'), ACTION_ZOOM_SELECTED, false)
          Column() {
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
        } else if (groupIndex === 24) {
          this.operationButton($r('app.string.gn_ribbon_vector_edit'), $r('sys.symbol.wrench_arrow_counterclockwise'),
            ACTION_VECTOR_EDIT, false)
          this.operationButton($r('app.string.gn_ribbon_attribute_edit'), $r('sys.symbol.doc_text'),
            ACTION_ATTRIBUTE_EDIT, false)
          this.operationButton('字段计算器', $r('sys.symbol.doc_text'), ACTION_ATTRIBUTE_EDIT, false)
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
          this.operationStatusButton('路径加数据', $r('sys.symbol.folder'), '路径加数据入口已预留：当前请使用添加数据选择本地文件')
          Column() {
            this.compactStatusButton($r('app.string.gn_arc_xy_table'), $r('sys.symbol.location_up'),
              'XY 表转点入口已预留：后续识别经纬度字段生成点图层')
            this.compactStatusButton('图形图层', $r('sys.symbol.layer'), '图形图层入口已预留：后续支持临时标绘和注记')
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
            this.compactStatusButton('信息图表', $r('sys.symbol.doc_text'), '信息图表入口已预留：后续展示人口、用地和统计卡片')
          }
        } else if (groupIndex === 28) {
          this.operationButton('标注设置', $r('sys.symbol.doc_text'), ACTION_LABELING, false)
          this.operationStatusButton('暂停标注', $r('sys.symbol.xmark'), '标注暂停入口已预留：当前可在标注系统中关闭标注')
          this.operationStatusButton('锁定标注', $r('sys.symbol.info_shield'), '标注锁定入口已预留：后续固定标注位置和避让结果')
          Column() {
            this.compactStatusButton('未放置标注', $r('sys.symbol.doc_text'), '未放置标注检查入口已预留')
            this.compactStatusButton('转换标注', $r('sys.symbol.arrow_right_and_square'), '标注转注记入口已预留')
          }
        } else if (groupIndex === 29) {
          this.operationStatusButton('下载地图', $r('sys.symbol.download'), '离线下载入口暂不接入花瓣：当前保留本地矢量底图')
          this.operationButton($r('app.string.gn_workbench_save'), $r('sys.symbol.archivebox_fill'), ACTION_SAVE_PROJECT,
            false)
          this.operationStatusButton('离线区域', $r('sys.symbol.map'), '离线区域管理入口已预留：后续打包本地瓦片和业务图层')
          Column() {
            this.compactStatusButton('同步离线', $r('sys.symbol.arrow_clockwise'), '离线同步入口已预留')
            this.compactStatusButton('清理缓存', $r('sys.symbol.trash'), '底图缓存清理入口已预留')
          }
        } else if (groupIndex === 30) {
          this.operationButton('新建地图', $r('sys.symbol.map'), ACTION_NEW_PROJECT, false)
          this.operationButton('新建布局', $r('sys.symbol.doc_text'), ACTION_LAYOUT, false)
          this.operationStatusButton('新建报表', $r('sys.symbol.doc_text'), '报表入口已预留：当前使用地图出图和打印导出')
          Column() {
            this.compactStatusButton('新建演示文稿', $r('sys.symbol.doc_text'), '演示文稿入口已预留')
            this.compactStatusButton('新建 Notebook', $r('sys.symbol.doc_text'), 'Notebook 入口已预留：后续接入脚本环境')
          }
          Column() {
            this.compactButton('工具箱', $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_SHOW_TOOLBOX)
            this.compactStatusButton('任务', $r('sys.symbol.list_checkmark'), '任务入口已预留：后续串联流程步骤')
          }
        } else if (groupIndex === 31) {
          this.operationStatusButton('导入地图', $r('sys.symbol.map'), '导入地图入口已预留：当前可打开 .gnproj 工程')
          this.operationStatusButton('导入布局', $r('sys.symbol.doc_text'), '导入布局入口已预留')
          this.operationStatusButton('连接', $r('sys.symbol.folder'), '连接入口已预留：后续管理数据库、服务和文件夹')
          Column() {
            this.compactStatusButton('添加文件夹', $r('sys.symbol.folder_fill'), '添加文件夹入口已预留')
            this.compactStatusButton('收藏夹', $r('sys.symbol.star_folder_fill'), '收藏夹入口已预留')
          }
        } else if (groupIndex === 32) {
          this.ribbonToolModeButton('点笔记', $r('sys.symbol.location_up'), MAP_TOOL_EDIT_ADD_POINT)
          this.ribbonToolModeButton('线笔记', $r('sys.symbol.road_lanes_badge_minus'), MAP_TOOL_EDIT_ADD_LINE)
          this.ribbonToolModeButton('面笔记', $r('sys.symbol.layer'), MAP_TOOL_EDIT_ADD_POLYGON)
          this.operationButton('文本笔记', $r('sys.symbol.doc_text'), ACTION_LABELING, false)
          Column() {
            this.compactStatusButton('链接图表', $r('sys.symbol.plus_square_on_square'), '链接图表入口已预留')
            this.compactToolButton('距离方向', $r('sys.symbol.plus_magnifyingglass'), MAP_TOOL_MEASURE_DISTANCE)
          }
        } else if (groupIndex === 33) {
          this.operationButton('模型构建器', $r('sys.symbol.list_checkmark'), ACTION_QGIS_CORE, false)
          this.operationButton($r('app.string.gn_arc_python'), $r('sys.symbol.doc_text'), ACTION_QGIS_CORE, false)
          this.operationButton('栅格函数', $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_QGIS_CORE, false)
          Column() {
            this.compactStatusButton('数据工程', $r('sys.symbol.doc_text'), '数据工程入口已预留')
            this.compactStatusButton('适宜性建模', $r('sys.symbol.map'), '适宜性建模入口已预留')
          }
          Column() {
            this.compactStatusButton('可视域分析', $r('sys.symbol.plus_magnifyingglass'), '可视域分析入口已预留')
            this.compactStatusButton('网络分析', $r('sys.symbol.plus_square_on_square'), '网络分析入口已预留')
          }
        } else if (groupIndex === 34) {
          this.operationStatusButton('链接视图', $r('sys.symbol.map'), '链接视图入口已预留：后续联动多个地图视图')
          this.operationStatusButton('链接光标', $r('sys.symbol.location_up'), '链接光标入口已预留：后续同步多视图光标')
          this.operationStatusButton('窗格集', $r('sys.symbol.layer'), '窗格集入口已预留：当前可用内容、目录和工具箱窗格')
          Column() {
            this.compactStatusButton('缩略图', $r('sys.symbol.map'), '缩略图入口已预留')
            this.compactStatusButton('色觉模拟', $r('sys.symbol.paintpalette'), '色觉模拟入口已预留')
          }
          Column() {
            this.compactStatusButton('启用定位', $r('sys.symbol.location_up'), '定位入口已预留：当前可使用坐标拾取')
            this.compactStatusButton('视图裁剪', $r('sys.symbol.square_dashed_and_arrow_turn_up_right'), '视图裁剪入口已预留')
          }
        } else if (groupIndex === 35) {
          this.operationStatusButton('粘贴', $r('sys.symbol.doc_text'), '剪贴板入口已预留')
          this.operationButton('保存编辑', $r('sys.symbol.archivebox_fill'), ACTION_SAVE_PROJECT, false)
          this.operationStatusButton('放弃编辑', $r('sys.symbol.xmark'), '放弃编辑入口已预留：当前可关闭工具重新加载图层')
          Column() {
            this.compactStatusButton('无拓扑', $r('sys.symbol.layer'), '拓扑规则入口已预留')
            this.compactStatusButton('错误检查器', $r('sys.symbol.exclamationmark_triangle'), '错误检查器入口已预留')
          }
          Column() {
            this.compactButton('吸附设置', $r('sys.symbol.location_up'), ACTION_VECTOR_EDIT)
            this.compactButton($r('app.string.gn_data_reviewer'), $r('sys.symbol.list_checkmark'), ACTION_REPAIR)
          }
        } else if (groupIndex === 36) {
          this.operationStatusButton('新工作空间', $r('sys.symbol.map'), '影像工作空间入口已预留')
          this.operationStatusButton('地理配准', $r('sys.symbol.location_up'), '地理配准入口已预留')
          this.operationButton('栅格函数', $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_QGIS_CORE, false)
          Column() {
            this.compactStatusButton('变化检测', $r('sys.symbol.arrow_clockwise'), '变化检测入口已预留')
            this.compactStatusButton('光谱分析', $r('sys.symbol.paintpalette'), '光谱分析入口已预留')
          }
          Column() {
            this.compactStatusButton('分类向导', $r('sys.symbol.list_checkmark'), '影像分类入口已预留')
            this.compactStatusButton('像素编辑', $r('sys.symbol.square_and_pencil'), '像素编辑入口已预留')
          }
        } else if (groupIndex === 37) {
          this.operationButton('工程包', $r('sys.symbol.archivebox_fill'), ACTION_SAVE_PROJECT, false)
          this.operationButton('地图包', $r('sys.symbol.map'), ACTION_EXPORT, false)
          this.operationButton('移动地图', $r('sys.symbol.map'), ACTION_EXPORT, false)
          Column() {
            this.compactStatusButton('Web 图层', $r('sys.symbol.map'), 'Web 图层发布入口已预留')
            this.compactStatusButton('地理数据服务', $r('sys.symbol.folder'), '地理数据服务入口已预留')
          }
          Column() {
            this.compactButton('工程模板', $r('sys.symbol.doc_text'), ACTION_SAVE_PROJECT)
            this.compactButton('导出地图', $r('sys.symbol.download'), ACTION_EXPORT)
          }
        } else if (groupIndex === 38) {
          this.operationStatusButton('Ribbon', $r('sys.symbol.layer'), 'Ribbon 自定义入口已预留')
          this.operationStatusButton('快速访问栏', $r('sys.symbol.archivebox_fill'), '快速访问工具栏入口已预留')
          this.operationStatusButton('快捷键', $r('sys.symbol.doc_text'), '快捷键入口已预留')
          Column() {
            this.compactStatusButton('诊断监视器', $r('sys.symbol.plus_magnifyingglass'), '诊断监视器入口已预留')
            this.compactStatusButton('技术支持', $r('sys.symbol.questionmark_circle'), '技术支持入口已预留')
          }
          Column() {
            this.operationButton($r('app.string.gn_backstage_help'), $r('sys.symbol.questionmark_circle'),
              ACTION_HELP, false)
            this.operationButton($r('app.string.gn_backstage_about'), $r('sys.symbol.info_circle'),
              ACTION_ABOUT, false)
          }
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
      if (this.activeRibbonTab === RIBBON_PROJECT) {
        this.operationGroup($r('app.string.gn_workbench_group_project'), 0, 316)
      } else if (this.activeRibbonTab === RIBBON_MAP) {
        this.operationGroup('导航', 21, 430)
        this.operationGroup('图层', 2, 390)
        this.operationGroup('选择', 20, 330)
        this.operationGroup('量算', 5, 360)
      } else if (this.activeRibbonTab === RIBBON_INSERT) {
        this.operationGroup('出图元素', 23, 180)
      } else if (this.activeRibbonTab === RIBBON_ANALYSIS) {
        this.operationGroup($r('app.string.gn_workbench_group_analysis'), 3, 390)
      } else if (this.activeRibbonTab === RIBBON_VIEW) {
        this.operationGroup('窗格', 16, 260)
      } else if (this.activeRibbonTab === RIBBON_EDIT) {
        this.operationGroup($r('app.string.gn_workbench_group_edit_tools'), 7, 540)
      } else if (this.activeRibbonTab === RIBBON_IMAGERY) {
        this.operationGroup($r('app.string.gn_workbench_group_imagery'), 8, 180)
      } else if (this.activeRibbonTab === RIBBON_SHARE) {
        this.operationGroup($r('app.string.gn_workbench_group_share'), 19, 240)
      } else {
        this.operationGroup($r('app.string.gn_workbench_group_help'), 10, 170)
      }
    }
    .height(74)
  }

  @Builder
  operationArea() {
    Column() {
      if (!this.isCompactLayout()) {
        this.titleArea()
      }
      this.ribbonTabBar()
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
  layerToolButton(icon: Resource, actionId: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      this.symbol(icon, $r('sys.color.icon_secondary'), 17)
    }
    .width(24)
    .height(24)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.handleOperation(actionId);
    })
  }

  @Builder
  layerToolbar() {
    Row({ space: 10 }) {
      this.layerToolButton($r('sys.symbol.plus_square_on_square'), ACTION_ADD_DATA)
      this.layerToolButton($r('sys.symbol.eye'), ACTION_LAYER_TOGGLE)
      this.layerToolButton($r('sys.symbol.funnel'), ACTION_LAYER_FILTER)
      this.layerToolButton($r('sys.symbol.arrow_up'), ACTION_LAYER_UP)
      this.layerToolButton($r('sys.symbol.arrow_down'), ACTION_LAYER_DOWN)
      this.layerToolButton($r('sys.symbol.trash'), ACTION_LAYER_DELETE)
      Blank()
    }
    .height(34)
    .padding({ left: 10, right: 8 })
    .backgroundColor($r('app.color.gn_pane'))
  }

  @Builder
  contentsSearchBox() {
    Search({ placeholder: $r('app.string.gn_contents_search_placeholder') })
      .height(30)
      .margin({ left: 8, right: 8, top: 8, bottom: 6 })
      .backgroundColor($r('app.color.gn_paper'))
      .borderRadius(this.itemRadiusValue())
  }

  @Builder
  contentsTabButton(label: ResourceStr, icon: Resource, section: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 2 }) {
        this.symbol(icon, this.contentsSection === section ? $r('app.color.gn_blue_800') :
          $r('sys.color.icon_secondary'), 17)
        Text(label)
          .fontSize(9)
          .fontColor(this.contentsSection === section ? $r('app.color.gn_blue_800') :
            $r('app.color.gn_text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(38)
      .justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1)
    .height(42)
    .padding(0)
    .backgroundColor(this.contentsSection === section ? $r('app.color.gn_paper') : Color.Transparent)
    .borderRadius(this.itemRadiusValue())
    .border({
      width: this.contentsSection === section ? 1 : 0,
      color: $r('app.color.gn_line')
    })
    .onClick(() => {
      this.contentsSection = section;
    })
  }

  @Builder
  contentsTabBar() {
    Row({ space: 4 }) {
      this.contentsTabButton($r('app.string.gn_contents_drawing_order'), $r('sys.symbol.list_bullet_square'),
        CONTENTS_DRAWING_ORDER)
      this.contentsTabButton($r('app.string.gn_contents_source'), $r('sys.symbol.externaldrive'), CONTENTS_SOURCE)
      this.contentsTabButton($r('app.string.gn_contents_selection'), $r('sys.symbol.checkmark_square'),
        CONTENTS_SELECTION)
      this.contentsTabButton($r('app.string.gn_contents_labeling'), $r('sys.symbol.textformat'), CONTENTS_LABELING)
      this.contentsTabButton($r('app.string.gn_contents_editing'), $r('sys.symbol.square_and_pencil'),
        CONTENTS_EDITING)
    }
    .height(48)
    .padding({ left: 8, right: 8, bottom: 6 })
    .backgroundColor($r('app.color.gn_pane'))
  }

  @Builder
  contentsSectionHeader(title: ResourceStr) {
    Column() {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
        .width('100%')
      Text(this.contentsSectionSummary())
        .fontSize(11)
        .fontColor($r('app.color.gn_text_muted'))
        .margin({ top: 3 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .padding({ left: 14, right: 12, top: 6, bottom: 7 })
    .width('100%')
    .backgroundColor($r('app.color.gn_pane_alt'))
    .border({ width: { top: 1, bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  contentsMetaChip(label: ResourceStr, color: ResourceColor) {
    Text(label)
      .height(20)
      .padding({ left: 7, right: 7 })
      .fontSize(10)
      .fontColor(color)
      .backgroundColor($r('app.color.gn_pane_alt'))
      .borderRadius(this.itemRadiusValue())
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  contentsEmptyState() {
    Column({ space: 6 }) {
      this.symbol($r('sys.symbol.plus_square_on_square'), $r('sys.color.icon_secondary'), 24)
      Text($r('app.string.gn_contents_empty_title'))
        .fontSize(12)
        .fontColor($r('app.color.gn_text_primary'))
      Text($r('app.string.gn_contents_empty_desc'))
        .fontSize(11)
        .fontColor($r('app.color.gn_text_muted'))
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 24, bottom: 24 })
  }

  @Builder
  layerVisibilityButton(checked: boolean, layerIndex: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      SymbolGlyph(checked ? $r('sys.symbol.checkmark_square') : $r('sys.symbol.square'))
        .fontSize(15)
        .fontColor([checked ? $r('app.color.gn_blue_800') : $r('sys.color.icon_secondary')])
    }
    .width(24)
    .height(24)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.toggleLayerVisibility(layerIndex);
    })
  }

  @Builder
  layerItem(label: ResourceStr, icon: Resource, iconColor: ResourceColor, level: number, checked: boolean,
    selected: boolean, layerIndex: number) {
    Row({ space: 6 }) {
      Blank()
        .width(level * 14)
      this.symbol(level === 0 ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right'),
        $r('sys.color.icon_secondary'), 11)
      this.layerVisibilityButton(checked, layerIndex)
      this.symbol(icon, checked ? iconColor : $r('sys.color.icon_secondary'), 16)
      Text(label)
        .fontSize(13)
        .fontColor(checked ? $r('app.color.gn_text_primary') : $r('app.color.gn_text_muted'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (!checked && layerIndex >= 0) {
        Text('隐藏')
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
      }
    }
    .height(28)
    .padding({ left: 8, right: 8 })
    .margin({ left: 6, right: 6, top: 1, bottom: 1 })
    .borderRadius(this.itemRadiusValue())
    .backgroundColor(selected ? $r('app.color.gn_arc_selected') : Color.Transparent)
    .onClick(() => {
      this.selectLayer(layerIndex);
    })
  }

  @Builder
  contentsSourceLayerItem(item: LayerDisplayItem) {
    Column({ space: 5 }) {
      Row({ space: 6 }) {
        this.symbol(this.geometryIcon(item.geomType), item.visible ? item.symbolColor : $r('sys.color.icon_secondary'),
          16)
        Text(item.name)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.visible ? $r('app.color.gn_text_primary') : $r('app.color.gn_text_muted'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')

      Text(this.layerSourcePathText(item.sourcePath))
        .fontSize(10)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: 5 }) {
        this.contentsMetaChip(item.geometryText, $r('app.color.gn_blue_800'))
        this.contentsMetaChip(item.featureCount.toString() + ' 要素', $r('app.color.gn_text_muted'))
        this.contentsMetaChip(item.fieldCount.toString() + ' 字段', $r('app.color.gn_text_muted'))
      }
      .width('100%')

      Text(item.referenceText)
        .fontSize(10)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .margin({ left: 8, right: 8, top: 4 })
    .borderRadius(this.itemRadiusValue())
    .backgroundColor(this.selectedLayerIndex === item.index ? $r('app.color.gn_arc_selected') :
      $r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
    .onClick(() => {
      this.selectLayer(item.index);
    })
  }

  @Builder
  contentsSelectionLayerItem(item: LayerDisplayItem) {
    Row({ space: 8 }) {
      this.layerVisibilityButton(item.visible, item.index)
      this.symbol(this.geometryIcon(item.geomType), item.visible ? item.symbolColor : $r('sys.color.icon_secondary'),
        16)
      Column() {
        Text(item.name)
          .fontSize(13)
          .fontColor(item.visible ? $r('app.color.gn_text_primary') : $r('app.color.gn_text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.selectedFeatureCountForLayer(item.index).toString() + ' 已选 · ' +
          item.featureCount.toString() + ' 要素')
          .fontSize(10)
          .fontColor(this.selectedFeatureCountForLayer(item.index) > 0 ? $r('app.color.gn_blue_800') :
            $r('app.color.gn_text_muted'))
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.selectedFeatureCountForLayer(item.index) > 0) {
        this.symbol($r('sys.symbol.checkmark_circle'), $r('app.color.gn_blue_800'), 15)
      }
    }
    .height(44)
    .padding({ left: 8, right: 8 })
    .margin({ left: 8, right: 8, top: 3 })
    .borderRadius(this.itemRadiusValue())
    .backgroundColor(this.selectedFeatureCountForLayer(item.index) > 0 ? $r('app.color.gn_blue_100') :
      Color.Transparent)
    .onClick(() => {
      this.selectLayer(item.index);
    })
  }

  @Builder
  contentsLabelingLayerItem(item: LayerDisplayItem) {
    Row({ space: 8 }) {
      this.symbol($r('sys.symbol.textformat'), item.visible ? item.symbolColor : $r('sys.color.icon_secondary'), 16)
      Column() {
        Text(item.name)
          .fontSize(13)
          .fontColor(item.visible ? $r('app.color.gn_text_primary') : $r('app.color.gn_text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.labelText)
          .fontSize(10)
          .fontColor(item.labelText === '标注关闭' ? $r('app.color.gn_text_muted') : $r('app.color.gn_blue_800'))
          .margin({ top: 2 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(item.rendererText)
        .fontSize(10)
        .fontColor($r('app.color.gn_text_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(74)
    }
    .height(46)
    .padding({ left: 10, right: 10 })
    .margin({ left: 8, right: 8, top: 3 })
    .borderRadius(this.itemRadiusValue())
    .backgroundColor(this.selectedLayerIndex === item.index ? $r('app.color.gn_arc_selected') : Color.Transparent)
    .onClick(() => {
      this.selectLayer(item.index);
      this.openWorkspaceDialog(11);
    })
  }

  @Builder
  contentsEditingLayerItem(item: LayerDisplayItem) {
    Row({ space: 8 }) {
      this.symbol(this.selectedOperationalLayerIndex() === item.index ? $r('sys.symbol.square_and_pencil') :
        this.geometryIcon(item.geomType), this.selectedOperationalLayerIndex() === item.index ?
        $r('app.color.gn_blue_800') : $r('sys.color.icon_secondary'), 16)
      Column() {
        Text(item.name)
          .fontSize(13)
          .fontColor($r('app.color.gn_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.geometryText + '图层 · ' + item.featureCount.toString() + ' 要素')
          .fontSize(10)
          .fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.selectedOperationalLayerIndex() === item.index) {
        this.contentsMetaChip($r('app.string.gn_contents_active_edit'), $r('app.color.gn_blue_800'))
      }
    }
    .height(46)
    .padding({ left: 10, right: 10 })
    .margin({ left: 8, right: 8, top: 3 })
    .borderRadius(this.itemRadiusValue())
    .backgroundColor(this.selectedOperationalLayerIndex() === item.index ? $r('app.color.gn_blue_100') :
      Color.Transparent)
    .onClick(() => {
      this.selectLayer(item.index);
    })
  }

  @Builder
  contentsDrawingOrderContent() {
    Column() {
      this.contentsSectionHeader($r('app.string.gn_contents_drawing_order'))
      this.layerItem($r('app.string.gn_map_section'), $r('sys.symbol.map'), $r('app.color.gn_blue_800'), 0, false,
        this.selectedLayerIndex === -1, -1)
      this.layerItem(this.basemapLayerName(), $r('sys.symbol.map'), $r('app.color.gn_green_700'), 1, true,
        this.selectedLayerIndex === -2, -2)

      ForEach(this.buildLayerDisplayList(), (item: LayerDisplayItem) => {
        this.layerItem(item.name, this.geometryIcon(item.geomType), item.symbolColor, 1, item.visible,
          this.selectedLayerIndex === item.index, item.index)
      }, (item: LayerDisplayItem) => item.stateKey)

      if (this.layerCount === 0) {
        this.contentsEmptyState()
      }
    }
    .width('100%')
  }

  @Builder
  contentsSourceContent() {
    Column() {
      this.contentsSectionHeader($r('app.string.gn_contents_source'))
      if (this.layerCount === 0) {
        this.contentsEmptyState()
      } else {
        ForEach(this.buildLayerDisplayList(), (item: LayerDisplayItem) => {
          this.contentsSourceLayerItem(item)
        }, (item: LayerDisplayItem) => 'source:' + item.stateKey)
      }
    }
    .width('100%')
  }

  @Builder
  contentsSelectionContent() {
    Column() {
      this.contentsSectionHeader($r('app.string.gn_contents_selection'))
      if (this.layerCount === 0) {
        this.contentsEmptyState()
      } else {
        ForEach(this.buildLayerDisplayList(), (item: LayerDisplayItem) => {
          this.contentsSelectionLayerItem(item)
        }, (item: LayerDisplayItem) => 'selection:' + item.stateKey)
      }
    }
    .width('100%')
  }

  @Builder
  contentsLabelingContent() {
    Column() {
      this.contentsSectionHeader($r('app.string.gn_contents_labeling'))
      if (this.layerCount === 0) {
        this.contentsEmptyState()
      } else {
        ForEach(this.buildLayerDisplayList(), (item: LayerDisplayItem) => {
          this.contentsLabelingLayerItem(item)
        }, (item: LayerDisplayItem) => 'labeling:' + item.stateKey)
      }
    }
    .width('100%')
  }

  @Builder
  contentsEditingContent() {
    Column() {
      this.contentsSectionHeader($r('app.string.gn_contents_editing'))
      if (this.layerCount === 0) {
        this.contentsEmptyState()
      } else {
        ForEach(this.buildLayerDisplayList(), (item: LayerDisplayItem) => {
          this.contentsEditingLayerItem(item)
        }, (item: LayerDisplayItem) => 'editing:' + item.stateKey)
      }
    }
    .width('100%')
  }

  @Builder
  contentsBody() {
    if (this.contentsSection === CONTENTS_SOURCE) {
      this.contentsSourceContent()
    } else if (this.contentsSection === CONTENTS_SELECTION) {
      this.contentsSelectionContent()
    } else if (this.contentsSection === CONTENTS_LABELING) {
      this.contentsLabelingContent()
    } else if (this.contentsSection === CONTENTS_EDITING) {
      this.contentsEditingContent()
    } else {
      this.contentsDrawingOrderContent()
    }
  }

  private geometryIcon(geomType: number): Resource {
    if (geomType === 1) return $r('sys.symbol.location_up');
    if (geomType === 2) return $r('sys.symbol.road_lanes_badge_minus');
    return $r('sys.symbol.layer');
  }

  private layerRampTotal(layer: GisLoadedLayer): number {
    if (layer.style.rendererMode === 1) {
      return qgisCategoryTotal(layer, layer.style.rendererField);
    }
    if (layer.style.rendererMode === 2) {
      return 5;
    }
    return 1;
  }

  private layerDisplayColor(layer: GisLoadedLayer): string {
    if (layer.info.legendColor.length > 0) {
      return layer.info.legendColor;
    }
    if (layer.style.rendererMode === 1 || layer.style.rendererMode === 2) {
      return qgisRampColor(layer.style.colorRamp, 0, this.layerRampTotal(layer));
    }
    if (layer.info.geometryType === 1) {
      return layer.style.pointColor;
    }
    if (layer.info.geometryType === 2) {
      return layer.style.lineColor;
    }
    return layer.style.fillColor;
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
        item.referenceText = this.layerReferenceText(layer);
        item.geometryText = this.geometryName(layer.info.geometryType);
        item.rendererText = this.layerRendererText(layer);
        item.labelText = this.layerLabelText(layer);
        item.stateKey = item.id + ':' + (item.visible ? 'visible' : 'hidden') + ':' +
          this.renderKey.toString() + ':' + this.activeLayerRevision.toString() + ':' +
          (this.selectedLayerIndex === i ? 'selected' : 'idle');
        items.push(item);
      }
    }
    return items;
  }

  @Builder
  layerPanel() {
    Column() {
      this.panelHeader($r('app.string.gn_workbench_layer_panel'), 0, this.layerPanelCollapsed)
      this.layerToolbar()
      this.contentsSearchBox()
      this.contentsTabBar()
      Scroll() {
        Column() {
          this.contentsBody()
          Blank()
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
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
    Row() {
      Row({ space: 6 }) {
        this.symbol($r('sys.symbol.map'), $r('app.color.gn_blue_800'), 16)
        Text(this.currentMapTitleText())
          .fontSize(13)
          .fontColor($r('app.color.gn_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .key('title:' + this.activeLayerRevision.toString())
      }
      .height(32)
      .padding({ left: 12, right: 14 })
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: { right: 1 }, color: $r('app.color.gn_line') })
      Scroll() {
        Row({ space: 6 }) {
          this.mapToolChip($r('app.string.gn_tool_identify'), MAP_TOOL_IDENTIFY)
          this.mapToolChip($r('app.string.gn_measure_distance'), MAP_TOOL_MEASURE_DISTANCE)
          this.mapToolChip($r('app.string.gn_measure_area'), MAP_TOOL_MEASURE_AREA)
          this.mapToolChip($r('app.string.gn_measure_angle'), MAP_TOOL_MEASURE_ANGLE)
          this.mapToolChip($r('app.string.gn_pick_coordinate'), MAP_TOOL_PICK_COORDINATE)
          this.mapToolChip('加点', MAP_TOOL_EDIT_ADD_POINT)
          this.mapToolChip('加线', MAP_TOOL_EDIT_ADD_LINE)
          this.mapToolChip('加面', MAP_TOOL_EDIT_ADD_POLYGON)
          this.mapToolChip('移节点', MAP_TOOL_EDIT_MOVE_NODE)
          this.mapToolChip('删节点', MAP_TOOL_EDIT_DELETE_NODE)
        }
        .padding({ left: 10, right: 10 })
      }
      .layoutWeight(1)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .height(34)
    .backgroundBlurStyle(MaterialStyle.toolbarBlurStyle())
    .backgroundColor(this.materialSurfaceColor($r('app.color.gn_pane_alt')))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  mapToolChip(label: ResourceStr, toolMode: number) {
    Text(label)
    .height(24)
    .padding({ left: 9, right: 9 })
      .fontSize(11)
      .fontWeight(this.mapToolMode === toolMode ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.mapToolMode === toolMode ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .backgroundBlurStyle(MaterialStyle.componentBlurStyle())
      .backgroundColor(this.mapToolMode === toolMode ? $r('app.color.gn_blue_100') : Color.Transparent)
      .borderRadius(this.itemRadiusValue())
      .onClick(() => {
        this.setMapToolMode(toolMode);
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
      GisMapCanvas({
        layers: this.buildLoadedLayers(),
        basemapMode: this.basemapMode,
        basemapDatumMode: this.basemapDatumMode,
        selectedFeatureId: this.selectedFeatureId,
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
        onFeatureSelected: (featureId: string, layerIndex: number) => {
          this.onFeatureSelected(featureId, layerIndex);
        },
        onViewportChanged: (viewport: MapViewport) => {
          this.onViewportChanged(viewport);
        },
        onMeasurementChanged: (summary: string) => {
          this.measurementStatus = summary;
        },
        onBasemapStatusChanged: (summary: string) => {
          this.basemapStatus = summary;
        },
        onSketchFeatureCreated: (geometryType: number, points: GisCoordinate[]) => {
          this.onSketchFeatureCreated(geometryType, points);
        },
        onNodeEditRequested: (editMode: number, layerIndex: number, featureId: string, partIndex: number,
          pointIndex: number, mapX: number, mapY: number) => {
          this.onNodeEditRequested(editMode, layerIndex, featureId, partIndex, pointIndex, mapX, mapY);
        }
      })
        .layoutWeight(1)

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
    .layoutWeight(1)
    .clip(true)
  }

  @Builder
  mapStatusSegment(icon: Resource, label: ResourceStr, color: ResourceColor) {
    Row({ space: 4 }) {
      this.symbol(icon, color, 13)
      Text(label)
        .fontSize(12)
        .fontColor(color)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(24)
    .padding({ left: 7, right: 7 })
    .borderRadius(this.itemRadiusValue())
    .backgroundColor($r('app.color.gn_pane_alt'))
  }

  @Builder
  mapStatusBar() {
    Scroll(undefined) {
      Row({ space: 6 }) {
        this.mapStatusSegment($r('sys.symbol.map'), this.viewportScale, $r('app.color.gn_text_primary'))
        this.mapStatusSegment($r('sys.symbol.location_up'), this.viewportCoordinateText,
          $r('app.color.gn_text_primary'))
        this.mapStatusSegment($r('sys.symbol.doc_text'), this.mapReferenceStatus, $r('app.color.gn_text_muted'))
        this.mapStatusSegment($r('sys.symbol.layer'), this.catalogSummaryText(), $r('app.color.gn_text_muted'))
        this.mapStatusSegment($r('sys.symbol.map'), this.basemapName(),
          this.basemapMode === BASEMAP_VECTOR ? $r('app.color.gn_text_muted') : $r('app.color.gn_blue_800'))
        if (this.isExternalBasemapMode(this.basemapMode)) {
          this.mapStatusSegment($r('sys.symbol.location_up'), this.basemapDatumName(), $r('app.color.gn_blue_800'))
        }
        if (this.basemapStatus.length > 0) {
          this.mapStatusSegment($r('sys.symbol.exclamationmark_triangle'), this.basemapStatus,
            this.basemapStatusColor())
        }
        if (this.measurementStatus.length > 0) {
          this.mapStatusSegment($r('sys.symbol.plus_magnifyingglass'), this.measurementStatus,
            $r('app.color.gn_orange_700'))
        }
        if (this.dataLoadStatus.length > 0) {
          this.mapStatusSegment($r('sys.symbol.arrow_clockwise'), this.dataLoadStatus, $r('app.color.gn_text_muted'))
        }
        if (this.editStatus.length > 0) {
          this.mapStatusSegment($r('sys.symbol.wrench_arrow_counterclockwise'), this.editStatus,
            $r('app.color.gn_blue_800'))
        }
        this.mapStatusSegment($r('sys.symbol.checkmark_square'), this.selectedFeatureStatusText(),
          $r('app.color.gn_text_muted'))
        if (this.projectDirty) {
          this.mapStatusSegment($r('sys.symbol.doc_text_badge_clock'), $r('app.string.gn_workbench_dirty_state'),
            $r('app.color.gn_orange_700'))
        } else {
          this.mapStatusSegment($r('sys.symbol.doc_plaintext_and_checkmark'), $r('app.string.gn_workbench_clean_state'),
            $r('app.color.gn_green_700'))
        }
        if (this.nativeBridgeAvailable) {
          this.mapStatusSegment($r('sys.symbol.checkmark_circle'), this.nativeBridgeVersion,
            $r('app.color.gn_blue_800'))
        } else {
          this.mapStatusSegment($r('sys.symbol.exclamationmark_triangle'),
            $r('app.string.gn_workbench_native_core_unavailable'), $r('app.color.gn_orange_700'))
        }
      }
      .padding({ left: 8, right: 8 })
    }
    .width('100%')
    .height(30)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Auto)
    .backgroundBlurStyle(MaterialStyle.toolbarBlurStyle())
    .backgroundColor(this.materialSurfaceColor($r('app.color.gn_paper')))
    .border({ width: { top: 1 }, color: $r('app.color.gn_line') })
  }

  @Builder
  mapPanel() {
    Column() {
      this.mapTabBar()
      this.mapCanvas()
      this.mapStatusBar()
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundBlurStyle(MaterialStyle.panelBlurStyle())
    .backgroundColor(this.materialSurfaceColor($r('app.color.gn_paper')))
    .borderRadius(this.paneRadiusValue())
    .clip(true)
    .border({ width: 1, color: $r('app.color.gn_line_strong') })
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
    let layerIndex = this.selectedOperationalLayerIndex();
    if (layerIndex < 0) {
      return undefined;
    }
    return this.gisService.getLayer(layerIndex);
  }

  private catalogLayerKey(): string {
    let layer = this.getCatalogLayer();
    if (layer === undefined) {
      return 'catalog:none:' + this.activeLayerRevision.toString();
    }
    return 'catalog:' + this.selectedOperationalLayerIndex().toString() + ':' + layer.info.layerId + ':' +
      this.activeLayerRevision.toString();
  }

  private catalogLayerMeta(item: LayerDisplayItem): string {
    let visibleText = item.visible ? '可见' : '隐藏';
    let crsText = item.referenceText.length > 0 ? item.referenceText : 'CRS 未声明';
    return item.featureCount.toString() + ' 要素 · ' + item.fieldCount.toString() + ' 字段 · ' + crsText +
      ' · ' + visibleText;
  }

  @Builder
  catalogScopeTab(label: ResourceStr, section: number) {
    Text(label)
      .height(28)
      .padding({ left: 8, right: 8 })
      .fontSize(13)
      .fontWeight(this.catalogSection === section ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.catalogSection === section ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .border({
        width: { bottom: this.catalogSection === section ? 2 : 0 },
        color: $r('app.color.gn_blue_800')
      })
      .onClick(() => {
        this.catalogSection = section;
      })
  }

  @Builder
  catalogScopeTabs() {
    Row() {
      this.catalogScopeTab($r('app.string.gn_project'), CATALOG_PROJECT)
      this.catalogScopeTab($r('app.string.gn_arc_portal'), CATALOG_PORTAL)
      this.catalogScopeTab($r('app.string.gn_arc_computer'), CATALOG_COMPUTER)
      this.catalogScopeTab($r('app.string.gn_arc_favorites'), CATALOG_FAVORITES)
      Blank()
      this.symbol($r('sys.symbol.line_3_horizontal'), $r('sys.color.icon_secondary'), 16)
    }
    .height(30)
    .padding({ left: 8, right: 10 })
    .backgroundColor($r('app.color.gn_pane'))
  }

  @Builder
  catalogNavButton(icon: Resource, enabledValue: boolean) {
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
      this.catalogSection = CATALOG_PROJECT;
    })
  }

  @Builder
  catalogNavigationRow() {
    Row({ space: 4 }) {
      this.catalogNavButton($r('sys.symbol.chevron_left'), false)
      this.catalogNavButton($r('sys.symbol.folder_fill'), true)
      this.symbol($r('sys.symbol.funnel'), $r('sys.color.icon_secondary'), 15)
      Search({ placeholder: $r('app.string.gn_arc_search_project') })
        .height(30)
        .layoutWeight(1)
        .backgroundColor($r('app.color.gn_paper'))
    }
    .height(36)
    .padding({ left: 8, right: 8, bottom: 4 })
    .backgroundColor($r('app.color.gn_pane'))
  }

  @Builder
  catalogItem(label: ResourceStr, icon: Resource, level: number, routeId: number) {
    Row({ space: 6 }) {
      Blank()
        .width(level * 14)
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
    .borderRadius(this.itemRadiusValue())
    .onClick(() => {
      this.openWorkspaceDialog(routeId);
    })
  }

  @Builder
  catalogPlaceholder(title: ResourceStr, desc: ResourceStr, icon: Resource) {
    Column({ space: 8 }) {
      this.symbol(icon, $r('sys.color.icon_secondary'), 28)
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
      Text(desc)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .textAlign(TextAlign.Center)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 38 })
  }

  @Builder
  catalogLayerItem(item: LayerDisplayItem) {
    Row({ space: 6 }) {
      Blank()
        .width(14)
      this.symbol($r('sys.symbol.chevron_right'), $r('sys.color.icon_secondary'), 11)
      this.symbol(this.geometryIcon(item.geomType), item.visible ? item.symbolColor : $r('sys.color.icon_secondary'), 16)
      Column() {
        Text(item.name)
          .fontSize(13)
          .fontColor(item.visible ? $r('app.color.gn_text_primary') : $r('app.color.gn_text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.catalogLayerMeta(item))
          .fontSize(10)
          .fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 2 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .height(42)
    .padding({ left: 8, right: 8 })
    .margin({ left: 6, right: 6, top: 1, bottom: 1 })
    .borderRadius(this.itemRadiusValue())
    .backgroundColor(this.selectedLayerIndex === item.index ? $r('app.color.gn_arc_selected') : Color.Transparent)
    .onClick(() => {
      this.selectLayer(item.index);
    })
  }

  @Builder
  catalogFieldItem(field: GisFieldInfo) {
    Row({ space: 6 }) {
      Blank()
        .width(32)
      this.symbol($r('sys.symbol.doc_text'), $r('sys.color.icon_secondary'), 13)
      Text(field.name)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(field.typeName)
        .fontSize(10)
        .fontColor($r('app.color.gn_text_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(26)
    .padding({ left: 8, right: 8 })
  }

  @Builder
  catalogContent() {
    Column() {
      Text(this.catalogLayerKey())
        .width(0)
        .height(0)
        .fontSize(0)
        .opacity(0)
      this.catalogScopeTabs()
      this.catalogNavigationRow()
      Scroll() {
        Column() {
          if (this.catalogSection === CATALOG_PROJECT) {
            this.catalogItem($r('app.string.gn_workbench_project_catalog'), $r('sys.symbol.folder_fill'), 0, 1)
            this.catalogItem($r('app.string.gn_arc_maps'), $r('sys.symbol.map'), 0, 1)
            this.catalogItem($r('app.string.gn_map_section'), $r('sys.symbol.map'), 1, 1)
            Text(this.catalogSummaryText())
              .fontSize(11)
              .fontColor($r('app.color.gn_text_muted'))
              .width('100%')
              .padding({ left: 38, top: 2, bottom: 4 })
            if (this.layerCount === 0) {
              Column() {
                Text($r('app.string.gn_catalog_no_layers_title'))
                  .fontSize(12)
                  .fontColor($r('app.color.gn_text_muted'))
                Text($r('app.string.gn_catalog_no_layers_desc'))
                  .fontSize(11)
                  .fontColor($r('app.color.gn_text_muted'))
                  .margin({ top: 4 })
              }
              .width('100%')
              .padding(12)
              .alignItems(HorizontalAlign.Start)
            } else {
              ForEach(this.buildLayerDisplayList(), (item: LayerDisplayItem) => {
                this.catalogLayerItem(item)
              }, (item: LayerDisplayItem) => 'catalog:' + item.stateKey)

              if (this.getCatalogLayer() !== undefined) {
                Text($r('app.string.gn_catalog_fields'))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.gn_text_muted'))
                  .width('100%')
                  .padding({ left: 12, top: 8, bottom: 4 })
                ForEach((this.getCatalogLayer() as GisLoadedLayer).info.fields, (field: GisFieldInfo) => {
                  this.catalogFieldItem(field)
                }, (field: GisFieldInfo) => this.catalogLayerKey() + ':field:' + field.name)
              }
            }

            this.catalogItem($r('app.string.gn_arc_toolboxes'), $r('sys.symbol.wrench_arrow_counterclockwise'), 0, 3)
            this.catalogItem($r('app.string.gn_arc_databases'), $r('sys.symbol.folder_fill'), 0, 1)
            this.catalogItem($r('app.string.gn_arc_styles'), $r('sys.symbol.paintpalette'), 0, 5)
            this.catalogItem($r('app.string.gn_arc_folders'), $r('sys.symbol.folder'), 0, 1)
            this.catalogItem($r('app.string.gn_arc_locators'), $r('sys.symbol.location_up'), 0, 1)
          } else if (this.catalogSection === CATALOG_PORTAL) {
            this.catalogPlaceholder($r('app.string.gn_arc_portal'), $r('app.string.gn_catalog_portal_placeholder'),
              $r('sys.symbol.map'))
          } else if (this.catalogSection === CATALOG_COMPUTER) {
            this.catalogPlaceholder($r('app.string.gn_arc_computer'), $r('app.string.gn_catalog_computer_placeholder'),
              $r('sys.symbol.folder'))
          } else {
            this.catalogPlaceholder($r('app.string.gn_arc_favorites'), $r('app.string.gn_catalog_favorites_placeholder'),
              $r('sys.symbol.star_folder_fill'))
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

  @Builder
  toolItem(label: ResourceStr, desc: ResourceStr, icon: Resource, actionId: number) {
    Row({ space: 10 }) {
      this.symbol(icon, $r('app.color.gn_blue_800'), 20)
      Column() {
        Text(label)
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
    }
    .height(58)
    .padding({ left: 12, right: 10 })
    .margin({ left: 8, right: 8, top: 4 })
    .borderRadius(this.itemRadiusValue())
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
    .onClick(() => {
      this.handleOperation(actionId);
    })
  }

  @Builder
  toolsContent() {
    Column() {
      Search({ placeholder: $r('app.string.gn_workbench_tool_search') })
        .height(30)
        .margin({ left: 8, right: 8, bottom: 6 })
        .backgroundColor($r('app.color.gn_paper'))
      Scroll() {
        Column() {
          this.toolItem($r('app.string.gn_qgis_core_title'), $r('app.string.gn_qgis_core_desc'),
            $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_QGIS_CORE)
          this.toolItem('矢量编辑', '新增点线面、节点移动删除、复制、撤销重做、吸附入口',
            $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_VECTOR_EDIT)
          this.toolItem('属性编辑', '字段值修改、批量赋值、字段增删和字段计算器',
            $r('sys.symbol.doc_text'), ACTION_ATTRIBUTE_EDIT)
          this.toolItem('标注系统', '字段标注、样式、避让、比例尺控制和开关',
            $r('sys.symbol.doc_text'), ACTION_LABELING)
          this.toolItem('栅格显示', '单波段、RGB、拉伸、NoData、色带和阴影地形配置',
            $r('sys.symbol.map'), ACTION_RASTER_DISPLAY)
          this.toolItem('地图出图', '布局标题、图例、比例尺、指北针、坐标网和导出格式',
            $r('sys.symbol.doc_text'), ACTION_LAYOUT)
          this.toolItem($r('app.string.gn_cmd_clip'), $r('app.string.gn_tool_runner_desc'),
            $r('sys.symbol.square_dashed_and_arrow_turn_up_right'), ACTION_CLIP)
          this.toolItem($r('app.string.gn_cmd_buffer'), $r('app.string.gn_workbench_buffer_desc'),
            $r('sys.symbol.circle_grid_2x2'), ACTION_BUFFER)
          this.toolItem($r('app.string.gn_cmd_repair'), $r('app.string.gn_workbench_repair_desc'),
            $r('sys.symbol.wrench_arrow_counterclockwise'), ACTION_REPAIR)
          this.toolItem($r('app.string.gn_cmd_export'), $r('app.string.gn_workbench_export_desc'),
            $r('sys.symbol.download'), ACTION_EXPORT)
          this.toolItem($r('app.string.gn_cmd_define_projection'), $r('app.string.gn_workbench_define_projection_desc'),
            $r('sys.symbol.map'), ACTION_DEFINE_PROJECTION)
          this.toolItem($r('app.string.gn_cmd_project_layer'), $r('app.string.gn_workbench_project_layer_desc'),
            $r('sys.symbol.arrow_right_and_square'), ACTION_PROJECT_LAYER)
          this.toolItem($r('app.string.gn_cmd_simplify'), $r('app.string.gn_workbench_simplify_desc'),
            $r('sys.symbol.arrow_down_right_and_arrow_up_left'), ACTION_SIMPLIFY)
          this.toolItem($r('app.string.gn_cmd_dissolve'), $r('app.string.gn_workbench_dissolve_desc'),
            $r('sys.symbol.square_and_square'), ACTION_DISSOLVE)
          this.toolItem($r('app.string.gn_cmd_centroid'), $r('app.string.gn_workbench_centroid_desc'),
            $r('sys.symbol.location_up'), ACTION_CENTROID)
          this.toolItem('打印出图', '页面尺寸、比例尺、图例、指北针和导出 PDF',
            $r('sys.symbol.printer'), ACTION_PRINT)
          Blank()
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .layoutWeight(1)
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
          featureCount: this.selectedFeatureAttrs.length,
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
        this.operationArea()
        this.workArea()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.gn_arc_window'))

      Row().width(0).height(0)
        .bindSheet($$this.backstageVisible, this.backstageDialogContent(), {
          detents: [SheetSize.LARGE],
          preferType: SheetType.CENTER,
          dragBar: false,
          backgroundColor: Color.Transparent,
          blurStyle: BlurStyle.Thin,
          systemMaterial: MaterialStyle.nativeMaterial(this.materialEnabled),
          showClose: false,
          onDisappear: (): void => { this.backstageVisible = false; }
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
          this.openWorkspaceDialog(9);
        },
        onOpenAttributeEdit: () => {
          this.openWorkspaceDialog(10);
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
        }
      })
      AttributeTableSheet({
        trigger: this.attributeTableTrigger,
        activeLayerRevision: this.activeLayerRevision,
        onLocateFeature: (featureId: string, layerIndex: number) => {
          this.onAttributeFeatureLocated(featureId, layerIndex);
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
          this.setMapToolMode(toolMode);
          this.editStatus = '编辑工具已启用';
        },
        onEditCommand: (command: number) => {
          this.runVectorEditCommand(command);
        }
      })
      AttributeEditSheet({
        trigger: this.attributeEditTrigger,
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
        toolMode: 1,
        onChooseLocalLayer: (fieldIndex: number, onSelected: (layerName: string) => void) => {
          this.chooseLocalLayerForTool(fieldIndex, onSelected);
        },
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.bufferToolTrigger,
        toolMode: 2,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.repairToolTrigger,
        toolMode: 3,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.exportToolTrigger,
        toolMode: 4,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.defineProjectionTrigger,
        toolMode: 5,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.projectLayerTrigger,
        toolMode: 6,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.simplifyToolTrigger,
        toolMode: 7,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.dissolveToolTrigger,
        toolMode: 8,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      ToolRunnerSheet({
        trigger: this.centroidToolTrigger,
        toolMode: 9,
        onToolCompleted: () => {
          this.onAnalysisToolCompleted();
        }
      })
      AppSettingsSheet({
        trigger: this.appSettingsTrigger
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.gn_arc_window'))
    .onAreaChange((_oldVal: Area, newVal: Area) => {
      this.updateCompactLayout(Number(newVal.width), Number(newVal.height));
    }, { expectedUpdateInterval: 100 })
  }
}

class LayerDisplayItem {
  index: number = 0;
  id: string = '';
  name: string = '';
  geomType: number = 0;
  visible: boolean = true;
  featureCount: number = 0;
  fieldCount: number = 0;
  crs: string = '';
  symbolColor: string = '#1D4F91';
  sourcePath: string = '';
  referenceText: string = '';
  geometryText: string = '';
  rendererText: string = '';
  labelText: string = '';
  stateKey: string = '';
}
