#include "geonest_gis_core.h"

#include <qgis.h>
#include <qgsapplication.h>
#include <qgsfeature.h>
#include <qgsfeatureiterator.h>
#include <qgsfeaturerequest.h>
#include <qgsfield.h>
#include <qgsfields.h>
#include <qgsgeometry.h>
#include <qgsfillsymbol.h>
#include <qgsgraduatedsymbolrenderer.h>
#include <qgscategorizedsymbolrenderer.h>
#include <qgshillshaderenderer.h>
#include <qgsmaplayer.h>
#include <qgsmaprenderersequentialjob.h>
#include <qgsmapsettings.h>
#include <qgsmarkersymbol.h>
#include <qgsmultibandcolorrenderer.h>
#include <qgspallabeling.h>
#include <qgspointxy.h>
#include <qgsrectangle.h>
#include <qgsrendererrange.h>
#include <qgsrasterdataprovider.h>
#include <qgsrasterlayer.h>
#include <qgsrasterrange.h>
#include <qgsrasterrenderer.h>
#include <qgssinglesymbolrenderer.h>
#include <qgssinglebandgrayrenderer.h>
#include <qgssymbol.h>
#include <qgstextbuffersettings.h>
#include <qgstextformat.h>
#include <qgsvectorlayer.h>
#include <qgsvectorlayerlabeling.h>
#include <qgsvectorfilewriter.h>
#include <qgslinesymbol.h>
#include <qgscoordinatereferencesystem.h>
#include <qgscoordinatetransform.h>
#include <qgscontrastenhancement.h>
#include <qgsexception.h>
#include <qgsexpression.h>
#include <qgsexpressioncontext.h>
#include <qgslegendsymbolitem.h>
#include <qgsproject.h>
#include <qgsrenderer.h>
#include <qgswkbtypes.h>

#include <QByteArray>
#include <QBrush>
#include <QColor>
#include <QDir>
#include <QFileInfo>
#include <QFont>
#include <QFontDatabase>
#include <QImage>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QList>
#include <QPainter>
#include <QPainterPath>
#include <QPageSize>
#include <QPdfWriter>
#include <QPen>
#include <QPoint>
#include <QPolygon>
#include <QRect>
#include <QString>
#include <QStringList>
#include <QSize>
#include <QSvgGenerator>
#include <QVariant>
#include <QVariantMap>
#include <QVector>

#if !defined(_WIN32)
#include <dlfcn.h>
#endif

#include <cstdlib>
#include <cstring>
#include <cmath>
#include <algorithm>
#include <map>
#include <memory>
#include <mutex>
#include <set>
#include <string>
#include <vector>

namespace geonest {
namespace {

struct QgisLayerState {
    LayerHandle handle = 0;
    std::string filePath;
    std::unique_ptr<QgsVectorLayer> layer;
};

struct QgisRasterState {
    LayerHandle handle = 0;
    std::string filePath;
    std::unique_ptr<QgsRasterLayer> layer;
};

static std::mutex g_mutex;
static std::map<LayerHandle, std::unique_ptr<QgisLayerState>> g_layers;
static std::map<LayerHandle, std::unique_ptr<QgisRasterState>> g_rasterLayers;
static std::vector<LayerHandle> g_layerOrder;
static LayerHandle g_nextHandle = 1;
static std::unique_ptr<QgsApplication> g_qgisApp;
static bool g_qgisReady = false;
static int g_qgisArgc = 3;
static char g_qgisArg0[] = "geonestgis";
static char g_qgisArg1[] = "-platform";
static char g_qgisArg2[] = "offscreen";
static char *g_qgisArgv[] = { g_qgisArg0, g_qgisArg1, g_qgisArg2, nullptr };

static QString ResolveSharedLibraryDir()
{
#if !defined(_WIN32)
    Dl_info info;
    if (dladdr(reinterpret_cast<void *>(&ResolveSharedLibraryDir), &info) != 0 && info.dli_fname) {
        QFileInfo libraryFile(QString::fromLocal8Bit(info.dli_fname));
        return libraryFile.absolutePath();
    }
#endif
    return QString();
}

static QString ResolveQgisPrefixPath()
{
    QString libraryDir = ResolveSharedLibraryDir();
    if (!libraryDir.isEmpty()) {
        QString packedPrefix = QDir(libraryDir).filePath("qgis");
        if (QFileInfo::exists(packedPrefix)) {
            return packedPrefix;
        }
    }

#ifdef GEONEST_QGIS_PREFIX
    return QString::fromUtf8(GEONEST_QGIS_PREFIX);
#else
    return QString();
#endif
}

static QString ResolveQgisPluginPath()
{
    QString libraryDir = ResolveSharedLibraryDir();
    if (!libraryDir.isEmpty()) {
        QString packedPluginDir = QDir(libraryDir).filePath("qgis/plugins");
        if (QFileInfo::exists(packedPluginDir)) {
            return packedPluginDir;
        }
        if (QFileInfo::exists(libraryDir)) {
            return libraryDir;
        }
    }

#ifdef GEONEST_QGIS_PLUGIN_PATH
    return QString::fromUtf8(GEONEST_QGIS_PLUGIN_PATH);
#else
    return QString();
#endif
}

static bool EnsureQgis()
{
    if (g_qgisReady) {
        return true;
    }

    QString libraryDir = ResolveSharedLibraryDir();
    if (!libraryDir.isEmpty()) {
        QString platformPluginPath = QDir(libraryDir).filePath("platforms");
        if (QFileInfo::exists(platformPluginPath)) {
            qputenv("QT_QPA_PLATFORM_PLUGIN_PATH", platformPluginPath.toUtf8());
        }
    }
    qputenv("QT_QPA_PLATFORM", QByteArray("offscreen"));
    qputenv("QT_QPA_FONTDIR", QByteArray("/system/fonts"));

    QString prefixPath = ResolveQgisPrefixPath();
    if (!prefixPath.isEmpty()) {
        QgsApplication::setPrefixPath(prefixPath, true);
    }
    QString pluginPath = ResolveQgisPluginPath();
    if (!pluginPath.isEmpty()) {
        QgsApplication::setPluginPath(pluginPath);
    }
    g_qgisApp.reset(new QgsApplication(g_qgisArgc, g_qgisArgv, false));
    QgsApplication::initQgis();
    g_qgisReady = true;
    return true;
}

static char *DuplicateCString(const std::string &value)
{
    char *buf = static_cast<char *>(malloc(value.size() + 1));
    if (buf) {
        memcpy(buf, value.c_str(), value.size() + 1);
    }
    return buf;
}

static std::string ToStdString(const QString &value)
{
    QByteArray bytes = value.toUtf8();
    return std::string(bytes.constData(), static_cast<size_t>(bytes.size()));
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

static int32_t MapGeometryType(Qgis::GeometryType geometryType)
{
    if (geometryType == Qgis::GeometryType::Point) {
        return GEOM_POINT;
    }
    if (geometryType == Qgis::GeometryType::Line) {
        return GEOM_LINESTRING;
    }
    if (geometryType == Qgis::GeometryType::Polygon) {
        return GEOM_POLYGON;
    }
    return GEOM_UNKNOWN;
}

static void AppendPoint(std::string &json, const QgsPointXY &point)
{
    json += "{\"x\":";
    json += std::to_string(point.x());
    json += ",\"y\":";
    json += std::to_string(point.y());
    json += ",\"z\":0,\"hasZ\":false}";
}

template<typename PointsT>
static void AppendPointPart(std::string &json, const PointsT &points, bool &firstPart)
{
    if (!firstPart) {
        json += ",";
    }
    firstPart = false;
    json += "{\"points\":[";
    for (int i = 0; i < points.size(); i++) {
        if (i > 0) {
            json += ",";
        }
        AppendPoint(json, points.at(i));
    }
    json += "]}";
}

static void AppendGeometryParts(std::string &json, const QgsGeometry &geometry, int32_t geometryType)
{
    bool firstPart = true;
    if (geometry.isNull()) {
        return;
    }

    if (geometryType == GEOM_POINT) {
        if (geometry.isMultipart()) {
            QgsMultiPointXY points = geometry.asMultiPoint();
            AppendPointPart(json, points, firstPart);
        } else {
            QVector<QgsPointXY> points;
            points.push_back(geometry.asPoint());
            AppendPointPart(json, points, firstPart);
        }
    } else if (geometryType == GEOM_LINESTRING) {
        if (geometry.isMultipart()) {
            QgsMultiPolylineXY lines = geometry.asMultiPolyline();
            for (int i = 0; i < lines.size(); i++) {
                AppendPointPart(json, lines.at(i), firstPart);
            }
        } else {
            QgsPolylineXY line = geometry.asPolyline();
            AppendPointPart(json, line, firstPart);
        }
    } else if (geometryType == GEOM_POLYGON) {
        if (geometry.isMultipart()) {
            QgsMultiPolygonXY polygons = geometry.asMultiPolygon();
            for (int pi = 0; pi < polygons.size(); pi++) {
                QgsPolygonXY polygon = polygons.at(pi);
                for (int ri = 0; ri < polygon.size(); ri++) {
                    AppendPointPart(json, polygon.at(ri), firstPart);
                }
            }
        } else {
            QgsPolygonXY polygon = geometry.asPolygon();
            for (int ri = 0; ri < polygon.size(); ri++) {
                AppendPointPart(json, polygon.at(ri), firstPart);
            }
        }
    }
}

static void AppendEnvelope(std::string &json, const QgsRectangle &rect)
{
    json += "{\"minX\":";
    json += std::to_string(rect.xMinimum());
    json += ",\"minY\":";
    json += std::to_string(rect.yMinimum());
    json += ",\"maxX\":";
    json += std::to_string(rect.xMaximum());
    json += ",\"maxY\":";
    json += std::to_string(rect.yMaximum());
    json += "}";
}

static QString DistanceUnitName(Qgis::DistanceUnit unit)
{
    if (unit == Qgis::DistanceUnit::Meters) {
        return QStringLiteral("meters");
    }
    if (unit == Qgis::DistanceUnit::Kilometers) {
        return QStringLiteral("kilometers");
    }
    if (unit == Qgis::DistanceUnit::Feet || unit == Qgis::DistanceUnit::FeetUSSurvey ||
        unit == Qgis::DistanceUnit::FeetBritish1865 || unit == Qgis::DistanceUnit::FeetBritish1936 ||
        unit == Qgis::DistanceUnit::FeetBritishBenoit1895A ||
        unit == Qgis::DistanceUnit::FeetBritishBenoit1895B ||
        unit == Qgis::DistanceUnit::FeetBritishSears1922Truncated ||
        unit == Qgis::DistanceUnit::FeetBritishSears1922 ||
        unit == Qgis::DistanceUnit::FeetClarkes || unit == Qgis::DistanceUnit::FeetGoldCoast ||
        unit == Qgis::DistanceUnit::FeetIndian || unit == Qgis::DistanceUnit::FeetIndian1937 ||
        unit == Qgis::DistanceUnit::FeetIndian1962 || unit == Qgis::DistanceUnit::FeetIndian1975) {
        return QStringLiteral("feet");
    }
    if (unit == Qgis::DistanceUnit::Yards || unit == Qgis::DistanceUnit::YardsBritishBenoit1895A ||
        unit == Qgis::DistanceUnit::YardsBritishBenoit1895B ||
        unit == Qgis::DistanceUnit::YardsBritishSears1922Truncated ||
        unit == Qgis::DistanceUnit::YardsBritishSears1922 ||
        unit == Qgis::DistanceUnit::YardsClarkes || unit == Qgis::DistanceUnit::YardsIndian ||
        unit == Qgis::DistanceUnit::YardsIndian1937 || unit == Qgis::DistanceUnit::YardsIndian1962 ||
        unit == Qgis::DistanceUnit::YardsIndian1975) {
        return QStringLiteral("yards");
    }
    if (unit == Qgis::DistanceUnit::Miles || unit == Qgis::DistanceUnit::MilesUSSurvey) {
        return QStringLiteral("miles");
    }
    if (unit == Qgis::DistanceUnit::NauticalMiles) {
        return QStringLiteral("nautical miles");
    }
    if (unit == Qgis::DistanceUnit::Centimeters) {
        return QStringLiteral("centimeters");
    }
    if (unit == Qgis::DistanceUnit::Millimeters) {
        return QStringLiteral("millimeters");
    }
    if (unit == Qgis::DistanceUnit::Inches) {
        return QStringLiteral("inches");
    }
    if (unit == Qgis::DistanceUnit::Degrees) {
        return QStringLiteral("degrees");
    }
    if (unit == Qgis::DistanceUnit::ChainsInternational || unit == Qgis::DistanceUnit::ChainsBritishBenoit1895A ||
        unit == Qgis::DistanceUnit::ChainsBritishBenoit1895B ||
        unit == Qgis::DistanceUnit::ChainsBritishSears1922Truncated ||
        unit == Qgis::DistanceUnit::ChainsBritishSears1922 || unit == Qgis::DistanceUnit::ChainsClarkes ||
        unit == Qgis::DistanceUnit::ChainsUSSurvey) {
        return QStringLiteral("chains");
    }
    if (unit == Qgis::DistanceUnit::LinksInternational || unit == Qgis::DistanceUnit::LinksBritishBenoit1895A ||
        unit == Qgis::DistanceUnit::LinksBritishBenoit1895B ||
        unit == Qgis::DistanceUnit::LinksBritishSears1922Truncated ||
        unit == Qgis::DistanceUnit::LinksBritishSears1922 || unit == Qgis::DistanceUnit::LinksClarkes ||
        unit == Qgis::DistanceUnit::LinksUSSurvey) {
        return QStringLiteral("links");
    }
    if (unit == Qgis::DistanceUnit::Fathoms) {
        return QStringLiteral("fathoms");
    }
    return QStringLiteral("unknown");
}

static int32_t DistanceUnitType(Qgis::DistanceUnit unit)
{
    if (unit == Qgis::DistanceUnit::Degrees) {
        return 1;
    }
    if (unit == Qgis::DistanceUnit::Unknown) {
        return 0;
    }
    return 2;
}

static QColor SymbolPreviewColor(QgsSymbol *symbol, const QColor &fallback)
{
    if (!symbol) {
        return fallback;
    }

    QColor symbolColor = symbol->color();
    if (symbolColor.isValid()) {
        return symbolColor;
    }

    QImage image = symbol->asImage(QSize(32, 24));
    if (!image.isNull()) {
        long long red = 0;
        long long green = 0;
        long long blue = 0;
        long long count = 0;
        for (int y = 0; y < image.height(); y++) {
            for (int x = 0; x < image.width(); x++) {
                QColor pixel = QColor::fromRgba(image.pixel(x, y));
                if (pixel.alpha() > 32) {
                    red += pixel.red();
                    green += pixel.green();
                    blue += pixel.blue();
                    count++;
                }
            }
        }
        if (count > 0) {
            return QColor(static_cast<int>(red / count), static_cast<int>(green / count),
                static_cast<int>(blue / count));
        }
    }

    QColor color = symbol->color();
    if (color.isValid()) {
        return color;
    }
    return fallback;
}

static QColor SymbolPreviewStrokeColor(QgsSymbol *symbol, const QColor &fallback)
{
    if (!symbol) {
        return fallback;
    }

    QImage image = symbol->asImage(QSize(32, 24));
    if (!image.isNull()) {
        QColor bestColor = fallback;
        int bestLuminance = 256 * 3;
        bool found = false;
        for (int y = 0; y < image.height(); y++) {
            for (int x = 0; x < image.width(); x++) {
                QColor pixel = QColor::fromRgba(image.pixel(x, y));
                if (pixel.alpha() > 32) {
                    int luminance = pixel.red() + pixel.green() + pixel.blue();
                    if (luminance < bestLuminance) {
                        bestLuminance = luminance;
                        bestColor = pixel;
                        found = true;
                    }
                }
            }
        }
        if (found) {
            return bestColor;
        }
    }

    return fallback;
}

static QColor VectorLayerLegendColor(QgsVectorLayer &layer)
{
    QColor fallback("#1D4F91");
    QgsFeatureRenderer *renderer = layer.renderer();
    if (renderer) {
        QgsLegendSymbolList legendItems = renderer->legendSymbolItems();
        if (!legendItems.isEmpty()) {
            QColor color = SymbolPreviewColor(legendItems.at(0).symbol(), fallback);
            if (color.isValid()) {
                return color;
            }
        }
    }

    std::unique_ptr<QgsSymbol> defaultSymbol(QgsSymbol::defaultSymbol(layer.geometryType()));
    return SymbolPreviewColor(defaultSymbol.get(), fallback);
}

static QColor VectorLayerLegendStrokeColor(QgsVectorLayer &layer)
{
    QColor fallback("#26362D");
    QgsFeatureRenderer *renderer = layer.renderer();
    if (renderer) {
        QgsLegendSymbolList legendItems = renderer->legendSymbolItems();
        if (!legendItems.isEmpty()) {
            QColor color = SymbolPreviewStrokeColor(legendItems.at(0).symbol(), fallback);
            if (color.isValid()) {
                return color;
            }
        }
    }

    std::unique_ptr<QgsSymbol> defaultSymbol(QgsSymbol::defaultSymbol(layer.geometryType()));
    return SymbolPreviewStrokeColor(defaultSymbol.get(), fallback);
}

static QgsCoordinateReferenceSystem CrsFromDefinition(const char *definition)
{
    QString text = QString::fromUtf8(definition ? definition : "").trimmed();
    QgsCoordinateReferenceSystem crs;
    if (text.isEmpty()) {
        return crs;
    }
    crs.createFromUserInput(text);
    if (!crs.isValid()) {
        crs.createFromString(text);
    }
    if (!crs.isValid()) {
        bool epsgOk = false;
        long epsg = text.toLong(&epsgOk);
        if (epsgOk) {
            crs = QgsCoordinateReferenceSystem::fromEpsgId(epsg);
        }
    }
    if (!crs.isValid() && text.contains(QStringLiteral("+proj"))) {
        crs = QgsCoordinateReferenceSystem::fromProj(text);
    }
    if (!crs.isValid()) {
        crs = QgsCoordinateReferenceSystem::fromWkt(text);
    }
    return crs;
}

static void AppendCrsSummaryFields(std::string &json, const QgsCoordinateReferenceSystem &crs)
{
    Qgis::DistanceUnit unit = crs.mapUnits();
    json += "\"isValid\":";
    json += crs.isValid() ? "true" : "false";
    json += ",\"authId\":\"";
    json += EscapeJson(ToStdString(crs.authid()));
    json += "\",\"description\":\"";
    json += EscapeJson(ToStdString(crs.description()));
    json += "\",\"friendlyName\":\"";
    json += EscapeJson(ToStdString(crs.userFriendlyIdentifier()));
    json += "\",\"projectionAcronym\":\"";
    json += EscapeJson(ToStdString(crs.projectionAcronym()));
    json += "\",\"ellipsoidAcronym\":\"";
    json += EscapeJson(ToStdString(crs.ellipsoidAcronym()));
    json += "\",\"geographicCrsAuthId\":\"";
    json += EscapeJson(ToStdString(crs.geographicCrsAuthId()));
    json += "\",\"celestialBodyName\":\"";
    json += EscapeJson(ToStdString(crs.celestialBodyName()));
    json += "\",\"isGeographic\":";
    json += crs.isGeographic() ? "true" : "false";
    json += ",\"hasAxisInverted\":";
    json += crs.hasAxisInverted() ? "true" : "false";
    json += ",\"srsId\":";
    json += std::to_string(static_cast<long long>(crs.srsid()));
    json += ",\"postgisSrid\":";
    json += std::to_string(static_cast<long long>(crs.postgisSrid()));
    json += ",\"mapUnitCode\":";
    json += std::to_string(static_cast<int32_t>(unit));
    json += ",\"unitName\":\"";
    json += EscapeJson(ToStdString(DistanceUnitName(unit)));
    json += "\",\"unitType\":";
    json += std::to_string(DistanceUnitType(unit));
    json += ",\"bounds\":";
    AppendEnvelope(json, crs.bounds());
    json += ",\"proj\":\"";
    json += EscapeJson(ToStdString(crs.toProj()));
    json += "\",\"wkt\":\"";
    json += EscapeJson(ToStdString(crs.toWkt()));
    json += "\"";
}

static std::string BuildCrsSummaryJson(const QgsCoordinateReferenceSystem &crs, const char *input,
                                       bool ok, int32_t code, const std::string &message)
{
    std::string json = "{\"ok\":";
    json += ok ? "true" : "false";
    json += ",\"code\":";
    json += std::to_string(code);
    json += ",\"message\":\"";
    json += EscapeJson(message);
    json += "\",\"input\":\"";
    json += EscapeJson(input ? input : "");
    json += "\",";
    AppendCrsSummaryFields(json, crs);
    json += "}";
    return json;
}

static std::string BuildLayerJson(QgsVectorLayer &layer, LayerHandle handle)
{
    QgsRectangle extent = layer.extent();
    QgsFields fields = layer.fields();
    QgsCoordinateReferenceSystem crs = layer.crs();
    Qgis::DistanceUnit unit = crs.mapUnits();
    QColor legendColor = VectorLayerLegendColor(layer);
    QColor legendStrokeColor = VectorLayerLegendStrokeColor(layer);

    std::string json = "{\"layerId\":\"L";
    json += std::to_string(handle);
    json += "\",\"name\":\"";
    json += EscapeJson(ToStdString(layer.name()));
    json += "\",\"geometryType\":";
    json += std::to_string(MapGeometryType(layer.geometryType()));
    json += ",\"featureCount\":";
    json += std::to_string(static_cast<long long>(layer.featureCount()));
    json += ",\"envelope\":";
    AppendEnvelope(json, extent);
    json += ",\"crs\":\"";
    json += EscapeJson(ToStdString(crs.authid()));
    json += "\",\"crsDescription\":\"";
    json += EscapeJson(ToStdString(crs.description()));
    json += "\",\"crsFriendlyName\":\"";
    json += EscapeJson(ToStdString(crs.userFriendlyIdentifier()));
    json += "\",\"projectionAcronym\":\"";
    json += EscapeJson(ToStdString(crs.projectionAcronym()));
    json += "\",\"ellipsoidAcronym\":\"";
    json += EscapeJson(ToStdString(crs.ellipsoidAcronym()));
    json += "\",\"geographicCrsAuthId\":\"";
    json += EscapeJson(ToStdString(crs.geographicCrsAuthId()));
    json += "\",\"crsIsGeographic\":";
    json += crs.isGeographic() ? "true" : "false";
    json += ",\"crsBounds\":";
    AppendEnvelope(json, crs.bounds());
    json += ",\"coordinateUnitName\":\"";
    json += EscapeJson(ToStdString(DistanceUnitName(unit)));
    json += "\",\"coordinateUnitType\":";
    json += std::to_string(DistanceUnitType(unit));
    json += ",\"legendColor\":\"";
    json += EscapeJson(ToStdString(legendColor.name(QColor::HexRgb)));
    json += "\"";
    json += ",\"legendStrokeColor\":\"";
    json += EscapeJson(ToStdString(legendStrokeColor.name(QColor::HexRgb)));
    json += "\"";
    json += ",\"fields\":[";
    for (int i = 0; i < fields.count(); i++) {
        if (i > 0) {
            json += ",";
        }
        QgsField field = fields.at(i);
        json += "{\"name\":\"";
        json += EscapeJson(ToStdString(field.name()));
        json += "\",\"alias\":\"";
        json += EscapeJson(ToStdString(field.alias()));
        json += "\",\"typeName\":\"";
        json += EscapeJson(ToStdString(field.typeName()));
        json += "\",\"width\":";
        json += std::to_string(field.length());
        json += ",\"precision\":";
        json += std::to_string(field.precision());
        json += ",\"nullable\":true}";
    }
    json += "]}";
    return json;
}

static std::string BuildRasterLayerJson(const QgsRasterLayer &layer, LayerHandle handle)
{
    QgsRectangle extent = layer.extent();
    QgsCoordinateReferenceSystem crs = layer.crs();
    Qgis::DistanceUnit unit = crs.mapUnits();
    std::string json = "{\"layerId\":\"L";
    json += std::to_string(handle);
    json += "\",\"name\":\"";
    json += EscapeJson(ToStdString(layer.name()));
    json += "\",\"geometryType\":";
    json += std::to_string(GEOM_UNKNOWN);
    json += ",\"featureCount\":0,\"envelope\":";
    AppendEnvelope(json, extent);
    json += ",\"crs\":\"";
    json += EscapeJson(ToStdString(crs.authid()));
    json += "\",\"crsDescription\":\"";
    json += EscapeJson(ToStdString(crs.description()));
    json += "\",\"crsFriendlyName\":\"";
    json += EscapeJson(ToStdString(crs.userFriendlyIdentifier()));
    json += "\",\"projectionAcronym\":\"";
    json += EscapeJson(ToStdString(crs.projectionAcronym()));
    json += "\",\"ellipsoidAcronym\":\"";
    json += EscapeJson(ToStdString(crs.ellipsoidAcronym()));
    json += "\",\"geographicCrsAuthId\":\"";
    json += EscapeJson(ToStdString(crs.geographicCrsAuthId()));
    json += "\",\"crsIsGeographic\":";
    json += crs.isGeographic() ? "true" : "false";
    json += ",\"crsBounds\":";
    AppendEnvelope(json, crs.bounds());
    json += ",\"coordinateUnitName\":\"";
    json += EscapeJson(ToStdString(DistanceUnitName(unit)));
    json += "\",\"coordinateUnitType\":";
    json += std::to_string(DistanceUnitType(unit));
    json += ",\"fields\":[]}";
    return json;
}

static std::string BuildGeometryJson(const QgsGeometry &geometry)
{
    int32_t geometryType = geometry.isNull() ? GEOM_UNKNOWN : MapGeometryType(geometry.type());
    QgsRectangle rect;
    if (!geometry.isNull()) {
        rect = geometry.boundingBox();
    }

    std::string json = "{\"geometryType\":";
    json += std::to_string(geometryType);
    json += ",\"parts\":[";
    AppendGeometryParts(json, geometry, geometryType);
    json += "],\"envelope\":";
    AppendEnvelope(json, rect);
    json += ",\"crs\":\"\"}";
    return json;
}

static std::string BuildFeatureJson(const QgsVectorLayer &layer, const QgsFeature &feature)
{
    QgsGeometry geometry = feature.geometry();
    QgsRectangle rect;
    if (!geometry.isNull()) {
        rect = geometry.boundingBox();
    }

    QgsFields fields = layer.fields();
    std::string json = "{\"featureId\":\"";
    json += std::to_string(static_cast<long long>(feature.id()));
    json += "\",\"geometry\":";
    json += BuildGeometryJson(geometry);
    json += ",\"envelope\":";
    AppendEnvelope(json, rect);
    json += ",\"attributesPreview\":[";
    for (int i = 0; i < fields.count(); i++) {
        if (i > 0) {
            json += ",";
        }
        QgsField field = fields.at(i);
        QVariant value = feature.attribute(i);
        bool isNull = !value.isValid() || value.isNull();
        bool numberOk = false;
        double numberValue = 0.0;
        if (!isNull) {
            numberValue = value.toDouble(&numberOk);
            if (!numberOk) {
                numberValue = 0.0;
            }
        }

        json += "{\"name\":\"";
        json += EscapeJson(ToStdString(field.name()));
        json += "\",\"typeName\":\"";
        json += EscapeJson(ToStdString(field.typeName()));
        json += "\",\"textValue\":\"";
        json += EscapeJson(isNull ? "" : ToStdString(value.toString()));
        json += "\",\"numberValue\":";
        json += std::to_string(numberValue);
        json += ",\"boolValue\":";
        json += (!isNull && value.toBool()) ? "true" : "false";
        json += ",\"isNull\":";
        json += isNull ? "true" : "false";
        json += "}";
    }
    json += "]}";
    return json;
}

static QgisLayerState *FindLayer(LayerHandle handle)
{
    std::map<LayerHandle, std::unique_ptr<QgisLayerState>>::iterator it = g_layers.find(handle);
    if (it == g_layers.end()) {
        return nullptr;
    }
    return it->second.get();
}

static QgisRasterState *FindRasterLayer(LayerHandle handle)
{
    std::map<LayerHandle, std::unique_ptr<QgisRasterState>>::iterator it = g_rasterLayers.find(handle);
    if (it == g_rasterLayers.end()) {
        return nullptr;
    }
    return it->second.get();
}

static QgsMapLayer *FindMapLayer(LayerHandle handle)
{
    QgisLayerState *vectorState = FindLayer(handle);
    if (vectorState && vectorState->layer) {
        return vectorState->layer.get();
    }
    QgisRasterState *rasterState = FindRasterLayer(handle);
    if (rasterState && rasterState->layer) {
        return rasterState->layer.get();
    }
    return nullptr;
}

static void TrackLayerOrder(LayerHandle handle)
{
    for (size_t i = 0; i < g_layerOrder.size(); i++) {
        if (g_layerOrder[i] == handle) {
            return;
        }
    }
    g_layerOrder.push_back(handle);
}

static void RemoveLayerOrder(LayerHandle handle)
{
    std::vector<LayerHandle>::iterator it = std::remove(g_layerOrder.begin(), g_layerOrder.end(), handle);
    if (it != g_layerOrder.end()) {
        g_layerOrder.erase(it, g_layerOrder.end());
    }
}

static double ClampDouble(double value, double minValue, double maxValue)
{
    if (value < minValue) {
        return minValue;
    }
    if (value > maxValue) {
        return maxValue;
    }
    return value;
}

static QColor ColorFromText(const char *text, const QColor &fallback)
{
    if (!text || std::strlen(text) == 0) {
        return fallback;
    }
    QColor color(QString::fromUtf8(text));
    if (!color.isValid()) {
        return fallback;
    }
    return color;
}

static QColor RampColor(int32_t ramp, int index, int total)
{
    double t = total <= 1 ? 0.0 : static_cast<double>(index) / static_cast<double>(total - 1);
    if (ramp == 1) {
        return QColor::fromRgbF(0.90 - 0.12 * t, 0.72 - 0.42 * t, 0.32 - 0.18 * t);
    }
    if (ramp == 2) {
        if (t < 0.5) {
            double local = t * 2.0;
            return QColor::fromRgbF(0.16 + 0.58 * local, 0.48 + 0.30 * local, 0.69 - 0.36 * local);
        }
        double local = (t - 0.5) * 2.0;
        return QColor::fromRgbF(0.74 + 0.05 * local, 0.78 - 0.42 * local, 0.33 - 0.12 * local);
    }
    return QColor::fromRgbF(0.12 + 0.44 * t, 0.42 + 0.30 * t, 0.70 - 0.48 * t);
}

static QString LinePatternName(int32_t linePattern)
{
    if (linePattern == 1) {
        return QStringLiteral("dash");
    }
    if (linePattern == 2) {
        return QStringLiteral("dot");
    }
    if (linePattern == 3) {
        return QStringLiteral("dash dot");
    }
    return QStringLiteral("solid");
}

static QString FillPatternName(int32_t fillPattern)
{
    if (fillPattern == 1) {
        return QStringLiteral("horizontal");
    }
    if (fillPattern == 2) {
        return QStringLiteral("diagonal_x");
    }
    if (fillPattern == 3) {
        return QStringLiteral("dense4");
    }
    return QStringLiteral("solid");
}

static QgsSymbol *CreateSymbolForLayer(QgsVectorLayer *layer, int32_t colorRamp, int32_t rampIndex,
                                       int32_t rampTotal, int32_t linePattern, int32_t fillPattern,
                                       const char *pointColor, const char *lineColor,
                                       const char *fillColor, const char *strokeColor,
                                       double lineWidth, double pointRadius, double opacity)
{
    if (!layer) {
        return nullptr;
    }
    double cleanOpacity = ClampDouble(opacity, 0.0, 1.0);
    Qgis::GeometryType geomType = layer->geometryType();
    QColor rampColor = RampColor(colorRamp, rampIndex, rampTotal);
    QColor point = rampTotal > 1 ? rampColor : ColorFromText(pointColor, QColor("#BD6B16"));
    QColor line = rampTotal > 1 ? rampColor : ColorFromText(lineColor, QColor("#2563A8"));
    QColor fill = rampTotal > 1 ? rampColor : ColorFromText(fillColor, QColor("#B8D7C9"));
    QColor stroke = ColorFromText(strokeColor, QColor("#4A8B6F"));

    QgsSymbol *symbol = nullptr;
    if (geomType == Qgis::GeometryType::Point) {
        QVariantMap props;
        props.insert(QStringLiteral("color"), point.name(QColor::HexRgb));
        props.insert(QStringLiteral("outline_color"), stroke.name(QColor::HexRgb));
        props.insert(QStringLiteral("size"), QString::number(ClampDouble(pointRadius, 1.0, 32.0), 'f', 2));
        std::unique_ptr<QgsMarkerSymbol> marker = QgsMarkerSymbol::createSimple(props);
        symbol = marker.release();
    } else if (geomType == Qgis::GeometryType::Line) {
        QVariantMap props;
        props.insert(QStringLiteral("color"), line.name(QColor::HexRgb));
        props.insert(QStringLiteral("width"), QString::number(ClampDouble(lineWidth, 0.2, 24.0), 'f', 2));
        props.insert(QStringLiteral("line_style"), LinePatternName(linePattern));
        std::unique_ptr<QgsLineSymbol> lineSymbol = QgsLineSymbol::createSimple(props);
        symbol = lineSymbol.release();
    } else if (geomType == Qgis::GeometryType::Polygon) {
        QVariantMap props;
        props.insert(QStringLiteral("color"), fill.name(QColor::HexRgb));
        props.insert(QStringLiteral("outline_color"), stroke.name(QColor::HexRgb));
        props.insert(QStringLiteral("outline_width"), QString::number(ClampDouble(lineWidth, 0.2, 24.0), 'f', 2));
        props.insert(QStringLiteral("style"), FillPatternName(fillPattern));
        std::unique_ptr<QgsFillSymbol> fillSymbol = QgsFillSymbol::createSimple(props);
        symbol = fillSymbol.release();
    }

    if (!symbol) {
        symbol = QgsSymbol::defaultSymbol(geomType);
    }
    if (symbol) {
        symbol->setOpacity(cleanOpacity);
    }
    return symbol;
}

static bool BuildCategorizedRenderer(QgsVectorLayer *layer, const QString &fieldName, int32_t colorRamp,
                                     int32_t linePattern, int32_t fillPattern, const char *pointColor,
                                     const char *lineColor, const char *fillColor, const char *strokeColor,
                                     double lineWidth, double pointRadius, double opacity)
{
    int fieldIndex = layer->fields().indexOf(fieldName);
    if (fieldIndex < 0) {
        return false;
    }
    QVector<QVariant> values;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QVariant value = feature.attribute(fieldIndex);
        bool exists = false;
        for (int i = 0; i < values.size(); i++) {
            if (values.at(i).toString() == value.toString()) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            values.push_back(value);
        }
        if (values.size() >= 12) {
            break;
        }
    }
    if (values.isEmpty()) {
        return false;
    }

    QgsCategoryList categories;
    for (int i = 0; i < values.size(); i++) {
        QgsSymbol *symbol = CreateSymbolForLayer(layer, colorRamp, i, values.size(), linePattern, fillPattern,
            pointColor, lineColor, fillColor, strokeColor, lineWidth, pointRadius, opacity);
        QString label = values.at(i).toString();
        categories.append(QgsRendererCategory(values.at(i), symbol, label, true));
    }
    layer->setRenderer(new QgsCategorizedSymbolRenderer(fieldName, categories));
    return true;
}

static bool BuildGraduatedRenderer(QgsVectorLayer *layer, const QString &fieldName, int32_t colorRamp,
                                   int32_t linePattern, int32_t fillPattern, const char *pointColor,
                                   const char *lineColor, const char *fillColor, const char *strokeColor,
                                   double lineWidth, double pointRadius, double opacity)
{
    int fieldIndex = layer->fields().indexOf(fieldName);
    if (fieldIndex < 0) {
        return false;
    }
    bool hasValue = false;
    double minValue = 0.0;
    double maxValue = 0.0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        bool ok = false;
        double value = feature.attribute(fieldIndex).toDouble(&ok);
        if (ok) {
            if (!hasValue) {
                minValue = value;
                maxValue = value;
                hasValue = true;
            } else {
                if (value < minValue) {
                    minValue = value;
                }
                if (value > maxValue) {
                    maxValue = value;
                }
            }
        }
    }
    if (!hasValue) {
        return false;
    }
    if (std::abs(maxValue - minValue) < 0.0000001) {
        maxValue = minValue + 1.0;
    }

    int rangeCount = 5;
    QgsRangeList ranges;
    double step = (maxValue - minValue) / static_cast<double>(rangeCount);
    for (int i = 0; i < rangeCount; i++) {
        double lower = minValue + step * static_cast<double>(i);
        double upper = (i == rangeCount - 1) ? maxValue : lower + step;
        QgsSymbol *symbol = CreateSymbolForLayer(layer, colorRamp, i, rangeCount, linePattern, fillPattern,
            pointColor, lineColor, fillColor, strokeColor, lineWidth, pointRadius, opacity);
        QString label = QString::number(lower, 'f', 2) + QStringLiteral(" - ") + QString::number(upper, 'f', 2);
        ranges.append(QgsRendererRange(lower, upper, symbol, label, true));
    }
    layer->setRenderer(new QgsGraduatedSymbolRenderer(fieldName, ranges));
    return true;
}

static QgsContrastEnhancement *CreateContrastEnhancement(QgsRasterDataProvider *provider, int bandNo,
                                                         int32_t stretchMode)
{
    if (!provider || stretchMode == 0) {
        return nullptr;
    }
    QgsContrastEnhancement *enhancement = new QgsContrastEnhancement(provider->dataType(bandNo));
    if (stretchMode == 1) {
        enhancement->setContrastEnhancementAlgorithm(QgsContrastEnhancement::StretchToMinimumMaximum, true);
    } else if (stretchMode == 2) {
        enhancement->setContrastEnhancementAlgorithm(QgsContrastEnhancement::StretchAndClipToMinimumMaximum, true);
    } else {
        enhancement->setContrastEnhancementAlgorithm(QgsContrastEnhancement::ClipToMinimumMaximum, true);
    }
    return enhancement;
}

static void CollectGeometryPoints(const QgsGeometry &geometry, std::vector<QgsPointXY> &points)
{
    if (geometry.isNull() || geometry.isEmpty()) {
        return;
    }
    int32_t geometryType = MapGeometryType(geometry.type());
    if (geometryType == GEOM_POINT) {
        if (geometry.isMultipart()) {
            QgsMultiPointXY multiPoints = geometry.asMultiPoint();
            for (int i = 0; i < multiPoints.size(); i++) {
                points.push_back(multiPoints.at(i));
            }
        } else {
            points.push_back(geometry.asPoint());
        }
    } else if (geometryType == GEOM_LINESTRING) {
        if (geometry.isMultipart()) {
            QgsMultiPolylineXY lines = geometry.asMultiPolyline();
            for (int li = 0; li < lines.size(); li++) {
                QgsPolylineXY line = lines.at(li);
                for (int pi = 0; pi < line.size(); pi++) {
                    points.push_back(line.at(pi));
                }
            }
        } else {
            QgsPolylineXY line = geometry.asPolyline();
            for (int pi = 0; pi < line.size(); pi++) {
                points.push_back(line.at(pi));
            }
        }
    } else if (geometryType == GEOM_POLYGON) {
        if (geometry.isMultipart()) {
            QgsMultiPolygonXY polygons = geometry.asMultiPolygon();
            for (int pi = 0; pi < polygons.size(); pi++) {
                QgsPolygonXY polygon = polygons.at(pi);
                for (int ri = 0; ri < polygon.size(); ri++) {
                    QgsPolylineXY ring = polygon.at(ri);
                    for (int vi = 0; vi < ring.size(); vi++) {
                        points.push_back(ring.at(vi));
                    }
                }
            }
        } else {
            QgsPolygonXY polygon = geometry.asPolygon();
            for (int ri = 0; ri < polygon.size(); ri++) {
                QgsPolylineXY ring = polygon.at(ri);
                for (int vi = 0; vi < ring.size(); vi++) {
                    points.push_back(ring.at(vi));
                }
            }
        }
    }
}

static bool SnapPointToTargets(QgsPointXY &point, const std::vector<QgsPointXY> &targets, double tolerance)
{
    double toleranceSq = tolerance * tolerance;
    double bestSq = toleranceSq;
    bool found = false;
    QgsPointXY bestPoint = point;
    for (size_t i = 0; i < targets.size(); i++) {
        double dx = targets[i].x() - point.x();
        double dy = targets[i].y() - point.y();
        double distSq = dx * dx + dy * dy;
        if (distSq > 0.000000000001 && distSq <= bestSq) {
            bestSq = distSq;
            bestPoint = targets[i];
            found = true;
        }
    }
    if (found) {
        point = bestPoint;
    }
    return found;
}

static void SetRingPoint(QgsPolylineXY &ring, int pointIndex, const QgsPointXY &point);

static bool SnapGeometryToTargets(QgsGeometry &geometry, const std::vector<QgsPointXY> &targets, double tolerance)
{
    if (geometry.isNull() || geometry.isEmpty() || targets.empty()) {
        return false;
    }
    bool changed = false;
    int32_t geometryType = MapGeometryType(geometry.type());
    if (geometryType == GEOM_POINT) {
        if (geometry.isMultipart()) {
            QgsMultiPointXY points = geometry.asMultiPoint();
            for (int i = 0; i < points.size(); i++) {
                QgsPointXY point = points.at(i);
                if (SnapPointToTargets(point, targets, tolerance)) {
                    points[i] = point;
                    changed = true;
                }
            }
            if (changed) {
                geometry = QgsGeometry::fromMultiPointXY(points);
            }
        } else {
            QgsPointXY point = geometry.asPoint();
            if (SnapPointToTargets(point, targets, tolerance)) {
                geometry = QgsGeometry::fromPointXY(point);
                changed = true;
            }
        }
    } else if (geometryType == GEOM_LINESTRING) {
        if (geometry.isMultipart()) {
            QgsMultiPolylineXY lines = geometry.asMultiPolyline();
            for (int li = 0; li < lines.size(); li++) {
                QgsPolylineXY line = lines.at(li);
                for (int pi = 0; pi < line.size(); pi++) {
                    QgsPointXY point = line.at(pi);
                    if (SnapPointToTargets(point, targets, tolerance)) {
                        line[pi] = point;
                        changed = true;
                    }
                }
                lines[li] = line;
            }
            if (changed) {
                geometry = QgsGeometry::fromMultiPolylineXY(lines);
            }
        } else {
            QgsPolylineXY line = geometry.asPolyline();
            for (int pi = 0; pi < line.size(); pi++) {
                QgsPointXY point = line.at(pi);
                if (SnapPointToTargets(point, targets, tolerance)) {
                    line[pi] = point;
                    changed = true;
                }
            }
            if (changed) {
                geometry = QgsGeometry::fromPolylineXY(line);
            }
        }
    } else if (geometryType == GEOM_POLYGON) {
        if (geometry.isMultipart()) {
            QgsMultiPolygonXY polygons = geometry.asMultiPolygon();
            for (int pi = 0; pi < polygons.size(); pi++) {
                QgsPolygonXY polygon = polygons.at(pi);
                for (int ri = 0; ri < polygon.size(); ri++) {
                    QgsPolylineXY ring = polygon.at(ri);
                    for (int vi = 0; vi < ring.size(); vi++) {
                        QgsPointXY point = ring.at(vi);
                        if (SnapPointToTargets(point, targets, tolerance)) {
                            SetRingPoint(ring, vi, point);
                            changed = true;
                        }
                    }
                    polygon[ri] = ring;
                }
                polygons[pi] = polygon;
            }
            if (changed) {
                geometry = QgsGeometry::fromMultiPolygonXY(polygons);
            }
        } else {
            QgsPolygonXY polygon = geometry.asPolygon();
            for (int ri = 0; ri < polygon.size(); ri++) {
                QgsPolylineXY ring = polygon.at(ri);
                for (int vi = 0; vi < ring.size(); vi++) {
                    QgsPointXY point = ring.at(vi);
                    if (SnapPointToTargets(point, targets, tolerance)) {
                        SetRingPoint(ring, vi, point);
                        changed = true;
                    }
                }
                polygon[ri] = ring;
            }
            if (changed) {
                geometry = QgsGeometry::fromPolygonXY(polygon);
            }
        }
    }
    return changed;
}

static std::vector<int64_t> ParseFidList(const char *fidListText)
{
    std::vector<int64_t> fids;
    std::set<int64_t> seen;
    if (!fidListText) {
        return fids;
    }
    const char *p = fidListText;
    while (*p != '\0') {
        char *endValue = nullptr;
        long long value = std::strtoll(p, &endValue, 10);
        if (endValue != p) {
            int64_t fid = static_cast<int64_t>(value);
            if (seen.find(fid) == seen.end()) {
                seen.insert(fid);
                fids.push_back(fid);
            }
            p = endValue;
        } else {
            p++;
        }
        if (*p == ';' || *p == ',') {
            p++;
        }
    }
    return fids;
}

static bool CollectMapLayers(QList<QgsMapLayer *> &layers, QgsRectangle &extent, QgsCoordinateReferenceSystem &crs,
                             const char *visibleLayerHandles)
{
    bool hasExtent = false;
    std::vector<int64_t> requestedHandles = ParseFidList(visibleLayerHandles);
    std::set<int64_t> requestedHandleSet(requestedHandles.begin(), requestedHandles.end());
    bool restrictToVisibleLayers = visibleLayerHandles != nullptr;
    for (size_t i = 0; i < g_layerOrder.size(); i++) {
        if (restrictToVisibleLayers &&
            requestedHandleSet.find(static_cast<int64_t>(g_layerOrder[i])) == requestedHandleSet.end()) {
            continue;
        }
        QgsMapLayer *layer = FindMapLayer(g_layerOrder[i]);
        if (!layer || !layer->isValid()) {
            continue;
        }
        layers.append(layer);
        QgsRectangle layerExtent = layer->extent();
        if (!layerExtent.isNull() && !layerExtent.isEmpty()) {
            if (!hasExtent) {
                extent = layerExtent;
                hasExtent = true;
                crs = layer->crs();
            } else {
                extent.combineExtentWith(layerExtent);
            }
        }
    }
    return !layers.isEmpty() && hasExtent;
}

static QImage RenderMapImage(const QList<QgsMapLayer *> &layers, const QgsRectangle &extent,
                             const QgsCoordinateReferenceSystem &crs, int32_t width, int32_t height)
{
    QgsMapSettings settings;
    settings.setLayers(layers);
    settings.setExtent(extent);
    settings.setOutputSize(QSize(width, height));
    settings.setOutputDpi(144.0);
    settings.setBackgroundColor(QColor(255, 255, 255, 0));
    if (crs.isValid()) {
        settings.setDestinationCrs(crs);
    }
    settings.setFlag(Qgis::MapSettingsFlag::Antialiasing, true);
    settings.setFlag(Qgis::MapSettingsFlag::DrawLabeling, true);
    QgsMapRendererSequentialJob job(settings);
    job.start();
    job.waitForFinished();
    return job.renderedImage();
}

static QString LayoutFontFamily()
{
    static bool initialized = false;
    static QString family;
    if (initialized) {
        return family;
    }
    initialized = true;

    QStringList fontFiles;
    QString libraryDir = ResolveSharedLibraryDir();
    if (!libraryDir.isEmpty()) {
        fontFiles.append(QDir(libraryDir).filePath("fonts/HarmonyOS_Sans_SC.ttf"));
    }
    fontFiles.append(QStringLiteral("/system/fonts/HarmonyOS_Sans_SC.ttf"));
    fontFiles.append(QStringLiteral("/system/fonts/HarmonyOS_Sans_SC_Regular.ttf"));
    fontFiles.append(QStringLiteral("/system/fonts/HarmonyOS_Sans_SC-Medium.ttf"));
    fontFiles.append(QStringLiteral("/system/fonts/HarmonyOS_Sans_SC-Regular.ttf"));
    fontFiles.append(QStringLiteral("/system/fonts/HarmonyOS_Sans.ttf"));
    fontFiles.append(QStringLiteral("/system/fonts/HarmonyOS_Sans_Regular.ttf"));
    fontFiles.append(QStringLiteral("/system/fonts/HarmonyOS_Sans-Regular.ttf"));
    fontFiles.append(QStringLiteral("/system/fonts/NotoSansCJK-Regular.ttc"));
    fontFiles.append(QStringLiteral("/system/fonts/NotoSansCJKsc-Regular.otf"));
    fontFiles.append(QStringLiteral("/system/fonts/NotoSansSC-Regular.otf"));
    fontFiles.append(QStringLiteral("/system/fonts/DroidSansFallback.ttf"));
    fontFiles.append(QStringLiteral("/system/fonts/SourceHanSansSC-Regular.otf"));
    for (int i = 0; i < fontFiles.size(); i++) {
        QString fontFile = fontFiles.at(i);
        if (!QFileInfo::exists(fontFile)) {
            continue;
        }
        int fontId = QFontDatabase::addApplicationFont(fontFile);
        if (fontId >= 0) {
            QStringList families = QFontDatabase::applicationFontFamilies(fontId);
            if (!families.isEmpty()) {
                family = families.first();
                return family;
            }
        }
    }

    QFontDatabase database;
    QStringList families = database.families();
    QStringList preferred = {
        QStringLiteral("HarmonyOS Sans SC"),
        QStringLiteral("HarmonyOS Sans"),
        QStringLiteral("Noto Sans CJK SC"),
        QStringLiteral("Noto Sans CJK"),
        QStringLiteral("Droid Sans Fallback"),
        QStringLiteral("sans-serif")
    };
    for (int i = 0; i < preferred.size(); i++) {
        QString candidate = preferred.at(i);
        if (families.contains(candidate, Qt::CaseInsensitive)) {
            family = candidate;
            return family;
        }
    }
    family = QStringLiteral("sans-serif");
    return family;
}

static QFont LayoutFont(int pointSize, bool bold)
{
    QFont font(LayoutFontFamily());
    font.setPointSize(pointSize);
    font.setBold(bold);
    font.setStyleStrategy(QFont::PreferAntialias);
    return font;
}

static QString LayoutTextOrDefault(const char *value, const QString &fallback)
{
    if (!value || std::strlen(value) == 0) {
        return fallback;
    }
    return QString::fromUtf8(value);
}

static int LegendEntryCountForLayer(QgsMapLayer *layer)
{
    QgsVectorLayer *vectorLayer = qobject_cast<QgsVectorLayer *>(layer);
    if (vectorLayer && vectorLayer->renderer()) {
        QgsLegendSymbolList legendItems = vectorLayer->renderer()->legendSymbolItems();
        if (!legendItems.isEmpty()) {
            return legendItems.size();
        }
    }
    return 1;
}

static int LegendEntryCount(const QList<QgsMapLayer *> &layers)
{
    int count = 0;
    for (int i = 0; i < layers.size(); i++) {
        count += LegendEntryCountForLayer(layers.at(i));
    }
    return std::max(1, count);
}

static void DrawLegendSymbolPatch(QPainter &painter, QgsSymbol *symbol, const QRect &rect,
                                  const QColor &fallbackColor)
{
    painter.save();
    painter.setRenderHint(QPainter::Antialiasing, true);
    if (symbol) {
        QImage symbolImage = symbol->asImage(QSize(rect.width(), rect.height()));
        if (!symbolImage.isNull()) {
            painter.drawImage(rect, symbolImage);
            painter.restore();
            return;
        }
    }
    painter.fillRect(rect, fallbackColor);
    painter.restore();
}

static QString LegendItemLabel(QgsMapLayer *layer, const QgsLegendSymbolList &legendItems,
                               const QgsLegendSymbolItem &item)
{
    QString itemLabel = item.label().trimmed();
    if (legendItems.size() <= 1 || itemLabel.isEmpty()) {
        return layer->name();
    }
    return layer->name() + QStringLiteral(" · ") + itemLabel;
}

static int DrawVectorLegendRows(QPainter &painter, QgsMapLayer *layer, const QRect &legendRect,
                                int rowIndex, int maxRows)
{
    QgsVectorLayer *vectorLayer = qobject_cast<QgsVectorLayer *>(layer);
    if (!vectorLayer || !vectorLayer->renderer()) {
        return rowIndex;
    }
    QgsLegendSymbolList legendItems = vectorLayer->renderer()->legendSymbolItems();
    if (legendItems.isEmpty()) {
        return rowIndex;
    }
    for (int i = 0; i < legendItems.size(); i++) {
        if (rowIndex >= maxRows) {
            return rowIndex;
        }
        int y = legendRect.top() + 42 + rowIndex * 28;
        QRect symbolRect(legendRect.left() + 12, y, 22, 18);
        QColor fallbackColor = RampColor(0, rowIndex, std::max(1, maxRows));
        DrawLegendSymbolPatch(painter, legendItems.at(i).symbol(), symbolRect, fallbackColor);
        painter.setPen(QPen(QColor("#17201D"), 1));
        painter.drawText(legendRect.left() + 40, y - 3, legendRect.width() - 52, 22,
            Qt::AlignLeft | Qt::AlignVCenter, LegendItemLabel(layer, legendItems, legendItems.at(i)));
        rowIndex++;
    }
    return rowIndex;
}

static int DrawFallbackLegendRow(QPainter &painter, QgsMapLayer *layer, const QRect &legendRect,
                                 int rowIndex, int maxRows)
{
    if (rowIndex >= maxRows) {
        return rowIndex;
    }
    int y = legendRect.top() + 42 + rowIndex * 28;
    painter.fillRect(legendRect.left() + 12, y + 2, 18, 12, RampColor(0, rowIndex, std::max(1, maxRows)));
    painter.setPen(QPen(QColor("#17201D"), 1));
    painter.drawText(legendRect.left() + 40, y - 3, legendRect.width() - 52, 22,
        Qt::AlignLeft | Qt::AlignVCenter, layer->name());
    return rowIndex + 1;
}

static bool IsTerrainBasemap(int32_t basemapMode)
{
    return basemapMode == 2 || basemapMode == 5;
}

static bool IsImageryBasemap(int32_t basemapMode)
{
    return basemapMode == 3 || basemapMode == 6;
}

static void DrawExportBasemap(QPainter &painter, const QRect &mapRect, int32_t basemapMode,
                              const QString &basemapLabel)
{
    painter.save();
    painter.setClipRect(mapRect);
    painter.fillRect(mapRect, QColor("#FBFCFD"));

    if (IsImageryBasemap(basemapMode)) {
        painter.fillRect(mapRect, QColor("#2F3B42"));
        int block = 92;
        for (int x = mapRect.left(); x < mapRect.right() + block; x += block) {
            for (int y = mapRect.top(); y < mapRect.bottom() + block; y += block) {
                int seed = ((x - mapRect.left()) / block + (y - mapRect.top()) / block) % 4;
                QColor color("#36464A");
                if (seed == 1) {
                    color = QColor("#253237");
                } else if (seed == 2) {
                    color = QColor("#44513F");
                } else if (seed == 3) {
                    color = QColor("#2B3A3E");
                }
                painter.fillRect(QRect(x, y, block, block), color);
            }
        }
        painter.setPen(QPen(QColor(140, 180, 205, 72), 2));
        for (int i = 0; i < 8; i++) {
            int y = mapRect.top() + 28 + i * 46;
            painter.drawLine(mapRect.left(), y, mapRect.right(), y + (i % 2 == 0 ? 18 : -16));
        }
    } else if (IsTerrainBasemap(basemapMode)) {
        painter.fillRect(mapRect, QColor("#F4F1E8"));
        for (int i = 0; i < 14; i++) {
            int y = mapRect.top() + 32 + i * 42;
            QColor color = (i % 2 == 0) ? QColor("#C7B98A") : QColor("#AFC4A2");
            painter.setPen(QPen(color, 1));
            QPainterPath path;
            path.moveTo(mapRect.left(), y);
            path.cubicTo(mapRect.left() + mapRect.width() * 0.25, y - 26,
                mapRect.left() + mapRect.width() * 0.58, y + 30, mapRect.right(), y - 10);
            painter.drawPath(path);
        }
        painter.fillRect(QRect(mapRect.left(), mapRect.top() + mapRect.height() * 2 / 3,
            mapRect.width(), mapRect.height() / 3), QColor(221, 231, 201, 112));
    } else {
        painter.fillRect(mapRect, QColor("#F6FAF7"));
        painter.fillRect(QRect(mapRect.left(), mapRect.top() + mapRect.height() * 58 / 100,
            mapRect.width(), mapRect.height() * 14 / 100), QColor("#DCEFEB"));
        painter.setPen(QPen(QColor("#BFD8CA"), 2));
        for (int i = 0; i < 10; i++) {
            int y = mapRect.top() + 24 + i * 48;
            painter.drawLine(mapRect.left(), y, mapRect.right(), y + (i % 2 == 0 ? 12 : -14));
        }
        painter.setPen(QPen(QColor("#FFFFFF"), 5));
        painter.drawLine(mapRect.left() + 16, mapRect.bottom() - 60, mapRect.right() - 22, mapRect.top() + 40);
        painter.setPen(QPen(QColor("#D7C7A2"), 2));
        painter.drawLine(mapRect.left() + 16, mapRect.bottom() - 60, mapRect.right() - 22, mapRect.top() + 40);
    }

    if (!basemapLabel.isEmpty()) {
        QRect labelRect(mapRect.left() + 14, mapRect.top() + 12, 360, 28);
        painter.fillRect(labelRect, QColor(255, 255, 255, 205));
        painter.setPen(QPen(QColor("#5D6B64"), 1));
        painter.setFont(LayoutFont(10, false));
        painter.drawText(labelRect.adjusted(8, 0, -8, 0), Qt::AlignLeft | Qt::AlignVCenter, basemapLabel);
    }

    painter.restore();
}

static void DrawLayoutDecorations(QPainter &painter, const QImage &mapImage, const QList<QgsMapLayer *> &layers,
                                  const QString &title, const QString &legendTitleText,
                                  const QString &scaleText, const QString &footerText,
                                  bool showLegend, bool showScaleBar,
                                  bool showNorthArrow, bool showGrid, int32_t width, int32_t height,
                                  int32_t basemapMode, const QString &basemapLabel)
{
    painter.fillRect(0, 0, width, height, QColor("#ffffff"));
    painter.setPen(QPen(QColor("#17201D"), 2));
    painter.setFont(LayoutFont(24, true));
    painter.drawText(32, 22, width - 64, 44, Qt::AlignLeft | Qt::AlignVCenter, title);

    QRect mapRect(32, 82, width - 64, height - 144);
    DrawExportBasemap(painter, mapRect, basemapMode, basemapLabel);
    painter.drawImage(mapRect, mapImage);
    painter.setPen(QPen(QColor("#27352F"), 2));
    painter.drawRect(mapRect);

    if (showGrid) {
        painter.setPen(QPen(QColor(39, 53, 47, 70), 1, Qt::DashLine));
        int cols = 6;
        int rows = 4;
        for (int i = 1; i < cols; i++) {
            int x = mapRect.left() + mapRect.width() * i / cols;
            painter.drawLine(x, mapRect.top(), x, mapRect.bottom());
        }
        for (int i = 1; i < rows; i++) {
            int y = mapRect.top() + mapRect.height() * i / rows;
            painter.drawLine(mapRect.left(), y, mapRect.right(), y);
        }
    }

    if (showLegend) {
        int legendWidth = 300;
        int entryCount = LegendEntryCount(layers);
        int maxLegendHeight = std::max(72, mapRect.height() - 28);
        int legendHeight = std::min(44 + entryCount * 28, maxLegendHeight);
        int maxRows = std::max(1, (legendHeight - 44) / 28);
        QRect legendRect(mapRect.right() - legendWidth - 14, mapRect.top() + 14, legendWidth, legendHeight);
        painter.fillRect(legendRect, QColor(255, 255, 255, 230));
        painter.setPen(QPen(QColor("#27352F"), 1));
        painter.drawRect(legendRect);
        painter.setFont(LayoutFont(14, true));
        painter.drawText(legendRect.left() + 12, legendRect.top() + 8, legendWidth - 24, 24, Qt::AlignLeft,
            legendTitleText);
        painter.setFont(LayoutFont(12, false));
        int rowIndex = 0;
        for (int i = 0; i < layers.size(); i++) {
            int previousRow = rowIndex;
            rowIndex = DrawVectorLegendRows(painter, layers.at(i), legendRect, rowIndex, maxRows);
            if (rowIndex == previousRow) {
                rowIndex = DrawFallbackLegendRow(painter, layers.at(i), legendRect, rowIndex, maxRows);
            }
            if (rowIndex >= maxRows) {
                break;
            }
        }
    }

    if (showScaleBar) {
        int barX = mapRect.left() + 24;
        int barY = mapRect.bottom() - 30;
        painter.setPen(QPen(QColor("#17201D"), 4));
        painter.drawLine(barX, barY, barX + 130, barY);
        painter.setPen(QPen(QColor("#17201D"), 1));
        painter.drawLine(barX, barY - 7, barX, barY + 7);
        painter.drawLine(barX + 130, barY - 7, barX + 130, barY + 7);
        painter.setFont(LayoutFont(11, false));
        painter.drawText(barX, barY + 12, 240, 24, Qt::AlignLeft, scaleText);
    }

    if (showNorthArrow) {
        int cx = mapRect.right() - 48;
        int cy = mapRect.bottom() - 58;
        QPolygon arrow;
        arrow << QPoint(cx, cy - 28) << QPoint(cx - 11, cy + 18) << QPoint(cx, cy + 8) << QPoint(cx + 11, cy + 18);
        painter.setBrush(QBrush(QColor("#17201D")));
        painter.setPen(QPen(QColor("#17201D"), 1));
        painter.drawPolygon(arrow);
        painter.setFont(LayoutFont(13, true));
        painter.drawText(cx - 10, cy - 46, 20, 16, Qt::AlignCenter, QStringLiteral("N"));
    }

    painter.setFont(LayoutFont(11, false));
    painter.setPen(QPen(QColor("#5D6B64"), 1));
    painter.drawText(32, height - 44, width - 64, 26, Qt::AlignLeft | Qt::AlignVCenter, footerText);
}

// ---------------------------------------------------------------------------
// Geoprocessing helpers
// ---------------------------------------------------------------------------

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

static const char *MakeProcessResult(bool ok, int32_t code, const std::string &message,
                                    const std::string &outputPath,
                                    const std::string &outputLayerName,
                                    int32_t featureCount, int32_t *outErrCode)
{
    if (outErrCode) {
        *outErrCode = ok ? GIS_OK : code;
    }
    return DuplicateCString(BuildProcessResultJson(ok, code, message, outputPath, outputLayerName, featureCount));
}

static std::string CommitErrors(QgsVectorLayer *layer)
{
    QStringList errors = layer->commitErrors();
    if (errors.isEmpty()) {
        return "QGIS provider commit failed";
    }
    std::string message;
    for (int i = 0; i < errors.size(); i++) {
        if (i > 0) {
            message += "; ";
        }
        message += ToStdString(errors.at(i));
    }
    return message;
}

static bool BeginEdit(QgsVectorLayer *layer, std::string &message)
{
    if (!layer) {
        message = "Layer not found";
        return false;
    }
    if (layer->isEditable()) {
        return true;
    }
    if (!layer->startEditing()) {
        message = "QGIS provider is not editable";
        return false;
    }
    return true;
}

static bool CommitEdit(QgsVectorLayer *layer, std::string &message)
{
    if (!layer->commitChanges()) {
        message = CommitErrors(layer);
        layer->rollBack();
        return false;
    }
    layer->updateExtents();
    layer->triggerRepaint();
    return true;
}

static std::vector<QgsPointXY> ParseCoordText(const char *coordsText)
{
    std::vector<QgsPointXY> points;
    if (!coordsText) {
        return points;
    }
    const char *p = coordsText;
    while (*p != '\0') {
        char *endX = nullptr;
        double x = std::strtod(p, &endX);
        if (endX == p || *endX != ',') {
            break;
        }
        p = endX + 1;
        char *endY = nullptr;
        double y = std::strtod(p, &endY);
        if (endY == p) {
            break;
        }
        points.push_back(QgsPointXY(x, y));
        p = endY;
        if (*p == ';') {
            p++;
        } else if (*p == '\0') {
            break;
        } else {
            p++;
        }
    }
    return points;
}

static bool SamePoint(const QgsPointXY &a, const QgsPointXY &b)
{
    return a.x() == b.x() && a.y() == b.y();
}

static QgsGeometry GeometryFromPoints(int32_t geometryType, const std::vector<QgsPointXY> &points)
{
    if (geometryType == GEOM_POINT && points.size() >= 1) {
        return QgsGeometry::fromPointXY(points[0]);
    }
    if (geometryType == GEOM_LINESTRING && points.size() >= 2) {
        QgsPolylineXY line;
        for (size_t i = 0; i < points.size(); i++) {
            line.push_back(points[i]);
        }
        return QgsGeometry::fromPolylineXY(line);
    }
    if (geometryType == GEOM_POLYGON && points.size() >= 3) {
        QgsPolylineXY ring;
        for (size_t i = 0; i < points.size(); i++) {
            ring.push_back(points[i]);
        }
        if (!SamePoint(ring.first(), ring.last())) {
            ring.push_back(ring.first());
        }
        QgsPolygonXY polygon;
        polygon.push_back(ring);
        return QgsGeometry::fromPolygonXY(polygon);
    }
    return QgsGeometry();
}

static int FieldIndexByName(QgsVectorLayer *layer, const char *fieldName)
{
    if (!layer || !fieldName) {
        return -1;
    }
    return layer->fields().indexOf(QString::fromUtf8(fieldName));
}

static bool FetchFeature(QgsVectorLayer *layer, int64_t fid, QgsFeature &feature)
{
    QgsFeatureRequest request;
    request.setFilterFid(static_cast<QgsFeatureId>(fid));
    QgsFeatureIterator iterator = layer->getFeatures(request);
    return iterator.nextFeature(feature);
}

static bool RowMatchesFilter(const QgsVectorLayer *layer, const QgsFeature &feature, const QString &filterText)
{
    if (filterText.isEmpty()) {
        return true;
    }
    QString needle = filterText.toLower();
    if (QString::number(static_cast<long long>(feature.id())).toLower().contains(needle)) {
        return true;
    }
    QgsFields fields = layer->fields();
    for (int i = 0; i < fields.count(); i++) {
        if (fields.at(i).name().toLower().contains(needle)) {
            return true;
        }
        QVariant value = feature.attribute(i);
        if (value.isValid() && !value.isNull() && value.toString().toLower().contains(needle)) {
            return true;
        }
    }
    return false;
}

static void SetRingPoint(QgsPolylineXY &ring, int pointIndex, const QgsPointXY &point)
{
    if (pointIndex < 0 || pointIndex >= ring.size()) {
        return;
    }
    ring[pointIndex] = point;
    if (ring.size() > 1) {
        if (pointIndex == 0) {
            ring[ring.size() - 1] = point;
        } else if (pointIndex == ring.size() - 1) {
            ring[0] = point;
        }
    }
}

static bool EditLineNode(QgsGeometry &geometry, bool deleteNode, int32_t partIndex, int32_t pointIndex,
                         const QgsPointXY &target, std::string &message)
{
    if (geometry.isMultipart()) {
        QgsMultiPolylineXY lines = geometry.asMultiPolyline();
        if (partIndex < 0 || partIndex >= lines.size()) {
            message = "Invalid line part";
            return false;
        }
        QgsPolylineXY line = lines[partIndex];
        if (pointIndex < 0 || pointIndex >= line.size()) {
            message = "Invalid line node";
            return false;
        }
        if (deleteNode) {
            if (line.size() <= 2) {
                message = "Line must keep at least two nodes";
                return false;
            }
            line.removeAt(pointIndex);
        } else {
            line[pointIndex] = target;
        }
        lines[partIndex] = line;
        geometry = QgsGeometry::fromMultiPolylineXY(lines);
        return true;
    }

    if (partIndex != 0) {
        message = "Invalid line part";
        return false;
    }
    QgsPolylineXY line = geometry.asPolyline();
    if (pointIndex < 0 || pointIndex >= line.size()) {
        message = "Invalid line node";
        return false;
    }
    if (deleteNode) {
        if (line.size() <= 2) {
            message = "Line must keep at least two nodes";
            return false;
        }
        line.removeAt(pointIndex);
    } else {
        line[pointIndex] = target;
    }
    geometry = QgsGeometry::fromPolylineXY(line);
    return true;
}

static bool EditPolygonRing(QgsPolylineXY &ring, bool deleteNode, int32_t pointIndex,
                            const QgsPointXY &target, std::string &message)
{
    if (pointIndex < 0 || pointIndex >= ring.size()) {
        message = "Invalid polygon node";
        return false;
    }
    if (deleteNode) {
        if (ring.size() <= 4) {
            message = "Polygon ring must keep at least three nodes";
            return false;
        }
        if (pointIndex == 0 || pointIndex == ring.size() - 1) {
            message = "Cannot delete closing polygon node";
            return false;
        }
        ring.removeAt(pointIndex);
        if (!SamePoint(ring.first(), ring.last())) {
            ring.push_back(ring.first());
        }
    } else {
        SetRingPoint(ring, pointIndex, target);
    }
    return true;
}

static bool EditPolygonNode(QgsGeometry &geometry, bool deleteNode, int32_t partIndex, int32_t pointIndex,
                            const QgsPointXY &target, std::string &message)
{
    if (geometry.isMultipart()) {
        QgsMultiPolygonXY polygons = geometry.asMultiPolygon();
        int currentPart = 0;
        for (int pi = 0; pi < polygons.size(); pi++) {
            QgsPolygonXY polygon = polygons[pi];
            for (int ri = 0; ri < polygon.size(); ri++) {
                if (currentPart == partIndex) {
                    QgsPolylineXY ring = polygon[ri];
                    if (!EditPolygonRing(ring, deleteNode, pointIndex, target, message)) {
                        return false;
                    }
                    polygon[ri] = ring;
                    polygons[pi] = polygon;
                    geometry = QgsGeometry::fromMultiPolygonXY(polygons);
                    return true;
                }
                currentPart++;
            }
        }
        message = "Invalid polygon part";
        return false;
    }

    QgsPolygonXY polygon = geometry.asPolygon();
    if (partIndex < 0 || partIndex >= polygon.size()) {
        message = "Invalid polygon part";
        return false;
    }
    QgsPolylineXY ring = polygon[partIndex];
    if (!EditPolygonRing(ring, deleteNode, pointIndex, target, message)) {
        return false;
    }
    polygon[partIndex] = ring;
    geometry = QgsGeometry::fromPolygonXY(polygon);
    return true;
}

static bool EditGeometryNode(QgsGeometry &geometry, int32_t geometryType, bool deleteNode,
                             int32_t partIndex, int32_t pointIndex, double x, double y, std::string &message)
{
    QgsPointXY target(x, y);
    if (geometryType == GEOM_POINT) {
        if (deleteNode) {
            message = "Point feature has no removable node";
            return false;
        }
        if (partIndex != 0 || pointIndex != 0) {
            message = "Invalid point node";
            return false;
        }
        geometry = QgsGeometry::fromPointXY(target);
        return true;
    }
    if (geometryType == GEOM_LINESTRING) {
        return EditLineNode(geometry, deleteNode, partIndex, pointIndex, target, message);
    }
    if (geometryType == GEOM_POLYGON) {
        return EditPolygonNode(geometry, deleteNode, partIndex, pointIndex, target, message);
    }
    message = "Unsupported geometry type";
    return false;
}

} // namespace

const char *GetNativeVersion()
{
    return "GeoNest GIS Native Core 0.8.0";
}

const char *GetCoreProfile()
{
    return "QGIS Core backend (vector/raster/style/label/edit/expression/geometry/overlay/layout)";
}

const char *GetProcessingAlgorithms()
{
    static const char catalog[] =
        "{\"backend\":\"qgis-core\",\"algorithms\":["
        "{\"id\":\"buffer\",\"name\":\"Buffer\",\"category\":\"geometry\",\"inputCount\":1,"
        "\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"simplify\",\"name\":\"Simplify\",\"category\":\"geometry\",\"inputCount\":1,"
        "\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"dissolve\",\"name\":\"Dissolve\",\"category\":\"geometry\",\"inputCount\":1,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"centroid\",\"name\":\"Centroid\",\"category\":\"geometry\",\"inputCount\":1,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"convex_hull\",\"name\":\"Convex hull\",\"category\":\"geometry\",\"inputCount\":1,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"bounding_boxes\",\"name\":\"Bounding boxes\",\"category\":\"geometry\",\"inputCount\":1,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"oriented_minimum_bounding_box\",\"name\":\"Oriented minimum bounding box\","
        "\"category\":\"geometry\",\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"multipart_to_singleparts\",\"name\":\"Multipart to singleparts\","
        "\"category\":\"geometry\",\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"voronoi\",\"name\":\"Voronoi polygons\",\"category\":\"geometry\",\"inputCount\":1,"
        "\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"nearest_neighbor\",\"name\":\"Nearest neighbor links\",\"category\":\"analysis\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"repair\",\"name\":\"Repair geometries\",\"category\":\"quality\",\"inputCount\":1,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"extract_by_expression\",\"name\":\"Extract by expression\",\"category\":\"selection\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"extract_by_location\",\"name\":\"Extract by location\",\"category\":\"selection\","
        "\"inputCount\":2,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"clip\",\"name\":\"Clip\",\"category\":\"overlay\",\"inputCount\":2,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"intersection\",\"name\":\"Intersection with attributes\",\"category\":\"overlay\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"difference\",\"name\":\"Difference\",\"category\":\"overlay\",\"inputCount\":2,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"symmetrical_difference\",\"name\":\"Symmetrical difference\",\"category\":\"overlay\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"spatial_join_summary\",\"name\":\"Spatial join summary\",\"category\":\"overlay\","
        "\"inputCount\":2,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"multi_ring_buffer\",\"name\":\"Multi-ring buffer\",\"category\":\"overlay\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"merge_layers\",\"name\":\"Merge layers\",\"category\":\"data\",\"inputCount\":2,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"define_projection\",\"name\":\"Define projection\",\"category\":\"crs\",\"inputCount\":1,"
        "\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"project\",\"name\":\"Reproject layer\",\"category\":\"crs\",\"inputCount\":1,"
        "\"numericParameter\":false,\"textParameter\":true}"
        "]}";
    return DuplicateCString(catalog);
}

const char *DescribeCoordinateReferenceSystem(const char *definition, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!EnsureQgis()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_NATIVE_NOT_READY;
        }
        QgsCoordinateReferenceSystem invalidCrs;
        return DuplicateCString(BuildCrsSummaryJson(invalidCrs, definition, false, GIS_ERR_NATIVE_NOT_READY,
            "QGIS CRS database is not ready"));
    }

    QgsCoordinateReferenceSystem crs = CrsFromDefinition(definition);
    bool ok = crs.isValid();
    int32_t code = ok ? GIS_OK : GIS_ERR_INVALID_PARAM;
    if (outErrCode) {
        *outErrCode = code;
    }
    return DuplicateCString(BuildCrsSummaryJson(crs, definition, ok, code,
        ok ? "CRS parsed through QGIS" : "Invalid CRS definition"));
}

const char *TransformCoordinate(const char *sourceDefinition, const char *targetDefinition,
                                double x, double y, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!EnsureQgis()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_NATIVE_NOT_READY;
        }
        return DuplicateCString("{\"ok\":false,\"code\":5,\"message\":\"QGIS CRS database is not ready\","
            "\"x\":0,\"y\":0,\"sourceAuthId\":\"\",\"targetAuthId\":\"\"}");
    }

    QgsCoordinateReferenceSystem source = CrsFromDefinition(sourceDefinition);
    QgsCoordinateReferenceSystem target = CrsFromDefinition(targetDefinition);
    if (!source.isValid() || !target.isValid()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        std::string json = "{\"ok\":false,\"code\":";
        json += std::to_string(GIS_ERR_INVALID_PARAM);
        json += ",\"message\":\"Invalid source or target CRS\",\"x\":0,\"y\":0,\"sourceAuthId\":\"";
        json += EscapeJson(ToStdString(source.authid()));
        json += "\",\"targetAuthId\":\"";
        json += EscapeJson(ToStdString(target.authid()));
        json += "\"}";
        return DuplicateCString(json);
    }
    if (!QgsCoordinateTransform::isTransformationPossible(source, target)) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        std::string json = "{\"ok\":false,\"code\":";
        json += std::to_string(GIS_ERR_INVALID_PARAM);
        json += ",\"message\":\"CRS transformation is not possible\",\"x\":0,\"y\":0,\"sourceAuthId\":\"";
        json += EscapeJson(ToStdString(source.authid()));
        json += "\",\"targetAuthId\":\"";
        json += EscapeJson(ToStdString(target.authid()));
        json += "\"}";
        return DuplicateCString(json);
    }

    try {
        QgsCoordinateTransform transform(source, target, QgsProject::instance());
        QgsPointXY point = transform.transform(x, y);
        if (outErrCode) {
            *outErrCode = GIS_OK;
        }
        std::string json = "{\"ok\":true,\"code\":0,\"message\":\"Coordinate transformed through QGIS\",";
        json += "\"x\":";
        json += std::to_string(point.x());
        json += ",\"y\":";
        json += std::to_string(point.y());
        json += ",\"sourceAuthId\":\"";
        json += EscapeJson(ToStdString(source.authid()));
        json += "\",\"targetAuthId\":\"";
        json += EscapeJson(ToStdString(target.authid()));
        json += "\"}";
        return DuplicateCString(json);
    } catch (const QgsCsException &ex) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        std::string json = "{\"ok\":false,\"code\":";
        json += std::to_string(GIS_ERR_INVALID_PARAM);
        json += ",\"message\":\"";
        json += EscapeJson(ToStdString(ex.what()));
        json += "\",\"x\":0,\"y\":0,\"sourceAuthId\":\"";
        json += EscapeJson(ToStdString(source.authid()));
        json += "\",\"targetAuthId\":\"";
        json += EscapeJson(ToStdString(target.authid()));
        json += "\"}";
        return DuplicateCString(json);
    }
}

const char *TransformEnvelope(const char *sourceDefinition, const char *targetDefinition,
                              double minX, double minY, double maxX, double maxY,
                              int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!EnsureQgis()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_NATIVE_NOT_READY;
        }
        return DuplicateCString("{\"ok\":false,\"code\":5,\"message\":\"QGIS CRS database is not ready\","
            "\"envelope\":{\"minX\":0,\"minY\":0,\"maxX\":0,\"maxY\":0},\"sourceAuthId\":\"\","
            "\"targetAuthId\":\"\"}");
    }

    QgsCoordinateReferenceSystem source = CrsFromDefinition(sourceDefinition);
    QgsCoordinateReferenceSystem target = CrsFromDefinition(targetDefinition);
    if (!source.isValid() || !target.isValid()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        std::string json = "{\"ok\":false,\"code\":";
        json += std::to_string(GIS_ERR_INVALID_PARAM);
        json += ",\"message\":\"Invalid source or target CRS\",\"envelope\":";
        AppendEnvelope(json, QgsRectangle());
        json += ",\"sourceAuthId\":\"";
        json += EscapeJson(ToStdString(source.authid()));
        json += "\",\"targetAuthId\":\"";
        json += EscapeJson(ToStdString(target.authid()));
        json += "\"}";
        return DuplicateCString(json);
    }
    if (!QgsCoordinateTransform::isTransformationPossible(source, target)) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        std::string json = "{\"ok\":false,\"code\":";
        json += std::to_string(GIS_ERR_INVALID_PARAM);
        json += ",\"message\":\"CRS transformation is not possible\",\"envelope\":";
        AppendEnvelope(json, QgsRectangle());
        json += ",\"sourceAuthId\":\"";
        json += EscapeJson(ToStdString(source.authid()));
        json += "\",\"targetAuthId\":\"";
        json += EscapeJson(ToStdString(target.authid()));
        json += "\"}";
        return DuplicateCString(json);
    }

    try {
        QgsCoordinateTransform transform(source, target, QgsProject::instance());
        QgsRectangle rect(minX, minY, maxX, maxY);
        QgsRectangle transformed = transform.transformBoundingBox(rect);
        if (outErrCode) {
            *outErrCode = GIS_OK;
        }
        std::string json = "{\"ok\":true,\"code\":0,\"message\":\"Envelope transformed through QGIS\",";
        json += "\"envelope\":";
        AppendEnvelope(json, transformed);
        json += ",\"sourceAuthId\":\"";
        json += EscapeJson(ToStdString(source.authid()));
        json += "\",\"targetAuthId\":\"";
        json += EscapeJson(ToStdString(target.authid()));
        json += "\"}";
        return DuplicateCString(json);
    } catch (const QgsCsException &ex) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        std::string json = "{\"ok\":false,\"code\":";
        json += std::to_string(GIS_ERR_INVALID_PARAM);
        json += ",\"message\":\"";
        json += EscapeJson(ToStdString(ex.what()));
        json += "\",\"envelope\":";
        AppendEnvelope(json, QgsRectangle());
        json += ",\"sourceAuthId\":\"";
        json += EscapeJson(ToStdString(source.authid()));
        json += "\",\"targetAuthId\":\"";
        json += EscapeJson(ToStdString(target.authid()));
        json += "\"}";
        return DuplicateCString(json);
    }
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
    if (!EnsureQgis()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_NATIVE_NOT_READY;
        }
        return 0;
    }

    QString path = QString::fromUtf8(filePath);
    QFileInfo fileInfo(path);
    if (!fileInfo.exists()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_FILE_NOT_FOUND;
        }
        return 0;
    }

    std::unique_ptr<QgsVectorLayer> layer(new QgsVectorLayer(path, fileInfo.baseName(), "ogr"));
    if (!layer->isValid()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_FORMAT;
        }
        return 0;
    }

    LayerHandle handle = g_nextHandle++;
    std::string layerJson = BuildLayerJson(*layer, handle);
    std::unique_ptr<QgisLayerState> state(new QgisLayerState());
    state->handle = handle;
    state->filePath = filePath;
    state->layer = std::move(layer);
    g_layers[handle] = std::move(state);
    TrackLayerOrder(handle);

    if (outLayerInfo) {
        *outLayerInfo = DuplicateCString(layerJson);
    }
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return handle;
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
    if (!EnsureQgis()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_NATIVE_NOT_READY;
        }
        return 0;
    }

    QString path = QString::fromUtf8(filePath);
    QFileInfo fileInfo(path);
    if (!fileInfo.exists()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_FILE_NOT_FOUND;
        }
        return 0;
    }

    std::unique_ptr<QgsRasterLayer> layer(new QgsRasterLayer(path, fileInfo.baseName(), "gdal"));
    if (!layer->isValid()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_FORMAT;
        }
        return 0;
    }

    LayerHandle handle = g_nextHandle++;
    std::string layerJson = BuildRasterLayerJson(*layer, handle);
    std::unique_ptr<QgisRasterState> state(new QgisRasterState());
    state->handle = handle;
    state->filePath = filePath;
    state->layer = std::move(layer);
    g_rasterLayers[handle] = std::move(state);
    TrackLayerOrder(handle);

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
    std::map<LayerHandle, std::unique_ptr<QgisLayerState>>::iterator it = g_layers.find(handle);
    if (it != g_layers.end()) {
        g_layers.erase(it);
        RemoveLayerOrder(handle);
        return GIS_OK;
    }
    std::map<LayerHandle, std::unique_ptr<QgisRasterState>>::iterator rasterIt = g_rasterLayers.find(handle);
    if (rasterIt != g_rasterLayers.end()) {
        g_rasterLayers.erase(rasterIt);
        RemoveLayerOrder(handle);
        return GIS_OK;
    }
    return GIS_ERR_LAYER_NOT_FOUND;
}

const char *GetLayerInfo(LayerHandle handle, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (state && state->layer) {
        if (outErrCode) {
            *outErrCode = GIS_OK;
        }
        return DuplicateCString(BuildLayerJson(*state->layer, handle));
    }

    QgisRasterState *rasterState = FindRasterLayer(handle);
    if (rasterState && rasterState->layer) {
        if (outErrCode) {
            *outErrCode = GIS_OK;
        }
        return DuplicateCString(BuildRasterLayerJson(*rasterState->layer, handle));
    }

    if (outErrCode) {
        *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
    }
    return nullptr;
}

const char *QueryFeatures(LayerHandle handle, double minX, double minY, double maxX, double maxY,
                          int32_t limit, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return nullptr;
    }

    QgsFeatureRequest request;
    request.setFilterRect(QgsRectangle(minX, minY, maxX, maxY));
    if (limit > 0) {
        request.setLimit(static_cast<long long>(limit) + 1);
    }

    std::string json = "{\"layerId\":\"L";
    json += std::to_string(handle);
    json += "\",\"features\":[";

    QgsFeature feature;
    QgsFeatureIterator iterator = state->layer->getFeatures(request);
    bool first = true;
    bool hasMore = false;
    int32_t count = 0;
    while (iterator.nextFeature(feature)) {
        if (limit > 0 && count >= limit) {
            hasMore = true;
            break;
        }
        if (!first) {
            json += ",";
        }
        first = false;
        json += BuildFeatureJson(*state->layer, feature);
        count++;
    }

    json += "],\"hasMore\":";
    json += hasMore ? "true}" : "false}";
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(json);
}

const char *GetFeature(LayerHandle handle, int64_t fid, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return nullptr;
    }

    QgsFeatureRequest request;
    request.setFilterFid(static_cast<QgsFeatureId>(fid));
    QgsFeature feature;
    QgsFeatureIterator iterator = state->layer->getFeatures(request);
    if (iterator.nextFeature(feature)) {
        if (outErrCode) {
            *outErrCode = GIS_OK;
        }
        return DuplicateCString(BuildFeatureJson(*state->layer, feature));
    }

    if (outErrCode) {
        *outErrCode = GIS_ERR_FEATURE_NOT_FOUND;
    }
    return nullptr;
}

// ---------------------------------------------------------------------------
// Geoprocessing: BufferLayer (QGIS Core)
// Creates buffered polygons around each feature and writes to Shapefile.
// ---------------------------------------------------------------------------
const char *BufferLayer(LayerHandle handle, double distance, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (distance <= 0.0 || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid buffer parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsFields fields = sourceLayer->fields();
    QgsCoordinateReferenceSystem crs = sourceLayer->crs();
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("buffer_output");

    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");

    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        Qgis::WkbType::Polygon, crs, QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create buffer output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geom = feature.geometry();
        if (!geom.isNull() && !geom.isEmpty()) {
            QgsGeometry buffered = geom.buffer(distance, 16);
            if (!buffered.isNull()) {
                QgsFeature outFeature(fields);
                outFeature.setGeometry(buffered);
                for (int i = 0; i < fields.count(); i++) {
                    outFeature.setAttribute(i, feature.attribute(i));
                }
                if (writer->addFeature(outFeature)) {
                    writtenCount++;
                }
            }
        }
    }

    return MakeProcessResult(true, GIS_OK, "Buffer completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

// ---------------------------------------------------------------------------
// Geoprocessing: RepairLayer (QGIS Core)
// Validates and repairs geometries using QgsGeometry::makeValid().
// ---------------------------------------------------------------------------
const char *RepairLayer(LayerHandle handle, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid repair parameters",
            "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsFields fields = sourceLayer->fields();
    QgsCoordinateReferenceSystem crs = sourceLayer->crs();
    Qgis::WkbType geomType = sourceLayer->wkbType();
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("repair_output");

    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");

    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        geomType, crs, QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create repair output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geom = feature.geometry();
        if (!geom.isNull() && !geom.isEmpty()) {
            QgsGeometry repaired = geom.makeValid();
            if (repaired.isNull()) {
                repaired = geom;
            }
            QgsFeature outFeature(fields);
            outFeature.setGeometry(repaired);
            for (int i = 0; i < fields.count(); i++) {
                outFeature.setAttribute(i, feature.attribute(i));
            }
            if (writer->addFeature(outFeature)) {
                writtenCount++;
            }
        }
    }

    return MakeProcessResult(true, GIS_OK, "Repair completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

// ---------------------------------------------------------------------------
// Geoprocessing: ClipLayer (QGIS Core)
// Clips input features by the union of clip layer geometries.
// ---------------------------------------------------------------------------
static QgsGeometry BuildClipUnion(QgsVectorLayer *clipLayer)
{
    QgsGeometry unionGeom;
    QgsFeatureIterator iterator = clipLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geom = feature.geometry();
        if (!geom.isNull() && !geom.isEmpty()) {
            if (unionGeom.isNull()) {
                unionGeom = geom;
            } else {
                unionGeom = unionGeom.combine(geom);
            }
        }
    }
    return unionGeom;
}

const char *ClipLayer(LayerHandle inputHandle, LayerHandle clipHandle, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0 || inputHandle == clipHandle) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid clip parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *clipState = FindLayer(clipHandle);
    if (!inputState || !inputState->layer || !clipState || !clipState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input or clip layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsGeometry clipGeom = BuildClipUnion(clipState->layer.get());
    if (clipGeom.isNull() || clipGeom.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Clip layer has no geometry",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = inputState->layer.get();
    QgsFields fields = sourceLayer->fields();
    QgsCoordinateReferenceSystem crs = sourceLayer->crs();
    Qgis::WkbType geomType = sourceLayer->wkbType();
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("clip_output");

    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");

    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        geomType, crs, QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create clip output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geom = feature.geometry();
        if (!geom.isNull() && !geom.isEmpty() && geom.intersects(clipGeom)) {
            QgsGeometry clipped = geom.intersection(clipGeom);
            if (!clipped.isNull() && !clipped.isEmpty()) {
                QgsFeature outFeature(fields);
                outFeature.setGeometry(clipped);
                for (int i = 0; i < fields.count(); i++) {
                    outFeature.setAttribute(i, feature.attribute(i));
                }
                if (writer->addFeature(outFeature)) {
                    writtenCount++;
                }
            }
        }
    }

    return MakeProcessResult(true, GIS_OK, "Clip completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

// ---------------------------------------------------------------------------
// ExportLayer (QGIS Core)
// Writes a loaded vector layer to Shapefile without changing geometry.
// ---------------------------------------------------------------------------
const char *ExportLayer(LayerHandle handle, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid export parameters",
            "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsFields fields = sourceLayer->fields();
    QgsCoordinateReferenceSystem crs = sourceLayer->crs();
    Qgis::WkbType geomType = sourceLayer->wkbType();
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("export_output");

    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");

    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        geomType, crs, QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create export output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsFeature outFeature(fields);
        outFeature.setGeometry(feature.geometry());
        for (int i = 0; i < fields.count(); i++) {
            outFeature.setAttribute(i, feature.attribute(i));
        }
        if (writer->addFeature(outFeature)) {
            writtenCount++;
        }
    }

    return MakeProcessResult(true, GIS_OK, "Export completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

// ---------------------------------------------------------------------------
// DefineLayerProjection (QGIS Core)
// Writes a loaded vector layer to Shapefile with a new CRS only. Coordinates
// are intentionally unchanged, matching ArcGIS Define Projection semantics.
// ---------------------------------------------------------------------------
const char *DefineLayerProjection(LayerHandle handle, const char *targetDefinition,
                                  const char *outputPath, const char *outputLayerName,
                                  int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0 || !targetDefinition ||
        std::strlen(targetDefinition) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid define projection parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsCoordinateReferenceSystem targetCrs = CrsFromDefinition(targetDefinition);
    if (!targetCrs.isValid()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid target CRS definition",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsFields fields = sourceLayer->fields();
    Qgis::WkbType geomType = sourceLayer->wkbType();
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("defined_projection_output");

    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");

    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        geomType, targetCrs, QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create defined projection output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsFeature outFeature(fields);
        outFeature.setGeometry(feature.geometry());
        for (int i = 0; i < fields.count(); i++) {
            outFeature.setAttribute(i, feature.attribute(i));
        }
        if (writer->addFeature(outFeature)) {
            writtenCount++;
        }
    }

    return MakeProcessResult(true, GIS_OK, "Projection defined", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

// ---------------------------------------------------------------------------
// ProjectLayer (QGIS Core)
// Transforms every geometry from the layer CRS into the target CRS.
// ---------------------------------------------------------------------------
const char *ProjectLayer(LayerHandle handle, const char *targetDefinition,
                         const char *outputPath, const char *outputLayerName,
                         int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0 || !targetDefinition ||
        std::strlen(targetDefinition) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid project parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsCoordinateReferenceSystem sourceCrs = sourceLayer->crs();
    QgsCoordinateReferenceSystem targetCrs = CrsFromDefinition(targetDefinition);
    if (!sourceCrs.isValid() || !targetCrs.isValid()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid source or target CRS",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    if (!QgsCoordinateTransform::isTransformationPossible(sourceCrs, targetCrs)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "CRS transformation is not possible",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields fields = sourceLayer->fields();
    Qgis::WkbType geomType = sourceLayer->wkbType();
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("project_output");

    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");

    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        geomType, targetCrs, QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create projected output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    try {
        QgsCoordinateTransform transform(sourceCrs, targetCrs, QgsProject::instance());
        int32_t writtenCount = 0;
        QgsFeatureIterator iterator = sourceLayer->getFeatures();
        QgsFeature feature;
        while (iterator.nextFeature(feature)) {
            QgsFeature outFeature(fields);
            QgsGeometry transformed = feature.geometry();
            if (!transformed.isNull() && !transformed.isEmpty()) {
                Qgis::GeometryOperationResult transformResult = transformed.transform(transform);
                if (transformResult != Qgis::GeometryOperationResult::Success) {
                    std::string message = "Failed to transform feature ";
                    message += std::to_string(static_cast<long long>(feature.id()));
                    return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, message,
                        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
                }
            }
            outFeature.setGeometry(transformed);
            for (int i = 0; i < fields.count(); i++) {
                outFeature.setAttribute(i, feature.attribute(i));
            }
            if (writer->addFeature(outFeature)) {
                writtenCount++;
            }
        }

        return MakeProcessResult(true, GIS_OK, "Projection completed", outputPath,
            outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
    } catch (const QgsCsException &ex) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, ToStdString(ex.what()),
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
}

const char *SimplifyLayer(LayerHandle handle, double tolerance, const char *outputPath,
                          const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (tolerance <= 0.0 || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid simplify parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsFields fields = sourceLayer->fields();
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("simplified_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        sourceLayer->wkbType(), sourceLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create simplified output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        QgsGeometry simplified = geometry.simplify(tolerance);
        if (simplified.isNull() || simplified.isEmpty()) {
            continue;
        }
        QgsFeature outFeature(fields);
        outFeature.setAttributes(feature.attributes());
        outFeature.setGeometry(simplified);
        if (writer->addFeature(outFeature)) {
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Simplify completed through QgsGeometry",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *DissolveLayer(LayerHandle handle, const char *outputPath,
                          const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid dissolve parameters",
            "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QVector<QgsGeometry> geometries;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (!geometry.isNull() && !geometry.isEmpty()) {
            geometries.push_back(geometry);
        }
    }
    if (geometries.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Input layer has no geometry",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsGeometry dissolved = QgsGeometry::unaryUnion(geometries);
    if (sourceLayer->geometryType() == Qgis::GeometryType::Line && !dissolved.isNull()) {
        QgsGeometry mergedLines = dissolved.mergeLines();
        if (!mergedLines.isNull() && !mergedLines.isEmpty()) {
            dissolved = mergedLines;
        }
    }
    if (dissolved.isNull() || dissolved.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "QGIS dissolve failed",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields fields;
    fields.append(QgsField(QStringLiteral("source_cnt"), QVariant::LongLong));
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("dissolved_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    Qgis::WkbType outputType = QgsWkbTypes::multiType(sourceLayer->wkbType());
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        outputType, sourceLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create dissolved output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsFeature outFeature(fields);
    outFeature.setGeometry(dissolved);
    outFeature.setAttribute(0, static_cast<qlonglong>(geometries.size()));
    if (!writer->addFeature(outFeature)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to write dissolved feature",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Dissolve completed through QgsGeometry unaryUnion",
        outputPath, outputLayerName ? outputLayerName : "", 1, outErrCode);
}

const char *CentroidLayer(LayerHandle handle, const char *outputPath,
                          const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid centroid parameters",
            "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsFields fields = sourceLayer->fields();
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("centroid_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        Qgis::WkbType::Point, sourceLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create centroid output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        QgsGeometry centroid = geometry.centroid();
        if (centroid.isNull() || centroid.isEmpty()) {
            continue;
        }
        QgsFeature outFeature(fields);
        outFeature.setAttributes(feature.attributes());
        outFeature.setGeometry(centroid);
        if (writer->addFeature(outFeature)) {
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Centroid completed through QgsGeometry",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *ConvexHullLayer(LayerHandle handle, const char *outputPath,
                            const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid convex hull parameters",
            "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QVector<QgsGeometry> geometries;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (!geometry.isNull() && !geometry.isEmpty()) {
            geometries.push_back(geometry);
        }
    }
    if (geometries.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Input layer has no geometry",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsGeometry merged = QgsGeometry::unaryUnion(geometries);
    QgsGeometry hull = merged.convexHull();
    if (hull.isNull() || hull.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "QGIS convex hull failed",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields fields;
    fields.append(QgsField(QStringLiteral("source_cnt"), QVariant::LongLong));
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("convex_hull_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        hull.wkbType(), sourceLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create convex hull output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFeature outFeature(fields);
    outFeature.setGeometry(hull);
    outFeature.setAttribute(0, static_cast<qlonglong>(geometries.size()));
    if (!writer->addFeature(outFeature)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to write convex hull",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Convex hull completed through QgsGeometry",
        outputPath, outputLayerName ? outputLayerName : "", 1, outErrCode);
}

const char *BoundingBoxLayer(LayerHandle handle, const char *outputPath,
                             const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid bounding box parameters",
            "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsFields fields = sourceLayer->fields();
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("bounding_boxes_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        Qgis::WkbType::Polygon, sourceLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create bounding box output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        QgsRectangle bounds = geometry.boundingBox();
        if (bounds.isEmpty()) {
            continue;
        }
        QgsFeature outFeature(fields);
        outFeature.setAttributes(feature.attributes());
        outFeature.setGeometry(QgsGeometry::fromRect(bounds));
        if (writer->addFeature(outFeature)) {
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Bounding boxes completed through QgsGeometry",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *MultipartToSinglepartsLayer(LayerHandle handle, const char *outputPath,
                                        const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid singleparts parameters",
            "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsFields fields = sourceLayer->fields();
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("singleparts_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    Qgis::WkbType outputType = QgsWkbTypes::singleType(sourceLayer->wkbType());
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        outputType, sourceLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create singleparts output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        QVector<QgsGeometry> parts;
        if (geometry.isMultipart()) {
            parts = geometry.asGeometryCollection();
        } else {
            parts.push_back(geometry);
        }
        for (int i = 0; i < parts.size(); i++) {
            QgsGeometry part = parts.at(i);
            if (part.isNull() || part.isEmpty()) {
                continue;
            }
            QgsFeature outFeature(fields);
            outFeature.setAttributes(feature.attributes());
            outFeature.setGeometry(part);
            if (writer->addFeature(outFeature)) {
                writtenCount++;
            }
        }
    }
    return MakeProcessResult(true, GIS_OK, "Multipart to singleparts completed through QgsGeometry",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *ExtractByExpressionLayer(LayerHandle handle, const char *expressionText,
                                     const char *outputPath, const char *outputLayerName,
                                     int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!expressionText || std::strlen(expressionText) == 0 ||
        !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid expression extraction parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QString expressionSource = QString::fromUtf8(expressionText).trimmed();
    QgsExpression expression(expressionSource);
    if (expressionSource.isEmpty() || expression.hasParserError()) {
        std::string message = expressionSource.isEmpty()
            ? "QGIS expression is empty" : ToStdString(expression.parserErrorString());
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, message,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsExpressionContext expressionContext;
    expressionContext.setFields(sourceLayer->fields());
    if (!expression.prepare(&expressionContext)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "QGIS expression preparation failed",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields fields = sourceLayer->fields();
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("expression_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        sourceLayer->wkbType(), sourceLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create expression output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        expressionContext.setFeature(feature);
        QVariant evaluated = expression.evaluate(&expressionContext);
        if (expression.hasEvalError()) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, ToStdString(expression.evalErrorString()),
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        if (!evaluated.toBool()) {
            continue;
        }
        QgsFeature outFeature(fields);
        outFeature.setAttributes(feature.attributes());
        outFeature.setGeometry(feature.geometry());
        if (writer->addFeature(outFeature)) {
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Expression extraction completed through QgsExpression",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static bool BuildLayerUnionInCrs(QgsVectorLayer *layer, const QgsCoordinateReferenceSystem &targetCrs,
                                 QgsGeometry &unionGeometry, int32_t &featureCount, std::string &message)
{
    if (!layer) {
        message = "Overlay layer is missing";
        return false;
    }
    QgsCoordinateReferenceSystem sourceCrs = layer->crs();
    bool transformNeeded = sourceCrs.isValid() && targetCrs.isValid() && sourceCrs != targetCrs;
    if (transformNeeded && !QgsCoordinateTransform::isTransformationPossible(sourceCrs, targetCrs)) {
        message = "Overlay CRS cannot be transformed to the input CRS";
        return false;
    }

    QgsCoordinateTransform transform;
    if (transformNeeded) {
        transform = QgsCoordinateTransform(sourceCrs, targetCrs, QgsProject::instance());
    }
    QVector<QgsGeometry> geometries;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        if (transformNeeded) {
            try {
                Qgis::GeometryOperationResult transformResult = geometry.transform(transform);
                if (transformResult != Qgis::GeometryOperationResult::Success) {
                    message = "Failed to transform overlay geometry";
                    return false;
                }
            } catch (const QgsCsException &ex) {
                message = ToStdString(ex.what());
                return false;
            }
        }
        geometries.push_back(geometry);
    }
    featureCount = static_cast<int32_t>(geometries.size());
    if (geometries.isEmpty()) {
        message = "Layer has no geometry";
        return false;
    }
    unionGeometry = QgsGeometry::unaryUnion(geometries);
    if (unionGeometry.isNull() || unionGeometry.isEmpty()) {
        message = "QGIS geometry union failed";
        return false;
    }
    return true;
}

const char *DifferenceLayer(LayerHandle inputHandle, LayerHandle overlayHandle,
                            const char *outputPath, const char *outputLayerName,
                            int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0 || inputHandle == overlayHandle) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid difference parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *overlayState = FindLayer(overlayHandle);
    if (!inputState || !inputState->layer || !overlayState || !overlayState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input or overlay layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = inputState->layer.get();
    QgsGeometry overlayUnion;
    int32_t overlayCount = 0;
    std::string unionMessage;
    if (!BuildLayerUnionInCrs(overlayState->layer.get(), sourceLayer->crs(), overlayUnion,
        overlayCount, unionMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, unionMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields fields = sourceLayer->fields();
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("difference_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        sourceLayer->wkbType(), sourceLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create difference output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        QgsGeometry difference = geometry;
        if (geometry.intersects(overlayUnion)) {
            difference = geometry.difference(overlayUnion);
        }
        if (difference.isNull() || difference.isEmpty()) {
            continue;
        }
        QgsFeature outFeature(fields);
        outFeature.setAttributes(feature.attributes());
        outFeature.setGeometry(difference);
        if (writer->addFeature(outFeature)) {
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Difference completed through QgsGeometry",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *SymmetricalDifferenceLayer(LayerHandle inputHandle, LayerHandle overlayHandle,
                                       const char *outputPath, const char *outputLayerName,
                                       int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0 || inputHandle == overlayHandle) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid symmetrical difference parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *overlayState = FindLayer(overlayHandle);
    if (!inputState || !inputState->layer || !overlayState || !overlayState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input or overlay layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *inputLayer = inputState->layer.get();
    QgsGeometry inputUnion;
    QgsGeometry overlayUnion;
    int32_t inputCount = 0;
    int32_t overlayCount = 0;
    std::string unionMessage;
    if (!BuildLayerUnionInCrs(inputLayer, inputLayer->crs(), inputUnion, inputCount, unionMessage) ||
        !BuildLayerUnionInCrs(overlayState->layer.get(), inputLayer->crs(), overlayUnion,
            overlayCount, unionMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, unionMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsGeometry resultGeometry = inputUnion.symDifference(overlayUnion);
    if (resultGeometry.isNull() || resultGeometry.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Symmetrical difference produced no geometry",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields fields;
    fields.append(QgsField(QStringLiteral("input_cnt"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("over_cnt"), QVariant::LongLong));
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("sym_difference_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        resultGeometry.wkbType(), inputLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
            "Failed to create symmetrical difference output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFeature outFeature(fields);
    outFeature.setGeometry(resultGeometry);
    outFeature.setAttribute(0, static_cast<qlonglong>(inputCount));
    outFeature.setAttribute(1, static_cast<qlonglong>(overlayCount));
    if (!writer->addFeature(outFeature)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
            "Failed to write symmetrical difference feature",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Symmetrical difference completed through QgsGeometry",
        outputPath, outputLayerName ? outputLayerName : "", 1, outErrCode);
}

struct FeatureGeometryRecord {
    QgsFeatureId id = -1;
    QgsGeometry geometry;
};

static bool TransformGeometryToCrs(QgsGeometry &geometry,
                                   const QgsCoordinateReferenceSystem &sourceCrs,
                                   const QgsCoordinateReferenceSystem &targetCrs,
                                   std::string &message)
{
    if (!sourceCrs.isValid() || !targetCrs.isValid() || sourceCrs == targetCrs) {
        return true;
    }
    if (!QgsCoordinateTransform::isTransformationPossible(sourceCrs, targetCrs)) {
        message = "Layer CRS cannot be transformed to the output CRS";
        return false;
    }
    try {
        QgsCoordinateTransform transform(sourceCrs, targetCrs, QgsProject::instance());
        Qgis::GeometryOperationResult result = geometry.transform(transform);
        if (result != Qgis::GeometryOperationResult::Success) {
            message = "Failed to transform feature geometry";
            return false;
        }
    } catch (const QgsCsException &ex) {
        message = ToStdString(ex.what());
        return false;
    }
    return true;
}

static bool LoadFeatureGeometries(QgsVectorLayer *layer,
                                  const QgsCoordinateReferenceSystem &targetCrs,
                                  std::vector<FeatureGeometryRecord> &records,
                                  std::string &message)
{
    if (!layer) {
        message = "Layer is missing";
        return false;
    }
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        if (!TransformGeometryToCrs(geometry, layer->crs(), targetCrs, message)) {
            return false;
        }
        FeatureGeometryRecord record;
        record.id = feature.id();
        record.geometry = geometry;
        records.push_back(record);
    }
    if (records.empty()) {
        message = "Layer has no geometry";
        return false;
    }
    return true;
}

static bool SpatialPredicateMatches(const QgsGeometry &input, const QgsGeometry &overlay, int32_t mode)
{
    if (mode == 1) {
        return input.contains(overlay);
    }
    if (mode == 2) {
        return input.within(overlay);
    }
    if (mode == 3) {
        return input.touches(overlay);
    }
    if (mode == 4) {
        return input.overlaps(overlay);
    }
    if (mode == 5) {
        return input.crosses(overlay);
    }
    if (mode == 6) {
        return !input.intersects(overlay);
    }
    return input.intersects(overlay);
}

static int AppendUniqueField(QgsFields &fields, const QgsField &sourceField, const QString &prefix)
{
    QgsField field = sourceField;
    QString baseName = prefix + sourceField.name();
    if (baseName.length() > 9) {
        baseName = baseName.left(9);
    }
    QString fieldName = baseName;
    int suffix = 1;
    while (fields.indexOf(fieldName) >= 0) {
        QString suffixText = QString::number(suffix);
        int prefixLength = std::max(1, 10 - static_cast<int>(suffixText.length()));
        fieldName = baseName.left(prefixLength) + suffixText;
        suffix++;
    }
    field.setName(fieldName);
    fields.append(field);
    return fields.count() - 1;
}

const char *MergeLayers(LayerHandle firstHandle, LayerHandle secondHandle,
                        const char *outputPath, const char *outputLayerName,
                        int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0 || firstHandle == secondHandle) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid merge layer parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *firstState = FindLayer(firstHandle);
    QgisLayerState *secondState = FindLayer(secondHandle);
    if (!firstState || !firstState->layer || !secondState || !secondState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Merge layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *firstLayer = firstState->layer.get();
    QgsVectorLayer *secondLayer = secondState->layer.get();
    if (firstLayer->geometryType() != secondLayer->geometryType()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Merge layers have different geometry types",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields fields = firstLayer->fields();
    QgsFields secondFields = secondLayer->fields();
    std::vector<int> secondOutputFields;
    for (int i = 0; i < secondFields.count(); i++) {
        int outputIndex = fields.indexOf(secondFields.at(i).name());
        if (outputIndex < 0) {
            outputIndex = AppendUniqueField(fields, secondFields.at(i), QString());
        }
        secondOutputFields.push_back(outputIndex);
    }
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("merged_layers_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        firstLayer->wkbType(), firstLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create merged layer output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsVectorLayer *layers[] = { firstLayer, secondLayer };
    for (int layerIndex = 0; layerIndex < 2; layerIndex++) {
        QgsVectorLayer *sourceLayer = layers[layerIndex];
        QgsFeatureIterator iterator = sourceLayer->getFeatures();
        QgsFeature feature;
        while (iterator.nextFeature(feature)) {
            QgsGeometry geometry = feature.geometry();
            std::string transformMessage;
            if (!TransformGeometryToCrs(geometry, sourceLayer->crs(), firstLayer->crs(), transformMessage)) {
                return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, transformMessage,
                    outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
            }
            QgsFeature outFeature(fields);
            outFeature.setGeometry(geometry);
            QgsFields sourceFields = sourceLayer->fields();
            if (layerIndex == 0) {
                for (int i = 0; i < sourceFields.count(); i++) {
                    int outputIndex = fields.indexOf(sourceFields.at(i).name());
                    if (outputIndex >= 0) {
                        outFeature.setAttribute(outputIndex, feature.attribute(i));
                    }
                }
            } else {
                for (int i = 0; i < sourceFields.count() &&
                    i < static_cast<int>(secondOutputFields.size()); i++) {
                    outFeature.setAttribute(secondOutputFields[static_cast<size_t>(i)], feature.attribute(i));
                }
            }
            if (writer->addFeature(outFeature)) {
                writtenCount++;
            }
        }
    }
    return MakeProcessResult(true, GIS_OK, "Layers merged through QGIS vector writer",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *MultiRingBufferLayer(LayerHandle handle, const char *distanceList,
                                 const char *outputPath, const char *outputLayerName,
                                 int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!distanceList || std::strlen(distanceList) == 0 ||
        !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid multi-ring buffer parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::vector<double> distances;
    QStringList distanceParts = QString::fromUtf8(distanceList).split(',', Qt::SkipEmptyParts);
    for (int i = 0; i < distanceParts.size(); i++) {
        bool ok = false;
        double distance = distanceParts.at(i).trimmed().toDouble(&ok);
        if (ok && distance > 0.0) {
            distances.push_back(distance);
        }
    }
    std::sort(distances.begin(), distances.end());
    distances.erase(std::unique(distances.begin(), distances.end()), distances.end());
    if (distances.empty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "No valid buffer distance was supplied",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsFields fields = sourceLayer->fields();
    int distanceField = AppendUniqueField(fields,
        QgsField(QStringLiteral("ring_dist"), QVariant::Double), QString());
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("multi_ring_buffer_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        Qgis::WkbType::MultiPolygon, sourceLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create multi-ring buffer output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        QgsGeometry previousBuffer;
        for (size_t i = 0; i < distances.size(); i++) {
            QgsGeometry currentBuffer = geometry.buffer(distances[i], 16);
            if (currentBuffer.isNull() || currentBuffer.isEmpty()) {
                continue;
            }
            QgsGeometry ring = currentBuffer;
            if (!previousBuffer.isNull() && !previousBuffer.isEmpty()) {
                ring = currentBuffer.difference(previousBuffer);
            }
            previousBuffer = currentBuffer;
            if (ring.isNull() || ring.isEmpty()) {
                continue;
            }
            QgsFeature outFeature(fields);
            for (int fieldIndex = 0; fieldIndex < sourceLayer->fields().count(); fieldIndex++) {
                outFeature.setAttribute(fieldIndex, feature.attribute(fieldIndex));
            }
            outFeature.setAttribute(distanceField, distances[i]);
            outFeature.setGeometry(ring);
            if (writer->addFeature(outFeature)) {
                writtenCount++;
            }
        }
    }
    return MakeProcessResult(true, GIS_OK, "Multi-ring buffer completed through QgsGeometry",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *ExtractByLocationLayer(LayerHandle inputHandle, LayerHandle overlayHandle,
                                   int32_t predicateMode, const char *outputPath,
                                   const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0 || inputHandle == overlayHandle) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid location extraction parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *overlayState = FindLayer(overlayHandle);
    if (!inputState || !inputState->layer || !overlayState || !overlayState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input or overlay layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *inputLayer = inputState->layer.get();
    std::vector<FeatureGeometryRecord> overlays;
    std::string loadMessage;
    if (!LoadFeatureGeometries(overlayState->layer.get(), inputLayer->crs(), overlays, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields fields = inputLayer->fields();
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("location_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        inputLayer->wkbType(), inputLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create location output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = inputLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        bool matches = predicateMode == 6;
        for (size_t i = 0; i < overlays.size(); i++) {
            bool current = SpatialPredicateMatches(geometry, overlays[i].geometry, predicateMode);
            if (predicateMode == 6) {
                if (!current) {
                    matches = false;
                    break;
                }
            } else if (current) {
                matches = true;
                break;
            }
        }
        if (!matches) {
            continue;
        }
        QgsFeature outFeature(fields);
        outFeature.setAttributes(feature.attributes());
        outFeature.setGeometry(geometry);
        if (writer->addFeature(outFeature)) {
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Location extraction completed through QGIS predicates",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *SpatialJoinSummaryLayer(LayerHandle inputHandle, LayerHandle joinHandle,
                                    int32_t predicateMode, const char *outputPath,
                                    const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0 || inputHandle == joinHandle) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid spatial join parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *joinState = FindLayer(joinHandle);
    if (!inputState || !inputState->layer || !joinState || !joinState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input or join layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *inputLayer = inputState->layer.get();
    std::vector<FeatureGeometryRecord> joins;
    std::string loadMessage;
    if (!LoadFeatureGeometries(joinState->layer.get(), inputLayer->crs(), joins, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields fields = inputLayer->fields();
    int countField = AppendUniqueField(fields,
        QgsField(QStringLiteral("join_cnt"), QVariant::LongLong), QString());
    int fidField = AppendUniqueField(fields,
        QgsField(QStringLiteral("join_fid"), QVariant::LongLong), QString());
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("spatial_join_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        inputLayer->wkbType(), inputLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create spatial join output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = inputLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        int64_t firstJoinId = -1;
        int64_t matchCount = 0;
        for (size_t i = 0; i < joins.size(); i++) {
            if (SpatialPredicateMatches(geometry, joins[i].geometry, predicateMode)) {
                if (firstJoinId < 0) {
                    firstJoinId = static_cast<int64_t>(joins[i].id);
                }
                matchCount++;
            }
        }
        QgsFeature outFeature(fields);
        for (int fieldIndex = 0; fieldIndex < inputLayer->fields().count(); fieldIndex++) {
            outFeature.setAttribute(fieldIndex, feature.attribute(fieldIndex));
        }
        outFeature.setAttribute(countField, static_cast<qlonglong>(matchCount));
        outFeature.setAttribute(fidField, static_cast<qlonglong>(firstJoinId));
        outFeature.setGeometry(geometry);
        if (writer->addFeature(outFeature)) {
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Spatial join summary completed through QGIS predicates",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *IntersectionLayer(LayerHandle inputHandle, LayerHandle overlayHandle,
                              const char *outputPath, const char *outputLayerName,
                              int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0 || inputHandle == overlayHandle) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid intersection parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *overlayState = FindLayer(overlayHandle);
    if (!inputState || !inputState->layer || !overlayState || !overlayState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input or overlay layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *inputLayer = inputState->layer.get();
    QgsVectorLayer *overlayLayer = overlayState->layer.get();
    QgsFields fields;
    QgsFields inputFields = inputLayer->fields();
    QgsFields overlayFields = overlayLayer->fields();
    for (int i = 0; i < inputFields.count(); i++) {
        AppendUniqueField(fields, inputFields.at(i), QStringLiteral("a_"));
    }
    for (int i = 0; i < overlayFields.count(); i++) {
        AppendUniqueField(fields, overlayFields.at(i), QStringLiteral("b_"));
    }

    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("intersection_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        inputLayer->wkbType(), inputLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create intersection output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator inputIterator = inputLayer->getFeatures();
    QgsFeature inputFeature;
    while (inputIterator.nextFeature(inputFeature)) {
        QgsGeometry inputGeometry = inputFeature.geometry();
        if (inputGeometry.isNull() || inputGeometry.isEmpty()) {
            continue;
        }
        QgsFeatureRequest overlayRequest;
        QgsFeatureIterator overlayIterator = overlayLayer->getFeatures(overlayRequest);
        QgsFeature overlayFeature;
        while (overlayIterator.nextFeature(overlayFeature)) {
            QgsGeometry overlayGeometry = overlayFeature.geometry();
            if (overlayGeometry.isNull() || overlayGeometry.isEmpty()) {
                continue;
            }
            std::string transformMessage;
            if (!TransformGeometryToCrs(overlayGeometry, overlayLayer->crs(), inputLayer->crs(),
                transformMessage)) {
                return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, transformMessage,
                    outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
            }
            if (!inputGeometry.intersects(overlayGeometry)) {
                continue;
            }
            QgsGeometry resultGeometry = inputGeometry.intersection(overlayGeometry);
            if (resultGeometry.isNull() || resultGeometry.isEmpty() ||
                QgsWkbTypes::geometryType(resultGeometry.wkbType()) != inputLayer->geometryType()) {
                continue;
            }
            QgsFeature outFeature(fields);
            int outputField = 0;
            for (int i = 0; i < inputFields.count(); i++) {
                outFeature.setAttribute(outputField, inputFeature.attribute(i));
                outputField++;
            }
            for (int i = 0; i < overlayFields.count(); i++) {
                outFeature.setAttribute(outputField, overlayFeature.attribute(i));
                outputField++;
            }
            outFeature.setGeometry(resultGeometry);
            if (writer->addFeature(outFeature)) {
                writtenCount++;
            }
        }
    }
    return MakeProcessResult(true, GIS_OK, "Intersection completed with attributes from both layers",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *NearestNeighborLayer(LayerHandle inputHandle, LayerHandle targetHandle,
                                 const char *outputPath, const char *outputLayerName,
                                 int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid nearest neighbor parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *targetState = FindLayer(targetHandle);
    if (!inputState || !inputState->layer || !targetState || !targetState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input or target layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *inputLayer = inputState->layer.get();
    std::vector<FeatureGeometryRecord> targets;
    std::string loadMessage;
    if (!LoadFeatureGeometries(targetState->layer.get(), inputLayer->crs(), targets, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields fields;
    fields.append(QgsField(QStringLiteral("source_fid"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("target_fid"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("distance"), QVariant::Double));
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("nearest_neighbor_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        Qgis::WkbType::LineString, inputLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create nearest neighbor output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = inputLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        double bestDistance = -1.0;
        QgsFeatureId bestTargetId = -1;
        QgsGeometry bestTargetGeometry;
        for (size_t i = 0; i < targets.size(); i++) {
            if (inputHandle == targetHandle && feature.id() == targets[i].id) {
                continue;
            }
            double distance = geometry.distance(targets[i].geometry);
            if (distance >= 0.0 && (bestDistance < 0.0 || distance < bestDistance)) {
                bestDistance = distance;
                bestTargetId = targets[i].id;
                bestTargetGeometry = targets[i].geometry;
            }
        }
        if (bestTargetId < 0) {
            continue;
        }
        QgsGeometry link = geometry.shortestLine(bestTargetGeometry);
        if (link.isNull() || link.isEmpty()) {
            QgsPointXY sourcePoint = geometry.centroid().asPoint();
            QgsPointXY targetPoint = bestTargetGeometry.centroid().asPoint();
            QgsPolylineXY line;
            line.push_back(sourcePoint);
            line.push_back(targetPoint);
            link = QgsGeometry::fromPolylineXY(line);
        }
        QgsFeature outFeature(fields);
        outFeature.setAttribute(0, static_cast<qlonglong>(feature.id()));
        outFeature.setAttribute(1, static_cast<qlonglong>(bestTargetId));
        outFeature.setAttribute(2, bestDistance);
        outFeature.setGeometry(link);
        if (writer->addFeature(outFeature)) {
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Nearest neighbor links completed through QgsGeometry",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *VoronoiLayer(LayerHandle handle, double tolerance, const char *outputPath,
                         const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0 || tolerance < 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid Voronoi parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsMultiPointXY points;
    std::vector<FeatureGeometryRecord> sources;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        QgsGeometry pointGeometry = geometry.centroid();
        if (pointGeometry.isNull() || pointGeometry.isEmpty()) {
            continue;
        }
        QgsPointXY point = pointGeometry.asPoint();
        points.push_back(point);
        FeatureGeometryRecord record;
        record.id = feature.id();
        record.geometry = pointGeometry;
        sources.push_back(record);
    }
    if (points.size() < 2) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Voronoi requires at least two features",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsRectangle extent = sourceLayer->extent();
    double margin = std::max(extent.width(), extent.height()) * 0.1;
    if (margin <= 0.0) {
        margin = 1.0;
    }
    extent.grow(margin);
    QgsGeometry diagram = QgsGeometry::fromMultiPointXY(points).voronoiDiagram(
        QgsGeometry::fromRect(extent), tolerance, false);
    if (diagram.isNull() || diagram.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "QGIS Voronoi generation failed",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields fields;
    fields.append(QgsField(QStringLiteral("source_fid"), QVariant::LongLong));
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("voronoi_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        Qgis::WkbType::Polygon, sourceLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create Voronoi output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QVector<QgsGeometry> cells = diagram.asGeometryCollection();
    if (cells.isEmpty()) {
        cells.push_back(diagram);
    }
    int32_t writtenCount = 0;
    for (int cellIndex = 0; cellIndex < cells.size(); cellIndex++) {
        QgsGeometry cell = cells.at(cellIndex);
        if (cell.isNull() || cell.isEmpty()) {
            continue;
        }
        QgsGeometry center = cell.centroid();
        double bestDistance = -1.0;
        QgsFeatureId bestSourceId = -1;
        for (size_t i = 0; i < sources.size(); i++) {
            double distance = center.distance(sources[i].geometry);
            if (distance >= 0.0 && (bestDistance < 0.0 || distance < bestDistance)) {
                bestDistance = distance;
                bestSourceId = sources[i].id;
            }
        }
        QgsFeature outFeature(fields);
        outFeature.setAttribute(0, static_cast<qlonglong>(bestSourceId));
        outFeature.setGeometry(cell);
        if (writer->addFeature(outFeature)) {
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Voronoi polygons completed through QgsGeometry",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *OrientedMinimumBoundingBoxLayer(LayerHandle handle, const char *outputPath,
                                            const char *outputLayerName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid minimum bounding box parameters",
            "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsFields fields = sourceLayer->fields();
    int areaField = AppendUniqueField(fields, QgsField(QStringLiteral("mbg_area"), QVariant::Double), QString());
    int angleField = AppendUniqueField(fields, QgsField(QStringLiteral("mbg_angle"), QVariant::Double), QString());
    int widthField = AppendUniqueField(fields, QgsField(QStringLiteral("mbg_width"), QVariant::Double), QString());
    int heightField = AppendUniqueField(fields, QgsField(QStringLiteral("mbg_height"), QVariant::Double), QString());
    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("minimum_bounding_box_output");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        Qgis::WkbType::Polygon, sourceLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create minimum bounding box output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        double area = 0.0;
        double angle = 0.0;
        double width = 0.0;
        double height = 0.0;
        QgsGeometry box = geometry.orientedMinimumBoundingBox(area, angle, width, height);
        if (box.isNull() || box.isEmpty()) {
            continue;
        }
        QgsFeature outFeature(fields);
        for (int i = 0; i < sourceLayer->fields().count(); i++) {
            outFeature.setAttribute(i, feature.attribute(i));
        }
        outFeature.setAttribute(areaField, area);
        outFeature.setAttribute(angleField, angle);
        outFeature.setAttribute(widthField, width);
        outFeature.setAttribute(heightField, height);
        outFeature.setGeometry(box);
        if (writer->addFeature(outFeature)) {
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Oriented minimum bounding boxes completed through QgsGeometry",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *ExecuteProcessingAlgorithm(const char *requestJson, int32_t *outErrCode)
{
    if (!requestJson || std::strlen(requestJson) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Processing request is empty",
            "", "", 0, outErrCode);
    }

    QJsonParseError parseError;
    QJsonDocument document = QJsonDocument::fromJson(QByteArray(requestJson), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Processing request JSON is invalid",
            "", "", 0, outErrCode);
    }
    QJsonObject request = document.object();
    QString algorithmId = request.value(QStringLiteral("algorithmId")).toString().trimmed().toLower();
    LayerHandle inputHandle = request.value(QStringLiteral("inputHandle")).toInt();
    LayerHandle overlayHandle = request.value(QStringLiteral("overlayHandle")).toInt();
    double numericValue = request.value(QStringLiteral("numericValue")).toDouble();
    QByteArray textValue = request.value(QStringLiteral("textValue")).toString().toUtf8();
    QByteArray outputPath = request.value(QStringLiteral("outputPath")).toString().toUtf8();
    QByteArray outputLayerName = request.value(QStringLiteral("outputLayerName")).toString().toUtf8();

    if (algorithmId == QStringLiteral("buffer") || algorithmId == QStringLiteral("overlay:buffer")) {
        return BufferLayer(inputHandle, numericValue, outputPath.constData(), outputLayerName.constData(),
            outErrCode);
    }
    if (algorithmId == QStringLiteral("simplify") ||
        algorithmId == QStringLiteral("cartography:generalization")) {
        return SimplifyLayer(inputHandle, numericValue, outputPath.constData(), outputLayerName.constData(),
            outErrCode);
    }
    if (algorithmId == QStringLiteral("dissolve")) {
        return DissolveLayer(inputHandle, outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("centroid") ||
        algorithmId == QStringLiteral("vector:centroid")) {
        return CentroidLayer(inputHandle, outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("convex_hull") ||
        algorithmId == QStringLiteral("vector:minimum_bounding_geometry")) {
        return ConvexHullLayer(inputHandle, outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("bounding_boxes")) {
        return BoundingBoxLayer(inputHandle, outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("oriented_minimum_bounding_box")) {
        return OrientedMinimumBoundingBoxLayer(inputHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("multipart_to_singleparts")) {
        return MultipartToSinglepartsLayer(inputHandle, outputPath.constData(), outputLayerName.constData(),
            outErrCode);
    }
    if (algorithmId == QStringLiteral("voronoi") || algorithmId == QStringLiteral("vector:voronoi")) {
        return VoronoiLayer(inputHandle, numericValue, outputPath.constData(), outputLayerName.constData(),
            outErrCode);
    }
    if (algorithmId == QStringLiteral("nearest_neighbor") ||
        algorithmId == QStringLiteral("vector:nearest")) {
        return NearestNeighborLayer(inputHandle, overlayHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("repair") || algorithmId == QStringLiteral("data:repair")) {
        return RepairLayer(inputHandle, outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("extract_by_expression")) {
        return ExtractByExpressionLayer(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("extract_by_location") ||
        algorithmId == QStringLiteral("overlay:select_by_location")) {
        return ExtractByLocationLayer(inputHandle, overlayHandle, static_cast<int32_t>(numericValue),
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("clip") || algorithmId == QStringLiteral("data:clip")) {
        return ClipLayer(inputHandle, overlayHandle, outputPath.constData(), outputLayerName.constData(),
            outErrCode);
    }
    if (algorithmId == QStringLiteral("intersection") ||
        algorithmId == QStringLiteral("overlay:intersection")) {
        return IntersectionLayer(inputHandle, overlayHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("difference") || algorithmId == QStringLiteral("overlay:erase")) {
        return DifferenceLayer(inputHandle, overlayHandle, outputPath.constData(), outputLayerName.constData(),
            outErrCode);
    }
    if (algorithmId == QStringLiteral("symmetrical_difference")) {
        return SymmetricalDifferenceLayer(inputHandle, overlayHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("spatial_join_summary") ||
        algorithmId == QStringLiteral("overlay:spatial_join")) {
        return SpatialJoinSummaryLayer(inputHandle, overlayHandle, static_cast<int32_t>(numericValue),
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("multi_ring_buffer") ||
        algorithmId == QStringLiteral("overlay:multi_ring_buffer")) {
        return MultiRingBufferLayer(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("merge_layers") || algorithmId == QStringLiteral("data:merge")) {
        return MergeLayers(inputHandle, overlayHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("export")) {
        return ExportLayer(inputHandle, outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("define_projection")) {
        return DefineLayerProjection(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("project") || algorithmId == QStringLiteral("data:reproject")) {
        return ProjectLayer(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }

    std::string message = "Algorithm is not available in the packaged QGIS providers: ";
    message += ToStdString(algorithmId);
    return MakeProcessResult(false, GIS_ERR_NATIVE_NOT_READY, message,
        outputPath.constData(), outputLayerName.constData(), 0, outErrCode);
}

const char *ApplyVectorStyle(LayerHandle handle, int32_t rendererMode, const char *rendererField,
                             int32_t colorRamp, int32_t linePattern, int32_t fillPattern,
                             const char *pointColor, const char *lineColor, const char *fillColor,
                             const char *strokeColor, double lineWidth, double pointRadius,
                             double opacity, const char *symbolName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    Q_UNUSED(symbolName);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Vector layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QString fieldName = QString::fromUtf8(rendererField ? rendererField : "");
    bool applied = false;
    if (rendererMode == 1 && !fieldName.isEmpty()) {
        applied = BuildCategorizedRenderer(layer, fieldName, colorRamp, linePattern, fillPattern, pointColor,
            lineColor, fillColor, strokeColor, lineWidth, pointRadius, opacity);
    } else if (rendererMode == 2 && !fieldName.isEmpty()) {
        applied = BuildGraduatedRenderer(layer, fieldName, colorRamp, linePattern, fillPattern, pointColor,
            lineColor, fillColor, strokeColor, lineWidth, pointRadius, opacity);
    }

    if (!applied) {
        QgsSymbol *symbol = CreateSymbolForLayer(layer, colorRamp, 0, 1, linePattern, fillPattern, pointColor,
            lineColor, fillColor, strokeColor, lineWidth, pointRadius, opacity);
        if (!symbol) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Failed to create QGIS symbol", "", "",
                static_cast<int32_t>(layer->featureCount()), outErrCode);
        }
        layer->setRenderer(new QgsSingleSymbolRenderer(symbol));
    }
    layer->triggerRepaint();
    return MakeProcessResult(true, GIS_OK, "Vector style applied through QGIS renderer", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *ApplyVectorLabeling(LayerHandle handle, bool enabled, const char *labelField,
                                double labelSize, const char *labelColor, bool halo,
                                bool avoidance, double minScale, double maxScale,
                                int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Vector layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    if (!enabled) {
        layer->setLabelsEnabled(false);
        layer->triggerRepaint();
        return MakeProcessResult(true, GIS_OK, "Vector labeling disabled through QGIS", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    QString fieldName = QString::fromUtf8(labelField ? labelField : "");
    if (fieldName.isEmpty() || layer->fields().indexOf(fieldName) < 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Label field not found", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    QgsTextFormat format;
    format.setSize(ClampDouble(labelSize, 6.0, 72.0));
    format.setColor(ColorFromText(labelColor, QColor("#17201D")));
    if (halo) {
        QgsTextBufferSettings buffer;
        buffer.setEnabled(true);
        buffer.setSize(1.2);
        buffer.setColor(QColor("#FFFFFF"));
        format.setBuffer(buffer);
    }

    QgsPalLayerSettings settings;
    settings.fieldName = fieldName;
    settings.drawLabels = true;
    settings.placement = layer->geometryType() == Qgis::GeometryType::Line
        ? Qgis::LabelPlacement::Line : Qgis::LabelPlacement::AroundPoint;
    settings.priority = 7;
    settings.scaleVisibility = minScale > 0.0 || maxScale > 0.0;
    settings.minimumScale = minScale;
    settings.maximumScale = maxScale;
    settings.obstacleSettings().setIsObstacle(avoidance);
    settings.setFormat(format);

    layer->setLabeling(new QgsVectorLayerSimpleLabeling(settings));
    layer->setLabelsEnabled(true);
    layer->triggerRepaint();
    return MakeProcessResult(true, GIS_OK, "Vector labeling applied through QGIS PAL labeling", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *ConfigureRasterDisplay(LayerHandle handle, int32_t bandMode, int32_t stretchMode,
                                   int32_t colorRamp, double opacity, const char *noData,
                                   const char *transparentColor, bool hillshade,
                                   int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisRasterState *state = FindRasterLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Raster layer not found", "", "", 0, outErrCode);
    }
    QgsRasterLayer *layer = state->layer.get();
    QgsRasterDataProvider *provider = layer->dataProvider();
    if (!provider || provider->bandCount() <= 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT, "Raster provider has no bands", "", "", 0,
            outErrCode);
    }

    if (noData && std::strlen(noData) > 0) {
        bool ok = false;
        double noDataValue = QString::fromUtf8(noData).toDouble(&ok);
        if (ok) {
            QgsRasterRangeList ranges;
            ranges.append(QgsRasterRange(noDataValue, noDataValue));
            for (int band = 1; band <= provider->bandCount(); band++) {
                provider->setUserNoDataValue(band, ranges);
            }
        }
    }

    QgsRasterRenderer *renderer = nullptr;
    if (hillshade) {
        renderer = new QgsHillshadeRenderer(provider, 1, 315.0, 45.0);
    } else if (bandMode == 1 && provider->bandCount() >= 3) {
        renderer = new QgsMultiBandColorRenderer(provider, 1, 2, 3,
            CreateContrastEnhancement(provider, 1, stretchMode),
            CreateContrastEnhancement(provider, 2, stretchMode),
            CreateContrastEnhancement(provider, 3, stretchMode));
    } else {
        QgsSingleBandGrayRenderer *grayRenderer = new QgsSingleBandGrayRenderer(provider, 1);
        grayRenderer->setGradient(colorRamp == 1 ? QgsSingleBandGrayRenderer::WhiteToBlack :
            QgsSingleBandGrayRenderer::BlackToWhite);
        grayRenderer->setContrastEnhancement(CreateContrastEnhancement(provider, 1, stretchMode));
        renderer = grayRenderer;
    }

    if (!renderer) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Failed to create raster renderer", "", "", 0,
            outErrCode);
    }
    if (transparentColor && std::strlen(transparentColor) > 0) {
        renderer->setNodataColor(ColorFromText(transparentColor, QColor(0, 0, 0, 0)));
    }
    double cleanOpacity = ClampDouble(opacity, 0.0, 1.0);
    renderer->setOpacity(cleanOpacity);
    layer->setRenderer(renderer);
    layer->setOpacity(cleanOpacity);
    layer->triggerRepaint();
    return MakeProcessResult(true, GIS_OK, "Raster display configured through QGIS raster renderer", "", "", 0,
        outErrCode);
}

const char *ExportMapLayout(const char *title, const char *outputPath, const char *format,
                            bool showLegend, bool showScaleBar, bool showNorthArrow,
                            bool showGrid, int32_t width, int32_t height,
                            const char *legendTitle, const char *scaleText, const char *footerText,
                            int32_t basemapMode, const char *basemapLabel,
                            const char *visibleLayerHandles, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Output path is empty", "", "", 0, outErrCode);
    }
    int32_t outWidth = width > 0 ? width : 1600;
    int32_t outHeight = height > 0 ? height : 1100;
    QList<QgsMapLayer *> layers;
    QgsRectangle extent;
    QgsCoordinateReferenceSystem crs;
    if (!CollectMapLayers(layers, extent, crs, visibleLayerHandles)) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "No visible QGIS layers to export", outputPath, "",
            0, outErrCode);
    }

    QImage mapImage = RenderMapImage(layers, extent, crs, outWidth - 64, outHeight - 134);
    if (mapImage.isNull()) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS map rendering returned an empty image",
            outputPath, "", 0, outErrCode);
    }

    QFileInfo outputInfo(QString::fromUtf8(outputPath));
    QDir parentDir = outputInfo.absoluteDir();
    if (!parentDir.exists()) {
        parentDir.mkpath(QStringLiteral("."));
    }
    QString titleText = QString::fromUtf8(title && std::strlen(title) > 0 ? title : "GeoNest Map");
    QString legendTitleText = LayoutTextOrDefault(legendTitle, QStringLiteral("图例"));
    QString scaleLabelText = LayoutTextOrDefault(scaleText, QStringLiteral("比例尺"));
    QString footerLabelText = LayoutTextOrDefault(footerText, QStringLiteral("GeoNest QGIS layout export"));
    QString basemapLabelText = LayoutTextOrDefault(basemapLabel, QStringLiteral("本地矢量底图"));
    QString formatText = QString::fromUtf8(format ? format : "png").toLower();
    bool ok = false;

    if (formatText == QStringLiteral("pdf")) {
        QPdfWriter writer(QString::fromUtf8(outputPath));
        writer.setResolution(144);
        writer.setPageSize(QPageSize(QSizeF(outWidth * 25.4 / 144.0, outHeight * 25.4 / 144.0),
            QPageSize::Millimeter));
        QPainter painter(&writer);
        DrawLayoutDecorations(painter, mapImage, layers, titleText, legendTitleText, scaleLabelText,
            footerLabelText, showLegend, showScaleBar, showNorthArrow, showGrid, outWidth, outHeight, basemapMode,
            basemapLabelText);
        painter.end();
        ok = true;
    } else if (formatText == QStringLiteral("svg")) {
        QSvgGenerator generator;
        generator.setFileName(QString::fromUtf8(outputPath));
        generator.setSize(QSize(outWidth, outHeight));
        generator.setViewBox(QRect(0, 0, outWidth, outHeight));
        generator.setResolution(144);
        QPainter painter(&generator);
        DrawLayoutDecorations(painter, mapImage, layers, titleText, legendTitleText, scaleLabelText,
            footerLabelText, showLegend, showScaleBar, showNorthArrow, showGrid, outWidth, outHeight, basemapMode,
            basemapLabelText);
        painter.end();
        ok = true;
    } else {
        QImage layoutImage(outWidth, outHeight, QImage::Format_ARGB32_Premultiplied);
        QPainter painter(&layoutImage);
        DrawLayoutDecorations(painter, mapImage, layers, titleText, legendTitleText, scaleLabelText,
            footerLabelText, showLegend, showScaleBar, showNorthArrow, showGrid, outWidth, outHeight, basemapMode,
            basemapLabelText);
        painter.end();
        ok = layoutImage.save(QString::fromUtf8(outputPath), "PNG");
    }

    if (!ok) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to write layout output", outputPath, "", 0,
            outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Map layout exported through QGIS map renderer", outputPath,
        titleText.toStdString(), layers.size(), outErrCode);
}

const char *AddFeature(LayerHandle handle, int32_t geometryType, const char *coordsText, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    if (MapGeometryType(layer->geometryType()) != geometryType) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Geometry type does not match active layer",
            "", "", static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    std::vector<QgsPointXY> points = ParseCoordText(coordsText);
    QgsGeometry geometry = GeometryFromPoints(geometryType, points);
    if (geometry.isNull() || geometry.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid sketch geometry", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    std::string message;
    if (!BeginEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    QgsFeature feature;
    feature.setFields(layer->fields(), true);
    feature.setGeometry(geometry);
    if (!layer->addFeature(feature)) {
        layer->rollBack();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS addFeature failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!CommitEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Feature added through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *DeleteFeature(LayerHandle handle, int64_t fid, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QgsFeature feature;
    if (!FetchFeature(layer, fid, feature)) {
        return MakeProcessResult(false, GIS_ERR_FEATURE_NOT_FOUND, "Feature not found", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    std::string message;
    if (!BeginEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!layer->deleteFeature(static_cast<QgsFeatureId>(fid))) {
        layer->rollBack();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS deleteFeature failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!CommitEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Feature deleted through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *MoveFeatureNode(LayerHandle handle, int64_t fid, int32_t partIndex, int32_t pointIndex,
                            double x, double y, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QgsFeature feature;
    if (!FetchFeature(layer, fid, feature)) {
        return MakeProcessResult(false, GIS_ERR_FEATURE_NOT_FOUND, "Feature not found", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QgsGeometry geometry = feature.geometry();
    std::string message;
    if (!EditGeometryNode(geometry, MapGeometryType(geometry.type()), false, partIndex, pointIndex, x, y, message)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!BeginEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!layer->changeGeometry(static_cast<QgsFeatureId>(fid), geometry)) {
        layer->rollBack();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS changeGeometry failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!CommitEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Node moved through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *DeleteFeatureNode(LayerHandle handle, int64_t fid, int32_t partIndex, int32_t pointIndex,
                              int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QgsFeature feature;
    if (!FetchFeature(layer, fid, feature)) {
        return MakeProcessResult(false, GIS_ERR_FEATURE_NOT_FOUND, "Feature not found", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QgsGeometry geometry = feature.geometry();
    std::string message;
    if (!EditGeometryNode(geometry, MapGeometryType(geometry.type()), true, partIndex, pointIndex, 0.0, 0.0,
        message)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!BeginEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!layer->changeGeometry(static_cast<QgsFeatureId>(fid), geometry)) {
        layer->rollBack();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS changeGeometry failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!CommitEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Node deleted through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *CopyFeature(LayerHandle handle, int64_t fid, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QgsFeature source;
    if (!FetchFeature(layer, fid, source)) {
        return MakeProcessResult(false, GIS_ERR_FEATURE_NOT_FOUND, "Feature not found", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    std::string message;
    if (!BeginEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QgsFeature copy;
    copy.setFields(layer->fields(), true);
    copy.setGeometry(source.geometry());
    copy.setAttributes(source.attributes());
    if (!layer->addFeature(copy)) {
        layer->rollBack();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS add copied feature failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!CommitEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Feature copied through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *SplitFeature(LayerHandle handle, int64_t fid, const char *coordsText, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    std::vector<QgsPointXY> parsedPoints = ParseCoordText(coordsText);
    if (parsedPoints.size() < 2) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Split line requires at least two points", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QgsFeature feature;
    if (!FetchFeature(layer, fid, feature)) {
        return MakeProcessResult(false, GIS_ERR_FEATURE_NOT_FOUND, "Feature not found", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QgsGeometry geometry = feature.geometry();
    if (geometry.isNull() || geometry.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Feature geometry is empty", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    QVector<QgsPointXY> splitLine;
    for (size_t i = 0; i < parsedPoints.size(); i++) {
        splitLine.push_back(parsedPoints[i]);
    }
    QVector<QgsGeometry> newGeometries;
    QVector<QgsPointXY> topologyPoints;
    Qgis::GeometryOperationResult splitResult = geometry.splitGeometry(splitLine, newGeometries, false,
        topologyPoints, true);
    if (splitResult != Qgis::GeometryOperationResult::Success || newGeometries.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "QGIS splitGeometry did not split the feature", "",
            "", static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    std::string message;
    if (!BeginEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!layer->changeGeometry(static_cast<QgsFeatureId>(fid), geometry)) {
        layer->rollBack();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS changeGeometry failed for split source", "",
            "", static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    for (int i = 0; i < newGeometries.size(); i++) {
        QgsFeature outFeature;
        outFeature.setFields(layer->fields(), true);
        outFeature.setAttributes(feature.attributes());
        outFeature.setGeometry(newGeometries.at(i));
        if (!layer->addFeature(outFeature)) {
            layer->rollBack();
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS add split feature failed", "", "",
                static_cast<int32_t>(layer->featureCount()), outErrCode);
        }
    }
    if (!CommitEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Feature split through QGIS geometry API", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *MergeFeatures(LayerHandle handle, const char *fidListText, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    std::vector<int64_t> fids = ParseFidList(fidListText);
    if (fids.size() < 2) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Merge requires at least two feature ids", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    QVector<QgsGeometry> geometries;
    QgsFeature firstFeature;
    bool hasFirst = false;
    for (size_t i = 0; i < fids.size(); i++) {
        QgsFeature feature;
        if (!FetchFeature(layer, fids[i], feature)) {
            return MakeProcessResult(false, GIS_ERR_FEATURE_NOT_FOUND, "Feature not found for merge", "", "",
                static_cast<int32_t>(layer->featureCount()), outErrCode);
        }
        if (!hasFirst) {
            firstFeature = feature;
            hasFirst = true;
        }
        QgsGeometry geometry = feature.geometry();
        if (!geometry.isNull() && !geometry.isEmpty()) {
            geometries.push_back(geometry);
        }
    }
    if (geometries.size() < 2) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Merge features have insufficient geometry", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    QgsGeometry merged = QgsGeometry::unaryUnion(geometries);
    if (merged.isNull() || merged.isEmpty()) {
        merged = geometries.at(0);
        for (int i = 1; i < geometries.size(); i++) {
            merged = merged.combine(geometries.at(i));
        }
    }
    if (layer->geometryType() == Qgis::GeometryType::Line && !merged.isNull() && !merged.isEmpty()) {
        QgsGeometry mergedLines = merged.mergeLines();
        if (!mergedLines.isNull() && !mergedLines.isEmpty()) {
            merged = mergedLines;
        }
    }
    if (merged.isNull() || merged.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "QGIS geometry merge failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    std::string message;
    if (!BeginEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QgsFeatureId keepFid = static_cast<QgsFeatureId>(fids[0]);
    if (!layer->changeGeometry(keepFid, merged)) {
        layer->rollBack();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS changeGeometry failed for merge", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    for (size_t i = 1; i < fids.size(); i++) {
        if (!layer->deleteFeature(static_cast<QgsFeatureId>(fids[i]))) {
            layer->rollBack();
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS delete merged feature failed", "", "",
                static_cast<int32_t>(layer->featureCount()), outErrCode);
        }
    }
    Q_UNUSED(firstFeature);
    if (!CommitEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Features merged through QGIS geometry API", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *SnapLayer(LayerHandle handle, LayerHandle targetHandle, double tolerance, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Source layer not found", "", "", 0, outErrCode);
    }
    QgisLayerState *targetState = FindLayer(targetHandle > 0 ? targetHandle : handle);
    if (!targetState || !targetState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Target layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QgsVectorLayer *targetLayer = targetState->layer.get();
    double snapTolerance = tolerance;
    if (snapTolerance <= 0.0) {
        QgsRectangle extent = layer->extent();
        double width = std::abs(extent.xMaximum() - extent.xMinimum());
        double height = std::abs(extent.yMaximum() - extent.yMinimum());
        snapTolerance = std::max(width, height) / 5000.0;
        if (snapTolerance <= 0.0) {
            snapTolerance = 1.0;
        }
    }

    std::vector<QgsPointXY> targetPoints;
    QgsFeatureIterator targetIterator = targetLayer->getFeatures();
    QgsFeature targetFeature;
    while (targetIterator.nextFeature(targetFeature)) {
        CollectGeometryPoints(targetFeature.geometry(), targetPoints);
    }
    if (targetPoints.empty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Target layer has no snap vertices", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    std::string message;
    if (!BeginEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    int32_t changedCount = 0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (SnapGeometryToTargets(geometry, targetPoints, snapTolerance)) {
            if (!layer->changeGeometry(feature.id(), geometry)) {
                layer->rollBack();
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS snapping changeGeometry failed", "",
                    "", changedCount, outErrCode);
            }
            changedCount++;
        }
    }
    if (!CommitEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "", changedCount, outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Layer snapped through QGIS provider geometry updates", "", "",
        changedCount, outErrCode);
}

const char *UpdateFeatureAttribute(LayerHandle handle, int64_t fid, const char *fieldName,
                                   const char *value, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    int fieldIndex = FieldIndexByName(layer, fieldName);
    if (fieldIndex < 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Field not found", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QgsFeature feature;
    if (!FetchFeature(layer, fid, feature)) {
        return MakeProcessResult(false, GIS_ERR_FEATURE_NOT_FOUND, "Feature not found", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    std::string message;
    if (!BeginEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QVariant attrValue(QString::fromUtf8(value ? value : ""));
    if (!layer->changeAttributeValue(static_cast<QgsFeatureId>(fid), fieldIndex, attrValue)) {
        layer->rollBack();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS changeAttributeValue failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!CommitEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Attribute updated through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *BatchAssignAttribute(LayerHandle handle, const char *fieldName, const char *filterText,
                                 const char *value, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    int fieldIndex = FieldIndexByName(layer, fieldName);
    if (fieldIndex < 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Field not found", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QString filter = QString::fromUtf8(filterText ? filterText : "").trimmed();
    bool useQgisExpression = filter.startsWith(QStringLiteral("qgis:"), Qt::CaseInsensitive);
    QString expressionText = useQgisExpression ? filter.mid(5).trimmed() : QString();
    QgsExpression expression(expressionText);
    QgsExpressionContext expressionContext;
    if (useQgisExpression) {
        if (expressionText.isEmpty() || expression.hasParserError()) {
            std::string expressionError = expressionText.isEmpty()
                ? "QGIS expression is empty" : ToStdString(expression.parserErrorString());
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, expressionError, "", "",
                static_cast<int32_t>(layer->featureCount()), outErrCode);
        }
        expressionContext.setFields(layer->fields());
        if (!expression.prepare(&expressionContext)) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "QGIS expression preparation failed", "", "",
                static_cast<int32_t>(layer->featureCount()), outErrCode);
        }
    }

    std::string message;
    if (!BeginEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QVariant attrValue(QString::fromUtf8(value ? value : ""));
    int32_t changed = 0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        bool matches = false;
        if (useQgisExpression) {
            expressionContext.setFeature(feature);
            QVariant evaluated = expression.evaluate(&expressionContext);
            if (expression.hasEvalError()) {
                layer->rollBack();
                return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
                    ToStdString(expression.evalErrorString()), "", "", changed, outErrCode);
            }
            matches = evaluated.toBool();
        } else {
            matches = RowMatchesFilter(layer, feature, filter);
        }
        if (matches) {
            if (layer->changeAttributeValue(feature.id(), fieldIndex, attrValue)) {
                changed++;
            }
        }
    }
    if (!CommitEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "", changed, outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Batch attribute assignment completed", "", "", changed, outErrCode);
}

const char *AddLayerField(LayerHandle handle, const char *fieldName, const char *typeName,
                          int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    if (!fieldName || std::strlen(fieldName) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Field name is empty", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (FieldIndexByName(layer, fieldName) >= 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Field already exists", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    std::string message;
    if (!BeginEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QString typeText = QString::fromUtf8(typeName ? typeName : "").toLower();
    QVariant::Type fieldType = QVariant::String;
    if (typeText.contains(QStringLiteral("int"))) {
        fieldType = QVariant::Int;
    } else if (typeText.contains(QStringLiteral("real")) || typeText.contains(QStringLiteral("double")) ||
        typeText.contains(QStringLiteral("float"))) {
        fieldType = QVariant::Double;
    }
    if (!layer->addAttribute(QgsField(QString::fromUtf8(fieldName), fieldType))) {
        layer->rollBack();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS addAttribute failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    layer->updateFields();
    if (!CommitEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Field added through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *DeleteLayerField(LayerHandle handle, const char *fieldName, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    int fieldIndex = FieldIndexByName(layer, fieldName);
    if (fieldIndex < 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Field not found", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    std::string message;
    if (!BeginEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!layer->deleteAttribute(fieldIndex)) {
        layer->rollBack();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS deleteAttribute failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    layer->updateFields();
    if (!CommitEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Field deleted through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *CalculateField(LayerHandle handle, const char *fieldName, int32_t calculatorMode,
                           const char *constantValue, int32_t *outErrCode)
{
    std::lock_guard<std::mutex> lock(g_mutex);
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    int fieldIndex = FieldIndexByName(layer, fieldName);
    if (fieldIndex < 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Field not found", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QString calculationText = QString::fromUtf8(constantValue ? constantValue : "");
    QgsExpression expression(calculationText);
    QgsExpressionContext expressionContext;
    if (calculatorMode == 4) {
        if (calculationText.trimmed().isEmpty() || expression.hasParserError()) {
            std::string expressionError = calculationText.trimmed().isEmpty()
                ? "QGIS expression is empty" : ToStdString(expression.parserErrorString());
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, expressionError, "", "",
                static_cast<int32_t>(layer->featureCount()), outErrCode);
        }
        expressionContext.setFields(layer->fields());
        if (!expression.prepare(&expressionContext)) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "QGIS expression preparation failed", "", "",
                static_cast<int32_t>(layer->featureCount()), outErrCode);
        }
    }

    std::string message;
    if (!BeginEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    int32_t changed = 0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QVariant value(calculationText);
        if (calculatorMode == 1) {
            value = QVariant::fromValue(static_cast<qlonglong>(feature.id()));
        } else if (calculatorMode == 2) {
            value = QVariant(feature.geometry().area());
        } else if (calculatorMode == 3) {
            value = QVariant(feature.geometry().length());
        } else if (calculatorMode == 4) {
            expressionContext.setFeature(feature);
            value = expression.evaluate(&expressionContext);
            if (expression.hasEvalError()) {
                layer->rollBack();
                return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
                    ToStdString(expression.evalErrorString()), "", "", changed, outErrCode);
            }
        }
        if (layer->changeAttributeValue(feature.id(), fieldIndex, value)) {
            changed++;
        }
    }
    if (!CommitEdit(layer, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "", changed, outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Field calculator completed through QGIS provider", "", "",
        changed, outErrCode);
}

void FreeCString(char *str)
{
    if (str) {
        free(str);
    }
}

} // namespace geonest
