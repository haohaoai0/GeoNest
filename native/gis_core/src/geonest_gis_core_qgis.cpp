#include "geonest_gis_core.h"

#include <qgis.h>
#include <qgsapplication.h>
#include <qgsabstractgeometry.h>
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
#include <qgsmaprenderercustompainterjob.h>
#include <qgsmapsettings.h>
#include <qgsmarkersymbol.h>
#include <qgsmultibandcolorrenderer.h>
#include <qgspallabeling.h>
#include <qgspointxy.h>
#include <qgspoint.h>
#include <qgsrectangle.h>
#include <qgsrendererrange.h>
#include <qgsrasterdataprovider.h>
#include <qgsrasterblock.h>
#include <qgsrasterlayer.h>
#include <qgsrasterrange.h>
#include <qgsrasterrenderer.h>
#include <qgssinglesymbolrenderer.h>
#include <qgsrulebasedrenderer.h>
#include <qgssinglebandgrayrenderer.h>
#include <qgsspatialindex.h>
#include <qgssymbol.h>
#include <qgstextbuffersettings.h>
#include <qgstextformat.h>
#include <qgsvectorlayer.h>
#include <qgsvectorlayerlabeling.h>
#include <qgsvectorfilewriter.h>
#include <qgslinesymbol.h>
#include <qgscoordinatereferencesystem.h>
#include <qgscoordinatetransform.h>
#include <qgscoordinatetransformcontext.h>
#include <qgscontrastenhancement.h>
#include <qgsexception.h>
#include <qgsexpression.h>
#include <qgsexpressioncontext.h>
#include <qgslegendsymbolitem.h>
#include <qgslayertree.h>
#include <qgslayertreelayer.h>
#include <qgsproject.h>
#include <qgsproviderregistry.h>
#include <qgsprovidersublayerdetails.h>
#include <qgsrenderer.h>
#include <qgswkbtypes.h>
#include <qgsvertexid.h>
#include <qgsziputils.h>
#include <qgslazinfo.h>
#include <qgscopcpointcloudindex.h>
#include <qgslazdecoder.h>
#include <qgspointcloudexpression.h>
#include <qgspointcloudblock.h>

#include <QByteArray>
#include <QBrush>
#include <QColor>
#include <QDateTime>
#include <QEventLoop>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QFont>
#include <QFontDatabase>
#include <QImage>
#include <QIODevice>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QList>
#include <QMap>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPainter>
#include <QPainterPath>
#include <QPageSize>
#include <QPdfWriter>
#include <QPen>
#include <QPoint>
#include <QPolygon>
#include <QRect>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QSize>
#include <QSvgGenerator>
#include <QTextStream>
#include <QTimer>
#include <QUndoStack>
#include <QUuid>
#include <QUrl>
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
#include <limits>
#include <memory>
#include <mutex>
#include <set>
#include <random>
#include <string>
#include <vector>
#include <unordered_set>

namespace geonest {

struct PreparedProcessingLayerReference {
    LayerHandle handle = 0;
    std::string sourceUri;
    std::string layerName;
    bool raster = false;
    int64_t sourceSize = -1;
    int64_t sourceModifiedMs = -1;
};

struct PreparedProcessingTask {
    std::string requestJson;
    std::string workerRequestJson;
    std::string algorithmId;
    std::string finalOutputPath;
    std::string temporaryOutputPath;
    bool overwriteOutput = true;
    bool outputCommitted = false;
    PreparedProcessingLayerReference inputLayer;
    PreparedProcessingLayerReference overlayLayer;
    QgsCoordinateTransformContext transformContext;
};

namespace {

struct QgisLayerState {
    LayerHandle handle = 0;
    std::string filePath;
    std::unique_ptr<QgsVectorLayer> layer;
    bool editSessionActive = false;
    bool editCommandActive = false;
};

struct QgisRasterState {
    LayerHandle handle = 0;
    std::string filePath;
    std::unique_ptr<QgsRasterLayer> layer;
};

struct KernelDensityPoint {
    double x = 0.0;
    double y = 0.0;
    double weight = 1.0;
};

struct KernelDensityOptions {
    double cellSize = 0.0;
    QString populationField;
    QString areaUnit;
};

struct XYTableOptions {
    int xFieldIndex = -1;
    int yFieldIndex = -1;
    int zFieldIndex = -1;
    int mFieldIndex = -1;
    QString crsDefinition = QStringLiteral("EPSG:4326");
};

struct AtlasPageDefinition {
    QgsFeatureId featureId = 0;
    QgsRectangle extent;
    QString sortValue;
    QString groupValue;
    QString pageName;
};

struct RasterReclassRule {
    bool hasMinimum = false;
    bool hasMaximum = false;
    double minimum = 0.0;
    double maximum = 0.0;
    double outputValue = 0.0;
};

struct LineDensitySegment {
    double x1 = 0.0;
    double y1 = 0.0;
    double x2 = 0.0;
    double y2 = 0.0;
    double length = 0.0;
    double weight = 1.0;
};

struct IdwPoint {
    double x = 0.0;
    double y = 0.0;
    double value = 0.0;
};

struct IdwOptions {
    double cellSize = 0.0;
    double power = 2.0;
    QString valueField;
};

struct WeightedDistance {
    double distance = 0.0;
    double weight = 1.0;
};

struct PointsToLineRecord {
    QgsFeatureId id = -1;
    QgsPointXY point;
    QString groupKey;
    QString orderText;
    double orderNumber = 0.0;
    bool numericOrder = false;
};

struct StatisticsGroupRecord {
    QString groupKey;
    QString categoryKey;
    QgsGeometry location;
    qlonglong count = 0;
    qlonglong numericCount = 0;
    double sum = 0.0;
    double minimum = 0.0;
    double maximum = 0.0;
    double sumSquares = 0.0;
};

struct QualityGeometryRecord {
    QgsFeatureId id = 0;
    QgsGeometry geometry;
    QgsRectangle bounds;
};

struct QualityEndpointRecord {
    QgsFeatureId id = 0;
    QgsPointXY point;
};

struct QgisApplicationDeleter {
    void operator()(QgsApplication *application) const
    {
        if (application) {
            QgsApplication::exitQgis();
            delete application;
        }
    }
};

static std::mutex g_mutex;
static std::unique_ptr<QgsApplication, QgisApplicationDeleter> g_qgisApp;
static std::map<LayerHandle, std::unique_ptr<QgisLayerState>> g_layers;
static std::map<LayerHandle, std::unique_ptr<QgisRasterState>> g_rasterLayers;
static std::vector<LayerHandle> g_layerOrder;
static LayerHandle g_nextHandle = 1;
static bool g_qgisReady = false;
static int g_qgisArgc = 3;
static char g_qgisArg0[] = "geonestgis";
static char g_qgisArg1[] = "-platform";
static char g_qgisArg2[] = "offscreen";
static char *g_qgisArgv[] = { g_qgisArg0, g_qgisArg1, g_qgisArg2, nullptr };

static thread_local bool g_processingWorkerActive = false;
static thread_local std::map<LayerHandle, std::unique_ptr<QgisLayerState>> g_processingLayers;
static thread_local std::map<LayerHandle, std::unique_ptr<QgisRasterState>> g_processingRasterLayers;
static thread_local const QgsCoordinateTransformContext *g_processingTransformContext = nullptr;
static thread_local const ProcessingCallbacks *g_processingCallbacks = nullptr;
static thread_local int64_t g_processingProcessedCount = 0;
static thread_local double g_processingProgress = 0.0;

class ProcessingStateLock {
public:
    ProcessingStateLock() : lock_(g_mutex, std::defer_lock)
    {
        if (!g_processingWorkerActive) {
            lock_.lock();
        }
    }

private:
    std::unique_lock<std::mutex> lock_;
};

static bool ProcessingCancellationRequested()
{
    return g_processingCallbacks && g_processingCallbacks->isCanceled &&
        g_processingCallbacks->isCanceled(g_processingCallbacks->userData);
}

static void ReportProcessingProgress(double progress, int64_t processedCount, const char *stage)
{
    if (progress < g_processingProgress) {
        progress = g_processingProgress;
    }
    if (progress > 100.0) {
        progress = 100.0;
    }
    g_processingProgress = progress;
    if (processedCount > g_processingProcessedCount) {
        g_processingProcessedCount = processedCount;
    }
    if (g_processingCallbacks && g_processingCallbacks->reportProgress) {
        g_processingCallbacks->reportProgress(g_processingCallbacks->userData, progress,
            g_processingProcessedCount, stage ? stage : "compute");
    }
}

static bool ProcessingLoopCheckpoint(const char *stage)
{
    g_processingProcessedCount++;
    if (g_processingProcessedCount == 1 || (g_processingProcessedCount % 32) == 0) {
        double nextProgress = g_processingProgress;
        if (nextProgress < 88.0) {
            nextProgress += 1.0;
        }
        ReportProcessingProgress(nextProgress, g_processingProcessedCount, stage);
    }
    return ProcessingCancellationRequested();
}

static QgsCoordinateTransformContext CurrentProcessingTransformContext()
{
    if (g_processingTransformContext) {
        return *g_processingTransformContext;
    }
    return QgsProject::instance()->transformContext();
}

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

static void AppendPoint(std::string &json, const QgsPoint &point)
{
    json += "{\"x\":";
    json += std::to_string(point.x());
    json += ",\"y\":";
    json += std::to_string(point.y());
    json += ",\"z\":";
    json += point.is3D() ? std::to_string(point.z()) : "0";
    json += ",\"hasZ\":";
    json += point.is3D() ? "true" : "false";
    json += ",\"m\":";
    json += point.isMeasure() ? std::to_string(point.m()) : "0";
    json += ",\"hasM\":";
    json += point.isMeasure() ? "true" : "false";
    json += "}";
}

static void AppendPointPart(std::string &json, const QgsPointSequence &points, bool &firstPart)
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
    if (geometry.isNull() || geometry.constGet() == nullptr) {
        return;
    }

    // coordinateSequence() retains the native WKB dimensions. The previous
    // asPoint/asPolyline/asPolygon helpers converted every vertex to
    // QgsPointXY, silently discarding Z and M before the value reached ArkTS.
    QgsCoordinateSequence coordinateSequence = geometry.constGet()->coordinateSequence();
    if (geometryType == GEOM_POINT && geometry.isMultipart()) {
        QgsPointSequence points;
        for (int pi = 0; pi < coordinateSequence.size(); pi++) {
            QgsRingSequence rings = coordinateSequence.at(pi);
            for (int ri = 0; ri < rings.size(); ri++) {
                QgsPointSequence ring = rings.at(ri);
                for (int vi = 0; vi < ring.size(); vi++) {
                    points.push_back(ring.at(vi));
                }
            }
        }
        AppendPointPart(json, points, firstPart);
        return;
    }
    for (int pi = 0; pi < coordinateSequence.size(); pi++) {
        QgsRingSequence rings = coordinateSequence.at(pi);
        for (int ri = 0; ri < rings.size(); ri++) {
            AppendPointPart(json, rings.at(ri), firstPart);
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
    json += ",\"hasZ\":";
    json += QgsWkbTypes::hasZ(layer.wkbType()) ? "true" : "false";
    json += ",\"hasM\":";
    json += QgsWkbTypes::hasM(layer.wkbType()) ? "true" : "false";
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
    if (g_processingWorkerActive) {
        std::map<LayerHandle, std::unique_ptr<QgisLayerState>>::iterator processingIt =
            g_processingLayers.find(handle);
        if (processingIt != g_processingLayers.end()) {
            return processingIt->second.get();
        }
        return nullptr;
    }
    std::map<LayerHandle, std::unique_ptr<QgisLayerState>>::iterator it = g_layers.find(handle);
    if (it == g_layers.end()) {
        return nullptr;
    }
    return it->second.get();
}

static QgisRasterState *FindRasterLayer(LayerHandle handle)
{
    if (g_processingWorkerActive) {
        std::map<LayerHandle, std::unique_ptr<QgisRasterState>>::iterator processingIt =
            g_processingRasterLayers.find(handle);
        if (processingIt != g_processingRasterLayers.end()) {
            return processingIt->second.get();
        }
        return nullptr;
    }
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

static QString FilePathFromProviderUri(const QString &providerUri)
{
    int pipeIndex = providerUri.indexOf('|');
    if (pipeIndex > 0) {
        return providerUri.left(pipeIndex);
    }
    return providerUri;
}

static std::vector<LayerHandle> ParseLayerHandles(const char *layerHandles)
{
    std::vector<LayerHandle> result;
    QString text = QString::fromUtf8(layerHandles ? layerHandles : "");
    QStringList parts = text.split(';', Qt::SkipEmptyParts);
    for (int i = 0; i < parts.size(); i++) {
        bool ok = false;
        int value = parts.at(i).trimmed().toInt(&ok);
        if (ok && value > 0) {
            result.push_back(static_cast<LayerHandle>(value));
        }
    }
    return result;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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

static bool ValidateQgisExpression(QgsVectorLayer *layer, const QString &expressionText, std::string &message)
{
    if (!layer) {
        message = "Vector layer not found";
        return false;
    }
    QString expressionSource = expressionText.trimmed();
    if (expressionSource.isEmpty()) {
        message = "QGIS expression is empty";
        return false;
    }
    QgsExpression expression(expressionSource);
    if (expression.hasParserError()) {
        message = ToStdString(expression.parserErrorString());
        return false;
    }
    QgsExpressionContext expressionContext;
    expressionContext.setFields(layer->fields());
    if (!expression.prepare(&expressionContext)) {
        message = "QGIS expression preparation failed";
        return false;
    }
    return true;
}

static bool BuildExpressionRuleRenderer(QgsVectorLayer *layer, const QString &expressionText, int32_t colorRamp,
                                        int32_t linePattern, int32_t fillPattern, const char *pointColor,
                                        const char *lineColor, const char *fillColor, const char *strokeColor,
                                        double lineWidth, double pointRadius, double opacity)
{
    QgsSymbol *matchSymbol = CreateSymbolForLayer(layer, colorRamp, 0, 2, linePattern, fillPattern,
        pointColor, lineColor, fillColor, strokeColor, lineWidth, pointRadius, opacity);
    QgsSymbol *otherSymbol = CreateSymbolForLayer(layer, colorRamp, 1, 2, linePattern, fillPattern,
        pointColor, lineColor, fillColor, strokeColor, lineWidth, pointRadius, ClampDouble(opacity, 0.0, 1.0) * 0.35);
    if (!matchSymbol || !otherSymbol) {
        delete matchSymbol;
        delete otherSymbol;
        return false;
    }

    QgsRuleBasedRenderer::Rule *rootRule = new QgsRuleBasedRenderer::Rule(nullptr);
    QgsRuleBasedRenderer::Rule *matchRule = new QgsRuleBasedRenderer::Rule(matchSymbol, 0, 0,
        expressionText.trimmed(), QStringLiteral("Expression match"), QStringLiteral("expr_match"), false);
    QgsRuleBasedRenderer::Rule *otherRule = new QgsRuleBasedRenderer::Rule(otherSymbol, 0, 0,
        QString(), QStringLiteral("Other features"), QStringLiteral("expr_other"), true);
    rootRule->appendChild(matchRule);
    rootRule->appendChild(otherRule);
    layer->setRenderer(new QgsRuleBasedRenderer(rootRule));
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

static bool CombinedExtentInCrs(const QList<QgsMapLayer *> &layers,
                                const QgsCoordinateReferenceSystem &destinationCrs,
                                QgsRectangle &extent)
{
    bool hasExtent = false;
    for (int i = 0; i < layers.size(); i++) {
        QgsMapLayer *layer = layers.at(i);
        if (!layer || !layer->isValid()) {
            continue;
        }
        QgsRectangle layerExtent = layer->extent();
        if (layerExtent.isNull() || layerExtent.isEmpty()) {
            continue;
        }
        QgsCoordinateReferenceSystem sourceCrs = layer->crs();
        if (destinationCrs.isValid() && sourceCrs.isValid() && sourceCrs != destinationCrs) {
            try {
                QgsCoordinateTransform transform(sourceCrs, destinationCrs, CurrentProcessingTransformContext());
                layerExtent = transform.transformBoundingBox(layerExtent);
            } catch (const QgsCsException &) {
                continue;
            }
        }
        if (!hasExtent) {
            extent = layerExtent;
            hasExtent = true;
        } else {
            extent.combineExtentWith(layerExtent);
        }
    }
    return hasExtent;
}

static QgsRectangle DefaultXyzExportExtent(int32_t width, int32_t height)
{
    const double originShift = 20037508.342789244;
    const double pi = 3.14159265358979323846;
    const double centerLongitude = 112.55;
    const double centerLatitude = 37.87;
    const double centerX = centerLongitude / 180.0 * originShift;
    const double latitudeRadians = centerLatitude * pi / 180.0;
    const double centerY = std::log(std::tan(pi / 4.0 + latitudeRadians / 2.0)) /
        pi * originShift;
    const double metersPerPixel = 156543.03392804097 / 64.0;
    double halfWidth = std::max(1, width) * metersPerPixel / 2.0;
    double halfHeight = std::max(1, height) * metersPerPixel / 2.0;
    return QgsRectangle(centerX - halfWidth, centerY - halfHeight, centerX + halfWidth, centerY + halfHeight);
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

static bool RenderMapVectorToPainter(QPainter &painter, const QList<QgsMapLayer *> &layers,
                                     const QgsRectangle &extent,
                                     const QgsCoordinateReferenceSystem &crs,
                                     const QRect &targetRect)
{
    if (!painter.isActive() || targetRect.width() <= 0 || targetRect.height() <= 0) {
        return false;
    }
    QgsMapSettings settings;
    settings.setLayers(layers);
    settings.setExtent(extent);
    settings.setOutputSize(targetRect.size());
    settings.setOutputDpi(144.0);
    settings.setBackgroundColor(QColor(255, 255, 255, 0));
    if (crs.isValid()) {
        settings.setDestinationCrs(crs);
    }
    settings.setFlag(Qgis::MapSettingsFlag::Antialiasing, true);
    settings.setFlag(Qgis::MapSettingsFlag::DrawLabeling, true);
    painter.save();
    painter.setClipRect(targetRect);
    painter.translate(targetRect.left(), targetRect.top());
    QgsMapRendererCustomPainterJob job(settings, &painter);
    job.start();
    job.waitForFinished();
    painter.restore();
    return true;
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

static bool IsXyzExportBasemap(int32_t basemapMode)
{
    return basemapMode >= 1 && basemapMode <= 3;
}

static int32_t StaticExportBasemapMode(int32_t basemapMode)
{
    if (basemapMode == 4) {
        return 1;
    }
    if (basemapMode == 5) {
        return 2;
    }
    if (basemapMode == 6) {
        return 3;
    }
    return basemapMode;
}

static QString XyzBasemapTemplate(int32_t basemapMode)
{
    if (basemapMode == 2) {
        return QStringLiteral("https://tile.opentopomap.org/{z}/{x}/{y}.png");
    }
    if (basemapMode == 3) {
        return QStringLiteral("https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png");
    }
    return QStringLiteral("https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png");
}

static QString XyzBasemapAttribution(int32_t basemapMode)
{
    if (basemapMode == 2) {
        return QStringLiteral("© OpenStreetMap contributors · SRTM · map style © OpenTopoMap (CC-BY-SA)");
    }
    return QStringLiteral("© OpenStreetMap contributors · © CARTO");
}

static int XyzMaximumZoom(int32_t basemapMode)
{
    return basemapMode == 2 ? 17 : 18;
}

static bool DownloadXyzTile(QNetworkAccessManager &manager, const QUrl &url, QImage &image,
                            QString &errorMessage)
{
    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "GeoNest/1.0 (HarmonyOS GIS layout export)");
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::PreferCache);
    QNetworkReply *reply = manager.get(request);
    if (!reply) {
        errorMessage = QStringLiteral("XYZ request could not be created: ") + url.toString();
        return false;
    }

    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    timer.start(8000);
    loop.exec();

    if (!timer.isActive()) {
        reply->abort();
        errorMessage = QStringLiteral("XYZ request timed out: ") + url.toString();
        delete reply;
        return false;
    }
    timer.stop();

    int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (reply->error() != QNetworkReply::NoError || statusCode < 200 || statusCode >= 300) {
        errorMessage = QStringLiteral("XYZ request failed (%1): %2")
            .arg(statusCode).arg(reply->errorString());
        delete reply;
        return false;
    }
    QByteArray bytes = reply->readAll();
    delete reply;
    if (!image.loadFromData(bytes) || image.isNull()) {
        errorMessage = QStringLiteral("XYZ response is not a valid image: ") + url.toString();
        return false;
    }
    return true;
}

static bool RenderXyzBasemap(const QgsRectangle &webMercatorExtent, int32_t width, int32_t height,
                             int32_t basemapMode, QImage &outputImage, QString &attribution,
                             QString &errorMessage)
{
    if (!IsXyzExportBasemap(basemapMode) || width <= 0 || height <= 0 ||
        webMercatorExtent.isNull() || webMercatorExtent.isEmpty()) {
        errorMessage = QStringLiteral("XYZ basemap parameters are invalid");
        return false;
    }

    const double originShift = 20037508.342789244;
    const double initialResolution = 156543.03392804097;
    const int tileSize = 256;
    double minX = std::max(-originShift, webMercatorExtent.xMinimum());
    double maxX = std::min(originShift, webMercatorExtent.xMaximum());
    double minY = std::max(-originShift, webMercatorExtent.yMinimum());
    double maxY = std::min(originShift, webMercatorExtent.yMaximum());
    if (maxX <= minX || maxY <= minY) {
        errorMessage = QStringLiteral("XYZ basemap extent is outside Web Mercator bounds");
        return false;
    }

    double requestedResolution = std::max((maxX - minX) / static_cast<double>(width),
        (maxY - minY) / static_cast<double>(height));
    int zoom = static_cast<int>(std::round(std::log(initialResolution / requestedResolution) / std::log(2.0)));
    zoom = std::max(1, std::min(XyzMaximumZoom(basemapMode), zoom));

    double worldPixels = 0.0;
    double minPixelX = 0.0;
    double maxPixelX = 0.0;
    double minPixelY = 0.0;
    double maxPixelY = 0.0;
    int startTileX = 0;
    int endTileX = 0;
    int startTileY = 0;
    int endTileY = 0;
    int tileCount = 0;
    while (true) {
        worldPixels = static_cast<double>(tileSize) * std::pow(2.0, zoom);
        minPixelX = (minX + originShift) / (2.0 * originShift) * worldPixels;
        maxPixelX = (maxX + originShift) / (2.0 * originShift) * worldPixels;
        minPixelY = (originShift - maxY) / (2.0 * originShift) * worldPixels;
        maxPixelY = (originShift - minY) / (2.0 * originShift) * worldPixels;
        startTileX = static_cast<int>(std::floor(minPixelX / tileSize));
        endTileX = static_cast<int>(std::floor((maxPixelX - 0.000001) / tileSize));
        startTileY = static_cast<int>(std::floor(minPixelY / tileSize));
        endTileY = static_cast<int>(std::floor((maxPixelY - 0.000001) / tileSize));
        tileCount = std::max(0, endTileX - startTileX + 1) * std::max(0, endTileY - startTileY + 1);
        if (tileCount <= 256 || zoom <= 1) {
            break;
        }
        zoom--;
    }
    if (tileCount <= 0 || tileCount > 256) {
        errorMessage = QStringLiteral("XYZ export requires too many tiles: %1").arg(tileCount);
        return false;
    }

    QNetworkAccessManager manager;
    QNetworkDiskCache *cache = new QNetworkDiskCache(&manager);
    QString cacheDirectory = QDir(QDir::tempPath()).filePath(QStringLiteral("geonest_xyz_cache"));
    QDir().mkpath(cacheDirectory);
    cache->setCacheDirectory(cacheDirectory);
    cache->setMaximumCacheSize(256LL * 1024LL * 1024LL);
    manager.setCache(cache);

    outputImage = QImage(width, height, QImage::Format_ARGB32_Premultiplied);
    outputImage.fill(QColor(255, 255, 255, 0));
    QPainter painter(&outputImage);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
    double scaleX = static_cast<double>(width) / (maxPixelX - minPixelX);
    double scaleY = static_cast<double>(height) / (maxPixelY - minPixelY);
    int matrixSize = static_cast<int>(std::pow(2.0, zoom));
    QString urlTemplate = XyzBasemapTemplate(basemapMode);
    int downloaded = 0;
    for (int tileY = startTileY; tileY <= endTileY; tileY++) {
        if (tileY < 0 || tileY >= matrixSize) {
            painter.end();
            errorMessage = QStringLiteral("XYZ tile row is outside the provider matrix");
            return false;
        }
        for (int tileX = startTileX; tileX <= endTileX; tileX++) {
            int wrappedX = tileX % matrixSize;
            if (wrappedX < 0) {
                wrappedX += matrixSize;
            }
            QString urlText = urlTemplate;
            urlText.replace(QStringLiteral("{z}"), QString::number(zoom));
            urlText.replace(QStringLiteral("{x}"), QString::number(wrappedX));
            urlText.replace(QStringLiteral("{y}"), QString::number(tileY));
            QImage tileImage;
            QString tileError;
            if (!DownloadXyzTile(manager, QUrl(urlText), tileImage, tileError)) {
                painter.end();
                errorMessage = QStringLiteral("XYZ basemap incomplete after %1/%2 tiles: %3")
                    .arg(downloaded).arg(tileCount).arg(tileError);
                return false;
            }
            double left = (static_cast<double>(tileX * tileSize) - minPixelX) * scaleX;
            double top = (static_cast<double>(tileY * tileSize) - minPixelY) * scaleY;
            QRectF target(left, top, static_cast<double>(tileSize) * scaleX,
                static_cast<double>(tileSize) * scaleY);
            painter.drawImage(target, tileImage);
            downloaded++;
        }
    }
    painter.end();
    attribution = XyzBasemapAttribution(basemapMode);
    return true;
}

static void DrawExportBasemap(QPainter &painter, const QRect &mapRect, int32_t basemapMode,
                              const QString &basemapLabel, const QImage &onlineBasemap,
                              const QString &attribution)
{
    painter.save();
    painter.setClipRect(mapRect);
    painter.fillRect(mapRect, QColor("#FBFCFD"));

    if (IsXyzExportBasemap(basemapMode) && !onlineBasemap.isNull()) {
        painter.drawImage(mapRect, onlineBasemap);
    } else if (IsImageryBasemap(basemapMode)) {
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

    if (!attribution.isEmpty()) {
        QRect attributionRect(mapRect.left() + 8, mapRect.bottom() - 30, mapRect.width() - 16, 24);
        painter.fillRect(attributionRect, QColor(255, 255, 255, 220));
        painter.setPen(QPen(QColor("#34423B"), 1));
        painter.setFont(LayoutFont(8, false));
        painter.drawText(attributionRect.adjusted(6, 0, -6, 0),
            Qt::AlignRight | Qt::AlignVCenter, attribution);
    }

    painter.restore();
}

static void DrawLayoutDecorations(QPainter &painter, const QImage &mapImage, const QList<QgsMapLayer *> &layers,
                                  const QString &title, const QString &legendTitleText,
                                  const QString &scaleText, const QString &footerText,
                                  bool showLegend, bool showScaleBar,
                                  bool showNorthArrow, bool showGrid, int32_t width, int32_t height,
                                  int32_t basemapMode, const QString &basemapLabel,
                                  const QImage &onlineBasemap, const QString &attribution,
                                  bool drawBackground, bool drawMapImage, bool drawOverlay)
{
    QRect mapRect(32, 82, width - 64, height - 144);
    if (drawBackground) {
        painter.fillRect(0, 0, width, height, QColor("#ffffff"));
        painter.setPen(QPen(QColor("#17201D"), 2));
        painter.setFont(LayoutFont(24, true));
        painter.drawText(32, 22, width - 64, 44, Qt::AlignLeft | Qt::AlignVCenter, title);
        DrawExportBasemap(painter, mapRect, basemapMode, basemapLabel, onlineBasemap, attribution);
        if (drawMapImage) {
            painter.drawImage(mapRect, mapImage);
        }
    }
    if (!drawOverlay) {
        return;
    }
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

static bool BeginEdit(QgisLayerState *state, const QString &commandText, std::string &message)
{
    QgsVectorLayer *layer = state ? state->layer.get() : nullptr;
    if (!layer) {
        message = "Layer not found";
        return false;
    }
    if (!layer->isEditable() && !layer->startEditing()) {
        message = "QGIS provider is not editable";
        return false;
    }
    if (state->editSessionActive) {
        layer->beginEditCommand(commandText);
        state->editCommandActive = true;
    }
    return true;
}

static void CancelEdit(QgisLayerState *state)
{
    if (!state || !state->layer) {
        return;
    }
    if (state->editSessionActive) {
        if (state->editCommandActive) {
            state->layer->destroyEditCommand();
            state->editCommandActive = false;
        }
        return;
    }
    state->layer->rollBack();
}

static bool CommitEdit(QgisLayerState *state, std::string &message)
{
    QgsVectorLayer *layer = state ? state->layer.get() : nullptr;
    if (!layer) {
        message = "Layer not found";
        return false;
    }
    if (state->editSessionActive) {
        if (state->editCommandActive) {
            layer->endEditCommand();
            state->editCommandActive = false;
        }
        layer->updateExtents();
        layer->triggerRepaint();
        return true;
    }
    if (!layer->commitChanges()) {
        message = CommitErrors(layer);
        layer->rollBack();
        return false;
    }
    layer->updateExtents();
    layer->triggerRepaint();
    return true;
}

struct ParsedCoordinate {
    double x = 0.0;
    double y = 0.0;
    double z = 0.0;
    double m = 0.0;
    bool hasZ = false;
    bool hasM = false;
};

static std::vector<ParsedCoordinate> ParseCoordText(const char *coordsText)
{
    std::vector<ParsedCoordinate> points;
    if (!coordsText) {
        return points;
    }
    QStringList coordinateItems = QString::fromUtf8(coordsText).split(';', Qt::SkipEmptyParts);
    for (int i = 0; i < coordinateItems.size(); i++) {
        QStringList values = coordinateItems.at(i).split(',');
        if (values.size() < 2) {
            continue;
        }
        bool xOk = false;
        bool yOk = false;
        ParsedCoordinate coordinate;
        coordinate.x = values.at(0).toDouble(&xOk);
        coordinate.y = values.at(1).toDouble(&yOk);
        if (!xOk || !yOk) {
            continue;
        }
        if (values.size() >= 4) {
            bool zOk = false;
            bool mOk = false;
            coordinate.z = values.at(2).toDouble(&zOk);
            coordinate.m = values.at(3).toDouble(&mOk);
            coordinate.hasZ = zOk && (values.size() < 5 || values.at(4).toInt() != 0);
            coordinate.hasM = mOk && (values.size() < 6 || values.at(5).toInt() != 0);
        } else if (values.size() == 3) {
            bool zOk = false;
            coordinate.z = values.at(2).toDouble(&zOk);
            coordinate.hasZ = zOk;
        }
        points.push_back(coordinate);
    }
    return points;
}

static bool SamePoint(const QgsPointXY &a, const QgsPointXY &b)
{
    return a.x() == b.x() && a.y() == b.y();
}

static QString CoordinateWkt(const ParsedCoordinate &point, bool hasZ, bool hasM)
{
    QString text = QString::number(point.x, 'g', 17) + " " + QString::number(point.y, 'g', 17);
    if (hasZ) {
        text += " " + QString::number(point.hasZ ? point.z : 0.0, 'g', 17);
    }
    if (hasM) {
        text += " " + QString::number(point.hasM ? point.m : 0.0, 'g', 17);
    }
    return text;
}

static QgsGeometry GeometryFromPoints(int32_t geometryType, const std::vector<ParsedCoordinate> &points,
                                      Qgis::WkbType layerWkbType)
{
    size_t minimumPoints = geometryType == GEOM_POINT ? 1 : (geometryType == GEOM_LINESTRING ? 2 : 3);
    if (points.size() < minimumPoints) {
        return QgsGeometry();
    }
    bool hasZ = QgsWkbTypes::hasZ(layerWkbType);
    bool hasM = QgsWkbTypes::hasM(layerWkbType);
    QString dimension = hasZ && hasM ? " ZM" : (hasZ ? " Z" : (hasM ? " M" : ""));
    QString coordinates;
    size_t count = geometryType == GEOM_POINT ? 1 : points.size();
    for (size_t i = 0; i < count; i++) {
        if (i > 0) {
            coordinates += ",";
        }
        coordinates += CoordinateWkt(points[i], hasZ, hasM);
    }
    if (geometryType == GEOM_POLYGON) {
        const ParsedCoordinate &first = points.front();
        const ParsedCoordinate &last = points.back();
        if (first.x != last.x || first.y != last.y) {
            coordinates += "," + CoordinateWkt(first, hasZ, hasM);
        }
    }
    QString wkt;
    if (geometryType == GEOM_POINT) {
        wkt = "POINT" + dimension + " (" + coordinates + ")";
    } else if (geometryType == GEOM_LINESTRING) {
        wkt = "LINESTRING" + dimension + " (" + coordinates + ")";
    } else if (geometryType == GEOM_POLYGON) {
        wkt = "POLYGON" + dimension + " ((" + coordinates + "))";
    }
    QgsGeometry geometry = QgsGeometry::fromWkt(wkt);
    if (!geometry.isNull() && QgsWkbTypes::isMultiType(layerWkbType)) {
        geometry.convertToMultiType();
    }
    return geometry;
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
    if (geometry.constGet() == nullptr || partIndex < 0 || pointIndex < 0) {
        message = "Invalid geometry node";
        return false;
    }
    QgsCoordinateSequence sequence = geometry.constGet()->coordinateSequence();
    int flattenedPart = 0;
    QgsVertexId vertexId;
    int selectedRingSize = 0;
    bool found = false;
    for (int pi = 0; pi < sequence.size() && !found; pi++) {
        QgsRingSequence rings = sequence.at(pi);
        for (int ri = 0; ri < rings.size() && !found; ri++) {
            QgsPointSequence ring = rings.at(ri);
            if (geometryType == GEOM_POINT) {
                if (partIndex == 0 && pointIndex >= flattenedPart && pointIndex < flattenedPart + ring.size()) {
                    vertexId = QgsVertexId(pi, ri, pointIndex - flattenedPart);
                    selectedRingSize = ring.size();
                    found = true;
                }
                flattenedPart += ring.size();
            } else {
                if (flattenedPart == partIndex && pointIndex < ring.size()) {
                    vertexId = QgsVertexId(pi, ri, pointIndex);
                    selectedRingSize = ring.size();
                    found = true;
                }
                flattenedPart++;
            }
        }
    }
    if (!found) {
        message = "Invalid geometry node";
        return false;
    }
    if (deleteNode) {
        if (geometryType == GEOM_POINT) {
            message = "Point feature has no removable node";
            return false;
        }
        if (geometryType == GEOM_LINESTRING && selectedRingSize <= 2) {
            message = "Line must keep at least two nodes";
            return false;
        }
        if (geometryType == GEOM_POLYGON) {
            if (selectedRingSize <= 4) {
                message = "Polygon ring must keep at least three nodes";
                return false;
            }
            if (vertexId.vertex == 0 || vertexId.vertex == selectedRingSize - 1) {
                message = "Cannot delete closing polygon node";
                return false;
            }
        }
    }
    int vertexNumber = geometry.vertexNrFromVertexId(vertexId);
    if (vertexNumber < 0) {
        message = "QGIS could not resolve geometry vertex";
        return false;
    }
    if (deleteNode) {
        if (!geometry.deleteVertex(vertexNumber)) {
            message = "QGIS could not delete geometry vertex";
            return false;
        }
        return true;
    }
    QgsPoint target = geometry.vertexAt(vertexNumber);
    target.setX(x);
    target.setY(y);
    if (!geometry.moveVertex(target, vertexNumber)) {
        message = "QGIS could not move geometry vertex";
        return false;
    }
    return true;
}

static KernelDensityOptions ParseKernelDensityOptions(const char *textValue)
{
    KernelDensityOptions options;
    options.cellSize = 0.0;
    options.populationField = QStringLiteral("NONE");
    options.areaUnit = QStringLiteral("SQUARE_MAP_UNITS");

    QString text = QString::fromUtf8(textValue ? textValue : "");
    QStringList parts = text.split(';', Qt::SkipEmptyParts);
    for (int i = 0; i < parts.size(); i++) {
        QString item = parts.at(i).trimmed();
        int eqIndex = item.indexOf('=');
        if (eqIndex <= 0) {
            continue;
        }
        QString key = item.left(eqIndex).trimmed().toLower();
        QString value = item.mid(eqIndex + 1).trimmed();
        if (key == QStringLiteral("cellsize")) {
            bool ok = false;
            double parsed = value.toDouble(&ok);
            if (ok) {
                options.cellSize = parsed;
            }
        } else if (key == QStringLiteral("populationfield")) {
            options.populationField = value.length() > 0 ? value : QStringLiteral("NONE");
        } else if (key == QStringLiteral("areaunit")) {
            options.areaUnit = value.length() > 0 ? value : QStringLiteral("SQUARE_MAP_UNITS");
        }
    }
    return options;
}

static XYTableOptions ParseXYTableOptions(const char *textValue)
{
    XYTableOptions options;
    QByteArray text = QByteArray(textValue ? textValue : "");
    QJsonParseError parseError;
    QJsonDocument document = QJsonDocument::fromJson(text, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        return options;
    }
    QJsonObject object = document.object();
    options.xFieldIndex = object.value(QStringLiteral("xFieldIndex")).toInt(-1);
    options.yFieldIndex = object.value(QStringLiteral("yFieldIndex")).toInt(-1);
    options.zFieldIndex = object.value(QStringLiteral("zFieldIndex")).toInt(-1);
    options.mFieldIndex = object.value(QStringLiteral("mFieldIndex")).toInt(-1);
    QString crsDefinition = object.value(QStringLiteral("crsDefinition")).toString().trimmed();
    if (!crsDefinition.isEmpty()) {
        options.crsDefinition = crsDefinition;
    }
    return options;
}

static IdwOptions ParseIdwOptions(const char *textValue)
{
    IdwOptions options;
    options.cellSize = 0.0;
    options.power = 2.0;
    options.valueField = QStringLiteral("NONE");

    QString text = QString::fromUtf8(textValue ? textValue : "");
    QStringList parts = text.split(';', Qt::SkipEmptyParts);
    for (int i = 0; i < parts.size(); i++) {
        QString item = parts.at(i).trimmed();
        int eqIndex = item.indexOf('=');
        if (eqIndex <= 0) {
            continue;
        }
        QString key = item.left(eqIndex).trimmed().toLower();
        QString value = item.mid(eqIndex + 1).trimmed();
        if (key == QStringLiteral("cellsize")) {
            bool ok = false;
            double parsed = value.toDouble(&ok);
            if (ok) {
                options.cellSize = parsed;
            }
        } else if (key == QStringLiteral("power")) {
            bool ok = false;
            double parsed = value.toDouble(&ok);
            if (ok) {
                options.power = parsed;
            }
        } else if (key == QStringLiteral("valuefield") || key == QStringLiteral("zfield") ||
            key == QStringLiteral("populationfield")) {
            options.valueField = value.length() > 0 ? value : QStringLiteral("NONE");
        }
    }
    return options;
}

static double DistanceUnitMeters(Qgis::DistanceUnit unit)
{
    if (unit == Qgis::DistanceUnit::Kilometers) {
        return 1000.0;
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
        return 0.3048;
    }
    if (unit == Qgis::DistanceUnit::Yards || unit == Qgis::DistanceUnit::YardsBritishBenoit1895A ||
        unit == Qgis::DistanceUnit::YardsBritishBenoit1895B ||
        unit == Qgis::DistanceUnit::YardsBritishSears1922Truncated ||
        unit == Qgis::DistanceUnit::YardsBritishSears1922 ||
        unit == Qgis::DistanceUnit::YardsClarkes || unit == Qgis::DistanceUnit::YardsIndian ||
        unit == Qgis::DistanceUnit::YardsIndian1937 || unit == Qgis::DistanceUnit::YardsIndian1962 ||
        unit == Qgis::DistanceUnit::YardsIndian1975) {
        return 0.9144;
    }
    return 1.0;
}

static double KernelDensityAreaScale(Qgis::DistanceUnit mapUnit, const QString &areaUnit)
{
    QString unit = areaUnit.trimmed().toUpper();
    if (unit.length() == 0 || unit == QStringLiteral("SQUARE_MAP_UNITS") ||
        unit == QStringLiteral("MAP_UNITS")) {
        return 1.0;
    }

    double targetAreaMeters = 1.0;
    if (unit == QStringLiteral("SQUARE_KILOMETERS") || unit == QStringLiteral("SQ_KM") ||
        unit == QStringLiteral("KM2")) {
        targetAreaMeters = 1000000.0;
    } else if (unit == QStringLiteral("HECTARES") || unit == QStringLiteral("HECTARE") ||
        unit == QStringLiteral("HA")) {
        targetAreaMeters = 10000.0;
    } else if (unit == QStringLiteral("SQUARE_MILES") || unit == QStringLiteral("SQ_MI") ||
        unit == QStringLiteral("MI2")) {
        targetAreaMeters = 2589988.110336;
    } else if (unit == QStringLiteral("ACRES") || unit == QStringLiteral("ACRE")) {
        targetAreaMeters = 4046.8564224;
    } else {
        targetAreaMeters = 1.0;
    }

    double mapUnitMeters = DistanceUnitMeters(mapUnit);
    if (mapUnitMeters <= 0.0) {
        return 1.0;
    }
    return targetAreaMeters / (mapUnitMeters * mapUnitMeters);
}

static double LineDensityScale(Qgis::DistanceUnit mapUnit, const QString &areaUnit)
{
    QString unit = areaUnit.trimmed().toUpper();
    if (unit.length() == 0 || unit == QStringLiteral("SQUARE_MAP_UNITS") ||
        unit == QStringLiteral("MAP_UNITS")) {
        return 1.0;
    }

    double targetAreaMeters = 1.0;
    double targetLengthMeters = 1.0;
    if (unit == QStringLiteral("SQUARE_KILOMETERS") || unit == QStringLiteral("SQ_KM") ||
        unit == QStringLiteral("KM2")) {
        targetAreaMeters = 1000000.0;
        targetLengthMeters = 1000.0;
    } else if (unit == QStringLiteral("HECTARES") || unit == QStringLiteral("HECTARE") ||
        unit == QStringLiteral("HA")) {
        targetAreaMeters = 10000.0;
        targetLengthMeters = 1.0;
    } else if (unit == QStringLiteral("SQUARE_MILES") || unit == QStringLiteral("SQ_MI") ||
        unit == QStringLiteral("MI2")) {
        targetAreaMeters = 2589988.110336;
        targetLengthMeters = 1609.344;
    } else if (unit == QStringLiteral("ACRES") || unit == QStringLiteral("ACRE")) {
        targetAreaMeters = 4046.8564224;
        targetLengthMeters = 1.0;
    } else {
        targetAreaMeters = 1.0;
        targetLengthMeters = 1.0;
    }

    double mapUnitMeters = DistanceUnitMeters(mapUnit);
    if (mapUnitMeters <= 0.0 || targetLengthMeters <= 0.0) {
        return 1.0;
    }
    return mapUnitMeters * targetAreaMeters / targetLengthMeters;
}

static void AppendKernelPoint(const QgsPointXY &point, double weight, std::vector<KernelDensityPoint> &points)
{
    if (weight <= 0.0) {
        return;
    }
    KernelDensityPoint item;
    item.x = point.x();
    item.y = point.y();
    item.weight = weight;
    points.push_back(item);
}

static void CollectKernelDensityPoints(const QgsGeometry &geometry, double weight,
                                       std::vector<KernelDensityPoint> &points)
{
    if (geometry.isNull() || geometry.isEmpty() || weight <= 0.0) {
        return;
    }
    if (geometry.isMultipart()) {
        QgsMultiPointXY multiPoints = geometry.asMultiPoint();
        for (int i = 0; i < multiPoints.size(); i++) {
            AppendKernelPoint(multiPoints.at(i), weight, points);
        }
        return;
    }
    AppendKernelPoint(geometry.asPoint(), weight, points);
}

static void AppendLineDensitySegment(const QgsPointXY &start, const QgsPointXY &end, double weight,
                                     std::vector<LineDensitySegment> &segments)
{
    if (weight <= 0.0) {
        return;
    }
    double dx = end.x() - start.x();
    double dy = end.y() - start.y();
    double length = std::sqrt(dx * dx + dy * dy);
    if (length <= 0.0) {
        return;
    }
    LineDensitySegment segment;
    segment.x1 = start.x();
    segment.y1 = start.y();
    segment.x2 = end.x();
    segment.y2 = end.y();
    segment.length = length;
    segment.weight = weight;
    segments.push_back(segment);
}

static void AppendLineDensityPolyline(const QgsPolylineXY &line, double weight,
                                      std::vector<LineDensitySegment> &segments)
{
    if (line.size() < 2 || weight <= 0.0) {
        return;
    }
    for (int i = 1; i < line.size(); i++) {
        AppendLineDensitySegment(line.at(i - 1), line.at(i), weight, segments);
    }
}

static void CollectLineDensitySegments(const QgsGeometry &geometry, double weight,
                                       std::vector<LineDensitySegment> &segments)
{
    if (geometry.isNull() || geometry.isEmpty() || weight <= 0.0) {
        return;
    }
    if (geometry.isMultipart()) {
        QgsMultiPolylineXY lines = geometry.asMultiPolyline();
        for (int i = 0; i < lines.size(); i++) {
            AppendLineDensityPolyline(lines.at(i), weight, segments);
        }
        return;
    }
    AppendLineDensityPolyline(geometry.asPolyline(), weight, segments);
}

static double SegmentLengthInsideCircle(const LineDensitySegment &segment, double centerX, double centerY,
                                        double radius)
{
    double dx = segment.x2 - segment.x1;
    double dy = segment.y2 - segment.y1;
    double fx = segment.x1 - centerX;
    double fy = segment.y1 - centerY;
    double a = dx * dx + dy * dy;
    if (a <= 0.0) {
        return 0.0;
    }
    double b = 2.0 * (fx * dx + fy * dy);
    double c = fx * fx + fy * fy - radius * radius;
    double discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0) {
        if (c <= 0.0) {
            return segment.length;
        }
        return 0.0;
    }
    double sqrtDiscriminant = std::sqrt(discriminant);
    double t1 = (-b - sqrtDiscriminant) / (2.0 * a);
    double t2 = (-b + sqrtDiscriminant) / (2.0 * a);
    double lower = std::max(0.0, std::min(t1, t2));
    double upper = std::min(1.0, std::max(t1, t2));
    if (upper <= lower) {
        return 0.0;
    }
    return (upper - lower) * segment.length;
}

static double KernelDensityWeight(const QgsFeature &feature, int populationFieldIndex, bool usePopulationField)
{
    if (!usePopulationField) {
        return 1.0;
    }
    QVariant value = feature.attribute(populationFieldIndex);
    if (!value.isValid() || value.isNull()) {
        return 0.0;
    }
    bool ok = false;
    double weight = value.toDouble(&ok);
    if (!ok || weight <= 0.0) {
        return 0.0;
    }
    return weight;
}

static void CollectIdwPoints(const QgsGeometry &geometry, double value, std::vector<IdwPoint> &points)
{
    if (geometry.isNull() || geometry.isEmpty()) {
        return;
    }
    if (geometry.isMultipart()) {
        QgsMultiPointXY multiPoints = geometry.asMultiPoint();
        for (int i = 0; i < multiPoints.size(); i++) {
            IdwPoint point;
            point.x = multiPoints.at(i).x();
            point.y = multiPoints.at(i).y();
            point.value = value;
            points.push_back(point);
        }
        return;
    }
    QgsPointXY sourcePoint = geometry.asPoint();
    IdwPoint point;
    point.x = sourcePoint.x();
    point.y = sourcePoint.y();
    point.value = value;
    points.push_back(point);
}

static double KernelDensityDefaultSearchRadius(const std::vector<KernelDensityPoint> &points,
                                               const QgsRectangle &extent)
{
    double totalWeight = 0.0;
    double meanX = 0.0;
    double meanY = 0.0;
    for (size_t i = 0; i < points.size(); i++) {
        totalWeight += points[i].weight;
        meanX += points[i].x * points[i].weight;
        meanY += points[i].y * points[i].weight;
    }
    if (totalWeight <= 0.0) {
        return std::max(extent.width(), extent.height()) / 30.0;
    }
    meanX /= totalWeight;
    meanY /= totalWeight;

    std::vector<WeightedDistance> distances;
    distances.reserve(points.size());
    double weightedDistanceSum = 0.0;
    for (size_t i = 0; i < points.size(); i++) {
        double dx = points[i].x - meanX;
        double dy = points[i].y - meanY;
        double distance = std::sqrt(dx * dx + dy * dy);
        WeightedDistance item;
        item.distance = distance;
        item.weight = points[i].weight;
        distances.push_back(item);
        weightedDistanceSum += points[i].weight * distance * distance;
    }
    std::sort(distances.begin(), distances.end(),
        [](const WeightedDistance &left, const WeightedDistance &right) {
            return left.distance < right.distance;
        });
    double medianDistance = distances[distances.size() / 2].distance;
    double runningWeight = 0.0;
    double medianTarget = totalWeight / 2.0;
    for (size_t i = 0; i < distances.size(); i++) {
        runningWeight += distances[i].weight;
        if (runningWeight >= medianTarget) {
            medianDistance = distances[i].distance;
            break;
        }
    }
    double standardDistance = std::sqrt(weightedDistanceSum / totalWeight);
    double robustDistance = std::sqrt(1.0 / std::log(2.0)) * medianDistance;
    double baseDistance = std::min(standardDistance, robustDistance);
    double radius = 0.9 * baseDistance * std::pow(totalWeight, -0.2);
    if (radius <= 0.0) {
        radius = std::max(extent.width(), extent.height()) / 30.0;
    }
    if (radius <= 0.0) {
        radius = 1.0;
    }
    return radius;
}

static double KernelDensityDefaultCellSize(const QgsRectangle &extent, double radius)
{
    double width = std::abs(extent.width());
    double height = std::abs(extent.height());
    double shorterSide = width > 0.0 && height > 0.0 ? std::min(width, height) : std::max(width, height);
    double cellSize = shorterSide / 250.0;
    if (cellSize <= 0.0) {
        cellSize = radius / 8.0;
    }
    if (cellSize <= 0.0) {
        cellSize = 1.0;
    }
    return cellSize;
}

static bool WriteKernelDensityAsciiGrid(const QString &outputPath, const QgsCoordinateReferenceSystem &crs,
                                        const QgsRectangle &extent, int cols, int rows, double cellSize,
                                        const std::vector<double> &values, std::string &message)
{
    QFileInfo fileInfo(outputPath);
    QDir parentDir = fileInfo.absoluteDir();
    if (!parentDir.exists() && !parentDir.mkpath(QStringLiteral("."))) {
        message = "Cannot create raster output directory";
        return false;
    }

    QFile file(outputPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        message = "Cannot open raster output for writing";
        return false;
    }

    QTextStream stream(&file);
    stream.setRealNumberNotation(QTextStream::FixedNotation);
    stream.setRealNumberPrecision(8);
    stream << "ncols " << cols << "\n";
    stream << "nrows " << rows << "\n";
    stream << "xllcorner " << extent.xMinimum() << "\n";
    stream << "yllcorner " << extent.yMinimum() << "\n";
    stream << "cellsize " << cellSize << "\n";
    stream << "NODATA_value -9999\n";
    for (int row = 0; row < rows; row++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        for (int col = 0; col < cols; col++) {
            if (col > 0) {
                stream << ' ';
            }
            stream << values[static_cast<size_t>(row * cols + col)];
        }
        stream << "\n";
    }
    file.close();

    if (crs.isValid()) {
        QString prjPath = outputPath;
        int dotIndex = prjPath.lastIndexOf('.');
        if (dotIndex > 0) {
            prjPath = prjPath.left(dotIndex);
        }
        prjPath += QStringLiteral(".prj");
        QFile prjFile(prjPath);
        if (prjFile.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
            QTextStream prjStream(&prjFile);
            prjStream << crs.toWkt();
            prjFile.close();
        }
    }
    return true;
}

static bool ReadRasterBandValues(QgsRasterLayer *layer, int bandNo, std::vector<double> &values,
                                 int &cols, int &rows, QgsRectangle &extent, std::string &message)
{
    if (!layer) {
        message = "Raster layer not found";
        return false;
    }
    QgsRasterDataProvider *provider = layer->dataProvider();
    if (!provider || provider->bandCount() < bandNo) {
        message = "Raster provider has no requested band";
        return false;
    }

    cols = provider->xSize();
    rows = provider->ySize();
    extent = provider->extent();
    if (cols <= 1 || rows <= 1 || extent.isEmpty()) {
        message = "Raster dimensions are invalid";
        return false;
    }

    std::unique_ptr<QgsRasterBlock> block(provider->block(bandNo, extent, cols, rows));
    if (!block || block->width() != cols || block->height() != rows) {
        message = "Failed to read raster band block";
        return false;
    }
    if (ProcessingCancellationRequested()) {
        message = "Processing canceled";
        return false;
    }

    values.assign(static_cast<size_t>(cols * rows), -9999.0);
    for (int row = 0; row < rows; row++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        for (int col = 0; col < cols; col++) {
            bool isNoData = false;
            double value = block->valueAndNoData(row, col, isNoData);
            if (!isNoData && std::isfinite(value)) {
                values[static_cast<size_t>(row * cols + col)] = value;
            }
        }
    }
    if (ProcessingCancellationRequested()) {
        values.clear();
        message = "Processing canceled";
        return false;
    }
    return true;
}

static bool RasterValueIsValid(const std::vector<double> &values, int cols, int row, int col)
{
    double value = values[static_cast<size_t>(row * cols + col)];
    return std::isfinite(value) && value != -9999.0;
}

static bool WriteRasterAnalysisGrid(const QString &outputPath, const QgsCoordinateReferenceSystem &crs,
                                    const QgsRectangle &extent, int cols, int rows,
                                    const std::vector<double> &values, std::string &message)
{
    double cellWidth = std::abs(extent.width()) / static_cast<double>(cols);
    double cellHeight = std::abs(extent.height()) / static_cast<double>(rows);
    double cellSize = (cellWidth + cellHeight) / 2.0;
    if (cellSize <= 0.0) {
        message = "Raster cell size is invalid";
        return false;
    }
    return WriteKernelDensityAsciiGrid(outputPath, crs, extent, cols, rows, cellSize, values, message);
}

static const char *RasterTerrainAnalysisLayer(LayerHandle handle, bool aspectMode, double zFactor,
                                              const char *outputPath, const char *outputLayerName,
                                              int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0 || zFactor <= 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid raster terrain parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgisRasterState *state = FindRasterLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Raster layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::vector<double> sourceValues;
    int cols = 0;
    int rows = 0;
    QgsRectangle extent;
    std::string readMessage;
    if (!ReadRasterBandValues(state->layer.get(), 1, sourceValues, cols, rows, extent, readMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT, readMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    double cellWidth = std::abs(extent.width()) / static_cast<double>(cols);
    double cellHeight = std::abs(extent.height()) / static_cast<double>(rows);
    if (cellWidth <= 0.0 || cellHeight <= 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT, "Raster cell size is invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    const double radiansToDegrees = 57.29577951308232;
    std::vector<double> outputValues(static_cast<size_t>(cols * rows), -9999.0);
    int validCells = 0;
    for (int row = 1; row < rows - 1; row++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        for (int col = 1; col < cols - 1; col++) {
            bool allValid = true;
            for (int rr = row - 1; rr <= row + 1; rr++) {
                for (int cc = col - 1; cc <= col + 1; cc++) {
                    if (!RasterValueIsValid(sourceValues, cols, rr, cc)) {
                        allValid = false;
                    }
                }
            }
            if (!allValid) {
                continue;
            }

            double z1 = sourceValues[static_cast<size_t>((row - 1) * cols + col - 1)] * zFactor;
            double z2 = sourceValues[static_cast<size_t>((row - 1) * cols + col)] * zFactor;
            double z3 = sourceValues[static_cast<size_t>((row - 1) * cols + col + 1)] * zFactor;
            double z4 = sourceValues[static_cast<size_t>(row * cols + col - 1)] * zFactor;
            double z6 = sourceValues[static_cast<size_t>(row * cols + col + 1)] * zFactor;
            double z7 = sourceValues[static_cast<size_t>((row + 1) * cols + col - 1)] * zFactor;
            double z8 = sourceValues[static_cast<size_t>((row + 1) * cols + col)] * zFactor;
            double z9 = sourceValues[static_cast<size_t>((row + 1) * cols + col + 1)] * zFactor;
            double dzdx = ((z3 + 2.0 * z6 + z9) - (z1 + 2.0 * z4 + z7)) / (8.0 * cellWidth);
            double dzdy = ((z7 + 2.0 * z8 + z9) - (z1 + 2.0 * z2 + z3)) / (8.0 * cellHeight);
            double resultValue = std::atan(std::sqrt(dzdx * dzdx + dzdy * dzdy)) * radiansToDegrees;
            if (aspectMode) {
                if (std::abs(dzdx) < 0.000000001 && std::abs(dzdy) < 0.000000001) {
                    resultValue = 0.0;
                } else {
                    resultValue = 90.0 - (std::atan2(dzdy, -dzdx) * radiansToDegrees);
                    while (resultValue < 0.0) {
                        resultValue += 360.0;
                    }
                    while (resultValue >= 360.0) {
                        resultValue -= 360.0;
                    }
                }
            }
            outputValues[static_cast<size_t>(row * cols + col)] = resultValue;
            validCells++;
        }
    }

    std::string writeMessage;
    QString outPath = QString::fromUtf8(outputPath);
    if (!WriteRasterAnalysisGrid(outPath, state->layer->crs(), extent, cols, rows, outputValues, writeMessage)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, writeMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::string message = aspectMode ? "Raster aspect completed" : "Raster slope completed";
    message += "; cells=";
    message += std::to_string(validCells);
    return MakeProcessResult(true, GIS_OK, message,
        outputPath, outputLayerName ? outputLayerName : "", validCells, outErrCode);
}

enum class SurfaceRasterMode {
    CanopyHeight,
    Earthwork,
    SurfaceArea
};

static const char *SurfaceRasterAnalysisLayer(LayerHandle inputHandle, LayerHandle overlayHandle,
                                               SurfaceRasterMode mode, double numericValue,
                                               const char *outputPath, const char *outputLayerName,
                                               int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid surface output path",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisRasterState *inputState = FindRasterLayer(inputHandle);
    if (!inputState || !inputState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input elevation raster not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<double> inputValues;
    int cols = 0;
    int rows = 0;
    QgsRectangle extent;
    std::string message;
    if (!ReadRasterBandValues(inputState->layer.get(), 1, inputValues, cols, rows, extent, message)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::vector<double> overlayValues;
    if (mode == SurfaceRasterMode::CanopyHeight) {
        QgisRasterState *overlayState = FindRasterLayer(overlayHandle);
        int overlayCols = 0;
        int overlayRows = 0;
        QgsRectangle overlayExtent;
        if (!overlayState || !overlayState->layer ||
            !ReadRasterBandValues(overlayState->layer.get(), 1, overlayValues, overlayCols, overlayRows,
                overlayExtent, message)) {
            return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "DTM raster not found or unreadable",
                outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
        }
        double tolerance = std::max(std::abs(extent.width()), std::abs(extent.height())) * 0.000000001;
        if (overlayCols != cols || overlayRows != rows ||
            std::abs(overlayExtent.xMinimum() - extent.xMinimum()) > tolerance ||
            std::abs(overlayExtent.yMinimum() - extent.yMinimum()) > tolerance ||
            std::abs(overlayExtent.xMaximum() - extent.xMaximum()) > tolerance ||
            std::abs(overlayExtent.yMaximum() - extent.yMaximum()) > tolerance) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
                "DSM and DTM must use the same extent and raster dimensions", outputPath,
                outputLayerName ? outputLayerName : "", 0, outErrCode);
        }
    }

    double cellWidth = std::abs(extent.width()) / static_cast<double>(cols);
    double cellHeight = std::abs(extent.height()) / static_cast<double>(rows);
    double planarCellArea = cellWidth * cellHeight;
    std::vector<double> outputValues(static_cast<size_t>(cols * rows), -9999.0);
    double cutVolume = 0.0;
    double fillVolume = 0.0;
    double totalSurfaceArea = 0.0;
    int validCells = 0;
    for (int row = 0; row < rows; row++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        for (int col = 0; col < cols; col++) {
            if (!RasterValueIsValid(inputValues, cols, row, col)) {
                continue;
            }
            size_t index = static_cast<size_t>(row * cols + col);
            double outputValue = 0.0;
            if (mode == SurfaceRasterMode::CanopyHeight) {
                if (!RasterValueIsValid(overlayValues, cols, row, col)) {
                    continue;
                }
                outputValue = std::max(0.0, inputValues[index] - overlayValues[index]);
            } else if (mode == SurfaceRasterMode::Earthwork) {
                outputValue = inputValues[index] - numericValue;
                if (outputValue >= 0.0) {
                    cutVolume += outputValue * planarCellArea;
                } else {
                    fillVolume += -outputValue * planarCellArea;
                }
            } else {
                if (row <= 0 || col <= 0 || row >= rows - 1 || col >= cols - 1 ||
                    !RasterValueIsValid(inputValues, cols, row, col - 1) ||
                    !RasterValueIsValid(inputValues, cols, row, col + 1) ||
                    !RasterValueIsValid(inputValues, cols, row - 1, col) ||
                    !RasterValueIsValid(inputValues, cols, row + 1, col)) {
                    continue;
                }
                double dzdx = (inputValues[index + 1] - inputValues[index - 1]) / (2.0 * cellWidth);
                double dzdy = (inputValues[index + static_cast<size_t>(cols)] -
                    inputValues[index - static_cast<size_t>(cols)]) / (2.0 * cellHeight);
                outputValue = planarCellArea * std::sqrt(1.0 + dzdx * dzdx + dzdy * dzdy);
                totalSurfaceArea += outputValue;
            }
            outputValues[index] = outputValue;
            validCells++;
        }
    }
    if (ProcessingCancellationRequested()) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Processing canceled", outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    if (!WriteRasterAnalysisGrid(QString::fromUtf8(outputPath), inputState->layer->crs(), extent,
        cols, rows, outputValues, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    if (mode == SurfaceRasterMode::CanopyHeight) {
        message = "CHM completed (DSM minus DTM); cells=" + std::to_string(validCells);
    } else if (mode == SurfaceRasterMode::Earthwork) {
        message = "Earthwork completed; cut=" + std::to_string(cutVolume) +
            "; fill=" + std::to_string(fillVolume) +
            "; net=" + std::to_string(cutVolume - fillVolume);
    } else {
        message = "Surface area completed; area=" + std::to_string(totalSurfaceArea);
    }
    return MakeProcessResult(true, GIS_OK, message, outputPath,
        outputLayerName ? outputLayerName : "", validCells, outErrCode);
}

struct RasterLineOptions {
    double startX = 0.0;
    double startY = 0.0;
    double endX = 0.0;
    double endY = 0.0;
    double observerHeight = 1.7;
    double targetHeight = 0.0;
};

static bool ParseRasterLineOptions(const char *textValue, const QgsRectangle &extent,
                                   RasterLineOptions &options, std::string &message)
{
    options.startX = extent.xMinimum();
    options.startY = extent.yMinimum();
    options.endX = extent.xMaximum();
    options.endY = extent.yMaximum();
    QString text = QString::fromUtf8(textValue ? textValue : "").trimmed();
    if (text.isEmpty()) {
        return true;
    }
    QStringList values = text.split(',', Qt::SkipEmptyParts);
    if (values.size() < 4) {
        message = "Line coordinates must use startX,startY,endX,endY[,observerHeight,targetHeight]";
        return false;
    }
    bool valid = false;
    options.startX = values.at(0).trimmed().toDouble(&valid);
    if (!valid) { message = "Invalid profile start X"; return false; }
    options.startY = values.at(1).trimmed().toDouble(&valid);
    if (!valid) { message = "Invalid profile start Y"; return false; }
    options.endX = values.at(2).trimmed().toDouble(&valid);
    if (!valid) { message = "Invalid profile end X"; return false; }
    options.endY = values.at(3).trimmed().toDouble(&valid);
    if (!valid) { message = "Invalid profile end Y"; return false; }
    if (values.size() >= 5) {
        options.observerHeight = values.at(4).trimmed().toDouble(&valid);
        if (!valid) { message = "Invalid observer height"; return false; }
    }
    if (values.size() >= 6) {
        options.targetHeight = values.at(5).trimmed().toDouble(&valid);
        if (!valid) { message = "Invalid target height"; return false; }
    }
    if (!extent.contains(options.startX, options.startY) || !extent.contains(options.endX, options.endY)) {
        message = "Profile endpoints must be inside the raster extent";
        return false;
    }
    return true;
}

static bool RasterCellAtCoordinate(const std::vector<double> &values, int cols, int rows,
                                   const QgsRectangle &extent, double x, double y,
                                   int &row, int &col, double &elevation)
{
    double colValue = (x - extent.xMinimum()) / extent.width() * static_cast<double>(cols);
    double rowValue = (extent.yMaximum() - y) / extent.height() * static_cast<double>(rows);
    col = std::max(0, std::min(cols - 1, static_cast<int>(std::floor(colValue))));
    row = std::max(0, std::min(rows - 1, static_cast<int>(std::floor(rowValue))));
    if (!RasterValueIsValid(values, cols, row, col)) {
        return false;
    }
    elevation = values[static_cast<size_t>(row * cols + col)];
    return true;
}

static const char *RasterProfileLayer(LayerHandle handle, int sampleCount, const char *textValue,
                                      const char *outputPath, const char *outputLayerName,
                                      int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisRasterState *state = FindRasterLayer(handle);
    if (!state || !state->layer || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Profile raster or output path is invalid",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<double> values;
    int cols = 0;
    int rows = 0;
    QgsRectangle extent;
    std::string message;
    if (!ReadRasterBandValues(state->layer.get(), 1, values, cols, rows, extent, message)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    RasterLineOptions options;
    if (!ParseRasterLineOptions(textValue, extent, options, message)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    if (sampleCount < 2) {
        double cellWidth = extent.width() / static_cast<double>(cols);
        double cellHeight = extent.height() / static_cast<double>(rows);
        double lineLength = std::hypot(options.endX - options.startX, options.endY - options.startY);
        sampleCount = static_cast<int>(std::ceil(lineLength / std::min(cellWidth, cellHeight))) + 1;
    }
    sampleCount = std::max(2, std::min(100000, sampleCount));
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("station"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("elevation"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("x"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("y"), QVariant::Double));
    QgsVectorFileWriter::SaveVectorOptions writerOptions;
    writerOptions.driverName = QStringLiteral("ESRI Shapefile");
    writerOptions.layerName = outputLayerName && std::strlen(outputLayerName) > 0
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("terrain_profile");
    writerOptions.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(QString::fromUtf8(outputPath), fields,
        Qgis::WkbType::PointZ, state->layer->crs(), QgsCoordinateTransformContext(), writerOptions));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create terrain profile output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    double totalDistance = std::hypot(options.endX - options.startX, options.endY - options.startY);
    int writtenCount = 0;
    for (int i = 0; i < sampleCount; i++) {
        double fraction = static_cast<double>(i) / static_cast<double>(sampleCount - 1);
        double x = options.startX + (options.endX - options.startX) * fraction;
        double y = options.startY + (options.endY - options.startY) * fraction;
        int row = 0;
        int col = 0;
        double elevation = 0.0;
        if (!RasterCellAtCoordinate(values, cols, rows, extent, x, y, row, col, elevation)) {
            continue;
        }
        QgsFeature outputFeature(fields);
        outputFeature.setAttribute(0, totalDistance * fraction);
        outputFeature.setAttribute(1, elevation);
        outputFeature.setAttribute(2, x);
        outputFeature.setAttribute(3, y);
        outputFeature.setGeometry(QgsGeometry(new QgsPoint(Qgis::WkbType::PointZ, x, y, elevation)));
        if (writer->addFeature(outputFeature)) {
            writtenCount++;
        }
    }
    message = "Terrain profile completed; samples=" + std::to_string(writtenCount) +
        "; length=" + std::to_string(totalDistance);
    return MakeProcessResult(true, GIS_OK, message, outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *RasterLineOfSightLayer(LayerHandle handle, const char *textValue,
                                          const char *outputPath, const char *outputLayerName,
                                          int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisRasterState *state = FindRasterLayer(handle);
    if (!state || !state->layer || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Line-of-sight raster or output is invalid",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<double> values;
    int cols = 0;
    int rows = 0;
    QgsRectangle extent;
    std::string message;
    if (!ReadRasterBandValues(state->layer.get(), 1, values, cols, rows, extent, message)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    RasterLineOptions options;
    if (!ParseRasterLineOptions(textValue, extent, options, message)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int startRow = 0;
    int startCol = 0;
    int endRow = 0;
    int endCol = 0;
    double startTerrain = 0.0;
    double endTerrain = 0.0;
    if (!RasterCellAtCoordinate(values, cols, rows, extent, options.startX, options.startY,
        startRow, startCol, startTerrain) ||
        !RasterCellAtCoordinate(values, cols, rows, extent, options.endX, options.endY,
        endRow, endCol, endTerrain)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Line-of-sight endpoint is NoData",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int sampleCount = std::max(std::abs(endRow - startRow), std::abs(endCol - startCol)) + 1;
    std::vector<double> outputValues(static_cast<size_t>(cols * rows), -9999.0);
    bool visible = true;
    double minimumClearance = std::numeric_limits<double>::max();
    for (int i = 0; i < sampleCount; i++) {
        double fraction = sampleCount <= 1 ? 0.0 : static_cast<double>(i) / static_cast<double>(sampleCount - 1);
        double x = options.startX + (options.endX - options.startX) * fraction;
        double y = options.startY + (options.endY - options.startY) * fraction;
        int row = 0;
        int col = 0;
        double terrain = 0.0;
        if (!RasterCellAtCoordinate(values, cols, rows, extent, x, y, row, col, terrain)) {
            visible = false;
            continue;
        }
        double sightElevation = startTerrain + options.observerHeight +
            ((endTerrain + options.targetHeight) - (startTerrain + options.observerHeight)) * fraction;
        double clearance = sightElevation - terrain;
        minimumClearance = std::min(minimumClearance, clearance);
        if (i > 0 && i < sampleCount - 1 && clearance < 0.0) {
            visible = false;
        }
        outputValues[static_cast<size_t>(row * cols + col)] = clearance >= 0.0 ? 1.0 : 0.0;
    }
    if (!WriteRasterAnalysisGrid(QString::fromUtf8(outputPath), state->layer->crs(), extent,
        cols, rows, outputValues, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    message = std::string("Line of sight completed; visible=") + (visible ? "true" : "false") +
        "; minimum_clearance=" + std::to_string(minimumClearance);
    return MakeProcessResult(true, GIS_OK, message, outputPath,
        outputLayerName ? outputLayerName : "", sampleCount, outErrCode);
}

struct RasterVisibilityOptions {
    double observerX = 0.0;
    double observerY = 0.0;
    double observerHeight = 1.7;
    int azimuthBins = 720;
    double maximumDistance = 0.0;
};

struct RasterVisibilityCell {
    int row = 0;
    int col = 0;
    int bin = 0;
    double distance = 0.0;
    double angle = 0.0;
    double x = 0.0;
    double y = 0.0;
    double elevation = 0.0;
};

static bool ParseRasterVisibilityOptions(const char *textValue, const QgsRectangle &extent,
                                         RasterVisibilityOptions &options, std::string &message)
{
    options.observerX = extent.center().x();
    options.observerY = extent.center().y();
    QString text = QString::fromUtf8(textValue ? textValue : "").trimmed();
    if (!text.isEmpty()) {
        QStringList values = text.split(',', Qt::KeepEmptyParts);
        if (values.size() < 2) {
            message = "Visibility options must use observerX,observerY[,observerHeight,azimuthBins,maximumDistance]";
            return false;
        }
        bool valid = false;
        options.observerX = values.at(0).trimmed().toDouble(&valid);
        if (!valid) { message = "Invalid observer X"; return false; }
        options.observerY = values.at(1).trimmed().toDouble(&valid);
        if (!valid) { message = "Invalid observer Y"; return false; }
        if (values.size() >= 3 && !values.at(2).trimmed().isEmpty()) {
            options.observerHeight = values.at(2).trimmed().toDouble(&valid);
            if (!valid || options.observerHeight < 0.0) { message = "Invalid observer height"; return false; }
        }
        if (values.size() >= 4 && !values.at(3).trimmed().isEmpty()) {
            options.azimuthBins = values.at(3).trimmed().toInt(&valid);
            if (!valid) { message = "Invalid azimuth bin count"; return false; }
        }
        if (values.size() >= 5 && !values.at(4).trimmed().isEmpty()) {
            options.maximumDistance = values.at(4).trimmed().toDouble(&valid);
            if (!valid || options.maximumDistance < 0.0) { message = "Invalid maximum distance"; return false; }
        }
    }
    options.azimuthBins = std::max(36, std::min(3600, options.azimuthBins));
    if (!extent.contains(options.observerX, options.observerY)) {
        message = "Observer must be inside the raster extent";
        return false;
    }
    return true;
}

static bool CollectRasterVisibilityCells(const std::vector<double> &values, int cols, int rows,
                                         const QgsRectangle &extent, const RasterVisibilityOptions &options,
                                         std::vector<RasterVisibilityCell> &cells,
                                         double &observerElevation, std::string &message)
{
    int observerRow = 0;
    int observerCol = 0;
    if (!RasterCellAtCoordinate(values, cols, rows, extent, options.observerX, options.observerY,
        observerRow, observerCol, observerElevation)) {
        message = "Observer position is NoData";
        return false;
    }
    const double cellWidth = extent.width() / static_cast<double>(cols);
    const double cellHeight = extent.height() / static_cast<double>(rows);
    const double twoPi = 6.28318530717958647692;
    cells.reserve(static_cast<size_t>(cols * rows));
    for (int row = 0; row < rows; row++) {
        for (int col = 0; col < cols; col++) {
            if (!RasterValueIsValid(values, cols, row, col)) continue;
            double x = extent.xMinimum() + (static_cast<double>(col) + 0.5) * cellWidth;
            double y = extent.yMaximum() - (static_cast<double>(row) + 0.5) * cellHeight;
            double dx = x - options.observerX;
            double dy = y - options.observerY;
            double distance = std::hypot(dx, dy);
            if (distance <= 0.0 || (options.maximumDistance > 0.0 && distance > options.maximumDistance)) continue;
            double azimuth = std::atan2(dx, dy);
            if (azimuth < 0.0) azimuth += twoPi;
            RasterVisibilityCell cell;
            cell.row = row;
            cell.col = col;
            cell.bin = std::min(options.azimuthBins - 1,
                static_cast<int>(std::floor(azimuth / twoPi * static_cast<double>(options.azimuthBins))));
            cell.distance = distance;
            cell.elevation = values[static_cast<size_t>(row * cols + col)];
            cell.angle = std::atan2(cell.elevation - (observerElevation + options.observerHeight), distance);
            cell.x = x;
            cell.y = y;
            cells.push_back(cell);
        }
    }
    std::sort(cells.begin(), cells.end(), [](const RasterVisibilityCell &left, const RasterVisibilityCell &right) {
        return left.distance < right.distance;
    });
    return true;
}

static const char *RasterViewshedLayer(LayerHandle handle, const char *textValue,
                                       const char *outputPath, const char *outputLayerName,
                                       int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisRasterState *state = FindRasterLayer(handle);
    if (!state || !state->layer || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Viewshed raster or output is invalid",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<double> values;
    int cols = 0;
    int rows = 0;
    QgsRectangle extent;
    std::string message;
    if (!ReadRasterBandValues(state->layer.get(), 1, values, cols, rows, extent, message)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    RasterVisibilityOptions options;
    if (!ParseRasterVisibilityOptions(textValue, extent, options, message)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<RasterVisibilityCell> cells;
    double observerElevation = 0.0;
    if (!CollectRasterVisibilityCells(values, cols, rows, extent, options, cells, observerElevation, message)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<double> horizon(static_cast<size_t>(options.azimuthBins),
        -std::numeric_limits<double>::infinity());
    std::vector<double> outputValues(static_cast<size_t>(cols * rows), -9999.0);
    int visibleCount = 0;
    for (const RasterVisibilityCell &cell : cells) {
        double &maximumAngle = horizon[static_cast<size_t>(cell.bin)];
        bool visible = cell.angle >= maximumAngle - 1e-12;
        outputValues[static_cast<size_t>(cell.row * cols + cell.col)] = visible ? 1.0 : 0.0;
        if (visible) {
            visibleCount++;
            maximumAngle = std::max(maximumAngle, cell.angle);
        }
    }
    int observerRow = 0;
    int observerCol = 0;
    double ignoredElevation = 0.0;
    RasterCellAtCoordinate(values, cols, rows, extent, options.observerX, options.observerY,
        observerRow, observerCol, ignoredElevation);
    outputValues[static_cast<size_t>(observerRow * cols + observerCol)] = 1.0;
    if (!WriteRasterAnalysisGrid(QString::fromUtf8(outputPath), state->layer->crs(), extent,
        cols, rows, outputValues, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    message = "Viewshed completed; visible_cells=" + std::to_string(visibleCount + 1) +
        "; tested_cells=" + std::to_string(cells.size() + 1);
    return MakeProcessResult(true, GIS_OK, message, outputPath,
        outputLayerName ? outputLayerName : "", visibleCount + 1, outErrCode);
}

static const char *RasterSkylineLayer(LayerHandle handle, const char *textValue,
                                      const char *outputPath, const char *outputLayerName,
                                      int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisRasterState *state = FindRasterLayer(handle);
    if (!state || !state->layer || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Skyline raster or output is invalid",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<double> values;
    int cols = 0;
    int rows = 0;
    QgsRectangle extent;
    std::string message;
    if (!ReadRasterBandValues(state->layer.get(), 1, values, cols, rows, extent, message)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    RasterVisibilityOptions options;
    if (!ParseRasterVisibilityOptions(textValue, extent, options, message)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<RasterVisibilityCell> cells;
    double observerElevation = 0.0;
    if (!CollectRasterVisibilityCells(values, cols, rows, extent, options, cells, observerElevation, message)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, message, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<int> skylineIndices(static_cast<size_t>(options.azimuthBins), -1);
    std::vector<double> horizon(static_cast<size_t>(options.azimuthBins),
        -std::numeric_limits<double>::infinity());
    for (size_t index = 0; index < cells.size(); index++) {
        const RasterVisibilityCell &cell = cells[index];
        if (cell.angle > horizon[static_cast<size_t>(cell.bin)]) {
            horizon[static_cast<size_t>(cell.bin)] = cell.angle;
            skylineIndices[static_cast<size_t>(cell.bin)] = static_cast<int>(index);
        }
    }
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("azimuth"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("angle_deg"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("distance"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("elevation"), QVariant::Double));
    QgsVectorFileWriter::SaveVectorOptions writerOptions;
    writerOptions.driverName = QStringLiteral("ESRI Shapefile");
    writerOptions.layerName = outputLayerName && std::strlen(outputLayerName) > 0
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("skyline");
    writerOptions.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(QString::fromUtf8(outputPath), fields,
        Qgis::WkbType::PointZ, state->layer->crs(), QgsCoordinateTransformContext(), writerOptions));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create skyline output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    const double radiansToDegrees = 57.2957795130823208768;
    int writtenCount = 0;
    for (int bin = 0; bin < options.azimuthBins; bin++) {
        int cellIndex = skylineIndices[static_cast<size_t>(bin)];
        if (cellIndex < 0) continue;
        const RasterVisibilityCell &cell = cells[static_cast<size_t>(cellIndex)];
        QgsFeature feature(fields);
        feature.setAttribute(0, (static_cast<double>(bin) + 0.5) * 360.0 /
            static_cast<double>(options.azimuthBins));
        feature.setAttribute(1, cell.angle * radiansToDegrees);
        feature.setAttribute(2, cell.distance);
        feature.setAttribute(3, cell.elevation);
        feature.setGeometry(QgsGeometry(new QgsPoint(Qgis::WkbType::PointZ, cell.x, cell.y, cell.elevation)));
        if (writer->addFeature(feature)) writtenCount++;
    }
    message = "Skyline completed; horizon_points=" + std::to_string(writtenCount);
    return MakeProcessResult(true, GIS_OK, message, outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static bool ParseRasterReclassRule(const QString &ruleText, RasterReclassRule &rule, std::string &message)
{
    QStringList assignment = ruleText.split(QLatin1Char('='), Qt::KeepEmptyParts);
    if (assignment.size() != 2) {
        message = "Reclass rule must use range=value syntax";
        return false;
    }
    bool outputOk = false;
    rule.outputValue = assignment.at(1).trimmed().toDouble(&outputOk);
    if (!outputOk) {
        message = "Reclass output value is invalid";
        return false;
    }

    QString rangeText = assignment.at(0).trimmed();
    if (rangeText.compare(QStringLiteral("else"), Qt::CaseInsensitive) == 0) {
        return true;
    }

    QStringList rangeParts = rangeText.split(QLatin1Char(':'), Qt::KeepEmptyParts);
    if (rangeParts.size() != 2) {
        message = "Reclass range must use min:max";
        return false;
    }

    QString minimumText = rangeParts.at(0).trimmed();
    if (!minimumText.isEmpty() && minimumText != QStringLiteral("*")) {
        bool ok = false;
        rule.minimum = minimumText.toDouble(&ok);
        if (!ok) {
            message = "Reclass minimum is invalid";
            return false;
        }
        rule.hasMinimum = true;
    }

    QString maximumText = rangeParts.at(1).trimmed();
    if (!maximumText.isEmpty() && maximumText != QStringLiteral("*")) {
        bool ok = false;
        rule.maximum = maximumText.toDouble(&ok);
        if (!ok) {
            message = "Reclass maximum is invalid";
            return false;
        }
        rule.hasMaximum = true;
    }

    if (rule.hasMinimum && rule.hasMaximum && rule.maximum < rule.minimum) {
        message = "Reclass range maximum is smaller than minimum";
        return false;
    }
    return true;
}

static bool ParseRasterReclassRules(const char *rulesText, std::vector<RasterReclassRule> &rules,
                                    std::string &message)
{
    QString text = QString::fromUtf8(rulesText ? rulesText : "").trimmed();
    if (text.isEmpty()) {
        message = "Reclass rules are empty";
        return false;
    }
    QStringList parts = text.split(QLatin1Char(';'), Qt::SkipEmptyParts);
    for (int i = 0; i < parts.size(); i++) {
        RasterReclassRule rule;
        if (!ParseRasterReclassRule(parts.at(i).trimmed(), rule, message)) {
            return false;
        }
        rules.push_back(rule);
    }
    if (rules.empty()) {
        message = "No valid reclass rules were supplied";
        return false;
    }
    return true;
}

static bool RasterReclassRuleMatches(const RasterReclassRule &rule, double value)
{
    if (rule.hasMinimum && value < rule.minimum) {
        return false;
    }
    if (rule.hasMaximum && value > rule.maximum) {
        return false;
    }
    return true;
}

static const char *RasterReclassifyLayer(LayerHandle handle, const char *rulesText,
                                         const char *outputPath, const char *outputLayerName,
                                         int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid raster reclass output path",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::vector<RasterReclassRule> rules;
    std::string parseMessage;
    if (!ParseRasterReclassRules(rulesText, rules, parseMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, parseMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgisRasterState *state = FindRasterLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Raster layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::vector<double> sourceValues;
    int cols = 0;
    int rows = 0;
    QgsRectangle extent;
    std::string readMessage;
    if (!ReadRasterBandValues(state->layer.get(), 1, sourceValues, cols, rows, extent, readMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT, readMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::vector<double> outputValues(static_cast<size_t>(cols * rows), -9999.0);
    int matchedCells = 0;
    for (int row = 0; row < rows; row++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        for (int col = 0; col < cols; col++) {
            if (!RasterValueIsValid(sourceValues, cols, row, col)) {
                continue;
            }
            double value = sourceValues[static_cast<size_t>(row * cols + col)];
            for (size_t ruleIndex = 0; ruleIndex < rules.size(); ruleIndex++) {
                if (RasterReclassRuleMatches(rules[ruleIndex], value)) {
                    outputValues[static_cast<size_t>(row * cols + col)] = rules[ruleIndex].outputValue;
                    matchedCells++;
                    break;
                }
            }
        }
    }

    std::string writeMessage;
    QString outPath = QString::fromUtf8(outputPath);
    if (!WriteRasterAnalysisGrid(outPath, state->layer->crs(), extent, cols, rows, outputValues, writeMessage)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, writeMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::string message = "Raster reclassify completed; matched cells=";
    message += std::to_string(matchedCells);
    return MakeProcessResult(true, GIS_OK, message,
        outputPath, outputLayerName ? outputLayerName : "", matchedCells, outErrCode);
}

} // namespace

#include "geonest_pointcloud_processing.inc"

const char *GetNativeVersion()
{
    return "GeoNest GIS Native Core 0.8.0";
}

const char *GetCoreProfile()
{
    return "QGIS Core backend (vector/raster/style/label/edit/expression/geometry/overlay/layout)";
}

const char *InspectPointCloud(const char *filePath, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QString path = QString::fromUtf8(filePath ? filePath : "");
    QFileInfo fileInfo(path);
    if (path.isEmpty() || !fileInfo.exists() || !fileInfo.isFile()) {
        if (outErrCode) *outErrCode = GIS_ERR_FILE_NOT_FOUND;
        return DuplicateCString("{\"ok\":false,\"code\":1,\"message\":\"Point cloud file not found\"}");
    }
    std::ifstream input(ToStdString(path), std::ios::binary);
    if (!input.good()) {
        if (outErrCode) *outErrCode = GIS_ERR_INVALID_FORMAT;
        return DuplicateCString("{\"ok\":false,\"code\":2,\"message\":\"Cannot open point cloud file\"}");
    }
    QgsLazInfo info = QgsLazInfo::fromFile(input);
    input.close();
    if (!info.isValid()) {
        if (outErrCode) *outErrCode = GIS_ERR_INVALID_FORMAT;
        std::string errorJson = "{\"ok\":false,\"code\":3,\"message\":\"" +
            EscapeJson(ToStdString(info.error())) + "\"}";
        return DuplicateCString(errorJson);
    }
    bool copc = path.toLower().endsWith(QStringLiteral(".copc.laz"));
    qint64 pointCount = static_cast<qint64>(info.pointCount());
    if (copc) {
        QgsCopcPointCloudIndex copcIndex;
        copcIndex.load(path);
        if (!copcIndex.isValid()) {
            if (outErrCode) *outErrCode = GIS_ERR_INVALID_FORMAT;
            return DuplicateCString("{\"ok\":false,\"code\":3,\"message\":\"Invalid COPC hierarchy\"}");
        }
        pointCount = copcIndex.pointCount();
    }
    QgsVector3D minimum = info.minCoords();
    QgsVector3D maximum = info.maxCoords();
    QgsVector3D scale = info.scale();
    QgsVector3D offset = info.offset();
    QPair<uint8_t, uint8_t> version = info.version();
    QgsPointCloudAttributeCollection attributeCollection = info.attributes();
    QVector<QgsPointCloudAttribute> attributes = attributeCollection.attributes();
    std::string json = "{\"ok\":true,\"code\":0,\"message\":\"Point cloud header loaded\",\"filePath\":\"";
    json += EscapeJson(ToStdString(path));
    json += "\",\"format\":\"";
    json += copc ? "COPC" : (path.toLower().endsWith(QStringLiteral(".laz")) ? "LAZ" : "LAS");
    json += "\",\"pointCount\":" + std::to_string(static_cast<long long>(pointCount));
    json += ",\"pointFormat\":" + std::to_string(info.pointFormat());
    json += ",\"version\":\"" + std::to_string(version.first) + "." + std::to_string(version.second) + "\"";
    json += ",\"crs\":\"" + EscapeJson(ToStdString(info.crs().authid())) + "\"";
    json += ",\"bounds\":{\"minX\":" + std::to_string(minimum.x()) +
        ",\"minY\":" + std::to_string(minimum.y()) + ",\"minZ\":" + std::to_string(minimum.z()) +
        ",\"maxX\":" + std::to_string(maximum.x()) + ",\"maxY\":" + std::to_string(maximum.y()) +
        ",\"maxZ\":" + std::to_string(maximum.z()) + "}";
    json += ",\"scale\":{\"x\":" + std::to_string(scale.x()) + ",\"y\":" +
        std::to_string(scale.y()) + ",\"z\":" + std::to_string(scale.z()) + "}";
    json += ",\"offset\":{\"x\":" + std::to_string(offset.x()) + ",\"y\":" +
        std::to_string(offset.y()) + ",\"z\":" + std::to_string(offset.z()) + "},\"attributes\":[";
    for (int i = 0; i < attributes.size(); i++) {
        if (i > 0) json += ",";
        json += "{\"name\":\"" + EscapeJson(ToStdString(attributes.at(i).name())) +
            "\",\"type\":\"" + EscapeJson(ToStdString(attributes.at(i).displayType())) +
            "\",\"size\":" + std::to_string(attributes.at(i).size()) + "}";
    }
    json += "]}";
    if (outErrCode) *outErrCode = GIS_OK;
    return DuplicateCString(json);
}

const char *GetProcessingAlgorithms()
{
    static const char catalog[] =
        "{\"backend\":\"qgis-core\",\"algorithms\":["
        "{\"id\":\"buffer\",\"name\":\"Buffer\",\"category\":\"geometry\",\"inputCount\":1,"
        "\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"advanced_buffer\",\"name\":\"Advanced Buffer\",\"category\":\"proximity\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
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
        "{\"id\":\"feature_to_point\",\"name\":\"Feature to point\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"polygon_to_line\",\"name\":\"Polygon to line\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"feature_to_polygon\",\"name\":\"Feature to polygon\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"vertices_to_points\",\"name\":\"Vertices to points\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"points_to_line\",\"name\":\"Points to line\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"densify\",\"name\":\"Densify by distance\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"smooth\",\"name\":\"Smooth geometry\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"remove_holes\",\"name\":\"Remove polygon holes\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"feature_to_line\",\"name\":\"Feature to Line\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"snap\",\"name\":\"Snap\",\"category\":\"geometry\","
        "\"inputCount\":2,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"integrate\",\"name\":\"Integrate\",\"category\":\"geometry\","
        "\"inputCount\":2,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"pairwise_integrate\",\"name\":\"Pairwise Integrate\",\"category\":\"pairwise\","
        "\"inputCount\":2,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"extend_trim_line\",\"name\":\"Extend or Trim Line\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"split_line_at_point\",\"name\":\"Split Line At Point\",\"category\":\"geometry\","
        "\"inputCount\":2,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"aggregate_polygons\",\"name\":\"Aggregate Polygons\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"eliminate\",\"name\":\"Eliminate\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"remove_fragments\",\"name\":\"Remove Fragments\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"unify_direction\",\"name\":\"Unify Polygon Direction\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"centerline\",\"name\":\"Generate Centerline\",\"category\":\"geometry\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"building_simplify\",\"name\":\"Building Simplification\",\"category\":\"cartography\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"road_merge\",\"name\":\"Merge Divided Roads\",\"category\":\"cartography\",\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"road_conflict\",\"name\":\"Resolve Road Conflicts\",\"category\":\"cartography\",\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"symbol_conflict\",\"name\":\"Detect Symbol Conflicts\",\"category\":\"cartography\",\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"cartographic_mask\",\"name\":\"Create Cartographic Masks\",\"category\":\"cartography\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"feature_stroke\",\"name\":\"Feature Stroke\",\"category\":\"cartography\",\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"label_to_annotation\",\"name\":\"Labels to Annotation\",\"category\":\"cartography\",\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"tile_annotation\",\"name\":\"Tiled Annotation\",\"category\":\"cartography\",\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"cartogram\",\"name\":\"Proportional Symbol Cartogram\",\"category\":\"cartography\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"fishnet\",\"name\":\"Create Fishnet\",\"category\":\"sampling\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"hexagon_grid\",\"name\":\"Create Hexagon Grid\",\"category\":\"sampling\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"random_points\",\"name\":\"Random Points\",\"category\":\"sampling\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"regular_points\",\"name\":\"Regular Sample Points\",\"category\":\"sampling\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"voronoi\",\"name\":\"Voronoi polygons\",\"category\":\"geometry\",\"inputCount\":1,"
        "\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"tin\",\"name\":\"TIN Delaunay terrain\",\"category\":\"terrain\",\"inputCount\":1,"
        "\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"kernel_density\",\"name\":\"Kernel Density\",\"category\":\"raster\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"point_density\",\"name\":\"Point Density\",\"category\":\"raster\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"line_density\",\"name\":\"Line Density\",\"category\":\"raster\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"idw\",\"name\":\"IDW interpolation\",\"category\":\"raster\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"dsm\",\"name\":\"DSM from elevation points\",\"category\":\"terrain\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"dtm\",\"name\":\"DTM from ground points\",\"category\":\"terrain\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"chm\",\"name\":\"Canopy Height Model (DSM-DTM)\",\"category\":\"terrain\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"earthwork\",\"name\":\"Cut and fill volume\",\"category\":\"terrain\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"surface_area\",\"name\":\"Terrain surface area\",\"category\":\"terrain\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"terrain_profile\",\"name\":\"Terrain profile\",\"category\":\"terrain\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"line_of_sight\",\"name\":\"Line of sight\",\"category\":\"visibility\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"viewshed\",\"name\":\"Viewshed\",\"category\":\"visibility\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"skyline\",\"name\":\"Skyline\",\"category\":\"visibility\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"raster_slope\",\"name\":\"Raster slope\",\"category\":\"raster\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"raster_aspect\",\"name\":\"Raster aspect\",\"category\":\"raster\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"raster_reclassify\",\"name\":\"Raster reclassify\",\"category\":\"raster\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"nearest_neighbor\",\"name\":\"Nearest neighbor links\",\"category\":\"analysis\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"near\",\"name\":\"Near\",\"category\":\"proximity\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"generate_near_table\",\"name\":\"Generate Near Table\",\"category\":\"proximity\","
        "\"inputCount\":2,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"point_distance\",\"name\":\"Point Distance\",\"category\":\"proximity\","
        "\"inputCount\":2,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"distance_matrix\",\"name\":\"Distance Matrix\",\"category\":\"proximity\","
        "\"inputCount\":2,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"shortest_connection\",\"name\":\"Shortest Connection Lines\",\"category\":\"proximity\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"summary_statistics\",\"name\":\"Summary Statistics\",\"category\":\"statistics\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"frequency\",\"name\":\"Frequency\",\"category\":\"statistics\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"unique_values\",\"name\":\"Unique Values\",\"category\":\"statistics\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"group_statistics\",\"name\":\"Grouped Statistics\",\"category\":\"statistics\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"crosstab_pivot\",\"name\":\"Crosstab and Pivot\",\"category\":\"statistics\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"statistics_chart\",\"name\":\"Statistics Result Chart\",\"category\":\"statistics\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"polygon_neighbors\",\"name\":\"Polygon Neighbors\",\"category\":\"statistics\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"mean_center\",\"name\":\"Mean Center\",\"category\":\"spatial_statistics\",\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"median_center\",\"name\":\"Median Center\",\"category\":\"spatial_statistics\",\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"central_feature\",\"name\":\"Central Feature\",\"category\":\"spatial_statistics\",\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"standard_distance\",\"name\":\"Standard Distance\",\"category\":\"spatial_statistics\",\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"directional_distribution\",\"name\":\"Directional Distribution\",\"category\":\"spatial_statistics\",\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"global_moran\",\"name\":\"Global Moran's I\",\"category\":\"spatial_autocorrelation\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"geary_c\",\"name\":\"Geary's C\",\"category\":\"spatial_autocorrelation\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"local_moran\",\"name\":\"Local Moran's I\",\"category\":\"spatial_autocorrelation\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"general_g\",\"name\":\"Getis-Ord General G\",\"category\":\"hotspot\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"gi_star\",\"name\":\"Getis-Ord Gi* Hot Spot Analysis\",\"category\":\"hotspot\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"ripley_k\",\"name\":\"Ripley's K\",\"category\":\"point_pattern\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"spatial_weights\",\"name\":\"Create Spatial Weights Matrix\",\"category\":\"spatial_weights\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"weights_convert\",\"name\":\"Convert Spatial Weights Matrix\",\"category\":\"spatial_weights\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"weights_visualize\",\"name\":\"Visualize Spatial Weights\",\"category\":\"spatial_weights\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"cluster_outlier\",\"name\":\"Cluster and Outlier Analysis\",\"category\":\"hotspot\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"ols\",\"name\":\"Ordinary Least Squares\",\"category\":\"spatial_regression\",\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"gwr\",\"name\":\"Geographically Weighted Regression\",\"category\":\"spatial_regression\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"mgwr\",\"name\":\"Multiscale GWR\",\"category\":\"spatial_regression\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"interpolation_cv\",\"name\":\"Spatial Interpolation Cross Validation\",\"category\":\"validation\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"forest\",\"name\":\"Spatial Forest Prediction\",\"category\":\"spatial_prediction\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"boosted_trees\",\"name\":\"Spatial Boosted Trees\",\"category\":\"spatial_prediction\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"maxent\",\"name\":\"Maximum Entropy Prediction\",\"category\":\"spatial_prediction\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"space_time_cube\",\"name\":\"Create Space Time Cube\",\"category\":\"space_time\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"emerging_hotspot\",\"name\":\"Emerging Hot Spot Analysis\",\"category\":\"space_time\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"spatiotemporal_cluster\",\"name\":\"Spatiotemporal Clustering\",\"category\":\"space_time\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"trajectory_cluster\",\"name\":\"Trajectory Clustering\",\"category\":\"space_time\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"time_series_forecast\",\"name\":\"Time Series Forecast\",\"category\":\"time_series\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"change_point\",\"name\":\"Change Point Detection\",\"category\":\"time_series\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"time_series_anomaly\",\"name\":\"Time Series Anomaly Detection\",\"category\":\"time_series\",\"inputCount\":1,\"numericParameter\":true,\"textParameter\":true},"
        "{\"id\":\"repair\",\"name\":\"Repair geometries\",\"category\":\"quality\",\"inputCount\":1,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"quality_check\",\"name\":\"Topology and attribute quality check\",\"category\":\"quality\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"extract_by_expression\",\"name\":\"Extract by expression\",\"category\":\"selection\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"select\",\"name\":\"Select\",\"category\":\"selection\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"table_select\",\"name\":\"Table Select\",\"category\":\"selection\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"split\",\"name\":\"Split by overlay features\",\"category\":\"selection\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"split_by_attributes\",\"name\":\"Split by attributes\",\"category\":\"selection\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"extract_by_extent\",\"name\":\"Extract by extent\",\"category\":\"selection\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"extract_by_time\",\"name\":\"Extract by time\",\"category\":\"selection\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"extract_by_mask\",\"name\":\"Extract by mask\",\"category\":\"selection\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"extract_by_location\",\"name\":\"Extract by location\",\"category\":\"selection\","
        "\"inputCount\":2,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"clip\",\"name\":\"Clip\",\"category\":\"overlay\",\"inputCount\":2,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"advanced_clip\",\"name\":\"Advanced Clip\",\"category\":\"overlay\","
        "\"inputCount\":2,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"intersection\",\"name\":\"Intersection with attributes\",\"category\":\"overlay\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"difference\",\"name\":\"Difference\",\"category\":\"overlay\",\"inputCount\":2,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"symmetrical_difference\",\"name\":\"Symmetrical difference\",\"category\":\"overlay\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"union\",\"name\":\"Union\",\"category\":\"overlay\",\"inputCount\":2,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"identity\",\"name\":\"Identity\",\"category\":\"overlay\",\"inputCount\":2,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"update\",\"name\":\"Update\",\"category\":\"overlay\",\"inputCount\":2,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"tabulate_intersection\",\"name\":\"Tabulate Intersection\",\"category\":\"overlay\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"summarize_within\",\"name\":\"Summarize Within\",\"category\":\"overlay\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"pairwise_clip\",\"name\":\"Pairwise Clip\",\"category\":\"pairwise\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"pairwise_buffer\",\"name\":\"Pairwise Buffer\",\"category\":\"pairwise\","
        "\"inputCount\":1,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"pairwise_dissolve\",\"name\":\"Pairwise Dissolve\",\"category\":\"pairwise\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"pairwise_intersect\",\"name\":\"Pairwise Intersect\",\"category\":\"pairwise\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"pairwise_erase\",\"name\":\"Pairwise Erase\",\"category\":\"pairwise\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"spatial_join_summary\",\"name\":\"Spatial join summary\",\"category\":\"overlay\","
        "\"inputCount\":2,\"numericParameter\":true,\"textParameter\":false},"
        "{\"id\":\"spatial_join\",\"name\":\"Spatial Join one-to-one or one-to-many\",\"category\":\"overlay\","
        "\"inputCount\":2,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"multi_ring_buffer\",\"name\":\"Multi-ring buffer\",\"category\":\"overlay\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"merge_layers\",\"name\":\"Merge layers\",\"category\":\"data\",\"inputCount\":2,"
        "\"numericParameter\":false,\"textParameter\":false},"
        "{\"id\":\"define_projection\",\"name\":\"Define projection\",\"category\":\"crs\",\"inputCount\":1,"
        "\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"project\",\"name\":\"Reproject layer\",\"category\":\"crs\",\"inputCount\":1,"
        "\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"export\",\"name\":\"Export layer\",\"category\":\"data\",\"inputCount\":1,"
        "\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"export_format\",\"name\":\"Export layer to format\",\"category\":\"data\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"xy_table_to_points\",\"name\":\"XY table to points\",\"category\":\"data\","
        "\"inputCount\":1,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"portable_project\",\"name\":\"Portable project package\",\"category\":\"project\","
        "\"inputCount\":0,\"numericParameter\":false,\"textParameter\":true},"
        "{\"id\":\"layout_atlas\",\"name\":\"Layout atlas\",\"category\":\"layout\",\"inputCount\":1,"
        "\"numericParameter\":true,\"textParameter\":true}"
        "]}";
    return DuplicateCString(catalog);
}

const char *ExtractZipArchive(const char *zipPath, const char *outputDirectory, int32_t *outErrCode)
{
    if (!zipPath || std::strlen(zipPath) == 0 || !outputDirectory || std::strlen(outputDirectory) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Invalid archive extraction parameters",
            outputDirectory ? outputDirectory : "", "", 0, outErrCode);
    }
    QFileInfo archiveInfo(QString::fromUtf8(zipPath));
    if (!archiveInfo.exists() || !archiveInfo.isFile()) {
        return MakeProcessResult(false, GIS_ERR_FILE_NOT_FOUND,
            "Archive file not found", outputDirectory, "", 0, outErrCode);
    }
    QDir outputDir(QString::fromUtf8(outputDirectory));
    if (!outputDir.exists() && !QDir().mkpath(outputDir.absolutePath())) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
            "Failed to create archive extraction directory", outputDirectory, "", 0, outErrCode);
    }
    QStringList files = QgsZipUtils::files(archiveInfo.absoluteFilePath());
    if (files.size() > 2000) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT,
            "ZIP archive contains too many files", outputDirectory, "", 0, outErrCode);
    }
    QStringList extractedFiles;
    bool ok = QgsZipUtils::unzip(archiveInfo.absoluteFilePath(), outputDir.absolutePath(), extractedFiles, true);
    if (!ok) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT,
            "ZIP archive could not be extracted", outputDirectory, "", 0, outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "ZIP archive extracted",
        outputDir.absolutePath().toStdString(), "", extractedFiles.size(), outErrCode);
}

const char *DescribeCoordinateReferenceSystem(const char *definition, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    ProcessingStateLock lock;
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
        QgsCoordinateTransform transform(source, target, CurrentProcessingTransformContext());
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
    ProcessingStateLock lock;
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
        QgsCoordinateTransform transform(source, target, CurrentProcessingTransformContext());
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

const char *ReadQgisProject(const char *projectPath, int32_t *outErrCode)
{
    if (!projectPath || std::strlen(projectPath) == 0) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString("{\"ok\":false,\"code\":6,\"message\":\"Project path is empty\","
                                "\"projectTitle\":\"\",\"projectCrs\":\"\",\"layerCount\":0,\"layers\":[]}");
    }

    ProcessingStateLock lock;
    if (!EnsureQgis()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_NATIVE_NOT_READY;
        }
        return DuplicateCString("{\"ok\":false,\"code\":5,\"message\":\"QGIS is not ready\","
                                "\"projectTitle\":\"\",\"projectCrs\":\"\",\"layerCount\":0,\"layers\":[]}");
    }

    QString path = QString::fromUtf8(projectPath);
    if (!QFileInfo::exists(path)) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_FILE_NOT_FOUND;
        }
        return DuplicateCString("{\"ok\":false,\"code\":1,\"message\":\"Project file not found\","
                                "\"projectTitle\":\"\",\"projectCrs\":\"\",\"layerCount\":0,\"layers\":[]}");
    }

    QgsProject project;
    if (!project.read(path)) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_FORMAT;
        }
        return DuplicateCString("{\"ok\":false,\"code\":2,\"message\":\"QGIS project read failed\","
                                "\"projectTitle\":\"\",\"projectCrs\":\"\",\"layerCount\":0,\"layers\":[]}");
    }

    QMap<QString, QgsMapLayer *> layerMap = project.mapLayers();
    QList<QgsMapLayer *> layers = layerMap.values();
    QString title = project.title();
    if (title.isEmpty()) {
        title = QFileInfo(path).baseName();
    }

    std::string json = "{\"ok\":true,\"code\":0,\"message\":\"OK\",\"projectTitle\":\"";
    json += EscapeJson(ToStdString(title));
    json += "\",\"projectCrs\":\"";
    json += EscapeJson(ToStdString(project.crs().authid()));
    json += "\",\"layerCount\":";
    json += std::to_string(static_cast<long long>(layers.size()));
    json += ",\"layers\":[";
    for (int i = 0; i < layers.size(); i++) {
        QgsMapLayer *layer = layers.at(i);
        if (i > 0) {
            json += ",";
        }
        QString typeText = QStringLiteral("unknown");
        if (dynamic_cast<QgsVectorLayer *>(layer) != nullptr) {
            typeText = QStringLiteral("vector");
        } else if (dynamic_cast<QgsRasterLayer *>(layer) != nullptr) {
            typeText = QStringLiteral("raster");
        }
        json += "{\"name\":\"";
        json += EscapeJson(ToStdString(layer ? layer->name() : QString()));
        json += "\",\"sourcePath\":\"";
        json += EscapeJson(ToStdString(layer ? layer->source() : QString()));
        json += "\",\"layerType\":\"";
        json += EscapeJson(ToStdString(typeText));
        json += "\",\"visible\":true}";
    }
    json += "]}";

    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(json);
}

const char *WriteQgisProject(const char *projectPath, const char *projectName,
                             const char *projectCrs, const char *layerHandles,
                             int32_t *outErrCode)
{
    if (!projectPath || std::strlen(projectPath) == 0) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString("{\"ok\":false,\"code\":6,\"message\":\"Project path is empty\"}");
    }

    ProcessingStateLock lock;
    if (!EnsureQgis()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_NATIVE_NOT_READY;
        }
        return DuplicateCString("{\"ok\":false,\"code\":5,\"message\":\"QGIS is not ready\"}");
    }

    QgsProject project;
    QString path = QString::fromUtf8(projectPath);
    QFileInfo fileInfo(FilePathFromProviderUri(path));
    QDir parentDir = fileInfo.absoluteDir();
    if (!parentDir.exists() && !parentDir.mkpath(QStringLiteral("."))) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        return DuplicateCString("{\"ok\":false,\"code\":7,\"message\":\"Cannot create project directory\"}");
    }

    QString title = QString::fromUtf8(projectName ? projectName : "").trimmed();
    if (title.isEmpty()) {
        title = fileInfo.baseName();
    }
    project.setTitle(title);

    QgsCoordinateReferenceSystem crs = CrsFromDefinition(projectCrs);
    if (crs.isValid()) {
        project.setCrs(crs);
    }

    std::vector<LayerHandle> handles = ParseLayerHandles(layerHandles);
    int addedCount = 0;
    for (size_t i = 0; i < handles.size(); i++) {
        QgisLayerState *vectorState = FindLayer(handles[i]);
        if (vectorState && vectorState->layer) {
            QString source = QString::fromUtf8(vectorState->filePath.c_str());
            QFileInfo sourceInfo(FilePathFromProviderUri(source));
            if (!sourceInfo.exists()) {
                continue;
            }
            QgsVectorLayer *copy = new QgsVectorLayer(source, vectorState->layer->name(), QStringLiteral("ogr"));
            if (copy->isValid()) {
                project.addMapLayer(copy);
                addedCount++;
            } else {
                delete copy;
            }
            continue;
        }

        QgisRasterState *rasterState = FindRasterLayer(handles[i]);
        if (rasterState && rasterState->layer) {
            QString source = QString::fromUtf8(rasterState->filePath.c_str());
            QFileInfo sourceInfo(FilePathFromProviderUri(source));
            if (!sourceInfo.exists()) {
                continue;
            }
            QgsRasterLayer *copy = new QgsRasterLayer(source, rasterState->layer->name(), QStringLiteral("gdal"));
            if (copy->isValid()) {
                project.addMapLayer(copy);
                addedCount++;
            } else {
                delete copy;
            }
        }
    }

    if (!project.write(path)) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_WRITE_FAILED;
        }
        return DuplicateCString("{\"ok\":false,\"code\":7,\"message\":\"QGIS project write failed\"}");
    }

    std::string json = "{\"ok\":true,\"code\":0,\"message\":\"QGIS project saved\",\"layerCount\":";
    json += std::to_string(addedCount);
    json += ",\"outputPath\":\"";
    json += EscapeJson(ToStdString(path));
    json += "\"}";
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(json);
}

LayerHandle OpenVectorLayer(const char *filePath, char **outLayerInfo, int32_t *outErrCode)
{
    if (!filePath || std::strlen(filePath) == 0) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return 0;
    }

    ProcessingStateLock lock;
    if (!EnsureQgis()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_NATIVE_NOT_READY;
        }
        return 0;
    }

    QString path = QString::fromUtf8(filePath);
    QFileInfo fileInfo(FilePathFromProviderUri(path));
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

    ProcessingStateLock lock;
    if (!EnsureQgis()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_NATIVE_NOT_READY;
        }
        return 0;
    }

    QString path = QString::fromUtf8(filePath);
    QFileInfo fileInfo(FilePathFromProviderUri(path));
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
    ProcessingStateLock lock;
    std::map<LayerHandle, std::unique_ptr<QgisLayerState>>::iterator it = g_layers.find(handle);
    if (it != g_layers.end()) {
        QgisLayerState *state = it->second.get();
        if (state && state->layer && state->editSessionActive && state->layer->isEditable()) {
            if (state->editCommandActive) {
                state->layer->destroyEditCommand();
                state->editCommandActive = false;
            }
            state->layer->rollBack();
            state->editSessionActive = false;
        }
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
    ProcessingStateLock lock;
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

const char *ListVectorSublayers(const char *filePath, int32_t *outErrCode)
{
    if (!filePath || std::strlen(filePath) == 0) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString("{\"ok\":false,\"layers\":[]}");
    }
    ProcessingStateLock lock;
    if (!EnsureQgis()) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_NATIVE_NOT_READY;
        }
        return DuplicateCString("{\"ok\":false,\"layers\":[]}");
    }
    QString path = QString::fromUtf8(filePath);
    QString physicalPath = FilePathFromProviderUri(path);
    if (!QFileInfo::exists(physicalPath)) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_FILE_NOT_FOUND;
        }
        return DuplicateCString("{\"ok\":false,\"layers\":[]}");
    }

    QList<QgsProviderSublayerDetails> details =
        QgsProviderRegistry::instance()->querySublayers(physicalPath);
    std::string json = "{\"ok\":true,\"layers\":[";
    bool first = true;
    for (int i = 0; i < details.size(); i++) {
        QString name = details.at(i).name().trimmed();
        QString uri = details.at(i).uri();
        if (name.isEmpty() || uri.isEmpty()) {
            continue;
        }
        if (!first) {
            json += ",";
        }
        first = false;
        json += "{\"name\":\"";
        json += EscapeJson(ToStdString(name));
        json += "\",\"uri\":\"";
        json += EscapeJson(ToStdString(uri));
        json += "\"}";
    }
    if (first) {
        QFileInfo sourceInfo(physicalPath);
        json += "{\"name\":\"";
        json += EscapeJson(ToStdString(sourceInfo.baseName()));
        json += "\",\"uri\":\"";
        json += EscapeJson(ToStdString(physicalPath));
        json += "\"}";
    }
    json += "]}";
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return DuplicateCString(json);
}

const char *QueryFeatures(LayerHandle handle, double minX, double minY, double maxX, double maxY,
                          int32_t limit, int32_t offset, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        }
        return nullptr;
    }

    QgsFeatureRequest request;
    if (minX < maxX && minY < maxY) {
        request.setFilterRect(QgsRectangle(minX, minY, maxX, maxY));
    }
    if (limit > 0) {
        request.setLimit(static_cast<long long>(limit) + static_cast<long long>(std::max(offset, 0)) + 1);
    }

    std::string json = "{\"layerId\":\"L";
    json += std::to_string(handle);
    json += "\",\"features\":[";

    QgsFeature feature;
    QgsFeatureIterator iterator = state->layer->getFeatures(request);
    bool first = true;
    bool hasMore = false;
    int32_t count = 0;
    int32_t skipped = 0;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        if (skipped < offset) {
            skipped++;
            continue;
        }
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

const char *SelectFeaturesByGeometry(LayerHandle handle, const char *selectionWkt,
                                     int32_t predicateMode, int32_t limit,
                                     int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        if (outErrCode) *outErrCode = GIS_ERR_LAYER_NOT_FOUND;
        return nullptr;
    }
    if (!selectionWkt || std::strlen(selectionWkt) == 0) {
        if (outErrCode) *outErrCode = GIS_ERR_INVALID_PARAM;
        return DuplicateCString("{\"featureIds\":[],\"matchedCount\":0,\"truncated\":false}");
    }
    QgsGeometry selection = QgsGeometry::fromWkt(QString::fromUtf8(selectionWkt));
    if (selection.isNull() || selection.isEmpty()) {
        if (outErrCode) *outErrCode = GIS_ERR_INVALID_PARAM;
        return DuplicateCString("{\"featureIds\":[],\"matchedCount\":0,\"truncated\":false}");
    }

    QgsFeatureRequest request;
    request.setFilterRect(selection.boundingBox());
    QgsFeatureIterator iterator = state->layer->getFeatures(request);
    QgsFeature feature;
    std::string json = "{\"featureIds\":[";
    int32_t matchedCount = 0;
    int32_t emittedCount = 0;
    bool truncated = false;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) continue;
        bool matched = false;
        if (predicateMode == 1) matched = selection.contains(geometry);
        else if (predicateMode == 2) matched = geometry.contains(selection);
        else if (predicateMode == 3) matched = selection.touches(geometry);
        else matched = selection.intersects(geometry);
        if (!matched) continue;
        matchedCount++;
        if (limit > 0 && emittedCount >= limit) {
            truncated = true;
            continue;
        }
        if (emittedCount > 0) json += ",";
        json += "\"" + std::to_string(static_cast<long long>(feature.id())) + "\"";
        emittedCount++;
    }
    json += "],\"matchedCount\":" + std::to_string(matchedCount);
    json += ",\"truncated\":";
    json += truncated ? "true}" : "false}";
    if (outErrCode) *outErrCode = GIS_OK;
    return DuplicateCString(json);
}

const char *GetFeature(LayerHandle handle, int64_t fid, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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

static bool BuildLayerUnionInCrs(QgsVectorLayer *layer,
                                 const QgsCoordinateReferenceSystem &targetCrs,
                                 QgsGeometry &unionGeometry, int32_t &featureCount,
                                 std::string &message);

static const char *FeaturePreservingSymmetricalDifferenceLayer(
    LayerHandle inputHandle, LayerHandle overlayHandle, const char *outputPath,
    const char *outputLayerName, int32_t *outErrCode);

// ---------------------------------------------------------------------------
// Geoprocessing: ClipLayer (QGIS Core)
// Clips input features by the union of clip layer geometries. Overlay geometry
// is transformed to the input CRS before any spatial operation.
// ---------------------------------------------------------------------------

const char *ClipLayer(LayerHandle inputHandle, LayerHandle clipHandle, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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

    QgsVectorLayer *sourceLayer = inputState->layer.get();
    QgsGeometry clipGeom;
    int32_t clipFeatureCount = 0;
    std::string clipMessage;
    if (!BuildLayerUnionInCrs(clipState->layer.get(), sourceLayer->crs(), clipGeom,
        clipFeatureCount, clipMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, clipMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
// ExportLayerToFormat (QGIS Core)
// Writes a loaded vector layer to the specified driver format.
// ---------------------------------------------------------------------------
const char *ExportLayerToFormat(LayerHandle handle, const char *outputPath,
                                const char *outputLayerName, const char *driverName,
                                int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    QString driver = (driverName && std::strlen(driverName) > 0)
        ? QString::fromUtf8(driverName) : QStringLiteral("ESRI Shapefile");

    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = driver;
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");

    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        geomType, crs, QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        std::string errMsg = "Failed to create output with driver " + driver.toStdString();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, errMsg,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    ProcessingStateLock lock;
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
        QgsCoordinateTransform transform(sourceCrs, targetCrs, CurrentProcessingTransformContext());
        int32_t writtenCount = 0;
        QgsFeatureIterator iterator = sourceLayer->getFeatures();
        QgsFeature feature;
        while (iterator.nextFeature(feature)) {
            if (ProcessingLoopCheckpoint("compute")) {
                break;
            }
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry geometry = feature.geometry();
        if (!geometry.isNull() && !geometry.isEmpty()) {
            geometries.push_back(geometry);
        }
    }
    if (ProcessingCancellationRequested()) {
        return MakeProcessResult(false, GIS_ERR_CANCELED, "Processing canceled",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry geometry = feature.geometry();
        if (!geometry.isNull() && !geometry.isEmpty()) {
            geometries.push_back(geometry);
        }
    }
    if (ProcessingCancellationRequested()) {
        return MakeProcessResult(false, GIS_ERR_CANCELED, "Processing canceled",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
        transform = QgsCoordinateTransform(sourceCrs, targetCrs, CurrentProcessingTransformContext());
    }
    QVector<QgsGeometry> geometries;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    if (ProcessingCancellationRequested()) {
        message = "Processing canceled";
        return false;
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    ProcessingStateLock lock;
    return FeaturePreservingSymmetricalDifferenceLayer(inputHandle, overlayHandle,
        outputPath, outputLayerName, outErrCode);
}

struct FeatureGeometryRecord {
    QgsFeatureId id = -1;
    QgsGeometry geometry;
};

struct OverlayFeatureRecord {
    QgsFeatureId id = -1;
    QgsGeometry geometry;
    QgsAttributes attributes;
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
        QgsCoordinateTransform transform(sourceCrs, targetCrs, CurrentProcessingTransformContext());
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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

static bool LoadOverlayFeatureRecords(QgsVectorLayer *layer,
                                      const QgsCoordinateReferenceSystem &targetCrs,
                                      std::vector<OverlayFeatureRecord> &records,
                                      std::string &message)
{
    if (!layer) {
        message = "Overlay layer is missing";
        return false;
    }
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("read")) {
            break;
        }
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        if (!TransformGeometryToCrs(geometry, layer->crs(), targetCrs, message)) {
            return false;
        }
        OverlayFeatureRecord record;
        record.id = feature.id();
        record.geometry = geometry;
        record.attributes = feature.attributes();
        records.push_back(record);
    }
    if (ProcessingCancellationRequested()) {
        message = "Processing canceled";
        return false;
    }
    if (records.empty()) {
        message = "Overlay layer has no geometry";
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

static QgsFields BuildOverlayOutputFields(const QgsFields &inputFields,
                                          const QgsFields &overlayFields)
{
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("fid_input"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("fid_over"), QVariant::LongLong));
    for (int i = 0; i < inputFields.count(); i++) {
        AppendUniqueField(fields, inputFields.at(i), QStringLiteral("in_"));
    }
    for (int i = 0; i < overlayFields.count(); i++) {
        AppendUniqueField(fields, overlayFields.at(i), QStringLiteral("ov_"));
    }
    return fields;
}

static bool AddCombinedOverlayFeature(QgsVectorFileWriter *writer, const QgsFields &fields,
                                      const QgsFields &inputFields, const QgsFields &overlayFields,
                                      const QgsFeature *inputFeature,
                                      const OverlayFeatureRecord *overlayFeature,
                                      QgsGeometry geometry, Qgis::GeometryType expectedGeometryType,
                                      bool forceMultipart, int32_t &writtenCount)
{
    if (!writer || geometry.isNull() || geometry.isEmpty() ||
        QgsWkbTypes::geometryType(geometry.wkbType()) != expectedGeometryType) {
        return true;
    }
    if (forceMultipart && !QgsWkbTypes::isMultiType(geometry.wkbType())) {
        geometry.convertToMultiType();
    }

    QgsFeature outputFeature(fields);
    outputFeature.setAttribute(0, static_cast<qlonglong>(inputFeature ? inputFeature->id() : -1));
    outputFeature.setAttribute(1, static_cast<qlonglong>(overlayFeature ? overlayFeature->id : -1));
    int outputIndex = 2;
    for (int i = 0; i < inputFields.count(); i++) {
        if (inputFeature) {
            outputFeature.setAttribute(outputIndex, inputFeature->attribute(i));
        }
        outputIndex++;
    }
    for (int i = 0; i < overlayFields.count(); i++) {
        if (overlayFeature && i < overlayFeature->attributes.count()) {
            outputFeature.setAttribute(outputIndex, overlayFeature->attributes.at(i));
        }
        outputIndex++;
    }
    outputFeature.setGeometry(geometry);
    if (!writer->addFeature(outputFeature)) {
        return false;
    }
    writtenCount++;
    return true;
}

static std::unique_ptr<QgsVectorFileWriter> CreateOverlayWriter(
    const char *outputPath, const char *outputLayerName, const QString &defaultLayerName,
    const QgsFields &fields, Qgis::WkbType outputType,
    const QgsCoordinateReferenceSystem &outputCrs)
{
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : defaultLayerName;
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    return std::unique_ptr<QgsVectorFileWriter>(QgsVectorFileWriter::create(
        QString::fromUtf8(outputPath), fields, outputType, outputCrs,
        QgsCoordinateTransformContext(), options));
}

static bool BuildOverlayRecordUnion(const std::vector<OverlayFeatureRecord> &records,
                                    QgsGeometry &unionGeometry, std::string &message)
{
    QVector<QgsGeometry> geometries;
    for (size_t i = 0; i < records.size(); i++) {
        if (ProcessingLoopCheckpoint("compute")) {
            message = "Processing canceled";
            return false;
        }
        geometries.push_back(records[i].geometry);
    }
    unionGeometry = QgsGeometry::unaryUnion(geometries);
    if (unionGeometry.isNull() || unionGeometry.isEmpty()) {
        message = "Overlay geometry union failed";
        return false;
    }
    return true;
}

static const char *UnionLayer(LayerHandle inputHandle, LayerHandle overlayHandle,
                              const char *outputPath, const char *outputLayerName,
                              int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0 || inputHandle == overlayHandle) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid union parameters",
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
    if (inputLayer->geometryType() != Qgis::GeometryType::Polygon ||
        overlayLayer->geometryType() != Qgis::GeometryType::Polygon) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Union requires two polygon layers", outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::vector<OverlayFeatureRecord> overlays;
    std::string loadMessage;
    if (!LoadOverlayFeatureRecords(overlayLayer, inputLayer->crs(), overlays, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsGeometry overlayUnion;
    if (!BuildOverlayRecordUnion(overlays, overlayUnion, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsGeometry inputUnion;
    int32_t inputGeometryCount = 0;
    if (!BuildLayerUnionInCrs(inputLayer, inputLayer->crs(), inputUnion,
        inputGeometryCount, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields inputFields = inputLayer->fields();
    QgsFields overlayFields = overlayLayer->fields();
    QgsFields fields = BuildOverlayOutputFields(inputFields, overlayFields);
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath,
        outputLayerName, QStringLiteral("union_output"), fields,
        Qgis::WkbType::MultiPolygon, inputLayer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create union output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    int32_t intersectionCount = 0;
    int32_t inputOnlyCount = 0;
    int32_t overlayOnlyCount = 0;
    QgsFeatureIterator inputIterator = inputLayer->getFeatures();
    QgsFeature inputFeature;
    while (inputIterator.nextFeature(inputFeature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry inputGeometry = inputFeature.geometry();
        if (inputGeometry.isNull() || inputGeometry.isEmpty()) {
            continue;
        }
        for (size_t i = 0; i < overlays.size(); i++) {
            if (!inputGeometry.intersects(overlays[i].geometry)) {
                continue;
            }
            QgsGeometry intersection = inputGeometry.intersection(overlays[i].geometry);
            int32_t before = writtenCount;
            if (!AddCombinedOverlayFeature(writer.get(), fields, inputFields, overlayFields,
                &inputFeature, &overlays[i], intersection, Qgis::GeometryType::Polygon,
                true, writtenCount)) {
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                    "Failed while writing union intersection", outputPath,
                    outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
            }
            if (writtenCount > before) {
                intersectionCount++;
            }
        }
        QgsGeometry inputOnly = inputGeometry.difference(overlayUnion);
        int32_t before = writtenCount;
        if (!AddCombinedOverlayFeature(writer.get(), fields, inputFields, overlayFields,
            &inputFeature, nullptr, inputOnly, Qgis::GeometryType::Polygon,
            true, writtenCount)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                "Failed while writing input-only union feature", outputPath,
                outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        if (writtenCount > before) {
            inputOnlyCount++;
        }
    }
    for (size_t i = 0; i < overlays.size(); i++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry overlayOnly = overlays[i].geometry.difference(inputUnion);
        int32_t before = writtenCount;
        if (!AddCombinedOverlayFeature(writer.get(), fields, inputFields, overlayFields,
            nullptr, &overlays[i], overlayOnly, Qgis::GeometryType::Polygon,
            true, writtenCount)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                "Failed while writing overlay-only union feature", outputPath,
                outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        if (writtenCount > before) {
            overlayOnlyCount++;
        }
    }

    std::string message = "Union completed; intersections=" + std::to_string(intersectionCount) +
        "; input-only=" + std::to_string(inputOnlyCount) +
        "; overlay-only=" + std::to_string(overlayOnlyCount);
    return MakeProcessResult(true, GIS_OK, message, outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *IdentityLayer(LayerHandle inputHandle, LayerHandle overlayHandle,
                                 const char *outputPath, const char *outputLayerName,
                                 int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0 || inputHandle == overlayHandle) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid identity parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *overlayState = FindLayer(overlayHandle);
    if (!inputState || !inputState->layer || !overlayState || !overlayState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input or identity layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *inputLayer = inputState->layer.get();
    QgsVectorLayer *overlayLayer = overlayState->layer.get();
    if (overlayLayer->geometryType() != Qgis::GeometryType::Polygon &&
        overlayLayer->geometryType() != inputLayer->geometryType()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Identity layer must be polygon or match the input geometry type",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::vector<OverlayFeatureRecord> overlays;
    std::string loadMessage;
    if (!LoadOverlayFeatureRecords(overlayLayer, inputLayer->crs(), overlays, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsGeometry overlayUnion;
    if (!BuildOverlayRecordUnion(overlays, overlayUnion, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields inputFields = inputLayer->fields();
    QgsFields overlayFields = overlayLayer->fields();
    QgsFields fields = BuildOverlayOutputFields(inputFields, overlayFields);
    Qgis::WkbType outputType = QgsWkbTypes::multiType(inputLayer->wkbType());
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath,
        outputLayerName, QStringLiteral("identity_output"), fields, outputType,
        inputLayer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create identity output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator inputIterator = inputLayer->getFeatures();
    QgsFeature inputFeature;
    while (inputIterator.nextFeature(inputFeature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry inputGeometry = inputFeature.geometry();
        if (inputGeometry.isNull() || inputGeometry.isEmpty()) {
            continue;
        }
        for (size_t i = 0; i < overlays.size(); i++) {
            if (!inputGeometry.intersects(overlays[i].geometry)) {
                continue;
            }
            QgsGeometry intersection = inputGeometry.intersection(overlays[i].geometry);
            if (!AddCombinedOverlayFeature(writer.get(), fields, inputFields, overlayFields,
                &inputFeature, &overlays[i], intersection, inputLayer->geometryType(),
                true, writtenCount)) {
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                    "Failed while writing identity intersection", outputPath,
                    outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
            }
        }
        QgsGeometry remainder = inputGeometry.difference(overlayUnion);
        if (!AddCombinedOverlayFeature(writer.get(), fields, inputFields, overlayFields,
            &inputFeature, nullptr, remainder, inputLayer->geometryType(),
            true, writtenCount)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                "Failed while writing identity remainder", outputPath,
                outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
    }
    return MakeProcessResult(true, GIS_OK,
        "Identity completed with input and identity attributes", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *FeaturePreservingSymmetricalDifferenceLayer(
    LayerHandle inputHandle, LayerHandle overlayHandle, const char *outputPath,
    const char *outputLayerName, int32_t *outErrCode)
{
    if (!outputPath || std::strlen(outputPath) == 0 || inputHandle == overlayHandle) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Invalid symmetrical difference parameters", outputPath ? outputPath : "",
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *overlayState = FindLayer(overlayHandle);
    if (!inputState || !inputState->layer || !overlayState || !overlayState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND,
            "Input or overlay layer not found", outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *inputLayer = inputState->layer.get();
    QgsVectorLayer *overlayLayer = overlayState->layer.get();
    if (inputLayer->geometryType() != overlayLayer->geometryType()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Symmetrical difference requires matching geometry types", outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::vector<OverlayFeatureRecord> overlays;
    std::string loadMessage;
    if (!LoadOverlayFeatureRecords(overlayLayer, inputLayer->crs(), overlays, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsGeometry overlayUnion;
    if (!BuildOverlayRecordUnion(overlays, overlayUnion, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsGeometry inputUnion;
    int32_t inputGeometryCount = 0;
    if (!BuildLayerUnionInCrs(inputLayer, inputLayer->crs(), inputUnion,
        inputGeometryCount, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields inputFields = inputLayer->fields();
    QgsFields overlayFields = overlayLayer->fields();
    QgsFields fields = BuildOverlayOutputFields(inputFields, overlayFields);
    Qgis::WkbType outputType = QgsWkbTypes::multiType(inputLayer->wkbType());
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath,
        outputLayerName, QStringLiteral("sym_difference_output"), fields, outputType,
        inputLayer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
            "Failed to create symmetrical difference output", outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator inputIterator = inputLayer->getFeatures();
    QgsFeature inputFeature;
    while (inputIterator.nextFeature(inputFeature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry inputOnly = inputFeature.geometry().difference(overlayUnion);
        if (!AddCombinedOverlayFeature(writer.get(), fields, inputFields, overlayFields,
            &inputFeature, nullptr, inputOnly, inputLayer->geometryType(),
            true, writtenCount)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                "Failed while writing input symmetrical difference", outputPath,
                outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
    }
    for (size_t i = 0; i < overlays.size(); i++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry overlayOnly = overlays[i].geometry.difference(inputUnion);
        if (!AddCombinedOverlayFeature(writer.get(), fields, inputFields, overlayFields,
            nullptr, &overlays[i], overlayOnly, inputLayer->geometryType(),
            true, writtenCount)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                "Failed while writing overlay symmetrical difference", outputPath,
                outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
    }
    return MakeProcessResult(true, GIS_OK,
        "Symmetrical difference completed with per-feature attributes", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *UpdateOverlayLayer(LayerHandle inputHandle, LayerHandle updateHandle,
                                      const char *outputPath, const char *outputLayerName,
                                      int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0 || inputHandle == updateHandle) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid update parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *updateState = FindLayer(updateHandle);
    if (!inputState || !inputState->layer || !updateState || !updateState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND,
            "Input or update layer not found", outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *inputLayer = inputState->layer.get();
    QgsVectorLayer *updateLayer = updateState->layer.get();
    if (inputLayer->geometryType() != Qgis::GeometryType::Polygon ||
        updateLayer->geometryType() != Qgis::GeometryType::Polygon) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Update requires two polygon layers", outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::vector<OverlayFeatureRecord> updates;
    std::string loadMessage;
    if (!LoadOverlayFeatureRecords(updateLayer, inputLayer->crs(), updates, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsGeometry updateUnion;
    if (!BuildOverlayRecordUnion(updates, updateUnion, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields fields = inputLayer->fields();
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath,
        outputLayerName, QStringLiteral("update_output"), fields,
        Qgis::WkbType::MultiPolygon, inputLayer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create update output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    QgsFeatureIterator inputIterator = inputLayer->getFeatures();
    QgsFeature inputFeature;
    while (inputIterator.nextFeature(inputFeature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry remainder = inputFeature.geometry().difference(updateUnion);
        if (remainder.isNull() || remainder.isEmpty()) {
            continue;
        }
        if (!QgsWkbTypes::isMultiType(remainder.wkbType())) {
            remainder.convertToMultiType();
        }
        QgsFeature outputFeature(fields);
        outputFeature.setAttributes(inputFeature.attributes());
        outputFeature.setGeometry(remainder);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                "Failed while writing retained input feature", outputPath,
                outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }

    QgsFields updateFields = updateLayer->fields();
    for (size_t i = 0; i < updates.size(); i++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry geometry = updates[i].geometry;
        if (!QgsWkbTypes::isMultiType(geometry.wkbType())) {
            geometry.convertToMultiType();
        }
        QgsFeature outputFeature(fields);
        for (int fieldIndex = 0; fieldIndex < fields.count(); fieldIndex++) {
            int updateFieldIndex = updateFields.indexOf(fields.at(fieldIndex).name());
            if (updateFieldIndex >= 0 && updateFieldIndex < updates[i].attributes.count()) {
                outputFeature.setAttribute(fieldIndex, updates[i].attributes.at(updateFieldIndex));
            }
        }
        outputFeature.setGeometry(geometry);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                "Failed while writing update feature", outputPath,
                outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK,
        "Update completed; update geometry and matching fields replaced input values",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *FeatureToPointLayer(LayerHandle handle, bool inside,
                                       const char *outputPath, const char *outputLayerName,
                                       int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid feature-to-point parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QgsFields fields = layer->fields();
    int sourceFidIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("orig_fid"), QVariant::LongLong), QString());
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("feature_points"), fields, Qgis::WkbType::Point, layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create point output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry point = inside ? feature.geometry().pointOnSurface() : feature.geometry().centroid();
        if (point.isNull() || point.isEmpty()) {
            continue;
        }
        QgsFeature outputFeature(fields);
        outputFeature.setAttributes(feature.attributes());
        outputFeature.setAttribute(sourceFidIndex, static_cast<qlonglong>(feature.id()));
        outputFeature.setGeometry(point);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing feature point",
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK, inside ? "Feature to inside point completed" :
        "Feature to centroid point completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *PolygonToLineLayer(LayerHandle handle, const char *outputPath,
                                      const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer ||
        (state->layer->geometryType() != Qgis::GeometryType::Polygon &&
         state->layer->geometryType() != Qgis::GeometryType::Line) ||
        !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Feature to line requires line or polygon input",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QgsFields fields = layer->fields();
    int sourceFidIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("orig_fid"), QVariant::LongLong), QString());
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("polygon_lines"), fields, Qgis::WkbType::MultiLineString, layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create line output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry line = feature.geometry();
        if (layer->geometryType() == Qgis::GeometryType::Polygon) {
            const QgsAbstractGeometry *sourceGeometry = feature.geometry().constGet();
            if (!sourceGeometry) continue;
            std::unique_ptr<QgsAbstractGeometry> boundary(sourceGeometry->boundary());
            if (!boundary) continue;
            line = QgsGeometry(std::move(boundary));
        }
        if (!QgsWkbTypes::isMultiType(line.wkbType())) {
            line.convertToMultiType();
        }
        QgsFeature outputFeature(fields);
        outputFeature.setAttributes(feature.attributes());
        outputFeature.setAttribute(sourceFidIndex, static_cast<qlonglong>(feature.id()));
        outputFeature.setGeometry(line);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing polygon boundary",
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK, "Polygon to line completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *FeatureToPolygonLayer(LayerHandle handle, const char *outputPath,
                                         const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid feature-to-polygon parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    if (layer->geometryType() != Qgis::GeometryType::Line &&
        layer->geometryType() != Qgis::GeometryType::Polygon) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Feature to polygon requires line or polygon input", outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QVector<QgsGeometry> linework;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        if (layer->geometryType() == Qgis::GeometryType::Polygon) {
            const QgsAbstractGeometry *sourceGeometry = geometry.constGet();
            std::unique_ptr<QgsAbstractGeometry> boundary(sourceGeometry ? sourceGeometry->boundary() : nullptr);
            if (boundary) {
                linework.append(QgsGeometry(std::move(boundary)));
            }
        } else {
            linework.append(geometry);
        }
    }
    QgsGeometry polygons = QgsGeometry::polygonize(linework);
    QVector<QgsGeometry> parts = polygons.asGeometryCollection();
    if (parts.isEmpty() && !polygons.isNull() && !polygons.isEmpty()) {
        parts.append(polygons);
    }
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("polygon_id"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("area"), QVariant::Double));
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("feature_polygons"), fields, Qgis::WkbType::MultiPolygon, layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create polygon output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    for (int i = 0; i < parts.count(); i++) {
        QgsGeometry polygon = parts.at(i);
        if (polygon.isNull() || polygon.isEmpty()) {
            continue;
        }
        if (!QgsWkbTypes::isMultiType(polygon.wkbType())) {
            polygon.convertToMultiType();
        }
        QgsFeature outputFeature(fields);
        outputFeature.setAttribute(0, static_cast<qlonglong>(i + 1));
        outputFeature.setAttribute(1, polygon.area());
        outputFeature.setGeometry(polygon);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing polygon",
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK, "Feature to polygon completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *VerticesToPointsLayer(LayerHandle handle, const char *outputPath,
                                         const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid vertices-to-points parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QgsFields fields = layer->fields();
    int sourceFidIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("orig_fid"), QVariant::LongLong), QString());
    int vertexIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("vertex_ix"), QVariant::Int), QString());
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("vertices"), fields, Qgis::WkbType::Point, layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create vertex output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsVertexIterator vertices = feature.geometry().vertices();
        int currentVertex = 0;
        while (vertices.hasNext()) {
            QgsPoint point = vertices.next();
            QgsFeature outputFeature(fields);
            outputFeature.setAttributes(feature.attributes());
            outputFeature.setAttribute(sourceFidIndex, static_cast<qlonglong>(feature.id()));
            outputFeature.setAttribute(vertexIndex, currentVertex);
            outputFeature.setGeometry(QgsGeometry::fromPointXY(QgsPointXY(point.x(), point.y())));
            if (!writer->addFeature(outputFeature)) {
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing vertex",
                    outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
            }
            currentVertex++;
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Vertices to points completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *PointsToLineLayer(LayerHandle handle, const char *optionsText,
                                     const char *outputPath, const char *outputLayerName,
                                     int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || state->layer->geometryType() != Qgis::GeometryType::Point ||
        !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Points to line requires a point layer",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QStringList options = QString::fromUtf8(optionsText ? optionsText : "NONE;NONE;0").split(';');
    QString groupField = options.value(0, QStringLiteral("NONE")).trimmed();
    QString orderField = options.value(1, QStringLiteral("NONE")).trimmed();
    bool closeLine = options.value(2, QStringLiteral("0")).trimmed() == QStringLiteral("1");
    int groupFieldIndex = groupField.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) == 0 ?
        -1 : layer->fields().indexOf(groupField);
    int orderFieldIndex = orderField.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) == 0 ?
        -1 : layer->fields().indexOf(orderField);
    if ((groupFieldIndex < 0 && groupField.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) != 0) ||
        (orderFieldIndex < 0 && orderField.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) != 0)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Group or order field was not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QMap<QString, QVector<PointsToLineRecord>> groups;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        PointsToLineRecord record;
        record.id = feature.id();
        record.point = geometry.asPoint();
        record.groupKey = groupFieldIndex >= 0 ? feature.attribute(groupFieldIndex).toString() :
            QStringLiteral("ALL");
        QVariant orderValue = orderFieldIndex >= 0 ? feature.attribute(orderFieldIndex) :
            QVariant::fromValue(static_cast<qlonglong>(feature.id()));
        record.orderText = orderValue.toString();
        bool numericOk = false;
        record.orderNumber = orderValue.toDouble(&numericOk);
        record.numericOrder = numericOk;
        groups[record.groupKey].append(record);
    }
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("group_key"), QVariant::String));
    fields.append(QgsField(QStringLiteral("point_cnt"), QVariant::Int));
    fields.append(QgsField(QStringLiteral("start_fid"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("end_fid"), QVariant::LongLong));
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("point_lines"), fields, Qgis::WkbType::LineString, layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create points-to-line output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QMap<QString, QVector<PointsToLineRecord>>::iterator groupIterator = groups.begin();
    while (groupIterator != groups.end()) {
        QVector<PointsToLineRecord> records = groupIterator.value();
        std::sort(records.begin(), records.end(), [](const PointsToLineRecord &left,
            const PointsToLineRecord &right) {
            if (left.numericOrder && right.numericOrder) {
                return left.orderNumber < right.orderNumber;
            }
            return left.orderText.localeAwareCompare(right.orderText) < 0;
        });
        if (records.count() >= 2) {
            QVector<QgsPointXY> points;
            for (int i = 0; i < records.count(); i++) {
                points.append(records.at(i).point);
            }
            if (closeLine && !SamePoint(points.first(), points.last())) {
                points.append(points.first());
            }
            QgsFeature outputFeature(fields);
            outputFeature.setAttribute(0, groupIterator.key());
            outputFeature.setAttribute(1, records.count());
            outputFeature.setAttribute(2, static_cast<qlonglong>(records.first().id));
            outputFeature.setAttribute(3, static_cast<qlonglong>(records.last().id));
            outputFeature.setGeometry(QgsGeometry::fromPolylineXY(points));
            if (!writer->addFeature(outputFeature)) {
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing line",
                    outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
            }
            writtenCount++;
        }
        ++groupIterator;
    }
    return MakeProcessResult(true, GIS_OK, "Points to line completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

enum class GeometryTransformMode {
    Densify,
    Smooth,
    RemoveHoles
};

static const char *TransformGeometryLayer(LayerHandle handle, GeometryTransformMode mode,
                                          double numericValue, const char *optionsText,
                                          const char *outputPath, const char *outputLayerName,
                                          int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid geometry transform parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    if (mode == GeometryTransformMode::Densify && numericValue <= 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Densify distance must be greater than zero",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    if (mode == GeometryTransformMode::RemoveHoles &&
        layer->geometryType() != Qgis::GeometryType::Polygon) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Remove holes requires polygon input",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("geometry_output"), layer->fields(), layer->wkbType(), layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create geometry output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int iterations = std::max(1, static_cast<int>(std::round(numericValue)));
    double offset = QString::fromUtf8(optionsText ? optionsText : "0.25").toDouble();
    if (offset <= 0.0 || offset >= 0.5) {
        offset = 0.25;
    }
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (mode == GeometryTransformMode::Densify) {
            geometry = geometry.densifyByDistance(numericValue);
        } else if (mode == GeometryTransformMode::Smooth) {
            geometry = geometry.smooth(iterations, offset);
        } else {
            double minimumArea = numericValue <= 0.0 ? -1.0 : numericValue;
            geometry = geometry.removeInteriorRings(minimumArea);
        }
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        QgsFeature outputFeature(layer->fields());
        outputFeature.setAttributes(feature.attributes());
        outputFeature.setGeometry(geometry);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing geometry output",
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK, "Geometry transformation completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static QString SafeOutputToken(const QString &value, int fallbackIndex)
{
    QString token = value.trimmed();
    for (int i = 0; i < token.length(); i++) {
        QChar character = token.at(i);
        if (!character.isLetterOrNumber() && character != QChar('_') && character != QChar('-')) {
            token[i] = QChar('_');
        }
    }
    if (token.isEmpty()) {
        token = QStringLiteral("group_%1").arg(fallbackIndex);
    }
    return token.left(40);
}

static const char *SplitByAttributesLayer(LayerHandle handle, const char *fieldNameText,
                                          const char *outputPath, const char *outputLayerName,
                                          int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid split-by-attributes parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QString fieldName = QString::fromUtf8(fieldNameText ? fieldNameText : "").trimmed();
    int fieldIndex = layer->fields().indexOf(fieldName);
    if (fieldIndex < 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Split field was not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QMap<QString, QVector<QgsFeature>> groups;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QString key = feature.attribute(fieldIndex).toString();
        groups[key].append(feature);
    }
    if (groups.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Input layer has no features",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QFileInfo requestedFile(QString::fromUtf8(outputPath));
    QString outputDirectory = requestedFile.absolutePath();
    QString outputBase = requestedFile.completeBaseName();
    QString firstOutputPath;
    int32_t writtenCount = 0;
    int groupIndex = 0;
    QMap<QString, QVector<QgsFeature>>::const_iterator groupIterator = groups.constBegin();
    while (groupIterator != groups.constEnd()) {
        groupIndex++;
        QString token = SafeOutputToken(groupIterator.key(), groupIndex);
        QString shardPath = QDir(outputDirectory).filePath(outputBase + QStringLiteral("_") +
            token + QStringLiteral(".shp"));
        QString shardLayerName = (outputLayerName && std::strlen(outputLayerName) > 0) ?
            QString::fromUtf8(outputLayerName) + QStringLiteral("_") + token : outputBase +
            QStringLiteral("_") + token;
        QByteArray shardPathBytes = shardPath.toUtf8();
        QByteArray shardLayerBytes = shardLayerName.toUtf8();
        std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(shardPathBytes.constData(),
            shardLayerBytes.constData(), shardLayerName, layer->fields(), layer->wkbType(), layer->crs());
        if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                "Failed to create split output shard", outputPath,
                outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        QVector<QgsFeature> groupFeatures = groupIterator.value();
        for (int i = 0; i < groupFeatures.count(); i++) {
            QgsFeature shardFeature = groupFeatures.at(i);
            if (!writer->addFeature(shardFeature)) {
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                    "Failed while writing split output shard", outputPath,
                    outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
            }
            writtenCount++;
        }
        writer.reset();
        if (firstOutputPath.isEmpty()) {
            firstOutputPath = shardPath;
        }
        ++groupIterator;
    }
    std::string message = "Split by attributes completed; outputs=" +
        std::to_string(static_cast<long long>(groups.count())) + "; directory=" +
        ToStdString(outputDirectory);
    return MakeProcessResult(true, GIS_OK, message, ToStdString(firstOutputPath),
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *ExtractByExtentLayer(LayerHandle handle, const char *extentText,
                                        const char *outputPath, const char *outputLayerName,
                                        int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid extent extraction parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QStringList values = QString::fromUtf8(extentText ? extentText : "").split(',');
    if (values.count() != 4) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Extent must be minX,minY,maxX,maxY", outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    bool ok0 = false;
    bool ok1 = false;
    bool ok2 = false;
    bool ok3 = false;
    double minX = values.at(0).toDouble(&ok0);
    double minY = values.at(1).toDouble(&ok1);
    double maxX = values.at(2).toDouble(&ok2);
    double maxY = values.at(3).toDouble(&ok3);
    if (!ok0 || !ok1 || !ok2 || !ok3 || minX >= maxX || minY >= maxY) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Extent values are invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("extent_extract"), layer->fields(), layer->wkbType(), layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create extent output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsRectangle extent(minX, minY, maxX, maxY);
    QgsFeatureRequest request;
    request.setFilterRect(extent);
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = layer->getFeatures(request);
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (!writer->addFeature(feature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing extent result",
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK, "Extract by extent completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *ExtractByTimeLayer(LayerHandle handle, const char *optionsText,
                                      const char *outputPath, const char *outputLayerName,
                                      int32_t *outErrCode)
{
    QStringList options = QString::fromUtf8(optionsText ? optionsText : "").split(';');
    if (options.count() < 3) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Time extraction requires field;start;end", outputPath ? outputPath : "",
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QString fieldName = options.at(0).trimmed();
    QString startValue = options.at(1).trimmed();
    QString endValue = options.at(2).trimmed();
    QString escapedStart = startValue;
    QString escapedEnd = endValue;
    escapedStart.replace(QChar('\''), QStringLiteral("''"));
    escapedEnd.replace(QChar('\''), QStringLiteral("''"));
    QString expression = QStringLiteral("\"") + fieldName + QStringLiteral("\" >= '") +
        escapedStart + QStringLiteral("' AND \"") + fieldName + QStringLiteral("\" <= '") +
        escapedEnd + QStringLiteral("'");
    QByteArray expressionBytes = expression.toUtf8();
    return ExtractByExpressionLayer(handle, expressionBytes.constData(), outputPath,
        outputLayerName, outErrCode);
}

static const char *SummarizeWithinLayer(LayerHandle polygonHandle, LayerHandle summaryHandle,
                                        const char *fieldNameText, const char *outputPath,
                                        const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *polygonState = FindLayer(polygonHandle);
    QgisLayerState *summaryState = FindLayer(summaryHandle);
    if (!polygonState || !polygonState->layer || !summaryState || !summaryState->layer ||
        polygonState->layer->geometryType() != Qgis::GeometryType::Polygon ||
        !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Summarize Within requires polygon zones and a summary layer",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *polygonLayer = polygonState->layer.get();
    QgsVectorLayer *summaryLayer = summaryState->layer.get();
    QString fieldName = QString::fromUtf8(fieldNameText ? fieldNameText : "NONE").trimmed();
    int summaryFieldIndex = fieldName.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) == 0 ?
        -1 : summaryLayer->fields().indexOf(fieldName);
    if (summaryFieldIndex < 0 && fieldName.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) != 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Summary field was not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<OverlayFeatureRecord> summaries;
    std::string loadMessage;
    if (!LoadOverlayFeatureRecords(summaryLayer, polygonLayer->crs(), summaries, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsFields fields = polygonLayer->fields();
    int countIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("sum_count"), QVariant::LongLong), QString());
    int valueIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("sum_value"), QVariant::Double), QString());
    int areaIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("sum_area"), QVariant::Double), QString());
    int lengthIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("sum_len"), QVariant::Double), QString());
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("summarize_within"), fields, polygonLayer->wkbType(), polygonLayer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create summary output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = polygonLayer->getFeatures();
    QgsFeature polygonFeature;
    while (iterator.nextFeature(polygonFeature)) {
        QgsGeometry polygonGeometry = polygonFeature.geometry();
        qlonglong matchCount = 0;
        double valueSum = 0.0;
        double areaSum = 0.0;
        double lengthSum = 0.0;
        for (size_t i = 0; i < summaries.size(); i++) {
            if (!polygonGeometry.intersects(summaries[i].geometry)) {
                continue;
            }
            matchCount++;
            QgsGeometry intersection = polygonGeometry.intersection(summaries[i].geometry);
            areaSum += intersection.area();
            lengthSum += intersection.length();
            if (summaryFieldIndex >= 0 && summaryFieldIndex < summaries[i].attributes.count()) {
                bool numericOk = false;
                double currentValue = summaries[i].attributes.at(summaryFieldIndex).toDouble(&numericOk);
                if (numericOk) {
                    valueSum += currentValue;
                }
            }
        }
        QgsFeature outputFeature(fields);
        outputFeature.setAttributes(polygonFeature.attributes());
        outputFeature.setAttribute(countIndex, matchCount);
        outputFeature.setAttribute(valueIndex, valueSum);
        outputFeature.setAttribute(areaIndex, areaSum);
        outputFeature.setAttribute(lengthIndex, lengthSum);
        outputFeature.setGeometry(polygonGeometry);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing summary zone",
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK, "Summarize Within completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *TabulateIntersectionLayer(LayerHandle zoneHandle, LayerHandle classHandle,
                                             const char *outputPath, const char *outputLayerName,
                                             int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *zoneState = FindLayer(zoneHandle);
    QgisLayerState *classState = FindLayer(classHandle);
    if (!zoneState || !zoneState->layer || !classState || !classState->layer ||
        zoneState->layer->geometryType() != Qgis::GeometryType::Polygon ||
        !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Tabulate Intersection requires polygon zones", outputPath ? outputPath : "",
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *zoneLayer = zoneState->layer.get();
    std::vector<OverlayFeatureRecord> classes;
    std::string loadMessage;
    if (!LoadOverlayFeatureRecords(classState->layer.get(), zoneLayer->crs(), classes, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("zone_fid"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("class_fid"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("measure"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("percent"), QVariant::Double));
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("tabulate_intersection"), fields, Qgis::WkbType::Point, zoneLayer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create tabulation output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = zoneLayer->getFeatures();
    QgsFeature zoneFeature;
    while (iterator.nextFeature(zoneFeature)) {
        QgsGeometry zoneGeometry = zoneFeature.geometry();
        double zoneArea = zoneGeometry.area();
        for (size_t i = 0; i < classes.size(); i++) {
            if (!zoneGeometry.intersects(classes[i].geometry)) {
                continue;
            }
            QgsGeometry intersection = zoneGeometry.intersection(classes[i].geometry);
            if (intersection.isNull() || intersection.isEmpty()) {
                continue;
            }
            double measure = QgsWkbTypes::geometryType(intersection.wkbType()) ==
                Qgis::GeometryType::Polygon ? intersection.area() : intersection.length();
            QgsGeometry location = intersection.pointOnSurface();
            if (location.isNull() || location.isEmpty()) {
                location = zoneGeometry.pointOnSurface();
            }
            QgsFeature outputFeature(fields);
            outputFeature.setAttribute(0, static_cast<qlonglong>(zoneFeature.id()));
            outputFeature.setAttribute(1, static_cast<qlonglong>(classes[i].id));
            outputFeature.setAttribute(2, measure);
            outputFeature.setAttribute(3, zoneArea > 0.0 ? measure * 100.0 / zoneArea : 0.0);
            outputFeature.setGeometry(location);
            if (!writer->addFeature(outputFeature)) {
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                    "Failed while writing tabulated intersection", outputPath,
                    outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
            }
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Tabulate Intersection completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static QgsPointXY QualityRepresentativePoint(const QgsGeometry &geometry, QgsVectorLayer *layer);

static const char *NearLayer(LayerHandle inputHandle, LayerHandle targetHandle,
                             const char *outputPath, const char *outputLayerName,
                             int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *targetState = FindLayer(targetHandle);
    if (!inputState || !inputState->layer || !targetState || !targetState->layer ||
        !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid Near parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *inputLayer = inputState->layer.get();
    std::vector<OverlayFeatureRecord> targets;
    std::string loadMessage;
    if (!LoadOverlayFeatureRecords(targetState->layer.get(), inputLayer->crs(), targets, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsFields fields = inputLayer->fields();
    int nearFidIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("near_fid"), QVariant::LongLong), QString());
    int nearDistanceIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("near_dist"), QVariant::Double), QString());
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("near_output"), fields, inputLayer->wkbType(), inputLayer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create Near output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = inputLayer->getFeatures();
    QgsFeature inputFeature;
    while (iterator.nextFeature(inputFeature)) {
        QgsGeometry inputGeometry = inputFeature.geometry();
        double nearestDistance = std::numeric_limits<double>::max();
        QgsFeatureId nearestId = -1;
        for (size_t i = 0; i < targets.size(); i++) {
            if (inputHandle == targetHandle && inputFeature.id() == targets[i].id) {
                continue;
            }
            double distance = inputGeometry.distance(targets[i].geometry);
            if (distance < nearestDistance) {
                nearestDistance = distance;
                nearestId = targets[i].id;
            }
        }
        QgsFeature outputFeature(fields);
        outputFeature.setAttributes(inputFeature.attributes());
        outputFeature.setAttribute(nearFidIndex, static_cast<qlonglong>(nearestId));
        outputFeature.setAttribute(nearDistanceIndex,
            nearestId >= 0 ? nearestDistance : QVariant());
        outputFeature.setGeometry(inputGeometry);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing Near output",
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK, "Near completed with true geometry distance", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *GenerateNearTableLayer(LayerHandle inputHandle, LayerHandle targetHandle,
                                          int neighborCount, double maximumDistance,
                                          const char *outputPath, const char *outputLayerName,
                                          int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *targetState = FindLayer(targetHandle);
    if (!inputState || !inputState->layer || !targetState || !targetState->layer ||
        !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid near-table parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *inputLayer = inputState->layer.get();
    std::vector<OverlayFeatureRecord> targets;
    std::string loadMessage;
    if (!LoadOverlayFeatureRecords(targetState->layer.get(), inputLayer->crs(), targets, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("source_fid"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("target_fid"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("near_rank"), QVariant::Int));
    fields.append(QgsField(QStringLiteral("distance"), QVariant::Double));
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("near_table"), fields, Qgis::WkbType::LineString, inputLayer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create near-table output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = inputLayer->getFeatures();
    QgsFeature inputFeature;
    while (iterator.nextFeature(inputFeature)) {
        QgsGeometry inputGeometry = inputFeature.geometry();
        std::vector<std::pair<double, size_t>> matches;
        for (size_t i = 0; i < targets.size(); i++) {
            if (inputHandle == targetHandle && inputFeature.id() == targets[i].id) {
                continue;
            }
            double distance = inputGeometry.distance(targets[i].geometry);
            if (maximumDistance <= 0.0 || distance <= maximumDistance) {
                matches.push_back(std::make_pair(distance, i));
            }
        }
        std::sort(matches.begin(), matches.end(), [](const std::pair<double, size_t> &left,
            const std::pair<double, size_t> &right) { return left.first < right.first; });
        int outputLimit = neighborCount <= 0 ? static_cast<int>(matches.size()) :
            std::min(neighborCount, static_cast<int>(matches.size()));
        for (int rank = 0; rank < outputLimit; rank++) {
            const std::pair<double, size_t> &match = matches[static_cast<size_t>(rank)];
            QgsGeometry link = inputGeometry.shortestLine(targets[match.second].geometry);
            if (link.isNull() || link.isEmpty()) {
                QgsPointXY start = QualityRepresentativePoint(inputGeometry, inputLayer);
                QgsPointXY end = QualityRepresentativePoint(targets[match.second].geometry, inputLayer);
                QVector<QgsPointXY> linePoints;
                linePoints.append(start);
                linePoints.append(end);
                link = QgsGeometry::fromPolylineXY(linePoints);
            }
            QgsFeature outputFeature(fields);
            outputFeature.setAttribute(0, static_cast<qlonglong>(inputFeature.id()));
            outputFeature.setAttribute(1, static_cast<qlonglong>(targets[match.second].id));
            outputFeature.setAttribute(2, rank + 1);
            outputFeature.setAttribute(3, match.first);
            outputFeature.setGeometry(link);
            if (!writer->addFeature(outputFeature)) {
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                    "Failed while writing near-table row", outputPath,
                    outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
            }
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Near table completed with ranked geometry distances",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static QString WriteStatisticsChart(const QMap<QString, StatisticsGroupRecord> &groups,
                                    const QString &outputPath)
{
    if (groups.isEmpty()) {
        return QString();
    }
    QFileInfo outputInfo(outputPath);
    QString chartPath = QDir(outputInfo.absolutePath()).filePath(
        outputInfo.completeBaseName() + QStringLiteral("_chart.svg"));
    QSvgGenerator generator;
    generator.setFileName(chartPath);
    generator.setSize(QSize(1000, 600));
    generator.setViewBox(QRect(0, 0, 1000, 600));
    generator.setTitle(QStringLiteral("GeoNest Statistics"));
    QPainter painter(&generator);
    if (!painter.isActive()) {
        return QString();
    }
    painter.fillRect(QRect(0, 0, 1000, 600), QColor(255, 255, 255));
    painter.setPen(QColor(30, 30, 30));
    painter.drawText(QRect(40, 20, 920, 40), Qt::AlignLeft | Qt::AlignVCenter,
        QStringLiteral("统计结果图表"));
    double maximumValue = 1.0;
    QMap<QString, StatisticsGroupRecord>::const_iterator maxIterator = groups.constBegin();
    while (maxIterator != groups.constEnd()) {
        double value = maxIterator.value().numericCount > 0 ? maxIterator.value().sum :
            static_cast<double>(maxIterator.value().count);
        maximumValue = std::max(maximumValue, std::abs(value));
        ++maxIterator;
    }
    int visibleCount = std::min(20, static_cast<int>(groups.count()));
    int barWidth = std::max(12, 860 / std::max(1, visibleCount));
    int chartIndex = 0;
    QMap<QString, StatisticsGroupRecord>::const_iterator chartIterator = groups.constBegin();
    while (chartIterator != groups.constEnd() && chartIndex < visibleCount) {
        double value = chartIterator.value().numericCount > 0 ? chartIterator.value().sum :
            static_cast<double>(chartIterator.value().count);
        int barHeight = static_cast<int>(std::round(std::abs(value) * 420.0 / maximumValue));
        int x = 60 + chartIndex * barWidth;
        painter.fillRect(QRect(x, 500 - barHeight, std::max(8, barWidth - 8), barHeight),
            QColor(46, 107, 255));
        painter.save();
        painter.translate(x + 4, 530);
        painter.rotate(-45.0);
        painter.drawText(QRect(0, 0, 160, 20), Qt::AlignLeft, chartIterator.key().left(20));
        painter.restore();
        chartIndex++;
        ++chartIterator;
    }
    painter.drawLine(50, 500, 960, 500);
    painter.end();
    return QFileInfo::exists(chartPath) ? chartPath : QString();
}

static const char *SummaryStatisticsLayer(LayerHandle handle, const char *optionsText,
                                          bool createChart, const char *outputPath,
                                          const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid statistics parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QStringList options = QString::fromUtf8(optionsText ? optionsText : "NONE;NONE;NONE").split(';');
    QString groupField = options.value(0, QStringLiteral("NONE")).trimmed();
    QString categoryField = options.value(1, QStringLiteral("NONE")).trimmed();
    QString valueField = options.value(2, QStringLiteral("NONE")).trimmed();
    int groupIndex = groupField.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) == 0 ?
        -1 : layer->fields().indexOf(groupField);
    int categoryIndex = categoryField.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) == 0 ?
        -1 : layer->fields().indexOf(categoryField);
    int valueIndex = valueField.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) == 0 ?
        -1 : layer->fields().indexOf(valueField);
    if ((groupIndex < 0 && groupField.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) != 0) ||
        (categoryIndex < 0 && categoryField.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) != 0) ||
        (valueIndex < 0 && valueField.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) != 0)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Statistics field was not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QMap<QString, StatisticsGroupRecord> groups;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QString groupKey = groupIndex >= 0 ? feature.attribute(groupIndex).toString() :
            QStringLiteral("ALL");
        QString categoryKey = categoryIndex >= 0 ? feature.attribute(categoryIndex).toString() :
            QStringLiteral("ALL");
        QString mapKey = groupKey + QChar(31) + categoryKey;
        StatisticsGroupRecord record = groups.value(mapKey);
        if (record.count == 0) {
            record.groupKey = groupKey;
            record.categoryKey = categoryKey;
            record.location = feature.geometry().pointOnSurface();
            if (record.location.isNull() || record.location.isEmpty()) {
                record.location = feature.geometry().centroid();
            }
        }
        record.count++;
        if (valueIndex >= 0) {
            bool numericOk = false;
            double value = feature.attribute(valueIndex).toDouble(&numericOk);
            if (numericOk) {
                if (record.numericCount == 0) {
                    record.minimum = value;
                    record.maximum = value;
                } else {
                    record.minimum = std::min(record.minimum, value);
                    record.maximum = std::max(record.maximum, value);
                }
                record.numericCount++;
                record.sum += value;
                record.sumSquares += value * value;
            }
        }
        groups.insert(mapKey, record);
    }
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("group_key"), QVariant::String));
    fields.append(QgsField(QStringLiteral("category"), QVariant::String));
    fields.append(QgsField(QStringLiteral("frequency"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("sum"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("minimum"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("maximum"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("mean"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("stddev"), QVariant::Double));
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("summary_statistics"), fields, Qgis::WkbType::Point, layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create statistics output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QMap<QString, StatisticsGroupRecord>::const_iterator groupIterator = groups.constBegin();
    while (groupIterator != groups.constEnd()) {
        StatisticsGroupRecord record = groupIterator.value();
        double mean = record.numericCount > 0 ? record.sum /
            static_cast<double>(record.numericCount) : 0.0;
        double variance = record.numericCount > 0 ? record.sumSquares /
            static_cast<double>(record.numericCount) - mean * mean : 0.0;
        QgsFeature outputFeature(fields);
        outputFeature.setAttribute(0, record.groupKey);
        outputFeature.setAttribute(1, record.categoryKey);
        outputFeature.setAttribute(2, record.count);
        outputFeature.setAttribute(3, record.sum);
        outputFeature.setAttribute(4, record.minimum);
        outputFeature.setAttribute(5, record.maximum);
        outputFeature.setAttribute(6, mean);
        outputFeature.setAttribute(7, std::sqrt(std::max(0.0, variance)));
        outputFeature.setGeometry(record.location);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing statistics row",
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
        ++groupIterator;
    }
    writer.reset();
    QString chartPath;
    if (createChart) {
        chartPath = WriteStatisticsChart(groups, QString::fromUtf8(outputPath));
    }
    std::string message = "Summary statistics completed; groups=" +
        std::to_string(static_cast<long long>(groups.count()));
    if (!chartPath.isEmpty()) {
        message += "; chart=" + ToStdString(chartPath);
    }
    return MakeProcessResult(true, GIS_OK, message, outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *PolygonNeighborsLayer(LayerHandle handle, const char *outputPath,
                                         const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || state->layer->geometryType() != Qgis::GeometryType::Polygon ||
        !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Polygon Neighbors requires polygon input", outputPath ? outputPath : "",
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    std::vector<OverlayFeatureRecord> polygons;
    std::string loadMessage;
    if (!LoadOverlayFeatureRecords(layer, layer->crs(), polygons, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("source_fid"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("neighbor"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("shared_len"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("overlap_ar"), QVariant::Double));
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("polygon_neighbors"), fields, Qgis::WkbType::LineString, layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create neighbors output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    for (size_t i = 0; i < polygons.size(); i++) {
        for (size_t j = i + 1; j < polygons.size(); j++) {
            if (!polygons[i].geometry.intersects(polygons[j].geometry) &&
                !polygons[i].geometry.touches(polygons[j].geometry)) {
                continue;
            }
            QgsGeometry boundaryA(polygons[i].geometry.constGet()->boundary());
            QgsGeometry boundaryB(polygons[j].geometry.constGet()->boundary());
            double sharedLength = boundaryA.intersection(boundaryB).length();
            double overlapArea = polygons[i].geometry.intersection(polygons[j].geometry).area();
            QgsPointXY start = QualityRepresentativePoint(polygons[i].geometry, layer);
            QgsPointXY end = QualityRepresentativePoint(polygons[j].geometry, layer);
            QVector<QgsPointXY> points;
            points.append(start);
            points.append(end);
            QgsFeature outputFeature(fields);
            outputFeature.setAttribute(0, static_cast<qlonglong>(polygons[i].id));
            outputFeature.setAttribute(1, static_cast<qlonglong>(polygons[j].id));
            outputFeature.setAttribute(2, sharedLength);
            outputFeature.setAttribute(3, overlapArea);
            outputFeature.setGeometry(QgsGeometry::fromPolylineXY(points));
            if (!writer->addFeature(outputFeature)) {
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                    "Failed while writing polygon neighbor", outputPath,
                    outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
            }
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Polygon Neighbors completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *SnapOutputLayer(LayerHandle inputHandle, LayerHandle targetHandle,
                                   double tolerance, const char *outputPath,
                                   const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *targetState = FindLayer(targetHandle);
    if (!inputState || !inputState->layer || !targetState || !targetState->layer ||
        tolerance <= 0.0 || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid Snap parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *inputLayer = inputState->layer.get();
    std::vector<OverlayFeatureRecord> targets;
    std::string loadMessage;
    if (!LoadOverlayFeatureRecords(targetState->layer.get(), inputLayer->crs(), targets, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<QgsPointXY> targetPoints;
    for (size_t i = 0; i < targets.size(); i++) {
        CollectGeometryPoints(targets[i].geometry, targetPoints);
    }
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("snap_output"), inputLayer->fields(), inputLayer->wkbType(), inputLayer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create Snap output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = inputLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        SnapGeometryToTargets(geometry, targetPoints, tolerance);
        QgsFeature outputFeature(inputLayer->fields());
        outputFeature.setAttributes(feature.attributes());
        outputFeature.setGeometry(geometry);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing Snap output",
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK, "Snap completed without modifying the source layer",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

enum class GeometryCleanupMode {
    ExtendLine,
    RemoveFragments,
    UnifyDirection
};

static QgsPointXY InterpolatePolylinePoint(const QVector<QgsPointXY> &points, double distance)
{
    double traversed = 0.0;
    for (int i = 1; i < points.count(); i++) {
        double dx = points.at(i).x() - points.at(i - 1).x();
        double dy = points.at(i).y() - points.at(i - 1).y();
        double segmentLength = std::sqrt(dx * dx + dy * dy);
        if (traversed + segmentLength >= distance && segmentLength > 0.0) {
            double ratio = (distance - traversed) / segmentLength;
            return QgsPointXY(points.at(i - 1).x() + dx * ratio,
                points.at(i - 1).y() + dy * ratio);
        }
        traversed += segmentLength;
    }
    return points.isEmpty() ? QgsPointXY() : points.last();
}

static QVector<QgsPointXY> TrimPolylinePoints(const QVector<QgsPointXY> &points,
                                              double startTrim, double endTrim)
{
    QVector<QgsPointXY> output;
    if (points.count() < 2) return output;
    double totalLength = 0.0;
    QVector<double> vertexDistances;
    vertexDistances.append(0.0);
    for (int i = 1; i < points.count(); i++) {
        double dx = points.at(i).x() - points.at(i - 1).x();
        double dy = points.at(i).y() - points.at(i - 1).y();
        totalLength += std::sqrt(dx * dx + dy * dy);
        vertexDistances.append(totalLength);
    }
    double startDistance = std::min(std::max(0.0, startTrim), totalLength);
    double endDistance = std::max(startDistance, totalLength - std::max(0.0, endTrim));
    if (endDistance <= startDistance) return output;
    output.append(InterpolatePolylinePoint(points, startDistance));
    for (int i = 1; i < points.count() - 1; i++) {
        if (vertexDistances.at(i) > startDistance && vertexDistances.at(i) < endDistance) {
            output.append(points.at(i));
        }
    }
    output.append(InterpolatePolylinePoint(points, endDistance));
    return output;
}

static QgsGeometry TrimLineGeometry(const QgsGeometry &geometry, double startTrim, double endTrim)
{
    if (QgsWkbTypes::isMultiType(geometry.wkbType())) {
        QgsMultiPolylineXY inputParts = geometry.asMultiPolyline();
        QgsMultiPolylineXY outputParts;
        for (int i = 0; i < inputParts.count(); i++) {
            QVector<QgsPointXY> part = TrimPolylinePoints(inputParts.at(i), startTrim, endTrim);
            if (part.count() >= 2) outputParts.append(part);
        }
        return QgsGeometry::fromMultiPolylineXY(outputParts);
    }
    return QgsGeometry::fromPolylineXY(TrimPolylinePoints(geometry.asPolyline(), startTrim, endTrim));
}

static const char *GeometryCleanupLayer(LayerHandle handle, GeometryCleanupMode mode,
                                        double numericValue, const char *optionsText,
                                        const char *outputPath, const char *outputLayerName,
                                        int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid cleanup parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    if (mode == GeometryCleanupMode::ExtendLine &&
        layer->geometryType() != Qgis::GeometryType::Line) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Extend Line requires line input",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    if (mode == GeometryCleanupMode::UnifyDirection &&
        layer->geometryType() != Qgis::GeometryType::Polygon) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Direction unification requires polygon input", outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    double endDistance = QString::fromUtf8(optionsText ? optionsText : "0").toDouble();
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("cleanup_output"), layer->fields(), layer->wkbType(), layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create cleanup output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (mode == GeometryCleanupMode::RemoveFragments) {
            double measure = layer->geometryType() == Qgis::GeometryType::Polygon ?
                geometry.area() : geometry.length();
            if (measure < numericValue) {
                continue;
            }
        } else if (mode == GeometryCleanupMode::ExtendLine) {
            if (numericValue < 0.0 || endDistance < 0.0) {
                geometry = TrimLineGeometry(geometry, std::abs(std::min(0.0, numericValue)),
                    std::abs(std::min(0.0, endDistance)));
            } else {
                geometry = geometry.extendLine(numericValue, endDistance);
            }
        } else {
            geometry = geometry.forceRHR();
        }
        QgsFeature outputFeature(layer->fields());
        outputFeature.setAttributes(feature.attributes());
        outputFeature.setGeometry(geometry);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing cleanup output",
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK, "Geometry cleanup completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *AggregatePolygonsLayer(LayerHandle handle, double distance,
                                          const char *outputPath, const char *outputLayerName,
                                          int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || state->layer->geometryType() != Qgis::GeometryType::Polygon ||
        distance < 0.0 || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Aggregate Polygons requires polygon input and nonnegative distance",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QVector<QgsGeometry> geometries;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (distance > 0.0) {
            geometry = geometry.buffer(distance, 12);
        }
        geometries.append(geometry);
    }
    QgsGeometry aggregated = QgsGeometry::unaryUnion(geometries);
    if (distance > 0.0) {
        aggregated = aggregated.buffer(-distance, 12);
    }
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("source_cnt"), QVariant::LongLong));
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("aggregate_polygons"), fields, Qgis::WkbType::MultiPolygon, layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create aggregate output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    if (!QgsWkbTypes::isMultiType(aggregated.wkbType())) {
        aggregated.convertToMultiType();
    }
    QgsFeature outputFeature(fields);
    outputFeature.setAttribute(0, static_cast<qlonglong>(layer->featureCount()));
    outputFeature.setGeometry(aggregated);
    if (!writer->addFeature(outputFeature)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to write aggregate output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Aggregate Polygons completed", outputPath,
        outputLayerName ? outputLayerName : "", 1, outErrCode);
}

static const char *EliminatePolygonsLayer(LayerHandle handle, double areaThreshold,
                                          const char *outputPath, const char *outputLayerName,
                                          int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || state->layer->geometryType() != Qgis::GeometryType::Polygon ||
        areaThreshold <= 0.0 || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Eliminate requires polygon input and a positive area threshold",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    std::vector<OverlayFeatureRecord> records;
    std::string loadMessage;
    if (!LoadOverlayFeatureRecords(layer, layer->crs(), records, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<bool> active(records.size(), true);
    for (size_t i = 0; i < records.size(); i++) {
        if (!active[i] || records[i].geometry.area() >= areaThreshold) continue;
        int bestNeighbor = -1;
        double bestSharedLength = -1.0;
        double bestDistance = std::numeric_limits<double>::max();
        QgsGeometry sourceBoundary(records[i].geometry.constGet()->boundary());
        for (size_t j = 0; j < records.size(); j++) {
            if (i == j || !active[j]) continue;
            QgsGeometry targetBoundary(records[j].geometry.constGet()->boundary());
            double sharedLength = sourceBoundary.intersection(targetBoundary).length();
            double distance = records[i].geometry.distance(records[j].geometry);
            if (sharedLength > bestSharedLength ||
                (std::abs(sharedLength - bestSharedLength) < 1e-12 && distance < bestDistance)) {
                bestNeighbor = static_cast<int>(j);
                bestSharedLength = sharedLength;
                bestDistance = distance;
            }
        }
        if (bestNeighbor >= 0) {
            records[static_cast<size_t>(bestNeighbor)].geometry =
                records[static_cast<size_t>(bestNeighbor)].geometry.combine(records[i].geometry);
            active[i] = false;
        }
    }
    QgsFields fields = layer->fields();
    int eliminatedIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("eliminated"), QVariant::Int), QString());
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("eliminate"), fields, layer->wkbType(), layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create Eliminate output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    int eliminatedCount = 0;
    for (size_t i = 0; i < records.size(); i++) {
        if (!active[i]) {
            eliminatedCount++;
            continue;
        }
        QgsFeature outputFeature(fields);
        outputFeature.setAttributes(records[i].attributes);
        outputFeature.setAttribute(eliminatedIndex, eliminatedCount);
        outputFeature.setGeometry(records[i].geometry);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing Eliminate output",
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK,
        "Eliminate completed using longest shared boundary and nearest-neighbor fallback",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *CenterlineLayer(LayerHandle handle, const char *outputPath,
                                   const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || state->layer->geometryType() != Qgis::GeometryType::Polygon ||
        !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Centerline requires polygon input",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QgsFields fields = layer->fields();
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("centerlines"), fields, Qgis::WkbType::LineString, layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create centerline output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        double area = 0.0;
        double angle = 0.0;
        double width = 0.0;
        double height = 0.0;
        feature.geometry().orientedMinimumBoundingBox(area, angle, width, height);
        QgsPointXY center = feature.geometry().centroid().asPoint();
        double length = std::max(width, height);
        double axisAngle = angle;
        if (height > width) {
            axisAngle += 90.0;
        }
        double radians = axisAngle * 3.14159265358979323846 / 180.0;
        double dx = std::cos(radians) * length * 0.5;
        double dy = std::sin(radians) * length * 0.5;
        QVector<QgsPointXY> points;
        points.append(QgsPointXY(center.x() - dx, center.y() - dy));
        points.append(QgsPointXY(center.x() + dx, center.y() + dy));
        QgsGeometry axis = QgsGeometry::fromPolylineXY(points).intersection(feature.geometry());
        if (axis.isNull() || axis.isEmpty()) {
            continue;
        }
        QgsFeature outputFeature(fields);
        outputFeature.setAttributes(feature.attributes());
        outputFeature.setGeometry(axis);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing centerline",
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK, "Centerlines generated from polygon principal axes",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

enum class SamplingGridMode {
    Fishnet,
    Hexagon,
    RandomPoints,
    RegularPoints
};

static const char *SamplingGridLayer(LayerHandle handle, SamplingGridMode mode,
                                     double numericValue, const char *optionsText,
                                     const char *outputPath, const char *outputLayerName,
                                     int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || numericValue <= 0.0 ||
        !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid grid or sampling parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QgsRectangle extent = layer->extent();
    bool pointMode = mode == SamplingGridMode::RandomPoints || mode == SamplingGridMode::RegularPoints;
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("cell_id"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("row_id"), QVariant::Int));
    fields.append(QgsField(QStringLiteral("col_id"), QVariant::Int));
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("sampling_grid"), fields,
        pointMode ? Qgis::WkbType::Point : Qgis::WkbType::Polygon, layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create grid output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    if (mode == SamplingGridMode::RandomPoints) {
        int pointCount = std::max(1, static_cast<int>(std::round(numericValue)));
        int seed = QString::fromUtf8(optionsText ? optionsText : "1").toInt();
        std::mt19937 generator(static_cast<unsigned int>(seed));
        std::uniform_real_distribution<double> xDistribution(extent.xMinimum(), extent.xMaximum());
        std::uniform_real_distribution<double> yDistribution(extent.yMinimum(), extent.yMaximum());
        for (int i = 0; i < pointCount; i++) {
            QgsPointXY point(xDistribution(generator), yDistribution(generator));
            QgsFeature outputFeature(fields);
            outputFeature.setAttribute(0, static_cast<qlonglong>(i + 1));
            outputFeature.setAttribute(1, 0);
            outputFeature.setAttribute(2, 0);
            outputFeature.setGeometry(QgsGeometry::fromPointXY(point));
            if (writer->addFeature(outputFeature)) {
                writtenCount++;
            }
        }
    } else {
        double spacing = numericValue;
        double rowStep = mode == SamplingGridMode::Hexagon ? spacing * 0.866025403784 : spacing;
        int row = 0;
        for (double y = extent.yMinimum(); y < extent.yMaximum(); y += rowStep) {
            int column = 0;
            double xOffset = mode == SamplingGridMode::Hexagon && row % 2 == 1 ? spacing * 0.75 : 0.0;
            for (double x = extent.xMinimum() + xOffset; x < extent.xMaximum(); x += spacing) {
                QgsGeometry geometry;
                if (mode == SamplingGridMode::RegularPoints) {
                    geometry = QgsGeometry::fromPointXY(QgsPointXY(x, y));
                } else {
                    QVector<QgsPointXY> ring;
                    if (mode == SamplingGridMode::Fishnet) {
                        ring.append(QgsPointXY(x, y));
                        ring.append(QgsPointXY(x + spacing, y));
                        ring.append(QgsPointXY(x + spacing, y + spacing));
                        ring.append(QgsPointXY(x, y + spacing));
                        ring.append(QgsPointXY(x, y));
                    } else {
                        for (int vertex = 0; vertex < 6; vertex++) {
                            double vertexAngle = (60.0 * vertex + 30.0) *
                                3.14159265358979323846 / 180.0;
                            ring.append(QgsPointXY(x + std::cos(vertexAngle) * spacing * 0.5,
                                y + std::sin(vertexAngle) * spacing * 0.5));
                        }
                        ring.append(ring.first());
                    }
                    QVector<QVector<QgsPointXY>> polygon;
                    polygon.append(ring);
                    geometry = QgsGeometry::fromPolygonXY(polygon);
                }
                QgsFeature outputFeature(fields);
                outputFeature.setAttribute(0, static_cast<qlonglong>(writtenCount + 1));
                outputFeature.setAttribute(1, row);
                outputFeature.setAttribute(2, column);
                outputFeature.setGeometry(geometry);
                if (writer->addFeature(outputFeature)) {
                    writtenCount++;
                }
                column++;
            }
            row++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Grid or sampling output completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static QgsGeometry GeodesicLocalBuffer(const QgsGeometry &sourceGeometry,
                                       const QgsCoordinateReferenceSystem &sourceCrs,
                                       double distanceMeters, int segments,
                                       Qgis::EndCapStyle endCapStyle,
                                       Qgis::JoinStyle joinStyle, double miterLimit,
                                       std::string &message)
{
    QgsCoordinateReferenceSystem geographic = QgsCoordinateReferenceSystem::fromEpsgId(4326);
    QgsGeometry geographicGeometry = sourceGeometry;
    if (!TransformGeometryToCrs(geographicGeometry, sourceCrs, geographic, message)) {
        return QgsGeometry();
    }
    QgsPointXY center = geographicGeometry.centroid().asPoint();
    QString localDefinition = QStringLiteral("+proj=aeqd +lat_0=%1 +lon_0=%2 +datum=WGS84 +units=m +no_defs")
        .arg(center.y(), 0, 'f', 10).arg(center.x(), 0, 'f', 10);
    QgsCoordinateReferenceSystem localCrs = QgsCoordinateReferenceSystem::fromProj(localDefinition);
    if (!localCrs.isValid()) {
        message = "Failed to create local geodesic buffer CRS";
        return QgsGeometry();
    }
    QgsGeometry localGeometry = geographicGeometry;
    if (!TransformGeometryToCrs(localGeometry, geographic, localCrs, message)) {
        return QgsGeometry();
    }
    QgsGeometry buffered = localGeometry.buffer(distanceMeters, segments, endCapStyle,
        joinStyle, miterLimit);
    if (!TransformGeometryToCrs(buffered, localCrs, sourceCrs, message)) {
        return QgsGeometry();
    }
    return buffered;
}

static const char *AdvancedBufferLayer(LayerHandle handle, double defaultDistance,
                                       const char *optionsText, const char *outputPath,
                                       const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid advanced buffer parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QStringList options = QString::fromUtf8(optionsText ? optionsText :
        "NONE;16;1;1;-1;0;0").split(';');
    QString distanceField = options.value(0, QStringLiteral("NONE")).trimmed();
    int distanceFieldIndex = distanceField.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) == 0 ?
        -1 : layer->fields().indexOf(distanceField);
    if (distanceFieldIndex < 0 && distanceField.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) != 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Buffer distance field was not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int segments = std::max(1, options.value(1, QStringLiteral("16")).toInt());
    int capValue = options.value(2, QStringLiteral("1")).toInt();
    int joinValue = options.value(3, QStringLiteral("1")).toInt();
    int sideValue = options.value(4, QStringLiteral("-1")).toInt();
    bool dissolve = options.value(5, QStringLiteral("0")) == QStringLiteral("1");
    bool geodesic = options.value(6, QStringLiteral("0")) == QStringLiteral("1");
    Qgis::EndCapStyle capStyle = capValue == 2 ? Qgis::EndCapStyle::Flat :
        (capValue == 3 ? Qgis::EndCapStyle::Square : Qgis::EndCapStyle::Round);
    Qgis::JoinStyle joinStyle = joinValue == 2 ? Qgis::JoinStyle::Miter :
        (joinValue == 3 ? Qgis::JoinStyle::Bevel : Qgis::JoinStyle::Round);
    QgsFields fields = dissolve ? QgsFields() : layer->fields();
    int sourceCountIndex = -1;
    if (dissolve) {
        fields.append(QgsField(QStringLiteral("source_cnt"), QVariant::LongLong));
        sourceCountIndex = 0;
    }
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("advanced_buffer"), fields, Qgis::WkbType::MultiPolygon, layer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create advanced buffer output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QVector<QgsGeometry> dissolveGeometries;
    int32_t writtenCount = 0;
    qlonglong sourceCount = 0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        double distance = defaultDistance;
        if (distanceFieldIndex >= 0) {
            bool numericOk = false;
            distance = feature.attribute(distanceFieldIndex).toDouble(&numericOk);
            if (!numericOk) {
                continue;
            }
        }
        if (distance <= 0.0) {
            continue;
        }
        QgsGeometry buffered;
        std::string geodesicMessage;
        if (geodesic) {
            buffered = GeodesicLocalBuffer(feature.geometry(), layer->crs(), distance,
                segments, capStyle, joinStyle, 2.0, geodesicMessage);
        } else if (sideValue >= 0 && layer->geometryType() == Qgis::GeometryType::Line) {
            buffered = feature.geometry().singleSidedBuffer(distance, segments,
                sideValue == 0 ? Qgis::BufferSide::Left : Qgis::BufferSide::Right, joinStyle, 2.0);
        } else {
            buffered = feature.geometry().buffer(distance, segments, capStyle, joinStyle, 2.0);
        }
        if (buffered.isNull() || buffered.isEmpty()) {
            continue;
        }
        sourceCount++;
        if (dissolve) {
            dissolveGeometries.append(buffered);
            continue;
        }
        if (!QgsWkbTypes::isMultiType(buffered.wkbType())) buffered.convertToMultiType();
        QgsFeature outputFeature(fields);
        outputFeature.setAttributes(feature.attributes());
        outputFeature.setGeometry(buffered);
        if (writer->addFeature(outputFeature)) writtenCount++;
    }
    if (dissolve && !dissolveGeometries.isEmpty()) {
        QgsGeometry dissolved = QgsGeometry::unaryUnion(dissolveGeometries);
        if (!QgsWkbTypes::isMultiType(dissolved.wkbType())) dissolved.convertToMultiType();
        QgsFeature outputFeature(fields);
        outputFeature.setAttribute(sourceCountIndex, sourceCount);
        outputFeature.setGeometry(dissolved);
        if (writer->addFeature(outputFeature)) writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK,
        geodesic ? "Geodesic advanced buffer completed" : "Advanced buffer completed",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *SpatialJoinLayer(LayerHandle inputHandle, LayerHandle joinHandle,
                                    const char *optionsText, const char *outputPath,
                                    const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *joinState = FindLayer(joinHandle);
    if (!inputState || !inputState->layer || !joinState || !joinState->layer ||
        !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid spatial join parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *inputLayer = inputState->layer.get();
    QgsVectorLayer *joinLayer = joinState->layer.get();
    QStringList options = QString::fromUtf8(optionsText ? optionsText : "0;0;NONE").split(';');
    int joinMode = options.value(0, QStringLiteral("0")).toInt();
    int predicateMode = options.value(1, QStringLiteral("0")).toInt();
    QString sumFieldName = options.value(2, QStringLiteral("NONE")).trimmed();
    int sumFieldIndex = sumFieldName.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) == 0 ?
        -1 : joinLayer->fields().indexOf(sumFieldName);
    if (sumFieldIndex < 0 && sumFieldName.compare(QStringLiteral("NONE"), Qt::CaseInsensitive) != 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Spatial join sum field was not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<OverlayFeatureRecord> joins;
    std::string loadMessage;
    if (!LoadOverlayFeatureRecords(joinLayer, inputLayer->crs(), joins, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsFields inputFields = inputLayer->fields();
    QgsFields joinFields = joinLayer->fields();
    QgsFields fields = BuildOverlayOutputFields(inputFields, joinFields);
    int countIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("join_cnt"), QVariant::LongLong), QString());
    int sumIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("join_sum"), QVariant::Double), QString());
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("spatial_join"), fields, inputLayer->wkbType(), inputLayer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create spatial join output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = inputLayer->getFeatures();
    QgsFeature inputFeature;
    while (iterator.nextFeature(inputFeature)) {
        std::vector<size_t> matches;
        double sum = 0.0;
        for (size_t i = 0; i < joins.size(); i++) {
            if (SpatialPredicateMatches(inputFeature.geometry(), joins[i].geometry, predicateMode)) {
                matches.push_back(i);
                if (sumFieldIndex >= 0 && sumFieldIndex < joins[i].attributes.count()) {
                    bool numericOk = false;
                    double value = joins[i].attributes.at(sumFieldIndex).toDouble(&numericOk);
                    if (numericOk) sum += value;
                }
            }
        }
        int rowCount = joinMode == 1 ? std::max(1, static_cast<int>(matches.size())) : 1;
        for (int row = 0; row < rowCount; row++) {
            const OverlayFeatureRecord *joinRecord = nullptr;
            if (!matches.empty()) {
                size_t matchIndex = joinMode == 1 ? matches[static_cast<size_t>(row)] : matches.front();
                joinRecord = &joins[matchIndex];
            }
            QgsFeature outputFeature(fields);
            outputFeature.setAttribute(0, static_cast<qlonglong>(inputFeature.id()));
            outputFeature.setAttribute(1,
                static_cast<qlonglong>(joinRecord ? joinRecord->id : -1));
            int outputIndex = 2;
            for (int i = 0; i < inputFields.count(); i++) {
                outputFeature.setAttribute(outputIndex, inputFeature.attribute(i));
                outputIndex++;
            }
            for (int i = 0; i < joinFields.count(); i++) {
                if (joinRecord && i < joinRecord->attributes.count()) {
                    outputFeature.setAttribute(outputIndex, joinRecord->attributes.at(i));
                }
                outputIndex++;
            }
            outputFeature.setAttribute(countIndex, static_cast<qlonglong>(matches.size()));
            outputFeature.setAttribute(sumIndex, sum);
            outputFeature.setGeometry(inputFeature.geometry());
            if (!writer->addFeature(outputFeature)) {
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                    "Failed while writing spatial join output", outputPath,
                    outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
            }
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK,
        joinMode == 1 ? "Spatial Join one-to-many completed" :
        "Spatial Join one-to-one with aggregation completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *AdvancedClipLayer(LayerHandle inputHandle, LayerHandle clipHandle,
                                     double tolerance, const char *outputPath,
                                     const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *inputState = FindLayer(inputHandle);
    QgisLayerState *clipState = FindLayer(clipHandle);
    if (!inputState || !inputState->layer || !clipState || !clipState->layer ||
        tolerance < 0.0 || !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid advanced Clip parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *inputLayer = inputState->layer.get();
    QgsGeometry clipGeometry;
    int32_t clipCount = 0;
    std::string loadMessage;
    if (!BuildLayerUnionInCrs(clipState->layer.get(), inputLayer->crs(), clipGeometry,
        clipCount, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    clipGeometry = clipGeometry.makeValid();
    if (tolerance > 0.0) {
        clipGeometry = clipGeometry.snappedToGrid(tolerance, tolerance);
    }
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("advanced_clip"), inputLayer->fields(), inputLayer->wkbType(), inputLayer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create advanced Clip output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = inputLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry().makeValid();
        if (tolerance > 0.0) {
            geometry = geometry.snappedToGrid(tolerance, tolerance);
        }
        if (!geometry.intersects(clipGeometry)) continue;
        QgsGeometry clipped = geometry.intersection(clipGeometry);
        if (clipped.isNull() || clipped.isEmpty()) continue;
        QgsFeature outputFeature(inputLayer->fields());
        outputFeature.setAttributes(feature.attributes());
        outputFeature.setGeometry(clipped);
        if (!writer->addFeature(outputFeature)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing Clip batch",
                outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
        }
        writtenCount++;
    }
    return MakeProcessResult(true, GIS_OK,
        "Advanced Clip completed with CRS transform, validity repair, tolerance grid and batch iteration",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static const char *SplitLineAtPointLayer(LayerHandle lineHandle, LayerHandle pointHandle,
                                         double tolerance, const char *outputPath,
                                         const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *lineState = FindLayer(lineHandle);
    QgisLayerState *pointState = FindLayer(pointHandle);
    if (!lineState || !lineState->layer || !pointState || !pointState->layer ||
        lineState->layer->geometryType() != Qgis::GeometryType::Line ||
        pointState->layer->geometryType() != Qgis::GeometryType::Point || tolerance < 0.0 ||
        !outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Split Line At Point requires line and point layers", outputPath ? outputPath : "",
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *lineLayer = lineState->layer.get();
    std::vector<OverlayFeatureRecord> pointRecords;
    std::string loadMessage;
    if (!LoadOverlayFeatureRecords(pointState->layer.get(), lineLayer->crs(), pointRecords, loadMessage)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, loadMessage, outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::vector<QgsPointXY> points;
    for (size_t i = 0; i < pointRecords.size(); i++) {
        points.push_back(pointRecords[i].geometry.asPoint());
    }
    QgsFields fields = lineLayer->fields();
    int sourceIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("orig_fid"), QVariant::LongLong), QString());
    int partIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("part_id"), QVariant::Int), QString());
    std::unique_ptr<QgsVectorFileWriter> writer = CreateOverlayWriter(outputPath, outputLayerName,
        QStringLiteral("split_lines"), fields, lineLayer->wkbType(), lineLayer->crs());
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create split-line output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    double splitLength = std::max(lineLayer->extent().width(), lineLayer->extent().height()) * 2.0;
    if (splitLength <= 0.0) splitLength = 1000.0;
    int32_t writtenCount = 0;
    QgsFeatureIterator iterator = lineLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QVector<QgsGeometry> parts;
        parts.append(feature.geometry());
        for (size_t pointIndexValue = 0; pointIndexValue < points.size(); pointIndexValue++) {
            for (int currentPart = 0; currentPart < parts.count(); currentPart++) {
                QgsGeometry part = parts.at(currentPart);
                QgsPointXY snappedPoint;
                int nextVertex = -1;
                double squaredDistance = part.closestSegmentWithContext(points[pointIndexValue],
                    snappedPoint, nextVertex);
                if (squaredDistance < 0.0 || (tolerance > 0.0 &&
                    std::sqrt(squaredDistance) > tolerance) || nextVertex <= 0) {
                    continue;
                }
                QgsPoint previous = part.vertexAt(nextVertex - 1);
                QgsPoint next = part.vertexAt(nextVertex);
                double dx = next.x() - previous.x();
                double dy = next.y() - previous.y();
                double segmentLength = std::sqrt(dx * dx + dy * dy);
                if (segmentLength <= 0.0) continue;
                double nx = -dy / segmentLength;
                double ny = dx / segmentLength;
                QVector<QgsPointXY> splitLine;
                splitLine.append(QgsPointXY(snappedPoint.x() - nx * splitLength,
                    snappedPoint.y() - ny * splitLength));
                splitLine.append(QgsPointXY(snappedPoint.x() + nx * splitLength,
                    snappedPoint.y() + ny * splitLength));
                QVector<QgsGeometry> newParts;
                QVector<QgsPointXY> topologyPoints;
                Qgis::GeometryOperationResult result = part.splitGeometry(splitLine, newParts,
                    false, topologyPoints, true);
                if (result == Qgis::GeometryOperationResult::Success && !newParts.isEmpty()) {
                    parts[currentPart] = part;
                    for (int newIndex = 0; newIndex < newParts.count(); newIndex++) {
                        parts.append(newParts.at(newIndex));
                    }
                    break;
                }
            }
        }
        for (int i = 0; i < parts.count(); i++) {
            QgsFeature outputFeature(fields);
            outputFeature.setAttributes(feature.attributes());
            outputFeature.setAttribute(sourceIndex, static_cast<qlonglong>(feature.id()));
            outputFeature.setAttribute(partIndex, i + 1);
            outputFeature.setGeometry(parts.at(i));
            if (!writer->addFeature(outputFeature)) {
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED,
                    "Failed while writing split-line part", outputPath,
                    outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
            }
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Split Line At Point completed", outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static QString QualityPointKey(const QgsPointXY &point)
{
    return QString::number(point.x(), 'f', 8) + QStringLiteral("|") + QString::number(point.y(), 'f', 8);
}

static QgsPointXY QualityFallbackPoint(QgsVectorLayer *layer)
{
    if (layer) {
        QgsRectangle extent = layer->extent();
        if (!extent.isNull() && !extent.isEmpty()) {
            return extent.center();
        }
    }
    return QgsPointXY(0.0, 0.0);
}

static QgsPointXY QualityRepresentativePoint(const QgsGeometry &geometry, QgsVectorLayer *layer)
{
    if (!geometry.isNull() && !geometry.isEmpty()) {
        QgsGeometry pointGeometry = geometry.pointOnSurface();
        if (!pointGeometry.isNull() && !pointGeometry.isEmpty()) {
            return pointGeometry.asPoint();
        }
        pointGeometry = geometry.centroid();
        if (!pointGeometry.isNull() && !pointGeometry.isEmpty()) {
            return pointGeometry.asPoint();
        }
        QgsRectangle bounds = geometry.boundingBox();
        if (!bounds.isNull() && !bounds.isEmpty()) {
            return bounds.center();
        }
    }
    return QualityFallbackPoint(layer);
}

static QStringList ParseQualityRequiredFields(const char *textValue)
{
    QStringList fields;
    QString text = QString::fromUtf8(textValue ? textValue : "").trimmed();
    if (text.isEmpty()) {
        return fields;
    }
    text.replace(QLatin1Char(','), QLatin1Char(';'));
    QStringList parts = text.split(QLatin1Char(';'), Qt::SkipEmptyParts);
    for (int i = 0; i < parts.size(); i++) {
        QString fieldName = parts.at(i).trimmed();
        if (fieldName.isEmpty()) {
            continue;
        }
        if (!fields.contains(fieldName, Qt::CaseInsensitive)) {
            fields.append(fieldName);
        }
    }
    return fields;
}

static bool AddQualityIssue(QgsVectorFileWriter *writer, const QgsFields &fields, QgsFeatureId sourceFid,
                            const QString &checkName, int severity, const QString &message,
                            const QString &fieldName, QgsFeatureId otherFid, const QgsPointXY &location,
                            int32_t &writtenCount, int32_t maxIssues)
{
    if (!writer || writtenCount >= maxIssues) {
        return false;
    }
    QgsFeature outFeature(fields);
    outFeature.setGeometry(QgsGeometry::fromPointXY(location));
    outFeature.setAttribute(0, QVariant::fromValue(static_cast<qlonglong>(sourceFid)));
    outFeature.setAttribute(1, checkName);
    outFeature.setAttribute(2, severity);
    outFeature.setAttribute(3, message.left(240));
    outFeature.setAttribute(4, fieldName.left(80));
    outFeature.setAttribute(5, QVariant::fromValue(static_cast<qlonglong>(otherFid)));
    if (writer->addFeature(outFeature)) {
        writtenCount++;
        return true;
    }
    return false;
}

static void CollectLineEndpoints(const QgsGeometry &geometry, QgsFeatureId fid,
                                 std::vector<QualityEndpointRecord> &endpoints)
{
    if (geometry.isMultipart()) {
        QgsMultiPolylineXY lines = geometry.asMultiPolyline();
        for (int i = 0; i < lines.size(); i++) {
            QgsPolylineXY line = lines.at(i);
            if (line.size() < 2) {
                continue;
            }
            QualityEndpointRecord first;
            first.id = fid;
            first.point = line.first();
            endpoints.push_back(first);
            QualityEndpointRecord last;
            last.id = fid;
            last.point = line.last();
            endpoints.push_back(last);
        }
        return;
    }
    QgsPolylineXY line = geometry.asPolyline();
    if (line.size() < 2) {
        return;
    }
    QualityEndpointRecord first;
    first.id = fid;
    first.point = line.first();
    endpoints.push_back(first);
    QualityEndpointRecord last;
    last.id = fid;
    last.point = line.last();
    endpoints.push_back(last);
}

static bool TopologyRuleEnabled(const QStringList &rules, const QString &rule)
{
    return rules.contains(rule, Qt::CaseInsensitive);
}

static bool ParseDirtyExtent(const char *text, QgsRectangle &extent)
{
    QString value = QString::fromUtf8(text ? text : "").trimmed();
    if (value.isEmpty()) return false;
    QStringList parts = value.split(QLatin1Char(','), Qt::SkipEmptyParts);
    if (parts.size() != 4) return false;
    bool ok0 = false, ok1 = false, ok2 = false, ok3 = false;
    double minX = parts.at(0).toDouble(&ok0);
    double minY = parts.at(1).toDouble(&ok1);
    double maxX = parts.at(2).toDouble(&ok2);
    double maxY = parts.at(3).toDouble(&ok3);
    if (!ok0 || !ok1 || !ok2 || !ok3 || maxX < minX || maxY < minY) return false;
    extent = QgsRectangle(minX, minY, maxX, maxY);
    return true;
}

static QgsGeometry CollectLayerUnion(QgsVectorLayer *layer, const QgsRectangle *filterRect,
                                     const QgsCoordinateReferenceSystem &destinationCrs)
{
    if (!layer) return QgsGeometry();
    QgsFeatureRequest request;
    if (filterRect) request.setFilterRect(*filterRect);
    QVector<QgsGeometry> geometries;
    QgsFeatureIterator iterator = layer->getFeatures(request);
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) continue;
        std::string transformMessage;
        if (!TransformGeometryToCrs(geometry, layer->crs(), destinationCrs, transformMessage)) continue;
        geometries.push_back(geometry);
    }
    if (geometries.isEmpty()) return QgsGeometry();
    return QgsGeometry::unaryUnion(geometries);
}

static bool AddTopologyIssue(QgsVectorFileWriter *writer, const QgsFields &fields,
                             const QString &ruleId, const QString &sourceLayer,
                             const QString &targetLayer, QgsFeatureId sourceFid,
                             QgsFeatureId otherFid, int severity, const QString &message,
                             const QString &strategies, const QgsPointXY &point,
                             int32_t &writtenCount)
{
    if (!writer) return false;
    QgsFeature issue(fields);
    issue.setGeometry(QgsGeometry::fromPointXY(point));
    issue.setAttribute(QStringLiteral("issue_id"), QUuid::createUuid().toString(QUuid::WithoutBraces));
    issue.setAttribute(QStringLiteral("rule_id"), ruleId);
    issue.setAttribute(QStringLiteral("source_layer"), sourceLayer);
    issue.setAttribute(QStringLiteral("target_layer"), targetLayer);
    issue.setAttribute(QStringLiteral("src_fid"), static_cast<qlonglong>(sourceFid));
    issue.setAttribute(QStringLiteral("other_fid"), static_cast<qlonglong>(otherFid));
    issue.setAttribute(QStringLiteral("severity"), severity);
    issue.setAttribute(QStringLiteral("message"), message);
    issue.setAttribute(QStringLiteral("status"), QStringLiteral("open"));
    issue.setAttribute(QStringLiteral("exception"), 0);
    issue.setAttribute(QStringLiteral("ignore_reason"), QString());
    issue.setAttribute(QStringLiteral("reviewer"), QString());
    issue.setAttribute(QStringLiteral("review_time"), QString());
    issue.setAttribute(QStringLiteral("repair"), strategies);
    bool added = writer->addFeature(issue);
    if (added) writtenCount++;
    return added;
}

const char *ValidateTopologyRules(LayerHandle sourceHandle, LayerHandle targetHandle,
                                  const char *rulesText, const char *dirtyExtentText,
                                  double tolerance, const char *outputPath,
                                  const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *sourceState = FindLayer(sourceHandle);
    QgisLayerState *targetState = FindLayer(targetHandle > 0 ? targetHandle : sourceHandle);
    if (!sourceState || !sourceState->layer || !targetState || !targetState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Topology source or target layer not found",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Topology output path is empty", "", "", 0,
            outErrCode);
    }
    QStringList rules = QString::fromUtf8(rulesText ? rulesText : "").split(QLatin1Char(';'), Qt::SkipEmptyParts);
    for (int i = 0; i < rules.size(); i++) rules[i] = rules.at(i).trimmed();
    if (rules.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Topology rule set is empty", outputPath,
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *source = sourceState->layer.get();
    QgsVectorLayer *target = targetState->layer.get();
    QgsRectangle dirtyRect;
    bool incremental = ParseDirtyExtent(dirtyExtentText, dirtyRect);
    if (incremental && tolerance > 0.0) dirtyRect.grow(tolerance);

    QgsFields fields;
    fields.append(QgsField(QStringLiteral("issue_id"), QVariant::String));
    fields.append(QgsField(QStringLiteral("rule_id"), QVariant::String));
    fields.append(QgsField(QStringLiteral("source_layer"), QVariant::String));
    fields.append(QgsField(QStringLiteral("target_layer"), QVariant::String));
    fields.append(QgsField(QStringLiteral("src_fid"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("other_fid"), QVariant::LongLong));
    fields.append(QgsField(QStringLiteral("severity"), QVariant::Int));
    fields.append(QgsField(QStringLiteral("message"), QVariant::String));
    fields.append(QgsField(QStringLiteral("status"), QVariant::String));
    fields.append(QgsField(QStringLiteral("exception"), QVariant::Int));
    fields.append(QgsField(QStringLiteral("ignore_reason"), QVariant::String));
    fields.append(QgsField(QStringLiteral("reviewer"), QVariant::String));
    fields.append(QgsField(QStringLiteral("review_time"), QVariant::String));
    fields.append(QgsField(QStringLiteral("repair"), QVariant::String));

    QString outPath = QString::fromUtf8(outputPath);
    QString name = QString::fromUtf8(outputLayerName && std::strlen(outputLayerName) > 0 ?
        outputLayerName : "topology_errors");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("GPKG");
    options.layerName = name;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        Qgis::WkbType::Point, source->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create topology error dataset",
            outputPath, ToStdString(name), 0, outErrCode);
    }

    const QgsRectangle *filter = incremental ? &dirtyRect : nullptr;
    QgsGeometry targetUnion = CollectLayerUnion(target, filter, source->crs());
    QVector<QualityGeometryRecord> records;
    QgsSpatialIndex spatialIndex;
    std::map<long long, int> recordIndex;
    std::vector<QualityEndpointRecord> endpoints;
    QgsFeatureRequest sourceRequest;
    if (filter) sourceRequest.setFilterRect(*filter);
    QgsFeatureIterator sourceIterator = source->getFeatures(sourceRequest);
    QgsFeature feature;
    int32_t writtenCount = 0;
    while (sourceIterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) continue;
        QgsFeatureId fid = feature.id();
        QgsPointXY point = QualityRepresentativePoint(geometry, source);
        if (TopologyRuleEnabled(rules, QStringLiteral("line_no_self_intersection")) &&
            source->geometryType() == Qgis::GeometryType::Line && !geometry.isGeosValid()) {
            AddTopologyIssue(writer.get(), fields, QStringLiteral("line_no_self_intersection"), source->name(),
                target->name(), fid, -1, 2, QStringLiteral("Line self-intersects"),
                QStringLiteral("split;make_valid"), point, writtenCount);
        }
        if ((TopologyRuleEnabled(rules, QStringLiteral("must_be_covered_by")) ||
             TopologyRuleEnabled(rules, QStringLiteral("point_in_polygon"))) && !targetUnion.isEmpty()) {
            bool covered = geometry.difference(targetUnion).isEmpty();
            if (!covered) {
                QString rule = source->geometryType() == Qgis::GeometryType::Point ?
                    QStringLiteral("point_in_polygon") : QStringLiteral("must_be_covered_by");
                AddTopologyIssue(writer.get(), fields, rule, source->name(), target->name(), fid, -1, 2,
                    QStringLiteral("Feature is not covered by the target layer"),
                    QStringLiteral("snap;clip"), point, writtenCount);
            }
        }
        if (source->geometryType() == Qgis::GeometryType::Point && !targetUnion.isEmpty()) {
            double distance = geometry.distance(targetUnion);
            if (TopologyRuleEnabled(rules, QStringLiteral("point_on_line")) && distance > tolerance) {
                AddTopologyIssue(writer.get(), fields, QStringLiteral("point_on_line"), source->name(),
                    target->name(), fid, -1, 2, QStringLiteral("Point is not on a target line"),
                    QStringLiteral("snap"), point, writtenCount);
            }
        }
        if (source->geometryType() == Qgis::GeometryType::Polygon ||
            source->geometryType() == Qgis::GeometryType::Line) {
            QualityGeometryRecord record;
            record.id = fid;
            record.geometry = geometry;
            record.bounds = geometry.boundingBox();
            recordIndex[static_cast<long long>(fid)] = records.size();
            records.push_back(record);
            spatialIndex.addFeature(fid, record.bounds);
        }
        if (source->geometryType() == Qgis::GeometryType::Line) CollectLineEndpoints(geometry, fid, endpoints);
    }

    bool pairRule = TopologyRuleEnabled(rules, QStringLiteral("polygon_no_overlap")) ||
        TopologyRuleEnabled(rules, QStringLiteral("line_no_intersection"));
    if (pairRule) {
        for (int i = 0; i < records.size(); i++) {
            QList<QgsFeatureId> candidates = spatialIndex.intersects(records.at(i).bounds);
            for (int c = 0; c < candidates.size(); c++) {
                QgsFeatureId otherId = candidates.at(c);
                if (otherId <= records.at(i).id) continue;
                std::map<long long, int>::const_iterator found = recordIndex.find(static_cast<long long>(otherId));
                if (found == recordIndex.end()) continue;
                const QualityGeometryRecord &other = records.at(found->second);
                QgsGeometry intersection = records.at(i).geometry.intersection(other.geometry);
                if (intersection.isNull() || intersection.isEmpty()) continue;
                if (source->geometryType() == Qgis::GeometryType::Polygon && intersection.area() > tolerance * tolerance) {
                    AddTopologyIssue(writer.get(), fields, QStringLiteral("polygon_no_overlap"), source->name(),
                        source->name(), records.at(i).id, other.id, 2, QStringLiteral("Polygons overlap"),
                        QStringLiteral("clip;merge"), QualityRepresentativePoint(intersection, source), writtenCount);
                } else if (source->geometryType() == Qgis::GeometryType::Line &&
                    !records.at(i).geometry.touches(other.geometry)) {
                    AddTopologyIssue(writer.get(), fields, QStringLiteral("line_no_intersection"), source->name(),
                        source->name(), records.at(i).id, other.id, 2, QStringLiteral("Lines intersect away from endpoints"),
                        QStringLiteral("split;trim"), QualityRepresentativePoint(intersection, source), writtenCount);
                }
            }
        }
    }

    if (TopologyRuleEnabled(rules, QStringLiteral("line_no_dangles")) && !endpoints.empty()) {
        for (size_t i = 0; i < endpoints.size(); i++) {
            bool connected = false;
            for (size_t j = 0; j < endpoints.size(); j++) {
                if (i == j) continue;
                if (endpoints[i].point.distance(endpoints[j].point) <= std::max(0.0, tolerance)) {
                    connected = true;
                    break;
                }
            }
            if (!connected) {
                AddTopologyIssue(writer.get(), fields, QStringLiteral("line_no_dangles"), source->name(),
                    target->name(), endpoints[i].id, -1, 1, QStringLiteral("Line has a dangling endpoint"),
                    QStringLiteral("snap;extend;trim"), endpoints[i].point, writtenCount);
            }
        }
    }

    if (TopologyRuleEnabled(rules, QStringLiteral("point_on_endpoint")) &&
        source->geometryType() == Qgis::GeometryType::Point) {
        std::vector<QualityEndpointRecord> targetEndpoints;
        QgsFeatureIterator targetIterator = target->getFeatures();
        QgsFeature targetFeature;
        while (targetIterator.nextFeature(targetFeature))
            CollectLineEndpoints(targetFeature.geometry(), targetFeature.id(), targetEndpoints);
        QgsFeatureIterator pointIterator = source->getFeatures(sourceRequest);
        while (pointIterator.nextFeature(feature)) {
            QgsGeometry geometry = feature.geometry();
            QgsPointXY point = QualityRepresentativePoint(geometry, source);
            bool matched = false;
            for (size_t i = 0; i < targetEndpoints.size(); i++) {
                if (point.distance(targetEndpoints[i].point) <= std::max(0.0, tolerance)) {
                    matched = true;
                    break;
                }
            }
            if (!matched) AddTopologyIssue(writer.get(), fields, QStringLiteral("point_on_endpoint"), source->name(),
                target->name(), feature.id(), -1, 2, QStringLiteral("Point is not on a target endpoint"),
                QStringLiteral("snap"), point, writtenCount);
        }
    }

    if (TopologyRuleEnabled(rules, QStringLiteral("polygon_no_gaps")) &&
        source->geometryType() == Qgis::GeometryType::Polygon && targetHandle > 0 && !targetUnion.isEmpty()) {
        QgsGeometry sourceUnion = CollectLayerUnion(source, filter, source->crs());
        QgsGeometry gaps = targetUnion.difference(sourceUnion);
        if (!gaps.isNull() && !gaps.isEmpty() && gaps.area() > tolerance * tolerance) {
            AddTopologyIssue(writer.get(), fields, QStringLiteral("polygon_no_gaps"), source->name(), target->name(),
                -1, -1, 2, QStringLiteral("Polygon coverage contains gaps"), QStringLiteral("extend;merge"),
                QualityRepresentativePoint(gaps, source), writtenCount);
        }
    }

    std::string message = incremental ? "Incremental topology validation completed" :
        "Full topology validation completed";
    return MakeProcessResult(true, GIS_OK, message, outputPath, ToStdString(name), writtenCount, outErrCode);
}

const char *QualityCheckLayer(LayerHandle handle, const char *requiredFieldsText,
                              const char *outputPath, const char *outputLayerName,
                              int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid quality check parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsFields qualityFields;
    qualityFields.append(QgsField(QStringLiteral("src_fid"), QVariant::LongLong));
    qualityFields.append(QgsField(QStringLiteral("check"), QVariant::String));
    qualityFields.append(QgsField(QStringLiteral("severity"), QVariant::Int));
    qualityFields.append(QgsField(QStringLiteral("message"), QVariant::String));
    qualityFields.append(QgsField(QStringLiteral("field"), QVariant::String));
    qualityFields.append(QgsField(QStringLiteral("other_fid"), QVariant::LongLong));

    QString outPath = QString::fromUtf8(outputPath);
    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("quality_errors");
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = layerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, qualityFields,
        Qgis::WkbType::Point, sourceLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create quality check output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    const int32_t maxIssues = 10000;
    int32_t writtenCount = 0;
    QStringList requiredFields = ParseQualityRequiredFields(requiredFieldsText);
    std::vector<int> requiredFieldIndexes;
    for (int i = 0; i < requiredFields.size(); i++) {
        int fieldIndex = sourceLayer->fields().indexOf(requiredFields.at(i));
        if (fieldIndex < 0) {
            AddQualityIssue(writer.get(), qualityFields, -1, QStringLiteral("field_missing"), 2,
                QStringLiteral("Required field is not present: ") + requiredFields.at(i), requiredFields.at(i),
                -1, QualityFallbackPoint(sourceLayer), writtenCount, maxIssues);
        } else {
            requiredFieldIndexes.push_back(fieldIndex);
        }
    }

    std::map<std::string, QgsFeatureId> seenPointKeys;
    std::vector<QualityGeometryRecord> polygonRecords;
    std::map<long long, size_t> polygonIndexByFid;
    QgsSpatialIndex polygonIndex;
    std::vector<QualityEndpointRecord> endpoints;

    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry geometry = feature.geometry();
        QgsFeatureId fid = feature.id();
        QgsPointXY representative = QualityRepresentativePoint(geometry, sourceLayer);

        for (size_t i = 0; i < requiredFieldIndexes.size(); i++) {
            int fieldIndex = requiredFieldIndexes[i];
            QVariant value = feature.attribute(fieldIndex);
            if (!value.isValid() || value.isNull() || value.toString().trimmed().isEmpty()) {
                AddQualityIssue(writer.get(), qualityFields, fid, QStringLiteral("field_null"), 1,
                    QStringLiteral("Required field value is empty"), sourceLayer->fields().at(fieldIndex).name(),
                    -1, representative, writtenCount, maxIssues);
            }
        }

        if (geometry.isNull() || geometry.isEmpty()) {
            AddQualityIssue(writer.get(), qualityFields, fid, QStringLiteral("empty_geometry"), 2,
                QStringLiteral("Feature geometry is empty"), QString(), -1, representative,
                writtenCount, maxIssues);
            continue;
        }

        QVector<QgsGeometry::Error> validationErrors;
        geometry.validateGeometry(validationErrors, Qgis::GeometryValidationEngine::QgisInternal);
        for (int i = 0; i < validationErrors.size(); i++) {
            QgsGeometry::Error error = validationErrors.at(i);
            QgsPointXY location = error.hasWhere() ? error.where() : representative;
            AddQualityIssue(writer.get(), qualityFields, fid, QStringLiteral("invalid_geometry"), 2,
                error.what(), QString(), -1, location, writtenCount, maxIssues);
        }
        if (validationErrors.isEmpty() && !geometry.isGeosValid()) {
            AddQualityIssue(writer.get(), qualityFields, fid, QStringLiteral("invalid_geometry"), 2,
                QStringLiteral("Geometry is not GEOS valid"), QString(), -1, representative,
                writtenCount, maxIssues);
        }

        if (sourceLayer->geometryType() == Qgis::GeometryType::Point) {
            QString pointKey = QualityPointKey(representative);
            std::string key = ToStdString(pointKey);
            std::map<std::string, QgsFeatureId>::const_iterator found = seenPointKeys.find(key);
            if (found == seenPointKeys.end()) {
                seenPointKeys[key] = fid;
            } else {
                AddQualityIssue(writer.get(), qualityFields, fid, QStringLiteral("duplicate_point"), 1,
                    QStringLiteral("Point geometry duplicates another feature"), QString(), found->second,
                    representative, writtenCount, maxIssues);
            }
        } else if (sourceLayer->geometryType() == Qgis::GeometryType::Polygon) {
            QualityGeometryRecord record;
            record.id = fid;
            record.geometry = geometry;
            record.bounds = geometry.boundingBox();
            polygonIndexByFid[static_cast<long long>(fid)] = polygonRecords.size();
            polygonRecords.push_back(record);
            polygonIndex.addFeature(fid, record.bounds);
        } else if (sourceLayer->geometryType() == Qgis::GeometryType::Line) {
            CollectLineEndpoints(geometry, fid, endpoints);
        }
    }

    for (size_t i = 0; i < polygonRecords.size(); i++) {
        QList<QgsFeatureId> candidates = polygonIndex.intersects(polygonRecords[i].bounds);
        for (int ci = 0; ci < candidates.size(); ci++) {
            QgsFeatureId otherFid = candidates.at(ci);
            if (otherFid <= polygonRecords[i].id) {
                continue;
            }
            std::map<long long, size_t>::const_iterator otherIndex =
                polygonIndexByFid.find(static_cast<long long>(otherFid));
            if (otherIndex == polygonIndexByFid.end()) {
                continue;
            }
            const QualityGeometryRecord &other = polygonRecords[otherIndex->second];
            if (!polygonRecords[i].geometry.intersects(other.geometry)) {
                continue;
            }
            QgsGeometry intersection = polygonRecords[i].geometry.intersection(other.geometry);
            if (intersection.isNull() || intersection.isEmpty() || intersection.area() <= 0.0) {
                continue;
            }
            AddQualityIssue(writer.get(), qualityFields, polygonRecords[i].id, QStringLiteral("polygon_overlap"), 2,
                QStringLiteral("Polygon overlaps another feature"), QString(), other.id,
                QualityRepresentativePoint(intersection, sourceLayer), writtenCount, maxIssues);
        }
    }

    std::map<std::string, int> endpointCounts;
    for (size_t i = 0; i < endpoints.size(); i++) {
        std::string key = ToStdString(QualityPointKey(endpoints[i].point));
        std::map<std::string, int>::iterator countIt = endpointCounts.find(key);
        if (countIt == endpointCounts.end()) {
            endpointCounts[key] = 1;
        } else {
            countIt->second++;
        }
    }
    for (size_t i = 0; i < endpoints.size(); i++) {
        std::string key = ToStdString(QualityPointKey(endpoints[i].point));
        std::map<std::string, int>::const_iterator countIt = endpointCounts.find(key);
        if (countIt != endpointCounts.end() && countIt->second == 1) {
            AddQualityIssue(writer.get(), qualityFields, endpoints[i].id, QStringLiteral("dangling_endpoint"), 1,
                QStringLiteral("Line endpoint is not connected to another line"), QString(), -1,
                endpoints[i].point, writtenCount, maxIssues);
        }
    }

    std::string message = "Quality check completed";
    if (writtenCount >= maxIssues) {
        message += "; output was limited to 10000 issues";
    }
    return MakeProcessResult(true, GIS_OK, message, outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *MergeLayers(LayerHandle firstHandle, LayerHandle secondHandle,
                        const char *outputPath, const char *outputLayerName,
                        int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
            if (ProcessingLoopCheckpoint("compute")) {
                break;
            }
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry inputGeometry = inputFeature.geometry();
        if (inputGeometry.isNull() || inputGeometry.isEmpty()) {
            continue;
        }
        QgsFeatureRequest overlayRequest;
        QgsFeatureIterator overlayIterator = overlayLayer->getFeatures(overlayRequest);
        QgsFeature overlayFeature;
        while (overlayIterator.nextFeature(overlayFeature)) {
            if (ProcessingLoopCheckpoint("compute")) {
                break;
            }
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
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
    ProcessingStateLock lock;
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
    std::vector<OverlayFeatureRecord> sources;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
        OverlayFeatureRecord record;
        record.id = feature.id();
        record.geometry = pointGeometry;
        record.attributes = feature.attributes();
        sources.push_back(record);
    }
    if (points.size() < 2) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Voronoi requires at least two features",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsRectangle extent = sourceLayer->extent();
    QgsGeometry diagram = QgsGeometry::fromMultiPointXY(points).voronoiDiagram(
        QgsGeometry::fromRect(extent), tolerance, false);
    if (diagram.isNull() || diagram.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "QGIS Voronoi generation failed",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsFields fields = sourceLayer->fields();
    int sourceFidIndex = AppendUniqueField(fields,
        QgsField(QStringLiteral("source_fid"), QVariant::LongLong), QString());
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
        int bestSourceIndex = -1;
        for (size_t i = 0; i < sources.size(); i++) {
            double distance = center.distance(sources[i].geometry);
            if (distance >= 0.0 && (bestDistance < 0.0 || distance < bestDistance)) {
                bestDistance = distance;
                bestSourceId = sources[i].id;
                bestSourceIndex = static_cast<int>(i);
            }
        }
        QgsFeature outFeature(fields);
        if (bestSourceIndex >= 0) {
            outFeature.setAttributes(sources[static_cast<size_t>(bestSourceIndex)].attributes);
        }
        outFeature.setAttribute(sourceFidIndex, static_cast<qlonglong>(bestSourceId));
        outFeature.setGeometry(cell);
        if (writer->addFeature(outFeature)) {
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "Voronoi polygons completed through QgsGeometry",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *TinLayer(LayerHandle handle, double tolerance, const char *outputPath,
                     const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0 || tolerance < 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid TIN parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "TIN input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsMultiPointXY points;
    std::vector<QgsPointXY> sourcePoints;
    std::vector<double> sourceElevations;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        QgsGeometry pointGeometry = geometry.type() == Qgis::GeometryType::Point ? geometry : geometry.centroid();
        QgsCoordinateSequence sequence = pointGeometry.constGet()->coordinateSequence();
        for (int pi = 0; pi < sequence.size(); pi++) {
            QgsRingSequence rings = sequence.at(pi);
            for (int ri = 0; ri < rings.size(); ri++) {
                QgsPointSequence ring = rings.at(ri);
                for (int vi = 0; vi < ring.size(); vi++) {
                    QgsPoint point = ring.at(vi);
                    QgsPointXY pointXY(point.x(), point.y());
                    points.push_back(pointXY);
                    sourcePoints.push_back(pointXY);
                    sourceElevations.push_back(point.is3D() ? point.z() : 0.0);
                }
            }
        }
    }
    if (points.size() < 3) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "TIN requires at least three elevation points",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsGeometry triangles = QgsGeometry::fromMultiPointXY(points).delaunayTriangulation(tolerance, false);
    if (triangles.isNull() || triangles.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "QGIS Delaunay triangulation failed",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("triangle_id"), QVariant::Int));
    fields.append(QgsField(QStringLiteral("min_z"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("max_z"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("mean_z"), QVariant::Double));
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = outputLayerName && std::strlen(outputLayerName) > 0
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("tin");
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(QString::fromUtf8(outputPath), fields,
        Qgis::WkbType::Polygon, sourceLayer->crs(), QgsCoordinateTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create TIN output",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QVector<QgsGeometry> triangleParts = triangles.asGeometryCollection();
    if (triangleParts.isEmpty()) {
        triangleParts.push_back(triangles);
    }
    int writtenCount = 0;
    for (int i = 0; i < triangleParts.size(); i++) {
        QgsGeometry triangle = triangleParts.at(i);
        QgsCoordinateSequence triangleSequence = triangle.constGet()->coordinateSequence();
        double minimumZ = std::numeric_limits<double>::max();
        double maximumZ = -std::numeric_limits<double>::max();
        double sumZ = 0.0;
        int elevationCount = 0;
        for (int pi = 0; pi < triangleSequence.size(); pi++) {
            QgsRingSequence rings = triangleSequence.at(pi);
            for (int ri = 0; ri < rings.size(); ri++) {
                QgsPointSequence ring = rings.at(ri);
                int vertexLimit = ring.size() > 1 ? ring.size() - 1 : ring.size();
                for (int vi = 0; vi < vertexLimit; vi++) {
                    QgsPointXY vertex(ring.at(vi).x(), ring.at(vi).y());
                    double bestDistance = std::numeric_limits<double>::max();
                    double elevation = 0.0;
                    for (size_t sourceIndex = 0; sourceIndex < sourcePoints.size(); sourceIndex++) {
                        double distance = vertex.sqrDist(sourcePoints[sourceIndex]);
                        if (distance < bestDistance) {
                            bestDistance = distance;
                            elevation = sourceElevations[sourceIndex];
                        }
                    }
                    minimumZ = std::min(minimumZ, elevation);
                    maximumZ = std::max(maximumZ, elevation);
                    sumZ += elevation;
                    elevationCount++;
                }
            }
        }
        if (elevationCount <= 0) {
            continue;
        }
        QgsFeature outputFeature(fields);
        outputFeature.setAttribute(0, i + 1);
        outputFeature.setAttribute(1, minimumZ);
        outputFeature.setAttribute(2, maximumZ);
        outputFeature.setAttribute(3, sumZ / static_cast<double>(elevationCount));
        outputFeature.setGeometry(triangle);
        if (writer->addFeature(outputFeature)) {
            writtenCount++;
        }
    }
    return MakeProcessResult(true, GIS_OK, "TIN Delaunay triangulation completed",
        outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

const char *OrientedMinimumBoundingBoxLayer(LayerHandle handle, const char *outputPath,
                                            const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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

const char *KernelDensityLayer(LayerHandle handle, double searchRadius, const char *textValue,
                               const char *outputPath, const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0 || searchRadius < 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid kernel density parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *sourceLayer = state->layer.get();
    if (sourceLayer->geometryType() != Qgis::GeometryType::Point) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Kernel Density currently requires point features",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    KernelDensityOptions options = ParseKernelDensityOptions(textValue);
    bool usePopulationField = options.populationField.trimmed().length() > 0 &&
        options.populationField.trimmed().toUpper() != QStringLiteral("NONE");
    int populationFieldIndex = -1;
    if (usePopulationField) {
        populationFieldIndex = sourceLayer->fields().indexOf(options.populationField.trimmed());
        if (populationFieldIndex < 0) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
                "Population field was not found",
                outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
        }
    }

    std::vector<KernelDensityPoint> points;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry geometry = feature.geometry();
        double weight = KernelDensityWeight(feature, populationFieldIndex, usePopulationField);
        CollectKernelDensityPoints(geometry, weight, points);
    }
    if (points.empty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Kernel Density requires at least one weighted point",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsRectangle sourceExtent = sourceLayer->extent();
    double radius = searchRadius > 0.0 ? searchRadius : KernelDensityDefaultSearchRadius(points, sourceExtent);
    if (radius <= 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Kernel Density search radius is invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsRectangle outputExtent = sourceExtent;
    outputExtent.grow(radius);
    double cellSize = options.cellSize > 0.0 ? options.cellSize : KernelDensityDefaultCellSize(outputExtent, radius);
    if (cellSize <= 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Kernel Density cell size is invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int cols = static_cast<int>(std::ceil(outputExtent.width() / cellSize));
    int rows = static_cast<int>(std::ceil(outputExtent.height() / cellSize));
    if (cols <= 0 || rows <= 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Kernel Density output extent is invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    long long cellCount = static_cast<long long>(cols) * static_cast<long long>(rows);
    if (cellCount > 4000000LL) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Kernel Density output has too many cells; increase the cell size",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    outputExtent.setXMaximum(outputExtent.xMinimum() + static_cast<double>(cols) * cellSize);
    outputExtent.setYMaximum(outputExtent.yMinimum() + static_cast<double>(rows) * cellSize);

    std::vector<double> values(static_cast<size_t>(cellCount), 0.0);
    const double pi = 3.14159265358979323846;
    double radiusSquared = radius * radius;
    double kernelNorm = 3.0 / (pi * radiusSquared);
    double xMin = outputExtent.xMinimum();
    double yMax = outputExtent.yMaximum();
    for (size_t pointIndex = 0; pointIndex < points.size(); pointIndex++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        const KernelDensityPoint &point = points[pointIndex];
        int colStart = std::max(0, static_cast<int>(std::floor((point.x - radius - xMin) / cellSize)));
        int colEnd = std::min(cols - 1, static_cast<int>(std::floor((point.x + radius - xMin) / cellSize)));
        int rowStart = std::max(0, static_cast<int>(std::floor((yMax - (point.y + radius)) / cellSize)));
        int rowEnd = std::min(rows - 1, static_cast<int>(std::floor((yMax - (point.y - radius)) / cellSize)));
        for (int row = rowStart; row <= rowEnd; row++) {
            if (ProcessingLoopCheckpoint("compute")) {
                break;
            }
            double cellY = yMax - (static_cast<double>(row) + 0.5) * cellSize;
            double dy = cellY - point.y;
            for (int col = colStart; col <= colEnd; col++) {
                double cellX = xMin + (static_cast<double>(col) + 0.5) * cellSize;
                double dx = cellX - point.x;
                double distanceSquared = dx * dx + dy * dy;
                if (distanceSquared > radiusSquared) {
                    continue;
                }
                double ratio = 1.0 - distanceSquared / radiusSquared;
                values[static_cast<size_t>(row * cols + col)] += point.weight * kernelNorm * ratio * ratio;
            }
        }
    }

    double areaScale = KernelDensityAreaScale(sourceLayer->crs().mapUnits(), options.areaUnit);
    if (areaScale != 1.0) {
        for (size_t i = 0; i < values.size(); i++) {
            if (ProcessingLoopCheckpoint("compute")) {
                break;
            }
            values[i] *= areaScale;
        }
    }

    std::string writeMessage;
    QString outPath = QString::fromUtf8(outputPath);
    if (!WriteKernelDensityAsciiGrid(outPath, sourceLayer->crs(), outputExtent, cols, rows, cellSize,
        values, writeMessage)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, writeMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::string message = "Kernel Density raster completed; radius=";
    message += std::to_string(radius);
    message += ", cellSize=";
    message += std::to_string(cellSize);
    message += ", points=";
    message += std::to_string(static_cast<long long>(points.size()));
    return MakeProcessResult(true, GIS_OK, message,
        outputPath, outputLayerName ? outputLayerName : "", static_cast<int32_t>(points.size()), outErrCode);
}

const char *PointDensityLayer(LayerHandle handle, double searchRadius, const char *textValue,
                              const char *outputPath, const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0 || searchRadius < 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid point density parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *sourceLayer = state->layer.get();
    if (sourceLayer->geometryType() != Qgis::GeometryType::Point) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Point Density requires point features",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    KernelDensityOptions options = ParseKernelDensityOptions(textValue);
    bool usePopulationField = options.populationField.trimmed().length() > 0 &&
        options.populationField.trimmed().toUpper() != QStringLiteral("NONE");
    int populationFieldIndex = -1;
    if (usePopulationField) {
        populationFieldIndex = sourceLayer->fields().indexOf(options.populationField.trimmed());
        if (populationFieldIndex < 0) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
                "Population field was not found",
                outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
        }
    }

    std::vector<KernelDensityPoint> points;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry geometry = feature.geometry();
        double weight = KernelDensityWeight(feature, populationFieldIndex, usePopulationField);
        CollectKernelDensityPoints(geometry, weight, points);
    }
    if (points.empty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Point Density requires at least one weighted point",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsRectangle sourceExtent = sourceLayer->extent();
    double radius = searchRadius > 0.0 ? searchRadius : std::min(std::abs(sourceExtent.width()),
        std::abs(sourceExtent.height())) / 30.0;
    if (radius <= 0.0) {
        radius = KernelDensityDefaultSearchRadius(points, sourceExtent);
    }
    if (radius <= 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Point Density search radius is invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsRectangle outputExtent = sourceExtent;
    outputExtent.grow(radius);
    double cellSize = options.cellSize > 0.0 ? options.cellSize : KernelDensityDefaultCellSize(outputExtent, radius);
    if (cellSize <= 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Point Density cell size is invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int cols = static_cast<int>(std::ceil(outputExtent.width() / cellSize));
    int rows = static_cast<int>(std::ceil(outputExtent.height() / cellSize));
    if (cols <= 0 || rows <= 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Point Density output extent is invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    long long cellCount = static_cast<long long>(cols) * static_cast<long long>(rows);
    if (cellCount > 4000000LL) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Point Density output has too many cells; increase the cell size",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    outputExtent.setXMaximum(outputExtent.xMinimum() + static_cast<double>(cols) * cellSize);
    outputExtent.setYMaximum(outputExtent.yMinimum() + static_cast<double>(rows) * cellSize);

    std::vector<double> values(static_cast<size_t>(cellCount), 0.0);
    std::vector<int> hits(static_cast<size_t>(cellCount), 0);
    double radiusSquared = radius * radius;
    double xMin = outputExtent.xMinimum();
    double yMax = outputExtent.yMaximum();
    for (size_t pointIndex = 0; pointIndex < points.size(); pointIndex++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        const KernelDensityPoint &point = points[pointIndex];
        int colStart = std::max(0, static_cast<int>(std::floor((point.x - radius - xMin) / cellSize)));
        int colEnd = std::min(cols - 1, static_cast<int>(std::floor((point.x + radius - xMin) / cellSize)));
        int rowStart = std::max(0, static_cast<int>(std::floor((yMax - (point.y + radius)) / cellSize)));
        int rowEnd = std::min(rows - 1, static_cast<int>(std::floor((yMax - (point.y - radius)) / cellSize)));
        for (int row = rowStart; row <= rowEnd; row++) {
            if (ProcessingLoopCheckpoint("compute")) {
                break;
            }
            double cellY = yMax - (static_cast<double>(row) + 0.5) * cellSize;
            double dy = cellY - point.y;
            for (int col = colStart; col <= colEnd; col++) {
                double cellX = xMin + (static_cast<double>(col) + 0.5) * cellSize;
                double dx = cellX - point.x;
                double distanceSquared = dx * dx + dy * dy;
                if (distanceSquared > radiusSquared) {
                    continue;
                }
                size_t cellIndex = static_cast<size_t>(row * cols + col);
                values[cellIndex] += point.weight;
                hits[cellIndex] = 1;
            }
        }
    }

    double area = 3.14159265358979323846 * radiusSquared;
    double areaScale = KernelDensityAreaScale(sourceLayer->crs().mapUnits(), options.areaUnit);
    for (size_t i = 0; i < values.size(); i++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        if (hits[i] == 0) {
            values[i] = -9999.0;
        } else {
            values[i] = values[i] / area * areaScale;
        }
    }

    std::string writeMessage;
    QString outPath = QString::fromUtf8(outputPath);
    if (!WriteKernelDensityAsciiGrid(outPath, sourceLayer->crs(), outputExtent, cols, rows, cellSize,
        values, writeMessage)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, writeMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::string message = "Point Density raster completed; radius=";
    message += std::to_string(radius);
    message += ", cellSize=";
    message += std::to_string(cellSize);
    message += ", points=";
    message += std::to_string(static_cast<long long>(points.size()));
    return MakeProcessResult(true, GIS_OK, message,
        outputPath, outputLayerName ? outputLayerName : "", static_cast<int32_t>(points.size()), outErrCode);
}

const char *LineDensityLayer(LayerHandle handle, double searchRadius, const char *textValue,
                             const char *outputPath, const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0 || searchRadius < 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid line density parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *sourceLayer = state->layer.get();
    if (sourceLayer->geometryType() != Qgis::GeometryType::Line) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Line Density requires polyline features",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    KernelDensityOptions options = ParseKernelDensityOptions(textValue);
    bool usePopulationField = options.populationField.trimmed().length() > 0 &&
        options.populationField.trimmed().toUpper() != QStringLiteral("NONE");
    int populationFieldIndex = -1;
    if (usePopulationField) {
        populationFieldIndex = sourceLayer->fields().indexOf(options.populationField.trimmed());
        if (populationFieldIndex < 0) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
                "Population field was not found",
                outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
        }
    }

    std::vector<LineDensitySegment> segments;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry geometry = feature.geometry();
        double weight = KernelDensityWeight(feature, populationFieldIndex, usePopulationField);
        CollectLineDensitySegments(geometry, weight, segments);
    }
    if (segments.empty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Line Density requires at least one weighted line segment",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsRectangle sourceExtent = sourceLayer->extent();
    double shortestSide = std::min(std::abs(sourceExtent.width()), std::abs(sourceExtent.height()));
    double radius = searchRadius > 0.0 ? searchRadius : shortestSide / 30.0;
    if (radius <= 0.0) {
        radius = std::max(std::abs(sourceExtent.width()), std::abs(sourceExtent.height())) / 30.0;
    }
    if (radius <= 0.0) {
        radius = 1.0;
    }

    QgsRectangle outputExtent = sourceExtent;
    outputExtent.grow(radius);
    double cellSize = options.cellSize > 0.0 ? options.cellSize : KernelDensityDefaultCellSize(outputExtent, radius);
    if (cellSize <= 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Line Density cell size is invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int cols = static_cast<int>(std::ceil(outputExtent.width() / cellSize));
    int rows = static_cast<int>(std::ceil(outputExtent.height() / cellSize));
    if (cols <= 0 || rows <= 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Line Density output extent is invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    long long cellCount = static_cast<long long>(cols) * static_cast<long long>(rows);
    if (cellCount > 4000000LL) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Line Density output has too many cells; increase the cell size",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    outputExtent.setXMaximum(outputExtent.xMinimum() + static_cast<double>(cols) * cellSize);
    outputExtent.setYMaximum(outputExtent.yMinimum() + static_cast<double>(rows) * cellSize);

    std::vector<double> values(static_cast<size_t>(cellCount), 0.0);
    std::vector<int> hits(static_cast<size_t>(cellCount), 0);
    double xMin = outputExtent.xMinimum();
    double yMax = outputExtent.yMaximum();
    for (size_t segmentIndex = 0; segmentIndex < segments.size(); segmentIndex++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        const LineDensitySegment &segment = segments[segmentIndex];
        double minX = std::min(segment.x1, segment.x2) - radius;
        double maxX = std::max(segment.x1, segment.x2) + radius;
        double minY = std::min(segment.y1, segment.y2) - radius;
        double maxY = std::max(segment.y1, segment.y2) + radius;
        int colStart = std::max(0, static_cast<int>(std::floor((minX - xMin) / cellSize)));
        int colEnd = std::min(cols - 1, static_cast<int>(std::floor((maxX - xMin) / cellSize)));
        int rowStart = std::max(0, static_cast<int>(std::floor((yMax - maxY) / cellSize)));
        int rowEnd = std::min(rows - 1, static_cast<int>(std::floor((yMax - minY) / cellSize)));
        for (int row = rowStart; row <= rowEnd; row++) {
            if (ProcessingLoopCheckpoint("compute")) {
                break;
            }
            double cellY = yMax - (static_cast<double>(row) + 0.5) * cellSize;
            for (int col = colStart; col <= colEnd; col++) {
                double cellX = xMin + (static_cast<double>(col) + 0.5) * cellSize;
                double insideLength = SegmentLengthInsideCircle(segment, cellX, cellY, radius);
                if (insideLength <= 0.0) {
                    continue;
                }
                size_t cellIndex = static_cast<size_t>(row * cols + col);
                values[cellIndex] += insideLength * segment.weight;
                hits[cellIndex] = 1;
            }
        }
    }

    double area = 3.14159265358979323846 * radius * radius;
    double densityScale = LineDensityScale(sourceLayer->crs().mapUnits(), options.areaUnit);
    for (size_t i = 0; i < values.size(); i++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        if (hits[i] == 0) {
            values[i] = -9999.0;
        } else {
            values[i] = values[i] / area * densityScale;
        }
    }

    std::string writeMessage;
    QString outPath = QString::fromUtf8(outputPath);
    if (!WriteKernelDensityAsciiGrid(outPath, sourceLayer->crs(), outputExtent, cols, rows, cellSize,
        values, writeMessage)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, writeMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::string message = "Line Density raster completed; radius=";
    message += std::to_string(radius);
    message += ", cellSize=";
    message += std::to_string(cellSize);
    message += ", segments=";
    message += std::to_string(static_cast<long long>(segments.size()));
    return MakeProcessResult(true, GIS_OK, message,
        outputPath, outputLayerName ? outputLayerName : "", static_cast<int32_t>(segments.size()), outErrCode);
}

const char *IdwInterpolationLayer(LayerHandle handle, double searchRadius, const char *textValue,
                                  const char *outputPath, const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0 || searchRadius < 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid IDW parameters",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *sourceLayer = state->layer.get();
    if (sourceLayer->geometryType() != Qgis::GeometryType::Point) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "IDW requires point features",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    IdwOptions options = ParseIdwOptions(textValue);
    if (options.power <= 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "IDW power must be greater than 0",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QString valueField = options.valueField.trimmed();
    if (valueField.length() == 0 || valueField.toUpper() == QStringLiteral("NONE")) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "IDW requires a numeric value field",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    int valueFieldIndex = sourceLayer->fields().indexOf(valueField);
    if (valueFieldIndex < 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "IDW value field was not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::vector<IdwPoint> points;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QVariant value = feature.attribute(valueFieldIndex);
        if (!value.isValid() || value.isNull()) {
            continue;
        }
        bool ok = false;
        double numericValue = value.toDouble(&ok);
        if (!ok) {
            continue;
        }
        CollectIdwPoints(feature.geometry(), numericValue, points);
    }
    if (points.empty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "IDW requires at least one point with a numeric value",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsRectangle outputExtent = sourceLayer->extent();
    double fallbackRadius = std::max(std::abs(outputExtent.width()), std::abs(outputExtent.height())) / 30.0;
    if (fallbackRadius <= 0.0) {
        fallbackRadius = 1.0;
    }
    if (outputExtent.width() <= 0.0 || outputExtent.height() <= 0.0) {
        outputExtent.grow(fallbackRadius);
    }
    double cellSize = options.cellSize > 0.0 ? options.cellSize : KernelDensityDefaultCellSize(outputExtent,
        searchRadius > 0.0 ? searchRadius : fallbackRadius);
    if (cellSize <= 0.0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "IDW cell size is invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int cols = static_cast<int>(std::ceil(outputExtent.width() / cellSize));
    int rows = static_cast<int>(std::ceil(outputExtent.height() / cellSize));
    if (cols <= 0 || rows <= 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "IDW output extent is invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    long long cellCount = static_cast<long long>(cols) * static_cast<long long>(rows);
    if (cellCount > 4000000LL) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "IDW output has too many cells; increase the cell size",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    outputExtent.setXMaximum(outputExtent.xMinimum() + static_cast<double>(cols) * cellSize);
    outputExtent.setYMaximum(outputExtent.yMinimum() + static_cast<double>(rows) * cellSize);

    std::vector<double> values(static_cast<size_t>(cellCount), -9999.0);
    double radiusSquared = searchRadius * searchRadius;
    double xMin = outputExtent.xMinimum();
    double yMax = outputExtent.yMaximum();
    for (int row = 0; row < rows; row++) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        double cellY = yMax - (static_cast<double>(row) + 0.5) * cellSize;
        for (int col = 0; col < cols; col++) {
            double cellX = xMin + (static_cast<double>(col) + 0.5) * cellSize;
            double weightedSum = 0.0;
            double weightSum = 0.0;
            bool exact = false;
            double exactValue = 0.0;
            for (size_t pointIndex = 0; pointIndex < points.size(); pointIndex++) {
                if (ProcessingLoopCheckpoint("compute")) {
                    break;
                }
                double dx = cellX - points[pointIndex].x;
                double dy = cellY - points[pointIndex].y;
                double distanceSquared = dx * dx + dy * dy;
                if (distanceSquared <= 0.000000000001) {
                    exact = true;
                    exactValue = points[pointIndex].value;
                    break;
                }
                if (searchRadius > 0.0 && distanceSquared > radiusSquared) {
                    continue;
                }
                double distance = std::sqrt(distanceSquared);
                double weight = 1.0 / std::pow(distance, options.power);
                weightedSum += weight * points[pointIndex].value;
                weightSum += weight;
            }
            size_t cellIndex = static_cast<size_t>(row * cols + col);
            if (exact) {
                values[cellIndex] = exactValue;
            } else if (weightSum > 0.0) {
                values[cellIndex] = weightedSum / weightSum;
            }
        }
    }

    std::string writeMessage;
    QString outPath = QString::fromUtf8(outputPath);
    if (!WriteKernelDensityAsciiGrid(outPath, sourceLayer->crs(), outputExtent, cols, rows, cellSize,
        values, writeMessage)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, writeMessage,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::string message = "IDW raster completed; radius=";
    message += std::to_string(searchRadius);
    message += ", cellSize=";
    message += std::to_string(cellSize);
    message += ", points=";
    message += std::to_string(static_cast<long long>(points.size()));
    return MakeProcessResult(true, GIS_OK, message,
        outputPath, outputLayerName ? outputLayerName : "", static_cast<int32_t>(points.size()), outErrCode);
}

static const char *XYTableToPoints(LayerHandle handle, const char *textValue,
                                   const char *outputPath, const char *outputLayerName,
                                   int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "XY table output path is empty",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QString outPath = QString::fromUtf8(outputPath).trimmed();
    if (!outPath.endsWith(QStringLiteral(".gpkg"), Qt::CaseInsensitive)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "XY table output must use .gpkg",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "XY source table was not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QgsVectorLayer *sourceLayer = state->layer.get();
    QgsFields fields = sourceLayer->fields();
    XYTableOptions options = ParseXYTableOptions(textValue);
    if (options.xFieldIndex < 0 || options.xFieldIndex >= fields.count() ||
        options.yFieldIndex < 0 || options.yFieldIndex >= fields.count() ||
        options.xFieldIndex == options.yFieldIndex ||
        options.zFieldIndex >= fields.count() || options.mFieldIndex >= fields.count() ||
        options.zFieldIndex < -1 || options.mFieldIndex < -1 ||
        options.zFieldIndex == options.xFieldIndex || options.zFieldIndex == options.yFieldIndex ||
        options.mFieldIndex == options.xFieldIndex || options.mFieldIndex == options.yFieldIndex ||
        (options.zFieldIndex >= 0 && options.zFieldIndex == options.mFieldIndex)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "XY field indexes are invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QByteArray crsText = options.crsDefinition.toUtf8();
    QgsCoordinateReferenceSystem crs = CrsFromDefinition(crsText.constData());
    if (!crs.isValid()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "XY coordinate reference system is invalid",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QFileInfo outputFile(outPath);
    QDir outputDirectory = outputFile.absoluteDir();
    if (!outputDirectory.exists() && !outputDirectory.mkpath(QStringLiteral("."))) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Cannot create XY table output directory",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QString layerName = (outputLayerName && std::strlen(outputLayerName) > 0)
        ? QString::fromUtf8(outputLayerName) : QStringLiteral("xy_points");
    QgsVectorFileWriter::SaveVectorOptions writerOptions;
    writerOptions.driverName = QStringLiteral("GPKG");
    writerOptions.layerName = layerName;
    writerOptions.fileEncoding = QStringLiteral("UTF-8");
    Qgis::WkbType pointType = Qgis::WkbType::Point;
    if (options.zFieldIndex >= 0 && options.mFieldIndex >= 0) {
        pointType = Qgis::WkbType::PointZM;
    } else if (options.zFieldIndex >= 0) {
        pointType = Qgis::WkbType::PointZ;
    } else if (options.mFieldIndex >= 0) {
        pointType = Qgis::WkbType::PointM;
    }
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outPath, fields,
        pointType, crs, QgsCoordinateTransformContext(), writerOptions));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create XY point GeoPackage",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    int32_t writtenCount = 0;
    int32_t skippedCount = 0;
    bool writeFailed = false;
    QgsFeatureIterator iterator = sourceLayer->getFeatures();
    QgsFeature sourceFeature;
    while (iterator.nextFeature(sourceFeature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        bool xOk = false;
        bool yOk = false;
        double x = sourceFeature.attribute(options.xFieldIndex).toDouble(&xOk);
        double y = sourceFeature.attribute(options.yFieldIndex).toDouble(&yOk);
        if (!xOk || !yOk || !std::isfinite(x) || !std::isfinite(y)) {
            skippedCount++;
            continue;
        }

        double z = 0.0;
        double m = 0.0;
        bool zOk = true;
        bool mOk = true;
        if (options.zFieldIndex >= 0) {
            z = sourceFeature.attribute(options.zFieldIndex).toDouble(&zOk);
            zOk = zOk && std::isfinite(z);
        }
        if (options.mFieldIndex >= 0) {
            m = sourceFeature.attribute(options.mFieldIndex).toDouble(&mOk);
            mOk = mOk && std::isfinite(m);
        }
        if (!zOk || !mOk) {
            skippedCount++;
            continue;
        }

        QgsFeature outputFeature(fields);
        outputFeature.setAttributes(sourceFeature.attributes());
        if (pointType == Qgis::WkbType::PointZM) {
            outputFeature.setGeometry(QgsGeometry(new QgsPoint(Qgis::WkbType::PointZM, x, y, z, m)));
        } else if (pointType == Qgis::WkbType::PointZ) {
            outputFeature.setGeometry(QgsGeometry(new QgsPoint(Qgis::WkbType::PointZ, x, y, z)));
        } else if (pointType == Qgis::WkbType::PointM) {
            outputFeature.setGeometry(QgsGeometry(new QgsPoint(Qgis::WkbType::PointM, x, y, 0.0, m)));
        } else {
            outputFeature.setGeometry(QgsGeometry::fromPointXY(QgsPointXY(x, y)));
        }
        if (!writer->addFeature(outputFeature)) {
            writeFailed = true;
            break;
        }
        writtenCount++;
    }

    if (writeFailed) {
        writer.reset();
        QFile::remove(outPath);
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed while writing XY point feature",
            outputPath, outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
    }
    if (writtenCount == 0) {
        writer.reset();
        QFile::remove(outPath);
        std::string message = "No valid XY rows; skipped=";
        message += std::to_string(skippedCount);
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, message,
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    std::string message = "XY table converted to GeoPackage points; written=";
    message += std::to_string(writtenCount);
    message += "; skipped=";
    message += std::to_string(skippedCount);
    return MakeProcessResult(true, GIS_OK, message, outputPath,
        outputLayerName ? outputLayerName : "", writtenCount, outErrCode);
}

static QString PortableTableName(const QString &sourceName, int index, QSet<QString> &usedNames)
{
    QString cleanName;
    QString trimmed = sourceName.trimmed();
    for (int i = 0; i < trimmed.size(); i++) {
        QChar ch = trimmed.at(i);
        if (ch.isLetterOrNumber() || ch == QChar('_')) {
            cleanName.append(ch);
        } else {
            cleanName.append(QChar('_'));
        }
    }
    while (cleanName.contains(QStringLiteral("__"))) {
        cleanName.replace(QStringLiteral("__"), QStringLiteral("_"));
    }
    cleanName = cleanName.left(48).trimmed();
    if (cleanName.isEmpty()) {
        cleanName = QStringLiteral("layer_%1").arg(index + 1);
    }
    if (cleanName.at(0).isDigit()) {
        cleanName.prepend(QStringLiteral("layer_"));
    }
    QString candidate = cleanName;
    int suffix = 2;
    while (usedNames.contains(candidate.toLower())) {
        candidate = cleanName.left(42) + QStringLiteral("_%1").arg(suffix);
        suffix++;
    }
    usedNames.insert(candidate.toLower());
    return candidate;
}

static const char *ExportPortableProjectPackage(const char *textValue, const char *outputPath,
                                                const char *outputLayerName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Portable project output path is empty",
            "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    if (!EnsureQgis()) {
        return MakeProcessResult(false, GIS_ERR_NATIVE_NOT_READY, "QGIS is not ready for project packaging",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QJsonObject optionsObject;
    if (textValue && std::strlen(textValue) > 0) {
        QJsonParseError optionsError;
        QJsonDocument optionsDocument = QJsonDocument::fromJson(QByteArray(textValue), &optionsError);
        if (optionsError.error != QJsonParseError::NoError || !optionsDocument.isObject()) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Portable project options JSON is invalid",
                outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
        }
        optionsObject = optionsDocument.object();
    }

    QString projectName = optionsObject.value(QStringLiteral("projectName")).toString().trimmed();
    if (projectName.isEmpty()) {
        projectName = QString::fromUtf8(outputLayerName ? outputLayerName : "").trimmed();
    }
    if (projectName.isEmpty()) {
        projectName = QStringLiteral("GeoNest Portable Project");
    }
    QString projectCrsText = optionsObject.value(QStringLiteral("projectCrs")).toString().trimmed();
    QString layerHandlesText = optionsObject.value(QStringLiteral("layerHandles")).toString().trimmed();
    QString visibleHandlesText = optionsObject.value(QStringLiteral("visibleLayerHandles")).toString().trimmed();
    bool hasVisibilityList = optionsObject.contains(QStringLiteral("visibleLayerHandles"));

    std::vector<LayerHandle> requestedHandles;
    if (!layerHandlesText.isEmpty()) {
        QByteArray handlesBytes = layerHandlesText.toUtf8();
        requestedHandles = ParseLayerHandles(handlesBytes.constData());
    } else {
        requestedHandles = g_layerOrder;
    }
    if (requestedHandles.empty()) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "No loaded layers are available for packaging",
            outputPath, projectName.toStdString(), 0, outErrCode);
    }

    QSet<LayerHandle> visibleHandles;
    if (hasVisibilityList && !visibleHandlesText.isEmpty()) {
        QByteArray visibleBytes = visibleHandlesText.toUtf8();
        std::vector<LayerHandle> parsedVisible = ParseLayerHandles(visibleBytes.constData());
        for (size_t i = 0; i < parsedVisible.size(); i++) {
            visibleHandles.insert(parsedVisible[i]);
        }
    }

    QString packagePath = QString::fromUtf8(outputPath);
    QFileInfo packageInfo(packagePath);
    QDir packageParent = packageInfo.absoluteDir();
    if (!packageParent.exists() && !packageParent.mkpath(QStringLiteral("."))) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Cannot create portable package directory",
            outputPath, projectName.toStdString(), 0, outErrCode);
    }
    QString stagingName = QStringLiteral(".geonest_package_") +
        QUuid::createUuid().toString(QUuid::WithoutBraces);
    QString stagingPath = packageParent.filePath(stagingName);
    QDir stagingDirectory(stagingPath);
    if (!QDir().mkpath(stagingPath)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Cannot create portable package staging directory",
            outputPath, projectName.toStdString(), 0, outErrCode);
    }

    QString geopackagePath = stagingDirectory.filePath(QStringLiteral("project.gpkg"));
    QString qgzPath = stagingDirectory.filePath(QStringLiteral("project.qgz"));
    QString manifestPath = stagingDirectory.filePath(QStringLiteral("manifest.json"));
    QgsProject project;
    project.setFileName(qgzPath);
    project.setTitle(projectName);
    project.setFilePathStorage(Qgis::FilePathType::Relative);
    QgsCoordinateReferenceSystem requestedProjectCrs = CrsFromDefinition(projectCrsText.toUtf8().constData());
    if (requestedProjectCrs.isValid()) {
        project.setCrs(requestedProjectCrs);
    }

    QSet<QString> usedTableNames;
    QJsonArray manifestLayers;
    QJsonArray manifestAttachments;
    QJsonArray manifestFonts;
    QJsonArray manifestSvgSymbols;
    QJsonArray manifestRelations;
    QJsonArray manifestForms;
    QStringList packagedAssetPaths;
    int vectorLayerCount = 0;
    int rasterLayerCount = 0;
    int rasterSkippedCount = 0;
    for (size_t i = 0; i < requestedHandles.size(); i++) {
        LayerHandle handle = requestedHandles[i];
        QgisLayerState *state = FindLayer(handle);
        if (!state || !state->layer) {
            QgisRasterState *rasterState = FindRasterLayer(handle);
            if (rasterState && rasterState->layer) {
                QString rasterSource = rasterState->layer->source();
                int providerSuffix = rasterSource.indexOf(QChar('|'));
                if (providerSuffix > 0) {
                    rasterSource = rasterSource.left(providerSuffix);
                }
                QFileInfo rasterSourceInfo(rasterSource);
                if (!rasterSourceInfo.exists() || !rasterSourceInfo.isFile()) {
                    rasterSkippedCount++;
                    continue;
                }
                QString rasterBaseName = PortableTableName(rasterState->layer->name(), rasterLayerCount,
                    usedTableNames);
                QString rasterSuffix = rasterSourceInfo.suffix().trimmed();
                QString rasterFileName = rasterBaseName + (rasterSuffix.isEmpty()
                    ? QStringLiteral(".raster") : QStringLiteral(".") + rasterSuffix);
                QString packagedRasterPath = stagingDirectory.filePath(rasterFileName);
                QFile::remove(packagedRasterPath);
                if (!QFile::copy(rasterSourceInfo.absoluteFilePath(), packagedRasterPath)) {
                    rasterSkippedCount++;
                    continue;
                }
                QgsRasterLayer *packagedRaster = new QgsRasterLayer(packagedRasterPath,
                    rasterState->layer->name(), QStringLiteral("gdal"));
                if (!packagedRaster->isValid()) {
                    delete packagedRaster;
                    QFile::remove(packagedRasterPath);
                    rasterSkippedCount++;
                    continue;
                }
                project.addMapLayer(packagedRaster, false);
                QgsLayerTreeLayer *rasterTreeLayer = project.layerTreeRoot()->addLayer(packagedRaster);
                bool rasterVisible = !hasVisibilityList || visibleHandles.contains(handle);
                if (rasterTreeLayer) {
                    rasterTreeLayer->setItemVisibilityChecked(rasterVisible);
                }
                QJsonObject manifestRaster;
                manifestRaster.insert(QStringLiteral("handle"), static_cast<int>(handle));
                manifestRaster.insert(QStringLiteral("name"), rasterState->layer->name());
                manifestRaster.insert(QStringLiteral("type"), QStringLiteral("raster"));
                manifestRaster.insert(QStringLiteral("file"), rasterFileName);
                manifestRaster.insert(QStringLiteral("visible"), rasterVisible);
                manifestLayers.append(manifestRaster);
                packagedAssetPaths.append(packagedRasterPath);
                rasterLayerCount++;
            }
            continue;
        }

        QgsVectorLayer *sourceLayer = state->layer.get();
        QString tableName = PortableTableName(sourceLayer->name(), vectorLayerCount, usedTableNames);
        QgsVectorFileWriter::SaveVectorOptions writerOptions;
        writerOptions.driverName = QStringLiteral("GPKG");
        writerOptions.layerName = tableName;
        writerOptions.fileEncoding = QStringLiteral("UTF-8");
        writerOptions.actionOnExistingFile = vectorLayerCount == 0
            ? QgsVectorFileWriter::CreateOrOverwriteFile
            : QgsVectorFileWriter::CreateOrOverwriteLayer;
        QString writerError;
        QgsVectorFileWriter::WriterError writerResult = QgsVectorFileWriter::writeAsVectorFormatV3(
            sourceLayer, geopackagePath, project.transformContext(), writerOptions, &writerError);
        if (writerResult != QgsVectorFileWriter::NoError) {
            project.clear();
            QDir(stagingPath).removeRecursively();
            std::string message = "Failed to package vector layer ";
            message += ToStdString(sourceLayer->name());
            if (!writerError.isEmpty()) {
                message += ": ";
                message += ToStdString(writerError);
            }
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message,
                outputPath, projectName.toStdString(), vectorLayerCount, outErrCode);
        }

        QString providerUri = geopackagePath + QStringLiteral("|layername=") + tableName;
        QgsVectorLayer *packagedLayer = new QgsVectorLayer(providerUri, sourceLayer->name(), QStringLiteral("ogr"));
        if (!packagedLayer->isValid()) {
            delete packagedLayer;
            project.clear();
            QDir(stagingPath).removeRecursively();
            return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT,
                "Packaged GeoPackage layer could not be reopened", outputPath,
                projectName.toStdString(), vectorLayerCount, outErrCode);
        }
        if (sourceLayer->renderer()) {
            packagedLayer->setRenderer(sourceLayer->renderer()->clone());
        }
        if (sourceLayer->labeling()) {
            packagedLayer->setLabeling(sourceLayer->labeling()->clone());
        }
        packagedLayer->setLabelsEnabled(sourceLayer->labelsEnabled());
        packagedLayer->setOpacity(sourceLayer->opacity());
        packagedLayer->setDisplayExpression(sourceLayer->displayExpression());
        project.addMapLayer(packagedLayer, false);
        QgsLayerTreeLayer *treeLayer = project.layerTreeRoot()->addLayer(packagedLayer);
        bool visible = !hasVisibilityList || visibleHandles.contains(handle);
        if (treeLayer) {
            treeLayer->setItemVisibilityChecked(visible);
        }

        QJsonObject manifestLayer;
        manifestLayer.insert(QStringLiteral("handle"), static_cast<int>(handle));
        manifestLayer.insert(QStringLiteral("name"), sourceLayer->name());
        manifestLayer.insert(QStringLiteral("type"), QStringLiteral("vector"));
        manifestLayer.insert(QStringLiteral("table"), tableName);
        manifestLayer.insert(QStringLiteral("visible"), visible);
        manifestLayer.insert(QStringLiteral("featureCount"), static_cast<qint64>(sourceLayer->featureCount()));
        manifestLayers.append(manifestLayer);
        vectorLayerCount++;
    }

    if (vectorLayerCount == 0 && rasterLayerCount == 0) {
        project.clear();
        QDir(stagingPath).removeRecursively();
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND,
            "Portable project requires at least one file-backed vector or raster layer",
            outputPath, projectName.toStdString(), 0, outErrCode);
    }
    if (!project.write(qgzPath)) {
        project.clear();
        QDir(stagingPath).removeRecursively();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to write relative-path QGZ project",
            outputPath, projectName.toStdString(), vectorLayerCount, outErrCode);
    }

    QJsonObject manifest;
    manifest.insert(QStringLiteral("format"), QStringLiteral("GEONEST_PORTABLE_PROJECT_V2"));
    manifest.insert(QStringLiteral("projectName"), projectName);
    manifest.insert(QStringLiteral("projectFile"), QStringLiteral("project.qgz"));
    manifest.insert(QStringLiteral("geopackageFile"), vectorLayerCount > 0 ?
        QStringLiteral("project.gpkg") : QString());
    manifest.insert(QStringLiteral("vectorLayerCount"), vectorLayerCount);
    manifest.insert(QStringLiteral("rasterLayerCount"), rasterLayerCount);
    manifest.insert(QStringLiteral("rasterSkippedCount"), rasterSkippedCount);
    manifest.insert(QStringLiteral("layers"), manifestLayers);
    manifest.insert(QStringLiteral("attachments"), manifestAttachments);
    manifest.insert(QStringLiteral("fonts"), manifestFonts);
    manifest.insert(QStringLiteral("svgSymbols"), manifestSvgSymbols);
    manifest.insert(QStringLiteral("relations"), manifestRelations);
    manifest.insert(QStringLiteral("forms"), manifestForms);
    manifest.insert(QStringLiteral("supportsRelativePaths"), true);
    manifest.insert(QStringLiteral("supportsProjectAssets"), true);
    QFile manifestFile(manifestPath);
    if (!manifestFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        project.clear();
        QDir(stagingPath).removeRecursively();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create portable package manifest",
            outputPath, projectName.toStdString(), vectorLayerCount, outErrCode);
    }
    manifestFile.write(QJsonDocument(manifest).toJson(QJsonDocument::Indented));
    manifestFile.close();

    QStringList archiveFiles;
    archiveFiles.append(qgzPath);
    if (vectorLayerCount > 0) {
        archiveFiles.append(geopackagePath);
    }
    archiveFiles.append(manifestPath);
    archiveFiles.append(packagedAssetPaths);
    project.clear();
    if (!QgsZipUtils::zip(packagePath, archiveFiles, true)) {
        QDir(stagingPath).removeRecursively();
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create .gnpkg archive",
            outputPath, projectName.toStdString(), vectorLayerCount, outErrCode);
    }
    QDir(stagingPath).removeRecursively();

    std::string message = "Portable project package V2 created; vector layers=";
    message += std::to_string(vectorLayerCount);
    message += "; raster layers=";
    message += std::to_string(rasterLayerCount);
    if (rasterSkippedCount > 0) {
        message += "; warning: raster layers skipped=";
        message += std::to_string(rasterSkippedCount);
    }
    return MakeProcessResult(true, GIS_OK, message, outputPath,
        projectName.toStdString(), vectorLayerCount + rasterLayerCount, outErrCode);
}

static bool RenderAtlasPageImage(const QList<QgsMapLayer *> &layers, const QgsRectangle &sourceExtent,
                                 const QgsCoordinateReferenceSystem &sourceCrs, const QString &title,
                                 const QString &legendTitle, int32_t width, int32_t height,
                                 bool showLegend, bool showScale, bool showNorth, bool showGrid,
                                 int32_t basemapMode, const QString &basemapLabel, QImage &pageImage,
                                 QString &errorMessage)
{
    QgsRectangle renderExtent = sourceExtent;
    QgsCoordinateReferenceSystem renderCrs = sourceCrs;
    QImage onlineBasemap;
    QString attribution;
    int32_t exportBasemapMode = StaticExportBasemapMode(basemapMode);
    if (IsXyzExportBasemap(exportBasemapMode)) {
        QgsCoordinateReferenceSystem webMercator(QStringLiteral("EPSG:3857"));
        if (!webMercator.isValid() || !sourceCrs.isValid()) {
            errorMessage = QStringLiteral("Atlas coverage CRS cannot be transformed for XYZ basemap export");
            return false;
        }
        if (sourceCrs != webMercator) {
            try {
                QgsCoordinateTransform transform(sourceCrs, webMercator, CurrentProcessingTransformContext());
                renderExtent = transform.transformBoundingBox(sourceExtent);
            } catch (const QgsCsException &) {
                errorMessage = QStringLiteral("Atlas extent transformation to EPSG:3857 failed");
                return false;
            }
        }
        renderCrs = webMercator;
    }

    int mapWidth = std::max(32, width - 64);
    int mapHeight = std::max(32, height - 144);
    QImage mapImage = RenderMapImage(layers, renderExtent, renderCrs, mapWidth, mapHeight);
    if (mapImage.isNull()) {
        errorMessage = QStringLiteral("Atlas map rendering returned an empty image");
        return false;
    }
    if (IsXyzExportBasemap(exportBasemapMode) &&
        !RenderXyzBasemap(renderExtent, mapWidth, mapHeight, exportBasemapMode, onlineBasemap, attribution,
            errorMessage)) {
        return false;
    }

    pageImage = QImage(width, height, QImage::Format_ARGB32_Premultiplied);
    pageImage.fill(QColor("#FFFFFF"));
    QPainter painter(&pageImage);
    DrawLayoutDecorations(painter, mapImage, layers, title, legendTitle,
        QStringLiteral("Atlas feature extent"), QStringLiteral("GeoNest layout atlas"),
        showLegend, showScale, showNorth, showGrid, width, height, exportBasemapMode, basemapLabel,
        onlineBasemap, attribution, true, true, true);
    painter.end();
    return true;
}

static const char *ExportLayoutAtlas(LayerHandle coverageHandle, const char *textValue,
                                     const char *outputPath, const char *outputLayerName,
                                     int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Atlas output path is empty", "",
            outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgisLayerState *coverageState = FindLayer(coverageHandle);
    if (!coverageState || !coverageState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Atlas coverage layer was not found",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }

    QJsonObject optionsObject;
    if (textValue && std::strlen(textValue) > 0) {
        QJsonParseError optionsError;
        QJsonDocument optionsDocument = QJsonDocument::fromJson(QByteArray(textValue), &optionsError);
        if (optionsError.error != QJsonParseError::NoError || !optionsDocument.isObject()) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Atlas options JSON is invalid",
                outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
        }
        optionsObject = optionsDocument.object();
    }

    QString format = optionsObject.value(QStringLiteral("format")).toString().trimmed().toLower();
    if (format.isEmpty()) {
        format = QFileInfo(QString::fromUtf8(outputPath)).suffix().toLower();
    }
    if (format != QStringLiteral("pdf") && format != QStringLiteral("png") &&
        format != QStringLiteral("svg")) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Atlas format must be PDF, PNG, or SVG",
            outputPath, outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QString title = optionsObject.value(QStringLiteral("title")).toString().trimmed();
    if (title.isEmpty()) {
        title = QString::fromUtf8(outputLayerName ? outputLayerName : "").trimmed();
    }
    if (title.isEmpty()) {
        title = QStringLiteral("GeoNest Atlas");
    }
    QString filterExpression = optionsObject.value(QStringLiteral("filterExpression")).toString().trimmed();
    QString sortField = optionsObject.value(QStringLiteral("sortField")).toString().trimmed();
    QString groupField = optionsObject.value(QStringLiteral("groupField")).toString().trimmed();
    QString pageNameField = optionsObject.value(QStringLiteral("pageNameField")).toString().trimmed();
    QString dynamicTitle = optionsObject.value(QStringLiteral("dynamicTitle")).toString().trimmed();
    bool sortAscending = optionsObject.value(QStringLiteral("sortAscending")).toBool(true);
    double margin = optionsObject.value(QStringLiteral("margin")).toDouble(0.10);
    margin = ClampDouble(margin, 0.0, 2.0);
    int32_t width = std::max(800, optionsObject.value(QStringLiteral("width")).toInt(1600));
    int32_t height = std::max(600, optionsObject.value(QStringLiteral("height")).toInt(1100));
    int32_t basemapMode = optionsObject.value(QStringLiteral("basemapMode")).toInt(0);
    QString basemapLabel = optionsObject.value(QStringLiteral("basemapLabel")).toString();
    bool showLegend = optionsObject.value(QStringLiteral("showLegend")).toBool(true);
    bool showScale = optionsObject.value(QStringLiteral("showScale")).toBool(true);
    bool showNorth = optionsObject.value(QStringLiteral("showNorth")).toBool(true);
    bool showGrid = optionsObject.value(QStringLiteral("showGrid")).toBool(false);
    QString visibleHandlesText = optionsObject.value(QStringLiteral("visibleLayerHandles")).toString().trimmed();
    if (visibleHandlesText.isEmpty()) {
        visibleHandlesText = QString::number(static_cast<int>(coverageHandle));
    }

    QgsVectorLayer *coverageLayer = coverageState->layer.get();
    if (!filterExpression.isEmpty()) {
        QgsExpression expression(filterExpression);
        if (expression.hasParserError()) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
                ToStdString(expression.parserErrorString()), outputPath, title.toStdString(), 0, outErrCode);
        }
    }
    QgsFeatureRequest featureRequest;
    if (!filterExpression.isEmpty()) {
        featureRequest.setFilterExpression(filterExpression);
    }
    std::vector<AtlasPageDefinition> pages;
    QgsRectangle coverageExtent = coverageLayer->extent();
    double fallbackSpan = std::max(std::abs(coverageExtent.width()), std::abs(coverageExtent.height())) * 0.01;
    if (fallbackSpan <= 0.0 || !std::isfinite(fallbackSpan)) {
        fallbackSpan = 1.0;
    }
    QgsFeatureIterator featureIterator = coverageLayer->getFeatures(featureRequest);
    QgsFeature feature;
    while (featureIterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) {
            continue;
        }
        QgsRectangle featureExtent = geometry.boundingBox();
        if (featureExtent.width() <= 0.0 || featureExtent.height() <= 0.0) {
            double centerX = featureExtent.center().x();
            double centerY = featureExtent.center().y();
            featureExtent = QgsRectangle(centerX - fallbackSpan, centerY - fallbackSpan,
                centerX + fallbackSpan, centerY + fallbackSpan);
        }
        double growDistance = std::max(featureExtent.width(), featureExtent.height()) * margin;
        if (growDistance > 0.0) {
            featureExtent.grow(growDistance);
        }
        AtlasPageDefinition page;
        page.featureId = feature.id();
        page.extent = featureExtent;
        page.sortValue = sortField.isEmpty() ? QString::number(feature.id()) : feature.attribute(sortField).toString();
        page.groupValue = groupField.isEmpty() ? QString() : feature.attribute(groupField).toString();
        page.pageName = pageNameField.isEmpty() ? QString::number(feature.id()) :
            feature.attribute(pageNameField).toString();
        if (page.pageName.trimmed().isEmpty()) {
            page.pageName = QString::number(feature.id());
        }
        pages.push_back(page);
    }
    if (pages.empty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Atlas coverage layer has no exportable geometry after filtering", outputPath,
            title.toStdString(), 0, outErrCode);
    }
    std::sort(pages.begin(), pages.end(), [sortAscending](const AtlasPageDefinition &left,
        const AtlasPageDefinition &right) {
        int compare = QString::localeAwareCompare(left.sortValue, right.sortValue);
        if (compare == 0) {
            compare = left.featureId < right.featureId ? -1 : (left.featureId > right.featureId ? 1 : 0);
        }
        return sortAscending ? compare < 0 : compare > 0;
    });

    QByteArray visibleBytes = visibleHandlesText.toUtf8();
    QList<QgsMapLayer *> layers;
    QgsRectangle unusedExtent;
    QgsCoordinateReferenceSystem unusedCrs;
    if (!CollectMapLayers(layers, unusedExtent, unusedCrs, visibleBytes.constData())) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Atlas has no visible renderable layers",
            outputPath, title.toStdString(), 0, outErrCode);
    }

    QString finalOutputPath = QString::fromUtf8(outputPath);
    QFileInfo outputInfo(finalOutputPath);
    QDir outputDirectory = outputInfo.absoluteDir();
    if (!outputDirectory.exists() && !outputDirectory.mkpath(QStringLiteral("."))) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Cannot create atlas output directory",
            outputPath, title.toStdString(), 0, outErrCode);
    }
    bool archiveBatch = format != QStringLiteral("pdf") &&
        (outputInfo.suffix().compare(QStringLiteral("zip"), Qt::CaseInsensitive) == 0 ||
         outputInfo.suffix().compare(QStringLiteral("gnatlas"), Qt::CaseInsensitive) == 0);
    QString batchDirectoryPath = outputDirectory.absolutePath();
    if (archiveBatch) {
        batchDirectoryPath = outputDirectory.filePath(QStringLiteral(".geonest_atlas_") +
            QUuid::createUuid().toString(QUuid::WithoutBraces));
        if (!QDir().mkpath(batchDirectoryPath)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Cannot create atlas staging directory",
                outputPath, title.toStdString(), 0, outErrCode);
        }
    }
    QString baseName = outputInfo.completeBaseName();
    if (baseName.isEmpty()) {
        baseName = QStringLiteral("GeoNestAtlas");
    }
    QStringList generatedFiles;
    bool exportOk = true;
    QString exportError;

    if (format == QStringLiteral("pdf")) {
        QPdfWriter writer(finalOutputPath);
        writer.setResolution(144);
        writer.setPageSize(QPageSize(QSizeF(width * 25.4 / 144.0, height * 25.4 / 144.0),
            QPageSize::Millimeter));
        QPainter painter(&writer);
        if (!painter.isActive()) {
            exportOk = false;
            exportError = QStringLiteral("Cannot initialize atlas PDF painter");
        }
        for (size_t i = 0; exportOk && i < pages.size(); i++) {
            QImage pageImage;
            QString pageError;
            QString pageTitle = dynamicTitle.isEmpty() ? title + QStringLiteral(" · ") + pages[i].pageName :
                dynamicTitle;
            pageTitle.replace(QStringLiteral("{title}"), title);
            pageTitle.replace(QStringLiteral("{name}"), pages[i].pageName);
            pageTitle.replace(QStringLiteral("{group}"), pages[i].groupValue);
            pageTitle.replace(QStringLiteral("{fid}"), QString::number(pages[i].featureId));
            pageTitle.replace(QStringLiteral("{page}"), QString::number(i + 1));
            pageTitle.replace(QStringLiteral("{pages}"), QString::number(pages.size()));
            if (!RenderAtlasPageImage(layers, pages[i].extent, coverageLayer->crs(), pageTitle,
                QStringLiteral("图例"), width, height, showLegend, showScale, showNorth, showGrid,
                basemapMode, basemapLabel, pageImage, pageError)) {
                exportOk = false;
                exportError = pageError;
                break;
            }
            if (i > 0 && !writer.newPage()) {
                exportOk = false;
                exportError = QStringLiteral("Cannot append atlas PDF page");
                break;
            }
            painter.drawImage(QRect(0, 0, width, height), pageImage);
        }
        painter.end();
        if (!exportOk) {
            QFile::remove(finalOutputPath);
        }
    } else {
        QDir batchDirectory(batchDirectoryPath);
        for (size_t i = 0; exportOk && i < pages.size(); i++) {
            QImage pageImage;
            QString pageError;
            QString pageTitle = dynamicTitle.isEmpty() ? title + QStringLiteral(" · ") + pages[i].pageName :
                dynamicTitle;
            pageTitle.replace(QStringLiteral("{title}"), title);
            pageTitle.replace(QStringLiteral("{name}"), pages[i].pageName);
            pageTitle.replace(QStringLiteral("{group}"), pages[i].groupValue);
            pageTitle.replace(QStringLiteral("{fid}"), QString::number(pages[i].featureId));
            pageTitle.replace(QStringLiteral("{page}"), QString::number(i + 1));
            pageTitle.replace(QStringLiteral("{pages}"), QString::number(pages.size()));
            if (!RenderAtlasPageImage(layers, pages[i].extent, coverageLayer->crs(), pageTitle,
                QStringLiteral("图例"), width, height, showLegend, showScale, showNorth, showGrid,
                basemapMode, basemapLabel, pageImage, pageError)) {
                exportOk = false;
                exportError = pageError;
                break;
            }
            QString fileName = QStringLiteral("%1_%2.%3").arg(baseName)
                .arg(static_cast<int>(i + 1), 4, 10, QChar('0')).arg(format);
            QString pagePath = batchDirectory.filePath(fileName);
            bool pageSaved = false;
            if (format == QStringLiteral("svg")) {
                QSvgGenerator generator;
                generator.setFileName(pagePath);
                generator.setSize(QSize(width, height));
                generator.setViewBox(QRect(0, 0, width, height));
                generator.setResolution(144);
                QPainter painter(&generator);
                if (painter.isActive()) {
                    painter.drawImage(QRect(0, 0, width, height), pageImage);
                    painter.end();
                    pageSaved = QFileInfo::exists(pagePath);
                }
            } else {
                pageSaved = pageImage.save(pagePath, "PNG");
            }
            if (!pageSaved) {
                exportOk = false;
                exportError = QStringLiteral("Failed to write atlas page: ") + pagePath;
                break;
            }
            generatedFiles.append(pagePath);
        }
        if (exportOk && archiveBatch) {
            exportOk = QgsZipUtils::zip(finalOutputPath, generatedFiles, true);
            if (!exportOk) {
                exportError = QStringLiteral("Failed to create atlas batch archive");
            }
        }
        if (!exportOk) {
            for (int i = 0; i < generatedFiles.size(); i++) {
                QFile::remove(generatedFiles.at(i));
            }
            if (archiveBatch) {
                QFile::remove(finalOutputPath);
            }
        }
        if (archiveBatch) {
            QDir(batchDirectoryPath).removeRecursively();
        }
    }

    if (!exportOk) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, ToStdString(exportError), outputPath,
            title.toStdString(), static_cast<int32_t>(generatedFiles.size()), outErrCode);
    }
    QString resultPath = finalOutputPath;
    if (format != QStringLiteral("pdf") && !archiveBatch && !generatedFiles.isEmpty()) {
        resultPath = generatedFiles.first();
    }
    std::string message = "Layout atlas exported; pages=";
    message += std::to_string(static_cast<long long>(pages.size()));
    if (archiveBatch) {
        message += "; batch archive contains ";
        message += ToStdString(format.toUpper());
        message += " pages";
    }
    return MakeProcessResult(true, GIS_OK, message, ToStdString(resultPath),
        title.toStdString(), static_cast<int32_t>(pages.size()), outErrCode);
}

#include "geonest_spatial_analysis.inc"

static bool IsAdvancedSpatialAlgorithm(const QString &algorithmId)
{
    static const QSet<QString> algorithms = {
        QStringLiteral("mean_center"), QStringLiteral("median_center"), QStringLiteral("central_feature"),
        QStringLiteral("standard_distance"), QStringLiteral("directional_distribution"),
        QStringLiteral("global_moran"), QStringLiteral("geary_c"), QStringLiteral("local_moran"),
        QStringLiteral("general_g"), QStringLiteral("gi_star"), QStringLiteral("ripley_k"),
        QStringLiteral("spatial_weights"), QStringLiteral("weights_convert"), QStringLiteral("weights_visualize"),
        QStringLiteral("cluster_outlier"), QStringLiteral("ols"), QStringLiteral("gwr"), QStringLiteral("mgwr"),
        QStringLiteral("interpolation_cv"), QStringLiteral("forest"), QStringLiteral("boosted_trees"),
        QStringLiteral("maxent"), QStringLiteral("space_time_cube"), QStringLiteral("emerging_hotspot"),
        QStringLiteral("spatiotemporal_cluster"), QStringLiteral("trajectory_cluster"),
        QStringLiteral("time_series_forecast"), QStringLiteral("change_point"), QStringLiteral("time_series_anomaly")
    };
    return algorithms.contains(algorithmId);
}

static const char *DispatchProcessingAlgorithm(const char *requestJson, int32_t *outErrCode)
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

    if (IsAdvancedSpatialAlgorithm(algorithmId)) {
        return RunAdvancedSpatialAnalysis(algorithmId, inputHandle, numericValue, textValue,
            outputPath, outputLayerName, outErrCode);
    }

    if (algorithmId == QStringLiteral("buffer") || algorithmId == QStringLiteral("overlay:buffer") ||
        algorithmId == QStringLiteral("pairwise_buffer")) {
        return BufferLayer(inputHandle, numericValue, outputPath.constData(), outputLayerName.constData(),
            outErrCode);
    }
    if (algorithmId == QStringLiteral("advanced_buffer") ||
        algorithmId == QStringLiteral("cartographic_mask") ||
        algorithmId == QStringLiteral("cartogram")) {
        return AdvancedBufferLayer(inputHandle, numericValue, textValue.constData(),
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("simplify") ||
        algorithmId == QStringLiteral("cartography:generalization") ||
        algorithmId == QStringLiteral("building_simplify")) {
        return SimplifyLayer(inputHandle, numericValue, outputPath.constData(), outputLayerName.constData(),
            outErrCode);
    }
    if (algorithmId == QStringLiteral("dissolve") || algorithmId == QStringLiteral("pairwise_dissolve") ||
        algorithmId == QStringLiteral("road_merge")) {
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
    if (algorithmId == QStringLiteral("feature_to_point") ||
        algorithmId == QStringLiteral("geometry:feature_to_point") ||
        algorithmId == QStringLiteral("label_to_annotation") ||
        algorithmId == QStringLiteral("tile_annotation")) {
        return FeatureToPointLayer(inputHandle, numericValue > 0.0, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("polygon_to_line") ||
        algorithmId == QStringLiteral("geometry:polygon_to_line") ||
        algorithmId == QStringLiteral("feature_to_line") ||
        algorithmId == QStringLiteral("feature_stroke")) {
        return PolygonToLineLayer(inputHandle, outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("feature_to_polygon") ||
        algorithmId == QStringLiteral("geometry:feature_to_polygon")) {
        return FeatureToPolygonLayer(inputHandle, outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("vertices_to_points") ||
        algorithmId == QStringLiteral("geometry:vertices_to_points")) {
        return VerticesToPointsLayer(inputHandle, outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("points_to_line") ||
        algorithmId == QStringLiteral("geometry:points_to_line")) {
        return PointsToLineLayer(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("densify") ||
        algorithmId == QStringLiteral("geometry:densify")) {
        return TransformGeometryLayer(inputHandle, GeometryTransformMode::Densify, numericValue,
            textValue.constData(), outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("smooth") ||
        algorithmId == QStringLiteral("geometry:smooth")) {
        return TransformGeometryLayer(inputHandle, GeometryTransformMode::Smooth, numericValue,
            textValue.constData(), outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("remove_holes") ||
        algorithmId == QStringLiteral("geometry:remove_holes")) {
        return TransformGeometryLayer(inputHandle, GeometryTransformMode::RemoveHoles, numericValue,
            textValue.constData(), outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("snap") || algorithmId == QStringLiteral("integrate") ||
        algorithmId == QStringLiteral("pairwise_integrate")) {
        return SnapOutputLayer(inputHandle, overlayHandle, numericValue, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("extend_trim_line")) {
        return GeometryCleanupLayer(inputHandle, GeometryCleanupMode::ExtendLine, numericValue,
            textValue.constData(), outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("split_line_at_point")) {
        return SplitLineAtPointLayer(inputHandle, overlayHandle, numericValue,
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("remove_fragments")) {
        return GeometryCleanupLayer(inputHandle, GeometryCleanupMode::RemoveFragments, numericValue,
            textValue.constData(), outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("unify_direction")) {
        return GeometryCleanupLayer(inputHandle, GeometryCleanupMode::UnifyDirection, numericValue,
            textValue.constData(), outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("aggregate_polygons")) {
        return AggregatePolygonsLayer(inputHandle, numericValue, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("eliminate")) {
        return EliminatePolygonsLayer(inputHandle, numericValue, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("centerline")) {
        return CenterlineLayer(inputHandle, outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("fishnet")) {
        return SamplingGridLayer(inputHandle, SamplingGridMode::Fishnet, numericValue,
            textValue.constData(), outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("hexagon_grid")) {
        return SamplingGridLayer(inputHandle, SamplingGridMode::Hexagon, numericValue,
            textValue.constData(), outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("random_points")) {
        return SamplingGridLayer(inputHandle, SamplingGridMode::RandomPoints, numericValue,
            textValue.constData(), outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("regular_points")) {
        return SamplingGridLayer(inputHandle, SamplingGridMode::RegularPoints, numericValue,
            textValue.constData(), outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("voronoi") || algorithmId == QStringLiteral("vector:voronoi")) {
        return VoronoiLayer(inputHandle, numericValue, outputPath.constData(), outputLayerName.constData(),
            outErrCode);
    }
    if (algorithmId == QStringLiteral("tin") || algorithmId == QStringLiteral("terrain:tin")) {
        return TinLayer(inputHandle, numericValue, outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("kernel_density") ||
        algorithmId == QStringLiteral("density:kernel_density") ||
        algorithmId == QStringLiteral("spatialanalyst:kernel_density")) {
        return KernelDensityLayer(inputHandle, numericValue, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("point_density") ||
        algorithmId == QStringLiteral("density:point_density") ||
        algorithmId == QStringLiteral("spatialanalyst:point_density")) {
        return PointDensityLayer(inputHandle, numericValue, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("line_density") ||
        algorithmId == QStringLiteral("density:line_density") ||
        algorithmId == QStringLiteral("spatialanalyst:line_density")) {
        return LineDensityLayer(inputHandle, numericValue, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("idw") ||
        algorithmId == QStringLiteral("dsm") ||
        algorithmId == QStringLiteral("dtm") ||
        algorithmId == QStringLiteral("interpolation:idw") ||
        algorithmId == QStringLiteral("spatialanalyst:idw")) {
        return IdwInterpolationLayer(inputHandle, numericValue, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("raster_slope") ||
        algorithmId == QStringLiteral("terrain:slope")) {
        return RasterTerrainAnalysisLayer(inputHandle, false, numericValue, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("raster_aspect") ||
        algorithmId == QStringLiteral("terrain:aspect")) {
        return RasterTerrainAnalysisLayer(inputHandle, true, numericValue, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("raster_reclassify") ||
        algorithmId == QStringLiteral("raster:reclassify")) {
        return RasterReclassifyLayer(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("chm") || algorithmId == QStringLiteral("terrain:chm")) {
        return SurfaceRasterAnalysisLayer(inputHandle, overlayHandle, SurfaceRasterMode::CanopyHeight, 0.0,
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("earthwork") || algorithmId == QStringLiteral("terrain:earthwork")) {
        return SurfaceRasterAnalysisLayer(inputHandle, overlayHandle, SurfaceRasterMode::Earthwork, numericValue,
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("surface_area") || algorithmId == QStringLiteral("terrain:surface_area")) {
        return SurfaceRasterAnalysisLayer(inputHandle, overlayHandle, SurfaceRasterMode::SurfaceArea, numericValue,
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("terrain_profile") || algorithmId == QStringLiteral("terrain:profile")) {
        return RasterProfileLayer(inputHandle, static_cast<int>(numericValue), textValue.constData(),
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("line_of_sight") || algorithmId == QStringLiteral("visibility:line_of_sight")) {
        return RasterLineOfSightLayer(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("viewshed") || algorithmId == QStringLiteral("visibility:viewshed")) {
        return RasterViewshedLayer(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("skyline") || algorithmId == QStringLiteral("visibility:skyline")) {
        return RasterSkylineLayer(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("nearest_neighbor") ||
        algorithmId == QStringLiteral("vector:nearest") ||
        algorithmId == QStringLiteral("symbol_conflict")) {
        return NearestNeighborLayer(inputHandle, overlayHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("near")) {
        return NearLayer(inputHandle, overlayHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("generate_near_table") ||
        algorithmId == QStringLiteral("distance_matrix")) {
        QStringList nearOptions = QString::fromUtf8(textValue).split(';');
        int neighborCount = static_cast<int>(numericValue);
        double maximumDistance = nearOptions.value(0, QStringLiteral("0")).toDouble();
        return GenerateNearTableLayer(inputHandle, overlayHandle, neighborCount, maximumDistance,
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("point_distance")) {
        return GenerateNearTableLayer(inputHandle, overlayHandle, static_cast<int>(numericValue), 0.0,
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("shortest_connection")) {
        return GenerateNearTableLayer(inputHandle, overlayHandle, 1, 0.0,
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("summary_statistics") ||
        algorithmId == QStringLiteral("frequency") ||
        algorithmId == QStringLiteral("unique_values") ||
        algorithmId == QStringLiteral("group_statistics") ||
        algorithmId == QStringLiteral("crosstab_pivot") ||
        algorithmId == QStringLiteral("statistics_chart")) {
        return SummaryStatisticsLayer(inputHandle, textValue.constData(),
            algorithmId == QStringLiteral("statistics_chart"), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("polygon_neighbors")) {
        return PolygonNeighborsLayer(inputHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("xy_table_to_points") ||
        algorithmId == QStringLiteral("data:xy_table_to_points")) {
        return XYTableToPoints(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("portable_project") ||
        algorithmId == QStringLiteral("project:portable_package")) {
        return ExportPortableProjectPackage(textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("layout_atlas") ||
        algorithmId == QStringLiteral("layout:atlas")) {
        return ExportLayoutAtlas(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("repair") || algorithmId == QStringLiteral("data:repair")) {
        return RepairLayer(inputHandle, outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("quality_check") ||
        algorithmId == QStringLiteral("quality:check")) {
        return QualityCheckLayer(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("extract_by_expression") ||
        algorithmId == QStringLiteral("select") || algorithmId == QStringLiteral("table_select")) {
        return ExtractByExpressionLayer(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("split_by_attributes")) {
        return SplitByAttributesLayer(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("extract_by_extent")) {
        return ExtractByExtentLayer(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("extract_by_time")) {
        return ExtractByTimeLayer(inputHandle, textValue.constData(), outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("extract_by_location") ||
        algorithmId == QStringLiteral("overlay:select_by_location")) {
        return ExtractByLocationLayer(inputHandle, overlayHandle, static_cast<int32_t>(numericValue),
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("clip") || algorithmId == QStringLiteral("data:clip") ||
        algorithmId == QStringLiteral("pairwise_clip") ||
        algorithmId == QStringLiteral("extract_by_mask")) {
        return ClipLayer(inputHandle, overlayHandle, outputPath.constData(), outputLayerName.constData(),
            outErrCode);
    }
    if (algorithmId == QStringLiteral("advanced_clip")) {
        return AdvancedClipLayer(inputHandle, overlayHandle, numericValue, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("intersection") || algorithmId == QStringLiteral("split") ||
        algorithmId == QStringLiteral("pairwise_intersect") ||
        algorithmId == QStringLiteral("overlay:intersection")) {
        return IntersectionLayer(inputHandle, overlayHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("difference") || algorithmId == QStringLiteral("overlay:erase") ||
        algorithmId == QStringLiteral("pairwise_erase") ||
        algorithmId == QStringLiteral("road_conflict")) {
        return DifferenceLayer(inputHandle, overlayHandle, outputPath.constData(), outputLayerName.constData(),
            outErrCode);
    }
    if (algorithmId == QStringLiteral("symmetrical_difference")) {
        return SymmetricalDifferenceLayer(inputHandle, overlayHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("union") ||
        algorithmId == QStringLiteral("overlay:union")) {
        return UnionLayer(inputHandle, overlayHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("identity") ||
        algorithmId == QStringLiteral("overlay:identity")) {
        return IdentityLayer(inputHandle, overlayHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("update") ||
        algorithmId == QStringLiteral("overlay:update")) {
        return UpdateOverlayLayer(inputHandle, overlayHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("tabulate_intersection")) {
        return TabulateIntersectionLayer(inputHandle, overlayHandle, outputPath.constData(),
            outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("summarize_within")) {
        return SummarizeWithinLayer(inputHandle, overlayHandle, textValue.constData(),
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("spatial_join_summary") ||
        algorithmId == QStringLiteral("overlay:spatial_join")) {
        return SpatialJoinSummaryLayer(inputHandle, overlayHandle, static_cast<int32_t>(numericValue),
            outputPath.constData(), outputLayerName.constData(), outErrCode);
    }
    if (algorithmId == QStringLiteral("spatial_join")) {
        return SpatialJoinLayer(inputHandle, overlayHandle, textValue.constData(),
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
    if (algorithmId == QStringLiteral("export_format")) {
        return ExportLayerToFormat(inputHandle, outputPath.constData(), outputLayerName.constData(),
            textValue.constData(), outErrCode);
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

const char *ExecuteProcessingAlgorithm(const char *requestJson, int32_t *outErrCode)
{
    QElapsedTimer timer;
    timer.start();

    QString executionId;
    QString validationError;
    QString requestedOutputPath;
    QString requestedOutputLayerName;
    QJsonObject environment;
    if (requestJson && std::strlen(requestJson) > 0) {
        QJsonParseError requestParseError;
        QJsonDocument requestDocument = QJsonDocument::fromJson(QByteArray(requestJson), &requestParseError);
        if (requestParseError.error == QJsonParseError::NoError && requestDocument.isObject()) {
            QJsonObject requestObject = requestDocument.object();
            executionId = requestObject.value(QStringLiteral("executionId")).toString().trimmed();
            validationError = requestObject.value(QStringLiteral("validationError")).toString().trimmed();
            requestedOutputPath = requestObject.value(QStringLiteral("outputPath")).toString();
            requestedOutputLayerName = requestObject.value(QStringLiteral("outputLayerName")).toString();
            QJsonValue environmentValue = requestObject.value(QStringLiteral("environment"));
            if (environmentValue.isObject()) {
                environment = environmentValue.toObject();
            }
        }
    }
    if (executionId.isEmpty()) {
        executionId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    }
    ReportProcessingProgress(2.0, 0, "prepare");

    QJsonObject resultObject;
    if (ProcessingCancellationRequested()) {
        resultObject.insert(QStringLiteral("ok"), false);
        resultObject.insert(QStringLiteral("code"), GIS_ERR_CANCELED);
        resultObject.insert(QStringLiteral("message"), QStringLiteral("Processing canceled"));
        resultObject.insert(QStringLiteral("outputPath"), requestedOutputPath);
        resultObject.insert(QStringLiteral("outputLayerName"), requestedOutputLayerName);
        resultObject.insert(QStringLiteral("featureCount"), 0);
        if (outErrCode) {
            *outErrCode = GIS_ERR_CANCELED;
        }
    } else if (!validationError.isEmpty()) {
        resultObject.insert(QStringLiteral("ok"), false);
        resultObject.insert(QStringLiteral("code"), GIS_ERR_INVALID_PARAM);
        resultObject.insert(QStringLiteral("message"), validationError);
        resultObject.insert(QStringLiteral("outputPath"), QString());
        resultObject.insert(QStringLiteral("outputLayerName"), QString());
        resultObject.insert(QStringLiteral("featureCount"), 0);
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
    } else {
        ReportProcessingProgress(8.0, 0, "read");
        const char *rawResult = DispatchProcessingAlgorithm(requestJson, outErrCode);
        if (rawResult) {
            QJsonParseError resultParseError;
            QJsonDocument resultDocument = QJsonDocument::fromJson(QByteArray(rawResult), &resultParseError);
            if (resultParseError.error == QJsonParseError::NoError && resultDocument.isObject()) {
                resultObject = resultDocument.object();
            }
            FreeCString(const_cast<char *>(rawResult));
        }
        ReportProcessingProgress(90.0, g_processingProcessedCount, "write");
        if (ProcessingCancellationRequested()) {
            resultObject.insert(QStringLiteral("ok"), false);
            resultObject.insert(QStringLiteral("code"), GIS_ERR_CANCELED);
            resultObject.insert(QStringLiteral("message"), QStringLiteral("Processing canceled"));
            resultObject.insert(QStringLiteral("outputPath"), requestedOutputPath);
            resultObject.insert(QStringLiteral("outputLayerName"), requestedOutputLayerName);
            resultObject.insert(QStringLiteral("featureCount"), 0);
            if (outErrCode) {
                *outErrCode = GIS_ERR_CANCELED;
            }
        }
    }
    if (resultObject.isEmpty()) {
        resultObject.insert(QStringLiteral("ok"), false);
        resultObject.insert(QStringLiteral("code"), GIS_ERR_NATIVE_NOT_READY);
        resultObject.insert(QStringLiteral("message"), QStringLiteral("Processing returned an invalid result"));
        resultObject.insert(QStringLiteral("outputPath"), QString());
        resultObject.insert(QStringLiteral("outputLayerName"), QString());
        resultObject.insert(QStringLiteral("featureCount"), 0);
        if (outErrCode) {
            *outErrCode = GIS_ERR_NATIVE_NOT_READY;
        }
    }

    resultObject.insert(QStringLiteral("executionId"), executionId);
    resultObject.insert(QStringLiteral("elapsedMs"), static_cast<double>(timer.elapsed()));
    resultObject.insert(QStringLiteral("environment"), environment);

    QJsonObject messageEntry;
    bool ok = resultObject.value(QStringLiteral("ok")).toBool(false);
    messageEntry.insert(QStringLiteral("level"), ok ? QStringLiteral("info") : QStringLiteral("error"));
    messageEntry.insert(QStringLiteral("code"), resultObject.value(QStringLiteral("code")).toInt());
    messageEntry.insert(QStringLiteral("text"), resultObject.value(QStringLiteral("message")).toString());
    QJsonArray messages;
    messages.append(messageEntry);
    resultObject.insert(QStringLiteral("messages"), messages);

    QByteArray json = QJsonDocument(resultObject).toJson(QJsonDocument::Compact);
    const char *finalResult = DuplicateCString(json.toStdString());
    if (!finalResult && outErrCode) {
        *outErrCode = GIS_ERR_NATIVE_NOT_READY;
    }
    if (!g_processingWorkerActive) {
        ReportProcessingProgress(100.0, g_processingProcessedCount, "complete");
    }
    return finalResult;
}

static void SetPreparedProcessingError(char **outErrorMessage, int32_t *outErrCode,
                                       int32_t code, const std::string &message)
{
    if (outErrorMessage) {
        *outErrorMessage = DuplicateCString(message);
    }
    if (outErrCode) {
        *outErrCode = code;
    }
}

static bool CapturePreparedProcessingSourceMetadata(PreparedProcessingLayerReference &reference,
                                                     std::string &message)
{
    QFileInfo sourceInfo(FilePathFromProviderUri(QString::fromUtf8(reference.sourceUri.c_str())));
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        message = "Background processing source file does not exist";
        return false;
    }
    reference.sourceSize = sourceInfo.size();
    reference.sourceModifiedMs = sourceInfo.lastModified().toMSecsSinceEpoch();
    return true;
}

static bool CapturePreparedProcessingLayer(LayerHandle handle,
                                           PreparedProcessingLayerReference &reference,
                                           std::string &message)
{
    if (handle <= 0) {
        return true;
    }

    std::map<LayerHandle, std::unique_ptr<QgisLayerState>>::iterator vectorIt = g_layers.find(handle);
    if (vectorIt != g_layers.end() && vectorIt->second && vectorIt->second->layer) {
        QgisLayerState *state = vectorIt->second.get();
        if (state->editSessionActive || state->editCommandActive || state->layer->isModified()) {
            message = "Commit or roll back pending edits before starting background processing";
            return false;
        }
        reference.handle = handle;
        reference.sourceUri = state->filePath;
        reference.layerName = ToStdString(state->layer->name());
        reference.raster = false;
        return CapturePreparedProcessingSourceMetadata(reference, message);
    }

    std::map<LayerHandle, std::unique_ptr<QgisRasterState>>::iterator rasterIt = g_rasterLayers.find(handle);
    if (rasterIt != g_rasterLayers.end() && rasterIt->second && rasterIt->second->layer) {
        QgisRasterState *state = rasterIt->second.get();
        reference.handle = handle;
        reference.sourceUri = state->filePath;
        reference.layerName = ToStdString(state->layer->name());
        reference.raster = true;
        return CapturePreparedProcessingSourceMetadata(reference, message);
    }

    message = "Processing input layer was not found";
    return false;
}

static QString CreateProcessingTemporaryPath(const QString &finalOutputPath)
{
    QFileInfo outputInfo(finalOutputPath);
    QString suffix = outputInfo.completeSuffix();
    QString temporaryName = QStringLiteral(".") + outputInfo.completeBaseName() +
        QStringLiteral(".geonest-") + QUuid::createUuid().toString(QUuid::WithoutBraces);
    if (!suffix.isEmpty()) {
        temporaryName += QStringLiteral(".") + suffix;
    }
    return outputInfo.absoluteDir().filePath(temporaryName);
}

static QString NormalizedProcessingFilePath(const QString &path)
{
    QFileInfo fileInfo(path);
    QString canonicalPath = fileInfo.canonicalFilePath();
    if (!canonicalPath.isEmpty()) {
        return QDir::cleanPath(canonicalPath);
    }
    return QDir::cleanPath(fileInfo.absoluteFilePath());
}

static bool PreparedOutputMatchesSource(const QString &finalOutputPath,
                                        const PreparedProcessingLayerReference &reference)
{
    if (reference.handle <= 0 || reference.sourceUri.empty()) {
        return false;
    }
    QString sourcePath = FilePathFromProviderUri(QString::fromUtf8(reference.sourceUri.c_str()));
    return NormalizedProcessingFilePath(finalOutputPath) == NormalizedProcessingFilePath(sourcePath);
}

PreparedProcessingTask *PrepareProcessingTask(const char *requestJson,
                                               char **outErrorMessage,
                                               int32_t *outErrCode)
{
    if (outErrorMessage) {
        *outErrorMessage = nullptr;
    }
    if (!requestJson || std::strlen(requestJson) == 0) {
        SetPreparedProcessingError(outErrorMessage, outErrCode, GIS_ERR_INVALID_PARAM,
            "Processing request is empty");
        return nullptr;
    }

    QJsonParseError parseError;
    QJsonDocument requestDocument = QJsonDocument::fromJson(QByteArray(requestJson), &parseError);
    if (parseError.error != QJsonParseError::NoError || !requestDocument.isObject()) {
        SetPreparedProcessingError(outErrorMessage, outErrCode, GIS_ERR_INVALID_PARAM,
            "Processing request JSON is invalid");
        return nullptr;
    }

    QJsonObject requestObject = requestDocument.object();
    QString algorithmId = requestObject.value(QStringLiteral("algorithmId")).toString().trimmed().toLower();
    if (algorithmId.isEmpty()) {
        SetPreparedProcessingError(outErrorMessage, outErrCode, GIS_ERR_INVALID_PARAM,
            "Processing algorithm is empty");
        return nullptr;
    }
    if (algorithmId == QStringLiteral("portable_project") ||
        algorithmId == QStringLiteral("project:portable_package") ||
        algorithmId == QStringLiteral("layout_atlas") ||
        algorithmId == QStringLiteral("layout:atlas")) {
        SetPreparedProcessingError(outErrorMessage, outErrCode, GIS_ERR_INVALID_PARAM,
            "This algorithm requires foreground map state and cannot run in the background queue");
        return nullptr;
    }

    QString finalOutputPath = requestObject.value(QStringLiteral("outputPath")).toString().trimmed();
    if (finalOutputPath.isEmpty()) {
        SetPreparedProcessingError(outErrorMessage, outErrCode, GIS_ERR_INVALID_PARAM,
            "Processing output path is empty");
        return nullptr;
    }
    QFileInfo finalOutputInfo(finalOutputPath);
    QDir outputDirectory = finalOutputInfo.absoluteDir();
    if (!outputDirectory.exists() && !outputDirectory.mkpath(QStringLiteral("."))) {
        SetPreparedProcessingError(outErrorMessage, outErrCode, GIS_ERR_WRITE_FAILED,
            "Cannot create processing output directory");
        return nullptr;
    }

    std::unique_ptr<PreparedProcessingTask> task(new PreparedProcessingTask());
    task->requestJson = requestJson;
    task->algorithmId = ToStdString(algorithmId);
    task->finalOutputPath = ToStdString(finalOutputPath);
    task->temporaryOutputPath = ToStdString(CreateProcessingTemporaryPath(finalOutputPath));
    QJsonValue environmentValue = requestObject.value(QStringLiteral("environment"));
    if (environmentValue.isObject()) {
        task->overwriteOutput = environmentValue.toObject().value(
            QStringLiteral("overwriteOutput")).toBool(true);
    }

    LayerHandle inputHandle = requestObject.value(QStringLiteral("inputHandle")).toInt();
    LayerHandle overlayHandle = requestObject.value(QStringLiteral("overlayHandle")).toInt();
    std::string captureMessage;
    {
        std::lock_guard<std::mutex> prepareLock(g_mutex);
        if (!EnsureQgis()) {
            SetPreparedProcessingError(outErrorMessage, outErrCode, GIS_ERR_NATIVE_NOT_READY,
                "QGIS is not ready for background processing");
            return nullptr;
        }
        if (inputHandle <= 0 ||
            !CapturePreparedProcessingLayer(inputHandle, task->inputLayer, captureMessage) ||
            !CapturePreparedProcessingLayer(overlayHandle, task->overlayLayer, captureMessage)) {
            if (captureMessage.empty()) {
                captureMessage = "Processing input layer was not found";
            }
            SetPreparedProcessingError(outErrorMessage, outErrCode, GIS_ERR_LAYER_NOT_FOUND, captureMessage);
            return nullptr;
        }
        task->transformContext = QgsProject::instance()->transformContext();
    }

    if (PreparedOutputMatchesSource(finalOutputPath, task->inputLayer) ||
        PreparedOutputMatchesSource(finalOutputPath, task->overlayLayer)) {
        SetPreparedProcessingError(outErrorMessage, outErrCode, GIS_ERR_INVALID_PARAM,
            "Processing output cannot replace an input data source");
        return nullptr;
    }

    requestObject.insert(QStringLiteral("outputPath"), QString::fromUtf8(task->temporaryOutputPath.c_str()));
    task->workerRequestJson = QJsonDocument(requestObject).toJson(QJsonDocument::Compact).toStdString();
    if (outErrCode) {
        *outErrCode = GIS_OK;
    }
    return task.release();
}

static bool OpenPreparedProcessingLayer(const PreparedProcessingLayerReference &reference,
                                        std::string &message)
{
    if (reference.handle <= 0) {
        return true;
    }
    if (g_processingLayers.find(reference.handle) != g_processingLayers.end() ||
        g_processingRasterLayers.find(reference.handle) != g_processingRasterLayers.end()) {
        return true;
    }

    QString sourceUri = QString::fromUtf8(reference.sourceUri.c_str());
    QFileInfo sourceInfo(FilePathFromProviderUri(sourceUri));
    if (!sourceInfo.exists()) {
        message = "Background processing source file no longer exists";
        return false;
    }
    if ((reference.sourceSize >= 0 && sourceInfo.size() != reference.sourceSize) ||
        (reference.sourceModifiedMs >= 0 &&
         sourceInfo.lastModified().toMSecsSinceEpoch() != reference.sourceModifiedMs)) {
        message = "Background processing source changed while the task was waiting";
        return false;
    }
    QString layerName = QString::fromUtf8(reference.layerName.c_str());
    if (layerName.isEmpty()) {
        layerName = sourceInfo.baseName();
    }

    if (reference.raster) {
        std::unique_ptr<QgsRasterLayer> layer(new QgsRasterLayer(sourceUri, layerName, "gdal"));
        if (!layer->isValid()) {
            message = "Background processing could not reopen the raster source";
            return false;
        }
        std::unique_ptr<QgisRasterState> state(new QgisRasterState());
        state->handle = reference.handle;
        state->filePath = reference.sourceUri;
        state->layer = std::move(layer);
        g_processingRasterLayers[reference.handle] = std::move(state);
        return true;
    }

    std::unique_ptr<QgsVectorLayer> layer(new QgsVectorLayer(sourceUri, layerName, "ogr"));
    if (!layer->isValid()) {
        message = "Background processing could not reopen the vector source";
        return false;
    }
    std::unique_ptr<QgisLayerState> state(new QgisLayerState());
    state->handle = reference.handle;
    state->filePath = reference.sourceUri;
    state->layer = std::move(layer);
    g_processingLayers[reference.handle] = std::move(state);
    return true;
}

static void AppendUniqueProcessingArtifact(QStringList &artifacts, const QString &path)
{
    QString absolutePath = QFileInfo(path).absoluteFilePath();
    QString canonicalPath;
    if (QFileInfo::exists(absolutePath)) {
        canonicalPath = QFileInfo(absolutePath).canonicalFilePath();
    }
    for (int i = 0; i < artifacts.size(); i++) {
        QString existingPath = QFileInfo(artifacts.at(i)).absoluteFilePath();
        if (existingPath == absolutePath) {
            return;
        }
        if (!canonicalPath.isEmpty() && QFileInfo::exists(existingPath) &&
            QFileInfo(existingPath).canonicalFilePath() == canonicalPath) {
            return;
        }
    }
    artifacts.append(absolutePath);
}

static QString ProcessingOutputStem(const QFileInfo &info)
{
    QString fileName = info.fileName();
    QString suffix = info.suffix();
    if (suffix.isEmpty()) {
        return fileName;
    }
    return fileName.left(fileName.length() - suffix.length() - 1);
}

static QStringList ProcessingOutputArtifacts(const QString &path)
{
    QFileInfo outputInfo(path);
    QDir outputDirectory = outputInfo.absoluteDir();
    QString stem = ProcessingOutputStem(outputInfo);
    QString suffix = outputInfo.suffix().toLower();
    QStringList artifacts;
    AppendUniqueProcessingArtifact(artifacts, outputInfo.absoluteFilePath());

    if (suffix == QStringLiteral("shp")) {
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".shx")));
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".dbf")));
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".prj")));
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".qpj")));
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".cpg")));
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".qix")));
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".sbn")));
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".sbx")));
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".fix")));
        AppendUniqueProcessingArtifact(artifacts, outputInfo.absoluteFilePath() + QStringLiteral(".xml"));
    } else if (suffix == QStringLiteral("asc")) {
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".prj")));
        AppendUniqueProcessingArtifact(artifacts, outputInfo.absoluteFilePath() + QStringLiteral(".aux.xml"));
    } else if (suffix == QStringLiteral("gpkg")) {
        AppendUniqueProcessingArtifact(artifacts, outputInfo.absoluteFilePath() + QStringLiteral("-wal"));
        AppendUniqueProcessingArtifact(artifacts, outputInfo.absoluteFilePath() + QStringLiteral("-shm"));
    } else if (suffix == QStringLiteral("tif") || suffix == QStringLiteral("tiff")) {
        AppendUniqueProcessingArtifact(artifacts, outputInfo.absoluteFilePath() + QStringLiteral(".aux.xml"));
        AppendUniqueProcessingArtifact(artifacts, outputInfo.absoluteFilePath() + QStringLiteral(".ovr"));
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".tfw")));
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".tifw")));
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".wld")));
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".prj")));
    } else if (suffix == QStringLiteral("csv")) {
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".csvt")));
        AppendUniqueProcessingArtifact(artifacts, outputDirectory.filePath(stem + QStringLiteral(".prj")));
    }

    QStringList expectedNames;
    for (int i = 0; i < artifacts.size(); i++) {
        expectedNames.append(QFileInfo(artifacts.at(i)).fileName().toLower());
    }
    QFileInfoList existingFiles = outputDirectory.entryInfoList(
        QDir::Files | QDir::Hidden | QDir::NoSymLinks);
    for (int i = 0; i < existingFiles.size(); i++) {
        QFileInfo existingInfo = existingFiles.at(i);
        if (expectedNames.contains(existingInfo.fileName().toLower())) {
            AppendUniqueProcessingArtifact(artifacts, existingInfo.absoluteFilePath());
        }
    }
    return artifacts;
}

static void RemoveProcessingOutputArtifacts(const QString &path)
{
    QStringList artifacts = ProcessingOutputArtifacts(path);
    QFileInfo outputInfo(path);
    QString temporaryStem = ProcessingOutputStem(outputInfo);
    if (!temporaryStem.isEmpty()) {
        QFileInfoList existingFiles = outputInfo.absoluteDir().entryInfoList(
            QDir::Files | QDir::Hidden | QDir::NoSymLinks);
        for (int i = 0; i < existingFiles.size(); i++) {
            QFileInfo existingInfo = existingFiles.at(i);
            if (existingInfo.fileName().startsWith(temporaryStem, Qt::CaseSensitive)) {
                AppendUniqueProcessingArtifact(artifacts, existingInfo.absoluteFilePath());
            }
        }
    }
    for (int i = 0; i < artifacts.size(); i++) {
        if (QFileInfo::exists(artifacts.at(i))) {
            QFile::remove(artifacts.at(i));
        }
    }
}

static bool DiscoverProcessingOutputMoves(const QString &temporaryPath, const QString &finalPath,
                                          QStringList &sourceArtifacts,
                                          QStringList &targetArtifacts,
                                          std::string &message)
{
    QFileInfo temporaryInfo(temporaryPath);
    QFileInfo finalInfo(finalPath);
    QDir temporaryDirectory = temporaryInfo.absoluteDir();
    QDir finalDirectory = finalInfo.absoluteDir();
    QString temporaryStem = ProcessingOutputStem(temporaryInfo);
    QString finalStem = ProcessingOutputStem(finalInfo);
    QString temporaryMainRemainder = temporaryInfo.fileName().mid(temporaryStem.length());

    QFileInfoList existingFiles = temporaryDirectory.entryInfoList(
        QDir::Files | QDir::Hidden | QDir::NoSymLinks);
    for (int i = 0; i < existingFiles.size(); i++) {
        QFileInfo sourceInfo = existingFiles.at(i);
        QString sourceName = sourceInfo.fileName();
        if (!sourceName.startsWith(temporaryStem, Qt::CaseSensitive)) {
            continue;
        }
        QString remainder = sourceName.mid(temporaryStem.length());
        QString targetPath;
        if (remainder.compare(temporaryMainRemainder, Qt::CaseInsensitive) == 0) {
            targetPath = finalInfo.absoluteFilePath();
        } else {
            targetPath = finalDirectory.filePath(finalStem + remainder);
        }
        sourceArtifacts.append(sourceInfo.absoluteFilePath());
        targetArtifacts.append(QFileInfo(targetPath).absoluteFilePath());
    }

    QStringList targetNames;
    for (int i = 0; i < targetArtifacts.size(); i++) {
        targetNames.append(QFileInfo(targetArtifacts.at(i)).fileName().toLower());
    }
    QString finalMainName = finalInfo.fileName().toLower();
    if (!targetNames.contains(finalMainName)) {
        message = "Processing did not create its expected output";
        return false;
    }
    if (finalInfo.suffix().compare(QStringLiteral("shp"), Qt::CaseInsensitive) == 0) {
        QString lowerStem = finalStem.toLower();
        if (!targetNames.contains(lowerStem + QStringLiteral(".shx")) ||
            !targetNames.contains(lowerStem + QStringLiteral(".dbf"))) {
            message = "Processing did not create a complete Shapefile output";
            return false;
        }
    }
    return true;
}

static void RestoreProcessingBackups(const QStringList &originalPaths,
                                     const QStringList &backupPaths)
{
    for (int i = backupPaths.size() - 1; i >= 0; i--) {
        if (QFileInfo::exists(backupPaths.at(i)) && !QFileInfo::exists(originalPaths.at(i))) {
            QFile::rename(backupPaths.at(i), originalPaths.at(i));
        }
    }
}

static bool PromoteProcessingOutput(const QString &temporaryPath, const QString &finalPath,
                                    bool overwriteOutput, std::string &message)
{
    QStringList sourceArtifacts;
    QStringList targetArtifacts;
    if (!DiscoverProcessingOutputMoves(temporaryPath, finalPath, sourceArtifacts, targetArtifacts, message)) {
        RemoveProcessingOutputArtifacts(temporaryPath);
        return false;
    }

    QStringList finalArtifacts = ProcessingOutputArtifacts(finalPath);
    for (int i = 0; i < targetArtifacts.size(); i++) {
        AppendUniqueProcessingArtifact(finalArtifacts, targetArtifacts.at(i));
    }
    if (!overwriteOutput) {
        for (int i = 0; i < finalArtifacts.size(); i++) {
            if (QFileInfo::exists(finalArtifacts.at(i))) {
                message = "Processing output already exists and overwrite is disabled";
                RemoveProcessingOutputArtifacts(temporaryPath);
                return false;
            }
        }
    }

    QString backupToken = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QStringList originalPaths;
    QStringList backupPaths;
    for (int i = 0; i < finalArtifacts.size(); i++) {
        QString originalPath = finalArtifacts.at(i);
        if (!QFileInfo::exists(originalPath)) {
            continue;
        }
        QString backupPath = originalPath + QStringLiteral(".geonest-backup-") + backupToken;
        if (!QFile::rename(originalPath, backupPath)) {
            RestoreProcessingBackups(originalPaths, backupPaths);
            RemoveProcessingOutputArtifacts(temporaryPath);
            message = "Cannot preserve the existing processing output";
            return false;
        }
        originalPaths.append(originalPath);
        backupPaths.append(backupPath);
    }

    QStringList movedTargets;
    for (int i = 0; i < sourceArtifacts.size(); i++) {
        QString sourcePath = sourceArtifacts.at(i);
        QString targetPath = targetArtifacts.at(i);
        if (!QFile::rename(sourcePath, targetPath)) {
            for (int movedIndex = movedTargets.size() - 1; movedIndex >= 0; movedIndex--) {
                QFile::remove(movedTargets.at(movedIndex));
            }
            RestoreProcessingBackups(originalPaths, backupPaths);
            RemoveProcessingOutputArtifacts(temporaryPath);
            message = "Cannot promote the temporary processing output";
            return false;
        }
        movedTargets.append(targetPath);
    }

    for (int i = 0; i < backupPaths.size(); i++) {
        QFile::remove(backupPaths.at(i));
    }
    return true;
}

class PreparedProcessingExecutionScope {
public:
    PreparedProcessingExecutionScope(PreparedProcessingTask *task, const ProcessingCallbacks *callbacks)
    {
        g_processingWorkerActive = true;
        g_processingCallbacks = callbacks;
        g_processingTransformContext = task ? &task->transformContext : nullptr;
        g_processingProcessedCount = 0;
        g_processingProgress = 0.0;
        g_processingLayers.clear();
        g_processingRasterLayers.clear();
    }

    ~PreparedProcessingExecutionScope()
    {
        g_processingLayers.clear();
        g_processingRasterLayers.clear();
        g_processingCallbacks = nullptr;
        g_processingTransformContext = nullptr;
        g_processingProcessedCount = 0;
        g_processingProgress = 0.0;
        g_processingWorkerActive = false;
    }
};

static QJsonObject ProcessingFailureObject(PreparedProcessingTask *task, int32_t code,
                                           const QString &message)
{
    QJsonObject resultObject;
    resultObject.insert(QStringLiteral("ok"), false);
    resultObject.insert(QStringLiteral("code"), code);
    resultObject.insert(QStringLiteral("message"), message);
    resultObject.insert(QStringLiteral("outputPath"),
        task ? QString::fromUtf8(task->finalOutputPath.c_str()) : QString());
    resultObject.insert(QStringLiteral("outputLayerName"), QString());
    resultObject.insert(QStringLiteral("featureCount"), 0);
    return resultObject;
}

const char *RunPreparedProcessingTask(PreparedProcessingTask *task,
                                      const ProcessingCallbacks *callbacks,
                                      int32_t *outErrCode)
{
    if (!task) {
        if (outErrCode) {
            *outErrCode = GIS_ERR_INVALID_PARAM;
        }
        return DuplicateCString("{\"ok\":false,\"code\":6,\"message\":\"Prepared processing task is null\","
            "\"outputPath\":\"\",\"outputLayerName\":\"\",\"featureCount\":0,\"elapsedMs\":0}");
    }

    QElapsedTimer timer;
    timer.start();
    PreparedProcessingExecutionScope executionScope(task, callbacks);
    ReportProcessingProgress(1.0, 0, "prepare");

    QJsonObject resultObject;
    int32_t resultCode = GIS_OK;
    std::string openMessage;
    if (ProcessingCancellationRequested()) {
        resultCode = GIS_ERR_CANCELED;
        resultObject = ProcessingFailureObject(task, resultCode, QStringLiteral("Processing canceled"));
    } else if (!OpenPreparedProcessingLayer(task->inputLayer, openMessage) ||
        !OpenPreparedProcessingLayer(task->overlayLayer, openMessage)) {
        resultCode = GIS_ERR_INVALID_FORMAT;
        resultObject = ProcessingFailureObject(task, resultCode, QString::fromUtf8(openMessage.c_str()));
    } else {
        ReportProcessingProgress(5.0, 0, "read");
        const char *rawResult = ExecuteProcessingAlgorithm(task->workerRequestJson.c_str(), &resultCode);
        if (rawResult) {
            QJsonParseError resultParseError;
            QJsonDocument resultDocument = QJsonDocument::fromJson(QByteArray(rawResult), &resultParseError);
            if (resultParseError.error == QJsonParseError::NoError && resultDocument.isObject()) {
                resultObject = resultDocument.object();
            }
            FreeCString(const_cast<char *>(rawResult));
        }
        if (resultObject.isEmpty()) {
            resultCode = GIS_ERR_NATIVE_NOT_READY;
            resultObject = ProcessingFailureObject(task, resultCode,
                QStringLiteral("Background processing returned an invalid result"));
        }
    }

    bool canceled = ProcessingCancellationRequested() || resultCode == GIS_ERR_CANCELED;
    bool succeeded = resultObject.value(QStringLiteral("ok")).toBool(false) && !canceled;
    QString temporaryPath = QString::fromUtf8(task->temporaryOutputPath.c_str());
    QString finalPath = QString::fromUtf8(task->finalOutputPath.c_str());
    if (canceled) {
        resultCode = GIS_ERR_CANCELED;
        RemoveProcessingOutputArtifacts(temporaryPath);
        resultObject.insert(QStringLiteral("ok"), false);
        resultObject.insert(QStringLiteral("code"), resultCode);
        resultObject.insert(QStringLiteral("message"), QStringLiteral("Processing canceled"));
        resultObject.insert(QStringLiteral("featureCount"), 0);
    } else if (succeeded) {
        ReportProcessingProgress(94.0, g_processingProcessedCount, "finalize");
        std::string promoteMessage;
        if (!PromoteProcessingOutput(temporaryPath, finalPath, task->overwriteOutput, promoteMessage)) {
            resultCode = GIS_ERR_WRITE_FAILED;
            resultObject.insert(QStringLiteral("ok"), false);
            resultObject.insert(QStringLiteral("code"), resultCode);
            resultObject.insert(QStringLiteral("message"), QString::fromUtf8(promoteMessage.c_str()));
            resultObject.insert(QStringLiteral("featureCount"), 0);
        } else {
            resultCode = GIS_OK;
            task->outputCommitted = true;
        }
    } else {
        RemoveProcessingOutputArtifacts(temporaryPath);
        resultCode = resultObject.value(QStringLiteral("code")).toInt(resultCode);
    }

    resultObject.insert(QStringLiteral("outputPath"), finalPath);
    resultObject.insert(QStringLiteral("elapsedMs"), static_cast<double>(timer.elapsed()));
    QJsonObject messageEntry;
    messageEntry.insert(QStringLiteral("level"), resultCode == GIS_OK ? QStringLiteral("info") :
        (resultCode == GIS_ERR_CANCELED ? QStringLiteral("warning") : QStringLiteral("error")));
    messageEntry.insert(QStringLiteral("code"), resultCode);
    messageEntry.insert(QStringLiteral("text"), resultObject.value(QStringLiteral("message")).toString());
    QJsonArray messages;
    messages.append(messageEntry);
    resultObject.insert(QStringLiteral("messages"), messages);

    if (outErrCode) {
        *outErrCode = resultCode;
    }
    if (resultCode == GIS_OK) {
        ReportProcessingProgress(100.0, g_processingProcessedCount, "complete");
    } else {
        ReportProcessingProgress(g_processingProgress, g_processingProcessedCount,
            resultCode == GIS_ERR_CANCELED ? "canceled" : "failed");
    }
    return DuplicateCString(QJsonDocument(resultObject).toJson(QJsonDocument::Compact).toStdString());
}

void FreePreparedProcessingTask(PreparedProcessingTask *task)
{
    if (task && !task->outputCommitted && !task->temporaryOutputPath.empty()) {
        RemoveProcessingOutputArtifacts(QString::fromUtf8(task->temporaryOutputPath.c_str()));
    }
    delete task;
}

const char *ApplyVectorStyle(LayerHandle handle, int32_t rendererMode, const char *rendererField,
                             int32_t colorRamp, int32_t linePattern, int32_t fillPattern,
                             const char *pointColor, const char *lineColor, const char *fillColor,
                             const char *strokeColor, double lineWidth, double pointRadius,
                             double opacity, const char *symbolName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    } else if (rendererMode == 3 && !fieldName.isEmpty()) {
        std::string expressionMessage;
        if (!ValidateQgisExpression(layer, fieldName, expressionMessage)) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, expressionMessage, "", "",
                static_cast<int32_t>(layer->featureCount()), outErrCode);
        }
        applied = BuildExpressionRuleRenderer(layer, fieldName, colorRamp, linePattern, fillPattern, pointColor,
            lineColor, fillColor, strokeColor, lineWidth, pointRadius, opacity);
        if (!applied) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Failed to create QGIS expression renderer", "",
                "", static_cast<int32_t>(layer->featureCount()), outErrCode);
        }
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

const char *ImportQmlStyle(LayerHandle handle, const char *qmlPath, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!qmlPath || std::strlen(qmlPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "QML style path is empty", "", "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Vector layer not found", "", "", 0, outErrCode);
    }
    QString path = QString::fromUtf8(qmlPath);
    if (!QFileInfo::exists(path)) {
        return MakeProcessResult(false, GIS_ERR_FILE_NOT_FOUND, "QML style file not found", "", "", 0, outErrCode);
    }
    bool resultFlag = false;
    QString message = state->layer->loadNamedStyle(path, resultFlag, false, QgsMapLayer::AllStyleCategories);
    if (!resultFlag) {
        std::string text = "QML style import failed";
        if (!message.isEmpty()) {
            text += ": ";
            text += ToStdString(message);
        }
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT, text, "", "", 0, outErrCode);
    }
    state->layer->triggerRepaint();
    return MakeProcessResult(true, GIS_OK, "QML style imported", "", "",
        static_cast<int32_t>(state->layer->featureCount()), outErrCode);
}

const char *ExportQmlStyle(LayerHandle handle, const char *qmlPath, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!qmlPath || std::strlen(qmlPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "QML style path is empty", "", "", 0, outErrCode);
    }
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Vector layer not found", "", "", 0, outErrCode);
    }
    QString path = QString::fromUtf8(qmlPath);
    QFileInfo fileInfo(path);
    QDir parentDir = fileInfo.absoluteDir();
    if (!parentDir.exists() && !parentDir.mkpath(QStringLiteral("."))) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Cannot create QML style directory", "", "", 0,
            outErrCode);
    }
    bool resultFlag = false;
    QString message = state->layer->saveNamedStyle(path, resultFlag, QgsMapLayer::AllStyleCategories);
    if (!resultFlag) {
        std::string text = "QML style export failed";
        if (!message.isEmpty()) {
            text += ": ";
            text += ToStdString(message);
        }
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, text, "", "", 0, outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "QML style exported", qmlPath, fileInfo.baseName().toUtf8().constData(),
        static_cast<int32_t>(state->layer->featureCount()), outErrCode);
}

const char *ApplyVectorLabeling(LayerHandle handle, bool enabled, const char *labelField,
                                double labelSize, const char *labelColor, bool halo,
                                bool avoidance, double minScale, double maxScale,
                                int32_t *outErrCode)
{
    ProcessingStateLock lock;
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

    QString fieldName = QString::fromUtf8(labelField ? labelField : "").trimmed();
    bool labelIsExpression = fieldName.startsWith(QStringLiteral("expr:"), Qt::CaseInsensitive);
    QString labelSource = labelIsExpression ? fieldName.mid(5).trimmed() : fieldName;
    if (labelIsExpression) {
        std::string expressionMessage;
        if (!ValidateQgisExpression(layer, labelSource, expressionMessage)) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, expressionMessage, "", "",
                static_cast<int32_t>(layer->featureCount()), outErrCode);
        }
    } else if (labelSource.isEmpty() || layer->fields().indexOf(labelSource) < 0) {
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
    settings.fieldName = labelSource;
    settings.isExpression = labelIsExpression;
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
    ProcessingStateLock lock;
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

const char *RenderMapView(const char *outputPath, double minX, double minY, double maxX, double maxY,
                          int32_t width, int32_t height, const char *visibleLayerHandles,
                          const char *destinationCrs, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Output path is empty", "", "", 0, outErrCode);
    }

    int32_t outWidth = width > 0 ? width : 800;
    int32_t outHeight = height > 0 ? height : 600;
    if (outWidth < 32) {
        outWidth = 32;
    }
    if (outHeight < 32) {
        outHeight = 32;
    }

    QList<QgsMapLayer *> layers;
    QgsRectangle combinedExtent;
    QgsCoordinateReferenceSystem renderCrs;
    const char *restrictedHandles = (visibleLayerHandles && std::strlen(visibleLayerHandles) > 0)
        ? visibleLayerHandles : nullptr;
    if (!CollectMapLayers(layers, combinedExtent, renderCrs, restrictedHandles)) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "No visible QGIS layers to render", outputPath, "",
            0, outErrCode);
    }

    if (destinationCrs && std::strlen(destinationCrs) > 0) {
        QgsCoordinateReferenceSystem requestedCrs(QString::fromUtf8(destinationCrs));
        if (requestedCrs.isValid()) {
            renderCrs = requestedCrs;
        }
    }

    QgsRectangle extent(minX, minY, maxX, maxY);
    if (extent.isNull() || extent.isEmpty()) {
        extent = combinedExtent;
    }

    QImage mapImage = RenderMapImage(layers, extent, renderCrs, outWidth, outHeight);
    if (mapImage.isNull()) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS map rendering returned an empty image",
            outputPath, "", 0, outErrCode);
    }

    QFileInfo outputInfo(QString::fromUtf8(outputPath));
    QDir parentDir = outputInfo.absoluteDir();
    if (!parentDir.exists()) {
        parentDir.mkpath(QStringLiteral("."));
    }
    bool ok = mapImage.save(QString::fromUtf8(outputPath), "PNG");
    if (!ok) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to write map view image", outputPath, "", 0,
            outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Map view rendered through QGIS map renderer", outputPath, "",
        layers.size(), outErrCode);
}

const char *ExportMapLayout(const char *title, const char *outputPath, const char *format,
                            bool showLegend, bool showScaleBar, bool showNorthArrow,
                            bool showGrid, int32_t width, int32_t height,
                            const char *legendTitle, const char *scaleText, const char *footerText,
                            int32_t basemapMode, const char *basemapLabel,
                            const char *basemapImagePath, const char *visibleLayerHandles, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    if (!outputPath || std::strlen(outputPath) == 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Output path is empty", "", "", 0, outErrCode);
    }
    int32_t exportBasemapMode = StaticExportBasemapMode(basemapMode);
    int32_t outWidth = std::max(800, width > 0 ? width : 1600);
    int32_t outHeight = std::max(600, height > 0 ? height : 1100);
    int32_t mapWidth = std::max(32, outWidth - 64);
    int32_t mapHeight = std::max(32, outHeight - 144);
    QList<QgsMapLayer *> layers;
    QgsRectangle extent;
    QgsCoordinateReferenceSystem crs;
    bool hasLayers = CollectMapLayers(layers, extent, crs, visibleLayerHandles);
    bool usingDefaultXyzExtent = false;
    if (!hasLayers && !IsXyzExportBasemap(exportBasemapMode)) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "No visible QGIS layers to export", outputPath, "",
            0, outErrCode);
    }

    if (IsXyzExportBasemap(exportBasemapMode)) {
        QgsCoordinateReferenceSystem webMercator(QStringLiteral("EPSG:3857"));
        if (!webMercator.isValid()) {
            return MakeProcessResult(false, GIS_ERR_NATIVE_NOT_READY, "EPSG:3857 is unavailable for XYZ export",
                outputPath, "", 0, outErrCode);
        }
        crs = webMercator;
        if (hasLayers) {
            if (!CombinedExtentInCrs(layers, crs, extent)) {
                return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
                    "Visible layer extents cannot be transformed to EPSG:3857", outputPath, "", 0, outErrCode);
            }
        } else {
            extent = DefaultXyzExportExtent(mapWidth, mapHeight);
            usingDefaultXyzExtent = true;
        }
    }

    QImage mapImage(mapWidth, mapHeight, QImage::Format_ARGB32_Premultiplied);
    mapImage.fill(QColor(255, 255, 255, 0));
    if (hasLayers) {
        mapImage = RenderMapImage(layers, extent, crs, mapWidth, mapHeight);
        if (mapImage.isNull()) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS map rendering returned an empty image",
                outputPath, "", 0, outErrCode);
        }
    }

    QImage onlineBasemap;
    QString attribution;
    bool hasStaticBasemapImage = basemapImagePath && std::strlen(basemapImagePath) > 0;
    if (hasStaticBasemapImage) {
        if (!onlineBasemap.load(QString::fromUtf8(basemapImagePath)) || onlineBasemap.isNull()) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to read Map Kit static basemap image",
                outputPath, "", 0, outErrCode);
        }
        attribution = QStringLiteral("© Huawei Map Kit / Petal Maps");
    } else if (IsXyzExportBasemap(exportBasemapMode)) {
        QString basemapError;
        if (!RenderXyzBasemap(extent, mapWidth, mapHeight, exportBasemapMode, onlineBasemap, attribution,
            basemapError)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, ToStdString(basemapError), outputPath, "", 0,
                outErrCode);
        }
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
            footerLabelText, showLegend, showScaleBar, showNorthArrow, showGrid, outWidth, outHeight, exportBasemapMode,
            basemapLabelText, onlineBasemap, attribution, true, false, false);
        bool vectorRendered = !hasLayers || RenderMapVectorToPainter(painter, layers, extent, crs,
            QRect(32, 82, mapWidth, mapHeight));
        DrawLayoutDecorations(painter, mapImage, layers, titleText, legendTitleText, scaleLabelText,
            footerLabelText, showLegend, showScaleBar, showNorthArrow, showGrid, outWidth, outHeight, exportBasemapMode,
            basemapLabelText, onlineBasemap, attribution, false, false, true);
        painter.end();
        ok = vectorRendered;
    } else if (formatText == QStringLiteral("svg")) {
        QSvgGenerator generator;
        generator.setFileName(QString::fromUtf8(outputPath));
        generator.setSize(QSize(outWidth, outHeight));
        generator.setViewBox(QRect(0, 0, outWidth, outHeight));
        generator.setResolution(144);
        QPainter painter(&generator);
        DrawLayoutDecorations(painter, mapImage, layers, titleText, legendTitleText, scaleLabelText,
            footerLabelText, showLegend, showScaleBar, showNorthArrow, showGrid, outWidth, outHeight, exportBasemapMode,
            basemapLabelText, onlineBasemap, attribution, true, false, false);
        bool vectorRendered = !hasLayers || RenderMapVectorToPainter(painter, layers, extent, crs,
            QRect(32, 82, mapWidth, mapHeight));
        DrawLayoutDecorations(painter, mapImage, layers, titleText, legendTitleText, scaleLabelText,
            footerLabelText, showLegend, showScaleBar, showNorthArrow, showGrid, outWidth, outHeight, exportBasemapMode,
            basemapLabelText, onlineBasemap, attribution, false, false, true);
        painter.end();
        ok = vectorRendered;
    } else {
        QImage layoutImage(outWidth, outHeight, QImage::Format_ARGB32_Premultiplied);
        QPainter painter(&layoutImage);
        DrawLayoutDecorations(painter, mapImage, layers, titleText, legendTitleText, scaleLabelText,
            footerLabelText, showLegend, showScaleBar, showNorthArrow, showGrid, outWidth, outHeight, exportBasemapMode,
            basemapLabelText, onlineBasemap, attribution, true, true, true);
        painter.end();
        ok = layoutImage.save(QString::fromUtf8(outputPath), "PNG");
    }

    if (!ok) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to write layout output", outputPath, "", 0,
            outErrCode);
    }
    std::string message = "Map layout exported through QGIS map renderer";
    if (hasStaticBasemapImage) {
        message += "; Map Kit static basemap image used";
    } else if (IsXyzExportBasemap(exportBasemapMode)) {
        message += usingDefaultXyzExtent
            ? "; XYZ basemap used the default Shanxi extent because no business layer was visible"
            : "; XYZ basemap used the combined visible-layer extent in EPSG:3857";
    }
    return MakeProcessResult(true, GIS_OK, message, outputPath,
        titleText.toStdString(), layers.size(), outErrCode);
}

const char *BeginEditSession(LayerHandle handle, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    if (state->editSessionActive && layer->isEditable()) {
        return MakeProcessResult(true, GIS_OK, "Edit session is already active", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (layer->isEditable()) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Layer already has an unmanaged edit buffer", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!layer->startEditing()) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS provider is not editable", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QUndoStack *undoStack = layer->undoStack();
    if (undoStack) {
        undoStack->clear();
    }
    state->editSessionActive = true;
    state->editCommandActive = false;
    return MakeProcessResult(true, GIS_OK, "Edit session started", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *CommitEditSession(LayerHandle handle, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    if (!state->editSessionActive || !layer->isEditable()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "No active edit session", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (state->editCommandActive) {
        layer->destroyEditCommand();
        state->editCommandActive = false;
    }
    if (!layer->commitChanges()) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, CommitErrors(layer), "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    state->editSessionActive = false;
    QUndoStack *undoStack = layer->undoStack();
    if (undoStack) {
        undoStack->clear();
    }
    layer->updateFields();
    layer->updateExtents();
    layer->triggerRepaint();
    return MakeProcessResult(true, GIS_OK, "Edit session committed", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *RollbackEditSession(LayerHandle handle, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    if (!state->editSessionActive || !layer->isEditable()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "No active edit session", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (state->editCommandActive) {
        layer->destroyEditCommand();
        state->editCommandActive = false;
    }
    if (!layer->rollBack()) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS provider rollback failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    state->editSessionActive = false;
    layer->updateFields();
    layer->updateExtents();
    layer->triggerRepaint();
    return MakeProcessResult(true, GIS_OK, "Edit session rolled back", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *UndoEdit(LayerHandle handle, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QUndoStack *undoStack = layer->undoStack();
    if (!state->editSessionActive || !layer->isEditable() || !undoStack || !undoStack->canUndo()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "No edit command to undo", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    undoStack->undo();
    layer->updateFields();
    layer->updateExtents();
    layer->triggerRepaint();
    return MakeProcessResult(true, GIS_OK, "Edit command undone", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *RedoEdit(LayerHandle handle, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QUndoStack *undoStack = layer->undoStack();
    if (!state->editSessionActive || !layer->isEditable() || !undoStack || !undoStack->canRedo()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "No edit command to redo", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    undoStack->redo();
    layer->updateFields();
    layer->updateExtents();
    layer->triggerRepaint();
    return MakeProcessResult(true, GIS_OK, "Edit command redone", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

bool IsEditing(LayerHandle handle)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    return state && state->layer && state->editSessionActive && state->layer->isEditable();
}

bool HasPendingEdits(LayerHandle handle)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    return state && state->layer && state->editSessionActive && state->layer->isModified();
}

bool CanUndo(LayerHandle handle)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    QUndoStack *undoStack = state && state->layer ? state->layer->undoStack() : nullptr;
    return state && state->editSessionActive && state->layer->isEditable() && undoStack && undoStack->canUndo();
}

bool CanRedo(LayerHandle handle)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    QUndoStack *undoStack = state && state->layer ? state->layer->undoStack() : nullptr;
    return state && state->editSessionActive && state->layer->isEditable() && undoStack && undoStack->canRedo();
}

const char *AddFeature(LayerHandle handle, int32_t geometryType, const char *coordsText, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    if (MapGeometryType(layer->geometryType()) != geometryType) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Geometry type does not match active layer",
            "", "", static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    std::vector<ParsedCoordinate> points = ParseCoordText(coordsText);
    QgsGeometry geometry = GeometryFromPoints(geometryType, points, layer->wkbType());
    if (geometry.isNull() || geometry.isEmpty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Invalid sketch geometry", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    std::string message;
    if (!BeginEdit(state, QStringLiteral("Add feature"), message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    QgsFeature feature;
    feature.setFields(layer->fields(), true);
    feature.setGeometry(geometry);
    if (!layer->addFeature(feature)) {
        CancelEdit(state);
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS addFeature failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!CommitEdit(state, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Feature added through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *DeleteFeature(LayerHandle handle, int64_t fid, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    if (!BeginEdit(state, QStringLiteral("Delete feature"), message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!layer->deleteFeature(static_cast<QgsFeatureId>(fid))) {
        CancelEdit(state);
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS deleteFeature failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!CommitEdit(state, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Feature deleted through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *MoveFeatureNode(LayerHandle handle, int64_t fid, int32_t partIndex, int32_t pointIndex,
                            double x, double y, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    if (!BeginEdit(state, QStringLiteral("Move feature node"), message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!layer->changeGeometry(static_cast<QgsFeatureId>(fid), geometry)) {
        CancelEdit(state);
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS changeGeometry failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!CommitEdit(state, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Node moved through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *DeleteFeatureNode(LayerHandle handle, int64_t fid, int32_t partIndex, int32_t pointIndex,
                              int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    if (!BeginEdit(state, QStringLiteral("Delete feature node"), message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!layer->changeGeometry(static_cast<QgsFeatureId>(fid), geometry)) {
        CancelEdit(state);
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS changeGeometry failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!CommitEdit(state, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Node deleted through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *CopyFeature(LayerHandle handle, int64_t fid, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    if (!BeginEdit(state, QStringLiteral("Copy feature"), message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QgsFeature copy;
    copy.setFields(layer->fields(), true);
    copy.setGeometry(source.geometry());
    copy.setAttributes(source.attributes());
    if (!layer->addFeature(copy)) {
        CancelEdit(state);
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS add copied feature failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!CommitEdit(state, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Feature copied through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *SplitFeature(LayerHandle handle, int64_t fid, const char *coordsText, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(handle);
    if (!state || !state->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Layer not found", "", "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    std::vector<ParsedCoordinate> parsedCoordinates = ParseCoordText(coordsText);
    std::vector<QgsPointXY> parsedPoints;
    for (size_t i = 0; i < parsedCoordinates.size(); i++) {
        parsedPoints.push_back(QgsPointXY(parsedCoordinates[i].x, parsedCoordinates[i].y));
    }
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
    if (!BeginEdit(state, QStringLiteral("Split feature"), message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!layer->changeGeometry(static_cast<QgsFeatureId>(fid), geometry)) {
        CancelEdit(state);
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS changeGeometry failed for split source", "",
            "", static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    for (int i = 0; i < newGeometries.size(); i++) {
        QgsFeature outFeature;
        outFeature.setFields(layer->fields(), true);
        outFeature.setAttributes(feature.attributes());
        outFeature.setGeometry(newGeometries.at(i));
        if (!layer->addFeature(outFeature)) {
            CancelEdit(state);
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS add split feature failed", "", "",
                static_cast<int32_t>(layer->featureCount()), outErrCode);
        }
    }
    if (!CommitEdit(state, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Feature split through QGIS geometry API", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *MergeFeatures(LayerHandle handle, const char *fidListText, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    if (!BeginEdit(state, QStringLiteral("Merge features"), message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QgsFeatureId keepFid = static_cast<QgsFeatureId>(fids[0]);
    if (!layer->changeGeometry(keepFid, merged)) {
        CancelEdit(state);
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS changeGeometry failed for merge", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    for (size_t i = 1; i < fids.size(); i++) {
        if (!layer->deleteFeature(static_cast<QgsFeatureId>(fids[i]))) {
            CancelEdit(state);
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS delete merged feature failed", "", "",
                static_cast<int32_t>(layer->featureCount()), outErrCode);
        }
    }
    Q_UNUSED(firstFeature);
    if (!CommitEdit(state, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Features merged through QGIS geometry API", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

static std::set<long long> ParseTopologyFeatureIds(const char *text)
{
    std::set<long long> ids;
    QStringList parts = QString::fromUtf8(text ? text : "").split(QLatin1Char(';'), Qt::SkipEmptyParts);
    for (int i = 0; i < parts.size(); i++) {
        bool ok = false;
        qlonglong value = parts.at(i).trimmed().toLongLong(&ok);
        if (ok) ids.insert(static_cast<long long>(value));
    }
    return ids;
}

static QgsGeometry ApplyTopologyRepairGeometry(const QgsGeometry &input, const QString &strategy,
                                               const QgsGeometry &targetUnion,
                                               const std::vector<QgsPointXY> &targetPoints,
                                               double tolerance)
{
    QgsGeometry result = input;
    if (strategy == QStringLiteral("make_valid")) {
        result = input.makeValid();
    } else if (strategy == QStringLiteral("snap") || strategy == QStringLiteral("extend")) {
        SnapGeometryToTargets(result, targetPoints, tolerance);
    } else if (strategy == QStringLiteral("clip") && !targetUnion.isEmpty()) {
        result = input.intersection(targetUnion);
    } else if (strategy == QStringLiteral("trim") && !targetUnion.isEmpty()) {
        result = input.difference(targetUnion);
    } else if (strategy == QStringLiteral("split") && !targetUnion.isEmpty()) {
        double cutWidth = tolerance > 0.0 ? tolerance * 0.05 : 0.000001;
        QgsGeometry boundaryGeometry(targetUnion.constGet()->boundary());
        result = input.difference(boundaryGeometry.buffer(cutWidth, 4));
    }
    if (result.isNull() || result.isEmpty()) return input;
    return result;
}

const char *RepairTopologyIssues(LayerHandle sourceHandle, LayerHandle targetHandle,
                                 const char *featureIdsText, const char *strategyText,
                                 double tolerance, bool previewOnly,
                                 const char *outputPath, const char *outputLayerName,
                                 int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QgisLayerState *state = FindLayer(sourceHandle);
    QgisLayerState *targetState = FindLayer(targetHandle > 0 ? targetHandle : sourceHandle);
    if (!state || !state->layer || !targetState || !targetState->layer) {
        return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Topology repair layer not found",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QString strategy = QString::fromUtf8(strategyText ? strategyText : "").trimmed().toLower();
    QSet<QString> supported;
    supported << QStringLiteral("make_valid") << QStringLiteral("snap") << QStringLiteral("merge")
              << QStringLiteral("extend") << QStringLiteral("trim") << QStringLiteral("clip")
              << QStringLiteral("split");
    if (!supported.contains(strategy)) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Unsupported topology repair strategy",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    std::set<long long> ids = ParseTopologyFeatureIds(featureIdsText);
    if (ids.empty()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "No topology issue features were selected",
            outputPath ? outputPath : "", outputLayerName ? outputLayerName : "", 0, outErrCode);
    }
    QgsVectorLayer *layer = state->layer.get();
    QgsVectorLayer *target = targetState->layer.get();
    QgsGeometry targetUnion = CollectLayerUnion(target, nullptr, layer->crs());
    std::vector<QgsPointXY> targetPoints;
    QgsFeatureIterator targetIterator = target->getFeatures();
    QgsFeature targetFeature;
    while (targetIterator.nextFeature(targetFeature)) {
        QgsGeometry targetGeometry = targetFeature.geometry();
        std::string transformMessage;
        if (TransformGeometryToCrs(targetGeometry, target->crs(), layer->crs(), transformMessage))
            CollectGeometryPoints(targetGeometry, targetPoints);
    }
    double safeTolerance = tolerance > 0.0 ? tolerance : std::max(layer->extent().width(), layer->extent().height()) / 5000.0;
    if (safeTolerance <= 0.0) safeTolerance = 1.0;

    QVector<QgsGeometry> mergeGeometries;
    QgsFeatureRequest selectedRequest;
    QgsFeatureIds requestedIds;
    for (std::set<long long>::const_iterator it = ids.begin(); it != ids.end(); ++it)
        requestedIds.insert(static_cast<QgsFeatureId>(*it));
    selectedRequest.setFilterFids(requestedIds);
    QgsFeatureIterator selectedIterator = layer->getFeatures(selectedRequest);
    QgsFeature selectedFeature;
    while (selectedIterator.nextFeature(selectedFeature)) mergeGeometries.push_back(selectedFeature.geometry());
    QgsGeometry mergedGeometry;
    if (strategy == QStringLiteral("merge")) {
        mergedGeometry = QgsGeometry::unaryUnion(mergeGeometries);
        if (layer->geometryType() == Qgis::GeometryType::Line && !mergedGeometry.isEmpty())
            mergedGeometry = mergedGeometry.mergeLines();
    }

    if (previewOnly) {
        if (!outputPath || std::strlen(outputPath) == 0) {
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Repair preview output path is empty", "", "", 0,
                outErrCode);
        }
        QString name = QString::fromUtf8(outputLayerName && std::strlen(outputLayerName) > 0 ?
            outputLayerName : "topology_repair_preview");
        QgsVectorFileWriter::SaveVectorOptions options;
        options.driverName = QStringLiteral("GPKG");
        options.layerName = name;
        options.fileEncoding = QStringLiteral("UTF-8");
        std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(QString::fromUtf8(outputPath),
            layer->fields(), layer->wkbType(), layer->crs(), QgsCoordinateTransformContext(), options));
        if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create topology repair preview",
                outputPath, ToStdString(name), 0, outErrCode);
        }
        QgsFeatureIterator iterator = layer->getFeatures();
        QgsFeature feature;
        int32_t count = 0;
        bool mergedWritten = false;
        while (iterator.nextFeature(feature)) {
            bool selected = ids.find(static_cast<long long>(feature.id())) != ids.end();
            if (strategy == QStringLiteral("merge") && selected) {
                if (mergedWritten) continue;
                feature.setGeometry(mergedGeometry);
                mergedWritten = true;
            } else if (selected) {
                feature.setGeometry(ApplyTopologyRepairGeometry(feature.geometry(), strategy, targetUnion,
                    targetPoints, safeTolerance));
            }
            if (writer->addFeature(feature)) count++;
        }
        return MakeProcessResult(true, GIS_OK, "Topology repair preview generated; source was not modified",
            outputPath, ToStdString(name), count, outErrCode);
    }

    if (!state->editSessionActive) {
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
            "Begin an edit session before applying topology repair so the operation can be rolled back",
            "", "", 0, outErrCode);
    }
    std::string editMessage;
    if (!BeginEdit(state, QStringLiteral("Topology repair"), editMessage)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, editMessage, "", "", 0, outErrCode);
    }
    int32_t changed = 0;
    if (strategy == QStringLiteral("merge")) {
        if (mergedGeometry.isNull() || mergedGeometry.isEmpty()) {
            CancelEdit(state);
            return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Selected features cannot be merged", "", "", 0,
                outErrCode);
        }
        QgsFeatureId keepId = *requestedIds.constBegin();
        if (!layer->changeGeometry(keepId, mergedGeometry)) {
            CancelEdit(state);
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to update merged geometry", "", "", 0,
                outErrCode);
        }
        for (QgsFeatureIds::const_iterator it = requestedIds.constBegin(); it != requestedIds.constEnd(); ++it) {
            if (*it != keepId && !layer->deleteFeature(*it)) {
                CancelEdit(state);
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to remove merged feature", "", "", 0,
                    outErrCode);
            }
        }
        changed = requestedIds.size();
    } else {
        QgsFeatureIterator iterator = layer->getFeatures(selectedRequest);
        QgsFeature feature;
        while (iterator.nextFeature(feature)) {
            QgsGeometry repaired = ApplyTopologyRepairGeometry(feature.geometry(), strategy, targetUnion,
                targetPoints, safeTolerance);
            if (!layer->changeGeometry(feature.id(), repaired)) {
                CancelEdit(state);
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to apply topology geometry repair",
                    "", "", changed, outErrCode);
            }
            changed++;
        }
    }
    if (!CommitEdit(state, editMessage)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, editMessage, "", "", changed, outErrCode);
    }
    return MakeProcessResult(true, GIS_OK,
        "Topology repair applied to the edit buffer; commit or roll back the edit session", "", "", changed,
        outErrCode);
}

const char *SnapLayer(LayerHandle handle, LayerHandle targetHandle, double tolerance, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    if (!BeginEdit(state, QStringLiteral("Snap layer"), message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }

    int32_t changedCount = 0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        QgsGeometry geometry = feature.geometry();
        if (SnapGeometryToTargets(geometry, targetPoints, snapTolerance)) {
            if (!layer->changeGeometry(feature.id(), geometry)) {
                CancelEdit(state);
                return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS snapping changeGeometry failed", "",
                    "", changedCount, outErrCode);
            }
            changedCount++;
        }
    }
    if (!CommitEdit(state, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "", changedCount, outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Layer snapped through QGIS provider geometry updates", "", "",
        changedCount, outErrCode);
}

const char *UpdateFeatureAttribute(LayerHandle handle, int64_t fid, const char *fieldName,
                                   const char *value, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    if (!BeginEdit(state, QStringLiteral("Update feature attribute"), message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QVariant attrValue(QString::fromUtf8(value ? value : ""));
    if (!layer->changeAttributeValue(static_cast<QgsFeatureId>(fid), fieldIndex, attrValue)) {
        CancelEdit(state);
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS changeAttributeValue failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!CommitEdit(state, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Attribute updated through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *BatchAssignAttribute(LayerHandle handle, const char *fieldName, const char *filterText,
                                 const char *value, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    if (!BeginEdit(state, QStringLiteral("Batch assign attribute"), message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    QVariant attrValue(QString::fromUtf8(value ? value : ""));
    int32_t changed = 0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
        bool matches = false;
        if (useQgisExpression) {
            expressionContext.setFeature(feature);
            QVariant evaluated = expression.evaluate(&expressionContext);
            if (expression.hasEvalError()) {
                CancelEdit(state);
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
    if (!CommitEdit(state, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "", changed, outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Batch attribute assignment completed", "", "", changed, outErrCode);
}

const char *AddLayerField(LayerHandle handle, const char *fieldName, const char *typeName,
                          int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    if (!BeginEdit(state, QStringLiteral("Add layer field"), message)) {
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
        CancelEdit(state);
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS addAttribute failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    layer->updateFields();
    if (!CommitEdit(state, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Field added through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *DeleteLayerField(LayerHandle handle, const char *fieldName, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    if (!BeginEdit(state, QStringLiteral("Delete layer field"), message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    if (!layer->deleteAttribute(fieldIndex)) {
        CancelEdit(state);
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "QGIS deleteAttribute failed", "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    layer->updateFields();
    if (!CommitEdit(state, message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    return MakeProcessResult(true, GIS_OK, "Field deleted through QGIS provider", "", "",
        static_cast<int32_t>(layer->featureCount()), outErrCode);
}

const char *CalculateField(LayerHandle handle, const char *fieldName, int32_t calculatorMode,
                           const char *constantValue, int32_t *outErrCode)
{
    ProcessingStateLock lock;
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
    if (!BeginEdit(state, QStringLiteral("Calculate field"), message)) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, "", "",
            static_cast<int32_t>(layer->featureCount()), outErrCode);
    }
    int32_t changed = 0;
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("compute")) {
            break;
        }
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
                CancelEdit(state);
                return MakeProcessResult(false, GIS_ERR_INVALID_PARAM,
                    ToStdString(expression.evalErrorString()), "", "", changed, outErrCode);
            }
        }
        if (layer->changeAttributeValue(feature.id(), fieldIndex, value)) {
            changed++;
        }
    }
    if (!CommitEdit(state, message)) {
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
