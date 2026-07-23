namespace {

struct PointCloudProcessOptions {
    int everyNth = 1;
    double voxelSize = 0.0;
    double sigma = 0.0;
    double cellSize = 0.0;
    QString rasterMode = QStringLiteral("max");
    std::set<int> classes;
    bool hasClip = false;
    QgsRectangle clip;
};

static PointCloudProcessOptions ParsePointCloudProcessOptions(const char *optionsText)
{
    PointCloudProcessOptions options;
    QStringList items = QString::fromUtf8(optionsText ? optionsText : "").split(';', Qt::SkipEmptyParts);
    for (int i = 0; i < items.size(); i++) {
        QString item = items.at(i).trimmed();
        int equals = item.indexOf('=');
        if (equals <= 0) continue;
        QString key = item.left(equals).trimmed().toLower();
        QString value = item.mid(equals + 1).trimmed();
        if (key == QStringLiteral("every") || key == QStringLiteral("everynth")) {
            options.everyNth = std::max(1, value.toInt());
        } else if (key == QStringLiteral("voxel")) {
            options.voxelSize = std::max(0.0, value.toDouble());
        } else if (key == QStringLiteral("sigma")) {
            options.sigma = std::max(0.0, value.toDouble());
        } else if (key == QStringLiteral("cellsize")) {
            options.cellSize = std::max(0.0, value.toDouble());
        } else if (key == QStringLiteral("mode")) {
            options.rasterMode = value.toLower();
        } else if (key == QStringLiteral("classes")) {
            QStringList classValues = value.split(',', Qt::SkipEmptyParts);
            for (int ci = 0; ci < classValues.size(); ci++) options.classes.insert(classValues.at(ci).toInt());
        } else if (key == QStringLiteral("clip")) {
            QStringList bounds = value.split(',', Qt::SkipEmptyParts);
            if (bounds.size() == 4) {
                options.clip = QgsRectangle(bounds.at(0).toDouble(), bounds.at(1).toDouble(),
                    bounds.at(2).toDouble(), bounds.at(3).toDouble());
                options.hasClip = !options.clip.isEmpty();
            }
        }
    }
    return options;
}

static int PointCloudClassification(const QgsPointCloudAttribute *attribute, const char *record, int offset)
{
    if (!attribute || offset < 0) return 0;
    return static_cast<int>(std::llround(attribute->convertValueToDouble(record + offset)));
}

static double PointCloudIntensity(const QgsPointCloudAttribute *attribute, const char *record, int offset)
{
    if (!attribute || offset < 0) return 0.0;
    return attribute->convertValueToDouble(record + offset);
}

static bool KeepPointCloudClass(const PointCloudProcessOptions &options, int classification)
{
    return options.classes.empty() || options.classes.find(classification) != options.classes.end();
}

} // namespace

const char *ProcessPointCloud(const char *inputPath, const char *operationText, const char *optionsText,
                              const char *outputPath, int32_t *outErrCode)
{
    ProcessingStateLock lock;
    QString input = QString::fromUtf8(inputPath ? inputPath : "");
    QString output = QString::fromUtf8(outputPath ? outputPath : "");
    QString operation = QString::fromUtf8(operationText ? operationText : "decode").trimmed().toLower();
    if (input.isEmpty() || output.isEmpty() || !QFileInfo::exists(input)) {
        return MakeProcessResult(false, GIS_ERR_FILE_NOT_FOUND, "Point cloud input or output is invalid",
            outputPath ? outputPath : "", "point_cloud", 0, outErrCode);
    }
    std::ifstream headerStream(ToStdString(input), std::ios::binary);
    QgsLazInfo info = QgsLazInfo::fromFile(headerStream);
    headerStream.close();
    if (!info.isValid()) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT, ToStdString(info.error()),
            outputPath, "point_cloud", 0, outErrCode);
    }
    PointCloudProcessOptions processOptions = ParsePointCloudProcessOptions(optionsText);
    QgsPointCloudAttributeCollection requestedAttributes = info.attributes();
    QgsPointCloudExpression filterExpression;
    QgsRectangle filterRectangle;
    if (processOptions.hasClip) filterRectangle = processOptions.clip;
    std::unique_ptr<QgsPointCloudBlock> block = QgsLazDecoder::decompressLaz(
        input, requestedAttributes, filterExpression, filterRectangle);
    if (!block || block->pointCount() <= 0) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT,
            "Point cloud decompression failed or filter returned no points", outputPath, "point_cloud", 0, outErrCode);
    }
    int xOffset = -1;
    int yOffset = -1;
    int zOffset = -1;
    int classOffset = -1;
    int intensityOffset = -1;
    const QgsPointCloudAttribute *xAttribute = requestedAttributes.find(QStringLiteral("X"), xOffset);
    const QgsPointCloudAttribute *yAttribute = requestedAttributes.find(QStringLiteral("Y"), yOffset);
    const QgsPointCloudAttribute *zAttribute = requestedAttributes.find(QStringLiteral("Z"), zOffset);
    const QgsPointCloudAttribute *classAttribute = requestedAttributes.find(QStringLiteral("Classification"), classOffset);
    const QgsPointCloudAttribute *intensityAttribute = requestedAttributes.find(QStringLiteral("Intensity"), intensityOffset);
    if (!xAttribute || !yAttribute || !zAttribute) {
        return MakeProcessResult(false, GIS_ERR_INVALID_FORMAT, "Point cloud has no XYZ attributes",
            outputPath, "point_cloud", 0, outErrCode);
    }
    const char *data = block->data();
    int recordSize = block->pointRecordSize();
    QgsVector3D scale = block->scale();
    QgsVector3D offset = block->offset();
    double zMean = 0.0;
    double zSquared = 0.0;
    if (operation == QStringLiteral("denoise") && processOptions.sigma > 0.0) {
        for (int i = 0; i < block->pointCount(); i++) {
            double x = 0.0, y = 0.0, z = 0.0;
            QgsPointCloudAttribute::getPointXYZ(data, i, recordSize, xOffset, xAttribute->type(),
                yOffset, yAttribute->type(), zOffset, zAttribute->type(), scale, offset, x, y, z);
            zMean += z;
            zSquared += z * z;
        }
        zMean /= static_cast<double>(block->pointCount());
    }
    double zDeviation = 0.0;
    if (processOptions.sigma > 0.0) {
        zDeviation = std::sqrt(std::max(0.0, zSquared / static_cast<double>(block->pointCount()) - zMean * zMean));
    }

    if (operation == QStringLiteral("rasterize")) {
        QgsVector3D minimum = info.minCoords();
        QgsVector3D maximum = info.maxCoords();
        QgsRectangle extent(minimum.x(), minimum.y(), maximum.x(), maximum.y());
        if (processOptions.hasClip) extent = extent.intersect(processOptions.clip);
        double cellSize = processOptions.cellSize;
        if (cellSize <= 0.0) cellSize = std::max(extent.width(), extent.height()) / 512.0;
        int cols = std::max(1, static_cast<int>(std::ceil(extent.width() / cellSize)));
        int rows = std::max(1, static_cast<int>(std::ceil(extent.height() / cellSize)));
        std::vector<double> values(static_cast<size_t>(cols * rows), -9999.0);
        std::vector<int> counts(static_cast<size_t>(cols * rows), 0);
        for (int i = 0; i < block->pointCount(); i++) {
            if (i % processOptions.everyNth != 0) continue;
            double x = 0.0, y = 0.0, z = 0.0;
            QgsPointCloudAttribute::getPointXYZ(data, i, recordSize, xOffset, xAttribute->type(),
                yOffset, yAttribute->type(), zOffset, zAttribute->type(), scale, offset, x, y, z);
            const char *record = data + static_cast<size_t>(i * recordSize);
            int classification = PointCloudClassification(classAttribute, record, classOffset);
            if (!KeepPointCloudClass(processOptions, classification) || !extent.contains(x, y)) continue;
            int col = std::min(cols - 1, std::max(0, static_cast<int>((x - extent.xMinimum()) / cellSize)));
            int row = std::min(rows - 1, std::max(0, static_cast<int>((extent.yMaximum() - y) / cellSize)));
            size_t index = static_cast<size_t>(row * cols + col);
            if (counts[index] == 0) values[index] = z;
            else if (processOptions.rasterMode == QStringLiteral("min")) values[index] = std::min(values[index], z);
            else if (processOptions.rasterMode == QStringLiteral("mean")) values[index] += z;
            else values[index] = std::max(values[index], z);
            counts[index]++;
        }
        int populated = 0;
        for (size_t i = 0; i < values.size(); i++) {
            if (counts[i] > 0) {
                if (processOptions.rasterMode == QStringLiteral("mean")) values[i] /= static_cast<double>(counts[i]);
                populated++;
            }
        }
        std::string message;
        if (!WriteRasterAnalysisGrid(output, info.crs(), extent, cols, rows, values, message)) {
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, message, outputPath, "point_cloud_raster", 0, outErrCode);
        }
        return MakeProcessResult(true, GIS_OK, "Point cloud rasterization completed", outputPath,
            "point_cloud_raster", populated, outErrCode);
    }

    QgsFields fields;
    fields.append(QgsField(QStringLiteral("classification"), QVariant::Int));
    fields.append(QgsField(QStringLiteral("intensity"), QVariant::Double));
    fields.append(QgsField(QStringLiteral("source_index"), QVariant::LongLong));
    QgsVectorFileWriter::SaveVectorOptions writerOptions;
    writerOptions.driverName = output.toLower().endsWith(QStringLiteral(".gpkg"))
        ? QStringLiteral("GPKG") : QStringLiteral("ESRI Shapefile");
    writerOptions.layerName = QStringLiteral("point_cloud");
    writerOptions.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(output, fields,
        Qgis::WkbType::PointZ, info.crs(), QgsCoordinateTransformContext(), writerOptions));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) {
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, "Failed to create point cloud vector output",
            outputPath, "point_cloud", 0, outErrCode);
    }
    std::unordered_set<std::string> occupiedVoxels;
    int written = 0;
    for (int i = 0; i < block->pointCount(); i++) {
        if (i % processOptions.everyNth != 0) continue;
        double x = 0.0, y = 0.0, z = 0.0;
        QgsPointCloudAttribute::getPointXYZ(data, i, recordSize, xOffset, xAttribute->type(),
            yOffset, yAttribute->type(), zOffset, zAttribute->type(), scale, offset, x, y, z);
        const char *record = data + static_cast<size_t>(i * recordSize);
        int classification = PointCloudClassification(classAttribute, record, classOffset);
        if (!KeepPointCloudClass(processOptions, classification)) continue;
        if (operation == QStringLiteral("denoise") && processOptions.sigma > 0.0 &&
            std::abs(z - zMean) > processOptions.sigma * zDeviation) continue;
        if (processOptions.voxelSize > 0.0) {
            long long vx = static_cast<long long>(std::floor(x / processOptions.voxelSize));
            long long vy = static_cast<long long>(std::floor(y / processOptions.voxelSize));
            long long vz = static_cast<long long>(std::floor(z / processOptions.voxelSize));
            std::string key = std::to_string(vx) + ":" + std::to_string(vy) + ":" + std::to_string(vz);
            if (!occupiedVoxels.insert(key).second) continue;
        }
        QgsFeature feature(fields);
        feature.setAttribute(0, classification);
        feature.setAttribute(1, PointCloudIntensity(intensityAttribute, record, intensityOffset));
        feature.setAttribute(2, static_cast<qlonglong>(i));
        feature.setGeometry(QgsGeometry(new QgsPoint(Qgis::WkbType::PointZ, x, y, z)));
        if (writer->addFeature(feature)) written++;
    }
    std::string resultMessage = "Point cloud " + ToStdString(operation) + " completed";
    return MakeProcessResult(true, GIS_OK, resultMessage, outputPath, "point_cloud", written, outErrCode);
}
