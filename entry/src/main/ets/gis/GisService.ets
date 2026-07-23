import {
  bridgeOpenVectorLayer,
  bridgeOpenRasterLayer,
  bridgeReadQgisProject,
  bridgeWriteQgisProject,
  bridgeGetLayerInfo,
  bridgeGetFeature,
  bridgeQueryFeatures,
  bridgeSelectFeaturesByGeometry,
  bridgeCloseLayer,
  bridgeGetProcessingAlgorithms,
  bridgeGetProcessingCatalog,
  bridgeExecuteProcessingAlgorithm,
  bridgeStartProcessingTask,
  bridgeGetProcessingTaskStatus,
  bridgeCancelProcessingTask,
  bridgeReleaseProcessingTask,
  bridgeExportLayerToFormat,
  bridgeApplyVectorStyle,
  bridgeImportQmlStyle,
  bridgeExportQmlStyle,
  bridgeApplyVectorLabeling,
  bridgeConfigureRasterDisplay,
  bridgeRenderMapView,
  bridgeExportMapLayout,
  bridgeDescribeCoordinateReferenceSystem,
  bridgeTransformCoordinate,
  bridgeTransformEnvelope,
  bridgeBeginEditSession,
  bridgeCommitEditSession,
  bridgeRollbackEditSession,
  bridgeUndoEdit,
  bridgeRedoEdit,
  bridgeIsEditing,
  bridgeHasPendingEdits,
  bridgeCanUndo,
  bridgeCanRedo,
  bridgeAddFeature,
  bridgeDeleteFeature,
  bridgeMoveFeatureNode,
  bridgeDeleteFeatureNode,
  bridgeCopyFeature,
  bridgeSplitFeature,
  bridgeMergeFeatures,
  bridgeSnapLayer,
  bridgeUpdateFeatureAttribute,
  bridgeBatchAssignAttribute,
  bridgeAddLayerField,
  bridgeDeleteLayerField,
  bridgeCalculateField,
  bridgeValidateTopologyRules,
  bridgeRepairTopologyIssues,
  bridgeListVectorSublayers,
  bridgeInspectPointCloud,
  bridgeProcessPointCloud
} from './GisNativeBridge';
import {
  GisLayerInfo,
  GisFeaturePage,
  GisFeatureSummary,
  GisEnvelope,
  GisFieldInfo,
  GisGeometryPayload,
  GisGeometryPart,
  GisCoordinate,
  GisAttributeValue,
  GisOperationResult,
  GisGeoProcessResult,
  GisCrsInfo,
  GisCoordinateTransformResult,
  GisEnvelopeTransformResult,
  GisProcessingCatalog,
  GisProcessingTaskRequest,
  GisProcessingTaskSnapshot,
  GIS_PROCESSING_TASK_CANCELED,
  GIS_PROCESSING_TASK_FAILED,
  GIS_PROCESSING_TASK_NOT_FOUND,
  GIS_PROCESSING_TASK_STATUS_UNAVAILABLE,
  GIS_PROCESSING_TASK_SUCCEEDED,
  GisQgisProjectReadResult,
  GisQgisProjectLayerRef,
  GisSpatialSelectionResult,
  GisLayerSelection,
  GisVectorSublayerInfo,
  GisPointCloudInfo
} from '../model/GeoNestModels';
import {
  ProcessingEnvironmentSnapshot,
  ProcessingHistoryManager,
  ProcessingTaskRecord
} from '../utils/ProcessingHistoryManager';

// Keep only a bounded interaction preview in ArkTS. Large layers are rendered by
// the native QGIS map renderer and queried separately for editing/selection.
const GIS_FEATURE_PREVIEW_LIMIT: number = 600;

// ---------------------------------------------------------------------------
// GisLayerStyle: simple renderer style used by map canvas and symbol panel
// ---------------------------------------------------------------------------
export class GisLayerStyle {
  pointColor: string = '#BD6B16';
  lineColor: string = '#5B8DB8';
  fillColor: string = '#B8D7C9';
  strokeColor: string = '#4A8B6F';
  lineWidth: number = 2.5;
  pointRadius: number = 6;
  rendererMode: number = 0;
  rendererField: string = '';
  colorRamp: number = 0;
  linePattern: number = 0;
  fillPattern: number = 0;
  opacity: number = 1.0;
  symbolName: string = '默认符号';
  labelEnabled: boolean = false;
  labelField: string = '';
  labelSize: number = 12;
  labelColor: string = '#17201D';
  labelHalo: boolean = true;
  labelAvoidance: boolean = true;
  labelMinScale: number = 0;
  labelMaxScale: number = 0;
  rasterBandMode: number = 0;
  rasterStretchMode: number = 0;
  rasterColorRamp: number = 0;
  rasterOpacity: number = 1.0;
  rasterNoData: string = '';
  rasterTransparentColor: string = '';
  rasterHillshade: boolean = false;

  constructor(pointColor: string, lineColor: string, fillColor: string, strokeColor: string, lineWidth: number,
    pointRadius: number) {
    this.pointColor = pointColor;
    this.lineColor = lineColor;
    this.fillColor = fillColor;
    this.strokeColor = strokeColor;
    this.lineWidth = lineWidth;
    this.pointRadius = pointRadius;
  }
}

export class GisLayerEditSnapshot {
  layerIndex: number = -1;
  featureCount: number = 0;
  envelope: GisEnvelope = new GisEnvelope(0, 0, 0, 0);
  fields: GisFieldInfo[] = [];
  features: GisFeatureSummary[] = [];

  constructor(layerIndex: number, featureCount: number, envelope: GisEnvelope, fields: GisFieldInfo[],
    features: GisFeatureSummary[]) {
    this.layerIndex = layerIndex;
    this.featureCount = featureCount;
    this.envelope = envelope;
    this.fields = fields;
    this.features = features;
  }
}

// ---------------------------------------------------------------------------
// GisLoadedLayer: wrapper holding layer metadata + loaded features
// ---------------------------------------------------------------------------
export class GisLoadedLayer {
  info: GisLayerInfo;
  sourcePath: string = '';
  visible: boolean = true;
  selected: boolean = false;
  features: GisFeatureSummary[] = [];
  style: GisLayerStyle;

  constructor(info: GisLayerInfo, style: GisLayerStyle, sourcePath: string) {
    this.info = info;
    this.style = style;
    this.sourcePath = sourcePath;
  }
}

class GisXYTableProcessingOptions {
  xFieldIndex: number = -1;
  yFieldIndex: number = -1;
  zFieldIndex: number = -1;
  mFieldIndex: number = -1;
  crsDefinition: string = 'EPSG:4326';

  constructor(xFieldIndex: number, yFieldIndex: number, zFieldIndex: number, mFieldIndex: number,
    crsDefinition: string) {
    this.xFieldIndex = xFieldIndex;
    this.yFieldIndex = yFieldIndex;
    this.zFieldIndex = zFieldIndex;
    this.mFieldIndex = mFieldIndex;
    this.crsDefinition = crsDefinition;
  }
}

class GisPortableProjectProcessingOptions {
  projectName: string = '';
  projectCrs: string = '';
  layerHandles: string = '';
  visibleLayerHandles: string = '';

  constructor(projectName: string, projectCrs: string, layerHandles: string, visibleLayerHandles: string) {
    this.projectName = projectName;
    this.projectCrs = projectCrs;
    this.layerHandles = layerHandles;
    this.visibleLayerHandles = visibleLayerHandles;
  }
}

class GisAtlasProcessingOptions {
  title: string = '';
  format: string = 'pdf';
  filterExpression: string = '';
  margin: number = 0.1;
  width: number = 1600;
  height: number = 1100;
  basemapMode: number = 0;
  basemapLabel: string = '';
  visibleLayerHandles: string = '';
  showLegend: boolean = true;
  showScale: boolean = true;
  showNorth: boolean = true;
  showGrid: boolean = false;
  sortField: string = '';
  groupField: string = '';
  pageNameField: string = '';
  dynamicTitle: string = '';
  sortAscending: boolean = true;

  constructor(title: string, format: string, filterExpression: string, margin: number, width: number,
    height: number, basemapMode: number, basemapLabel: string, visibleLayerHandles: string,
    sortField: string, groupField: string, pageNameField: string, dynamicTitle: string,
    sortAscending: boolean) {
    this.title = title;
    this.format = format;
    this.filterExpression = filterExpression;
    this.margin = margin;
    this.width = width;
    this.height = height;
    this.basemapMode = basemapMode;
    this.basemapLabel = basemapLabel;
    this.visibleLayerHandles = visibleLayerHandles;
    this.sortField = sortField;
    this.groupField = groupField;
    this.pageNameField = pageNameField;
    this.dynamicTitle = dynamicTitle;
    this.sortAscending = sortAscending;
  }
}

class GisPendingProcessingTask {
  historyTaskId: string = '';
  request: GisProcessingTaskRequest = new GisProcessingTaskRequest('', -1, -1, 0, '', '', '');
  snapshot: GisProcessingTaskSnapshot = new GisProcessingTaskSnapshot('', '', GIS_PROCESSING_TASK_NOT_FOUND,
    0, 0, '', '', 0, 0, false, true, null);
  finalized: boolean = false;

  constructor(historyTaskId: string, request: GisProcessingTaskRequest,
    snapshot: GisProcessingTaskSnapshot) {
    this.historyTaskId = historyTaskId;
    this.request = request;
    this.snapshot = snapshot;
  }
}

// ---------------------------------------------------------------------------
// GisService: singleton managing loaded layers
// ---------------------------------------------------------------------------
export class GisService {
  private layers: GisLoadedLayer[] = [];
  private activeLayerIndex: number = -1;
  private draftFeatureSeed: number = 1;
  private editUndoStack: GisLayerEditSnapshot[] = [];
  private editRedoStack: GisLayerEditSnapshot[] = [];
  private processingTasks: GisPendingProcessingTask[] = [];
  private processingPollTimer: number = -1;

  private createLayerStyle(geometryType: number, layerIndex: number): GisLayerStyle {
    let pointColors: string[] = ['#BD6B16', '#7C3AED', '#0F766E', '#B42318'];
    let lineColors: string[] = ['#2563A8', '#8A5A00', '#047857', '#9F1239'];
    let fillColors: string[] = ['#B8D7C9', '#F2D7A6', '#BFD7F2', '#D7C4E8'];
    let strokeColors: string[] = ['#4A8B6F', '#A36B00', '#376D9B', '#72539B'];
    let idx = layerIndex % pointColors.length;

    let pointColor = pointColors[idx];
    let lineColor = lineColors[idx];
    let fillColor = fillColors[idx];
    let strokeColor = strokeColors[idx];

    if (geometryType === 1) {
      return new GisLayerStyle(pointColor, lineColor, fillColor, strokeColor, 2.0, 6);
    }
    if (geometryType === 2) {
      return new GisLayerStyle(pointColor, lineColor, fillColor, strokeColor, 3.0, 6);
    }
    return new GisLayerStyle(pointColor, lineColor, fillColor, strokeColor, 1.4, 6);
  }

  private createLayerStyleFromInfo(layerInfo: GisLayerInfo, layerIndex: number): GisLayerStyle {
    let style = this.createLayerStyle(layerInfo.geometryType, layerIndex);
    if (layerInfo.legendColor.length > 0) {
      if (layerInfo.geometryType === 1) {
        style.pointColor = layerInfo.legendColor;
      } else if (layerInfo.geometryType === 2) {
        style.lineColor = layerInfo.legendColor;
      } else if (layerInfo.geometryType === 3) {
        style.fillColor = layerInfo.legendColor;
      }
    }
    if (layerInfo.legendStrokeColor.length > 0) {
      style.strokeColor = layerInfo.legendStrokeColor;
    }
    return style;
  }

  getLayerCount(): number {
    return this.layers.length;
  }

  getVisibleLayerCount(): number {
    let count = 0;
    for (let i = 0; i < this.layers.length; i++) {
      if (this.layers[i].visible) {
        count++;
      }
    }
    return count;
  }

  getLayer(index: number): GisLoadedLayer | undefined {
    if (index < 0 || index >= this.layers.length) {
      return undefined;
    }
    return this.layers[index];
  }

  getActiveLayer(): GisLoadedLayer | undefined {
    if (this.activeLayerIndex < 0 || this.activeLayerIndex >= this.layers.length) {
      return undefined;
    }
    return this.layers[this.activeLayerIndex];
  }

  getActiveLayerIndex(): number {
    return this.activeLayerIndex;
  }

  setActiveLayerIndex(index: number): void {
    if (index >= 0 && index < this.layers.length) {
      this.activeLayerIndex = index;
    }
  }

  setLayerVisibility(index: number, visible: boolean): void {
    if (index >= 0 && index < this.layers.length) {
      this.layers[index].visible = visible;
    }
  }

  describeCoordinateReferenceSystem(definition: string): GisCrsInfo {
    return bridgeDescribeCoordinateReferenceSystem(definition);
  }

  inspectPointCloud(filePath: string): GisPointCloudInfo {
    return bridgeInspectPointCloud(filePath);
  }

  processPointCloud(inputPath: string, operation: string, optionsText: string,
    outputPath: string): GisGeoProcessResult {
    let result: GisGeoProcessResult = bridgeProcessPointCloud(inputPath, operation, optionsText, outputPath);
    return this.processingResultAfterOutputPolicy(result);
  }

  transformCoordinate(sourceDefinition: string, targetDefinition: string, x: number,
    y: number): GisCoordinateTransformResult {
    return bridgeTransformCoordinate(sourceDefinition, targetDefinition, x, y);
  }

  transformEnvelope(sourceDefinition: string, targetDefinition: string,
    envelope: GisEnvelope): GisEnvelopeTransformResult {
    return bridgeTransformEnvelope(sourceDefinition, targetDefinition, envelope);
  }

  moveLayer(fromIndex: number, toIndex: number): boolean {
    if (fromIndex < 0 || fromIndex >= this.layers.length) {
      return false;
    }
    if (toIndex < 0 || toIndex >= this.layers.length) {
      return false;
    }
    if (fromIndex === toIndex) {
      return true;
    }
    let movingLayer = this.layers[fromIndex];
    this.layers.splice(fromIndex, 1);
    this.layers.splice(toIndex, 0, movingLayer);
    this.activeLayerIndex = toIndex;
    return true;
  }

  getAllLayerNames(): string[] {
    let names: string[] = [];
    for (let i = 0; i < this.layers.length; i++) {
      names.push(this.layers[i].info.name);
    }
    return names;
  }

  findLayerIndexByName(layerName: string): number {
    for (let i = 0; i < this.layers.length; i++) {
      if (this.layers[i].info.name === layerName) {
        return i;
      }
    }
    return -1;
  }

  firstOtherLayerIndex(layerIndex: number): number {
    for (let i = 0; i < this.layers.length; i++) {
      if (i !== layerIndex) {
        return i;
      }
    }
    return -1;
  }

  isRasterLayerIndex(layerIndex: number): boolean {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return false;
    }
    return layer.info.geometryType === 0 && layer.info.fields.length === 0;
  }

  private isRasterLoadedLayer(layer: GisLoadedLayer): boolean {
    return layer.info.geometryType === 0 && layer.info.fields.length === 0;
  }

  private cloneEnvelope(env: GisEnvelope): GisEnvelope {
    return new GisEnvelope(env.minX, env.minY, env.maxX, env.maxY);
  }

  private cloneField(field: GisFieldInfo): GisFieldInfo {
    return new GisFieldInfo(field.name, field.alias, field.typeName, field.width, field.precision, field.nullable);
  }

  private cloneCoordinate(coord: GisCoordinate): GisCoordinate {
    let cloned: GisCoordinate = new GisCoordinate(coord.x, coord.y, coord.z, coord.hasZ, coord.m, coord.hasM);
    return cloned;
  }

  private cloneGeometry(geometry: GisGeometryPayload): GisGeometryPayload {
    let parts: GisGeometryPart[] = [];
    for (let pi = 0; pi < geometry.parts.length; pi++) {
      let sourcePart = geometry.parts[pi];
      let points: GisCoordinate[] = [];
      for (let ci = 0; ci < sourcePart.points.length; ci++) {
        points.push(this.cloneCoordinate(sourcePart.points[ci]));
      }
      parts.push(new GisGeometryPart(points));
    }
    return new GisGeometryPayload(geometry.geometryType, parts, this.cloneEnvelope(geometry.envelope), geometry.crs);
  }

  private cloneAttribute(attr: GisAttributeValue): GisAttributeValue {
    return new GisAttributeValue(attr.name, attr.typeName, attr.textValue, attr.numberValue, attr.boolValue,
      attr.isNull);
  }

  private cloneFeature(feature: GisFeatureSummary): GisFeatureSummary {
    let attrs: GisAttributeValue[] = [];
    for (let ai = 0; ai < feature.attributesPreview.length; ai++) {
      attrs.push(this.cloneAttribute(feature.attributesPreview[ai]));
    }
    return new GisFeatureSummary(feature.featureId, this.cloneGeometry(feature.geometry),
      this.cloneEnvelope(feature.envelope), attrs);
  }

  private cloneFeatureList(features: GisFeatureSummary[]): GisFeatureSummary[] {
    let result: GisFeatureSummary[] = [];
    for (let i = 0; i < features.length; i++) {
      result.push(this.cloneFeature(features[i]));
    }
    return result;
  }

  private cloneFieldList(fields: GisFieldInfo[]): GisFieldInfo[] {
    let result: GisFieldInfo[] = [];
    for (let i = 0; i < fields.length; i++) {
      result.push(this.cloneField(fields[i]));
    }
    return result;
  }

  private captureLayerSnapshot(layerIndex: number): GisLayerEditSnapshot | undefined {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return undefined;
    }
    return new GisLayerEditSnapshot(layerIndex, layer.info.featureCount, this.cloneEnvelope(layer.info.envelope),
      this.cloneFieldList(layer.info.fields), this.cloneFeatureList(layer.features));
  }

  private pushUndoSnapshot(layerIndex: number): boolean {
    let snapshot = this.captureLayerSnapshot(layerIndex);
    if (snapshot === undefined) {
      return false;
    }
    this.editUndoStack.push(snapshot);
    if (this.editUndoStack.length > 30) {
      this.editUndoStack.splice(0, 1);
    }
    this.editRedoStack = [];
    return true;
  }

  private restoreLayerSnapshot(snapshot: GisLayerEditSnapshot): boolean {
    let layer = this.getLayer(snapshot.layerIndex);
    if (layer === undefined) {
      return false;
    }
    layer.info.featureCount = snapshot.featureCount;
    layer.info.envelope = this.cloneEnvelope(snapshot.envelope);
    layer.info.fields = this.cloneFieldList(snapshot.fields);
    layer.features = this.cloneFeatureList(snapshot.features);
    this.activeLayerIndex = snapshot.layerIndex;
    return true;
  }

  private recalculateLayerEnvelope(layer: GisLoadedLayer): void {
    if (layer.features.length === 0) {
      layer.info.envelope = new GisEnvelope(0, 0, 0, 0);
      layer.info.featureCount = 0;
      return;
    }
    let minX = 1e18;
    let minY = 1e18;
    let maxX = -1e18;
    let maxY = -1e18;
    for (let i = 0; i < layer.features.length; i++) {
      let env = layer.features[i].envelope;
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
    layer.info.envelope = new GisEnvelope(minX, minY, maxX, maxY);
    layer.info.featureCount = layer.features.length;
  }

  private envelopeFromPoints(points: GisCoordinate[]): GisEnvelope {
    if (points.length === 0) {
      return new GisEnvelope(0, 0, 0, 0);
    }
    let minX = points[0].x;
    let minY = points[0].y;
    let maxX = points[0].x;
    let maxY = points[0].y;
    for (let i = 1; i < points.length; i++) {
      let point = points[i];
      if (point.x < minX) {
        minX = point.x;
      }
      if (point.y < minY) {
        minY = point.y;
      }
      if (point.x > maxX) {
        maxX = point.x;
      }
      if (point.y > maxY) {
        maxY = point.y;
      }
    }
    return new GisEnvelope(minX, minY, maxX, maxY);
  }

  private createEmptyAttributes(fields: GisFieldInfo[]): GisAttributeValue[] {
    let attrs: GisAttributeValue[] = [];
    for (let i = 0; i < fields.length; i++) {
      let field = fields[i];
      attrs.push(new GisAttributeValue(field.name, field.typeName, '', 0, false, true));
    }
    return attrs;
  }

  private findFeatureIndex(layer: GisLoadedLayer, featureId: string): number {
    for (let i = 0; i < layer.features.length; i++) {
      if (layer.features[i].featureId === featureId) {
        return i;
      }
    }
    return -1;
  }

  private setAttributeValue(attr: GisAttributeValue, value: string): void {
    attr.textValue = value;
    attr.numberValue = Number(value);
    attr.boolValue = value === 'true' || value === '1' || value === '是';
    attr.isNull = value.length === 0;
  }

  private rowMatchesText(row: GisFeatureSummary, filterText: string): boolean {
    if (filterText.length === 0) {
      return true;
    }
    let needle = filterText.toLowerCase();
    if (row.featureId.toLowerCase().indexOf(needle) >= 0) {
      return true;
    }
    for (let i = 0; i < row.attributesPreview.length; i++) {
      let attr = row.attributesPreview[i];
      if (attr.name.toLowerCase().indexOf(needle) >= 0) {
        return true;
      }
      if (attr.textValue.toLowerCase().indexOf(needle) >= 0) {
        return true;
      }
      if (attr.numberValue.toString().indexOf(needle) >= 0) {
        return true;
      }
    }
    return false;
  }

  // Open a vector or raster layer from file path. Returns index or -1 on failure.
  openLayer(filePath: string): number {
    let layerInfo = bridgeOpenVectorLayer(filePath);
    if (layerInfo === undefined) {
      layerInfo = bridgeOpenRasterLayer(filePath);
      if (layerInfo === undefined) {
        return -1;
      }
    }
    let loaded = new GisLoadedLayer(layerInfo, this.createLayerStyleFromInfo(layerInfo, this.layers.length),
      filePath);
    if (!this.isRasterLoadedLayer(loaded)) {
      // Query features using the layer's actual data envelope (not hardcoded 0-1)
      let env = layerInfo.envelope;
      let page = bridgeQueryFeatures(layerInfo.layerId, env.minX, env.minY, env.maxX, env.maxY,
        GIS_FEATURE_PREVIEW_LIMIT);
      if (page !== undefined) {
        loaded.features = page.features;
      }
    }
    this.layers.push(loaded);
    let newIndex = this.layers.length - 1;
    this.activeLayerIndex = newIndex;
    return newIndex;
  }

  tablePhysicalPath(sourcePath: string): string {
    let pipeIndex: number = sourcePath.indexOf('|');
    if (pipeIndex > 0) {
      return sourcePath.substring(0, pipeIndex);
    }
    return sourcePath;
  }

  listVectorSublayers(sourcePath: string): GisVectorSublayerInfo[] {
    let physicalPath: string = this.tablePhysicalPath(sourcePath);
    if (physicalPath.length === 0) {
      return [];
    }
    return bridgeListVectorSublayers(physicalPath);
  }

  openConfiguredTableLayer(sourceUri: string, separator: string): number {
    let configuredUri: string = sourceUri;
    if (separator !== 'AUTO' && separator.length > 0) {
      configuredUri += '|option:SEPARATOR=' + separator;
    }
    for (let i = 0; i < this.layers.length; i++) {
      if (this.layers[i].sourcePath === configuredUri) {
        this.activeLayerIndex = i;
        return i;
      }
    }
    return this.openLayer(configuredUri);
  }

  // Close a layer by index
  closeLayerByIndex(index: number): GisOperationResult {
    if (index < 0 || index >= this.layers.length) {
      return new GisOperationResult(false, 3, 'Invalid index');
    }
    if (this.isEditSessionActive(index)) {
      return new GisOperationResult(false, 4, '该图层仍在编辑，请先保存或放弃编辑');
    }
    let layerId = this.layers[index].info.layerId;
    let result = bridgeCloseLayer(layerId);
    if (result.ok) {
      this.layers.splice(index, 1);
      if (this.activeLayerIndex >= this.layers.length) {
        this.activeLayerIndex = this.layers.length - 1;
      }
    }
    return result;
  }

  // Toggle layer visibility
  toggleLayerVisibility(index: number): void {
    if (index >= 0 && index < this.layers.length) {
      this.layers[index].visible = !this.layers[index].visible;
    }
  }

  // Refresh features for a layer
  refreshFeatures(index: number): void {
    if (index < 0 || index >= this.layers.length) {
      return;
    }
    let layer = this.layers[index];
    if (this.isRasterLoadedLayer(layer)) {
      layer.features = [];
      return;
    }
    let env = layer.info.envelope;
    let page = bridgeQueryFeatures(layer.info.layerId, env.minX, env.minY, env.maxX, env.maxY,
      GIS_FEATURE_PREVIEW_LIMIT);
    if (page !== undefined) {
      layer.features = page.features;
    }
  }

  queryLayerFeatures(index: number, envelope: GisEnvelope, limit: number,
    offset: number = 0): GisFeaturePage | undefined {
    if (index < 0 || index >= this.layers.length || limit <= 0) {
      return undefined;
    }
    let layer = this.layers[index];
    if (this.isRasterLoadedLayer(layer)) {
      return undefined;
    }
    return bridgeQueryFeatures(layer.info.layerId, envelope.minX, envelope.minY, envelope.maxX, envelope.maxY,
      limit, offset);
  }

  getLayerFeatureById(index: number, featureId: string): GisFeatureSummary | undefined {
    if (index < 0 || index >= this.layers.length) {
      return undefined;
    }
    let fid = Number(featureId);
    if (fid !== fid) {
      return undefined;
    }
    return bridgeGetFeature(this.layers[index].info.layerId, fid);
  }

  refreshLayerInfo(index: number): GisOperationResult {
    if (index < 0 || index >= this.layers.length) {
      return new GisOperationResult(false, 3, 'Invalid index');
    }
    let layer = this.layers[index];
    let latestInfo = bridgeGetLayerInfo(layer.info.layerId);
    if (latestInfo === undefined) {
      return new GisOperationResult(false, 4, 'QGIS layer metadata refresh failed');
    }
    layer.info = latestInfo;
    this.refreshFeatures(index);
    return new GisOperationResult(true, 0, 'OK');
  }

  processingAlgorithmsJson(): string {
    return bridgeGetProcessingAlgorithms();
  }

  processingCatalog(): GisProcessingCatalog {
    return bridgeGetProcessingCatalog();
  }

  processingEnvironment(): ProcessingEnvironmentSnapshot {
    return ProcessingHistoryManager.getInstance().environment();
  }

  processingOutputDirectory(): string {
    return ProcessingHistoryManager.getInstance().outputDirectory();
  }

  processingHistory(): ProcessingTaskRecord[] {
    return ProcessingHistoryManager.getInstance().history();
  }

  clearProcessingHistory(): void {
    ProcessingHistoryManager.getInstance().clearHistory();
  }

  private processingParameterSummary(numericValue: number, textValue: string): string {
    let summary: string = 'numeric=' + numericValue.toString();
    let cleanText: string = textValue.trim();
    if (cleanText.length > 0) {
      if (cleanText.length > 240) {
        cleanText = cleanText.substring(0, 240);
      }
      summary += '; text=' + cleanText;
    }
    return summary;
  }

  private normalizedProcessingPath(path: string): string {
    let cleanPath: string = path.trim();
    let slashPath: string = '';
    for (let i: number = 0; i < cleanPath.length; i++) {
      let ch: string = cleanPath.charAt(i);
      slashPath += ch === '\\' ? '/' : ch;
    }
    let prefix: string = '';
    if (slashPath.startsWith('file://')) {
      prefix = 'file://';
      slashPath = slashPath.substring(7);
    }
    let absolutePath: boolean = slashPath.startsWith('/');
    let parts: string[] = slashPath.split('/');
    let normalizedParts: string[] = [];
    for (let i: number = 0; i < parts.length; i++) {
      let part: string = parts[i];
      if (part.length === 0 || part === '.') {
        continue;
      }
      if (part === '..') {
        if (normalizedParts.length > 0 && normalizedParts[normalizedParts.length - 1] !== '..') {
          normalizedParts.pop();
        } else if (!absolutePath) {
          normalizedParts.push(part);
        }
      } else {
        normalizedParts.push(part);
      }
    }
    let result: string = absolutePath ? '/' : '';
    for (let i: number = 0; i < normalizedParts.length; i++) {
      if (i > 0) {
        result += '/';
      }
      result += normalizedParts[i];
    }
    return prefix + result;
  }

  private processingOutputValidationMessage(outputPath: string): string {
    let managerMessage: string = ProcessingHistoryManager.getInstance().validateOutputPath(outputPath);
    if (managerMessage.length > 0) {
      return managerMessage;
    }
    let normalizedOutput: string = this.normalizedProcessingPath(outputPath);
    for (let i: number = 0; i < this.layers.length; i++) {
      let sourcePath: string = this.normalizedProcessingPath(this.layers[i].sourcePath);
      if (sourcePath.length > 0 && sourcePath === normalizedOutput) {
        return '输出路径与已加载图层的数据源相同；请更换输出名称或先移除该图层';
      }
    }
    return '';
  }

  private processingResultAfterOutputPolicy(result: GisGeoProcessResult): GisGeoProcessResult {
    result.outputLoaded = false;
    if (!result.ok || result.outputPath.length === 0 || !this.processingEnvironment().autoLoadOutput) {
      return result;
    }
    if (this.openLayer(result.outputPath) >= 0) {
      result.outputLoaded = true;
      return result;
    }
    let warningMessage: string = result.message;
    if (warningMessage.length > 0) {
      warningMessage += '；';
    }
    warningMessage += '输出已生成，但自动加载结果图层失败';
    return new GisGeoProcessResult(true, result.code, warningMessage, result.outputPath,
      result.outputLayerName, result.featureCount, result.executionId, result.elapsedMs, false);
  }

  private allLayerHandlesText(): string {
    let result = '';
    for (let i = 0; i < this.layers.length; i++) {
      let layer = this.layers[i];
      if (layer.info.layerId.length <= 1) {
        continue;
      }
      if (result.length > 0) {
        result += ';';
      }
      result += layer.info.layerId.substring(1);
    }
    return result;
  }

  private visibleLayerHandlesText(): string {
    let result: string = '';
    for (let i = 0; i < this.layers.length; i++) {
      let layer: GisLoadedLayer = this.layers[i];
      if (!layer.visible || layer.info.layerId.length <= 1) {
        continue;
      }
      if (result.length > 0) {
        result += ';';
      }
      result += layer.info.layerId.substring(1);
    }
    return result;
  }

  readQgisProject(projectPath: string): GisQgisProjectReadResult {
    return bridgeReadQgisProject(projectPath);
  }

  loadQgisProject(projectPath: string): GisQgisProjectReadResult {
    let projectResult = this.readQgisProject(projectPath);
    if (!projectResult.ok) {
      return projectResult;
    }
    this.clearAll();
    let loadedCount = 0;
    for (let i = 0; i < projectResult.layers.length; i++) {
      let layerRef: GisQgisProjectLayerRef = projectResult.layers[i];
      if (layerRef.sourcePath.length === 0) {
        continue;
      }
      let idx = this.openLayer(layerRef.sourcePath);
      if (idx >= 0) {
        this.setLayerVisibility(idx, layerRef.visible);
        loadedCount++;
      }
    }
    projectResult.loadedCount = loadedCount;
    if (loadedCount === 0 && projectResult.layerCount > 0) {
      projectResult.ok = false;
      projectResult.code = 3;
      projectResult.message = 'QGIS 工程已读取，但图层源文件无法加载';
    } else {
      projectResult.message = '已加载 QGIS 工程图层 ' + loadedCount.toString() + '/' +
        projectResult.layerCount.toString();
    }
    return projectResult;
  }

  saveQgisProject(projectPath: string, projectName: string, projectCrs: string): GisOperationResult {
    return bridgeWriteQgisProject(projectPath, projectName, projectCrs, this.allLayerHandlesText());
  }

  private copyProcessingResult(source: GisGeoProcessResult | null): GisGeoProcessResult | null {
    if (source === null) {
      return null;
    }
    return new GisGeoProcessResult(source.ok, source.code, source.message, source.outputPath,
      source.outputLayerName, source.featureCount, source.executionId, source.elapsedMs, source.outputLoaded);
  }

  private copyProcessingTaskSnapshot(source: GisProcessingTaskSnapshot): GisProcessingTaskSnapshot {
    return new GisProcessingTaskSnapshot(source.taskId, source.algorithmId, source.state, source.progress,
      source.processedCount, source.stage, source.message, source.errCode, source.elapsedMs,
      source.cancelRequested, source.done, this.copyProcessingResult(source.result));
  }

  private findPendingProcessingTask(taskId: string): GisPendingProcessingTask | undefined {
    for (let i: number = 0; i < this.processingTasks.length; i++) {
      if (this.processingTasks[i].snapshot.taskId === taskId) {
        return this.processingTasks[i];
      }
    }
    return undefined;
  }

  processingTask(taskId: string): GisProcessingTaskSnapshot | undefined {
    let pending: GisPendingProcessingTask | undefined = this.findPendingProcessingTask(taskId);
    if (pending === undefined) {
      return undefined;
    }
    return this.copyProcessingTaskSnapshot(pending.snapshot);
  }

  activeProcessingTasks(): GisProcessingTaskSnapshot[] {
    let result: GisProcessingTaskSnapshot[] = [];
    for (let i: number = 0; i < this.processingTasks.length; i++) {
      let pending: GisPendingProcessingTask = this.processingTasks[i];
      if (!pending.finalized) {
        result.push(this.copyProcessingTaskSnapshot(pending.snapshot));
      }
    }
    return result;
  }

  private failedProcessingTask(historyTaskId: string, request: GisProcessingTaskRequest,
    message: string, code: number): GisProcessingTaskSnapshot {
    let result: GisGeoProcessResult = new GisGeoProcessResult(false, code, message,
      request.outputPath, request.outputLayerName, 0, historyTaskId, 0);
    ProcessingHistoryManager.getInstance().finishTask(historyTaskId, result);
    let snapshot: GisProcessingTaskSnapshot = new GisProcessingTaskSnapshot(historyTaskId,
      request.algorithmId, GIS_PROCESSING_TASK_FAILED, 0, 0, GIS_PROCESSING_TASK_FAILED,
      message, code, 0, false, true, result);
    let pending: GisPendingProcessingTask = new GisPendingProcessingTask(historyTaskId, request, snapshot);
    pending.finalized = true;
    this.processingTasks.push(pending);
    this.trimProcessingTasks();
    ProcessingHistoryManager.getInstance().notifyTaskRevision();
    return this.copyProcessingTaskSnapshot(snapshot);
  }

  startProcessingAlgorithmTask(request: GisProcessingTaskRequest): GisProcessingTaskSnapshot {
    let inputLayer: GisLoadedLayer | undefined = this.getLayer(request.inputLayerIndex);
    if (inputLayer === undefined) {
      return this.failedProcessingTask('', request, '未选择输入图层', 3);
    }
    let overlayLayerId: string = '';
    let overlayLayerName: string = '';
    if (request.overlayLayerIndex >= 0) {
      let overlayLayer: GisLoadedLayer | undefined = this.getLayer(request.overlayLayerIndex);
      if (overlayLayer === undefined) {
        return this.failedProcessingTask('', request, '未选择叠加图层', 3);
      }
      overlayLayerId = overlayLayer.info.layerId;
      overlayLayerName = overlayLayer.info.name;
    }

    let historyManager: ProcessingHistoryManager = ProcessingHistoryManager.getInstance();
    let historyTaskId: string = historyManager.startTask(request.algorithmId, inputLayer.info.name,
      overlayLayerName, this.processingParameterSummary(request.numericValue, request.textValue),
      request.outputPath, request.outputLayerName);
    let validationMessage: string = this.processingOutputValidationMessage(request.outputPath);
    if (validationMessage.length > 0) {
      return this.failedProcessingTask(historyTaskId, request, validationMessage, 6);
    }
    if (this.isEditSessionActive(request.inputLayerIndex) ||
      (request.overlayLayerIndex >= 0 && this.isEditSessionActive(request.overlayLayerIndex))) {
      return this.failedProcessingTask(historyTaskId, request,
        '后台处理前请先提交或回滚图层编辑', 6);
    }

    let snapshot: GisProcessingTaskSnapshot = bridgeStartProcessingTask(request.algorithmId,
      inputLayer.info.layerId, overlayLayerId, request.numericValue, request.textValue,
      request.outputPath, request.outputLayerName, historyTaskId, historyManager.environmentJson());
    snapshot.algorithmId = request.algorithmId;
    if (snapshot.taskId.length === 0) {
      let startMessage: string = snapshot.message.length > 0 ? snapshot.message : '后台处理任务启动失败';
      return this.failedProcessingTask(historyTaskId, request, startMessage,
        snapshot.errCode !== 0 ? snapshot.errCode : 5);
    }

    let pending: GisPendingProcessingTask = new GisPendingProcessingTask(historyTaskId, request, snapshot);
    this.processingTasks.push(pending);
    if (snapshot.done) {
      this.finalizeProcessingTask(pending);
    } else {
      this.ensureProcessingPolling();
      historyManager.notifyTaskRevision();
    }
    return this.copyProcessingTaskSnapshot(pending.snapshot);
  }

  cancelProcessingTask(taskId: string): GisProcessingTaskSnapshot | undefined {
    let pending: GisPendingProcessingTask | undefined = this.findPendingProcessingTask(taskId);
    if (pending === undefined || pending.finalized) {
      return pending === undefined ? undefined : this.copyProcessingTaskSnapshot(pending.snapshot);
    }
    let snapshot: GisProcessingTaskSnapshot = bridgeCancelProcessingTask(taskId);
    snapshot.algorithmId = pending.request.algorithmId;
    if (snapshot.state === GIS_PROCESSING_TASK_STATUS_UNAVAILABLE) {
      pending.snapshot.message = snapshot.message;
      ProcessingHistoryManager.getInstance().notifyTaskRevision();
      return this.copyProcessingTaskSnapshot(pending.snapshot);
    }
    pending.snapshot = snapshot;
    if (snapshot.done) {
      this.finalizeProcessingTask(pending);
    } else {
      ProcessingHistoryManager.getInstance().notifyTaskRevision();
    }
    return this.copyProcessingTaskSnapshot(pending.snapshot);
  }

  private ensureProcessingPolling(): void {
    if (this.processingPollTimer >= 0) {
      return;
    }
    this.processingPollTimer = setInterval((): void => {
      this.pollProcessingTasks();
    }, 250);
  }

  private pollProcessingTasks(): void {
    let hasActiveTask: boolean = false;
    let changed: boolean = false;
    for (let i: number = 0; i < this.processingTasks.length; i++) {
      let pending: GisPendingProcessingTask = this.processingTasks[i];
      if (pending.finalized) {
        continue;
      }
      let snapshot: GisProcessingTaskSnapshot = bridgeGetProcessingTaskStatus(pending.snapshot.taskId);
      snapshot.algorithmId = pending.request.algorithmId;
      if (snapshot.state === GIS_PROCESSING_TASK_STATUS_UNAVAILABLE) {
        pending.snapshot.message = snapshot.message;
        hasActiveTask = true;
        changed = true;
        continue;
      }
      if (snapshot.state === GIS_PROCESSING_TASK_NOT_FOUND) {
        snapshot.state = GIS_PROCESSING_TASK_FAILED;
        snapshot.done = true;
        snapshot.errCode = 5;
        snapshot.message = '后台处理任务状态已丢失';
      }
      pending.snapshot = snapshot;
      changed = true;
      if (snapshot.done) {
        this.finalizeProcessingTask(pending);
      } else {
        hasActiveTask = true;
      }
    }
    if (!hasActiveTask && this.processingPollTimer >= 0) {
      clearInterval(this.processingPollTimer);
      this.processingPollTimer = -1;
    }
    if (changed) {
      ProcessingHistoryManager.getInstance().notifyTaskRevision();
    }
  }

  private applyBackgroundProcessingStyle(algorithmId: string, result: GisGeoProcessResult): void {
    if (!result.ok || !result.outputLoaded) {
      return;
    }
    let activeIndex: number = this.getActiveLayerIndex();
    let layer: GisLoadedLayer | undefined = this.getLayer(activeIndex);
    if (layer === undefined) {
      return;
    }
    if (algorithmId === 'kernel_density' || algorithmId === 'point_density' ||
      algorithmId === 'line_density' || algorithmId === 'idw' || algorithmId === 'raster_slope' ||
      algorithmId === 'raster_aspect' || algorithmId === 'raster_reclassify' || algorithmId === 'chm' ||
      algorithmId === 'earthwork' || algorithmId === 'surface_area' || algorithmId === 'dsm' ||
      algorithmId === 'dtm' || algorithmId === 'line_of_sight' || algorithmId === 'viewshed') {
      if (this.isRasterLoadedLayer(layer)) {
        let rasterStyle: GisLayerStyle = layer.style;
        rasterStyle.rasterStretchMode = 1;
        rasterStyle.rasterColorRamp = 1;
        if (algorithmId === 'raster_slope' || algorithmId === 'raster_aspect' ||
          algorithmId === 'raster_reclassify' || algorithmId === 'chm' || algorithmId === 'earthwork' ||
          algorithmId === 'surface_area') {
          rasterStyle.rasterOpacity = 0.86;
        } else {
          rasterStyle.rasterOpacity = 0.82;
        }
        this.updateLayerStyle(activeIndex, rasterStyle);
      }
      return;
    }
    if (algorithmId === 'quality_check' && !this.isRasterLoadedLayer(layer)) {
      let qualityStyle: GisLayerStyle = layer.style;
      qualityStyle.rendererMode = 0;
      qualityStyle.rendererField = '';
      qualityStyle.pointColor = '#D92D20';
      qualityStyle.lineColor = '#D92D20';
      qualityStyle.fillColor = '#FEE4E2';
      qualityStyle.strokeColor = '#B42318';
      qualityStyle.pointRadius = 8;
      qualityStyle.opacity = 0.96;
      qualityStyle.symbolName = '质检错误点';
      this.updateLayerStyle(activeIndex, qualityStyle);
    }
  }

  private finalizeProcessingTask(pending: GisPendingProcessingTask): void {
    if (pending.finalized) {
      return;
    }
    pending.finalized = true;
    let result: GisGeoProcessResult | null = pending.snapshot.result;
    if (result === null) {
      let code: number = pending.snapshot.state === GIS_PROCESSING_TASK_CANCELED ? 8 :
        (pending.snapshot.errCode !== 0 ? pending.snapshot.errCode : 5);
      let message: string = pending.snapshot.message.length > 0 ? pending.snapshot.message :
        (code === 8 ? '处理任务已取消' : '后台处理任务失败');
      result = new GisGeoProcessResult(false, code, message, pending.request.outputPath,
        pending.request.outputLayerName, 0, pending.historyTaskId, pending.snapshot.elapsedMs);
    }
    if (pending.snapshot.state === GIS_PROCESSING_TASK_CANCELED) {
      result.ok = false;
      result.code = 8;
      result.message = '处理任务已取消';
    }
    if (result.executionId.length === 0) {
      result.executionId = pending.historyTaskId;
    }
    if (result.elapsedMs <= 0) {
      result.elapsedMs = pending.snapshot.elapsedMs;
    }
    if (result.outputPath.length === 0) {
      result.outputPath = pending.request.outputPath;
    }
    if (result.outputLayerName.length === 0) {
      result.outputLayerName = pending.request.outputLayerName;
    }
    result = this.processingResultAfterOutputPolicy(result);
    this.applyBackgroundProcessingStyle(pending.request.algorithmId, result);
    pending.snapshot.result = result;
    pending.snapshot.errCode = result.code;
    pending.snapshot.elapsedMs = result.elapsedMs;
    pending.snapshot.message = result.message;
    pending.snapshot.done = true;
    pending.snapshot.progress = result.code === 8 ? pending.snapshot.progress : 100;
    if (result.code === 8) {
      pending.snapshot.state = GIS_PROCESSING_TASK_CANCELED;
    } else {
      pending.snapshot.state = result.ok ? GIS_PROCESSING_TASK_SUCCEEDED : GIS_PROCESSING_TASK_FAILED;
    }
    ProcessingHistoryManager.getInstance().finishTask(pending.historyTaskId, result);
    bridgeReleaseProcessingTask(pending.snapshot.taskId);
    this.trimProcessingTasks();
    ProcessingHistoryManager.getInstance().notifyTaskRevision();
  }

  private trimProcessingTasks(): void {
    while (this.processingTasks.length > 50) {
      let removed: boolean = false;
      for (let i: number = 0; i < this.processingTasks.length; i++) {
        if (this.processingTasks[i].finalized) {
          this.processingTasks.splice(i, 1);
          removed = true;
          break;
        }
      }
      if (!removed) {
        return;
      }
    }
  }

  runProcessingAlgorithm(algorithmId: string, inputLayerIndex: number, overlayLayerIndex: number,
    numericValue: number, textValue: string, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    let inputLayer = this.getLayer(inputLayerIndex);
    if (inputLayer === undefined) {
      return new GisGeoProcessResult(false, 3, '未选择输入图层', outputPath, outputLayerName, 0);
    }
    let overlayLayerId: string = '';
    let overlayLayerName: string = '';
    if (overlayLayerIndex >= 0) {
      let overlayLayer = this.getLayer(overlayLayerIndex);
      if (overlayLayer === undefined) {
        return new GisGeoProcessResult(false, 3, '未选择叠加图层', outputPath, outputLayerName, 0);
      }
      overlayLayerId = overlayLayer.info.layerId;
      overlayLayerName = overlayLayer.info.name;
    }
    let historyManager: ProcessingHistoryManager = ProcessingHistoryManager.getInstance();
    let taskId: string = historyManager.startTask(algorithmId, inputLayer.info.name, overlayLayerName,
      this.processingParameterSummary(numericValue, textValue), outputPath, outputLayerName);
    let validationMessage: string = this.processingOutputValidationMessage(outputPath);
    if (validationMessage.length > 0) {
      let invalidResult: GisGeoProcessResult = new GisGeoProcessResult(false, 6, validationMessage,
        outputPath, outputLayerName, 0, taskId, 0);
      historyManager.finishTask(taskId, invalidResult);
      return invalidResult;
    }
    let result: GisGeoProcessResult = bridgeExecuteProcessingAlgorithm(algorithmId, inputLayer.info.layerId,
      overlayLayerId, numericValue, textValue, outputPath, outputLayerName, taskId,
      historyManager.environmentJson());
    result = this.processingResultAfterOutputPolicy(result);
    historyManager.finishTask(taskId, result);
    return result;
  }

  runConvexHull(layerIndex: number, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('convex_hull', layerIndex, -1, 0, '', outputPath, outputLayerName);
  }

  runBoundingBoxes(layerIndex: number, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('bounding_boxes', layerIndex, -1, 0, '', outputPath, outputLayerName);
  }

  runMultipartToSingleparts(layerIndex: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('multipart_to_singleparts', layerIndex, -1, 0, '',
      outputPath, outputLayerName);
  }

  runExtractByExpression(layerIndex: number, expression: string, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('extract_by_expression', layerIndex, -1, 0, expression,
      outputPath, outputLayerName);
  }

  runDifference(inputLayerIndex: number, overlayLayerIndex: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('difference', inputLayerIndex, overlayLayerIndex, 0, '',
      outputPath, outputLayerName);
  }

  runSymmetricalDifference(inputLayerIndex: number, overlayLayerIndex: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('symmetrical_difference', inputLayerIndex, overlayLayerIndex, 0, '',
      outputPath, outputLayerName);
  }

  runMergeLayers(firstLayerIndex: number, secondLayerIndex: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('merge_layers', firstLayerIndex, secondLayerIndex, 0, '',
      outputPath, outputLayerName);
  }

  runMultiRingBuffer(layerIndex: number, distanceList: string, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('multi_ring_buffer', layerIndex, -1, 0, distanceList,
      outputPath, outputLayerName);
  }

  runExtractByLocation(inputLayerIndex: number, overlayLayerIndex: number, predicateMode: number,
    outputPath: string, outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('extract_by_location', inputLayerIndex, overlayLayerIndex,
      predicateMode, '', outputPath, outputLayerName);
  }

  runSpatialJoinSummary(inputLayerIndex: number, joinLayerIndex: number, predicateMode: number,
    outputPath: string, outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('spatial_join_summary', inputLayerIndex, joinLayerIndex,
      predicateMode, '', outputPath, outputLayerName);
  }

  runIntersection(inputLayerIndex: number, overlayLayerIndex: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('intersection', inputLayerIndex, overlayLayerIndex, 0, '',
      outputPath, outputLayerName);
  }

  runNearestNeighbor(inputLayerIndex: number, targetLayerIndex: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('nearest_neighbor', inputLayerIndex, targetLayerIndex, 0, '',
      outputPath, outputLayerName);
  }

  runVoronoi(layerIndex: number, tolerance: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('voronoi', layerIndex, -1, tolerance, '',
      outputPath, outputLayerName);
  }

  runOrientedMinimumBoundingBox(layerIndex: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('oriented_minimum_bounding_box', layerIndex, -1, 0, '',
      outputPath, outputLayerName);
  }

  private kernelDensityTextValue(cellSize: number, populationField: string, areaUnit: string): string {
    let cleanPopulationField = populationField.trim();
    if (cleanPopulationField.length === 0) {
      cleanPopulationField = 'NONE';
    }
    let cleanAreaUnit = areaUnit.trim();
    if (cleanAreaUnit.length === 0) {
      cleanAreaUnit = 'SQUARE_MAP_UNITS';
    }
    return 'cellSize=' + cellSize.toString() + ';populationField=' + cleanPopulationField +
      ';areaUnit=' + cleanAreaUnit;
  }

  runKernelDensity(layerIndex: number, searchRadius: number, cellSize: number, populationField: string,
    areaUnit: string, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    let textValue = this.kernelDensityTextValue(cellSize, populationField, areaUnit);
    let result = this.runProcessingAlgorithm('kernel_density', layerIndex, -1, searchRadius, textValue,
      outputPath, outputLayerName);
    if (result.ok && result.outputLoaded) {
      let activeIndex = this.getActiveLayerIndex();
      let layer = this.getLayer(activeIndex);
      if (layer !== undefined && this.isRasterLoadedLayer(layer)) {
        let style = layer.style;
        style.rasterStretchMode = 1;
        style.rasterColorRamp = 1;
        style.rasterOpacity = 0.82;
        this.updateLayerStyle(activeIndex, style);
      }
    }
    return result;
  }

  runPointDensity(layerIndex: number, searchRadius: number, cellSize: number, populationField: string,
    areaUnit: string, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    let textValue = this.kernelDensityTextValue(cellSize, populationField, areaUnit);
    let result = this.runProcessingAlgorithm('point_density', layerIndex, -1, searchRadius, textValue,
      outputPath, outputLayerName);
    if (result.ok && result.outputLoaded) {
      let activeIndex = this.getActiveLayerIndex();
      let layer = this.getLayer(activeIndex);
      if (layer !== undefined && this.isRasterLoadedLayer(layer)) {
        let style = layer.style;
        style.rasterStretchMode = 1;
        style.rasterColorRamp = 1;
        style.rasterOpacity = 0.82;
        this.updateLayerStyle(activeIndex, style);
      }
    }
    return result;
  }

  runLineDensity(layerIndex: number, searchRadius: number, cellSize: number, populationField: string,
    areaUnit: string, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    let textValue = this.kernelDensityTextValue(cellSize, populationField, areaUnit);
    let result = this.runProcessingAlgorithm('line_density', layerIndex, -1, searchRadius, textValue,
      outputPath, outputLayerName);
    if (result.ok && result.outputLoaded) {
      let activeIndex = this.getActiveLayerIndex();
      let layer = this.getLayer(activeIndex);
      if (layer !== undefined && this.isRasterLoadedLayer(layer)) {
        let style = layer.style;
        style.rasterStretchMode = 1;
        style.rasterColorRamp = 1;
        style.rasterOpacity = 0.82;
        this.updateLayerStyle(activeIndex, style);
      }
    }
    return result;
  }

  private idwTextValue(cellSize: number, valueField: string, power: string): string {
    let cleanValueField = valueField.trim();
    if (cleanValueField.length === 0) {
      cleanValueField = 'NONE';
    }
    let cleanPower = power.trim();
    if (cleanPower.length === 0) {
      cleanPower = '2';
    }
    return 'cellSize=' + cellSize.toString() + ';valueField=' + cleanValueField + ';power=' + cleanPower;
  }

  runIdwInterpolation(layerIndex: number, searchRadius: number, cellSize: number, valueField: string,
    power: string, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    let textValue = this.idwTextValue(cellSize, valueField, power);
    let result = this.runProcessingAlgorithm('idw', layerIndex, -1, searchRadius, textValue,
      outputPath, outputLayerName);
    if (result.ok && result.outputLoaded) {
      let activeIndex = this.getActiveLayerIndex();
      let layer = this.getLayer(activeIndex);
      if (layer !== undefined && this.isRasterLoadedLayer(layer)) {
        let style = layer.style;
        style.rasterStretchMode = 1;
        style.rasterColorRamp = 1;
        style.rasterOpacity = 0.82;
        this.updateLayerStyle(activeIndex, style);
      }
    }
    return result;
  }

  runRasterSlope(layerIndex: number, zFactor: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    let result = this.runProcessingAlgorithm('raster_slope', layerIndex, -1, zFactor, '',
      outputPath, outputLayerName);
    if (result.ok && result.outputLoaded) {
      let activeIndex = this.getActiveLayerIndex();
      let layer = this.getLayer(activeIndex);
      if (layer !== undefined && this.isRasterLoadedLayer(layer)) {
        let style = layer.style;
        style.rasterStretchMode = 1;
        style.rasterColorRamp = 1;
        style.rasterOpacity = 0.86;
        this.updateLayerStyle(activeIndex, style);
      }
    }
    return result;
  }

  runRasterAspect(layerIndex: number, zFactor: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    let result = this.runProcessingAlgorithm('raster_aspect', layerIndex, -1, zFactor, '',
      outputPath, outputLayerName);
    if (result.ok && result.outputLoaded) {
      let activeIndex = this.getActiveLayerIndex();
      let layer = this.getLayer(activeIndex);
      if (layer !== undefined && this.isRasterLoadedLayer(layer)) {
        let style = layer.style;
        style.rasterStretchMode = 1;
        style.rasterColorRamp = 1;
        style.rasterOpacity = 0.86;
        this.updateLayerStyle(activeIndex, style);
      }
    }
    return result;
  }

  runRasterReclassify(layerIndex: number, rules: string, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    let result = this.runProcessingAlgorithm('raster_reclassify', layerIndex, -1, 0, rules,
      outputPath, outputLayerName);
    if (result.ok && result.outputLoaded) {
      let activeIndex = this.getActiveLayerIndex();
      let layer = this.getLayer(activeIndex);
      if (layer !== undefined && this.isRasterLoadedLayer(layer)) {
        let style = layer.style;
        style.rasterStretchMode = 1;
        style.rasterColorRamp = 1;
        style.rasterOpacity = 0.86;
        this.updateLayerStyle(activeIndex, style);
      }
    }
    return result;
  }

  runQualityCheck(layerIndex: number, requiredFields: string, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    let result = this.runProcessingAlgorithm('quality_check', layerIndex, -1, 0, requiredFields,
      outputPath, outputLayerName);
    if (result.ok && result.outputLoaded) {
      let activeIndex = this.getActiveLayerIndex();
      let layer = this.getLayer(activeIndex);
      if (layer !== undefined && !this.isRasterLoadedLayer(layer)) {
        let style = layer.style;
        style.rendererMode = 0;
        style.rendererField = '';
        style.pointColor = '#D92D20';
        style.lineColor = '#D92D20';
        style.fillColor = '#FEE4E2';
        style.strokeColor = '#B42318';
        style.pointRadius = 8;
        style.opacity = 0.96;
        style.symbolName = '质检错误点';
        this.updateLayerStyle(activeIndex, style);
      }
    }
    return result;
  }

  validateTopologyRules(sourceLayerIndex: number, targetLayerIndex: number, rulesText: string,
    dirtyExtentText: string, tolerance: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    let source: GisLoadedLayer | undefined = this.getLayer(sourceLayerIndex);
    if (source === undefined || this.isRasterLoadedLayer(source)) {
      return new GisGeoProcessResult(false, 3, '请选择矢量源图层', outputPath, outputLayerName, 0);
    }
    let target: GisLoadedLayer = source;
    let candidate: GisLoadedLayer | undefined = this.getLayer(targetLayerIndex);
    if (candidate !== undefined && !this.isRasterLoadedLayer(candidate)) {
      target = candidate;
    }
    let validation: string = this.processingOutputValidationMessage(outputPath);
    if (validation.length > 0) {
      return new GisGeoProcessResult(false, 4, validation, outputPath, outputLayerName, 0);
    }
    let result: GisGeoProcessResult = bridgeValidateTopologyRules(source.info.layerId, target.info.layerId,
      rulesText, dirtyExtentText, tolerance, outputPath, outputLayerName);
    result = this.processingResultAfterOutputPolicy(result);
    if (result.ok && result.outputLoaded) {
      let errorLayerIndex: number = this.getActiveLayerIndex();
      let errorLayer: GisLoadedLayer | undefined = this.getLayer(errorLayerIndex);
      if (errorLayer !== undefined) {
        let style: GisLayerStyle = errorLayer.style;
        style.pointColor = '#D92D20';
        style.strokeColor = '#B42318';
        style.pointRadius = 8;
        style.opacity = 0.96;
        style.symbolName = '拓扑规则错误';
        this.updateLayerStyle(errorLayerIndex, style);
      }
    }
    return result;
  }

  repairTopologyIssues(sourceLayerIndex: number, targetLayerIndex: number, featureIds: string[],
    strategy: string, tolerance: number, previewOnly: boolean, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    let source: GisLoadedLayer | undefined = this.getLayer(sourceLayerIndex);
    if (source === undefined || this.isRasterLoadedLayer(source)) {
      return new GisGeoProcessResult(false, 3, '请选择可编辑矢量图层', outputPath, outputLayerName, 0);
    }
    if (featureIds.length === 0) {
      return new GisGeoProcessResult(false, 4, '请选择至少一个待修复要素', outputPath, outputLayerName, 0);
    }
    let target: GisLoadedLayer = source;
    let candidate: GisLoadedLayer | undefined = this.getLayer(targetLayerIndex);
    if (candidate !== undefined && !this.isRasterLoadedLayer(candidate)) {
      target = candidate;
    }
    if (!previewOnly && !this.isEditing(sourceLayerIndex)) {
      let beginResult: GisOperationResult = this.beginEditSession(sourceLayerIndex);
      if (!beginResult.ok) {
        return new GisGeoProcessResult(false, beginResult.code, beginResult.message, outputPath,
          outputLayerName, 0);
      }
    }
    let idsText: string = '';
    for (let i = 0; i < featureIds.length; i++) {
      if (idsText.length > 0) {
        idsText += ';';
      }
      idsText += featureIds[i];
    }
    let result: GisGeoProcessResult = bridgeRepairTopologyIssues(source.info.layerId, target.info.layerId,
      idsText, strategy, tolerance, previewOnly, outputPath, outputLayerName);
    if (previewOnly) {
      return this.processingResultAfterOutputPolicy(result);
    }
    if (result.ok) {
      this.refreshLayerInfo(sourceLayerIndex);
    }
    return result;
  }

  selectProviderFeaturesByGeometry(layerIndex: number, selectionWkt: string,
    predicateMode: number): GisSpatialSelectionResult {
    let layer: GisLoadedLayer | undefined = this.getLayer(layerIndex);
    if (layer === undefined || this.isRasterLoadedLayer(layer)) {
      return new GisSpatialSelectionResult(false, 3, [], 0, false, '请选择矢量图层');
    }
    return bridgeSelectFeaturesByGeometry(layer.info.layerId, selectionWkt, predicateMode);
  }

  selectProviderFeaturesAcrossLayers(selectionWkt: string, predicateMode: number,
    visibleOnly: boolean): GisLayerSelection[] {
    let selections: GisLayerSelection[] = [];
    for (let i = 0; i < this.layers.length; i++) {
      let layer: GisLoadedLayer = this.layers[i];
      if (this.isRasterLoadedLayer(layer) || (visibleOnly && !layer.visible)) {
        continue;
      }
      let result: GisSpatialSelectionResult = bridgeSelectFeaturesByGeometry(layer.info.layerId,
        selectionWkt, predicateMode);
      if (result.ok && result.featureIds.length > 0) {
        selections.push(new GisLayerSelection(i, layer.info.name, result.featureIds));
      }
    }
    return selections;
  }

  runXYTableToPoints(layerIndex: number, xFieldIndex: number, yFieldIndex: number,
    zFieldIndex: number, mFieldIndex: number, crsDefinition: string, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    let cleanCrs: string = crsDefinition.trim();
    if (cleanCrs.length === 0) {
      cleanCrs = 'EPSG:4326';
    }
    let options: GisXYTableProcessingOptions = new GisXYTableProcessingOptions(xFieldIndex, yFieldIndex,
      zFieldIndex, mFieldIndex, cleanCrs);
    let textValue: string = JSON.stringify(options);
    return this.runProcessingAlgorithm('xy_table_to_points', layerIndex, -1, 0, textValue,
      outputPath, outputLayerName);
  }

  runPortableProject(outputPath: string, projectName: string, projectCrs: string): GisGeoProcessResult {
    if (this.layers.length === 0) {
      return new GisGeoProcessResult(false, 3, '当前没有可打包图层', outputPath, projectName, 0);
    }
    let options: GisPortableProjectProcessingOptions = new GisPortableProjectProcessingOptions(
      projectName, projectCrs, this.allLayerHandlesText(), this.visibleLayerHandlesText());
    let historyManager: ProcessingHistoryManager = ProcessingHistoryManager.getInstance();
    let taskId: string = historyManager.startTask('portable_project', projectName, '',
      'projectCrs=' + projectCrs, outputPath, projectName);
    let validationMessage: string = this.processingOutputValidationMessage(outputPath);
    if (validationMessage.length > 0) {
      let invalidResult: GisGeoProcessResult = new GisGeoProcessResult(false, 6, validationMessage,
        outputPath, projectName, 0, taskId, 0);
      historyManager.finishTask(taskId, invalidResult);
      return invalidResult;
    }
    let result: GisGeoProcessResult = bridgeExecuteProcessingAlgorithm('portable_project', '', '', 0,
      JSON.stringify(options), outputPath, projectName, taskId, historyManager.environmentJson());
    historyManager.finishTask(taskId, result);
    return result;
  }

  runLayoutAtlas(coverageLayerIndex: number, outputPath: string, format: string, title: string,
    filterExpression: string, margin: number, width: number, height: number,
    basemapMode: number, basemapLabel: string, sortField: string, groupField: string,
    pageNameField: string, dynamicTitle: string, sortAscending: boolean): GisGeoProcessResult {
    let coverageLayer: GisLoadedLayer | undefined = this.getLayer(coverageLayerIndex);
    if (coverageLayer === undefined) {
      return new GisGeoProcessResult(false, 3, '未选择地图集覆盖图层', outputPath, title, 0);
    }
    if (this.isRasterLoadedLayer(coverageLayer)) {
      return new GisGeoProcessResult(false, 4, '地图集覆盖图层必须是矢量图层', outputPath, title, 0);
    }
    let visibleHandles: string = this.visibleLayerHandlesText();
    let coverageHandle: string = coverageLayer.info.layerId.length > 1 ? coverageLayer.info.layerId.substring(1) : '';
    if (coverageHandle.length > 0 && !this.handleTextContains(visibleHandles, coverageHandle)) {
      visibleHandles = visibleHandles.length > 0 ? visibleHandles + ';' + coverageHandle : coverageHandle;
    }
    let options: GisAtlasProcessingOptions = new GisAtlasProcessingOptions(title, format, filterExpression,
      margin, width, height, basemapMode, basemapLabel, visibleHandles, sortField, groupField,
      pageNameField, dynamicTitle, sortAscending);
    let historyManager: ProcessingHistoryManager = ProcessingHistoryManager.getInstance();
    let taskId: string = historyManager.startTask('layout_atlas', coverageLayer.info.name, '',
      'format=' + format + '; margin=' + margin.toString(), outputPath, title);
    let validationMessage: string = this.processingOutputValidationMessage(outputPath);
    if (validationMessage.length > 0) {
      let invalidResult: GisGeoProcessResult = new GisGeoProcessResult(false, 6, validationMessage,
        outputPath, title, 0, taskId, 0);
      historyManager.finishTask(taskId, invalidResult);
      return invalidResult;
    }
    let result: GisGeoProcessResult = bridgeExecuteProcessingAlgorithm('layout_atlas', coverageLayer.info.layerId,
      '', margin, JSON.stringify(options), outputPath, title, taskId, historyManager.environmentJson());
    historyManager.finishTask(taskId, result);
    return result;
  }

  private handleTextContains(handles: string, expectedHandle: string): boolean {
    let items: string[] = handles.split(';');
    for (let i = 0; i < items.length; i++) {
      if (items[i] === expectedHandle) {
        return true;
      }
    }
    return false;
  }

  runBuffer(layerIndex: number, distance: number, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('buffer', layerIndex, -1, distance, '', outputPath, outputLayerName);
  }

  runSimplify(layerIndex: number, tolerance: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('simplify', layerIndex, -1, tolerance, '', outputPath, outputLayerName);
  }

  runDissolve(layerIndex: number, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('dissolve', layerIndex, -1, 0, '', outputPath, outputLayerName);
  }

  runCentroid(layerIndex: number, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('centroid', layerIndex, -1, 0, '', outputPath, outputLayerName);
  }

  runRepair(layerIndex: number, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('repair', layerIndex, -1, 0, '', outputPath, outputLayerName);
  }

  runClip(inputLayerIndex: number, clipLayerIndex: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('clip', inputLayerIndex, clipLayerIndex, 0, '',
      outputPath, outputLayerName);
  }

  runExport(layerIndex: number, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    return this.runProcessingAlgorithm('export', layerIndex, -1, 0, '', outputPath, outputLayerName);
  }

  runExportToFormat(layerIndex: number, outputPath: string, outputLayerName: string,
    driverName: string): GisGeoProcessResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisGeoProcessResult(false, 3, '未选择输入图层', outputPath, outputLayerName, 0);
    }
    let historyManager: ProcessingHistoryManager = ProcessingHistoryManager.getInstance();
    let taskId: string = historyManager.startTask('export_format', layer.info.name, '',
      'driver=' + driverName, outputPath, outputLayerName);
    let validationMessage: string = this.processingOutputValidationMessage(outputPath);
    if (validationMessage.length > 0) {
      let invalidResult: GisGeoProcessResult = new GisGeoProcessResult(false, 6, validationMessage,
        outputPath, outputLayerName, 0, taskId, 0);
      historyManager.finishTask(taskId, invalidResult);
      return invalidResult;
    }
    let startedAt: number = Date.now();
    let result: GisGeoProcessResult = bridgeExportLayerToFormat(layer.info.layerId, outputPath, outputLayerName,
      driverName);
    result.executionId = taskId;
    result.elapsedMs = Math.max(0, Date.now() - startedAt);
    result = this.processingResultAfterOutputPolicy(result);
    historyManager.finishTask(taskId, result);
    return result;
  }

  runDefineProjection(layerIndex: number, targetDefinition: string, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    if (targetDefinition.trim().length === 0) {
      return new GisGeoProcessResult(false, 6, '未填写目标坐标系', outputPath, outputLayerName, 0);
    }
    return this.runProcessingAlgorithm('define_projection', layerIndex, -1, 0, targetDefinition,
      outputPath, outputLayerName);
  }

  runProjectLayer(layerIndex: number, targetDefinition: string, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    if (targetDefinition.trim().length === 0) {
      return new GisGeoProcessResult(false, 6, '未填写目标坐标系', outputPath, outputLayerName, 0);
    }
    return this.runProcessingAlgorithm('project', layerIndex, -1, 0, targetDefinition,
      outputPath, outputLayerName);
  }

  updateLayerStyle(layerIndex: number, style: GisLayerStyle): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择图层');
    }
    if (this.isRasterLoadedLayer(layer)) {
      let rasterResult = bridgeConfigureRasterDisplay(layer.info.layerId, style.rasterBandMode,
        style.rasterStretchMode, style.rasterColorRamp, style.rasterOpacity, style.rasterNoData,
        style.rasterTransparentColor, style.rasterHillshade);
      if (rasterResult.ok) {
        layer.style = style;
        let rasterInfo = bridgeGetLayerInfo(layer.info.layerId);
        if (rasterInfo !== undefined) {
          layer.info = rasterInfo;
        }
      }
      return rasterResult;
    }
    let styleResult = bridgeApplyVectorStyle(layer.info.layerId, style.rendererMode, style.rendererField,
      style.colorRamp, style.linePattern, style.fillPattern, style.pointColor, style.lineColor, style.fillColor,
      style.strokeColor, style.lineWidth, style.pointRadius, style.opacity, style.symbolName);
    if (!styleResult.ok) {
      return styleResult;
    }
    let labelResult = bridgeApplyVectorLabeling(layer.info.layerId, style.labelEnabled, style.labelField,
      style.labelSize, style.labelColor, style.labelHalo, style.labelAvoidance, style.labelMinScale,
      style.labelMaxScale);
    if (!labelResult.ok) {
      return labelResult;
    }
    layer.style = style;
    let latestInfo = bridgeGetLayerInfo(layer.info.layerId);
    if (latestInfo !== undefined) {
      layer.info = latestInfo;
    }
    return new GisOperationResult(true, 0, 'OK');
  }

  importQmlStyle(layerIndex: number, qmlPath: string): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择图层');
    }
    if (this.isRasterLoadedLayer(layer)) {
      return new GisOperationResult(false, 4, '当前仅支持矢量图层 QML 样式');
    }
    let result = bridgeImportQmlStyle(layer.info.layerId, qmlPath);
    if (!result.ok) {
      return result;
    }
    let latestInfo = bridgeGetLayerInfo(layer.info.layerId);
    if (latestInfo !== undefined) {
      layer.info = latestInfo;
      layer.style = this.createLayerStyleFromInfo(latestInfo, layerIndex);
    }
    return result;
  }

  exportQmlStyle(layerIndex: number, qmlPath: string): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择图层');
    }
    if (this.isRasterLoadedLayer(layer)) {
      return new GisOperationResult(false, 4, '当前仅支持矢量图层 QML 样式');
    }
    return bridgeExportQmlStyle(layer.info.layerId, qmlPath);
  }

  renderMapView(outputPath: string, minX: number, minY: number, maxX: number, maxY: number,
    width: number, height: number, visibleLayerHandles: string, destinationCrs: string): GisGeoProcessResult {
    return bridgeRenderMapView(outputPath, minX, minY, maxX, maxY, width, height, visibleLayerHandles,
      destinationCrs);
  }

  exportMapLayout(title: string, outputPath: string, format: string, showLegend: boolean, showScaleBar: boolean,
    showNorthArrow: boolean, showGrid: boolean, width: number, height: number,
    legendTitle: string, scaleText: string, footerText: string, basemapMode: number,
    basemapLabel: string, basemapImagePath: string = ''): GisGeoProcessResult {
    let visibleLayerHandles = '';
    let visibleLayerCount = 0;
    for (let i = 0; i < this.layers.length; i++) {
      let layer = this.layers[i];
      if (!layer.visible) {
        continue;
      }
      if (visibleLayerHandles.length > 0) {
        visibleLayerHandles += ';';
      }
      if (layer.info.layerId.length > 1) {
        visibleLayerHandles += layer.info.layerId.substring(1);
      }
      visibleLayerCount++;
    }
    if (visibleLayerCount === 0 && basemapMode === 0) {
      return new GisGeoProcessResult(false, 3, '当前没有显示中的图层，无法出图', outputPath, title, 0);
    }
    return bridgeExportMapLayout(title, outputPath, format, showLegend, showScaleBar, showNorthArrow, showGrid,
      width, height, legendTitle, scaleText, footerText, basemapMode, basemapLabel, basemapImagePath,
      visibleLayerHandles);
  }

  beginEditSession(layerIndex: number): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择编辑图层');
    }
    if (this.isRasterLoadedLayer(layer)) {
      return new GisOperationResult(false, 4, '栅格图层不支持编辑会话');
    }
    let result = bridgeBeginEditSession(layer.info.layerId);
    if (result.ok) {
      this.activeLayerIndex = layerIndex;
    }
    return result;
  }

  commitEditSession(layerIndex: number): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择编辑图层');
    }
    let result = bridgeCommitEditSession(layer.info.layerId);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  rollbackEditSession(layerIndex: number): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择编辑图层');
    }
    let result = bridgeRollbackEditSession(layer.info.layerId);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  isEditSessionActive(layerIndex: number): boolean {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined || this.isRasterLoadedLayer(layer)) {
      return false;
    }
    return bridgeIsEditing(layer.info.layerId);
  }

  isEditing(layerIndex: number): boolean {
    return this.isEditSessionActive(layerIndex);
  }

  hasActiveEditSessions(): boolean {
    for (let i = 0; i < this.layers.length; i++) {
      if (this.isEditSessionActive(i)) {
        return true;
      }
    }
    return false;
  }

  hasPendingEditChangesForLayer(layerIndex: number): boolean {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined || this.isRasterLoadedLayer(layer)) {
      return false;
    }
    return bridgeHasPendingEdits(layer.info.layerId);
  }

  hasPendingEditChanges(): boolean {
    for (let i = 0; i < this.layers.length; i++) {
      if (this.hasPendingEditChangesForLayer(i)) {
        return true;
      }
    }
    return false;
  }

  commitAllEditSessions(): GisOperationResult {
    let committed = 0;
    for (let i = 0; i < this.layers.length; i++) {
      if (!this.isEditSessionActive(i)) {
        continue;
      }
      let result = this.commitEditSession(i);
      if (!result.ok) {
        return result;
      }
      committed++;
    }
    if (committed === 0) {
      return new GisOperationResult(true, 0, '没有待提交的编辑会话');
    }
    return new GisOperationResult(true, 0, '已提交 ' + committed.toString() + ' 个编辑会话');
  }

  rollbackAllEditSessions(): GisOperationResult {
    let rolledBack = 0;
    for (let i = 0; i < this.layers.length; i++) {
      if (!this.isEditSessionActive(i)) {
        continue;
      }
      let result = this.rollbackEditSession(i);
      if (!result.ok) {
        return result;
      }
      rolledBack++;
    }
    if (rolledBack === 0) {
      return new GisOperationResult(true, 0, '没有待放弃的编辑会话');
    }
    return new GisOperationResult(true, 0, '已放弃 ' + rolledBack.toString() + ' 个编辑会话');
  }

  private currentEditSessionLayerIndex(): number {
    if (this.isEditSessionActive(this.activeLayerIndex)) {
      return this.activeLayerIndex;
    }
    for (let i = 0; i < this.layers.length; i++) {
      if (this.isEditSessionActive(i)) {
        return i;
      }
    }
    return -1;
  }

  addSketchFeature(layerIndex: number, geometryType: number, points: GisCoordinate[]): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择编辑图层');
    }
    if (points.length === 0) {
      return new GisOperationResult(false, 4, '没有草图点');
    }
    if (geometryType === 2 && points.length < 2) {
      return new GisOperationResult(false, 4, '线要素至少需要两个点');
    }
    if (geometryType === 3 && points.length < 3) {
      return new GisOperationResult(false, 4, '面要素至少需要三个点');
    }
    let result = bridgeAddFeature(layer.info.layerId, geometryType, points);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  deleteFeature(layerIndex: number, featureId: string): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择编辑图层');
    }
    if (featureId.length === 0) {
      return new GisOperationResult(false, 4, '未选择要删除的要素');
    }
    let result = bridgeDeleteFeature(layer.info.layerId, featureId);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  moveFeatureNode(layerIndex: number, featureId: string, partIndex: number, pointIndex: number, x: number,
    y: number): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择编辑图层');
    }
    let result = bridgeMoveFeatureNode(layer.info.layerId, featureId, partIndex, pointIndex, x, y);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  deleteFeatureNode(layerIndex: number, featureId: string, partIndex: number, pointIndex: number): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择编辑图层');
    }
    let result = bridgeDeleteFeatureNode(layer.info.layerId, featureId, partIndex, pointIndex);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  copyFeature(layerIndex: number, featureId: string): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择编辑图层');
    }
    let result = bridgeCopyFeature(layer.info.layerId, featureId);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  private buildDefaultSplitLine(feature: GisFeatureSummary): GisCoordinate[] {
    let points: GisCoordinate[] = [];
    let env = feature.envelope;
    let width = Math.abs(env.maxX - env.minX);
    let height = Math.abs(env.maxY - env.minY);
    let margin = Math.max(width, height) * 0.2;
    if (margin <= 0) {
      margin = 1.0;
    }
    if (width >= height) {
      let centerX = (env.minX + env.maxX) / 2.0;
      points.push(new GisCoordinate(centerX, env.minY - margin, 0, false));
      points.push(new GisCoordinate(centerX, env.maxY + margin, 0, false));
    } else {
      let centerY = (env.minY + env.maxY) / 2.0;
      points.push(new GisCoordinate(env.minX - margin, centerY, 0, false));
      points.push(new GisCoordinate(env.maxX + margin, centerY, 0, false));
    }
    return points;
  }

  splitSelectedFeature(layerIndex: number, featureId: string): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择编辑图层');
    }
    if (this.isRasterLoadedLayer(layer)) {
      return new GisOperationResult(false, 4, '栅格图层不能执行矢量切割');
    }
    let feature: GisFeatureSummary | undefined = undefined;
    for (let i = 0; i < layer.features.length; i++) {
      if (layer.features[i].featureId === featureId) {
        feature = layer.features[i];
        break;
      }
    }
    if (feature === undefined) {
      return new GisOperationResult(false, 4, '请先选择要切割的要素');
    }
    if (feature.geometry.geometryType === 1) {
      return new GisOperationResult(false, 4, '点要素不能切割');
    }
    let splitLine = this.buildDefaultSplitLine(feature);
    let result = bridgeSplitFeature(layer.info.layerId, featureId, splitLine);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  splitFeatureWithSketch(layerIndex: number, featureId: string,
    points: GisCoordinate[]): GisOperationResult {
    let layer: GisLoadedLayer | undefined = this.getLayer(layerIndex);
    if (layer === undefined || this.isRasterLoadedLayer(layer)) {
      return new GisOperationResult(false, 3, '请选择可编辑矢量图层');
    }
    if (featureId.length === 0 || points.length < 2) {
      return new GisOperationResult(false, 4, '请选择待切割要素并绘制至少两个草图点');
    }
    let result: GisOperationResult = bridgeSplitFeature(layer.info.layerId, featureId, points);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  private findMergePartnerFeatureId(layer: GisLoadedLayer, featureId: string): string {
    for (let i = 0; i < layer.features.length; i++) {
      if (layer.features[i].featureId !== featureId) {
        return layer.features[i].featureId;
      }
    }
    return '';
  }

  mergeFeatureWithNext(layerIndex: number, featureId: string): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择编辑图层');
    }
    if (this.isRasterLoadedLayer(layer)) {
      return new GisOperationResult(false, 4, '栅格图层不能执行矢量合并');
    }
    if (featureId.length === 0) {
      return new GisOperationResult(false, 4, '请先选择要合并的要素');
    }
    let partnerId = this.findMergePartnerFeatureId(layer, featureId);
    if (partnerId.length === 0) {
      return new GisOperationResult(false, 4, '当前图层没有可合并的第二个要素');
    }
    let result = bridgeMergeFeatures(layer.info.layerId, featureId + ';' + partnerId);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  private defaultSnapTolerance(layer: GisLoadedLayer): number {
    let env = layer.info.envelope;
    let width = Math.abs(env.maxX - env.minX);
    let height = Math.abs(env.maxY - env.minY);
    let tolerance = Math.max(width, height) / 5000.0;
    if (tolerance <= 0) {
      return 1.0;
    }
    return tolerance;
  }

  snapLayer(layerIndex: number, targetLayerIndex: number, tolerance: number): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择编辑图层');
    }
    if (this.isRasterLoadedLayer(layer)) {
      return new GisOperationResult(false, 4, '栅格图层不能执行矢量吸附');
    }
    let targetLayer: GisLoadedLayer = layer;
    let candidateLayer = this.getLayer(targetLayerIndex);
    if (candidateLayer !== undefined && !this.isRasterLoadedLayer(candidateLayer)) {
      targetLayer = candidateLayer;
    }
    let snapTolerance = tolerance > 0 ? tolerance : this.defaultSnapTolerance(layer);
    let result = bridgeSnapLayer(layer.info.layerId, targetLayer.info.layerId, snapTolerance);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  private isIntegerFeatureId(featureId: string): boolean {
    if (featureId.length === 0) {
      return false;
    }
    let startIndex = featureId.charAt(0) === '-' ? 1 : 0;
    if (startIndex >= featureId.length) {
      return false;
    }
    for (let i = startIndex; i < featureId.length; i++) {
      let code = featureId.charCodeAt(i);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    return true;
  }

  private selectedFeatureFilter(featureIds: string[]): string {
    let values = '';
    for (let i = 0; i < featureIds.length; i++) {
      let featureId = featureIds[i];
      if (!this.isIntegerFeatureId(featureId)) {
        return '';
      }
      if (values.length > 0) {
        values += ',';
      }
      values += featureId;
    }
    if (values.length === 0) {
      return '';
    }
    return 'qgis:$id IN (' + values + ')';
  }

  updateFeatureAttribute(layerIndex: number, featureId: string, fieldName: string, value: string): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择图层');
    }
    let result = bridgeUpdateFeatureAttribute(layer.info.layerId, featureId, fieldName, value);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  batchAssignAttribute(layerIndex: number, fieldName: string, filterText: string, value: string): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择图层');
    }
    let result = bridgeBatchAssignAttribute(layer.info.layerId, fieldName, filterText, value);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  batchAssignSelectedAttribute(layerIndex: number, featureIds: string[], fieldName: string,
    value: string): GisOperationResult {
    if (featureIds.length === 0) {
      return new GisOperationResult(false, 4, '请先选择至少一个要素');
    }
    let filterText = this.selectedFeatureFilter(featureIds);
    if (filterText.length === 0) {
      return new GisOperationResult(false, 4, '选择集中包含无效 FID');
    }
    return this.batchAssignAttribute(layerIndex, fieldName, filterText, value);
  }

  addLayerField(layerIndex: number, fieldName: string, typeName: string): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择图层');
    }
    if (fieldName.length === 0) {
      return new GisOperationResult(false, 4, '字段名不能为空');
    }
    let result = bridgeAddLayerField(layer.info.layerId, fieldName, typeName);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  deleteLayerField(layerIndex: number, fieldName: string): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择图层');
    }
    let result = bridgeDeleteLayerField(layer.info.layerId, fieldName);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  calculateField(layerIndex: number, fieldName: string, calculatorMode: number, constantValue: string): GisOperationResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 3, '未选择图层');
    }
    let result = bridgeCalculateField(layer.info.layerId, fieldName, calculatorMode, constantValue);
    if (result.ok) {
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  undoEdit(): GisOperationResult {
    let layerIndex = this.currentEditSessionLayerIndex();
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 4, '没有活动的编辑会话');
    }
    let result = bridgeUndoEdit(layer.info.layerId);
    if (result.ok) {
      this.activeLayerIndex = layerIndex;
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  redoEdit(): GisOperationResult {
    let layerIndex = this.currentEditSessionLayerIndex();
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisOperationResult(false, 4, '没有活动的编辑会话');
    }
    let result = bridgeRedoEdit(layer.info.layerId);
    if (result.ok) {
      this.activeLayerIndex = layerIndex;
      this.refreshLayerInfo(layerIndex);
    }
    return result;
  }

  canUndo(): boolean {
    let layerIndex = this.currentEditSessionLayerIndex();
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return false;
    }
    return bridgeCanUndo(layer.info.layerId);
  }

  canRedo(): boolean {
    let layerIndex = this.currentEditSessionLayerIndex();
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return false;
    }
    return bridgeCanRedo(layer.info.layerId);
  }

  undoCount(): number {
    return this.canUndo() ? 1 : 0;
  }

  redoCount(): number {
    return this.canRedo() ? 1 : 0;
  }

  // Get total feature count across all layers
  getTotalFeatureCount(): number {
    let total = 0;
    for (let i = 0; i < this.layers.length; i++) {
      total += this.layers[i].info.featureCount;
    }
    return total;
  }

  // Find feature by id across all layers
  findFeatureById(featureId: string): GisFeatureSummary | undefined {
    for (let i = 0; i < this.layers.length; i++) {
      for (let j = 0; j < this.layers[i].features.length; j++) {
        if (this.layers[i].features[j].featureId === featureId) {
          return this.layers[i].features[j];
        }
      }
    }
    return undefined;
  }

  // Clear all layers
  clearAll(): void {
    for (let i = this.layers.length - 1; i >= 0; i--) {
      bridgeCloseLayer(this.layers[i].info.layerId);
    }
    this.layers = [];
    this.activeLayerIndex = -1;
    this.editUndoStack = [];
    this.editRedoStack = [];
  }
}

function qgisChannelToHex(value: number): string {
  let cleanValue = value;
  if (cleanValue < 0) {
    cleanValue = 0;
  }
  if (cleanValue > 255) {
    cleanValue = 255;
  }
  let text = Math.round(cleanValue).toString(16).toUpperCase();
  if (text.length < 2) {
    return '0' + text;
  }
  return text;
}

function qgisRgbFractionToHex(red: number, green: number, blue: number): string {
  return '#' + qgisChannelToHex(red * 255.0) + qgisChannelToHex(green * 255.0) +
    qgisChannelToHex(blue * 255.0);
}

export function qgisRampColor(colorRamp: number, index: number, total: number): string {
  let safeTotal = total;
  if (safeTotal < 1) {
    safeTotal = 1;
  }
  let safeIndex = index;
  if (safeIndex < 0) {
    safeIndex = 0;
  }
  if (safeIndex >= safeTotal) {
    safeIndex = safeTotal - 1;
  }
  let t = safeTotal <= 1 ? 0.0 : safeIndex / (safeTotal - 1);
  if (colorRamp === 1) {
    return qgisRgbFractionToHex(0.90 - 0.12 * t, 0.72 - 0.42 * t, 0.32 - 0.18 * t);
  }
  if (colorRamp === 2) {
    if (t < 0.5) {
      let local = t * 2.0;
      return qgisRgbFractionToHex(0.16 + 0.58 * local, 0.48 + 0.30 * local, 0.69 - 0.36 * local);
    }
    let local = (t - 0.5) * 2.0;
    return qgisRgbFractionToHex(0.74 + 0.05 * local, 0.78 - 0.42 * local, 0.33 - 0.12 * local);
  }
  return qgisRgbFractionToHex(0.12 + 0.44 * t, 0.42 + 0.30 * t, 0.70 - 0.48 * t);
}

function qgisFeatureAttributeText(feature: GisFeatureSummary, fieldName: string): string {
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

export function qgisCategoryTotal(layer: GisLoadedLayer, fieldName: string): number {
  let count = 0;
  for (let i = 0; i < layer.features.length; i++) {
    let value = qgisFeatureAttributeText(layer.features[i], fieldName);
    let exists = false;
    for (let j = 0; j < i; j++) {
      let priorValue = qgisFeatureAttributeText(layer.features[j], fieldName);
      if (priorValue === value) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      count++;
      if (count >= 12) {
        return count;
      }
    }
  }
  if (count < 1) {
    return 1;
  }
  return count;
}

export function qgisCategoryBucket(layer: GisLoadedLayer, fieldName: string, value: string): number {
  let bucket = 0;
  for (let i = 0; i < layer.features.length; i++) {
    let featureValue = qgisFeatureAttributeText(layer.features[i], fieldName);
    let exists = false;
    for (let j = 0; j < i; j++) {
      let priorValue = qgisFeatureAttributeText(layer.features[j], fieldName);
      if (priorValue === featureValue) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      if (featureValue === value) {
        return bucket;
      }
      bucket++;
      if (bucket >= 12) {
        break;
      }
    }
  }
  return 0;
}

export function qgisGraduatedBucket(layer: GisLoadedLayer, fieldName: string, value: number): number {
  let hasValue = false;
  let minValue = 0.0;
  let maxValue = 0.0;
  for (let i = 0; i < layer.features.length; i++) {
    let text = qgisFeatureAttributeText(layer.features[i], fieldName);
    if (text.length === 0) {
      continue;
    }
    let numericValue = Number(text);
    if (numericValue !== numericValue) {
      continue;
    }
    if (!hasValue) {
      minValue = numericValue;
      maxValue = numericValue;
      hasValue = true;
    } else {
      if (numericValue < minValue) {
        minValue = numericValue;
      }
      if (numericValue > maxValue) {
        maxValue = numericValue;
      }
    }
  }
  if (!hasValue) {
    return 0;
  }
  if (Math.abs(maxValue - minValue) < 0.0000001) {
    maxValue = minValue + 1.0;
  }
  let step = (maxValue - minValue) / 5.0;
  if (step <= 0.0) {
    return 0;
  }
  if (value <= minValue) {
    return 0;
  }
  if (value >= maxValue) {
    return 4;
  }
  let bucket = Math.floor((value - minValue) / step);
  if (bucket < 0) {
    return 0;
  }
  if (bucket > 4) {
    return 4;
  }
  return bucket;
}

// Singleton instance
let gisServiceInstance: GisService | undefined = undefined;

export function getGisService(): GisService {
  if (gisServiceInstance === undefined) {
    gisServiceInstance = new GisService();
  }
  return gisServiceInstance;
}
