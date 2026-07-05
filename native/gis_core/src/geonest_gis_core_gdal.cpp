#include "geonest_gis_core.h"

#include <cpl_conv.h>
#include <gdal_priv.h>
#include <ogrsf_frmts.h>

#include <cstdlib>
#include <cstring>
#include <fstream>
#include <map>
#include <memory>
#include <mutex>
#include <string>

namespace geonest {
namespace {

struct DatasetDeleter {
    void operator()(GDALDataset *dataset) const
    {
        if (dataset) {
            GDALClose(dataset);
        }
    }
};

struct GeometryDeleter {
    void operator()(OGRGeometry *geometry) const
    {
        if (geometry) {
            OGRGeometryFactory::destroyGeometry(geometry);
        }
    }
};

using GeometryPtr = std::unique_ptr<OGRGeometry, GeometryDeleter>;

struct GdalLayerState {
    LayerHandle handle = 0;
    std::string filePath;
    std::unique_ptr<GDALDataset, DatasetDeleter> dataset;
    int layerIndex = 0;
};

static std::mutex g_mutex;
static std::map<LayerHandle, std::unique_ptr<GdalLayerState>> g_layers;
static LayerHandle g_nextHandle = 1;
static bool g_gdalReady = false;

static void EnsureGdal()
{
    if (!g_gdalReady) {
        GDALAllRegister();
        g_gdalReady = true;
    }
}

static char *DuplicateCString(const std::string &value)
{
    char *buf = static_cast<char *>(malloc(value.size() + 1));
    if (buf) {
        memcpy(buf, value.c_str(), value.size() + 1);
    }
    return buf;
}

static std::string EscapeJson(const std::string &value)
{
    std::string out;
    for (size_t i = 0; i < value.size(); i++) {
        char c = value[i];
        if (c == '"') {
            out += "\\\"";
        } else if (c == '\\') {
            out += "\\\\";
        } else if (c == '\n') {
            out += "\\n";
        } else if (c == '\r') {
            out += "\\r";
        } else if (c == '\t') {
            out += "\\t";
        } else {
            out += c;
        }
    }
    return out;
}

static int32_t MapGeometryType(OGRwkbGeometryType geometryType)
{
    OGRwkbGeometryType flatType = wkbFlatten(geometryType);
    if (flatType == wkbPoint) {
        return GEOM_POINT;
    }
    if (flatType == wkbLineString) {
        return GEOM_LINESTRING;
    }
    if (flatType == wkbPolygon) {
        return GEOM_POLYGON;
    }
    if (flatType == wkbMultiPoint) {
        return GEOM_MULTIPOINT;
    }
    if (flatType == wkbMultiLineString) {
        return GEOM_MULTILINESTRING;
    }
    if (flatType == wkbMultiPolygon) {
        return GEOM_MULTIPOLYGON;
    }
    return GEOM_UNKNOWN;
}

static int32_t NormalizeGeometryType(OGRwkbGeometryType geometryType)
{
    int32_t mappedType = MapGeometryType(geometryType);
    if (mappedType == GEOM_MULTIPOINT) {
        return GEOM_POINT;
    }
    if (mappedType == GEOM_MULTILINESTRING) {
        return GEOM_LINESTRING;
    }
    if (mappedType == GEOM_MULTIPOLYGON) {
        return GEOM_POLYGON;
    }
    return mappedType;
}

static void AppendEnvelope(std::string &json, const OGREnvelope &envelope)
{
    json += "{\"minX\":";
    json += std::to_string(envelope.MinX);
    json += ",\"minY\":";
    json += std::to_string(envelope.MinY);
    json += ",\"maxX\":";
    json += std::to_string(envelope.MaxX);
    json += ",\"maxY\":";
    json += std::to_string(envelope.MaxY);
    json += "}";
}

static OGREnvelope EmptyEnvelope()
{
    OGREnvelope envelope;
    envelope.MinX = 0;
    envelope.MinY = 0;
    envelope.MaxX = 0;
    envelope.MaxY = 0;
    return envelope;
}

static void AppendPoint(std::string &json, const OGRPoint *point)
{
    json += "{\"x\":";
    json += std::to_string(point ? point->getX() : 0.0);
    json += ",\"y\":";
    json += std::to_string(point ? point->getY() : 0.0);
    json += ",\"z\":";
    json += std::to_string(point && point->getCoordinateDimension() >= 3 ? point->getZ() : 0.0);
    json += ",\"hasZ\":";
    json += point && point->getCoordinateDimension() >= 3 ? "true" : "false";
    json += "}";
}

static void AppendLinePart(std::string &json, const OGRLineString *line, bool &firstPart)
{
    if (!line) {
        return;
    }
    if (!firstPart) {
        json += ",";
    }
    firstPart = false;
    json += "{\"points\":[";
    for (int i = 0; i < line->getNumPoints(); i++) {
        if (i > 0) {
            json += ",";
        }
        OGRPoint point;
        line->getPoint(i, &point);
        AppendPoint(json, &point);
    }
    json += "]}";
}

static void AppendPointPart(std::string &json, const OGRPoint *point, bool &firstPart)
{
    if (!firstPart) {
        json += ",";
    }
    firstPart = false;
    json += "{\"points\":[";
    AppendPoint(json, point);
    json += "]}";
}

static void AppendPolygonParts(std::string &json, const OGRPolygon *polygon, bool &firstPart)
{
    if (!polygon) {
        return;
    }
    AppendLinePart(json, polygon->getExteriorRing(), firstPart);
    for (int i = 0; i < polygon->getNumInteriorRings(); i++) {
        AppendLinePart(json, polygon->getInteriorRing(i), firstPart);
    }
}

static void AppendGeometryParts(std::string &json, const OGRGeometry *geometry, bool &firstPart)
{
    if (!geometry) {
        return;
    }

    OGRwkbGeometryType flatType = wkbFlatten(geometry->getGeometryType());
    if (flatType == wkbPoint) {
        AppendPointPart(json, geometry->toPoint(), firstPart);
    } else if (flatType == wkbLineString) {
        AppendLinePart(json, geometry->toLineString(), firstPart);
    } else if (flatType == wkbPolygon) {
        AppendPolygonParts(json, geometry->toPolygon(), firstPart);
    } else if (flatType == wkbMultiPoint || flatType == wkbMultiLineString ||
               flatType == wkbMultiPolygon || flatType == wkbGeometryCollection) {
        const OGRGeometryCollection *collection = geometry->toGeometryCollection();
        for (int i = 0; collection && i < collection->getNumGeometries(); i++) {
            AppendGeometryParts(json, collection->getGeometryRef(i), firstPart);
        }
    }
}

static std::string SpatialRefId(const OGRSpatialReference *srs)
{
    if (!srs) {
        return "";
    }

    const char *authorityName = srs->GetAuthorityName(nullptr);
    const char *authorityCode = srs->GetAuthorityCode(nullptr);
    if (authorityName && authorityCode) {
        std::string value(authorityName);
        value += ":";
        value += authorityCode;
        return value;
    }
    return "";
}

static int32_t SpatialUnitType(const OGRSpatialReference *srs)
{
    if (!srs) {
        return 0;
    }
    if (srs->IsGeographic()) {
        return 1;
    }
    if (srs->IsProjected()) {
        return 2;
    }
    return 0;
}

static std::string SpatialUnitName(const OGRSpatialReference *srs)
{
    if (!srs) {
        return "";
    }
    const char *unitName = nullptr;
    if (srs->IsGeographic()) {
        srs->GetAngularUnits(&unitName);
    } else if (srs->IsProjected()) {
        srs->GetLinearUnits(&unitName);
    }
    return unitName ? std::string(unitName) : std::string();
}

static OGRLayer *LayerFromState(const GdalLayerState *state)
{
    if (!state || !state->dataset) {
        return nullptr;
    }
    return state->dataset->GetLayer(state->layerIndex);
}

static GdalLayerState *FindLayer(LayerHandle handle)
{
    std::map<LayerHandle, std::unique_ptr<GdalLayerState>>::iterator it = g_layers.find(handle);
    if (it == g_layers.end()) {
        return nullptr;
    }
    return it->second.get();
}

static std::string FieldTypeName(OGRFieldType type)
{
    const char *name = OGRFieldDefn::GetFieldTypeName(type);
    return name ? std::string(name) : std::string("unknown");
}

static std::string BuildLayerJson(OGRLayer *layer, LayerHandle handle)
{
    OGREnvelope envelope = EmptyEnvelope();
    if (!layer || layer->GetExtent(&envelope, TRUE) != OGRERR_NONE) {
        envelope = EmptyEnvelope();
    }

    OGRFeatureDefn *definition = layer ? layer->GetLayerDefn() : nullptr;
    OGRSpatialReference *srs = layer ? layer->GetSpatialRef() : nullptr;

    std::string json = "{\"layerId\":\"L";
    json += std::to_string(handle);
    json += "\",\"name\":\"";
    json += EscapeJson(layer ? layer->GetName() : "");
    json += "\",\"geometryType\":";
    json += std::to_string(definition ? NormalizeGeometryType(definition->GetGeomType()) : GEOM_UNKNOWN);
    json += ",\"featureCount\":";
    json += std::to_string(layer ? static_cast<long long>(layer->GetFeatureCount(FALSE)) : 0);
    json += ",\"envelope\":";
    AppendEnvelope(json, envelope);
    json += ",\"crs\":\"";
    json += EscapeJson(SpatialRefId(srs));
    json += "\",\"coordinateUnitName\":\"";
    json += EscapeJson(SpatialUnitName(srs));
    json += "\",\"coordinateUnitType\":";
    json += std::to_string(SpatialUnitType(srs));
    json += ",\"fields\":[";
    if (definition) {
        for (int i = 0; i < definition->GetFieldCount(); i++) {
            if (i > 0) {
                json += ",";
            }
            OGRFieldDefn *field = definition->GetFieldDefn(i);
            json += "{\"name\":\"";
            json += EscapeJson(field ? field->GetNameRef() : "");
            json += "\",\"alias\":\"";
            json += EscapeJson(field ? field->GetAlternativeNameRef() : "");
            json += "\",\"typeName\":\"";
            json += EscapeJson(field ? FieldTypeName(field->GetType()) : "unknown");
            json += "\",\"width\":";
            json += std::to_string(field ? field->GetWidth() : 0);
            json += ",\"precision\":";
            json += std::to_string(field ? field->GetPrecision() : 0);
            json += ",\"nullable\":";
            json += field && field->IsNullable() ? "true" : "false";
            json += "}";
        }
    }
    json += "]}";
    return json;
}

static std::string BuildGeometryJson(const OGRGeometry *geometry)
{
    int32_t geometryType = geometry ? NormalizeGeometryType(geometry->getGeometryType()) : GEOM_UNKNOWN;
    OGREnvelope envelope = EmptyEnvelope();
    if (geometry) {
        geometry->getEnvelope(&envelope);
    }

    std::string json = "{\"geometryType\":";
    json += std::to_string(geometryType);
    json += ",\"parts\":[";
    bool firstPart = true;
    AppendGeometryParts(json, geometry, firstPart);
    json += "],\"envelope\":";
    AppendEnvelope(json, envelope);
    json += ",\"crs\":\"\"}";
    return json;
}

static std::string FeatureFieldText(OGRFeature *feature, int fieldIndex)
{
    if (!feature || !feature->IsFieldSetAndNotNull(fieldIndex)) {
        return "";
    }
    const char *value = feature->GetFieldAsString(fieldIndex);
    return value ? std::string(value) : std::string();
}

static double FeatureFieldNumber(OGRFeature *feature, int fieldIndex, bool &isNumber)
{
    isNumber = false;
    if (!feature || !feature->IsFieldSetAndNotNull(fieldIndex)) {
        return 0.0;
    }
    OGRFeatureDefn *definition = feature->GetDefnRef();
    OGRFieldDefn *field = definition ? definition->GetFieldDefn(fieldIndex) : nullptr;
    if (!field) {
        return 0.0;
    }
    OGRFieldType type = field->GetType();
    if (type == OFTInteger || type == OFTInteger64 || type == OFTReal) {
        isNumber = true;
        return feature->GetFieldAsDouble(fieldIndex);
    }
    return 0.0;
}

static std::string BuildFeatureJson(OGRFeature *feature)
{
    OGRGeometry *geometry = feature ? feature->GetGeometryRef() : nullptr;
    OGREnvelope envelope = EmptyEnvelope();
    if (geometry) {
        geometry->getEnvelope(&envelope);
    }
    OGRFeatureDefn *definition = feature ? feature->GetDefnRef() : nullptr;

    std::string json = "{\"featureId\":\"";
    json += std::to_string(feature ? static_cast<long long>(feature->GetFID()) : 0);
    json += "\",\"geometry\":";
    json += BuildGeometryJson(geometry);
    json += ",\"envelope\":";
    AppendEnvelope(json, envelope);
    json += ",\"attributesPreview\":[";
    if (definition) {
        for (int i = 0; i < definition->GetFieldCount(); i++) {
            if (i > 0) {
                json += ",";
            }
            OGRFieldDefn *field = definition->GetFieldDefn(i);
            bool isNull = !feature || !feature->IsFieldSetAndNotNull(i);
            bool isNumber = false;
            double numberValue = FeatureFieldNumber(feature, i, isNumber);
            json += "{\"name\":\"";
            json += EscapeJson(field ? field->GetNameRef() : "");
            json += "\",\"typeName\":\"";
            json += EscapeJson(field ? FieldTypeName(field->GetType()) : "unknown");
            json += "\",\"textValue\":\"";
            json += EscapeJson(isNull ? "" : FeatureFieldText(feature, i));
            json += "\",\"numberValue\":";
            json += std::to_string(isNumber ? numberValue : 0.0);
            json += ",\"boolValue\":";
            json += (!isNull && FeatureFieldText(feature, i) == "true") ? "true" : "false";
            json += ",\"isNull\":";
            json += isNull ? "true" : "false";
            json += "}";
        }
    }
    json += "]}";
    return json;
}

static bool FileExists(const char *filePath)
{
    std::ifstream input(filePath, std::ios::binary);
    return input.good();
}

static std::string BuildProcessResultJson(bool ok, int32_t code, const std::string &message,
                                          const std::string &outputPath,
                                          const std::string &outputLayerName,
                                          int32_t featureCount)
{
    std::string json = "{\"ok\":";
    json += ok ? "true" : "false";
    json += ",\"code\":";
    json += std::to_string(code);
    json += ",\"message\":\"";
    json += EscapeJson(message);
    json += "\",\"outputPath\":\"";
    json += EscapeJson(outputPath);
    json += "\",\"outputLayerName\":\"";
    json += EscapeJson(outputLayerName);
    json += "\",\"featureCount\":";
    json += std::to_string(featureCount);
    json += "}";
    return json;
}

static OGRwkbGeometryType OutputGeometryType(OGRLayer *sourceLayer, bool forcePolygon)
{
    if (forcePolygon) {
        return wkbPolygon;
    }
    OGRFeatureDefn *definition = sourceLayer ? sourceLayer->GetLayerDefn() : nullptr;
    if (!definition) {
        return wkbUnknown;
    }
    OGRwkbGeometryType flatType = wkbFlatten(definition->GetGeomType());
    if (flatType == wkbMultiPoint) {
        return wkbPoint;
    }
    if (flatType == wkbMultiLineString) {
        return wkbLineString;
    }
    if (flatType == wkbMultiPolygon) {
        return wkbPolygon;
    }
    return flatType;
}

static bool CopyLayerFields(OGRLayer *sourceLayer, OGRLayer *outputLayer)
{
    OGRFeatureDefn *definition = sourceLayer ? sourceLayer->GetLayerDefn() : nullptr;
    if (!definition || !outputLayer) {
        return false;
    }
    for (int i = 0; i < definition->GetFieldCount(); i++) {
        OGRFieldDefn *field = definition->GetFieldDefn(i);
        if (field) {
            OGRFieldDefn outputField(field);
            if (outputLayer->CreateField(&outputField) != OGRERR_NONE) {
                return false;
            }
        }
    }
    return true;
}

static OGRLayer *CreateOutputLayerWithSrs(const char *outputPath, const char *outputLayerName,
                                          OGRLayer *sourceLayer, OGRwkbGeometryType geometryType,
                                          OGRSpatialReference *srs, GDALDataset **outDataset)
{
    if (!outputPath || std::strlen(outputPath) == 0 || !sourceLayer || !outDataset) {
        return nullptr;
    }
    GDALDriver *driver = GetGDALDriverManager()->GetDriverByName("ESRI Shapefile");
    if (!driver) {
        return nullptr;
    }
    if (FileExists(outputPath)) {
        driver->Delete(outputPath);
    }
    GDALDataset *dataset = driver->Create(outputPath, 0, 0, 0, GDT_Unknown, nullptr);
    if (!dataset) {
        return nullptr;
    }
    std::string layerName = outputLayerName && std::strlen(outputLayerName) > 0 ? outputLayerName : "geonest_output";
    OGRLayer *outputLayer = dataset->CreateLayer(layerName.c_str(), srs, geometryType, nullptr);
    if (!outputLayer) {
        GDALClose(dataset);
        return nullptr;
    }
    if (!CopyLayerFields(sourceLayer, outputLayer)) {
        GDALClose(dataset);
        return nullptr;
    }
    *outDataset = dataset;
    return outputLayer;
}

static OGRLayer *CreateOutputLayer(const char *outputPath, const char *outputLayerName,
                                   OGRLayer *sourceLayer, OGRwkbGeometryType geometryType,
                                   GDALDataset **outDataset)
{
    OGRSpatialReference *srs = sourceLayer ? sourceLayer->GetSpatialRef() : nullptr;
    return CreateOutputLayerWithSrs(outputPath, outputLayerName, sourceLayer, geometryType, srs, outDataset);
}

static std::unique_ptr<OGRSpatialReference> CreateSpatialReferenceFromDefinition(const char *definition)
{
    if (!definition || std::strlen(definition) == 0) {
        return nullptr;
    }
    std::unique_ptr<OGRSpatialReference> srs(new OGRSpatialReference());
    if (srs->SetFromUserInput(definition) != OGRERR_NONE) {
        return nullptr;
    }
    srs->SetAxisMappingStrategy(OAMS_TRADITIONAL_GIS_ORDER);
    return srs;
}

static bool WriteOutputFeature(OGRLayer *outputLayer, OGRFeature *sourceFeature, GeometryPtr geometry)
{
    if (!outputLayer || !sourceFeature || !geometry || geometry->IsEmpty()) {
        return false;
    }
    OGRFeature *outputFeature = OGRFeature::CreateFeature(outputLayer->GetLayerDefn());
    if (!outputFeature) {
        return false;
    }
    outputFeature->SetFrom(sourceFeature, TRUE);
    outputFeature->SetGeometryDirectly(geometry.release());
    OGRErr err = outputLayer->CreateFeature(outputFeature);
    OGRFeature::DestroyFeature(outputFeature);
    return err == OGRERR_NONE;
}

static GeometryPtr BuildLayerUnion(OGRLayer *layer)
{
    if (!layer) {
        return GeometryPtr(nullptr);
    }
    layer->ResetReading();
    GeometryPtr unionGeometry(nullptr);
    while (OGRFeature *feature = layer->GetNextFeature()) {
        OGRGeometry *geometry = feature->GetGeometryRef();
        if (geometry && !geometry->IsEmpty()) {
            if (!unionGeometry) {
                unionGeometry.reset(geometry->clone());
            } else {
                GeometryPtr nextUnion(unionGeometry->Union(geometry));
                if (nextUnion) {
                    unionGeometry.reset(nextUnion.release());
                }
            }
        }
        OGRFeature::DestroyFeature(feature);
    }
    layer->ResetReading();
    return unionGeometry;
}

} // namespace

const char *GetNativeVersion()
{
    return "GeoNest GIS Native Core 0.6.0";
}

const char *GetCoreProfile()
{
    return "GDAL/OGR vector backend";
}

LayerHandle OpenVectorLayer(const char *filePath, char **outLayerInfo, int32_t *outErrCode)
{
    if (!filePath || std::strlen(filePath) == 0) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return 0;
    }

    std::lock_guard<std::mutex> lock(g_mutex);
    EnsureGdal();

    if (!FileExists(filePath)) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_FILE_NOT_FOUND;
        }
        return 0;
    }

    GDALDataset *rawDataset = static_cast<GDALDataset *>(
        GDALOpenEx(filePath, GDAL_OF_VECTOR | GDAL_OF_READONLY, nullptr, nullptr, nullptr));
    if (!rawDataset || rawDataset->GetLayerCount() <= 0) {
        if (rawDataset) {
            GDALClose(rawDataset);
        }
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_FORMAT;
        }
        return 0;
    }

    LayerHandle handle = g_nextHandle++;
    std::unique_ptr<GdalLayerState> state(new GdalLayerState());
    state->handle = handle;
    state->filePath = filePath;
    state->dataset.reset(rawDataset);
    state->layerIndex = 0;

    OGRLayer *layer = LayerFromState(state.get());
    if (!layer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return 0;
    }

    std::string layerJson = BuildLayerJson(layer, handle);
    g_layers[handle] = std::move(state);

    if (outLayerInfo) {
        *outLayerInfo = DuplicateCString(layerJson);
    }
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return handle;
}

int32_t CloseLayer(LayerHandle handle)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    std::map<LayerHandle, std::unique_ptr<GdalLayerState>>::iterator it = g_layers.find(handle);
    if (it == g_layers.end()) {
        return GIS_ERR_LAYER_NOT_FOUND;
    }
    g_layers.erase(it);
    return GIS_OK;
}

const char *GetLayerInfo(LayerHandle handle, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    GdalLayerState *state = FindLayer(handle);
    OGRLayer *layer = LayerFromState(state);
    if (!layer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return nullptr;
    }

    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(BuildLayerJson(layer, handle));
}

const char *QueryFeatures(LayerHandle handle, double minX, double minY, double maxX, double maxY,
                          int32_t limit, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    GdalLayerState *state = FindLayer(handle);
    OGRLayer *layer = LayerFromState(state);
    if (!layer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return nullptr;
    }

    layer->ResetReading();
    bool useSpatialFilter = limit > 0 && minX < maxX && minY < maxY;
    if (useSpatialFilter) {
        layer->SetSpatialFilterRect(minX, minY, maxX, maxY);
    }

    std::string json = "{\"layerId\":\"L";
    json += std::to_string(handle);
    json += "\",\"features\":[";

    bool first = true;
    int32_t count = 0;
    while (OGRFeature *feature = layer->GetNextFeature()) {
        if (!first) {
            json += ",";
        }
        first = false;
        json += BuildFeatureJson(feature);
        OGRFeature::DestroyFeature(feature);
        count++;
        if (limit > 0 && count >= limit) {
            break;
        }
    }
    if (useSpatialFilter) {
        layer->SetSpatialFilter(nullptr);
    }

    json += "],\"hasMore\":false}";
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(json);
}

const char *GetFeature(LayerHandle handle, int64_t fid, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    GdalLayerState *state = FindLayer(handle);
    OGRLayer *layer = LayerFromState(state);
    if (!layer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return nullptr;
    }

    OGRFeature *feature = layer->GetFeature(static_cast<GIntBig>(fid));
    if (!feature) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_FEATURE_NOT_FOUND;
        }
        return nullptr;
    }

    std::string json = BuildFeatureJson(feature);
    OGRFeature::DestroyFeature(feature);
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(json);
}

const char *BufferLayer(LayerHandle handle, double distance, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (distance <= 0.0 || !outputPath || std::strlen(outputPath) == 0) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM,
            "Invalid buffer parameters", outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0));
    }
    EnsureGdal();
    GdalLayerState *state = FindLayer(handle);
    OGRLayer *sourceLayer = LayerFromState(state);
    if (!sourceLayer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_LAYER_NOT_FOUND,
            "Input layer not found", outputPath, outputLayerName ? outputLayerName : "", 0));
    }

    GDALDataset *rawOutputDataset = nullptr;
    OGRLayer *outputLayer = CreateOutputLayer(outputPath, outputLayerName, sourceLayer, wkbPolygon, &rawOutputDataset);
    std::unique_ptr<GDALDataset, DatasetDeleter> outputDataset(rawOutputDataset);
    if (!outputLayer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_WRITE_FAILED,
            "Failed to create buffer output", outputPath, outputLayerName ? outputLayerName : "", 0));
    }

    int32_t writtenCount = 0;
    sourceLayer->ResetReading();
    while (OGRFeature *feature = sourceLayer->GetNextFeature()) {
        OGRGeometry *geometry = feature->GetGeometryRef();
        if (geometry && !geometry->IsEmpty()) {
            GeometryPtr bufferedGeometry(geometry->Buffer(distance));
            if (WriteOutputFeature(outputLayer, feature, std::move(bufferedGeometry))) {
                writtenCount++;
            }
        }
        OGRFeature::DestroyFeature(feature);
    }
    sourceLayer->ResetReading();
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(BuildProcessResultJson(true, GIS_OK, "Buffer completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount));
}

const char *RepairLayer(LayerHandle handle, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM,
            "Invalid repair parameters", "", outputLayerName ? outputLayerName : "", 0));
    }
    EnsureGdal();
    GdalLayerState *state = FindLayer(handle);
    OGRLayer *sourceLayer = LayerFromState(state);
    if (!sourceLayer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_LAYER_NOT_FOUND,
            "Input layer not found", outputPath, outputLayerName ? outputLayerName : "", 0));
    }

    GDALDataset *rawOutputDataset = nullptr;
    OGRLayer *outputLayer = CreateOutputLayer(outputPath, outputLayerName, sourceLayer,
        OutputGeometryType(sourceLayer, false), &rawOutputDataset);
    std::unique_ptr<GDALDataset, DatasetDeleter> outputDataset(rawOutputDataset);
    if (!outputLayer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_WRITE_FAILED,
            "Failed to create repair output", outputPath, outputLayerName ? outputLayerName : "", 0));
    }

    int32_t writtenCount = 0;
    sourceLayer->ResetReading();
    while (OGRFeature *feature = sourceLayer->GetNextFeature()) {
        OGRGeometry *geometry = feature->GetGeometryRef();
        if (geometry && !geometry->IsEmpty()) {
            GeometryPtr repairedGeometry(geometry->MakeValid());
            if (!repairedGeometry) {
                repairedGeometry.reset(geometry->clone());
            }
            if (WriteOutputFeature(outputLayer, feature, std::move(repairedGeometry))) {
                writtenCount++;
            }
        }
        OGRFeature::DestroyFeature(feature);
    }
    sourceLayer->ResetReading();
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(BuildProcessResultJson(true, GIS_OK, "Repair completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount));
}

const char *ClipLayer(LayerHandle inputHandle, LayerHandle clipHandle, const char *outputPath,
                      const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0 || inputHandle == clipHandle) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM,
            "Invalid clip parameters", outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0));
    }
    EnsureGdal();
    OGRLayer *inputLayer = LayerFromState(FindLayer(inputHandle));
    OGRLayer *clipLayer = LayerFromState(FindLayer(clipHandle));
    if (!inputLayer || !clipLayer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_LAYER_NOT_FOUND,
            "Input or clip layer not found", outputPath, outputLayerName ? outputLayerName : "", 0));
    }
    GeometryPtr clipGeometry = BuildLayerUnion(clipLayer);
    if (!clipGeometry || clipGeometry->IsEmpty()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM,
            "Clip layer has no geometry", outputPath, outputLayerName ? outputLayerName : "", 0));
    }

    GDALDataset *rawOutputDataset = nullptr;
    OGRLayer *outputLayer = CreateOutputLayer(outputPath, outputLayerName, inputLayer,
        OutputGeometryType(inputLayer, false), &rawOutputDataset);
    std::unique_ptr<GDALDataset, DatasetDeleter> outputDataset(rawOutputDataset);
    if (!outputLayer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_WRITE_FAILED,
            "Failed to create clip output", outputPath, outputLayerName ? outputLayerName : "", 0));
    }

    int32_t writtenCount = 0;
    inputLayer->ResetReading();
    while (OGRFeature *feature = inputLayer->GetNextFeature()) {
        OGRGeometry *geometry = feature->GetGeometryRef();
        if (geometry && !geometry->IsEmpty() && geometry->Intersects(clipGeometry.get())) {
            GeometryPtr clippedGeometry(geometry->Intersection(clipGeometry.get()));
            if (WriteOutputFeature(outputLayer, feature, std::move(clippedGeometry))) {
                writtenCount++;
            }
        }
        OGRFeature::DestroyFeature(feature);
    }
    inputLayer->ResetReading();
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(BuildProcessResultJson(true, GIS_OK, "Clip completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount));
}

const char *ExportLayer(LayerHandle handle, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM,
            "Invalid export parameters", "", outputLayerName ? outputLayerName : "", 0));
    }
    EnsureGdal();
    OGRLayer *sourceLayer = LayerFromState(FindLayer(handle));
    if (!sourceLayer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_LAYER_NOT_FOUND,
            "Input layer not found", outputPath, outputLayerName ? outputLayerName : "", 0));
    }

    GDALDataset *rawOutputDataset = nullptr;
    OGRLayer *outputLayer = CreateOutputLayer(outputPath, outputLayerName, sourceLayer,
        OutputGeometryType(sourceLayer, false), &rawOutputDataset);
    std::unique_ptr<GDALDataset, DatasetDeleter> outputDataset(rawOutputDataset);
    if (!outputLayer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_WRITE_FAILED,
            "Failed to create export output", outputPath, outputLayerName ? outputLayerName : "", 0));
    }

    int32_t writtenCount = 0;
    sourceLayer->ResetReading();
    while (OGRFeature *feature = sourceLayer->GetNextFeature()) {
        OGRGeometry *geometry = feature->GetGeometryRef();
        if (geometry && !geometry->IsEmpty()) {
            GeometryPtr outputGeometry(geometry->clone());
            if (WriteOutputFeature(outputLayer, feature, std::move(outputGeometry))) {
                writtenCount++;
            }
        }
        OGRFeature::DestroyFeature(feature);
    }
    sourceLayer->ResetReading();
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(BuildProcessResultJson(true, GIS_OK, "Export completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount));
}

const char *DefineLayerProjection(LayerHandle handle, const char *targetDefinition, const char *outputPath,
                                  const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0 || !targetDefinition ||
        std::strlen(targetDefinition) == 0) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM,
            "Invalid define projection parameters", outputPath ? outputPath : "",
            outputLayerName ? outputLayerName : "", 0));
    }
    EnsureGdal();
    OGRLayer *sourceLayer = LayerFromState(FindLayer(handle));
    if (!sourceLayer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_LAYER_NOT_FOUND,
            "Input layer not found", outputPath, outputLayerName ? outputLayerName : "", 0));
    }
    std::unique_ptr<OGRSpatialReference> targetSrs = CreateSpatialReferenceFromDefinition(targetDefinition);
    if (!targetSrs) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM,
            "Invalid target CRS definition", outputPath, outputLayerName ? outputLayerName : "", 0));
    }

    GDALDataset *rawOutputDataset = nullptr;
    OGRLayer *outputLayer = CreateOutputLayerWithSrs(outputPath, outputLayerName, sourceLayer,
        OutputGeometryType(sourceLayer, false), targetSrs.get(), &rawOutputDataset);
    std::unique_ptr<GDALDataset, DatasetDeleter> outputDataset(rawOutputDataset);
    if (!outputLayer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_WRITE_FAILED,
            "Failed to create defined projection output", outputPath, outputLayerName ? outputLayerName : "", 0));
    }

    int32_t writtenCount = 0;
    sourceLayer->ResetReading();
    while (OGRFeature *feature = sourceLayer->GetNextFeature()) {
        OGRGeometry *geometry = feature->GetGeometryRef();
        if (geometry && !geometry->IsEmpty()) {
            GeometryPtr outputGeometry(geometry->clone());
            if (WriteOutputFeature(outputLayer, feature, std::move(outputGeometry))) {
                writtenCount++;
            }
        }
        OGRFeature::DestroyFeature(feature);
    }
    sourceLayer->ResetReading();
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(BuildProcessResultJson(true, GIS_OK, "Projection defined", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount));
}

const char *ProjectLayer(LayerHandle handle, const char *targetDefinition, const char *outputPath,
                         const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0 || !targetDefinition ||
        std::strlen(targetDefinition) == 0) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM,
            "Invalid project parameters", outputPath ? outputPath : "",
            outputLayerName ? outputLayerName : "", 0));
    }
    EnsureGdal();
    OGRLayer *sourceLayer = LayerFromState(FindLayer(handle));
    if (!sourceLayer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_LAYER_NOT_FOUND,
            "Input layer not found", outputPath, outputLayerName ? outputLayerName : "", 0));
    }
    OGRSpatialReference *sourceRawSrs = sourceLayer->GetSpatialRef();
    if (!sourceRawSrs) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM,
            "Invalid source or target CRS", outputPath, outputLayerName ? outputLayerName : "", 0));
    }
    std::unique_ptr<OGRSpatialReference> sourceSrs(sourceRawSrs->Clone());
    std::unique_ptr<OGRSpatialReference> targetSrs = CreateSpatialReferenceFromDefinition(targetDefinition);
    if (!sourceSrs || !targetSrs) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM,
            "Invalid source or target CRS", outputPath, outputLayerName ? outputLayerName : "", 0));
    }
    sourceSrs->SetAxisMappingStrategy(OAMS_TRADITIONAL_GIS_ORDER);
    std::unique_ptr<OGRCoordinateTransformation, decltype(&OCTDestroyCoordinateTransformation)> transform(
        OGRCreateCoordinateTransformation(sourceSrs.get(), targetSrs.get()), OCTDestroyCoordinateTransformation);
    if (!transform) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM,
            "CRS transformation is not possible", outputPath, outputLayerName ? outputLayerName : "", 0));
    }

    GDALDataset *rawOutputDataset = nullptr;
    OGRLayer *outputLayer = CreateOutputLayerWithSrs(outputPath, outputLayerName, sourceLayer,
        OutputGeometryType(sourceLayer, false), targetSrs.get(), &rawOutputDataset);
    std::unique_ptr<GDALDataset, DatasetDeleter> outputDataset(rawOutputDataset);
    if (!outputLayer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_WRITE_FAILED,
            "Failed to create projected output", outputPath, outputLayerName ? outputLayerName : "", 0));
    }

    int32_t writtenCount = 0;
    sourceLayer->ResetReading();
    while (OGRFeature *feature = sourceLayer->GetNextFeature()) {
        OGRGeometry *geometry = feature->GetGeometryRef();
        if (geometry && !geometry->IsEmpty()) {
            GeometryPtr outputGeometry(geometry->clone());
            if (!outputGeometry || outputGeometry->transform(transform.get()) != OGRERR_NONE) {
                std::string message = "Failed to transform feature ";
                message += std::to_string(static_cast<long long>(feature->GetFID()));
                OGRFeature::DestroyFeature(feature);
                sourceLayer->ResetReading();
                if (outErrCode) {
                    *outErrCode = GIS_ERR_INVALID_PARAM;
                }
                return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM, message,
                    outputPath, outputLayerName ? outputLayerName : "", writtenCount));
            }
            if (WriteOutputFeature(outputLayer, feature, std::move(outputGeometry))) {
                writtenCount++;
            }
        }
        OGRFeature::DestroyFeature(feature);
    }
    sourceLayer->ResetReading();
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(BuildProcessResultJson(true, GIS_OK, "Projection completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount));
}

void FreeCString(char *str)
{
    if (str) {
        free(str);
    }
}

} // namespace geonest
