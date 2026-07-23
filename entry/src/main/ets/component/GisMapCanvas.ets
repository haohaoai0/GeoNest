import {
  getGisService,
  GisLoadedLayer,
  qgisRampColor
} from '../gis/GisService';
import {
  GisFeatureSummary,
  GisFeaturePage,
  GisCoordinate,
  GisEnvelope,
  GisGeometryPayload,
  GisAttributeValue,
  GisGeoProcessResult,
  GisCoordinateTransformResult,
  GisEnvelopeTransformResult
} from '../model/GeoNestModels';
import { AsyncCallback, BusinessError } from '@ohos.base';
import { webview } from '@kit.ArkWeb';
import { MapComponent, map, mapCommon } from '@kit.MapKit';
import hilog from '@ohos.hilog';
import {
  BASEMAP_DATUM_AUTO,
  BASEMAP_DATUM_GCJ02,
  BASEMAP_DATUM_WGS84,
  BASEMAP_HARMONY_IMAGERY,
  BASEMAP_HARMONY_STANDARD,
  BASEMAP_HARMONY_TERRAIN,
  BASEMAP_IMAGERY,
  BASEMAP_ONLINE_STANDARD,
  BASEMAP_TERRAIN,
  BASEMAP_VECTOR,
  FEATURE_SELECTION_REPLACE,
  FEATURE_SELECTION_TOGGLE,
  MAP_COMMAND_FULL_EXTENT,
  MAP_COMMAND_NONE,
  MAP_COMMAND_ZOOM_IN,
  MAP_COMMAND_ZOOM_OUT,
  MAP_COMMAND_ZOOM_PRIMARY,
  MAP_COMMAND_ZOOM_SELECTED,
  MAP_TOOL_EDIT_ADD_LINE,
  MAP_TOOL_EDIT_ADD_POINT,
  MAP_TOOL_EDIT_ADD_POLYGON,
  MAP_TOOL_EDIT_CUT_SKETCH,
  MAP_TOOL_EDIT_DELETE_NODE,
  MAP_TOOL_EDIT_MOVE_NODE,
  MAP_TOOL_EDIT_ORTHOGONAL,
  MAP_TOOL_EDIT_PARALLEL,
  MAP_TOOL_EDIT_PERPENDICULAR,
  MAP_TOOL_EDIT_TRACE,
  MAP_TOOL_IDENTIFY,
  MAP_TOOL_MEASURE_ANGLE,
  MAP_TOOL_MEASURE_AREA,
  MAP_TOOL_MEASURE_DISTANCE,
  MAP_TOOL_PICK_COORDINATE,
  MAP_TOOL_SELECT_BOX,
  MAP_TOOL_SELECT_LASSO,
  MAP_TOOL_SELECT_MULTIPLE,
  MAP_TOOL_SELECT_POLYGON
} from '@geonest/common';

// Geometry type constants (must match native)
const GEOM_UNKNOWN: number = 0;
const GEOM_POINT: number = 1;
const GEOM_LINESTRING: number = 2;
const GEOM_POLYGON: number = 3;
const UNIT_UNKNOWN: number = 0;
const UNIT_ANGULAR: number = 1;
const UNIT_LINEAR: number = 2;
const TAG: number = 0xFF00;
const DOMAIN: string = 'GeoNest';
const WEB_MERCATOR_METERS_PER_PIXEL_Z0: number = 156543.03392804097;
const WEB_MERCATOR_MAX_LATITUDE: number = 85.0511287798066;
const WEB_MERCATOR_RADIUS_METERS: number = 6378137.0;
const EARTH_RADIUS_METERS: number = 6371008.8;
const SCREEN_PIXEL_SIZE_METERS: number = 0.0002645833333;
const HARMONY_MAP_LOAD_TIMEOUT_MS: number = 8000;
const NATIVE_VECTOR_RENDER_THRESHOLD: number = 400;
const MAX_CANVAS_LABELS_PER_LAYER: number = 120;
const VIEWPORT_INTERACTION_LIMIT: number = 1200;
const POINT_QUERY_LIMIT: number = 128;

class EditNodeHit {
  found: boolean = false;
  layerIndex: number = -1;
  featureId: string = '';
  partIndex: number = -1;
  pointIndex: number = -1;

  constructor(found: boolean, layerIndex: number, featureId: string, partIndex: number, pointIndex: number) {
    this.found = found;
    this.layerIndex = layerIndex;
    this.featureId = featureId;
    this.partIndex = partIndex;
    this.pointIndex = pointIndex;
  }
}

class LayerRenderStats {
  categoryValues: string[] = [];
  hasNumericRange: boolean = false;
  minValue: number = 0.0;
  maxValue: number = 0.0;

  categoryBucket(value: string): number {
    for (let i = 0; i < this.categoryValues.length; i++) {
      if (this.categoryValues[i] === value) {
        return i;
      }
    }
    return 0;
  }

  categoryTotal(): number {
    if (this.categoryValues.length < 1) {
      return 1;
    }
    return this.categoryValues.length;
  }

  graduatedBucket(value: number): number {
    if (!this.hasNumericRange || Math.abs(this.maxValue - this.minValue) < 0.0000001) {
      return 0;
    }
    let ratio = (value - this.minValue) / (this.maxValue - this.minValue);
    let bucket = Math.floor(ratio * 5.0);
    if (bucket < 0) {
      return 0;
    }
    if (bucket > 4) {
      return 4;
    }
    return bucket;
  }
}

class ViewportFeatureCache {
  layerId: string = '';
  envelope: GisEnvelope = new GisEnvelope(0, 0, 0, 0);
  features: GisFeatureSummary[] = [];
  hasMore: boolean = false;

  constructor(layerId: string, envelope: GisEnvelope, features: GisFeatureSummary[], hasMore: boolean) {
    this.layerId = layerId;
    this.envelope = envelope;
    this.features = features;
    this.hasMore = hasMore;
  }
}

// ---------------------------------------------------------------------------
// Map viewport state
// ---------------------------------------------------------------------------
export class MapViewport {
  centerX: number = 0.5;
  centerY: number = 0.5;
  displayLongitude: number = 0.5;
  displayLatitude: number = 0.5;
  displayCoordinateMode: number = 0;
  scale: number = 100.0;
  canvasWidth: number = 800;
  canvasHeight: number = 600;
  scaleLabel: string = 'CRS 未声明';

  private safeCanvasWidth(): number {
    if (this.canvasWidth < 1) {
      return 1;
    }
    return this.canvasWidth;
  }

  private safeCanvasHeight(): number {
    if (this.canvasHeight < 1) {
      return 1;
    }
    return this.canvasHeight;
  }

  getMapUnitsPerPixel(): number {
    if (this.scale < 0.000000001) {
      return 1000000000;
    }
    return 1.0 / this.scale;
  }

  clampScale(): void {
    if (this.scale < 0.000000001) {
      this.scale = 0.000000001;
    }
    if (this.scale > 1000000000) {
      this.scale = 1000000000;
    }
  }

  clone(): MapViewport {
    let result = new MapViewport();
    result.centerX = this.centerX;
    result.centerY = this.centerY;
    result.displayLongitude = this.displayLongitude;
    result.displayLatitude = this.displayLatitude;
    result.displayCoordinateMode = this.displayCoordinateMode;
    result.scale = this.scale;
    result.canvasWidth = this.canvasWidth;
    result.canvasHeight = this.canvasHeight;
    result.scaleLabel = this.scaleLabel;
    return result;
  }

  // Convert data coordinates to canvas pixels
  dataToCanvasX(dataX: number): number {
    return this.safeCanvasWidth() / 2 + (dataX - this.centerX) * this.scale;
  }

  dataToCanvasY(dataY: number): number {
    return this.safeCanvasHeight() / 2 - (dataY - this.centerY) * this.scale;
  }

  canvasToDataX(canvasX: number): number {
    return this.centerX + (canvasX - this.safeCanvasWidth() / 2) / this.scale;
  }

  canvasToDataY(canvasY: number): number {
    return this.centerY - (canvasY - this.safeCanvasHeight() / 2) / this.scale;
  }

  getVisibleEnvelope(): GisEnvelope {
    let halfWidth = this.safeCanvasWidth() / (2 * this.scale);
    let halfHeight = this.safeCanvasHeight() / (2 * this.scale);
    let env: GisEnvelope = new GisEnvelope(this.centerX - halfWidth, this.centerY - halfHeight,
      this.centerX + halfWidth, this.centerY + halfHeight);
    return env;
  }

  // Auto-fit viewport to a data envelope with 10% padding
  fitToEnvelope(minX: number, minY: number, maxX: number, maxY: number): void {
    let dx = maxX - minX;
    let dy = maxY - minY;
    if (dx < 0.0001) dx = 0.0001;
    if (dy < 0.0001) dy = 0.0001;
    let padX = dx * 0.1;
    let padY = dy * 0.1;
    dx += padX * 2;
    dy += padY * 2;
    this.centerX = minX - padX + dx / 2;
    this.centerY = minY - padY + dy / 2;
    let scaleX = this.safeCanvasWidth() / dx;
    let scaleY = this.safeCanvasHeight() / dy;
    this.scale = Math.min(scaleX, scaleY);
    this.clampScale();
    hilog.info(TAG, DOMAIN, 'fitToEnvelope: center=%{public}s,%{public}s scale=%{public}s',
      this.centerX.toFixed(2), this.centerY.toFixed(2), this.scale.toFixed(4));
  }
}

// ---------------------------------------------------------------------------
// Feature hit-test result
// ---------------------------------------------------------------------------
export class HitTestResult {
  featureId: string = '';
  layerIndex: number = -1;
  found: boolean = false;

  constructor(featureId: string, layerIndex: number, found: boolean) {
    this.featureId = featureId;
    this.layerIndex = layerIndex;
    this.found = found;
  }
}

// ---------------------------------------------------------------------------
// GisMapCanvas: renders GIS features on an ArkUI Canvas
// ---------------------------------------------------------------------------
@Component
export struct GisMapCanvas {
  @Prop layers: GisLoadedLayer[] = [];
  @Prop @Watch('onBasemapModeChanged') basemapMode: number = BASEMAP_VECTOR;
  @Prop @Watch('onBasemapDatumModeChanged') basemapDatumMode: number = BASEMAP_DATUM_AUTO;
  @Prop selectedFeatureId: string = '';
  @Prop selectedFeatureIds: string[] = [];
  @Prop selectedFeatureLayerIndex: number = -1;
  @Prop @Watch('onDataChanged') renderKey: number = 0;
  @Prop mapCommand: number = MAP_COMMAND_NONE;
  @Prop @Watch('onMapCommandChanged') mapCommandKey: number = 0;
  @Prop @Watch('onMapToolChanged') mapToolMode: number = MAP_TOOL_IDENTIFY;
  @Prop editLayerIndex: number = -1;
  @Prop renderQuality: number = 1;
  @Prop framePacing: number = 1;
  @Prop cacheStrategy: number = 1;
  @Prop progressiveLoading: boolean = true;
  @Prop pointerSmoothing: boolean = true;
  @Prop @Watch('onExternalViewportChanged') externalViewportKey: number = 0;
  @Prop externalViewportCenterX: number = 0.5;
  @Prop externalViewportCenterY: number = 0.5;
  @Prop externalViewportScale: number = 100.0;
  @Prop crossLayerSelection: boolean = true;
  @State viewport: MapViewport = new MapViewport();
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  onFeatureSelected: (featureId: string, layerIndex: number, operation: number) => void =
    (_featureId: string, _layerIndex: number, _operation: number): void => {};
  onViewportChanged: (viewport: MapViewport) => void = () => {};
  onMeasurementChanged: (summary: string) => void = () => {};
  onEditFeedback: (summary: string, shouldToast: boolean) => void =
    (_summary: string, _shouldToast: boolean): void => {};
  onBasemapStatusChanged: (summary: string) => void = () => {};
  onSketchFeatureCreated: (geometryType: number, points: GisCoordinate[]) => void = () => {};
  onSelectionGeometryCompleted: (selectionWkt: string, crossLayers: boolean) => void =
    (_selectionWkt: string, _crossLayers: boolean): void => {};
  onCutSketchCompleted: (points: GisCoordinate[]) => void = () => {};
  onNodeEditRequested: (editMode: number, layerIndex: number, featureId: string, partIndex: number,
    pointIndex: number, mapX: number, mapY: number) => void = () => {};
  private tileWebController: webview.WebviewController = new webview.WebviewController();
  private tilePageReady: boolean = false;
  private harmonyMapController?: map.MapComponentController;
  private harmonyMapEventManager?: map.MapEventManager;
  private harmonyMapReady: boolean = false;
  private harmonyMapLoaded: boolean = false;
  private harmonyMapEventsRegistered: boolean = false;
  private harmonyMapPageVisible: boolean = false;
  private harmonyMapLoadTimer: number = -1;
  private externalBasemapFailed: boolean = false;
  private lastBasemapStatus: string = '';
  private harmonyMapCallback: AsyncCallback<map.MapComponentController> =
    (err, mapController): void => {
      if (err) {
        this.clearHarmonyMapLoadTimer();
        this.harmonyMapController = undefined;
        this.harmonyMapEventManager = undefined;
        this.harmonyMapReady = false;
        this.harmonyMapLoaded = false;
        this.harmonyMapEventsRegistered = false;
        this.externalBasemapFailed = true;
        this.updateBasemapStatus('花瓣地图初始化失败：' + err.code.toString());
        hilog.error(TAG, DOMAIN, 'Harmony map init failed: %{public}d, %{public}s', err.code, err.message);
        this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
        return;
      }
      this.harmonyMapController = mapController;
      this.harmonyMapEventManager = mapController.getEventManager();
      this.harmonyMapReady = true;
      this.harmonyMapLoaded = false;
      this.harmonyMapEventsRegistered = false;
      this.externalBasemapFailed = false;
      this.updateBasemapStatus('花瓣地图组件已创建，等待底图加载');
      this.registerHarmonyMapEvents();
      this.scheduleHarmonyMapLoadWatchdog();
      if (this.harmonyMapPageVisible && this.usesHarmonyBasemap()) {
        this.safeShowHarmonyMap();
        if (!this.externalBasemapFailed) {
          this.syncHarmonyBasemap();
        }
      }
    };

  private updateBasemapStatus(summary: string): void {
    if (this.lastBasemapStatus === summary) {
      return;
    }
    this.lastBasemapStatus = summary;
    this.onBasemapStatusChanged(summary);
  }

  private markHarmonyMapDisplayed(status: string): void {
    this.clearHarmonyMapLoadTimer();
    this.harmonyMapLoaded = true;
    this.externalBasemapFailed = false;
    this.updateBasemapStatus(status);
  }

  private reportHarmonyMapError(statusPrefix: string, logPrefix: string, error: BusinessError): void {
    this.harmonyMapLoaded = false;
    this.externalBasemapFailed = true;
    this.updateBasemapStatus(statusPrefix + error.code.toString());
    hilog.error(TAG, DOMAIN, '%{public}s: %{public}d, %{public}s', logPrefix, error.code, error.message);
    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
  }

  private registerHarmonyMapEvents(): void {
    if (this.harmonyMapEventManager === undefined || this.harmonyMapEventsRegistered) {
      return;
    }
    try {
      this.harmonyMapEventManager.on('error', (mapError: BusinessError): void => {
        this.reportHarmonyMapError('花瓣地图运行错误：', 'Harmony map runtime error', mapError);
      });
      this.harmonyMapEventManager.on('mapLoad', (): void => {
        this.onHarmonyMapLoaded();
      });
      this.harmonyMapEventsRegistered = true;
    } catch (e) {
      let error = e as BusinessError;
      this.reportHarmonyMapError('花瓣地图事件注册失败：', 'Harmony map event register failed', error);
    }
  }

  private onHarmonyMapLoaded(): void {
    this.markHarmonyMapDisplayed('花瓣地图已加载');
    this.configureHarmonyMapController();
    this.syncHarmonyBasemap();
  }

  private configureHarmonyMapController(): void {
    if (this.harmonyMapController === undefined) {
      return;
    }
    try {
      this.harmonyMapController.setBuildingEnabled(true);
      this.harmonyMapController.setAllGesturesEnabled(false);
    } catch (e) {
      let error = e as BusinessError;
      this.reportHarmonyMapError('花瓣地图配置失败：', 'Harmony map configure failed', error);
    }
  }

  private safeShowHarmonyMap(): void {
    if (!this.usesHarmonyBasemap() || this.harmonyMapController === undefined) {
      return;
    }
    try {
      this.harmonyMapController.show();
      if (!this.harmonyMapLoaded) {
        this.markHarmonyMapDisplayed('花瓣地图已显示');
      }
    } catch (e) {
      let error = e as BusinessError;
      this.reportHarmonyMapError('花瓣地图显示失败：', 'Harmony map show failed', error);
    }
  }

  private safeHideHarmonyMap(): void {
    if (this.harmonyMapController === undefined) {
      return;
    }
    try {
      this.harmonyMapController.hide();
    } catch (e) {
      let error = e as BusinessError;
      hilog.warn(TAG, DOMAIN, 'Harmony map hide failed: %{public}d, %{public}s', error.code, error.message);
    }
  }

  private scheduleHarmonyMapLoadWatchdog(): void {
    this.clearHarmonyMapLoadTimer();
    this.harmonyMapLoadTimer = setTimeout(() => {
      this.onHarmonyMapLoadTimeout();
    }, HARMONY_MAP_LOAD_TIMEOUT_MS);
  }

  private clearHarmonyMapLoadTimer(): void {
    if (this.harmonyMapLoadTimer >= 0) {
      clearTimeout(this.harmonyMapLoadTimer);
      this.harmonyMapLoadTimer = -1;
    }
  }

  private onHarmonyMapLoadTimeout(): void {
    this.harmonyMapLoadTimer = -1;
    if (!this.usesHarmonyBasemap() || !this.harmonyMapReady || this.harmonyMapLoaded) {
      return;
    }
    if (this.harmonyMapController !== undefined) {
      this.markHarmonyMapDisplayed('花瓣地图已显示');
      this.syncHarmonyBasemap();
      return;
    }
    this.externalBasemapFailed = true;
    this.updateBasemapStatus('花瓣地图未加载：请检查 AGC Map Kit 授权和签名 Profile');
    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
  }

  private resetHarmonyMapController(): void {
    this.clearHarmonyMapLoadTimer();
    this.harmonyMapController = undefined;
    this.harmonyMapEventManager = undefined;
    this.harmonyMapReady = false;
    this.harmonyMapLoaded = false;
    this.harmonyMapEventsRegistered = false;
    this.externalBasemapFailed = false;
  }
  private lastPanX: number = 0;
  private lastPanY: number = 0;
  private lastPanDx: number = 0;
  private lastPanDy: number = 0;
  private lastInteractiveRenderTimestamp: number = 0;
  private isPanning: boolean = false;
  private isPinching: boolean = false;
  private isMiddleButtonPanning: boolean = false;
  private middlePanStartX: number = 0;
  private middlePanStartY: number = 0;
  private middlePanStartCenterX: number = 0;
  private middlePanStartCenterY: number = 0;
  private lastWheelZoomX: number = 0;
  private lastWheelZoomY: number = 0;
  private rasterBitmap?: ImageBitmap;
  private rasterBitmapPath: string = '';
  private rasterRenderKey: string = '';
  private rasterRenderSerial: number = 0;
  private viewportFeatureCaches: ViewportFeatureCache[] = [];
  private canvasReady: boolean = false;
  private dataFitted: boolean = false;
  private lastExternalViewportKey: number = 0;
  private measurementPoints: GisCoordinate[] = [];
  private sketchPoints: GisCoordinate[] = [];
  private selectionPoints: GisCoordinate[] = [];
  private movingNodeHit: EditNodeHit = new EditNodeHit(false, -1, '', -1, -1);

  private interactiveFrameInterval(): number {
    if (this.framePacing === 0) {
      return 33;
    }
    if (this.framePacing === 2) {
      return 11;
    }
    return 16;
  }

  private shouldRenderInteractiveFrame(timestamp: number): boolean {
    if (this.lastInteractiveRenderTimestamp === 0 ||
      timestamp - this.lastInteractiveRenderTimestamp >= this.interactiveFrameInterval()) {
      this.lastInteractiveRenderTimestamp = timestamp;
      return true;
    }
    return false;
  }

  private webCacheMode(): CacheMode {
    if (this.cacheStrategy === 0) {
      return CacheMode.Online;
    }
    if (this.cacheStrategy === 2) {
      return CacheMode.None;
    }
    return CacheMode.Default;
  }

  aboutToAppear(): void {
    this.harmonyMapPageVisible = true;
    this.safeShowHarmonyMap();
    if (!this.externalBasemapFailed) {
      this.syncHarmonyBasemap();
    }
  }

  aboutToDisappear(): void {
    this.harmonyMapPageVisible = false;
    this.clearHarmonyMapLoadTimer();
    this.safeHideHarmonyMap();
  }

  onPageShow(): void {
    this.harmonyMapPageVisible = true;
    this.safeShowHarmonyMap();
    if (this.usesHarmonyBasemap() && this.harmonyMapReady && !this.harmonyMapLoaded) {
      this.scheduleHarmonyMapLoadWatchdog();
    }
    if (!this.externalBasemapFailed) {
      this.syncHarmonyBasemap();
    }
  }

  onPageHide(): void {
    this.harmonyMapPageVisible = false;
    this.clearHarmonyMapLoadTimer();
    this.safeHideHarmonyMap();
  }

  @Builder
  harmonyMapDiagnosticOverlay() {
    Row() {
      Text(this.harmonyMapDiagnosticText())
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.externalBasemapFailed ? $r('app.color.gn_red_700') : $r('app.color.gn_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(34)
    .width('82%')
    .padding({ left: 12, right: 12 })
    .backgroundColor($r('app.color.gn_paper'))
    .borderRadius(12)
    .border({
      width: 1,
      color: this.externalBasemapFailed ? $r('app.color.gn_red_700') : $r('app.color.gn_line')
    })
    .shadow({ radius: 10, color: '#1A000000', offsetX: 0, offsetY: 4 })
    .position({ x: 14, y: 14 })
    .zIndex(2)
  }

  // ---------------------------------------------------------------------------
  // Drawing helpers
  // ---------------------------------------------------------------------------

  private addLayerPathToCanvas(ctx: CanvasRenderingContext2D, layer: GisLoadedLayer, points: GisCoordinate[],
    closePath: boolean, minimumPoints: number): boolean {
    let validCount = 0;
    let pathStarted = false;
    for (let ci = 0; ci < points.length; ci++) {
      let coord = points[ci];
      let displayCoord = this.coordinateToDisplay(layer, coord.x, coord.y);
      if (displayCoord === undefined) {
        continue;
      }
      let px = this.viewport.dataToCanvasX(displayCoord.x);
      let py = this.viewport.dataToCanvasY(displayCoord.y);
      if (!pathStarted) {
        ctx.moveTo(px, py);
        pathStarted = true;
      } else {
        ctx.lineTo(px, py);
      }
      validCount++;
    }
    if (validCount < minimumPoints) {
      return false;
    }
    if (closePath) {
      ctx.closePath();
    }
    return true;
  }

  private drawPointFeature(ctx: CanvasRenderingContext2D, layer: GisLoadedLayer, feature: GisFeatureSummary,
    color: string,
    radius: number, selected: boolean): void {
    let geom = feature.geometry;
    if (geom.parts.length === 0 && geom.geometryType === GEOM_POINT) {
      // Point geometry has no parts, use direct coordinates from parts[0]
      return;
    }
    // For point features, parts[0].points contains the point coordinates
    for (let pi = 0; pi < geom.parts.length; pi++) {
      let part = geom.parts[pi];
      for (let ci = 0; ci < part.points.length; ci++) {
        let coord = part.points[ci];
        let displayCoord = this.coordinateToDisplay(layer, coord.x, coord.y);
        if (displayCoord === undefined) {
          continue;
        }
        let px = this.viewport.dataToCanvasX(displayCoord.x);
        let py = this.viewport.dataToCanvasY(displayCoord.y);

        if (selected) {
          ctx.beginPath();
          ctx.arc(px, py, radius + 4, 0, Math.PI * 2);
          ctx.strokeStyle = '#1D4F91';
          ctx.lineWidth = 3;
          ctx.stroke();
        }

        ctx.beginPath();
        ctx.arc(px, py, radius, 0, Math.PI * 2);
        ctx.fillStyle = color;
        ctx.fill();
        ctx.strokeStyle = '#FFFFFF';
        ctx.lineWidth = 1.5;
        ctx.stroke();
      }
    }
  }

  private drawLineFeature(ctx: CanvasRenderingContext2D, layer: GisLoadedLayer, feature: GisFeatureSummary,
    color: string,
    lineWidth: number, selected: boolean): void {
    let geom = feature.geometry;
    for (let pi = 0; pi < geom.parts.length; pi++) {
      let part = geom.parts[pi];
      if (part.points.length < 2) {
        continue;
      }

      if (selected) {
        ctx.beginPath();
        if (!this.addLayerPathToCanvas(ctx, layer, part.points, false, 2)) {
          continue;
        }
        ctx.strokeStyle = '#1D4F91';
        ctx.lineWidth = lineWidth + 4;
        ctx.lineJoin = 'round';
        ctx.stroke();
      }

      ctx.beginPath();
      if (!this.addLayerPathToCanvas(ctx, layer, part.points, false, 2)) {
        continue;
      }
      ctx.strokeStyle = color;
      ctx.lineWidth = lineWidth;
      ctx.lineJoin = 'round';
      ctx.stroke();
    }
  }

  private drawPolygonFeature(ctx: CanvasRenderingContext2D, layer: GisLoadedLayer, feature: GisFeatureSummary,
    fillColor: string,
    strokeColor: string, selected: boolean): void {
    let geom = feature.geometry;
    for (let pi = 0; pi < geom.parts.length; pi++) {
      let part = geom.parts[pi];
      if (part.points.length < 3) {
        continue;
      }

      ctx.beginPath();
      if (!this.addLayerPathToCanvas(ctx, layer, part.points, true, 3)) {
        continue;
      }

      ctx.fillStyle = selected ? '#8EC4AA' : fillColor;
      ctx.fill();

      ctx.strokeStyle = selected ? '#1D4F91' : strokeColor;
      ctx.lineWidth = selected ? 2.5 : 1.2;
      ctx.stroke();
    }
  }

  private attrText(feature: GisFeatureSummary, fieldName: string): string {
    if (fieldName.length === 0) {
      return '';
    }
    for (let i = 0; i < feature.attributesPreview.length; i++) {
      let attr = feature.attributesPreview[i];
      if (attr.name === fieldName) {
        if (attr.isNull) {
          return '';
        }
        if (attr.textValue.length > 0) {
          return attr.textValue;
        }
        return attr.numberValue.toString();
      }
    }
    return '';
  }

  private hasAttributeField(feature: GisFeatureSummary, fieldName: string): boolean {
    if (fieldName.length === 0) {
      return false;
    }
    for (let i = 0; i < feature.attributesPreview.length; i++) {
      if (feature.attributesPreview[i].name === fieldName) {
        return true;
      }
    }
    return false;
  }

  private attributeDisplayText(attr: GisAttributeValue): string {
    if (attr.isNull) {
      return '';
    }
    if (attr.textValue.length > 0) {
      return attr.textValue;
    }
    let typeName = attr.typeName.toLowerCase();
    if (typeName.indexOf('bool') >= 0) {
      return attr.boolValue ? 'true' : 'false';
    }
    if (typeName.indexOf('int') >= 0 || typeName.indexOf('real') >= 0 || typeName.indexOf('double') >= 0 ||
      typeName.indexOf('float') >= 0 || typeName.indexOf('number') >= 0 || typeName.indexOf('numeric') >= 0) {
      return attr.numberValue.toString();
    }
    return '';
  }

  private fallbackLabelText(feature: GisFeatureSummary): string {
    for (let i = 0; i < feature.attributesPreview.length; i++) {
      let text = this.attributeDisplayText(feature.attributesPreview[i]);
      if (text.length > 0) {
        return text;
      }
    }
    return feature.featureId;
  }

  private featureLabelText(layer: GisLoadedLayer, feature: GisFeatureSummary): string {
    if (layer.style.labelField.length > 0) {
      if (layer.style.labelField.startsWith('expr:')) {
        let expressionText = layer.style.labelField.substring(5).trim();
        let expressionLabel = this.simpleExpressionLabelText(feature, expressionText);
        if (expressionLabel.length > 0) {
          return expressionLabel;
        }
      }
      let text = this.attrText(feature, layer.style.labelField);
      if (text.length > 0) {
        return text;
      }
      if (this.hasAttributeField(feature, layer.style.labelField)) {
        return '';
      }
    }
    return this.fallbackLabelText(feature);
  }

  private safeLabelSize(size: number): number {
    if (size !== size || size < 8) {
      return 12;
    }
    if (size > 48) {
      return 48;
    }
    return size;
  }

  private expressionFieldName(token: string): string {
    let text = token.trim();
    if (text.length >= 2 && text.charAt(0) === '"' && text.charAt(text.length - 1) === '"') {
      return text.substring(1, text.length - 1);
    }
    if (text.length >= 2 && text.charAt(0) === '[' && text.charAt(text.length - 1) === ']') {
      return text.substring(1, text.length - 1);
    }
    if (text.length > 0 && text.charAt(0) !== '\'' && text.charAt(0) !== '$') {
      let value = Number(text);
      if (value !== value) {
        return text;
      }
    }
    return '';
  }

  private buildLayerRenderStats(layer: GisLoadedLayer): LayerRenderStats {
    let stats = new LayerRenderStats();
    if (layer.style.rendererField.length === 0) {
      return stats;
    }
    if (layer.style.rendererMode === 1) {
      for (let i = 0; i < layer.features.length; i++) {
        let value = this.attrText(layer.features[i], layer.style.rendererField);
        let exists = false;
        for (let j = 0; j < stats.categoryValues.length; j++) {
          if (stats.categoryValues[j] === value) {
            exists = true;
            break;
          }
        }
        if (!exists) {
          stats.categoryValues.push(value);
          if (stats.categoryValues.length >= 12) {
            break;
          }
        }
      }
      return stats;
    }
    if (layer.style.rendererMode === 2) {
      for (let i = 0; i < layer.features.length; i++) {
        let text = this.attrText(layer.features[i], layer.style.rendererField);
        if (text.length === 0) {
          continue;
        }
        let value = Number(text);
        if (value !== value) {
          continue;
        }
        if (!stats.hasNumericRange) {
          stats.minValue = value;
          stats.maxValue = value;
          stats.hasNumericRange = true;
        } else {
          if (value < stats.minValue) {
            stats.minValue = value;
          }
          if (value > stats.maxValue) {
            stats.maxValue = value;
          }
        }
      }
    }
    return stats;
  }

  private expressionLiteralText(token: string): string {
    let text = token.trim();
    if (text.length >= 2 && text.charAt(0) === '\'' && text.charAt(text.length - 1) === '\'') {
      return text.substring(1, text.length - 1);
    }
    if (text.length >= 2 && text.charAt(0) === '"' && text.charAt(text.length - 1) === '"') {
      return text.substring(1, text.length - 1);
    }
    return text;
  }

  private expressionValueText(feature: GisFeatureSummary, token: string): string {
    let fieldName = this.expressionFieldName(token);
    if (fieldName.length > 0 && this.hasAttributeField(feature, fieldName)) {
      return this.attrText(feature, fieldName);
    }
    return this.expressionLiteralText(token);
  }

  private featureMetricValue(feature: GisFeatureSummary, token: string): number {
    let cleanToken = token.trim().toLowerCase();
    let width = Math.abs(feature.envelope.maxX - feature.envelope.minX);
    let height = Math.abs(feature.envelope.maxY - feature.envelope.minY);
    if (cleanToken === '$area' || cleanToken === 'area($geometry)') {
      return width * height;
    }
    if (cleanToken === '$length' || cleanToken === 'length($geometry)') {
      return width + height;
    }
    return Number(this.expressionValueText(feature, token));
  }

  private compareExpressionValues(feature: GisFeatureSummary, left: string, operatorText: string,
    right: string): boolean {
    let leftText = this.expressionValueText(feature, left);
    let rightText = this.expressionValueText(feature, right);
    let leftNumber = this.featureMetricValue(feature, left);
    let rightNumber = this.featureMetricValue(feature, right);
    let numericCompare = leftNumber === leftNumber && rightNumber === rightNumber;
    if (operatorText === '=' || operatorText === '==') {
      if (numericCompare) {
        return Math.abs(leftNumber - rightNumber) < 0.0000001;
      }
      return leftText === rightText;
    }
    if (operatorText === '!=' || operatorText === '<>') {
      if (numericCompare) {
        return Math.abs(leftNumber - rightNumber) >= 0.0000001;
      }
      return leftText !== rightText;
    }
    if (!numericCompare) {
      return false;
    }
    if (operatorText === '>') {
      return leftNumber > rightNumber;
    }
    if (operatorText === '>=') {
      return leftNumber >= rightNumber;
    }
    if (operatorText === '<') {
      return leftNumber < rightNumber;
    }
    if (operatorText === '<=') {
      return leftNumber <= rightNumber;
    }
    return false;
  }

  private simpleExpressionMatches(feature: GisFeatureSummary, expressionText: string): boolean {
    let expression = expressionText.trim();
    let lower = expression.toLowerCase();
    if (lower === 'true' || lower === '1=1' || lower === '1 = 1') {
      return true;
    }
    if (lower === 'false' || lower === '1=0' || lower === '1 = 0') {
      return false;
    }
    let isNotNullIndex = lower.indexOf(' is not null');
    if (isNotNullIndex > 0) {
      let fieldName = this.expressionFieldName(expression.substring(0, isNotNullIndex));
      return fieldName.length > 0 && this.hasAttributeField(feature, fieldName) &&
        this.attrText(feature, fieldName).length > 0;
    }
    let isNullIndex = lower.indexOf(' is null');
    if (isNullIndex > 0) {
      let fieldName = this.expressionFieldName(expression.substring(0, isNullIndex));
      return fieldName.length > 0 && (!this.hasAttributeField(feature, fieldName) ||
        this.attrText(feature, fieldName).length === 0);
    }
    let operators: string[] = ['>=', '<=', '!=', '<>', '==', '=', '>', '<'];
    for (let i = 0; i < operators.length; i++) {
      let operatorText = operators[i];
      let operatorIndex = expression.indexOf(operatorText);
      if (operatorIndex > 0) {
        let left = expression.substring(0, operatorIndex);
        let right = expression.substring(operatorIndex + operatorText.length);
        return this.compareExpressionValues(feature, left, operatorText, right);
      }
    }
    return false;
  }

  private simpleExpressionLabelText(feature: GisFeatureSummary, expressionText: string): string {
    let expression = expressionText.trim();
    if (expression.length === 0) {
      return '';
    }
    let pieces: string[] = expression.split('||');
    if (pieces.length > 1) {
      let result = '';
      for (let i = 0; i < pieces.length; i++) {
        result += this.expressionValueText(feature, pieces[i]);
      }
      return result;
    }
    return this.expressionValueText(feature, expression);
  }

  private featureRenderColor(layer: GisLoadedLayer, feature: GisFeatureSummary, baseColor: string,
    stats: LayerRenderStats): string {
    if (layer.style.rendererMode === 1 && layer.style.rendererField.length > 0) {
      let value = this.attrText(feature, layer.style.rendererField);
      return qgisRampColor(layer.style.colorRamp, stats.categoryBucket(value), stats.categoryTotal());
    }
    if (layer.style.rendererMode === 2 && layer.style.rendererField.length > 0) {
      let text = this.attrText(feature, layer.style.rendererField);
      if (text.length === 0) {
        return baseColor;
      }
      let value = Number(text);
      if (value === value) {
        return qgisRampColor(layer.style.colorRamp, stats.graduatedBucket(value), 5);
      }
    }
    if (layer.style.rendererMode === 3 && layer.style.rendererField.length > 0) {
      if (this.simpleExpressionMatches(feature, layer.style.rendererField)) {
        return qgisRampColor(layer.style.colorRamp, 0, 2);
      }
      return qgisRampColor(layer.style.colorRamp, 1, 2);
    }
    return baseColor;
  }

  private featureCenterX(feature: GisFeatureSummary): number {
    return (feature.envelope.minX + feature.envelope.maxX) / 2.0;
  }

  private featureCenterY(feature: GisFeatureSummary): number {
    return (feature.envelope.minY + feature.envelope.maxY) / 2.0;
  }

  private featureCenterDisplay(layer: GisLoadedLayer, feature: GisFeatureSummary): GisCoordinate | undefined {
    return this.coordinateToDisplay(layer, this.featureCenterX(feature), this.featureCenterY(feature));
  }

  private drawFeatureLabel(ctx: CanvasRenderingContext2D, layer: GisLoadedLayer, feature: GisFeatureSummary): void {
    if (!layer.style.labelEnabled) {
      return;
    }
    let text = this.featureLabelText(layer, feature);
    if (text.length === 0) {
      return;
    }
    let center = this.featureCenterDisplay(layer, feature);
    if (center === undefined) {
      return;
    }
    let px = this.viewport.dataToCanvasX(center.x);
    let py = this.viewport.dataToCanvasY(center.y);
    let labelSize = this.safeLabelSize(layer.style.labelSize);
    ctx.font = labelSize.toString() + 'px sans-serif';
    if (layer.style.labelHalo) {
      ctx.fillStyle = '#FFFFFF';
      ctx.fillText(text, px + 1, py);
      ctx.fillText(text, px - 1, py);
      ctx.fillText(text, px, py + 1);
      ctx.fillText(text, px, py - 1);
    }
    ctx.fillStyle = layer.style.labelColor;
    ctx.fillText(text, px, py);
  }

  private isFeatureSelected(featureId: string, layerIndex: number): boolean {
    if (layerIndex !== this.selectedFeatureLayerIndex) {
      return false;
    }
    for (let i = 0; i < this.selectedFeatureIds.length; i++) {
      if (this.selectedFeatureIds[i] === featureId) {
        return true;
      }
    }
    return false;
  }

  private shouldUseNativeVectorRender(layer: GisLoadedLayer): boolean {
    return !this.isRasterLayer(layer) && layer.info.featureCount > NATIVE_VECTOR_RENDER_THRESHOLD;
  }

  private nativeVectorRenderAvailable(layer: GisLoadedLayer): boolean {
    return this.shouldUseNativeVectorRender(layer) && this.rasterBitmap !== undefined &&
      this.rasterRenderKey.length > 0;
  }

  private viewportCacheIndex(layerId: string): number {
    for (let i = 0; i < this.viewportFeatureCaches.length; i++) {
      if (this.viewportFeatureCaches[i].layerId === layerId) {
        return i;
      }
    }
    return -1;
  }

  private interactionFeaturesForLayer(layerIndex: number): GisFeatureSummary[] {
    if (layerIndex < 0 || layerIndex >= this.layers.length) {
      return [];
    }
    let layer = this.layers[layerIndex];
    if (!this.shouldUseNativeVectorRender(layer)) {
      return layer.features;
    }
    let cacheIndex = this.viewportCacheIndex(layer.info.layerId);
    if (cacheIndex >= 0) {
      return this.viewportFeatureCaches[cacheIndex].features;
    }
    return layer.features;
  }

  private featureByIdForLayer(layerIndex: number, featureId: string): GisFeatureSummary | undefined {
    if (layerIndex < 0 || layerIndex >= this.layers.length || featureId.length === 0) {
      return undefined;
    }
    let interactionFeatures = this.interactionFeaturesForLayer(layerIndex);
    for (let i = 0; i < interactionFeatures.length; i++) {
      if (interactionFeatures[i].featureId === featureId) {
        return interactionFeatures[i];
      }
    }
    let feature = getGisService().getLayerFeatureById(layerIndex, featureId);
    if (feature === undefined) {
      return undefined;
    }
    let layer = this.layers[layerIndex];
    if (this.shouldUseNativeVectorRender(layer)) {
      let features: GisFeatureSummary[] = [];
      features.push(feature);
      let page = new GisFeaturePage(layer.info.layerId, features, false);
      this.mergeViewportFeaturePage(layer, feature.envelope, page);
    }
    return feature;
  }

  private displayEnvelopeToLayerEnvelope(layer: GisLoadedLayer,
    displayEnvelope: GisEnvelope): GisEnvelope | undefined {
    if (!this.usesExternalBasemap()) {
      return displayEnvelope;
    }
    let low = this.webMercatorToLonLat(new GisCoordinate(displayEnvelope.minX, displayEnvelope.minY, 0, false));
    let high = this.webMercatorToLonLat(new GisCoordinate(displayEnvelope.maxX, displayEnvelope.maxY, 0, false));
    let lonLatEnvelope = new GisEnvelope(Math.min(low.x, high.x), Math.min(low.y, high.y),
      Math.max(low.x, high.x), Math.max(low.y, high.y));
    if (layer.info.coordinateUnitType === UNIT_ANGULAR || layer.info.crs.length === 0) {
      return lonLatEnvelope;
    }
    let transformResult: GisEnvelopeTransformResult =
      getGisService().transformEnvelope('EPSG:4326', layer.info.crs, lonLatEnvelope);
    if (!transformResult.ok) {
      return undefined;
    }
    return transformResult.envelope;
  }

  private expandedDisplayEnvelope(pixelPadding: number): GisEnvelope {
    let envelope = this.viewport.getVisibleEnvelope();
    let padding = pixelPadding / Math.max(this.viewport.scale, 0.000000001);
    return new GisEnvelope(envelope.minX - padding, envelope.minY - padding,
      envelope.maxX + padding, envelope.maxY + padding);
  }

  private pointDisplayEnvelope(canvasX: number, canvasY: number, pixelTolerance: number): GisEnvelope {
    let centerX = this.viewport.canvasToDataX(canvasX);
    let centerY = this.viewport.canvasToDataY(canvasY);
    let padding = pixelTolerance / Math.max(this.viewport.scale, 0.000000001);
    return new GisEnvelope(centerX - padding, centerY - padding, centerX + padding, centerY + padding);
  }

  private storeViewportFeaturePage(layer: GisLoadedLayer, envelope: GisEnvelope, page: GisFeaturePage): void {
    let cache = new ViewportFeatureCache(layer.info.layerId, envelope, page.features, page.hasMore);
    let cacheIndex = this.viewportCacheIndex(layer.info.layerId);
    if (cacheIndex >= 0) {
      this.viewportFeatureCaches[cacheIndex] = cache;
    } else {
      this.viewportFeatureCaches.push(cache);
    }
  }

  private mergeViewportFeaturePage(layer: GisLoadedLayer, envelope: GisEnvelope, page: GisFeaturePage): void {
    let cacheIndex = this.viewportCacheIndex(layer.info.layerId);
    if (cacheIndex < 0) {
      this.storeViewportFeaturePage(layer, envelope, page);
      return;
    }
    let cache = this.viewportFeatureCaches[cacheIndex];
    for (let i = 0; i < page.features.length; i++) {
      let candidate = page.features[i];
      let exists = false;
      for (let j = 0; j < cache.features.length; j++) {
        if (cache.features[j].featureId === candidate.featureId) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        cache.features.push(candidate);
      }
    }
  }

  private refreshViewportFeatureCache(): void {
    if (!this.canvasReady) {
      return;
    }
    let displayEnvelope = this.expandedDisplayEnvelope(48.0);
    for (let i = 0; i < this.layers.length; i++) {
      let layer = this.layers[i];
      if (!layer.visible || !this.shouldUseNativeVectorRender(layer)) {
        continue;
      }
      let queryEnvelope = this.displayEnvelopeToLayerEnvelope(layer, displayEnvelope);
      if (queryEnvelope === undefined) {
        continue;
      }
      let page = getGisService().queryLayerFeatures(i, queryEnvelope, VIEWPORT_INTERACTION_LIMIT, 0);
      if (page !== undefined) {
        this.storeViewportFeaturePage(layer, queryEnvelope, page);
      }
    }
  }

  private refreshInteractionFeaturesNearPoint(canvasX: number, canvasY: number): void {
    let displayEnvelope = this.pointDisplayEnvelope(canvasX, canvasY, 14.0);
    for (let i = 0; i < this.layers.length; i++) {
      let layer = this.layers[i];
      if (!layer.visible || !this.shouldUseNativeVectorRender(layer)) {
        continue;
      }
      let queryEnvelope = this.displayEnvelopeToLayerEnvelope(layer, displayEnvelope);
      if (queryEnvelope === undefined) {
        continue;
      }
      let page = getGisService().queryLayerFeatures(i, queryEnvelope, POINT_QUERY_LIMIT, 0);
      if (page !== undefined) {
        this.mergeViewportFeaturePage(layer, queryEnvelope, page);
      }
    }
  }

  private featureIntersectsViewport(layer: GisLoadedLayer, feature: GisFeatureSummary,
    visibleEnvelope: GisEnvelope): boolean {
    let displayEnvelope = this.envelopeToDisplay(layer, feature.envelope);
    if (displayEnvelope === undefined) {
      return false;
    }
    let padding = 12.0 / Math.max(this.viewport.scale, 0.000000001);
    return displayEnvelope.maxX >= visibleEnvelope.minX - padding &&
      displayEnvelope.minX <= visibleEnvelope.maxX + padding &&
      displayEnvelope.maxY >= visibleEnvelope.minY - padding &&
      displayEnvelope.minY <= visibleEnvelope.maxY + padding;
  }

  // ---------------------------------------------------------------------------
  // Main render
  // ---------------------------------------------------------------------------

  private renderMap(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    // Update viewport dimensions
    this.viewport.canvasWidth = width;
    this.viewport.canvasHeight = height;

    // Clear with selected basemap.
    this.drawBasemap(ctx, width, height);

    this.drawNativeRasterView(ctx, width, height);

    // Efficient mode keeps the basemap and features, but omits the decorative grid.
    if (this.renderQuality !== 0) {
      this.drawGrid(ctx, width, height);
    }

    let visibleEnvelope = this.viewport.getVisibleEnvelope();

    // Draw layers back-to-front. Large vector layers are already present in the
    // native QGIS bitmap; Canvas only paints their selected interaction preview.
    for (let li = 0; li < this.layers.length; li++) {
      let layer = this.layers[li];
      if (!layer.visible) {
        continue;
      }

      let geomType = layer.info.geometryType;
      let nativeVectorLayer = this.nativeVectorRenderAvailable(layer);
      let renderStats = this.buildLayerRenderStats(layer);
      let interactionFeatures = this.interactionFeaturesForLayer(li);
      let previousAlpha = ctx.globalAlpha;
      ctx.globalAlpha = layer.style.opacity;

      let featureStep = this.progressiveLoading && this.isPanning ? 2 : 1;
      for (let fi = 0; fi < interactionFeatures.length; fi += featureStep) {
        let feature = interactionFeatures[fi];
        let isSelected = this.isFeatureSelected(feature.featureId, li);
        if (nativeVectorLayer && !isSelected) {
          continue;
        }
        if (!this.featureIntersectsViewport(layer, feature, visibleEnvelope)) {
          continue;
        }

        if (geomType === GEOM_POLYGON) {
          let fillColor = this.featureRenderColor(layer, feature, layer.style.fillColor, renderStats);
          this.drawPolygonFeature(ctx, layer, feature, fillColor, layer.style.strokeColor, isSelected);
        } else if (geomType === GEOM_LINESTRING) {
          let lineColor = this.featureRenderColor(layer, feature, layer.style.lineColor, renderStats);
          this.drawLineFeature(ctx, layer, feature, lineColor, layer.style.lineWidth, isSelected);
        } else if (geomType === GEOM_POINT) {
          let pointColor = this.featureRenderColor(layer, feature, layer.style.pointColor, renderStats);
          this.drawPointFeature(ctx, layer, feature, pointColor, layer.style.pointRadius, isSelected);
        }
      }
      ctx.globalAlpha = previousAlpha;

      if (!nativeVectorLayer && this.renderQuality !== 0 && (!this.isPanning || this.renderQuality === 2)) {
        let drawnLabels = 0;
        for (let labelIndex = 0; labelIndex < layer.features.length; labelIndex++) {
          let labelFeature = layer.features[labelIndex];
          if (!this.featureIntersectsViewport(layer, labelFeature, visibleEnvelope)) {
            continue;
          }
          this.drawFeatureLabel(ctx, layer, labelFeature);
          drawnLabels++;
          if (drawnLabels >= MAX_CANVAS_LABELS_PER_LAYER) {
            break;
          }
        }
      }
    }

    // Draw scale bar
    this.drawScaleBar(ctx, width, height);

    // Draw crosshair
    this.drawCrosshair(ctx, width, height);

    // Draw measurement overlay last.
    this.drawMeasurementOverlay(ctx);
    this.drawSelectionOverlay(ctx);

    // Draw edit sketches above measurement and feature graphics.
    this.drawEditOverlay(ctx);

    this.syncOnlineBasemap();
    this.syncHarmonyBasemap();
  }

  private isRasterLayer(layer: GisLoadedLayer): boolean {
    return layer.info.geometryType === GEOM_UNKNOWN && layer.info.fields.length === 0;
  }

  private visibleNativeRenderHandles(): string {
    let result: string = '';
    for (let i = 0; i < this.layers.length; i++) {
      let layer = this.layers[i];
      let nativeVectorLayer = this.shouldUseNativeVectorRender(layer);
      if (!layer.visible || (!this.isRasterLayer(layer) && !nativeVectorLayer) || layer.info.layerId.length <= 1) {
        continue;
      }
      if (result.length > 0) {
        result += ';';
      }
      result += layer.info.layerId.substring(1);
    }
    return result;
  }

  private rasterDestinationCrs(): string {
    if (this.usesExternalBasemap()) {
      return 'EPSG:3857';
    }
    return '';
  }

  private rasterViewOutputPath(): string {
    let ctx = getContext(this);
    let slot = this.rasterRenderSerial % 2;
    this.rasterRenderSerial++;
    return ctx.filesDir + '/geonest_raster_preview/map_view_' + slot.toString() + '.png';
  }

  private buildRasterRenderKey(handles: string, width: number, height: number, envelope: GisEnvelope,
    destinationCrs: string): string {
    return handles + ':' + this.renderKey.toString() + ':' + Math.round(width).toString() + 'x' +
      Math.round(height).toString() + ':' +
      envelope.minX.toFixed(6) + ',' + envelope.minY.toFixed(6) + ',' +
      envelope.maxX.toFixed(6) + ',' + envelope.maxY.toFixed(6) + ':' + destinationCrs;
  }

  private closeRasterBitmap(): void {
    if (this.rasterBitmap !== undefined) {
      try {
        this.rasterBitmap.close();
      } catch (e) {
      }
      this.rasterBitmap = undefined;
    }
    this.rasterBitmapPath = '';
  }

  private drawCachedRasterBitmap(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    if (this.rasterBitmap === undefined) {
      return;
    }
    try {
      ctx.drawImage(this.rasterBitmap, 0, 0, width, height);
    } catch (e) {
      this.closeRasterBitmap();
    }
  }

  private drawNativeRasterView(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    let handles = this.visibleNativeRenderHandles();
    if (handles.length === 0) {
      this.rasterRenderKey = '';
      this.closeRasterBitmap();
      return;
    }

    let envelope = this.viewport.getVisibleEnvelope();
    let destinationCrs = this.rasterDestinationCrs();
    let key = this.buildRasterRenderKey(handles, width, height, envelope, destinationCrs);
    if (key === this.rasterRenderKey && this.rasterBitmap !== undefined) {
      this.drawCachedRasterBitmap(ctx, width, height);
      return;
    }
    if ((this.isPanning || this.isMiddleButtonPanning || this.isPinching) && this.rasterBitmap !== undefined) {
      this.drawCachedRasterBitmap(ctx, width, height);
      return;
    }

    let outputPath = this.rasterViewOutputPath();
    let result: GisGeoProcessResult = getGisService().renderMapView(outputPath, envelope.minX, envelope.minY,
      envelope.maxX, envelope.maxY, Math.round(width), Math.round(height), handles, destinationCrs);
    if (!result.ok) {
      this.rasterRenderKey = '';
      hilog.warn(TAG, DOMAIN, 'Native map render failed: %{public}s', result.message);
      this.drawCachedRasterBitmap(ctx, width, height);
      return;
    }

    this.closeRasterBitmap();
    try {
      this.rasterBitmap = new ImageBitmap(outputPath);
      this.rasterBitmapPath = outputPath;
      this.rasterRenderKey = key;
      this.drawCachedRasterBitmap(ctx, width, height);
    } catch (e) {
      this.rasterRenderKey = '';
      this.rasterBitmapPath = '';
      hilog.warn(TAG, DOMAIN, 'Failed to load rendered raster bitmap');
    }
  }

  private usesTileBasemap(): boolean {
    return this.basemapMode === BASEMAP_ONLINE_STANDARD || this.basemapMode === BASEMAP_TERRAIN ||
      this.basemapMode === BASEMAP_IMAGERY;
  }

  private usesHarmonyBasemap(): boolean {
    return this.basemapMode === BASEMAP_HARMONY_STANDARD || this.basemapMode === BASEMAP_HARMONY_TERRAIN ||
      this.basemapMode === BASEMAP_HARMONY_IMAGERY;
  }

  private usesExternalBasemap(): boolean {
    return this.usesTileBasemap() || this.usesHarmonyBasemap();
  }

  private coordinateToDisplay(layer: GisLoadedLayer, x: number, y: number): GisCoordinate | undefined {
    if (!this.usesExternalBasemap()) {
      return new GisCoordinate(x, y, 0, false);
    }
    let lonLat = this.coordinateToLonLat(layer, x, y);
    if (lonLat === undefined) {
      return undefined;
    }
    return this.lonLatToExternalDisplay(lonLat);
  }

  private envelopeToDisplay(layer: GisLoadedLayer, envelope: GisEnvelope): GisEnvelope | undefined {
    if (!this.usesExternalBasemap()) {
      return envelope;
    }
    if (layer.info.coordinateUnitType === UNIT_ANGULAR) {
      let lonLatEnvelope = new GisEnvelope(this.clampLongitude(envelope.minX), this.clampLatitude(envelope.minY),
        this.clampLongitude(envelope.maxX), this.clampLatitude(envelope.maxY));
      return this.lonLatEnvelopeToExternalDisplay(lonLatEnvelope);
    }
    if (layer.info.crs.length > 0) {
      let transformResult: GisEnvelopeTransformResult =
        getGisService().transformEnvelope(layer.info.crs, 'EPSG:4326', envelope);
      if (transformResult.ok) {
        return this.lonLatEnvelopeToExternalDisplay(transformResult.envelope);
      }
    }
    return undefined;
  }

  private lonLatEnvelopeToExternalDisplay(envelope: GisEnvelope): GisEnvelope {
    let p0 = this.lonLatToExternalDisplay(new GisCoordinate(this.clampLongitude(envelope.minX),
      this.clampLatitude(envelope.minY), 0, false));
    let p1 = this.lonLatToExternalDisplay(new GisCoordinate(this.clampLongitude(envelope.minX),
      this.clampLatitude(envelope.maxY), 0, false));
    let p2 = this.lonLatToExternalDisplay(new GisCoordinate(this.clampLongitude(envelope.maxX),
      this.clampLatitude(envelope.minY), 0, false));
    let p3 = this.lonLatToExternalDisplay(new GisCoordinate(this.clampLongitude(envelope.maxX),
      this.clampLatitude(envelope.maxY), 0, false));
    let minX = Math.min(Math.min(p0.x, p1.x), Math.min(p2.x, p3.x));
    let minY = Math.min(Math.min(p0.y, p1.y), Math.min(p2.y, p3.y));
    let maxX = Math.max(Math.max(p0.x, p1.x), Math.max(p2.x, p3.x));
    let maxY = Math.max(Math.max(p0.y, p1.y), Math.max(p2.y, p3.y));
    return new GisEnvelope(minX, minY, maxX, maxY);
  }

  private lonLatToExternalDisplay(lonLat: GisCoordinate): GisCoordinate {
    let mapLonLat = this.lonLatToExternalMapDatum(lonLat);
    return this.lonLatToWebMercator(mapLonLat);
  }

  private lonLatToExternalMapDatum(lonLat: GisCoordinate): GisCoordinate {
    if (!this.needsHarmonyGcj02(lonLat.x, lonLat.y)) {
      return lonLat;
    }
    let input: mapCommon.LatLng = {
      longitude: lonLat.x,
      latitude: lonLat.y
    };
    try {
      let output: mapCommon.LatLng =
        map.convertCoordinateSync(mapCommon.CoordinateType.WGS84, mapCommon.CoordinateType.GCJ02, input);
      return new GisCoordinate(this.clampLongitude(output.longitude), this.clampLatitude(output.latitude), 0, false);
    } catch (e) {
      return lonLat;
    }
  }

  private clampWebMercatorLatitude(lat: number): number {
    if (lat < -WEB_MERCATOR_MAX_LATITUDE) {
      return -WEB_MERCATOR_MAX_LATITUDE;
    }
    if (lat > WEB_MERCATOR_MAX_LATITUDE) {
      return WEB_MERCATOR_MAX_LATITUDE;
    }
    return lat;
  }

  private lonLatToWebMercator(lonLat: GisCoordinate): GisCoordinate {
    let lon = this.clampLongitude(lonLat.x);
    let lat = this.clampWebMercatorLatitude(lonLat.y);
    let x = WEB_MERCATOR_RADIUS_METERS * this.degreesToRadians(lon);
    let latRad = this.degreesToRadians(lat);
    let y = WEB_MERCATOR_RADIUS_METERS * Math.log(Math.tan(Math.PI / 4.0 + latRad / 2.0));
    return new GisCoordinate(x, y, 0, false);
  }

  private webMercatorToLonLat(point: GisCoordinate): GisCoordinate {
    let lon = this.clampLongitude(point.x / WEB_MERCATOR_RADIUS_METERS * 180.0 / Math.PI);
    let lat = (2.0 * Math.atan(Math.exp(point.y / WEB_MERCATOR_RADIUS_METERS)) - Math.PI / 2.0) * 180.0 /
      Math.PI;
    return new GisCoordinate(lon, this.clampLatitude(lat), 0, false);
  }

  private needsHarmonyGcj02(lon: number, lat: number): boolean {
    if (this.basemapDatumMode === BASEMAP_DATUM_WGS84) {
      return false;
    }
    if (this.basemapDatumMode === BASEMAP_DATUM_AUTO && !this.usesHarmonyBasemap()) {
      return false;
    }
    if (lon < 72.0 || lon > 137.9 || lat < 0.8 || lat > 55.9) {
      return false;
    }
    if (lon >= 119.0 && lon <= 122.5 && lat >= 21.5 && lat <= 25.7) {
      return false;
    }
    return true;
  }

  private layerCanDrawOnExternalBasemap(layer: GisLoadedLayer): boolean {
    if (layer.info.coordinateUnitType === UNIT_ANGULAR) {
      return true;
    }
    return layer.info.crs.length > 0;
  }

  private hasVisibleLayerMissingExternalReference(): boolean {
    for (let i = 0; i < this.layers.length; i++) {
      let layer = this.layers[i];
      if (layer.visible && !this.layerCanDrawOnExternalBasemap(layer)) {
        return true;
      }
    }
    return false;
  }

  private displayCenterLonLat(): GisCoordinate {
    if (this.usesExternalBasemap()) {
      return this.webMercatorToLonLat(new GisCoordinate(this.viewport.centerX, this.viewport.centerY, 0, false));
    }
    return new GisCoordinate(this.clampLongitude(this.viewport.centerX), this.clampLatitude(this.viewport.centerY), 0,
      false);
  }

  private geographicMetersPerPixel(): number {
    let center = this.displayCenterLonLat();
    let mapUnitsPerPixel = this.viewport.getMapUnitsPerPixel();
    if (this.usesExternalBasemap()) {
      let cosLat = Math.cos(center.y * Math.PI / 180.0);
      if (cosLat < 0.1) {
        cosLat = 0.1;
      }
      return mapUnitsPerPixel * cosLat;
    }
    let eastLon = this.clampLongitude(center.x + mapUnitsPerPixel);
    return this.haversineMeters(center.x, center.y, eastLon, center.y);
  }

  private currentMetersPerPixel(layer: GisLoadedLayer): number {
    if (this.usesExternalBasemap()) {
      return this.geographicMetersPerPixel();
    }
    return this.metersPerPixel(layer);
  }

  private updateViewportDisplayCoordinate(): void {
    let center = this.displayCenterLonLat();
    this.viewport.displayLongitude = center.x;
    this.viewport.displayLatitude = center.y;
    this.viewport.displayCoordinateMode = this.usesExternalBasemap() ? 1 : 0;
  }

  private notifyViewportChanged(): void {
    this.refreshViewportFeatureCache();
    this.updateViewportDisplayCoordinate();
    this.updateScaleLabel();
    let viewportSnapshot = this.viewport.clone();
    setTimeout(() => {
      this.onViewportChanged(viewportSnapshot);
    }, 0);
  }

  private applyExternalViewportIfNeeded(): void {
    if (!this.canvasReady) {
      return;
    }
    if (this.externalViewportKey === this.lastExternalViewportKey) {
      return;
    }
    if (this.externalViewportScale <= 0.000000001) {
      return;
    }
    this.lastExternalViewportKey = this.externalViewportKey;
    this.viewport.centerX = this.externalViewportCenterX;
    this.viewport.centerY = this.externalViewportCenterY;
    this.viewport.scale = this.externalViewportScale;
    this.viewport.clampScale();
    this.updateViewportDisplayCoordinate();
    this.updateScaleLabel();
    this.syncOnlineBasemap();
    this.syncHarmonyBasemap();
    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
  }

  private onExternalViewportChanged(): void {
    this.applyExternalViewportIfNeeded();
  }

  private shouldShowHarmonyMapDiagnostic(): boolean {
    if (!this.usesHarmonyBasemap()) {
      return false;
    }
    return this.externalBasemapFailed && !this.harmonyMapLoaded;
  }

  private harmonyMapDiagnosticText(): string {
    if (this.externalBasemapFailed && this.lastBasemapStatus.length > 0) {
      return this.lastBasemapStatus;
    }
    if (!this.harmonyMapReady) {
      return '花瓣地图初始化中';
    }
    if (!this.harmonyMapLoaded) {
      return '花瓣地图组件已创建，等待底图加载';
    }
    return this.lastBasemapStatus;
  }

  private onlineBasemapProviderKey(): string {
    if (this.basemapMode === BASEMAP_TERRAIN) {
      return 'topo';
    }
    if (this.basemapMode === BASEMAP_IMAGERY) {
      return 'voyager';
    }
    return 'positron';
  }

  private clampLongitude(lon: number): number {
    let value = lon;
    while (value < -180.0) {
      value += 360.0;
    }
    while (value > 180.0) {
      value -= 360.0;
    }
    return value;
  }

  private clampLatitude(lat: number): number {
    if (lat < -85.0) {
      return -85.0;
    }
    if (lat > 85.0) {
      return 85.0;
    }
    return lat;
  }

  private defaultOnlineCenter(): GisCoordinate {
    let center = new GisCoordinate(112.55, 37.87, 0, false);
    return this.lonLatToExternalMapDatum(center);
  }

  private defaultExternalDisplayCenter(): GisCoordinate {
    return this.lonLatToExternalDisplay(new GisCoordinate(112.55, 37.87, 0, false));
  }

  private projectedViewportCenter(first: GisLoadedLayer): GisCoordinate {
    if (this.usesExternalBasemap()) {
      return this.displayCenterLonLat();
    }
    if (first.info.crs.length > 0 && first.info.coordinateUnitType !== UNIT_ANGULAR) {
      let transformResult: GisCoordinateTransformResult =
        getGisService().transformCoordinate(first.info.crs, 'EPSG:4326', this.viewport.centerX, this.viewport.centerY);
      if (transformResult.ok) {
        return new GisCoordinate(this.clampLongitude(transformResult.x), this.clampLatitude(transformResult.y), 0,
          false);
      }
    }
    if (first.info.coordinateUnitType === UNIT_ANGULAR) {
      return new GisCoordinate(this.clampLongitude(this.viewport.centerX), this.clampLatitude(this.viewport.centerY),
        0, false);
    }
    return this.defaultOnlineCenter();
  }

  private onlineCenter(): GisCoordinate {
    let first = this.getFirstVisibleLayer();
    if (first === undefined) {
      return this.defaultOnlineCenter();
    }
    return this.projectedViewportCenter(first);
  }

  private onlineZoom(centerLat: number): number {
    let first = this.getFirstVisibleLayer();
    let zoom = 4.0;
    if (first !== undefined || this.usesExternalBasemap()) {
      let metersPerPixel = 0.0;
      if (this.usesExternalBasemap()) {
        metersPerPixel = this.viewport.getMapUnitsPerPixel();
      } else if (first !== undefined) {
        metersPerPixel = this.metersPerPixel(first);
      }
      let cosLat = 1.0;
      if (!this.usesExternalBasemap()) {
        cosLat = Math.cos(centerLat * Math.PI / 180.0);
        if (cosLat < 0.1) {
          cosLat = 0.1;
        }
      }
      if (metersPerPixel > 0.0) {
        zoom = Math.log(WEB_MERCATOR_METERS_PER_PIXEL_Z0 * cosLat / metersPerPixel) / 0.6931471805599453;
      }
    } else if (this.viewport.scale > 0.0) {
      zoom = Math.log(this.viewport.scale * 360.0 / 256.0) / 0.6931471805599453;
    }
    if (zoom < 1.0) {
      return 1.0;
    }
    if (zoom > 18.0) {
      return 18.0;
    }
    return zoom;
  }

  private syncOnlineBasemap(): void {
    if (!this.usesTileBasemap() || !this.tilePageReady) {
      return;
    }
    let center = this.onlineCenter();
    let zoom = this.onlineZoom(center.y);
    let script = 'window.GeoNestTiles&&window.GeoNestTiles.setView(' + center.x.toString() + ',' +
      center.y.toString() + ',' + zoom.toString() + ',"' + this.onlineBasemapProviderKey() + '");';
    this.tileWebController.runJavaScript(script).catch(() => {
      hilog.warn(TAG, DOMAIN, 'syncOnlineBasemap: runJavaScript failed');
    });
  }

  private harmonyMapType(): mapCommon.MapType {
    if (this.basemapMode === BASEMAP_HARMONY_TERRAIN) {
      return mapCommon.MapType.TERRAIN;
    }
    if (this.basemapMode === BASEMAP_HARMONY_IMAGERY) {
      return mapCommon.MapType.HYBRID;
    }
    return mapCommon.MapType.STANDARD;
  }

  private harmonyZoom(centerLat: number): number {
    let zoom = this.onlineZoom(centerLat);
    if (zoom < 2.0) {
      return 2.0;
    }
    if (zoom > 20.0) {
      return 20.0;
    }
    return zoom;
  }

  private harmonyCameraPosition(): mapCommon.CameraPosition {
    let center = this.onlineCenter();
    let target: mapCommon.LatLng = {
      longitude: center.x,
      latitude: center.y
    };
    let cameraPosition: mapCommon.CameraPosition = {
      target: target,
      zoom: this.harmonyZoom(center.y),
      tilt: 0,
      bearing: 0
    };
    return cameraPosition;
  }

  private createHarmonyMapOptions(): mapCommon.MapOptions {
    let options: mapCommon.MapOptions = {
      mapType: this.harmonyMapType(),
      position: this.harmonyCameraPosition(),
      minZoom: 2,
      maxZoom: 20,
      rotateGesturesEnabled: false,
      scrollGesturesEnabled: false,
      zoomGesturesEnabled: false,
      tiltGesturesEnabled: false,
      zoomControlsEnabled: false,
      myLocationControlsEnabled: false,
      compassControlsEnabled: false,
      scaleControlsEnabled: false,
      dayNightMode: mapCommon.DayNightMode.DAY
    };
    return options;
  }

  private syncHarmonyBasemap(): void {
    if (!this.usesHarmonyBasemap() || !this.harmonyMapReady || this.harmonyMapController === undefined) {
      return;
    }
    let cameraPosition: mapCommon.CameraPosition = this.harmonyCameraPosition();
    try {
      this.harmonyMapController.setMapType(this.harmonyMapType());
      this.harmonyMapController.moveCamera(map.newCameraPosition(cameraPosition));
      if (!this.harmonyMapLoaded) {
        this.markHarmonyMapDisplayed('花瓣地图已显示');
      }
    } catch (e) {
      let error = e as BusinessError;
      this.reportHarmonyMapError('花瓣地图同步失败：', 'Harmony map sync failed', error);
    }
  }

  private getFirstVisibleLayer(): GisLoadedLayer | undefined {
    for (let i = 0; i < this.layers.length; i++) {
      if (this.layers[i].visible) {
        return this.layers[i];
      }
    }
    return undefined;
  }

  private hasMixedVisibleReference(): boolean {
    let first = this.getFirstVisibleLayer();
    if (first === undefined) {
      return false;
    }
    let baseCrs = first.info.crs;
    let baseUnitName = first.info.coordinateUnitName;
    let baseUnitType = first.info.coordinateUnitType;
    for (let i = 0; i < this.layers.length; i++) {
      let layer = this.layers[i];
      if (layer.visible) {
        if (layer.info.crs !== baseCrs || layer.info.coordinateUnitName !== baseUnitName ||
          layer.info.coordinateUnitType !== baseUnitType) {
          return true;
        }
      }
    }
    return false;
  }

  private canDrawCoordinateScale(): boolean {
    let first = this.getFirstVisibleLayer();
    if (first === undefined) {
      return false;
    }
    if (this.usesExternalBasemap()) {
      return this.geographicMetersPerPixel() > 0.0;
    }
    if (this.hasMixedVisibleReference()) {
      return false;
    }
    return first.info.coordinateUnitType !== UNIT_UNKNOWN && first.info.coordinateUnitName.length > 0;
  }

  private unitLabel(layer: GisLoadedLayer): string {
    let unitName = layer.info.coordinateUnitName;
    let lowerName = unitName.toLowerCase();
    if (layer.info.coordinateUnitType === UNIT_ANGULAR && lowerName.indexOf('degree') >= 0) {
      return '°';
    }
    if (layer.info.coordinateUnitType === UNIT_LINEAR) {
      if (lowerName === 'metre' || lowerName === 'meter' || lowerName === 'metre (1.0)' ||
        lowerName === 'meter (1.0)') {
        return 'm';
      }
    }
    return unitName;
  }

  private unitToMetersFactor(layer: GisLoadedLayer): number {
    let lowerName = layer.info.coordinateUnitName.toLowerCase();
    if (lowerName === 'meters' || lowerName === 'meter' || lowerName === 'metres' || lowerName === 'metre' ||
      lowerName === 'meter (1.0)' || lowerName === 'metre (1.0)') {
      return 1.0;
    }
    if (lowerName === 'kilometers' || lowerName === 'kilometer' || lowerName === 'kilometres' ||
      lowerName === 'kilometre') {
      return 1000.0;
    }
    if (lowerName === 'feet') {
      return 0.3048;
    }
    if (lowerName === 'yards') {
      return 0.9144;
    }
    if (lowerName === 'miles') {
      return 1609.344;
    }
    if (lowerName === 'nautical miles') {
      return 1852.0;
    }
    if (lowerName === 'centimeters' || lowerName === 'centimetres') {
      return 0.01;
    }
    if (lowerName === 'millimeters' || lowerName === 'millimetres') {
      return 0.001;
    }
    if (lowerName === 'inches') {
      return 0.0254;
    }
    if (lowerName === 'chains') {
      return 20.1168;
    }
    if (lowerName === 'links') {
      return 0.201168;
    }
    if (lowerName === 'fathoms') {
      return 1.8288;
    }
    return 0.0;
  }

  private coordinateToLonLat(layer: GisLoadedLayer, x: number, y: number): GisCoordinate | undefined {
    if (layer.info.coordinateUnitType === UNIT_ANGULAR) {
      return new GisCoordinate(this.clampLongitude(x), this.clampLatitude(y), 0, false);
    }
    if (layer.info.crs.length > 0) {
      let transformResult: GisCoordinateTransformResult =
        getGisService().transformCoordinate(layer.info.crs, 'EPSG:4326', x, y);
      if (transformResult.ok) {
        return new GisCoordinate(this.clampLongitude(transformResult.x), this.clampLatitude(transformResult.y), 0,
          false);
      }
    }
    return undefined;
  }

  private degreesToRadians(value: number): number {
    return value * Math.PI / 180.0;
  }

  private haversineMeters(lon0: number, lat0: number, lon1: number, lat1: number): number {
    let lat0Rad = this.degreesToRadians(lat0);
    let lat1Rad = this.degreesToRadians(lat1);
    let dLat = this.degreesToRadians(lat1 - lat0);
    let dLon = this.degreesToRadians(lon1 - lon0);
    let sinLat = Math.sin(dLat / 2.0);
    let sinLon = Math.sin(dLon / 2.0);
    let a = sinLat * sinLat + Math.cos(lat0Rad) * Math.cos(lat1Rad) * sinLon * sinLon;
    if (a > 1.0) {
      a = 1.0;
    }
    return 2.0 * EARTH_RADIUS_METERS * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));
  }

  private metersPerPixel(layer: GisLoadedLayer): number {
    let mapUnitsPerPixel = this.viewport.getMapUnitsPerPixel();
    let centerLonLat = this.coordinateToLonLat(layer, this.viewport.centerX, this.viewport.centerY);
    let eastLonLat = this.coordinateToLonLat(layer, this.viewport.centerX + mapUnitsPerPixel, this.viewport.centerY);
    if (centerLonLat !== undefined && eastLonLat !== undefined) {
      let geodesicMeters = this.haversineMeters(centerLonLat.x, centerLonLat.y, eastLonLat.x, eastLonLat.y);
      if (geodesicMeters > 0.0) {
        return geodesicMeters;
      }
    }
    if (layer.info.coordinateUnitType === UNIT_LINEAR) {
      let factor = this.unitToMetersFactor(layer);
      if (factor > 0.0) {
        return mapUnitsPerPixel * factor;
      }
    }
    return 0.0;
  }

  private metricDistanceLabel(distanceMeters: number): string {
    if (distanceMeters >= 1000.0) {
      return this.numberLabel(distanceMeters / 1000.0) + ' km';
    }
    return this.numberLabel(distanceMeters) + ' m';
  }

  private metricAreaLabel(areaSquareMeters: number): string {
    if (areaSquareMeters >= 1000000.0) {
      return this.numberLabel(areaSquareMeters / 1000000.0) + ' km²';
    }
    return this.numberLabel(areaSquareMeters) + ' m²';
  }

  private formatIntegerWithCommas(value: number): string {
    let text = Math.round(value).toString();
    let result = '';
    let count = 0;
    for (let i = text.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 === 0) {
        result = ',' + result;
      }
      result = text.charAt(i) + result;
      count++;
    }
    return result;
  }

  private lonLatLabel(lon: number, lat: number): string {
    let lonSuffix = lon >= 0.0 ? 'E' : 'W';
    let latSuffix = lat >= 0.0 ? 'N' : 'S';
    return Math.abs(lon).toFixed(6) + '°' + lonSuffix + ' ' + Math.abs(lat).toFixed(6) + '°' + latSuffix;
  }

  private scaleDenominatorLabel(metersPerPixelValue: number): string {
    if (metersPerPixelValue <= 0.0) {
      return this.referenceNoticeText();
    }
    let denominator = metersPerPixelValue / SCREEN_PIXEL_SIZE_METERS;
    if (denominator < 1.0) {
      denominator = 1.0;
    }
    return '1:' + this.formatIntegerWithCommas(denominator);
  }

  private niceCoordinateDistance(rawDistance: number): number {
    if (rawDistance <= 0) {
      return 0;
    }
    let normalized = rawDistance;
    let multiplier = 1.0;
    while (normalized >= 10.0) {
      normalized = normalized / 10.0;
      multiplier = multiplier * 10.0;
    }
    while (normalized < 1.0) {
      normalized = normalized * 10.0;
      multiplier = multiplier / 10.0;
    }
    if (normalized >= 5.0) {
      return 5.0 * multiplier;
    }
    if (normalized >= 2.0) {
      return 2.0 * multiplier;
    }
    return multiplier;
  }

  private numberLabel(value: number): string {
    if (value >= 1000.0) {
      return value.toFixed(0);
    }
    if (value >= 100.0) {
      return value.toFixed(1);
    }
    if (value >= 10.0) {
      return value.toFixed(2);
    }
    if (value >= 1.0) {
      return value.toFixed(3);
    }
    return value.toFixed(6);
  }

  private coordinateDistanceLabel(distance: number, layer: GisLoadedLayer): string {
    let label = this.unitLabel(layer);
    if (layer.info.coordinateUnitType === UNIT_LINEAR && label === 'm' && distance >= 1000.0) {
      return this.numberLabel(distance / 1000.0) + ' km';
    }
    if (label.length === 0) {
      return this.numberLabel(distance) + ' 坐标单位';
    }
    return this.numberLabel(distance) + ' ' + label;
  }

  private referenceNoticeText(): string {
    let first = this.getFirstVisibleLayer();
    if (first === undefined) {
      return '无可见图层';
    }
    if (this.usesExternalBasemap()) {
      if (!this.layerCanDrawOnExternalBasemap(first)) {
        return '在线底图叠加需要先定义图层 CRS';
      }
      if (this.hasVisibleLayerMissingExternalReference()) {
        return '部分图层缺少 CRS，未参与在线叠加';
      }
      if (this.usesHarmonyBasemap()) {
        if (this.basemapDatumMode === BASEMAP_DATUM_WGS84) {
          return '花瓣底图叠加 · 原始/WGS84 · Web Mercator';
        }
        if (this.basemapDatumMode === BASEMAP_DATUM_GCJ02) {
          return '花瓣底图叠加 · WGS84→GCJ-02 · Web Mercator';
        }
        return '花瓣底图叠加 · 自动坐标 · Web Mercator';
      }
      if (this.basemapDatumMode === BASEMAP_DATUM_GCJ02) {
        return '在线底图叠加 · WGS84→GCJ-02 · Web Mercator';
      }
      return '在线底图叠加 · WGS84 · Web Mercator';
    }
    if (this.hasMixedVisibleReference()) {
      return '可见图层 CRS 不一致';
    }
    if (first.info.crs.length === 0) {
      return 'CRS 未声明';
    }
    if (first.info.coordinateUnitType === UNIT_UNKNOWN) {
      return first.info.crs + ' · 单位未声明';
    }
    return first.info.crs + ' · ' + first.info.coordinateUnitName;
  }

  private drawBasemap(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    if (this.usesExternalBasemap()) {
      if (this.externalBasemapFailed) {
        ctx.fillStyle = '#F7F9FB';
        ctx.fillRect(0, 0, width, height);
      } else {
        ctx.clearRect(0, 0, width, height);
      }
      return;
    }

    if (this.basemapMode === BASEMAP_IMAGERY) {
      ctx.fillStyle = '#2F3B42';
      ctx.fillRect(0, 0, width, height);
      let block = 96;
      for (let x = 0; x < width + block; x += block) {
        for (let y = 0; y < height + block; y += block) {
          let seed = (x / block + y / block) % 4;
          if (seed === 0) {
            ctx.fillStyle = '#36464A';
          } else if (seed === 1) {
            ctx.fillStyle = '#253237';
          } else if (seed === 2) {
            ctx.fillStyle = '#44513F';
          } else {
            ctx.fillStyle = '#2B3A3E';
          }
          ctx.fillRect(x, y, block, block);
        }
      }
      ctx.fillStyle = '#1F3E55';
      ctx.globalAlpha = 0.28;
      ctx.beginPath();
      ctx.moveTo(0, height * 0.62);
      ctx.bezierCurveTo(width * 0.24, height * 0.48, width * 0.42, height * 0.78, width, height * 0.54);
      ctx.lineTo(width, height);
      ctx.lineTo(0, height);
      ctx.closePath();
      ctx.fill();
      ctx.globalAlpha = 1.0;
      return;
    }

    if (this.basemapMode === BASEMAP_TERRAIN) {
      ctx.fillStyle = '#F4F1E8';
      ctx.fillRect(0, 0, width, height);
      for (let i = 0; i < 12; i++) {
        let y = 40 + i * 54;
        ctx.strokeStyle = i % 2 === 0 ? '#C7B98A' : '#AFC4A2';
        ctx.lineWidth = 1.0;
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.bezierCurveTo(width * 0.25, y - 34, width * 0.55, y + 34, width, y - 12);
        ctx.stroke();
      }
      ctx.fillStyle = '#DDE7C9';
      ctx.globalAlpha = 0.45;
      ctx.beginPath();
      ctx.moveTo(0, height * 0.72);
      ctx.bezierCurveTo(width * 0.35, height * 0.58, width * 0.56, height * 0.84, width, height * 0.68);
      ctx.lineTo(width, height);
      ctx.lineTo(0, height);
      ctx.closePath();
      ctx.fill();
      ctx.globalAlpha = 1.0;
      return;
    }

    ctx.fillStyle = '#FBFCFD';
    ctx.fillRect(0, 0, width, height);
  }

  private updateScaleLabel(): void {
    let first = this.getFirstVisibleLayer();
    if (first === undefined || !this.canDrawCoordinateScale()) {
      this.viewport.scaleLabel = this.referenceNoticeText();
      return;
    }
    let metersPerPixelValue = this.currentMetersPerPixel(first);
    if (metersPerPixelValue > 0.0) {
      this.viewport.scaleLabel = this.scaleDenominatorLabel(metersPerPixelValue) + ' · 每像素 ' +
        this.metricDistanceLabel(metersPerPixelValue);
      return;
    }
    this.viewport.scaleLabel = '每像素 ' + this.coordinateDistanceLabel(this.viewport.getMapUnitsPerPixel(), first);
  }

  private drawGrid(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    if (this.usesExternalBasemap()) {
      ctx.strokeStyle = '#FFFFFF5C';
    } else if (this.basemapMode === BASEMAP_IMAGERY) {
      ctx.strokeStyle = '#FFFFFF1F';
    } else if (this.basemapMode === BASEMAP_TERRAIN) {
      ctx.strokeStyle = '#B8AA7A66';
    } else {
      ctx.strokeStyle = '#E8EDEA';
    }
    ctx.lineWidth = 0.5;
    let step = Math.max(40, Math.floor(width / 20));

    for (let x = 0; x < width; x += step) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, height);
      ctx.stroke();
    }
    for (let y = 0; y < height; y += step) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }
  }

  private drawScaleBar(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    this.updateScaleLabel();
    let first = this.getFirstVisibleLayer();
    if (first === undefined || !this.canDrawCoordinateScale()) {
      ctx.font = '11px sans-serif';
      ctx.fillStyle = '#66736D';
      ctx.fillText(this.referenceNoticeText(), 16, height - 16);
      return;
    }
    let targetWidth = Math.min(140, Math.max(80, width * 0.22));
    let metersPerPixelValue = this.currentMetersPerPixel(first);
    let barDistance = 0.0;
    let barWidth = 0.0;
    let scaleText = '';
    if (metersPerPixelValue > 0.0) {
      barDistance = this.niceCoordinateDistance(targetWidth * metersPerPixelValue);
      barWidth = barDistance / metersPerPixelValue;
      scaleText = this.metricDistanceLabel(barDistance);
    } else {
      barDistance = this.niceCoordinateDistance(targetWidth / this.viewport.scale);
      barWidth = barDistance * this.viewport.scale;
      scaleText = this.coordinateDistanceLabel(barDistance, first);
    }
    if (barWidth < 1) {
      return;
    }
    let barHeight = 4;
    let x = width - barWidth - 16;
    let y = height - 24;

    ctx.fillStyle = '#17201D';
    ctx.fillRect(x, y, barWidth, barHeight);

    ctx.fillStyle = '#FBFCFD';
    for (let i = 0; i < barWidth; i += 20) {
      ctx.fillRect(x + i, y, 10, barHeight);
    }

    ctx.font = '11px sans-serif';
    ctx.fillStyle = '#66736D';
    ctx.fillText(scaleText, x, y - 6);
  }

  private drawCrosshair(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    let cx = width / 2;
    let cy = height / 2;
    let size = 8;

    ctx.strokeStyle = '#1D4F9180';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(cx - size, cy);
    ctx.lineTo(cx + size, cy);
    ctx.moveTo(cx, cy - size);
    ctx.lineTo(cx, cy + size);
    ctx.stroke();
  }

  private measurementModeText(): string {
    if (this.mapToolMode === MAP_TOOL_MEASURE_DISTANCE) {
      return '距离';
    }
    if (this.mapToolMode === MAP_TOOL_MEASURE_AREA) {
      return '面积';
    }
    if (this.mapToolMode === MAP_TOOL_MEASURE_ANGLE) {
      return '角度';
    }
    if (this.mapToolMode === MAP_TOOL_PICK_COORDINATE) {
      return '坐标';
    }
    return '';
  }

  private isMeasurementTool(): boolean {
    return this.mapToolMode === MAP_TOOL_MEASURE_DISTANCE || this.mapToolMode === MAP_TOOL_MEASURE_AREA ||
      this.mapToolMode === MAP_TOOL_MEASURE_ANGLE || this.mapToolMode === MAP_TOOL_PICK_COORDINATE;
  }

  private isEditTool(): boolean {
    return this.mapToolMode === MAP_TOOL_EDIT_ADD_POINT || this.mapToolMode === MAP_TOOL_EDIT_ADD_LINE ||
      this.mapToolMode === MAP_TOOL_EDIT_ADD_POLYGON || this.mapToolMode === MAP_TOOL_EDIT_MOVE_NODE ||
      this.mapToolMode === MAP_TOOL_EDIT_DELETE_NODE || this.mapToolMode === MAP_TOOL_EDIT_CUT_SKETCH ||
      this.mapToolMode === MAP_TOOL_EDIT_TRACE || this.mapToolMode === MAP_TOOL_EDIT_PARALLEL ||
      this.mapToolMode === MAP_TOOL_EDIT_PERPENDICULAR || this.mapToolMode === MAP_TOOL_EDIT_ORTHOGONAL;
  }

  private editModeText(): string {
    if (this.mapToolMode === MAP_TOOL_EDIT_ADD_POINT) {
      return '新增点';
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_ADD_LINE) {
      return '新增线';
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_ADD_POLYGON) {
      return '新增面';
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_MOVE_NODE) {
      return '移动节点';
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_DELETE_NODE) {
      return '删除节点';
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_CUT_SKETCH) {
      return '自由草图切割';
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_TRACE) {
      return '追踪绘制';
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_PARALLEL) {
      return '平行线';
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_PERPENDICULAR) {
      return '垂线';
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_ORTHOGONAL) {
      return '正交约束';
    }
    return '';
  }

  private editGeometryType(): number {
    if (this.mapToolMode === MAP_TOOL_EDIT_ADD_POINT) {
      return GEOM_POINT;
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_ADD_LINE || this.mapToolMode === MAP_TOOL_EDIT_CUT_SKETCH ||
      this.mapToolMode === MAP_TOOL_EDIT_TRACE || this.mapToolMode === MAP_TOOL_EDIT_PARALLEL ||
      this.mapToolMode === MAP_TOOL_EDIT_PERPENDICULAR || this.mapToolMode === MAP_TOOL_EDIT_ORTHOGONAL) {
      return GEOM_LINESTRING;
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_ADD_POLYGON) {
      return GEOM_POLYGON;
    }
    return 0;
  }

  private requiredSketchPointCount(): number {
    if (this.mapToolMode === MAP_TOOL_EDIT_ADD_POINT) {
      return 1;
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_ADD_LINE || this.mapToolMode === MAP_TOOL_EDIT_CUT_SKETCH ||
      this.mapToolMode === MAP_TOOL_EDIT_TRACE || this.mapToolMode === MAP_TOOL_EDIT_PARALLEL ||
      this.mapToolMode === MAP_TOOL_EDIT_PERPENDICULAR || this.mapToolMode === MAP_TOOL_EDIT_ORTHOGONAL) {
      return 2;
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_ADD_POLYGON) {
      return 3;
    }
    return 0;
  }

  private measurementDistance(): number {
    let distance = 0.0;
    for (let i = 1; i < this.measurementPoints.length; i++) {
      let p0 = this.measurementPoints[i - 1];
      let p1 = this.measurementPoints[i];
      let dx = p1.x - p0.x;
      let dy = p1.y - p0.y;
      distance += Math.sqrt(dx * dx + dy * dy);
    }
    return distance;
  }

  private measurementArea(): number {
    if (this.measurementPoints.length < 3) {
      return 0.0;
    }
    let sum = 0.0;
    for (let i = 0; i < this.measurementPoints.length; i++) {
      let nextIndex = i + 1;
      if (nextIndex >= this.measurementPoints.length) {
        nextIndex = 0;
      }
      let p0 = this.measurementPoints[i];
      let p1 = this.measurementPoints[nextIndex];
      sum += p0.x * p1.y - p1.x * p0.y;
    }
    return Math.abs(sum) / 2.0;
  }

  private measurementPointToLonLat(layer: GisLoadedLayer, point: GisCoordinate): GisCoordinate | undefined {
    if (this.usesExternalBasemap()) {
      return this.webMercatorToLonLat(point);
    }
    return this.coordinateToLonLat(layer, point.x, point.y);
  }

  private measurementDistanceGeodesicMeters(layer: GisLoadedLayer): number {
    if (this.measurementPoints.length < 2) {
      return 0.0;
    }
    let distance = 0.0;
    let previous: GisCoordinate | undefined = undefined;
    for (let i = 0; i < this.measurementPoints.length; i++) {
      let point = this.measurementPoints[i];
      let lonLat = this.measurementPointToLonLat(layer, point);
      if (lonLat === undefined) {
        return 0.0;
      }
      if (previous !== undefined) {
        distance += this.haversineMeters(previous.x, previous.y, lonLat.x, lonLat.y);
      }
      previous = lonLat;
    }
    return distance;
  }

  private measurementAreaGeodesicSquareMeters(layer: GisLoadedLayer): number {
    if (this.measurementPoints.length < 3) {
      return 0.0;
    }
    let lonLatPoints: GisCoordinate[] = [];
    for (let i = 0; i < this.measurementPoints.length; i++) {
      let point = this.measurementPoints[i];
      let lonLat = this.measurementPointToLonLat(layer, point);
      if (lonLat === undefined) {
        return 0.0;
      }
      lonLatPoints.push(lonLat);
    }
    let lon0 = lonLatPoints[0].x;
    let latSum = 0.0;
    for (let j = 0; j < lonLatPoints.length; j++) {
      latSum += lonLatPoints[j].y;
    }
    let lat0 = latSum / lonLatPoints.length;
    let metersPerDegreeLon = this.haversineMeters(lon0, lat0, lon0 + 1.0, lat0);
    let metersPerDegreeLat = this.haversineMeters(lon0, lat0, lon0, lat0 + 1.0);
    if (metersPerDegreeLon <= 0.0 || metersPerDegreeLat <= 0.0) {
      return 0.0;
    }
    let sum = 0.0;
    for (let k = 0; k < lonLatPoints.length; k++) {
      let nextIndex = k + 1;
      if (nextIndex >= lonLatPoints.length) {
        nextIndex = 0;
      }
      let p0 = lonLatPoints[k];
      let p1 = lonLatPoints[nextIndex];
      let x0 = (p0.x - lon0) * metersPerDegreeLon;
      let y0 = (p0.y - lat0) * metersPerDegreeLat;
      let x1 = (p1.x - lon0) * metersPerDegreeLon;
      let y1 = (p1.y - lat0) * metersPerDegreeLat;
      sum += x0 * y1 - x1 * y0;
    }
    return Math.abs(sum) / 2.0;
  }

  private measurementDistanceMeters(layer: GisLoadedLayer): number {
    let geodesicDistance = this.measurementDistanceGeodesicMeters(layer);
    if (geodesicDistance > 0.0) {
      return geodesicDistance;
    }
    if (layer.info.coordinateUnitType === UNIT_LINEAR) {
      let factor = this.unitToMetersFactor(layer);
      if (factor > 0.0) {
        return this.measurementDistance() * factor;
      }
    }
    return 0.0;
  }

  private measurementAreaSquareMeters(layer: GisLoadedLayer): number {
    if (this.measurementPoints.length < 3) {
      return 0.0;
    }
    let geodesicArea = this.measurementAreaGeodesicSquareMeters(layer);
    if (geodesicArea > 0.0) {
      return geodesicArea;
    }
    if (layer.info.coordinateUnitType === UNIT_LINEAR) {
      let factor = this.unitToMetersFactor(layer);
      if (factor > 0.0) {
        return this.measurementArea() * factor * factor;
      }
      return 0.0;
    }
    if (layer.info.coordinateUnitType !== UNIT_ANGULAR) {
      return 0.0;
    }
    return 0.0;
  }

  private measurementAngle(): number {
    if (this.measurementPoints.length < 3) {
      return 0.0;
    }
    let a = this.measurementPoints[0];
    let b = this.measurementPoints[1];
    let c = this.measurementPoints[2];
    let abx = a.x - b.x;
    let aby = a.y - b.y;
    let cbx = c.x - b.x;
    let cby = c.y - b.y;
    let dot = abx * cbx + aby * cby;
    let abLen = Math.sqrt(abx * abx + aby * aby);
    let cbLen = Math.sqrt(cbx * cbx + cby * cby);
    if (abLen <= 0.0 || cbLen <= 0.0) {
      return 0.0;
    }
    let value = dot / (abLen * cbLen);
    if (value < -1.0) {
      value = -1.0;
    }
    if (value > 1.0) {
      value = 1.0;
    }
    return Math.acos(value) * 180.0 / Math.PI;
  }

  private coordinateSummary(point: GisCoordinate): string {
    if (this.usesExternalBasemap()) {
      let lonLat = this.webMercatorToLonLat(point);
      if (this.usesHarmonyBasemap()) {
        return '花瓣坐标：' + this.lonLatLabel(lonLat.x, lonLat.y);
      }
      return '经纬度：' + this.lonLatLabel(lonLat.x, lonLat.y);
    }
    let first = this.getFirstVisibleLayer();
    if (first !== undefined && first.info.coordinateUnitType === UNIT_ANGULAR) {
      return '经纬度：' + this.lonLatLabel(point.x, point.y);
    }
    if (first !== undefined && first.info.crs.length > 0 && first.info.coordinateUnitType === UNIT_LINEAR) {
      let transformResult: GisCoordinateTransformResult =
        getGisService().transformCoordinate(first.info.crs, 'EPSG:4326', point.x, point.y);
      if (transformResult.ok) {
        return '坐标：' + point.x.toFixed(3) + ', ' + point.y.toFixed(3) + ' · 经纬度 ' +
          this.lonLatLabel(transformResult.x, transformResult.y);
      }
    }
    return '坐标：' + point.x.toFixed(6) + ', ' + point.y.toFixed(6);
  }

  private measurementSummary(): string {
    if (this.mapToolMode === MAP_TOOL_PICK_COORDINATE) {
      if (this.measurementPoints.length === 0) {
        return '坐标拾取：点击地图';
      }
      let p = this.measurementPoints[this.measurementPoints.length - 1];
      return this.coordinateSummary(p);
    }
    if (this.mapToolMode === MAP_TOOL_MEASURE_DISTANCE) {
      let first = this.getFirstVisibleLayer();
      if (first !== undefined) {
        let meters = this.measurementDistanceMeters(first);
        if (meters > 0.0) {
          return '距离：' + this.metricDistanceLabel(meters);
        }
        return '距离：' + this.coordinateDistanceLabel(this.measurementDistance(), first);
      }
      return '距离：' + this.measurementDistance().toFixed(3) + ' 坐标单位';
    }
    if (this.mapToolMode === MAP_TOOL_MEASURE_AREA) {
      let first = this.getFirstVisibleLayer();
      if (first !== undefined) {
        let areaMeters = this.measurementAreaSquareMeters(first);
        if (areaMeters > 0.0) {
          return '面积：' + this.metricAreaLabel(areaMeters);
        }
        return '面积：' + this.numberLabel(this.measurementArea()) + ' 平方' + this.unitLabel(first);
      }
      return '面积：' + this.measurementArea().toFixed(3) + ' 平方坐标单位';
    }
    if (this.mapToolMode === MAP_TOOL_MEASURE_ANGLE) {
      return '角度：' + this.measurementAngle().toFixed(2) + '°';
    }
    return '';
  }

  private drawMeasurementOverlay(ctx: CanvasRenderingContext2D): void {
    if (this.mapToolMode === MAP_TOOL_IDENTIFY || this.measurementPoints.length === 0) {
      return;
    }

    ctx.strokeStyle = '#BD6B16';
    ctx.fillStyle = '#BD6B16';
    ctx.lineWidth = 2;

    if (this.measurementPoints.length >= 2) {
      ctx.beginPath();
      let first = this.measurementPoints[0];
      ctx.moveTo(this.viewport.dataToCanvasX(first.x), this.viewport.dataToCanvasY(first.y));
      for (let i = 1; i < this.measurementPoints.length; i++) {
        let p = this.measurementPoints[i];
        ctx.lineTo(this.viewport.dataToCanvasX(p.x), this.viewport.dataToCanvasY(p.y));
      }
      if (this.mapToolMode === MAP_TOOL_MEASURE_AREA && this.measurementPoints.length >= 3) {
        ctx.closePath();
        ctx.fillStyle = '#BD6B1624';
        ctx.fill();
        ctx.fillStyle = '#BD6B16';
      }
      ctx.stroke();
    }

    for (let pi = 0; pi < this.measurementPoints.length; pi++) {
      let point = this.measurementPoints[pi];
      let x = this.viewport.dataToCanvasX(point.x);
      let y = this.viewport.dataToCanvasY(point.y);
      ctx.beginPath();
      ctx.arc(x, y, 4, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 1.5;
      ctx.stroke();
      ctx.strokeStyle = '#BD6B16';
      ctx.lineWidth = 2;
    }

    let summary = this.measurementSummary();
    if (summary.length > 0) {
      ctx.font = '12px sans-serif';
      ctx.fillStyle = '#17201D';
      ctx.fillText(this.measurementModeText() + ' · ' + summary, 16, 38);
    }
  }

  private drawEditOverlay(ctx: CanvasRenderingContext2D): void {
    if (!this.isEditTool()) {
      return;
    }
    ctx.font = '12px sans-serif';
    ctx.fillStyle = '#17201D';
    let status = this.editModeText();
    if (this.sketchPoints.length > 0) {
      status += ' · 草图点 ' + this.sketchPoints.length.toString() + '/' +
        this.requiredSketchPointCount().toString();
    }
    if (this.movingNodeHit.found) {
      status += ' · 已选节点，点击目标位置';
    }
    ctx.fillText(status, 16, 58);

    if (this.sketchPoints.length > 0) {
      ctx.strokeStyle = '#0F766E';
      ctx.fillStyle = '#0F766E';
      ctx.lineWidth = 2;
      if (this.sketchPoints.length >= 2) {
        ctx.beginPath();
        let first = this.sketchPoints[0];
        ctx.moveTo(this.viewport.dataToCanvasX(first.x), this.viewport.dataToCanvasY(first.y));
        for (let i = 1; i < this.sketchPoints.length; i++) {
          let p = this.sketchPoints[i];
          ctx.lineTo(this.viewport.dataToCanvasX(p.x), this.viewport.dataToCanvasY(p.y));
        }
        if (this.mapToolMode === MAP_TOOL_EDIT_ADD_POLYGON && this.sketchPoints.length >= 3) {
          ctx.closePath();
        }
        ctx.stroke();
      }
      for (let pi = 0; pi < this.sketchPoints.length; pi++) {
        let point = this.sketchPoints[pi];
        let x = this.viewport.dataToCanvasX(point.x);
        let y = this.viewport.dataToCanvasY(point.y);
        ctx.beginPath();
        ctx.arc(x, y, 4, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  private handleMeasurementClick(canvasX: number, canvasY: number): void {
    let dataX = this.viewport.canvasToDataX(canvasX);
    let dataY = this.viewport.canvasToDataY(canvasY);
    if (this.mapToolMode === MAP_TOOL_PICK_COORDINATE) {
      this.measurementPoints = [];
      this.measurementPoints.push(new GisCoordinate(dataX, dataY, 0, false));
    } else if (this.mapToolMode === MAP_TOOL_MEASURE_ANGLE) {
      if (this.measurementPoints.length >= 3) {
        this.measurementPoints = [];
      }
      this.measurementPoints.push(new GisCoordinate(dataX, dataY, 0, false));
    } else {
      this.measurementPoints.push(new GisCoordinate(dataX, dataY, 0, false));
    }
    let summary = this.measurementSummary();
    this.onMeasurementChanged(summary);
    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
  }

  private findNearestNode(canvasX: number, canvasY: number): EditNodeHit {
    let tolerance = 12.0;
    let bestDistance = tolerance;
    let best = new EditNodeHit(false, -1, '', -1, -1);
    for (let li = this.layers.length - 1; li >= 0; li--) {
      if (this.editLayerIndex >= 0 && li !== this.editLayerIndex) {
        continue;
      }
      let layer = this.layers[li];
      if (!layer.visible) {
        continue;
      }
      let interactionFeatures = this.interactionFeaturesForLayer(li);
      for (let fi = interactionFeatures.length - 1; fi >= 0; fi--) {
        let feature = interactionFeatures[fi];
        for (let pi = 0; pi < feature.geometry.parts.length; pi++) {
          let part = feature.geometry.parts[pi];
          for (let ci = 0; ci < part.points.length; ci++) {
            let point = part.points[ci];
            let displayPoint = this.coordinateToDisplay(layer, point.x, point.y);
            if (displayPoint === undefined) {
              continue;
            }
            let px = this.viewport.dataToCanvasX(displayPoint.x);
            let py = this.viewport.dataToCanvasY(displayPoint.y);
            let dx = canvasX - px;
            let dy = canvasY - py;
            let distance = Math.sqrt(dx * dx + dy * dy);
            if (distance <= bestDistance) {
              bestDistance = distance;
              best = new EditNodeHit(true, li, feature.featureId, pi, ci);
            }
          }
        }
      }
    }
    return best;
  }

  private cloneSketchPoints(): GisCoordinate[] {
    let result: GisCoordinate[] = [];
    for (let i = 0; i < this.sketchPoints.length; i++) {
      let point = this.sketchPoints[i];
      result.push(new GisCoordinate(point.x, point.y, point.z, point.hasZ));
    }
    return result;
  }

  private drawSelectionOverlay(ctx: CanvasRenderingContext2D): void {
    if (!this.isSpatialSelectionTool() || this.selectionPoints.length === 0) {
      return;
    }
    ctx.strokeStyle = '#1D4F91';
    ctx.fillStyle = '#1D4F9124';
    ctx.lineWidth = 2;
    ctx.beginPath();
    let first: GisCoordinate = this.selectionPoints[0];
    ctx.moveTo(this.viewport.dataToCanvasX(first.x), this.viewport.dataToCanvasY(first.y));
    for (let i = 1; i < this.selectionPoints.length; i++) {
      let point: GisCoordinate = this.selectionPoints[i];
      ctx.lineTo(this.viewport.dataToCanvasX(point.x), this.viewport.dataToCanvasY(point.y));
    }
    if (this.selectionPoints.length >= 3) {
      ctx.closePath();
      ctx.fill();
    }
    ctx.stroke();
    ctx.fillStyle = '#17201D';
    ctx.font = '12px sans-serif';
    ctx.fillText('服务端全数据集空间选择', 16, 58);
  }

  private isSpatialSelectionTool(): boolean {
    return this.mapToolMode === MAP_TOOL_SELECT_BOX || this.mapToolMode === MAP_TOOL_SELECT_LASSO ||
      this.mapToolMode === MAP_TOOL_SELECT_POLYGON;
  }

  private selectionRequiredPointCount(): number {
    if (this.mapToolMode === MAP_TOOL_SELECT_BOX) {
      return 2;
    }
    return 3;
  }

  private selectionWkt(): string {
    if (this.selectionPoints.length < 2) {
      return '';
    }
    let points: GisCoordinate[] = [];
    if (this.mapToolMode === MAP_TOOL_SELECT_BOX) {
      let first: GisCoordinate = this.selectionPoints[0];
      let second: GisCoordinate = this.selectionPoints[1];
      points.push(new GisCoordinate(first.x, first.y, 0, false));
      points.push(new GisCoordinate(second.x, first.y, 0, false));
      points.push(new GisCoordinate(second.x, second.y, 0, false));
      points.push(new GisCoordinate(first.x, second.y, 0, false));
    } else {
      for (let i = 0; i < this.selectionPoints.length; i++) {
        points.push(this.selectionPoints[i]);
      }
    }
    if (points.length < 3) {
      return '';
    }
    let text: string = 'POLYGON((';
    for (let i = 0; i < points.length; i++) {
      if (i > 0) {
        text += ',';
      }
      text += points[i].x.toString() + ' ' + points[i].y.toString();
    }
    text += ',' + points[0].x.toString() + ' ' + points[0].y.toString() + '))';
    return text;
  }

  private handleSpatialSelectionClick(canvasX: number, canvasY: number): void {
    if (this.usesExternalBasemap()) {
      this.reportEditFeedback('全数据集空间选择请在本地图层坐标视图中执行', true);
      return;
    }
    this.selectionPoints.push(new GisCoordinate(this.viewport.canvasToDataX(canvasX),
      this.viewport.canvasToDataY(canvasY), 0, false));
    if (this.selectionPoints.length >= this.selectionRequiredPointCount()) {
      let wkt: string = this.selectionWkt();
      if (wkt.length > 0) {
        this.onSelectionGeometryCompleted(wkt, this.crossLayerSelection);
      }
      this.selectionPoints = [];
    } else {
      this.onMeasurementChanged('空间选择：继续绘制范围');
    }
    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
  }

  private reportEditFeedback(summary: string, shouldToast: boolean): void {
    this.onMeasurementChanged(summary);
    this.onEditFeedback(summary, shouldToast);
  }

  private referenceDirection(): GisCoordinate {
    if (this.selectedFeatureLayerIndex >= 0 && this.selectedFeatureLayerIndex < this.layers.length) {
      let layer: GisLoadedLayer = this.layers[this.selectedFeatureLayerIndex];
      let interactionFeatures: GisFeatureSummary[] = this.interactionFeaturesForLayer(this.selectedFeatureLayerIndex);
      for (let i = 0; i < interactionFeatures.length; i++) {
        let feature: GisFeatureSummary = interactionFeatures[i];
        if (feature.featureId !== this.selectedFeatureId || feature.geometry.parts.length === 0 ||
          feature.geometry.parts[0].points.length < 2) {
          continue;
        }
        let first: GisCoordinate = feature.geometry.parts[0].points[0];
        let second: GisCoordinate = feature.geometry.parts[0].points[1];
        return new GisCoordinate(second.x - first.x, second.y - first.y, 0, false);
      }
    }
    return new GisCoordinate(1, 0, 0, false);
  }

  private constrainedSketchPoint(canvasX: number, canvasY: number, dataX: number, dataY: number): GisCoordinate {
    if (this.mapToolMode === MAP_TOOL_EDIT_TRACE) {
      let hit: EditNodeHit = this.findNearestNode(canvasX, canvasY);
      if (hit.found && hit.layerIndex >= 0 && hit.layerIndex < this.layers.length) {
        let layer: GisLoadedLayer = this.layers[hit.layerIndex];
        let interactionFeatures: GisFeatureSummary[] = this.interactionFeaturesForLayer(hit.layerIndex);
        for (let i = 0; i < interactionFeatures.length; i++) {
          if (interactionFeatures[i].featureId === hit.featureId && hit.partIndex >= 0 &&
            hit.partIndex < interactionFeatures[i].geometry.parts.length && hit.pointIndex >= 0 &&
            hit.pointIndex < interactionFeatures[i].geometry.parts[hit.partIndex].points.length) {
            let point: GisCoordinate = interactionFeatures[i].geometry.parts[hit.partIndex].points[hit.pointIndex];
            return new GisCoordinate(point.x, point.y, point.z, point.hasZ);
          }
        }
      }
    }
    if (this.sketchPoints.length === 0) {
      return new GisCoordinate(dataX, dataY, 0, false);
    }
    let origin: GisCoordinate = this.sketchPoints[0];
    if (this.mapToolMode === MAP_TOOL_EDIT_ORTHOGONAL) {
      if (Math.abs(dataX - origin.x) >= Math.abs(dataY - origin.y)) {
        return new GisCoordinate(dataX, origin.y, 0, false);
      }
      return new GisCoordinate(origin.x, dataY, 0, false);
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_PARALLEL ||
      this.mapToolMode === MAP_TOOL_EDIT_PERPENDICULAR) {
      let direction: GisCoordinate = this.referenceDirection();
      let dx: number = direction.x;
      let dy: number = direction.y;
      if (this.mapToolMode === MAP_TOOL_EDIT_PERPENDICULAR) {
        let oldDx: number = dx;
        dx = -dy;
        dy = oldDx;
      }
      let length: number = Math.sqrt(dx * dx + dy * dy);
      if (length <= 0) {
        return new GisCoordinate(dataX, dataY, 0, false);
      }
      dx /= length;
      dy /= length;
      let projection: number = (dataX - origin.x) * dx + (dataY - origin.y) * dy;
      return new GisCoordinate(origin.x + projection * dx, origin.y + projection * dy, 0, false);
    }
    return new GisCoordinate(dataX, dataY, 0, false);
  }

  private handleEditClick(canvasX: number, canvasY: number): void {
    if (this.usesExternalBasemap()) {
      this.reportEditFeedback('在线底图下请先切回本地矢量底图再编辑，避免写入错误坐标', true);
      return;
    }
    this.refreshInteractionFeaturesNearPoint(canvasX, canvasY);
    let dataX = this.viewport.canvasToDataX(canvasX);
    let dataY = this.viewport.canvasToDataY(canvasY);
    if (this.mapToolMode === MAP_TOOL_EDIT_MOVE_NODE) {
      if (this.movingNodeHit.found) {
        this.onNodeEditRequested(this.mapToolMode, this.movingNodeHit.layerIndex, this.movingNodeHit.featureId,
          this.movingNodeHit.partIndex, this.movingNodeHit.pointIndex, dataX, dataY);
        this.movingNodeHit = new EditNodeHit(false, -1, '', -1, -1);
      } else {
        this.movingNodeHit = this.findNearestNode(canvasX, canvasY);
        if (this.movingNodeHit.found) {
          this.reportEditFeedback('已选节点：' + this.movingNodeHit.featureId, false);
        } else {
          this.reportEditFeedback('未命中可移动节点', true);
        }
      }
      this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
      return;
    }
    if (this.mapToolMode === MAP_TOOL_EDIT_DELETE_NODE) {
      let hit = this.findNearestNode(canvasX, canvasY);
      if (hit.found) {
        this.onNodeEditRequested(this.mapToolMode, hit.layerIndex, hit.featureId, hit.partIndex, hit.pointIndex,
          dataX, dataY);
      } else {
        this.reportEditFeedback('未命中可删除节点', true);
      }
      this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
      return;
    }
    this.sketchPoints.push(this.constrainedSketchPoint(canvasX, canvasY, dataX, dataY));
    if (this.sketchPoints.length >= this.requiredSketchPointCount()) {
      if (this.mapToolMode === MAP_TOOL_EDIT_CUT_SKETCH) {
        this.onCutSketchCompleted(this.cloneSketchPoints());
      } else {
        this.onSketchFeatureCreated(this.editGeometryType(), this.cloneSketchPoints());
      }
      this.sketchPoints = [];
    } else {
      this.reportEditFeedback(this.editModeText() + '：继续点击地图', false);
    }
    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
  }

  // ---------------------------------------------------------------------------
  // Hit testing
  // ---------------------------------------------------------------------------

  private hitTest(canvasX: number, canvasY: number): HitTestResult {
    let tolerance = 10;

    for (let li = this.layers.length - 1; li >= 0; li--) {
      let layer = this.layers[li];
      if (!layer.visible) {
        continue;
      }

      let interactionFeatures = this.interactionFeaturesForLayer(li);
      for (let fi = interactionFeatures.length - 1; fi >= 0; fi--) {
        let feature = interactionFeatures[fi];
        let geom = feature.geometry;

        if (geom.geometryType === GEOM_POINT) {
          for (let pi = 0; pi < geom.parts.length; pi++) {
            let part = geom.parts[pi];
            for (let ci = 0; ci < part.points.length; ci++) {
              let coord = part.points[ci];
              let displayCoord = this.coordinateToDisplay(layer, coord.x, coord.y);
              if (displayCoord === undefined) {
                continue;
              }
              let px = this.viewport.dataToCanvasX(displayCoord.x);
              let py = this.viewport.dataToCanvasY(displayCoord.y);
              let dx = canvasX - px;
              let dy = canvasY - py;
              if (dx * dx + dy * dy <= tolerance * tolerance) {
                return new HitTestResult(feature.featureId, li, true);
              }
            }
          }
        } else if (geom.geometryType === GEOM_POLYGON) {
          for (let pi = 0; pi < geom.parts.length; pi++) {
            let part = geom.parts[pi];
            if (part.points.length >= 3) {
              if (this.pointInPolygon(layer, canvasX, canvasY, part.points)) {
                return new HitTestResult(feature.featureId, li, true);
              }
            }
          }
        } else if (geom.geometryType === GEOM_LINESTRING) {
          for (let pi = 0; pi < geom.parts.length; pi++) {
            let part = geom.parts[pi];
            for (let ci = 1; ci < part.points.length; ci++) {
              let p0 = part.points[ci - 1];
              let p1 = part.points[ci];
              let displayP0 = this.coordinateToDisplay(layer, p0.x, p0.y);
              let displayP1 = this.coordinateToDisplay(layer, p1.x, p1.y);
              if (displayP0 === undefined || displayP1 === undefined) {
                continue;
              }
              let x0 = this.viewport.dataToCanvasX(displayP0.x);
              let y0 = this.viewport.dataToCanvasY(displayP0.y);
              let x1 = this.viewport.dataToCanvasX(displayP1.x);
              let y1 = this.viewport.dataToCanvasY(displayP1.y);
              let dist = this.pointToSegmentDistance(canvasX, canvasY, x0, y0, x1, y1);
              if (dist <= tolerance) {
                return new HitTestResult(feature.featureId, li, true);
              }
            }
          }
        }
      }
    }

    return new HitTestResult('', -1, false);
  }

  private pointInPolygon(layer: GisLoadedLayer, px: number, py: number, points: GisCoordinate[]): boolean {
    let inside = false;
    let n = points.length;
    let j = n - 1;
    for (let i = 0; i < n; j = i++) {
      let displayI = this.coordinateToDisplay(layer, points[i].x, points[i].y);
      let displayJ = this.coordinateToDisplay(layer, points[j].x, points[j].y);
      if (displayI === undefined || displayJ === undefined) {
        continue;
      }
      let xi = this.viewport.dataToCanvasX(displayI.x);
      let yi = this.viewport.dataToCanvasY(displayI.y);
      let xj = this.viewport.dataToCanvasX(displayJ.x);
      let yj = this.viewport.dataToCanvasY(displayJ.y);

      if (((yi > py) !== (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  private pointToSegmentDistance(px: number, py: number, x0: number, y0: number, x1: number, y1: number): number {
    let dx = x1 - x0;
    let dy = y1 - y0;
    let lenSq = dx * dx + dy * dy;
    if (lenSq === 0) {
      let ex = px - x0;
      let ey = py - y0;
      return Math.sqrt(ex * ex + ey * ey);
    }
    let t = ((px - x0) * dx + (py - y0) * dy) / lenSq;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    let projX = x0 + t * dx;
    let projY = y0 + t * dy;
    let ex = px - projX;
    let ey = py - projY;
    return Math.sqrt(ex * ex + ey * ey);
  }

  // Auto-fit viewport to combined extent of all loaded layers
  private fitToLayerExtent(): void {
    if (this.layers.length === 0) {
      return;
    }
    let minX = 1e18;
    let minY = 1e18;
    let maxX = -1e18;
    let maxY = -1e18;
    let hasVisibleLayer = false;
    for (let li = 0; li < this.layers.length; li++) {
      if (!this.layers[li].visible) {
        continue;
      }
      let env = this.envelopeToDisplay(this.layers[li], this.layers[li].info.envelope);
      if (env === undefined) {
        continue;
      }
      hasVisibleLayer = true;
      if (env.minX < minX) minX = env.minX;
      if (env.minY < minY) minY = env.minY;
      if (env.maxX > maxX) maxX = env.maxX;
      if (env.maxY > maxY) maxY = env.maxY;
    }
    if (!hasVisibleLayer) {
      if (this.usesExternalBasemap()) {
        let center = this.defaultExternalDisplayCenter();
        let halfSize = 100000.0;
        this.viewport.fitToEnvelope(center.x - halfSize, center.y - halfSize, center.x + halfSize,
          center.y + halfSize);
      }
      return;
    }
    if (maxX > minX && maxY > minY) {
      this.viewport.fitToEnvelope(minX, minY, maxX, maxY);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  build() {
    Stack() {
      if (this.usesTileBasemap()) {
        Web({ src: $rawfile('online_tile_basemap.html'), controller: this.tileWebController })
          .width('100%')
          .height('100%')
          .javaScriptAccess(true)
          .fileAccess(true)
          .onlineImageAccess(true)
          .imageAccess(true)
          .domStorageAccess(true)
          .cacheMode(this.webCacheMode())
          .onPageEnd(() => {
            this.tilePageReady = true;
            this.externalBasemapFailed = false;
            this.updateBasemapStatus('在线底图已加载');
            this.syncOnlineBasemap();
          })
          .onErrorReceive(() => {
            this.externalBasemapFailed = true;
            this.updateBasemapStatus('在线底图加载失败');
            hilog.warn(TAG, DOMAIN, 'online tile basemap web resource error');
            this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
          })
          .zIndex(0)
      }
      if (this.usesHarmonyBasemap()) {
        MapComponent({ mapOptions: this.createHarmonyMapOptions(), mapCallback: this.harmonyMapCallback })
          .width('100%')
          .height('100%')
          .zIndex(0)
      }

      Canvas(this.canvasContext)
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .zIndex(1)
        .onReady(() => {
          this.canvasReady = true;
          if (this.layers.length > 0 && !this.dataFitted) {
            this.dataFitted = true;
            this.fitToLayerExtent();
            this.lastLayerCount = this.layers.length;
            this.updateScaleLabel();
            this.notifyViewportChanged();
          }
          this.applyExternalViewportIfNeeded();
          this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
        })
        .onAreaChange((_oldVal: Area, newVal: Area) => {
          this.viewport.canvasWidth = newVal.width as number;
          this.viewport.canvasHeight = newVal.height as number;
          this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
        })
        .gesture(
          PanGesture({ distance: 5 })
            .onActionStart((event: GestureEvent) => {
              try {
                let x = event.fingerList[0].localX;
                let y = event.fingerList[0].localY;
                this.lastPanX = x;
                this.lastPanY = y;
                this.lastPanDx = 0;
                this.lastPanDy = 0;
                this.lastInteractiveRenderTimestamp = 0;
                this.isPanning = true;
              } catch (e) {
                this.isPanning = false;
              }
            })
            .onActionUpdate((event: GestureEvent) => {
              try {
                if (this.isPanning) {
                  let x = event.fingerList[0].localX;
                  let y = event.fingerList[0].localY;
                  let dx = x - this.lastPanX;
                  let dy = y - this.lastPanY;
                  if (this.pointerSmoothing) {
                    dx = (dx + this.lastPanDx) * 0.5;
                    dy = (dy + this.lastPanDy) * 0.5;
                  }
                  let dataDx = -dx / this.viewport.scale;
                  let dataDy = dy / this.viewport.scale;
                  this.viewport.centerX += dataDx;
                  this.viewport.centerY += dataDy;
                  this.lastPanDx = dx;
                  this.lastPanDy = dy;
                  this.lastPanX = x;
                  this.lastPanY = y;
                  if (this.shouldRenderInteractiveFrame(event.timestamp)) {
                    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
                  }
                }
              } catch (e) {
                this.isPanning = false;
              }
            })
            .onActionEnd(() => {
              this.isPanning = false;
              this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
              this.notifyViewportChanged();
            })
        )
        .gesture(
          PinchGesture({ fingers: 2 })
            .onActionStart(() => {
              this.isPinching = true;
              this.lastInteractiveRenderTimestamp = 0;
            })
            .onActionUpdate((event: GestureEvent) => {
              let scaleFactor = event.scale;
              if (scaleFactor > 0.5 && scaleFactor < 3.0) {
                this.viewport.scale = this.viewport.scale * scaleFactor;
                this.viewport.clampScale();
                if (this.shouldRenderInteractiveFrame(event.timestamp)) {
                  this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
                }
              }
            })
            .onActionEnd(() => {
              this.isPinching = false;
              this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
              this.notifyViewportChanged();
            })
        )
        .onClick((event: ClickEvent) => {
          if (this.isSpatialSelectionTool()) {
            this.handleSpatialSelectionClick(event.x, event.y);
            return;
          }
          if (this.isEditTool()) {
            this.handleEditClick(event.x, event.y);
            return;
          }
          if (this.isMeasurementTool()) {
            this.handleMeasurementClick(event.x, event.y);
            return;
          }
          this.refreshInteractionFeaturesNearPoint(event.x, event.y);
          let hit = this.hitTest(event.x, event.y);
          if (hit.found) {
            let operation = this.mapToolMode === MAP_TOOL_SELECT_MULTIPLE ? FEATURE_SELECTION_TOGGLE :
              FEATURE_SELECTION_REPLACE;
            this.onFeatureSelected(hit.featureId, hit.layerIndex, operation);
          } else {
            this.onFeatureSelected('', -1, FEATURE_SELECTION_REPLACE);
          }
          this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
        })
        .onMouse((event: MouseEvent) => {
          if (event.action === MouseAction.Press && event.button === 2) {
            this.isMiddleButtonPanning = true;
            this.lastInteractiveRenderTimestamp = 0;
            this.middlePanStartX = event.x;
            this.middlePanStartY = event.y;
            this.middlePanStartCenterX = this.viewport.centerX;
            this.middlePanStartCenterY = this.viewport.centerY;
            return;
          }
          if (event.action === MouseAction.Release && event.button === 2) {
            this.isMiddleButtonPanning = false;
            this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
            this.notifyViewportChanged();
            return;
          }
          if (this.isMiddleButtonPanning && event.action === MouseAction.Move) {
            let dx = (event.x - this.middlePanStartX) / this.viewport.scale;
            let dy = (event.y - this.middlePanStartY) / this.viewport.scale;
            this.viewport.centerX = this.middlePanStartCenterX - dx;
            this.viewport.centerY = this.middlePanStartCenterY + dy;
            if (this.shouldRenderInteractiveFrame(Date.now())) {
              this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
            }
            return;
          }
        })
        .onAxisEvent((event?: AxisEvent) => {
          if (event === undefined) {
            return;
          }
          let step = event.scrollStep;
          if (step === undefined) {
            return;
          }
          let vpX = event.x;
          let vpY = event.y;
          if (step > 0) {
            let factor = 1.15;
            let mapX = this.viewport.centerX + (vpX - this.viewport.canvasWidth / 2) / this.viewport.scale;
            let mapY = this.viewport.centerY - (vpY - this.viewport.canvasHeight / 2) / this.viewport.scale;
            this.viewport.scale = this.viewport.scale * factor;
            this.viewport.clampScale();
            this.viewport.centerX = mapX - (vpX - this.viewport.canvasWidth / 2) / this.viewport.scale;
            this.viewport.centerY = mapY + (vpY - this.viewport.canvasHeight / 2) / this.viewport.scale;
            this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
            this.notifyViewportChanged();
          } else if (step < 0) {
            let factor = 1 / 1.15;
            let mapX = this.viewport.centerX + (vpX - this.viewport.canvasWidth / 2) / this.viewport.scale;
            let mapY = this.viewport.centerY - (vpY - this.viewport.canvasHeight / 2) / this.viewport.scale;
            this.viewport.scale = this.viewport.scale * factor;
            this.viewport.clampScale();
            this.viewport.centerX = mapX - (vpX - this.viewport.canvasWidth / 2) / this.viewport.scale;
            this.viewport.centerY = mapY + (vpY - this.viewport.canvasHeight / 2) / this.viewport.scale;
            this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
            this.notifyViewportChanged();
          }
        })

      if (this.shouldShowHarmonyMapDiagnostic()) {
        this.harmonyMapDiagnosticOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  private lastLayerCount: number = 0;

  onDataChanged(): void {
    if (!this.canvasReady) {
      return;
    }
    if (this.layers.length > 0) {
      if (!this.dataFitted || this.layers.length !== this.lastLayerCount) {
        this.dataFitted = true;
        this.fitToLayerExtent();
      }
    } else {
      this.dataFitted = false;
    }
    this.viewportFeatureCaches = [];
    this.lastLayerCount = this.layers.length;
    this.updateScaleLabel();
    this.notifyViewportChanged();
    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
  }

  onMapCommandChanged(): void {
    if (!this.canvasReady) {
      return;
    }
    if (this.mapCommand === MAP_COMMAND_ZOOM_IN) {
      this.zoomIn();
    } else if (this.mapCommand === MAP_COMMAND_ZOOM_OUT) {
      this.zoomOut();
    } else if (this.mapCommand === MAP_COMMAND_FULL_EXTENT) {
      this.zoomToFullExtent();
    } else if (this.mapCommand === MAP_COMMAND_ZOOM_SELECTED) {
      this.zoomToSelectedFeatures();
    } else if (this.mapCommand === MAP_COMMAND_ZOOM_PRIMARY) {
      this.zoomToPrimaryFeature();
    }
  }

  onMapToolChanged(): void {
    this.measurementPoints = [];
    this.sketchPoints = [];
    this.selectionPoints = [];
    this.movingNodeHit = new EditNodeHit(false, -1, '', -1, -1);
    this.onMeasurementChanged('');
    if (this.canvasReady) {
      this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
    }
  }

  onBasemapModeChanged(): void {
    this.externalBasemapFailed = false;
    this.measurementPoints = [];
    this.sketchPoints = [];
    this.movingNodeHit = new EditNodeHit(false, -1, '', -1, -1);
    this.onMeasurementChanged('');
    if (this.usesHarmonyBasemap()) {
      if (this.harmonyMapReady) {
        this.safeShowHarmonyMap();
        if (!this.harmonyMapLoaded && !this.externalBasemapFailed) {
          this.updateBasemapStatus('花瓣地图组件已创建，等待底图加载');
          this.scheduleHarmonyMapLoadWatchdog();
        }
        if (!this.externalBasemapFailed) {
          this.syncHarmonyBasemap();
        }
      } else {
        this.updateBasemapStatus('花瓣地图初始化中');
      }
    } else if (this.usesTileBasemap()) {
      this.safeHideHarmonyMap();
      this.resetHarmonyMapController();
      this.updateBasemapStatus('在线底图加载中');
      this.syncOnlineBasemap();
    } else {
      this.safeHideHarmonyMap();
      this.resetHarmonyMapController();
      this.updateBasemapStatus('');
    }
    if (this.canvasReady) {
      if (this.layers.length > 0) {
        this.fitToLayerExtent();
      }
      this.updateScaleLabel();
      this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
      this.notifyViewportChanged();
    }
  }

  onBasemapDatumModeChanged(): void {
    this.measurementPoints = [];
    this.sketchPoints = [];
    this.movingNodeHit = new EditNodeHit(false, -1, '', -1, -1);
    this.onMeasurementChanged('');
    if (this.canvasReady) {
      if (this.layers.length > 0) {
        this.fitToLayerExtent();
      }
      this.updateScaleLabel();
      this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
      this.notifyViewportChanged();
    }
  }

  private zoomToPrimaryFeature(): void {
    if (this.selectedFeatureId.length === 0 || this.selectedFeatureLayerIndex < 0 ||
      this.selectedFeatureLayerIndex >= this.layers.length) {
      return;
    }
    let layer = this.layers[this.selectedFeatureLayerIndex];
    let feature = this.featureByIdForLayer(this.selectedFeatureLayerIndex, this.selectedFeatureId);
    if (feature === undefined) {
      return;
    }
    let env = this.envelopeToDisplay(layer, feature.envelope);
    if (env === undefined) {
      return;
    }
    this.viewport.fitToEnvelope(env.minX, env.minY, env.maxX, env.maxY);
    this.notifyViewportChanged();
    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
  }

  private zoomToSelectedFeatures(): void {
    if (this.selectedFeatureIds.length === 0 || this.selectedFeatureLayerIndex < 0 ||
      this.selectedFeatureLayerIndex >= this.layers.length) {
      return;
    }
    let layer = this.layers[this.selectedFeatureLayerIndex];
    let found = false;
    let minX = 0.0;
    let minY = 0.0;
    let maxX = 0.0;
    let maxY = 0.0;
    for (let fi = 0; fi < this.selectedFeatureIds.length; fi++) {
      let feature = this.featureByIdForLayer(this.selectedFeatureLayerIndex, this.selectedFeatureIds[fi]);
      if (feature === undefined) {
        continue;
      }
      let env = this.envelopeToDisplay(layer, feature.envelope);
      if (env === undefined) {
        continue;
      }
      if (!found) {
        minX = env.minX;
        minY = env.minY;
        maxX = env.maxX;
        maxY = env.maxY;
        found = true;
      } else {
        if (env.minX < minX) {
          minX = env.minX;
        }
        if (env.minY < minY) {
          minY = env.minY;
        }
        if (env.maxX > maxX) {
          maxX = env.maxX;
        }
        if (env.maxY > maxY) {
          maxY = env.maxY;
        }
      }
    }
    if (!found) {
      return;
    }
    this.viewport.fitToEnvelope(minX, minY, maxX, maxY);
    this.notifyViewportChanged();
    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
  }

  // Public method: zoom to full extent (uses data envelope)
  zoomToFullExtent(): void {
    this.fitToLayerExtent();
    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
    this.notifyViewportChanged();
  }

  // Public method: zoom in
  zoomIn(): void {
    this.viewport.scale = this.viewport.scale * 1.5;
    this.viewport.clampScale();
    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
    this.notifyViewportChanged();
  }

  // Public method: zoom out
  zoomOut(): void {
    this.viewport.scale = this.viewport.scale / 1.5;
    this.viewport.clampScale();
    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
    this.notifyViewportChanged();
  }

  // Public method: force redraw
  redraw(): void {
    this.renderMap(this.canvasContext, this.viewport.canvasWidth, this.viewport.canvasHeight);
  }
}
