import {
  bridgeOpenVectorLayer,
  bridgeOpenRasterLayer,
  bridgeGetLayerInfo,
  bridgeQueryFeatures,
  bridgeCloseLayer,
  bridgeGetFeature,
  bridgeGetProcessingAlgorithms,
  bridgeExecuteProcessingAlgorithm,
  bridgeBufferLayer,
  bridgeSimplifyLayer,
  bridgeDissolveLayer,
  bridgeCentroidLayer,
  bridgeRepairLayer,
  bridgeClipLayer,
  bridgeExportLayer,
  bridgeDefineLayerProjection,
  bridgeProjectLayer,
  bridgeApplyVectorStyle,
  bridgeApplyVectorLabeling,
  bridgeConfigureRasterDisplay,
  bridgeExportMapLayout,
  bridgeDescribeCoordinateReferenceSystem,
  bridgeTransformCoordinate,
  bridgeTransformEnvelope,
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
  bridgeCalculateField
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
  GisEnvelopeTransformResult
} from '../model/GeoNestModels';

const GIS_FEATURE_PREVIEW_LIMIT: number = 1200;

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

// ---------------------------------------------------------------------------
// GisService: singleton managing loaded layers
// ---------------------------------------------------------------------------
export class GisService {
  private layers: GisLoadedLayer[] = [];
  private activeLayerIndex: number = -1;
  private draftFeatureSeed: number = 1;
  private editUndoStack: GisLayerEditSnapshot[] = [];
  private editRedoStack: GisLayerEditSnapshot[] = [];

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

  private loadFeaturesByFid(layerInfo: GisLayerInfo): GisFeatureSummary[] {
    let result: GisFeatureSummary[] = [];
    for (let fid = 0; fid < layerInfo.featureCount; fid++) {
      let feature = bridgeGetFeature(layerInfo.layerId, fid);
      if (feature !== undefined) {
        result.push(feature);
      }
    }
    return result;
  }

  private cloneEnvelope(env: GisEnvelope): GisEnvelope {
    return new GisEnvelope(env.minX, env.minY, env.maxX, env.maxY);
  }

  private cloneField(field: GisFieldInfo): GisFieldInfo {
    return new GisFieldInfo(field.name, field.alias, field.typeName, field.width, field.precision, field.nullable);
  }

  private cloneCoordinate(coord: GisCoordinate): GisCoordinate {
    return new GisCoordinate(coord.x, coord.y, coord.z, coord.hasZ);
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
      if (layerInfo.featureCount <= GIS_FEATURE_PREVIEW_LIMIT && loaded.features.length < layerInfo.featureCount) {
        let fidFeatures = this.loadFeaturesByFid(layerInfo);
        if (fidFeatures.length > loaded.features.length) {
          loaded.features = fidFeatures;
        }
      }
    }
    this.layers.push(loaded);
    let newIndex = this.layers.length - 1;
    this.activeLayerIndex = newIndex;
    return newIndex;
  }

  // Close a layer by index
  closeLayerByIndex(index: number): GisOperationResult {
    if (index < 0 || index >= this.layers.length) {
      return new GisOperationResult(false, 3, 'Invalid index');
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

  runProcessingAlgorithm(algorithmId: string, inputLayerIndex: number, overlayLayerIndex: number,
    numericValue: number, textValue: string, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    let inputLayer = this.getLayer(inputLayerIndex);
    if (inputLayer === undefined) {
      return new GisGeoProcessResult(false, 3, '未选择输入图层', outputPath, outputLayerName, 0);
    }
    let overlayLayerId: string = '';
    if (overlayLayerIndex >= 0) {
      let overlayLayer = this.getLayer(overlayLayerIndex);
      if (overlayLayer === undefined) {
        return new GisGeoProcessResult(false, 3, '未选择叠加图层', outputPath, outputLayerName, 0);
      }
      overlayLayerId = overlayLayer.info.layerId;
    }
    let result = bridgeExecuteProcessingAlgorithm(algorithmId, inputLayer.info.layerId, overlayLayerId,
      numericValue, textValue, outputPath, outputLayerName);
    if (result.ok && result.outputPath.length > 0 && this.openLayer(result.outputPath) < 0) {
      return new GisGeoProcessResult(false, 2, '输出已生成，但加载结果图层失败', result.outputPath,
        result.outputLayerName, result.featureCount);
    }
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

  runBuffer(layerIndex: number, distance: number, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisGeoProcessResult(false, 3, '未选择输入图层', outputPath, outputLayerName, 0);
    }
    let result = bridgeBufferLayer(layer.info.layerId, distance, outputPath, outputLayerName);
    if (result.ok) {
      let idx = this.openLayer(result.outputPath);
      if (idx < 0) {
        return new GisGeoProcessResult(false, 2, '输出已生成，但加载结果图层失败', result.outputPath,
          result.outputLayerName, result.featureCount);
      }
    }
    return result;
  }

  runSimplify(layerIndex: number, tolerance: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisGeoProcessResult(false, 3, '未选择输入图层', outputPath, outputLayerName, 0);
    }
    let result = bridgeSimplifyLayer(layer.info.layerId, tolerance, outputPath, outputLayerName);
    if (result.ok && this.openLayer(result.outputPath) < 0) {
      return new GisGeoProcessResult(false, 2, '输出已生成，但加载结果图层失败', result.outputPath,
        result.outputLayerName, result.featureCount);
    }
    return result;
  }

  runDissolve(layerIndex: number, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisGeoProcessResult(false, 3, '未选择输入图层', outputPath, outputLayerName, 0);
    }
    let result = bridgeDissolveLayer(layer.info.layerId, outputPath, outputLayerName);
    if (result.ok && this.openLayer(result.outputPath) < 0) {
      return new GisGeoProcessResult(false, 2, '输出已生成，但加载结果图层失败', result.outputPath,
        result.outputLayerName, result.featureCount);
    }
    return result;
  }

  runCentroid(layerIndex: number, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisGeoProcessResult(false, 3, '未选择输入图层', outputPath, outputLayerName, 0);
    }
    let result = bridgeCentroidLayer(layer.info.layerId, outputPath, outputLayerName);
    if (result.ok && this.openLayer(result.outputPath) < 0) {
      return new GisGeoProcessResult(false, 2, '输出已生成，但加载结果图层失败', result.outputPath,
        result.outputLayerName, result.featureCount);
    }
    return result;
  }

  runRepair(layerIndex: number, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisGeoProcessResult(false, 3, '未选择输入图层', outputPath, outputLayerName, 0);
    }
    let result = bridgeRepairLayer(layer.info.layerId, outputPath, outputLayerName);
    if (result.ok) {
      let idx = this.openLayer(result.outputPath);
      if (idx < 0) {
        return new GisGeoProcessResult(false, 2, '输出已生成，但加载结果图层失败', result.outputPath,
          result.outputLayerName, result.featureCount);
      }
    }
    return result;
  }

  runClip(inputLayerIndex: number, clipLayerIndex: number, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    let inputLayer = this.getLayer(inputLayerIndex);
    let clipLayer = this.getLayer(clipLayerIndex);
    if (inputLayer === undefined || clipLayer === undefined) {
      return new GisGeoProcessResult(false, 3, '未选择输入图层或裁剪图层', outputPath, outputLayerName, 0);
    }
    let result = bridgeClipLayer(inputLayer.info.layerId, clipLayer.info.layerId, outputPath, outputLayerName);
    if (result.ok) {
      let idx = this.openLayer(result.outputPath);
      if (idx < 0) {
        return new GisGeoProcessResult(false, 2, '输出已生成，但加载结果图层失败', result.outputPath,
          result.outputLayerName, result.featureCount);
      }
    }
    return result;
  }

  runExport(layerIndex: number, outputPath: string, outputLayerName: string): GisGeoProcessResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisGeoProcessResult(false, 3, '未选择输入图层', outputPath, outputLayerName, 0);
    }
    let result = bridgeExportLayer(layer.info.layerId, outputPath, outputLayerName);
    if (result.ok) {
      let idx = this.openLayer(result.outputPath);
      if (idx < 0) {
        return new GisGeoProcessResult(false, 2, '输出已生成，但加载结果图层失败', result.outputPath,
          result.outputLayerName, result.featureCount);
      }
    }
    return result;
  }

  runDefineProjection(layerIndex: number, targetDefinition: string, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisGeoProcessResult(false, 3, '未选择输入图层', outputPath, outputLayerName, 0);
    }
    if (targetDefinition.trim().length === 0) {
      return new GisGeoProcessResult(false, 6, '未填写目标坐标系', outputPath, outputLayerName, 0);
    }
    let result = bridgeDefineLayerProjection(layer.info.layerId, targetDefinition, outputPath, outputLayerName);
    if (result.ok) {
      let idx = this.openLayer(result.outputPath);
      if (idx < 0) {
        return new GisGeoProcessResult(false, 2, '输出已生成，但加载结果图层失败', result.outputPath,
          result.outputLayerName, result.featureCount);
      }
    }
    return result;
  }

  runProjectLayer(layerIndex: number, targetDefinition: string, outputPath: string,
    outputLayerName: string): GisGeoProcessResult {
    let layer = this.getLayer(layerIndex);
    if (layer === undefined) {
      return new GisGeoProcessResult(false, 3, '未选择输入图层', outputPath, outputLayerName, 0);
    }
    if (targetDefinition.trim().length === 0) {
      return new GisGeoProcessResult(false, 6, '未填写目标坐标系', outputPath, outputLayerName, 0);
    }
    let result = bridgeProjectLayer(layer.info.layerId, targetDefinition, outputPath, outputLayerName);
    if (result.ok) {
      let idx = this.openLayer(result.outputPath);
      if (idx < 0) {
        return new GisGeoProcessResult(false, 2, '输出已生成，但加载结果图层失败', result.outputPath,
          result.outputLayerName, result.featureCount);
      }
    }
    return result;
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

  exportMapLayout(title: string, outputPath: string, format: string, showLegend: boolean, showScaleBar: boolean,
    showNorthArrow: boolean, showGrid: boolean, width: number, height: number,
    legendTitle: string, scaleText: string, footerText: string, basemapMode: number,
    basemapLabel: string): GisGeoProcessResult {
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
    if (visibleLayerCount === 0) {
      return new GisGeoProcessResult(false, 3, '当前没有显示中的图层，无法出图', outputPath, title, 0);
    }
    return bridgeExportMapLayout(title, outputPath, format, showLegend, showScaleBar, showNorthArrow, showGrid,
      width, height, legendTitle, scaleText, footerText, basemapMode, basemapLabel, visibleLayerHandles);
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
    if (this.editUndoStack.length === 0) {
      return new GisOperationResult(false, 4, '没有可撤销的编辑');
    }
    let snapshot = this.editUndoStack[this.editUndoStack.length - 1];
    this.editUndoStack.splice(this.editUndoStack.length - 1, 1);
    let current = this.captureLayerSnapshot(snapshot.layerIndex);
    if (current !== undefined) {
      this.editRedoStack.push(current);
    }
    if (this.restoreLayerSnapshot(snapshot)) {
      return new GisOperationResult(true, 0, '已撤销');
    }
    return new GisOperationResult(false, 5, '撤销失败');
  }

  redoEdit(): GisOperationResult {
    if (this.editRedoStack.length === 0) {
      return new GisOperationResult(false, 4, '没有可重做的编辑');
    }
    let snapshot = this.editRedoStack[this.editRedoStack.length - 1];
    this.editRedoStack.splice(this.editRedoStack.length - 1, 1);
    let current = this.captureLayerSnapshot(snapshot.layerIndex);
    if (current !== undefined) {
      this.editUndoStack.push(current);
    }
    if (this.restoreLayerSnapshot(snapshot)) {
      return new GisOperationResult(true, 0, '已重做');
    }
    return new GisOperationResult(false, 5, '重做失败');
  }

  undoCount(): number {
    return this.editUndoStack.length;
  }

  redoCount(): number {
    return this.editRedoStack.length;
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
