#ifndef GEONEST_GIS_CORE_H
#define GEONEST_GIS_CORE_H

#include <cstdint>
#include <string>

namespace geonest {

// Geometry type constants (matches OGR)
constexpr int32_t GEOM_UNKNOWN = 0;
constexpr int32_t GEOM_POINT = 1;
constexpr int32_t GEOM_LINESTRING = 2;
constexpr int32_t GEOM_POLYGON = 3;
constexpr int32_t GEOM_MULTIPOINT = 4;
constexpr int32_t GEOM_MULTILINESTRING = 5;
constexpr int32_t GEOM_MULTIPOLYGON = 6;

// Error codes
constexpr int32_t GIS_OK = 0;
constexpr int32_t GIS_ERR_FILE_NOT_FOUND = 1;
constexpr int32_t GIS_ERR_INVALID_FORMAT = 2;
constexpr int32_t GIS_ERR_LAYER_NOT_FOUND = 3;
constexpr int32_t GIS_ERR_FEATURE_NOT_FOUND = 4;
constexpr int32_t GIS_ERR_NATIVE_NOT_READY = 5;
constexpr int32_t GIS_ERR_INVALID_PARAM = 6;
constexpr int32_t GIS_ERR_WRITE_FAILED = 7;
constexpr int32_t GIS_ERR_CANCELED = 8;

// Layer handle returned by openVectorLayer, 0 means invalid
using LayerHandle = int32_t;

const char *GetNativeVersion();
const char *GetCoreProfile();
// Returns a JSON catalog describing the geoprocessing algorithms exposed by this bridge.
// Caller must free the returned string with FreeCString.
const char *GetProcessingAlgorithms();

// Execute an exposed processing algorithm from a JSON request. The request contains
// algorithmId, inputHandle, overlayHandle, numericValue, textValue, outputPath and
// outputLayerName. Caller must free the returned JSON result with FreeCString.
const char *ExecuteProcessingAlgorithm(const char *requestJson, int32_t *outErrCode);

// Background processing is split into a caller-thread preparation phase and a
// worker-thread execution phase. Preparation snapshots only stable source URIs
// and transform context; the worker opens private layer instances and never
// dereferences the application's loaded QgsMapLayer objects. A prepared task has
// exactly one owner: RunPreparedProcessingTask and FreePreparedProcessingTask
// must never be called concurrently for the same pointer.
struct PreparedProcessingTask;

using ProcessingCancelCallback = bool (*)(void *userData);
using ProcessingProgressCallback = void (*)(void *userData, double progress,
                                             int64_t processedCount, const char *stage);

struct ProcessingCallbacks {
    void *userData = nullptr;
    ProcessingCancelCallback isCanceled = nullptr;
    ProcessingProgressCallback reportProgress = nullptr;
};

// outErrorMessage is allocated by the core and must be released with
// FreeCString. A null return means the request cannot safely run in background.
PreparedProcessingTask *PrepareProcessingTask(const char *requestJson,
                                               char **outErrorMessage,
                                               int32_t *outErrCode);
const char *RunPreparedProcessingTask(PreparedProcessingTask *task,
                                      const ProcessingCallbacks *callbacks,
                                      int32_t *outErrCode);
void FreePreparedProcessingTask(PreparedProcessingTask *task);

// Read a QGIS .qgs/.qgz project and return JSON metadata plus layer source URIs.
const char *ReadQgisProject(const char *projectPath, int32_t *outErrCode);

// Write currently loaded layer handles into a QGIS .qgs/.qgz project.
const char *WriteQgisProject(const char *projectPath, const char *projectName,
                             const char *projectCrs, const char *layerHandles,
                             int32_t *outErrCode);

// Extract a ZIP archive into a sandbox directory. The returned JSON follows the
// common process result shape; featureCount is the number of extracted files.
const char *ExtractZipArchive(const char *zipPath, const char *outputDirectory, int32_t *outErrCode);

// Open a vector layer from file path. Returns handle (>0) or negative error code.
// On success, also writes the layer JSON info into outLayerInfo (caller must free with FreeCString).
LayerHandle OpenVectorLayer(const char *filePath, char **outLayerInfo, int32_t *outErrCode);

// Open a raster layer from file path. Returns handle (>0) or 0 on error.
// On success, also writes the layer JSON info into outLayerInfo (caller must free with FreeCString).
LayerHandle OpenRasterLayer(const char *filePath, char **outLayerInfo, int32_t *outErrCode);

// Close a previously opened layer.
int32_t CloseLayer(LayerHandle handle);

// Get layer info as JSON string. Caller must free with FreeCString.
const char *GetLayerInfo(LayerHandle handle, int32_t *outErrCode);

// Enumerate vector sublayers (for example XLS/XLSX worksheets) as JSON.
// Caller must free the returned string with FreeCString.
const char *ListVectorSublayers(const char *filePath, int32_t *outErrCode);

// Query features within envelope. Returns JSON array. Caller must free with FreeCString.
// limit <= 0 means no limit. offset skips matching provider rows for paging.
const char *QueryFeatures(LayerHandle handle, double minX, double minY, double maxX, double maxY,
                         int32_t limit, int32_t offset, int32_t *outErrCode);

// Query the complete provider dataset with a WKT selection geometry. predicateMode:
// 0 intersects, 1 contains, 2 within, 3 touches. limit <= 0 means no limit.
// The returned JSON contains provider FIDs and is not constrained by the UI preview cache.
const char *SelectFeaturesByGeometry(LayerHandle handle, const char *selectionWkt,
                                     int32_t predicateMode, int32_t limit,
                                     int32_t *outErrCode);

// Get a single feature by FID as JSON. Caller must free with FreeCString.
const char *GetFeature(LayerHandle handle, int64_t fid, int32_t *outErrCode);

// Create a buffer output layer as Shapefile. Distance is in layer coordinate units.
const char *BufferLayer(LayerHandle handle, double distance, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode);

// Write a geometry-repaired copy of the layer as Shapefile.
const char *RepairLayer(LayerHandle handle, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode);

// Rule-driven topology validation. rulesText is a semicolon-separated rule id list.
// targetHandle may be 0 for same-layer rules. dirtyExtentText is empty for a full
// scan or "minX,minY,maxX,maxY" for incremental dirty-area validation.
const char *ValidateTopologyRules(LayerHandle sourceHandle, LayerHandle targetHandle,
                                  const char *rulesText, const char *dirtyExtentText,
                                  double tolerance, const char *outputPath,
                                  const char *outputLayerName, int32_t *outErrCode);

// Preview or apply a topology repair strategy. Preview writes a non-destructive
// output dataset. Apply updates the current edit buffer and remains rollbackable
// until CommitEditSession is called.
const char *RepairTopologyIssues(LayerHandle sourceHandle, LayerHandle targetHandle,
                                 const char *featureIdsText, const char *strategy,
                                 double tolerance, bool previewOnly,
                                 const char *outputPath, const char *outputLayerName,
                                 int32_t *outErrCode);

// Clip an input layer by another loaded layer and write a Shapefile result.
const char *ClipLayer(LayerHandle inputHandle, LayerHandle clipHandle, const char *outputPath,
                      const char *outputLayerName, int32_t *outErrCode);

// Export a loaded layer to a Shapefile result.
const char *ExportLayer(LayerHandle handle, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode);

// Export a loaded layer to a specified format (driverName).
// Supported driverName values: "ESRI Shapefile", "GeoJSON", "GPKG", "KML", "CSV",
// "FlatGeobuf", "GTiff", "JPEG", "PNG", etc.
const char *ExportLayerToFormat(LayerHandle handle, const char *outputPath,
                                const char *outputLayerName, const char *driverName,
                                int32_t *outErrCode);

const char *ExportRasterToFormat(LayerHandle handle, const char *outputPath,
                                 const char *outputLayerName, const char *driverName,
                                 int32_t *outErrCode);

// Write a loaded layer to Shapefile with a new CRS definition without changing coordinates.
const char *DefineLayerProjection(LayerHandle handle, const char *targetDefinition,
                                  const char *outputPath, const char *outputLayerName,
                                  int32_t *outErrCode);

// Reproject a loaded layer into a target CRS and write a Shapefile result.
const char *ProjectLayer(LayerHandle handle, const char *targetDefinition,
                         const char *outputPath, const char *outputLayerName,
                         int32_t *outErrCode);

// Simplify every non-empty geometry and write a Shapefile result.
const char *SimplifyLayer(LayerHandle handle, double tolerance, const char *outputPath,
                          const char *outputLayerName, int32_t *outErrCode);

// Dissolve all non-empty geometries into one feature and write a Shapefile result.
const char *DissolveLayer(LayerHandle handle, const char *outputPath,
                          const char *outputLayerName, int32_t *outErrCode);

// Create one centroid point for every non-empty input geometry.
const char *CentroidLayer(LayerHandle handle, const char *outputPath,
                          const char *outputLayerName, int32_t *outErrCode);

// Create one convex hull for all non-empty input geometries.
const char *ConvexHullLayer(LayerHandle handle, const char *outputPath,
                            const char *outputLayerName, int32_t *outErrCode);

// Create one rectangular envelope polygon for every non-empty input geometry.
const char *BoundingBoxLayer(LayerHandle handle, const char *outputPath,
                             const char *outputLayerName, int32_t *outErrCode);

// Split multipart geometries into individual singlepart features.
const char *MultipartToSinglepartsLayer(LayerHandle handle, const char *outputPath,
                                        const char *outputLayerName, int32_t *outErrCode);

// Export features matching a QGIS expression.
const char *ExtractByExpressionLayer(LayerHandle handle, const char *expressionText,
                                     const char *outputPath, const char *outputLayerName,
                                     int32_t *outErrCode);

// Subtract the union of the overlay layer from every input feature.
const char *DifferenceLayer(LayerHandle inputHandle, LayerHandle overlayHandle,
                            const char *outputPath, const char *outputLayerName,
                            int32_t *outErrCode);

// Create one geometry containing the symmetric difference of two layer unions.
const char *SymmetricalDifferenceLayer(LayerHandle inputHandle, LayerHandle overlayHandle,
                                       const char *outputPath, const char *outputLayerName,
                                       int32_t *outErrCode);

// Merge two compatible vector layers into one output dataset.
const char *MergeLayers(LayerHandle firstHandle, LayerHandle secondHandle,
                        const char *outputPath, const char *outputLayerName,
                        int32_t *outErrCode);

// Create non-overlapping buffer rings from a comma-separated distance list.
const char *MultiRingBufferLayer(LayerHandle handle, const char *distanceList,
                                 const char *outputPath, const char *outputLayerName,
                                 int32_t *outErrCode);

// Export input features matching a spatial predicate against an overlay layer.
const char *ExtractByLocationLayer(LayerHandle inputHandle, LayerHandle overlayHandle,
                                   int32_t predicateMode, const char *outputPath,
                                   const char *outputLayerName, int32_t *outErrCode);

// Join spatial match counts and first matching feature id onto input features.
const char *SpatialJoinSummaryLayer(LayerHandle inputHandle, LayerHandle joinHandle,
                                    int32_t predicateMode, const char *outputPath,
                                    const char *outputLayerName, int32_t *outErrCode);

// Intersect two layers and preserve attributes from both inputs.
const char *IntersectionLayer(LayerHandle inputHandle, LayerHandle overlayHandle,
                              const char *outputPath, const char *outputLayerName,
                              int32_t *outErrCode);

// Create shortest-line nearest-neighbor links between two layers.
const char *NearestNeighborLayer(LayerHandle inputHandle, LayerHandle targetHandle,
                                 const char *outputPath, const char *outputLayerName,
                                 int32_t *outErrCode);

// Create Voronoi polygons from representative points of input features.
const char *VoronoiLayer(LayerHandle handle, double tolerance, const char *outputPath,
                         const char *outputLayerName, int32_t *outErrCode);

// Create an oriented minimum bounding rectangle for every input feature.
const char *OrientedMinimumBoundingBoxLayer(LayerHandle handle, const char *outputPath,
                                            const char *outputLayerName, int32_t *outErrCode);

// Native presentation/rendering bridge backed by QGIS renderer, labeling, raster renderer and map renderer APIs.
const char *ApplyVectorStyle(LayerHandle handle, int32_t rendererMode, const char *rendererField,
                             int32_t colorRamp, int32_t linePattern, int32_t fillPattern,
                             const char *pointColor, const char *lineColor, const char *fillColor,
                             const char *strokeColor, double lineWidth, double pointRadius,
                             double opacity, const char *symbolName, int32_t *outErrCode);
const char *ImportQmlStyle(LayerHandle handle, const char *qmlPath, int32_t *outErrCode);
const char *ExportQmlStyle(LayerHandle handle, const char *qmlPath, int32_t *outErrCode);
const char *ApplyVectorLabeling(LayerHandle handle, bool enabled, const char *labelField,
                                double labelSize, const char *labelColor, bool halo,
                                bool avoidance, double minScale, double maxScale,
                                int32_t *outErrCode);
const char *ConfigureRasterDisplay(LayerHandle handle, int32_t bandMode, int32_t stretchMode,
                                   int32_t colorRamp, double opacity, const char *noData,
                                   const char *transparentColor, bool hillshade,
                                   int32_t *outErrCode);
const char *RenderMapView(const char *outputPath, double minX, double minY, double maxX, double maxY,
                          int32_t width, int32_t height, const char *visibleLayerHandles,
                          const char *destinationCrs, int32_t *outErrCode);
const char *ExportMapLayout(const char *title, const char *outputPath, const char *format,
                            bool showLegend, bool showScaleBar, bool showNorthArrow,
                            bool showGrid, int32_t width, int32_t height,
                            const char *legendTitle, const char *scaleText, const char *footerText,
                            int32_t basemapMode, const char *basemapLabel,
                            const char *basemapImagePath, const char *visibleLayerHandles, int32_t *outErrCode);

// Coordinate reference system bridge backed by QGIS CRS/PROJ APIs when available.
const char *DescribeCoordinateReferenceSystem(const char *definition, int32_t *outErrCode);
const char *TransformCoordinate(const char *sourceDefinition, const char *targetDefinition,
                                double x, double y, int32_t *outErrCode);
const char *TransformEnvelope(const char *sourceDefinition, const char *targetDefinition,
                              double minX, double minY, double maxX, double maxY,
                              int32_t *outErrCode);

// Reads LAS/LAZ/COPC headers using the QGIS lazperf/COPC core without loading
// the complete point set into memory.
const char *InspectPointCloud(const char *filePath, int32_t *outErrCode);
const char *ProcessPointCloud(const char *inputPath, const char *operation, const char *optionsText,
                              const char *outputPath, int32_t *outErrCode);

// Manage a durable edit session for a loaded vector layer. Edit operations keep
// their changes in the provider edit buffer while a session is active; callers
// must explicitly commit or roll back the session.
const char *BeginEditSession(LayerHandle handle, int32_t *outErrCode);
const char *CommitEditSession(LayerHandle handle, int32_t *outErrCode);
const char *RollbackEditSession(LayerHandle handle, int32_t *outErrCode);
const char *UndoEdit(LayerHandle handle, int32_t *outErrCode);
const char *RedoEdit(LayerHandle handle, int32_t *outErrCode);
bool IsEditing(LayerHandle handle);
bool HasPendingEdits(LayerHandle handle);
bool CanUndo(LayerHandle handle);
bool CanRedo(LayerHandle handle);

// Edit a loaded vector layer through QGIS provider APIs.
const char *AddFeature(LayerHandle handle, int32_t geometryType, const char *coordsText, int32_t *outErrCode);
const char *DeleteFeature(LayerHandle handle, int64_t fid, int32_t *outErrCode);
const char *MoveFeatureNode(LayerHandle handle, int64_t fid, int32_t partIndex, int32_t pointIndex,
                            double x, double y, int32_t *outErrCode);
const char *DeleteFeatureNode(LayerHandle handle, int64_t fid, int32_t partIndex, int32_t pointIndex,
                              int32_t *outErrCode);
const char *CopyFeature(LayerHandle handle, int64_t fid, int32_t *outErrCode);
const char *SplitFeature(LayerHandle handle, int64_t fid, const char *coordsText, int32_t *outErrCode);
const char *MergeFeatures(LayerHandle handle, const char *fidListText, int32_t *outErrCode);
const char *SnapLayer(LayerHandle handle, LayerHandle targetHandle, double tolerance, int32_t *outErrCode);
const char *UpdateFeatureAttribute(LayerHandle handle, int64_t fid, const char *fieldName,
                                   const char *value, int32_t *outErrCode);
const char *BatchAssignAttribute(LayerHandle handle, const char *fieldName, const char *filterText,
                                 const char *value, int32_t *outErrCode);
const char *AddLayerField(LayerHandle handle, const char *fieldName, const char *typeName,
                          int32_t *outErrCode);
const char *DeleteLayerField(LayerHandle handle, const char *fieldName, int32_t *outErrCode);
const char *CalculateField(LayerHandle handle, const char *fieldName, int32_t calculatorMode,
                           const char *constantValue, int32_t *outErrCode);

// Free a C string returned by this module.
void FreeCString(char *str);

} // namespace geonest

#endif // GEONEST_GIS_CORE_H
