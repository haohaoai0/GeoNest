#include <qgsapplication.h>
#include <qgsfeature.h>
#include <qgsfeatureiterator.h>
#include <qgsfields.h>
#include <qgsgeometry.h>
#include <qgsrectangle.h>
#include <qgsvectorlayer.h>
#include <qgswkbtypes.h>

#include <QFileInfo>
#include <QString>
#include <QVariant>

#include <iostream>

static std::string ToStdString(const QString &value)
{
    return value.toUtf8().constData();
}

static void PrintUsage()
{
    std::cerr << "Usage: geonest_qgis_vector_probe <vector-layer-path>\n";
}

int main(int argc, char *argv[])
{
    if (argc < 2) {
        PrintUsage();
        return 1;
    }

    QgsApplication app(argc, argv, false);
    QgsApplication::initQgis();

    const QString filePath = QString::fromLocal8Bit(argv[1]);
    const QFileInfo fileInfo(filePath);
    QgsVectorLayer layer(filePath, fileInfo.baseName(), "ogr");

    if (!layer.isValid()) {
        std::cerr << "Failed to open vector layer: " << argv[1] << "\n";
        QgsApplication::exitQgis();
        return 2;
    }

    const QgsRectangle extent = layer.extent();
    const QgsFields fields = layer.fields();

    std::cout << "name=" << ToStdString(layer.name()) << "\n";
    std::cout << "provider=" << ToStdString(layer.providerType()) << "\n";
    std::cout << "geometryType=" << static_cast<int>(layer.geometryType()) << "\n";
    std::cout << "wkbType=" << ToStdString(QgsWkbTypes::displayString(layer.wkbType())) << "\n";
    std::cout << "featureCount=" << layer.featureCount() << "\n";
    std::cout << "crs=" << ToStdString(layer.crs().authid()) << "\n";
    std::cout << "extent="
              << extent.xMinimum() << ","
              << extent.yMinimum() << ","
              << extent.xMaximum() << ","
              << extent.yMaximum() << "\n";

    std::cout << "fields=";
    for (int i = 0; i < fields.count(); i++) {
        if (i > 0) {
            std::cout << ",";
        }
        std::cout << ToStdString(fields.at(i).name());
    }
    std::cout << "\n";

    QgsFeature feature;
    QgsFeatureIterator iterator = layer.getFeatures();
    int printed = 0;
    while (printed < 3 && iterator.nextFeature(feature)) {
        std::cout << "feature[" << printed << "].id=" << feature.id();
        if (feature.hasGeometry()) {
            const QgsRectangle featureBox = feature.geometry().boundingBox();
            std::cout << " bbox="
                      << featureBox.xMinimum() << ","
                      << featureBox.yMinimum() << ","
                      << featureBox.xMaximum() << ","
                      << featureBox.yMaximum();
        }
        std::cout << " attrs=";
        for (int i = 0; i < fields.count(); i++) {
            if (i > 0) {
                std::cout << "|";
            }
            std::cout << ToStdString(feature.attribute(i).toString());
        }
        std::cout << "\n";
        printed++;
    }

    QgsApplication::exitQgis();
    return 0;
}
