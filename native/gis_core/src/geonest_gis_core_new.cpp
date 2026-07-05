#include "geonest_gis_core.h"

#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <cmath>
#include <map>
#include <vector>
#include <string>
#include <mutex>
#include <fstream>

namespace geonest {

// ---------------------------------------------------------------------------
// Internal layer store
// ---------------------------------------------------------------------------

struct MockPoint {
    double x;
    double y;
};

struct MockRing {
    std::vector<MockPoint> points;
};

struct MockGeometry {
    int32_t type;
    std::vector<MockRing> rings;
    std::vector<MockPoint> points;
};

struct MockField {
    std::string name;
    std::string typeName;
    std::string value;
};

struct MockFeature {
    int64_t fid;
    MockGeometry geom;
    std::vector<MockField> fields;
};

struct MockLayer {
    LayerHandle handle;
    std::string filePath;
    std::string name;
    int32_t geomType;
    std::string crs;
    double minX;
    double minY;
    double maxX;
    double maxY;
    std::vector<std::string> fieldNames;
    std::vector<std::string> fieldTypes;
    std::vector<MockFeature> features;
};

static std::mutex g_mutex;
static std::map<LayerHandle, MockLayer> g_layers;
static LayerHandle g_nextHandle = 1;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static char *DuplicateCString(const std::string &s)
{
    char *buf = static_cast<char *>(malloc(s.size() + 1));
    if (buf) memcpy(buf, s.c_str(), s.size() + 1);
    return buf;
}

static std::string EscapeJson(const std::string &s)
{
    std::string out;
    for (size_t i = 0; i < s.size(); i++) {
        char c = s[i];
        if (c == '"') out += "\\"";
        else if (c == '\\') out += "\\\\";
        else if (c == '\n') out += "\\n";
        else if (c == '\r') out += "\\r";
        else if (c == '\t') out += "\\t";
        else out += c;
    }
    return out;
}

static int32_t ReadInt32LE(const unsigned char *p) {
    return static_cast<int32_t>(p[0] | (p[1]<<8) | (p[2]<<16) | (p[3]<<24));
}

static int32_t ReadInt32BE(const unsigned char *p) {
    return static_cast<int32_t>((p[0]<<24) | (p[1]<<16) | (p[2]<<8) | p[3]);
}

static double ReadFloat64LE(const unsigned char *p) {
    double val;
    memcpy(&val, p, 8);
    return val;
}

static int16_t ReadInt16LE(const unsigned char *p) {
    return static_cast<int16_t>(p[0] | (p[1]<<8));
}

// ---------------------------------------------------------------------------
// Real SHP file reader
// ---------------------------------------------------------------------------

static bool ReadShapefile(const std::string &shpPath, MockLayer &layer)
{
    // Build companion file paths
    std::string basePath = shpPath;
    // Remove .shp extension if present
    if (basePath.size() > 4 && basePath.substr(basePath.size() - 4) == ".shp") {
        basePath = basePath.substr(0, basePath.size() - 4);
    }

    // Read .shp file
    std::string shpFile = basePath + ".shp";
    std::ifstream shpIn(shpFile, std::ios::binary | std::ios::ate);
    if (!shpIn.is_open()) return false;

    std::streamsize shpSize = shpIn.tellg();
    shpIn.seekg(0, std::ios::beg);
    std::vector<unsigned char> shpData(shpSize);
    if (!shpIn.read(reinterpret_cast<char *>(shpData.data()), shpSize)) return false;
    shpIn.close();

    if (shpSize < 100) return false;
    const unsigned char *hdr = shpData.data();

    // Validate header
    int32_t fileCode = ReadInt32BE(hdr);
    if (fileCode != 9994) return false;

    int32_t version = ReadInt32LE(hdr + 32);
    if (version != 1000) return false;

    int32_t shapeType = ReadInt32LE(hdr + 36);
    layer.geomType = shapeType; // 1=Point, 3=PolyLine, 5=Polygon

    layer.minX = ReadFloat64LE(hdr + 36 + 4); // skip shapeType(4), then bbox starts
    layer.minY = ReadFloat64LE(hdr + 36 + 4 + 8);
    layer.maxX = ReadFloat64LE(hdr + 36 + 4 + 16);
    layer.maxY = ReadFloat64LE(hdr + 36 + 4 + 24);

    // Wait - the Shapefile header bbox is at bytes 36-67 (after shapeType at 36)
    // shapeType is at 36-39, then bbox starts at 40
    layer.minX = ReadFloat64LE(hdr + 40);
    layer.minY = ReadFloat64LE(hdr + 48);
    layer.maxX = ReadFloat64LE(hdr + 56);
    layer.maxY = ReadFloat64LE(hdr + 64);

    // Parse records
    int32_t off = 100;
    int64_t fid = 1;
    while (off + 8 <= static_cast<int32_t>(shpSize)) {
        int32_t recNum = ReadInt32BE(shpData.data() + off);
        int32_t contentLen = ReadInt32BE(shpData.data() + off + 4) * 2;
        if (contentLen <= 0 || off + 8 + contentLen > static_cast<int32_t>(shpSize)) break;

        const unsigned char *rec = shpData.data() + off + 8;
        int32_t recType = ReadInt32LE(rec);

        MockFeature feat;
        feat.fid = fid++;

        if (recType == 1 && shapeType == 1) {
            // Point
            feat.geom.type = GEOM_POINT;
            double x = ReadFloat64LE(rec + 4);
            double y = ReadFloat64LE(rec + 12);
            feat.geom.points.push_back({x, y});
        } else if ((recType == 3 || recType == 5) && (shapeType == 3 || shapeType == 5)) {
            // PolyLine or Polygon
            feat.geom.type = (shapeType == 5) ? GEOM_POLYGON : GEOM_LINESTRING;

            int32_t numParts = ReadInt32LE(rec + 36);
            int32_t numPoints = ReadInt32LE(rec + 40);
            const unsigned char *partsArr = rec + 44;
            const unsigned char *pointsArr = partsArr + numParts * 4;

            for (int32_t pi = 0; pi < numParts; pi++) {
                int32_t startIdx = ReadInt32LE(partsArr + pi * 4);
                int32_t endIdx = (pi + 1 < numParts) ? ReadInt32LE(partsArr + (pi + 1) * 4) : numPoints;

                MockRing ring;
                for (int32_t j = startIdx; j < endIdx; j++) {
                    double px = ReadFloat64LE(pointsArr + j * 16);
                    double py = ReadFloat64LE(pointsArr + j * 16 + 8);
                    ring.points.push_back({px, py});
                }
                feat.geom.rings.push_back(ring);

                if (shapeType != 5) {
                    // For polylines, also store points flat
                    for (const auto &pt : ring.points) {
                        feat.geom.points.push_back(pt);
                    }
                }
            }
        } else {
            off += 8 + contentLen;
            continue; // skip unknown/unsupported shape types
        }

        layer.features.push_back(feat);
        off += 8 + contentLen;
    }

    // Read .dbf file for field data
    std::string dbfFile = basePath + ".dbf";
    std::ifstream dbfIn(dbfFile, std::ios::binary | std::ios::ate);
    if (dbfIn.is_open()) {
        std::streamsize dbfSize = dbfIn.tellg();
        dbfIn.seekg(0, std::ios::beg);
        std::vector<unsigned char> dbfData(dbfSize);
        dbfIn.read(reinterpret_cast<char *>(dbfData.data()), dbfSize);
        dbfIn.close();

        if (dbfSize >= 32) {
            int32_t nRecords = ReadInt32LE(dbfData.data() + 4);
            int16_t headerLen = ReadInt16LE(dbfData.data() + 8);
            int16_t recordLen = ReadInt16LE(dbfData.data() + 10);

            // Parse field definitions
            struct DField { std::string name; char type; int size; };
            std::vector<DField> fields;
            int fOff = 32;
            while (fOff < headerLen - 1 && fOff + 32 <= static_cast<int32_t>(dbfSize)) {
                DField df;
                for (int i = 0; i < 11; i++) {
                    char c = static_cast<char>(dbfData[fOff + i]);
                    if (c == 0) break;
                    df.name += c;
                }
                df.type = static_cast<char>(dbfData[fOff + 11]);
                df.size = dbfData[fOff + 16];
                fields.push_back(df);
                fOff += 32;
            }

            // Set field metadata
            for (size_t fi = 0; fi < fields.size(); fi++) {
                layer.fieldNames.push_back(fields[fi].name);
                if (fields[fi].type == 'N' || fields[fi].type == 'F') {
                    layer.fieldTypes.push_back("double");
                } else {
                    layer.fieldTypes.push_back("string");
                }
            }

            // Read attribute values for each record
            for (int32_t ri = 0; ri < nRecords && ri < static_cast<int32_t>(layer.features.size()); ri++) {
                int32_t recStart = headerLen + ri * recordLen;
                if (recStart + recordLen > static_cast<int32_t>(dbfSize)) break;

                int vOff = recStart + 1; // skip delete flag
                for (size_t fi = 0; fi < fields.size(); fi++) {
                    MockField mf;
                    mf.name = fields[fi].name;
                    mf.typeName = layer.fieldTypes[fi];
                    // Read raw bytes as value
                    std::string rawVal;
                    for (int j = 0; j < fields[fi].size && vOff + j < static_cast<int32_t>(dbfSize); j++) {
                        unsigned char c = dbfData[vOff + j];
                        if (c == 0) break;
                        rawVal += static_cast<char>(c);
                    }
                    // Trim spaces
                    size_t start = rawVal.find_first_not_of(' ');
                    size_t end = rawVal.find_last_not_of(' ');
                    if (start != std::string::npos) {
                        mf.value = rawVal.substr(start, end - start + 1);
                    } else {
                        mf.value = "";
                    }
                    layer.features[ri].fields.push_back(mf);
                    vOff += fields[fi].size;
                }
            }
        }
    }

    // Extract layer name from file path
    std::string fname = basePath;
    size_t lastSlash = fname.find_last_of("/\\");
    if (lastSlash != std::string::npos) fname = fname.substr(lastSlash + 1);
    layer.name = fname;
    layer.crs = "EPSG:4326";

    return true;
}
