export const ACTION_NEW_PROJECT: number = 1;
export const ACTION_OPEN_PROJECT: number = 2;
export const ACTION_SAVE_PROJECT: number = 3;
export const ACTION_PROJECT_INFO: number = 4;
export const ACTION_ATTRIBUTE_TABLE: number = 5;
export const ACTION_ADD_DATA: number = 7;
export const ACTION_ZOOM_IN: number = 8;
export const ACTION_ZOOM_OUT: number = 9;
export const ACTION_FULL_EXTENT: number = 10;
export const ACTION_SYMBOLOGY: number = 11;
export const ACTION_EXPORT: number = 20;
export const ACTION_SETTINGS: number = 39;
export const ACTION_HELP: number = 40;

export const BACKSTAGE_INFO: number = 0;
export const BACKSTAGE_ABOUT: number = 1;
export const BACKSTAGE_HELP: number = 2;
export const BACKSTAGE_SETTINGS: number = 3;

export enum WorkbenchToolAction {
  CLIP = 12,
  BUFFER = 13,
  REPAIR = 14,
  EXPORT = 20,
  QGIS_CORE = 21,
  VECTOR_EDIT = 22,
  ATTRIBUTE_EDIT = 23,
  LABELING = 24,
  RASTER_DISPLAY = 25,
  LAYOUT = 26,
  PRINT = 27,
  DEFINE_PROJECTION = 28,
  PROJECT_LAYER = 29,
  SIMPLIFY = 36,
  DISSOLVE = 37,
  CENTROID = 38,
  CONVEX_HULL = 47,
  BOUNDING_BOXES = 48,
  ORIENTED_MINIMUM_BOUNDING_BOX = 49,
  MULTIPART_TO_SINGLEPARTS = 50,
  EXTRACT_BY_EXPRESSION = 51,
  DIFFERENCE = 52,
  SYMMETRICAL_DIFFERENCE = 53,
  MERGE_LAYERS = 54,
  MULTI_RING_BUFFER = 55,
  EXTRACT_BY_LOCATION = 56,
  SPATIAL_JOIN_SUMMARY = 57,
  INTERSECTION = 58,
  NEAREST_NEIGHBOR = 59,
  VORONOI = 60,
  PROCESSING_BROWSER = 61,
  KERNEL_DENSITY = 62,
  POINT_DENSITY = 63,
  LINE_DENSITY = 64,
  IDW = 65,
  EXPRESSION_WORKBENCH = 66,
  RASTER_SLOPE = 67,
  RASTER_ASPECT = 68,
  RASTER_RECLASSIFY = 69,
  QUALITY_CHECK = 70
}

export enum WorkbenchSearchCandidateKind {
  COMMAND = 0,
  LAYER = 1
}

export enum WorkbenchCatalogSection {
  PROJECT = 0,
  PORTAL = 1,
  COMPUTER = 2,
  FAVORITES = 3
}

export enum WorkbenchCatalogAction {
  OPEN_PROJECT = 2,
  SAVE_PROJECT = 3,
  ATTRIBUTE_TABLE = 5,
  ADD_DATA = 7,
  SYMBOLOGY = 11,
  CLIP = 12,
  BUFFER = 13,
  EXPORT = 20,
  LABELING = 24,
  LAYOUT = 26,
  SHARE = 42,
  CLOUD_MANAGE = 44,
  CLOUD_PUSH = 45,
  CLOUD_PULL = 46,
  SPATIAL_JOIN_SUMMARY = 57,
  INTERSECTION = 58,
  QUALITY_CHECK = 70
}

export enum WorkbenchContentsSection {
  DRAWING_ORDER = 0,
  SOURCE = 1,
  SELECTION = 2,
  LABELING = 3,
  EDITING = 4
}

export enum WorkbenchContentsAction {
  ADD_DATA = 7,
  LAYER_TOGGLE = 15,
  LAYER_FILTER = 16,
  LAYER_UP = 17,
  LAYER_DOWN = 18,
  LAYER_DELETE = 19
}
