export const getNativeVersion: () => string;
export const getCoreProfile: () => string;
export const getProcessingAlgorithms: () => string;

export interface NativeLayerOpenResult {
  handle: number;
  layerInfo: string;
  errCode: number;
}

export interface NativeLayerInfoResult {
  layerInfo: string;
  errCode: number;
}

export interface NativeFeaturePageResult {
  featurePage: string;
  errCode: number;
}

export interface NativeFeatureResult {
  feature: string;
  errCode: number;
}

export interface NativeGeoProcessResult {
  resultInfo: string;
  errCode: number;
}

export const executeProcessingAlgorithm: (requestJson: string) => NativeGeoProcessResult;

export const openVectorLayer: (filePath: string) => NativeLayerOpenResult;
export const openRasterLayer: (filePath: string) => NativeLayerOpenResult;
export const closeLayer: (handle: number) => number;
export const getLayerInfo: (handle: number) => NativeLayerInfoResult;
export const queryFeatures: (handle: number, minX: number, minY: number, maxX: number, maxY: number, limit: number) => NativeFeaturePageResult;
export const getFeature: (handle: number, fid: number) => NativeFeatureResult;
export const bufferLayer: (handle: number, distance: number, outputPath: string, outputLayerName: string) => NativeGeoProcessResult;
export const simplifyLayer: (handle: number, tolerance: number, outputPath: string, outputLayerName: string) => NativeGeoProcessResult;
export const dissolveLayer: (handle: number, outputPath: string, outputLayerName: string) => NativeGeoProcessResult;
export const centroidLayer: (handle: number, outputPath: string, outputLayerName: string) => NativeGeoProcessResult;
export const repairLayer: (handle: number, outputPath: string, outputLayerName: string) => NativeGeoProcessResult;
export const clipLayer: (inputHandle: number, clipHandle: number, outputPath: string, outputLayerName: string) => NativeGeoProcessResult;
export const exportLayer: (handle: number, outputPath: string, outputLayerName: string) => NativeGeoProcessResult;
export const defineLayerProjection: (handle: number, targetDefinition: string, outputPath: string, outputLayerName: string) => NativeGeoProcessResult;
export const projectLayer: (handle: number, targetDefinition: string, outputPath: string, outputLayerName: string) => NativeGeoProcessResult;
export const applyVectorStyle: (handle: number, rendererMode: number, rendererField: string, colorRamp: number, linePattern: number, fillPattern: number, pointColor: string, lineColor: string, fillColor: string, strokeColor: string, lineWidth: number, pointRadius: number, opacity: number, symbolName: string) => NativeGeoProcessResult;
export const applyVectorLabeling: (handle: number, enabled: boolean, labelField: string, labelSize: number, labelColor: string, halo: boolean, avoidance: boolean, minScale: number, maxScale: number) => NativeGeoProcessResult;
export const configureRasterDisplay: (handle: number, bandMode: number, stretchMode: number, colorRamp: number, opacity: number, noData: string, transparentColor: string, hillshade: boolean) => NativeGeoProcessResult;
export const exportMapLayout: (title: string, outputPath: string, format: string, showLegend: boolean, showScaleBar: boolean, showNorthArrow: boolean, showGrid: boolean, width: number, height: number, legendTitle: string, scaleText: string, footerText: string, basemapMode: number, basemapLabel: string, visibleLayerHandles: string) => NativeGeoProcessResult;
export const describeCoordinateReferenceSystem: (definition: string) => NativeGeoProcessResult;
export const transformCoordinate: (sourceDefinition: string, targetDefinition: string, x: number, y: number) => NativeGeoProcessResult;
export const transformEnvelope: (sourceDefinition: string, targetDefinition: string, minX: number, minY: number, maxX: number, maxY: number) => NativeGeoProcessResult;
export const addFeature: (handle: number, geometryType: number, coordsText: string) => NativeGeoProcessResult;
export const deleteFeature: (handle: number, fid: number) => NativeGeoProcessResult;
export const moveFeatureNode: (handle: number, fid: number, partIndex: number, pointIndex: number, x: number, y: number) => NativeGeoProcessResult;
export const deleteFeatureNode: (handle: number, fid: number, partIndex: number, pointIndex: number) => NativeGeoProcessResult;
export const copyFeature: (handle: number, fid: number) => NativeGeoProcessResult;
export const splitFeature: (handle: number, fid: number, coordsText: string) => NativeGeoProcessResult;
export const mergeFeatures: (handle: number, fidListText: string) => NativeGeoProcessResult;
export const snapLayer: (handle: number, targetHandle: number, tolerance: number) => NativeGeoProcessResult;
export const updateFeatureAttribute: (handle: number, fid: number, fieldName: string, value: string) => NativeGeoProcessResult;
export const batchAssignAttribute: (handle: number, fieldName: string, filterText: string, value: string) => NativeGeoProcessResult;
export const addLayerField: (handle: number, fieldName: string, typeName: string) => NativeGeoProcessResult;
export const deleteLayerField: (handle: number, fieldName: string) => NativeGeoProcessResult;
export const calculateField: (handle: number, fieldName: string, calculatorMode: number, constantValue: string) => NativeGeoProcessResult;
