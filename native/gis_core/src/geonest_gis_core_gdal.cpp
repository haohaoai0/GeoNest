#include "geonest_gis_core.h"

#include <cpl_conv.h>
#include <cpl_string.h>
#include <cpl_vsi.h>
#include <gdal_priv.h>
#include <ogrsf_frmts.h>

#include <cctype>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <map>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>

namespace geonest {

struct PreparedProcessingTask {};

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
    bool editSessionActive = false;
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
    OGRwkbGeometryType layerGeometryType = definition ? definition->GetGeomType() : wkbUnknown;
    json += ",\"hasZ\":";
    json += wkbHasZ(layerGeometryType) ? "true" : "false";
    json += ",\"hasM\":";
    json += wkbHasM(layerGeometryType) ? "true" : "false";
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

static std::string ToLowerAscii(const char *value)
{
    std::string result = value ? std::string(value) : std::string();
    for (size_t i = 0; i < result.size(); i++) {
        result[i] = static_cast<char>(std::tolower(static_cast<unsigned char>(result[i])));
    }
    return result;
}

static bool EndsWith(const std::string &value, const char *suffix)
{
    std::string tail = suffix ? std::string(suffix) : std::string();
    if (tail.size() > value.size()) {
        return false;
    }
    return value.compare(value.size() - tail.size(), tail.size(), tail) == 0;
}

static GDALDataset *OpenVectorWithDriver(const char *filePath, const char *driverName)
{
    const char *const allowedDrivers[] = { driverName, nullptr };
    return static_cast<GDALDataset *>(
        GDALOpenEx(filePath, GDAL_OF_VECTOR | GDAL_OF_READONLY, allowedDrivers, nullptr, nullptr));
}

static GDALDataset *OpenRasterWithDriver(const char *filePath, const char *driverName)
{
    const char *const allowedDrivers[] = { driverName, nullptr };
    return static_cast<GDALDataset *>(
        GDALOpenEx(filePath, GDAL_OF_RASTER | GDAL_OF_READONLY, allowedDrivers, nullptr, nullptr));
}

static void AddCandidate(std::vector<std::string> &drivers, const char *driverName)
{
    std::string candidate(driverName);
    for (size_t i = 0; i < drivers.size(); i++) {
        if (drivers[i] == candidate) {
            return;
        }
    }
    drivers.push_back(candidate);
}

static std::vector<std::string> VectorDriverCandidates(const char *filePath)
{
    std::string lower = ToLowerAscii(filePath);
    std::vector<std::string> drivers;
    if (EndsWith(lower, ".shp")) {
        AddCandidate(drivers, "ESRI Shapefile");
    } else if (EndsWith(lower, ".geojson") || EndsWith(lower, ".json") || EndsWith(lower, ".ovjsn")) {
        AddCandidate(drivers, "GeoJSON");
    } else if (EndsWith(lower, ".gpkg")) {
        AddCandidate(drivers, "GPKG");
        AddCandidate(drivers, "SQLite");
    } else if (EndsWith(lower, ".kml") || EndsWith(lower, ".ovkml")) {
        AddCandidate(drivers, "LIBKML");
        AddCandidate(drivers, "KML");
    } else if (EndsWith(lower, ".kmz") || EndsWith(lower, ".ovkmz")) {
        AddCandidate(drivers, "LIBKML");
    } else if (EndsWith(lower, ".csv") || EndsWith(lower, ".txt")) {
        AddCandidate(drivers, "CSV");
    } else if (EndsWith(lower, ".fgb")) {
        AddCandidate(drivers, "FlatGeobuf");
    } else if (EndsWith(lower, ".gpx")) {
        AddCandidate(drivers, "GPX");
    } else if (EndsWith(lower, ".dxf")) {
        AddCandidate(drivers, "DXF");
    } else if (EndsWith(lower, ".dwg") || EndsWith(lower, ".ovcad")) {
        AddCandidate(drivers, "CAD");
        AddCandidate(drivers, "DWG");
    } else if (EndsWith(lower, ".osm")) {
        AddCandidate(drivers, "OSM");
    } else if (EndsWith(lower, ".xml")) {
        AddCandidate(drivers, "GPX");
        AddCandidate(drivers, "LIBKML");
        AddCandidate(drivers, "KML");
        AddCandidate(drivers, "OSM");
    }
    return drivers;
}

static std::vector<std::string> RasterDriverCandidates(const char *filePath)
{
    std::string lower = ToLowerAscii(filePath);
    std::vector<std::string> drivers;
    if (EndsWith(lower, ".tif") || EndsWith(lower, ".tiff")) {
        AddCandidate(drivers, "GTiff");
    } else if (EndsWith(lower, ".jpg") || EndsWith(lower, ".jpeg")) {
        AddCandidate(drivers, "JPEG");
    } else if (EndsWith(lower, ".png")) {
        AddCandidate(drivers, "PNG");
    } else if (EndsWith(lower, ".ovmap")) {
        AddCandidate(drivers, "OziExplorer");
        AddCandidate(drivers, "MAP");
    } else if (EndsWith(lower, ".pdf")) {
        AddCandidate(drivers, "PDF");
    }
    return drivers;
}

static GDALDataset *OpenOziPltAsMemoryDataset(const char *filePath);

static GDALDataset *TryOpenVectorDataset(const char *filePath)
{
    GDALDataset *dataset = static_cast<GDALDataset *>(
        GDALOpenEx(filePath, GDAL_OF_VECTOR | GDAL_OF_READONLY, nullptr, nullptr, nullptr));
    if (dataset && dataset->GetLayerCount() > 0) {
        return dataset;
    }
    if (dataset) {
        GDALClose(dataset);
    }

    std::vector<std::string> drivers = VectorDriverCandidates(filePath);
    for (size_t i = 0; i < drivers.size(); i++) {
        dataset = OpenVectorWithDriver(filePath, drivers[i].c_str());
        if (dataset && dataset->GetLayerCount() > 0) {
            return dataset;
        }
        if (dataset) {
            GDALClose(dataset);
        }
    }

    std::string lower = ToLowerAscii(filePath);
    if (EndsWith(lower, ".plt")) {
        return OpenOziPltAsMemoryDataset(filePath);
    }
    return nullptr;
}

static GDALDataset *TryOpenRasterDataset(const char *filePath)
{
    GDALDataset *dataset = static_cast<GDALDataset *>(
        GDALOpenEx(filePath, GDAL_OF_RASTER | GDAL_OF_READONLY, nullptr, nullptr, nullptr));
    if (dataset && dataset->GetRasterCount() > 0) {
        return dataset;
    }
    if (dataset) {
        GDALClose(dataset);
    }

    std::vector<std::string> drivers = RasterDriverCandidates(filePath);
    for (size_t i = 0; i < drivers.size(); i++) {
        dataset = OpenRasterWithDriver(filePath, drivers[i].c_str());
        if (dataset && dataset->GetRasterCount() > 0) {
            return dataset;
        }
        if (dataset) {
            GDALClose(dataset);
        }
    }
    return nullptr;
}

static bool ParseCoordinateToken(const std::string &token, double *outValue)
{
    if (!outValue) {
        return false;
    }
    char *end = nullptr;
    double value = std::strtod(token.c_str(), &end);
    if (end == token.c_str()) {
        return false;
    }
    *outValue = value;
    return true;
}

static GDALDataset *OpenOziPltAsMemoryDataset(const char *filePath)
{
    std::ifstream input(filePath);
    if (!input.good()) {
        return nullptr;
    }

    OGRLineString line;
    std::string textLine;
    while (std::getline(input, textLine)) {
        std::stringstream stream(textLine);
        std::string latToken;
        std::string lonToken;
        if (!std::getline(stream, latToken, ',')) {
            continue;
        }
        if (!std::getline(stream, lonToken, ',')) {
            continue;
        }
        double lat = 0.0;
        double lon = 0.0;
        if (!ParseCoordinateToken(latToken, &lat) || !ParseCoordinateToken(lonToken, &lon)) {
            continue;
        }
        if (lat < -90.0 || lat > 90.0 || lon < -180.0 || lon > 180.0) {
            continue;
        }
        line.addPoint(lon, lat);
    }

    if (line.getNumPoints() < 2) {
        return nullptr;
    }

    GDALDriver *driver = GetGDALDriverManager()->GetDriverByName("MEM");
    if (!driver) {
        driver = GetGDALDriverManager()->GetDriverByName("Memory");
    }
    if (!driver) {
        return nullptr;
    }

    GDALDataset *dataset = driver->Create("", 0, 0, 0, GDT_Unknown, nullptr);
    if (!dataset) {
        return nullptr;
    }

    OGRSpatialReference srs;
    srs.SetWellKnownGeogCS("WGS84");
    srs.SetAxisMappingStrategy(OAMS_TRADITIONAL_GIS_ORDER);
    OGRLayer *layer = dataset->CreateLayer("track", &srs, wkbLineString, nullptr);
    if (!layer) {
        GDALClose(dataset);
        return nullptr;
    }

    OGRFieldDefn sourceField("source", OFTString);
    layer->CreateField(&sourceField);

    OGRFeature *feature = OGRFeature::CreateFeature(layer->GetLayerDefn());
    if (!feature) {
        GDALClose(dataset);
        return nullptr;
    }
    feature->SetField("source", filePath);
    feature->SetGeometry(&line);
    if (layer->CreateFeature(feature) != OGRERR_NONE) {
        OGRFeature::DestroyFeature(feature);
        GDALClose(dataset);
        return nullptr;
    }
    OGRFeature::DestroyFeature(feature);
    return dataset;
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

static std::string NormalizeArchiveMemberPath(const std::string &path)
{
    std::string normalized;
    normalized.reserve(path.size());
    for (size_t i = 0; i < path.size(); i++) {
        char ch = path[i];
        normalized += ch == '\\' ? '/' : ch;
    }
    return normalized;
}

static bool IsSafeArchiveMemberPath(const std::string &path)
{
    if (path.empty() || path[0] == '/') {
        return false;
    }
    if (path.size() >= 2 && path[1] == ':') {
        return false;
    }
    size_t segmentStart = 0;
    while (segmentStart <= path.size()) {
        size_t segmentEnd = path.find('/', segmentStart);
        if (segmentEnd == std::string::npos) {
            segmentEnd = path.size();
        }
        std::string segment = path.substr(segmentStart, segmentEnd - segmentStart);
        if (segment == "..") {
            return false;
        }
        if (segmentEnd == path.size()) {
            break;
        }
        segmentStart = segmentEnd + 1;
    }
    return true;
}

static std::string ParentDirectory(const std::string &path)
{
    size_t slash = path.find_last_of('/');
    if (slash == std::string::npos) {
        return "";
    }
    return path.substr(0, slash);
}

static bool EnsureDirectoryExists(const std::string &path)
{
    if (path.empty()) {
        return true;
    }
    return VSIMkdirRecursive(path.c_str(), 0755) == 0;
}

static bool CopyVsiFile(const std::string &sourcePath, const std::string &destinationPath,
                        long long *copiedBytes)
{
    VSILFILE *source = VSIFOpenL(sourcePath.c_str(), "rb");
    if (!source) {
        return false;
    }
    VSILFILE *destination = VSIFOpenL(destinationPath.c_str(), "wb");
    if (!destination) {
        VSIFCloseL(source);
        return false;
    }

    std::vector<unsigned char> buffer(64 * 1024);
    bool ok = true;
    while (true) {
        size_t readCount = VSIFReadL(buffer.data(), 1, buffer.size(), source);
        if (readCount == 0) {
            break;
        }
        size_t writeCount = VSIFWriteL(buffer.data(), 1, readCount, destination);
        if (writeCount != readCount) {
            ok = false;
            break;
        }
        if (copiedBytes) {
            *copiedBytes += static_cast<long long>(readCount);
        }
    }

    if (VSIFCloseL(destination) != 0) {
        ok = false;
    }
    VSIFCloseL(source);
    return ok;
}

static const char *ExtractZipArchiveImpl(const char *zipPath, const char *outputDirectory, int32_t *outErrCode)
{
    if (!zipPath || std::strlen(zipPath) == 0 || !outputDirectory || std::strlen(outputDirectory) == 0) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM,
            "Invalid archive extraction parameters", outputDirectory ? outputDirectory : "", "", 0));
    }

    EnsureGdal();
    if (!FileExists(zipPath)) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_FILE_NOT_FOUND;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_FILE_NOT_FOUND,
            "Archive file not found", outputDirectory, "", 0));
    }

    std::string destinationRoot = outputDirectory;
    while (!destinationRoot.empty() && destinationRoot[destinationRoot.size() - 1] == '/') {
        destinationRoot.resize(destinationRoot.size() - 1);
    }
    if (!EnsureDirectoryExists(destinationRoot)) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_WRITE_FAILED,
            "Failed to create archive extraction directory", destinationRoot, "", 0));
    }

    std::string archiveRoot = std::string("/vsizip/") + zipPath;
    char **entries = VSIReadDirRecursive(archiveRoot.c_str());
    if (!entries) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_FORMAT;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_FORMAT,
            "ZIP archive could not be read", destinationRoot, "", 0));
    }

    const int maxExtractedFiles = 2000;
    const long long maxExtractedBytes = 2LL * 1024LL * 1024LL * 1024LL;
    int extractedFiles = 0;
    long long extractedBytes = 0;
    bool failed = false;
    std::string failureMessage;

    for (int i = 0; entries[i] != nullptr; i++) {
        std::string relativePath = NormalizeArchiveMemberPath(entries[i]);
        if (relativePath.empty()) {
            continue;
        }
        if (!IsSafeArchiveMemberPath(relativePath)) {
            failed = true;
            failureMessage = "ZIP archive contains an unsafe path";
            break;
        }

        std::string sourcePath = archiveRoot + "/" + relativePath;
        VSIStatBufL statBuffer;
        if (VSIStatL(sourcePath.c_str(), &statBuffer) != 0) {
            continue;
        }
        bool isDirectory = VSI_ISDIR(statBuffer.st_mode) || relativePath[relativePath.size() - 1] == '/';
        std::string destinationPath = destinationRoot + "/" + relativePath;
        if (isDirectory) {
            if (!EnsureDirectoryExists(destinationPath)) {
                failed = true;
                failureMessage = "Failed to create directory from ZIP archive";
                break;
            }
            continue;
        }

        if (extractedFiles >= maxExtractedFiles ||
            extractedBytes + static_cast<long long>(statBuffer.st_size) > maxExtractedBytes) {
            failed = true;
            failureMessage = "ZIP archive is too large to import";
            break;
        }

        std::string parent = ParentDirectory(destinationPath);
        if (!EnsureDirectoryExists(parent)) {
            failed = true;
            failureMessage = "Failed to create directory for ZIP member";
            break;
        }
        if (!CopyVsiFile(sourcePath, destinationPath, &extractedBytes)) {
            failed = true;
            failureMessage = "Failed to extract file from ZIP archive";
            break;
        }
        extractedFiles++;
    }
    CSLDestroy(entries);

    if (failed) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_WRITE_FAILED,
            failureMessage, destinationRoot, "", extractedFiles));
    }
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(BuildProcessResultJson(true, GIS_OK,
        "ZIP archive extracted", destinationRoot, "", extractedFiles));
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

const char *ExtractZipArchive(const char *zipPath, const char *outputDirectory, int32_t *outErrCode)
{
    return ExtractZipArchiveImpl(zipPath, outputDirectory, outErrCode);
}

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

    GDALDataset *rawDataset = TryOpenVectorDataset(filePath);
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
    GdalLayerState *state = it->second.get();
    if (state && state->dataset && state->editSessionActive) {
        state->dataset->RollbackTransaction();
        state->editSessionActive = false;
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

const char *ListVectorSublayers(const char *filePath, int32_t *outErrCode)
{
    if (!filePath || std::strlen(filePath) == 0) {
        if (outErrCode) *outErrCode = GIS_ERR_INVALID_PARAM;
        return DuplicateCString("{\"ok\":false,\"layers\":[]}");
    }
    std::lock_guard<std::mutex> lock(g_mutex);
    EnsureGdal();
    GDALDataset *dataset = TryOpenVectorDataset(filePath);
    if (!dataset) {
        if (outErrCode) *outErrCode = GIS_ERR_INVALID_FORMAT;
        return DuplicateCString("{\"ok\":false,\"layers\":[]}");
    }
    std::string json = "{\"ok\":true,\"layers\":[";
    for (int i = 0; i < dataset->GetLayerCount(); i++) {
        OGRLayer *layer = dataset->GetLayer(i);
        if (i > 0) json += ",";
        std::string name = layer && layer->GetName() ? layer->GetName() : "";
        json += "{\"name\":\"" + EscapeJson(name) + "\",\"uri\":\"" +
            EscapeJson(std::string(filePath) + "|layername=" + name) + "\"}";
    }
    json += "]}";
    GDALClose(dataset);
    if (outErrCode) *outErrCode = GIS_OK;
    return DuplicateCString(json);
}

const char *QueryFeatures(LayerHandle handle, double minX, double minY, double maxX, double maxY,
                          int32_t limit, int32_t offset, int32_t *outErrCode)
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
    int32_t skipped = 0;
    bool hasMore = false;
    while (OGRFeature *feature = layer->GetNextFeature()) {
        if (skipped < offset) {
            skipped++;
            OGRFeature::DestroyFeature(feature);
            continue;
        }
        if (limit > 0 && count >= limit) {
            hasMore = true;
            OGRFeature::DestroyFeature(feature);
            break;
        }
        if (!first) {
            json += ",";
        }
        first = false;
        json += BuildFeatureJson(feature);
        OGRFeature::DestroyFeature(feature);
        count++;
    }
    if (useSpatialFilter) {
        layer->SetSpatialFilter(nullptr);
    }

    json += hasMore ? "],\"hasMore\":true}" : "],\"hasMore\":false}";
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

static const char *MakeEditSessionResult(bool ok, int32_t code, const std::string &message,
                                         OGRLayer *layer, int32_t *outErrCode)
{
    if (outErrCode) {
        *outErrCode = ok ? GIS_OK : code;
    }
    int32_t featureCount = layer ? static_cast<int32_t>(layer->GetFeatureCount()) : 0;
    return DuplicateCString(BuildProcessResultJson(ok, code, message, "", "", featureCount));
}

const char *BeginEditSession(LayerHandle handle, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    GdalLayerState *state = FindLayer(handle);
    OGRLayer *layer = LayerFromState(state);
    if (!state || !state->dataset || !layer) {
        return MakeEditSessionResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", layer, outErrCode);
    }
    if (state->editSessionActive) {
        return MakeEditSessionResult(true, GIS_OK, "Edit session is already active", layer, outErrCode);
    }
    if (state->dataset->StartTransaction(FALSE) != OGRERR_NONE) {
        return MakeEditSessionResult(false, GIS_ERR_WRITE_FAILED, "GDAL dataset transaction is not available",
            layer, outErrCode);
    }
    state->editSessionActive = true;
    return MakeEditSessionResult(true, GIS_OK, "Edit session started", layer, outErrCode);
}

const char *CommitEditSession(LayerHandle handle, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    GdalLayerState *state = FindLayer(handle);
    OGRLayer *layer = LayerFromState(state);
    if (!state || !state->dataset || !layer) {
        return MakeEditSessionResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", layer, outErrCode);
    }
    if (!state->editSessionActive) {
        return MakeEditSessionResult(false, GIS_ERR_INVALID_PARAM, "No active edit session", layer, outErrCode);
    }
    if (state->dataset->CommitTransaction() != OGRERR_NONE) {
        return MakeEditSessionResult(false, GIS_ERR_WRITE_FAILED, "GDAL transaction commit failed", layer,
            outErrCode);
    }
    state->editSessionActive = false;
    return MakeEditSessionResult(true, GIS_OK, "Edit session committed", layer, outErrCode);
}

const char *RollbackEditSession(LayerHandle handle, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    GdalLayerState *state = FindLayer(handle);
    OGRLayer *layer = LayerFromState(state);
    if (!state || !state->dataset || !layer) {
        return MakeEditSessionResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", layer, outErrCode);
    }
    if (!state->editSessionActive) {
        return MakeEditSessionResult(false, GIS_ERR_INVALID_PARAM, "No active edit session", layer, outErrCode);
    }
    if (state->dataset->RollbackTransaction() != OGRERR_NONE) {
        return MakeEditSessionResult(false, GIS_ERR_WRITE_FAILED, "GDAL transaction rollback failed", layer,
            outErrCode);
    }
    state->editSessionActive = false;
    return MakeEditSessionResult(true, GIS_OK, "Edit session rolled back", layer, outErrCode);
}

const char *UndoEdit(LayerHandle handle, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    GdalLayerState *state = FindLayer(handle);
    OGRLayer *layer = LayerFromState(state);
    if (!layer) {
        return MakeEditSessionResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", layer, outErrCode);
    }
    return MakeEditSessionResult(false, GIS_ERR_NATIVE_NOT_READY,
        "Undo is only available with the QGIS edit backend", layer, outErrCode);
}

const char *RedoEdit(LayerHandle handle, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    GdalLayerState *state = FindLayer(handle);
    OGRLayer *layer = LayerFromState(state);
    if (!layer) {
        return MakeEditSessionResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", layer, outErrCode);
    }
    return MakeEditSessionResult(false, GIS_ERR_NATIVE_NOT_READY,
        "Redo is only available with the QGIS edit backend", layer, outErrCode);
}

bool IsEditing(LayerHandle handle)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    GdalLayerState *state = FindLayer(handle);
    return state && state->editSessionActive;
}

bool HasPendingEdits(LayerHandle handle)
{
    (void)handle;
    return false;
}

bool CanUndo(LayerHandle handle)
{
    (void)handle;
    return false;
}

bool CanRedo(LayerHandle handle)
{
    (void)handle;
    return false;
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

static OGRLayer *CreateOutputLayerWithDriver(const char *outputPath, const char *outputLayerName,
                                             OGRLayer *sourceLayer, OGRwkbGeometryType geometryType,
                                             const char *driverName, GDALDataset **outDataset)
{
    if (!outputPath || std::strlen(outputPath) == 0 || !sourceLayer || !outDataset) {
        return nullptr;
    }
    const char *drv = (driverName && std::strlen(driverName) > 0) ? driverName : "ESRI Shapefile";
    GDALDriver *driver = GetGDALDriverManager()->GetDriverByName(drv);
    if (!driver) {
        return nullptr;
    }
    std::string drvStr(drv);

    char **papszDsoOptions = nullptr;
    if (drvStr == "ESRI Shapefile") {
        papszDsoOptions = CSLSetNameValue(papszDsoOptions, "FORMAT", "SHP");
    } else if (drvStr == "CSV") {
        papszDsoOptions = CSLSetNameValue(papszDsoOptions, "GEOMETRY", "AS_WKT");
        papszDsoOptions = CSLSetNameValue(papszDsoOptions, "WRITE_BOM", "YES");
    }

    if (FileExists(outputPath)) {
        driver->Delete(outputPath);
    }

    GDALDataset *dataset = driver->Create(outputPath, 0, 0, 0, GDT_Unknown, papszDsoOptions);
    CSLDestroy(papszDsoOptions);
    if (!dataset) {
        return nullptr;
    }

    OGRSpatialReference *srs = sourceLayer->GetSpatialRef();
    std::string layerName = outputLayerName && std::strlen(outputLayerName) > 0 ? outputLayerName : "geonest_output";

    char **papszLyrOptions = nullptr;
    if (drvStr == "KML") {
        papszLyrOptions = CSLSetNameValue(papszLyrOptions, "NameField", "Name");
    }

    OGRLayer *outputLayer = dataset->CreateLayer(layerName.c_str(), srs, geometryType, papszLyrOptions);
    CSLDestroy(papszLyrOptions);

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

const char *ExportLayerToFormat(LayerHandle handle, const char *outputPath,
                                const char *outputLayerName, const char *driverName,
                                int32_t *outErrCode)
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
    OGRLayer *outputLayer = CreateOutputLayerWithDriver(outputPath, outputLayerName, sourceLayer,
        OutputGeometryType(sourceLayer, false), driverName, &rawOutputDataset);
    std::unique_ptr<GDALDataset, DatasetDeleter> outputDataset(rawOutputDataset);
    if (!outputLayer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        std::string drv = (driverName && std::strlen(driverName) > 0) ? driverName : "ESRI Shapefile";
        GDALDriver *checkDriver = GetGDALDriverManager()->GetDriverByName(drv.c_str());
        std::string errMsg = "Failed to create output with driver " + drv;
        if (!checkDriver) {
            errMsg += " (driver not available in this GDAL build)";
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_WRITE_FAILED,
            errMsg, outputPath, outputLayerName ? outputLayerName : "", 0));
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

LayerHandle OpenRasterLayer(const char *filePath, char **outLayerInfo, int32_t *outErrCode)
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

    GDALDataset *rawDataset = TryOpenRasterDataset(filePath);
    if (!rawDataset) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_FORMAT;
        }
        return 0;
    }

    int bandCount = rawDataset->GetRasterCount();
    if (bandCount <= 0) {
        GDALClose(rawDataset);
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

    int xSize = rawDataset->GetRasterXSize();
    int ySize = rawDataset->GetRasterYSize();
    double transform[6] = {0};
    rawDataset->GetGeoTransform(transform);

    GDALRasterBand *firstBand = rawDataset->GetRasterBand(1);
    GDALDataType dataType = firstBand ? firstBand->GetRasterDataType() : GDT_Unknown;
    const char *dataTypeName = GDALGetDataTypeName(dataType);

    OGRSpatialReference *srs = nullptr;
    const char *crsWkt = rawDataset->GetProjectionRef();
    if (crsWkt && std::strlen(crsWkt) > 0) {
        srs = new OGRSpatialReference();
        srs->SetFromUserInput(crsWkt);
    }

    double minX = transform[0];
    double maxY = transform[3];
    double maxX = minX + xSize * transform[1] + ySize * transform[2];
    double minY = maxY + xSize * transform[4] + ySize * transform[5];
    if (minX > maxX) { double tmp = minX; minX = maxX; maxX = tmp; }
    if (minY > maxY) { double tmp = minY; minY = maxY; maxY = tmp; }

    std::string json = "{\"layerId\":\"L";
    json += std::to_string(handle);
    json += "\",\"name\":\"";
    json += EscapeJson(rawDataset->GetDescription());
    json += "\",\"geometryType\":0";
    json += ",\"featureCount\":";
    json += std::to_string(bandCount);
    json += ",\"rasterWidth\":";
    json += std::to_string(xSize);
    json += ",\"rasterHeight\":";
    json += std::to_string(ySize);
    json += ",\"rasterBandCount\":";
    json += std::to_string(bandCount);
    json += ",\"rasterDataType\":\"";
    json += EscapeJson(dataTypeName ? dataTypeName : "Unknown");
    json += "\",\"envelope\":";
    OGREnvelope env;
    env.MinX = minX;
    env.MinY = minY;
    env.MaxX = maxX;
    env.MaxY = maxY;
    AppendEnvelope(json, env);
    json += ",\"crs\":\"";
    json += EscapeJson(SpatialRefId(srs));
    json += "\",\"coordinateUnitName\":\"";
    json += EscapeJson(SpatialUnitName(srs));
    json += "\",\"coordinateUnitType\":";
    json += std::to_string(SpatialUnitType(srs));
    json += ",\"fields\":[]}";
    delete srs;

    g_layers[handle] = std::move(state);

    if (outLayerInfo) {
        *outLayerInfo = DuplicateCString(json);
    }
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return handle;
}

const char *ExportRasterToFormat(LayerHandle handle, const char *outputPath,
                                 const char *outputName, const char *driverName,
                                 int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_PARAM,
            "Invalid export parameters", "", outputName ? outputName : "", 0));
    }
    EnsureGdal();
    GdalLayerState *state = FindLayer(handle);
    if (!state || !state->dataset) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_LAYER_NOT_FOUND,
            "Input layer not found", outputPath, outputName ? outputName : "", 0));
    }

    GDALDataset *srcDataset = state->dataset.get();
    int bandCount = srcDataset->GetRasterCount();
    if (bandCount <= 0) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_FORMAT;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_INVALID_FORMAT,
            "No raster bands", outputPath, outputName ? outputName : "", 0));
    }

    const char *drv = (driverName && std::strlen(driverName) > 0) ? driverName : "GTiff";
    GDALDriver *driver = GetGDALDriverManager()->GetDriverByName(drv);
    if (!driver) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_WRITE_FAILED,
            std::string("Unknown driver: ") + drv, outputPath, outputName ? outputName : "", 0));
    }

    if (FileExists(outputPath)) {
        driver->Delete(outputPath);
    }

    int xSize = srcDataset->GetRasterXSize();
    int ySize = srcDataset->GetRasterYSize();

    GDALDataType outType = srcDataset->GetRasterBand(1)->GetRasterDataType();
    char **papszOptions = nullptr;
    std::string drvStr(drv);
    if (drvStr == "GTiff") {
        papszOptions = CSLSetNameValue(papszOptions, "COMPRESS", "LZW");
    }

    GDALDataset *outDataset = driver->Create(outputPath, xSize, ySize, bandCount, outType, papszOptions);
    CSLDestroy(papszOptions);
    if (!outDataset) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_WRITE_FAILED,
            "Failed to create output raster", outputPath, outputName ? outputName : "", 0));
    }

    double transform[6] = {0};
    srcDataset->GetGeoTransform(transform);
    outDataset->SetGeoTransform(transform);
    const char *proj = srcDataset->GetProjectionRef();
    if (proj && std::strlen(proj) > 0) {
        outDataset->SetProjection(proj);
    }

    int copyErr = 0;
    int blockSize = 256;
    for (int i = 1; i <= bandCount; i++) {
        GDALRasterBand *srcBand = srcDataset->GetRasterBand(i);
        GDALRasterBand *dstBand = outDataset->GetRasterBand(i);
        if (!srcBand || !dstBand) {
            copyErr = 1;
            break;
        }
        GDALDataType bufType = srcBand->GetRasterDataType();
        for (int y = 0; y < ySize; y += blockSize) {
            int rows = (y + blockSize > ySize) ? (ySize - y) : blockSize;
            for (int x = 0; x < xSize; x += blockSize) {
                int cols = (x + blockSize > xSize) ? (xSize - x) : blockSize;
                void *buffer = CPLMalloc(cols * rows * GDALGetDataTypeSizeBytes(bufType));
                if (srcBand->RasterIO(GF_Read, x, y, cols, rows, buffer, cols, rows, bufType, 0, 0) != CE_None ||
                    dstBand->RasterIO(GF_Write, x, y, cols, rows, buffer, cols, rows, bufType, 0, 0) != CE_None) {
                    CPLFree(buffer);
                    copyErr = 1;
                    break;
                }
                CPLFree(buffer);
            }
            if (copyErr) break;
        }
        if (copyErr) break;
        double nodata = srcBand->GetNoDataValue();
        int hasNodata = 0;
        srcBand->GetNoDataValue(&hasNodata);
        if (hasNodata) {
            dstBand->SetNoDataValue(nodata);
        }
    }

    GDALClose(outDataset);

    if (copyErr) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_WRITE_FAILED,
            "Raster copy failed", outputPath, outputName ? outputName : "", 0));
    }

    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(BuildProcessResultJson(true, GIS_OK, "Raster export completed",
        outputPath, outputName ? outputName : "", bandCount));
}

const char *GetProcessingAlgorithms()
{
    return DuplicateCString("{\"backend\":\"gdal\",\"algorithms\":[]}");
}

const char *ExecuteProcessingAlgorithm(const char *requestJson, int32_t *outErrCode)
{
    (void)requestJson;
    if (outErrCode) {
        *outErrCode = GIS_ERR_NATIVE_NOT_READY;
    }
    return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_NATIVE_NOT_READY,
        "Background Processing requires the QGIS backend", "", "", 0));
}

PreparedProcessingTask *PrepareProcessingTask(const char *requestJson, char **outErrorMessage,
                                               int32_t *outErrCode)
{
    (void)requestJson;
    if (outErrorMessage) {
        *outErrorMessage = DuplicateCString("Background Processing requires the QGIS backend");
    }
    if (outErrCode) {
        *outErrCode = GIS_ERR_NATIVE_NOT_READY;
    }
    return nullptr;
}

const char *RunPreparedProcessingTask(PreparedProcessingTask *task,
                                      const ProcessingCallbacks *callbacks,
                                      int32_t *outErrCode)
{
    (void)task;
    (void)callbacks;
    return ExecuteProcessingAlgorithm(nullptr, outErrCode);
}

void FreePreparedProcessingTask(PreparedProcessingTask *task)
{
    delete task;
}

const char *ReadQgisProject(const char *projectPath, int32_t *outErrCode)
{
    if (outErrCode) {
        *outErrCode = GIS_ERR_NATIVE_NOT_READY;
    }
    return DuplicateCString(BuildProcessResultJson(false, GIS_ERR_NATIVE_NOT_READY,
        "QGIS project support requires the QGIS backend", projectPath ? projectPath : "", "", 0));
}

const char *WriteQgisProject(const char *projectPath, const char *projectName,
                             const char *projectCrs, const char *layerHandles,
                             int32_t *outErrCode)
{
    (void)projectName;
    (void)projectCrs;
    (void)layerHandles;
    return ReadQgisProject(projectPath, outErrCode);
}

void FreeCString(char *str)
{
    if (str) {
        free(str);
    }
}

} // namespace geonest
