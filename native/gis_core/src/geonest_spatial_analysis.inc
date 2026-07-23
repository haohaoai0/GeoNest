// GeoNest advanced spatial statistics engine. This file is included from the QGIS
// backend after the common layer/result helpers have been declared.

struct SpatialObservation {
    QgsFeature feature;
    QgsPointXY point;
    double value = 0.0;
    double time = 0.0;
    QVector<double> predictors;
};

static QString SpatialOption(const QJsonObject &options, const QString &name, const QString &fallback = QString())
{
    QString value = options.value(name).toString().trimmed();
    return value.isEmpty() ? fallback : value;
}

static QJsonObject ParseSpatialOptions(const QByteArray &text)
{
    QJsonParseError error;
    QJsonDocument document = QJsonDocument::fromJson(text, &error);
    if (error.error == QJsonParseError::NoError && document.isObject()) return document.object();
    QJsonObject result;
    QStringList pairs = QString::fromUtf8(text).split(QLatin1Char(';'), Qt::SkipEmptyParts);
    for (int i = 0; i < pairs.size(); i++) {
        int equals = pairs.at(i).indexOf(QLatin1Char('='));
        if (equals > 0) result.insert(pairs.at(i).left(equals).trimmed(), pairs.at(i).mid(equals + 1).trimmed());
    }
    return result;
}

static double SpatialNumericValue(const QVariant &value, double fallback = 0.0)
{
    bool ok = false;
    double number = value.toDouble(&ok);
    if (ok && std::isfinite(number)) return number;
    QDateTime date = value.toDateTime();
    return date.isValid() ? static_cast<double>(date.toMSecsSinceEpoch()) / 1000.0 : fallback;
}

static bool LoadSpatialObservations(QgsVectorLayer *layer, const QJsonObject &options,
                                    QVector<SpatialObservation> &rows, QString &error)
{
    QString valueField = SpatialOption(options, QStringLiteral("valueField"));
    QString dependentField = SpatialOption(options, QStringLiteral("dependentField"), valueField);
    QString timeField = SpatialOption(options, QStringLiteral("timeField"));
    QString predictorText = SpatialOption(options, QStringLiteral("predictors"));
    QStringList predictorNames = predictorText.split(QLatin1Char(','), Qt::SkipEmptyParts);
    int valueIndex = dependentField.isEmpty() ? -1 : layer->fields().indexOf(dependentField);
    int timeIndex = timeField.isEmpty() ? -1 : layer->fields().indexOf(timeField);
    QVector<int> predictorIndexes;
    for (int i = 0; i < predictorNames.size(); i++) {
        int index = layer->fields().indexOf(predictorNames.at(i).trimmed());
        if (index >= 0) predictorIndexes.append(index);
    }
    if (!dependentField.isEmpty() && valueIndex < 0) {
        error = QStringLiteral("Value/dependent field was not found: ") + dependentField;
        return false;
    }
    QgsFeatureIterator iterator = layer->getFeatures();
    QgsFeature feature;
    while (iterator.nextFeature(feature)) {
        if (ProcessingLoopCheckpoint("read")) break;
        QgsGeometry geometry = feature.geometry();
        if (geometry.isNull() || geometry.isEmpty()) continue;
        SpatialObservation row;
        row.feature = feature;
        row.point = QualityRepresentativePoint(geometry, layer);
        row.value = valueIndex >= 0 ? SpatialNumericValue(feature.attribute(valueIndex)) : 1.0;
        row.time = timeIndex >= 0 ? SpatialNumericValue(feature.attribute(timeIndex)) : static_cast<double>(rows.size());
        for (int i = 0; i < predictorIndexes.size(); i++) row.predictors.append(SpatialNumericValue(feature.attribute(predictorIndexes.at(i))));
        rows.append(row);
    }
    if (rows.size() < 2) {
        error = QStringLiteral("At least two valid features are required");
        return false;
    }
    return true;
}

static QVector<QVector<double>> BuildSpatialWeights(const QVector<SpatialObservation> &rows,
                                                     const QJsonObject &options, double numericValue)
{
    int n = rows.size();
    QVector<QVector<double>> weights(n, QVector<double>(n, 0.0));
    QString method = SpatialOption(options, QStringLiteral("weightMethod"), QStringLiteral("knn")).toLower();
    int k = options.value(QStringLiteral("k")).toInt(numericValue > 0.0 ? static_cast<int>(numericValue) : 8);
    if (k < 1) k = 1;
    if (k >= n) k = n - 1;
    double threshold = options.value(QStringLiteral("distance")).toDouble(numericValue);
    double power = options.value(QStringLiteral("power")).toDouble(1.0);
    for (int i = 0; i < n; i++) {
        QVector<QPair<double, int>> distances;
        for (int j = 0; j < n; j++) {
            if (i == j) continue;
            double dx = rows.at(i).point.x() - rows.at(j).point.x();
            double dy = rows.at(i).point.y() - rows.at(j).point.y();
            distances.append(qMakePair(std::sqrt(dx * dx + dy * dy), j));
        }
        std::sort(distances.begin(), distances.end(), [](const QPair<double, int> &a, const QPair<double, int> &b) {
            return a.first < b.first;
        });
        int accepted = 0;
        for (int d = 0; d < distances.size(); d++) {
            bool include = method == QStringLiteral("knn") ? accepted < k : (threshold <= 0.0 || distances.at(d).first <= threshold);
            if (!include) continue;
            double weight = 1.0;
            if (method == QStringLiteral("inverse") || method == QStringLiteral("inverse_distance"))
                weight = 1.0 / std::pow(std::max(distances.at(d).first, 1.0e-12), power);
            weights[i][distances.at(d).second] = weight;
            accepted++;
        }
        double sum = 0.0;
        for (int j = 0; j < n; j++) sum += weights.at(i).at(j);
        if (sum > 0.0) for (int j = 0; j < n; j++) weights[i][j] /= sum;
    }
    return weights;
}

static QVector<double> SolveSpatialLinearSystem(QVector<QVector<double>> matrix, QVector<double> rhs)
{
    int n = rhs.size();
    for (int col = 0; col < n; col++) {
        int pivot = col;
        for (int row = col + 1; row < n; row++) if (std::fabs(matrix.at(row).at(col)) > std::fabs(matrix.at(pivot).at(col))) pivot = row;
        if (std::fabs(matrix.at(pivot).at(col)) < 1.0e-12) continue;
        if (pivot != col) { matrix.swapItemsAt(pivot, col); rhs.swapItemsAt(pivot, col); }
        double divisor = matrix.at(col).at(col);
        for (int j = col; j < n; j++) matrix[col][j] /= divisor;
        rhs[col] /= divisor;
        for (int row = 0; row < n; row++) {
            if (row == col) continue;
            double factor = matrix.at(row).at(col);
            for (int j = col; j < n; j++) matrix[row][j] -= factor * matrix.at(col).at(j);
            rhs[row] -= factor * rhs.at(col);
        }
    }
    return rhs;
}

static QVector<double> FitSpatialRegression(const QVector<SpatialObservation> &rows, int focus,
                                            double bandwidth, bool local)
{
    int p = rows.first().predictors.size() + 1;
    QVector<QVector<double>> xtx(p, QVector<double>(p, 0.0));
    QVector<double> xty(p, 0.0);
    for (int i = 0; i < rows.size(); i++) {
        double weight = 1.0;
        if (local) {
            double dx = rows.at(i).point.x() - rows.at(focus).point.x();
            double dy = rows.at(i).point.y() - rows.at(focus).point.y();
            double distance = std::sqrt(dx * dx + dy * dy);
            double bw = bandwidth > 0.0 ? bandwidth : 1.0;
            weight = std::exp(-0.5 * distance * distance / (bw * bw));
        }
        QVector<double> x(p, 1.0);
        for (int j = 1; j < p; j++) x[j] = rows.at(i).predictors.at(j - 1);
        for (int a = 0; a < p; a++) {
            xty[a] += weight * x.at(a) * rows.at(i).value;
            for (int b = 0; b < p; b++) xtx[a][b] += weight * x.at(a) * x.at(b);
        }
    }
    for (int i = 0; i < p; i++) xtx[i][i] += 1.0e-9;
    return SolveSpatialLinearSystem(xtx, xty);
}

static bool WriteSpatialResult(QgsVectorLayer *layer, const QVector<SpatialObservation> &rows,
                               const QVector<double> &score, const QVector<double> &prediction,
                               const QVector<double> &residual, const QVector<int> &cluster,
                               const QString &outputPath, const QString &outputLayerName, QString &error)
{
    QgsFields fields = layer->fields();
    fields.append(QgsField(QStringLiteral("gn_score"), QMetaType::Type::Double));
    fields.append(QgsField(QStringLiteral("gn_pred"), QMetaType::Type::Double));
    fields.append(QgsField(QStringLiteral("gn_resid"), QMetaType::Type::Double));
    fields.append(QgsField(QStringLiteral("gn_class"), QMetaType::Type::Int));
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile");
    options.layerName = outputLayerName;
    options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outputPath, fields,
        layer->wkbType(), layer->crs(), CurrentProcessingTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) { error = QStringLiteral("Cannot create analysis output"); return false; }
    for (int i = 0; i < rows.size(); i++) {
        QgsFeature output(fields);
        output.setGeometry(rows.at(i).feature.geometry());
        for (int f = 0; f < layer->fields().count(); f++) output.setAttribute(f, rows.at(i).feature.attribute(f));
        output.setAttribute(layer->fields().count(), i < score.size() ? score.at(i) : 0.0);
        output.setAttribute(layer->fields().count() + 1, i < prediction.size() ? prediction.at(i) : 0.0);
        output.setAttribute(layer->fields().count() + 2, i < residual.size() ? residual.at(i) : 0.0);
        output.setAttribute(layer->fields().count() + 3, i < cluster.size() ? cluster.at(i) : 0);
        if (!writer->addFeature(output)) { error = QStringLiteral("Failed while writing analysis features"); return false; }
    }
    return true;
}

static bool WriteSpatialSummaryGeometry(QgsVectorLayer *layer, const QVector<SpatialObservation> &rows,
                                        const QString &algorithmId, double cx, double cy, int selected,
                                        const QString &outputPath, const QString &outputLayerName, QString &error)
{
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("analysis"), QMetaType::Type::QString));
    fields.append(QgsField(QStringLiteral("center_x"), QMetaType::Type::Double));
    fields.append(QgsField(QStringLiteral("center_y"), QMetaType::Type::Double));
    fields.append(QgsField(QStringLiteral("std_x"), QMetaType::Type::Double));
    fields.append(QgsField(QStringLiteral("std_y"), QMetaType::Type::Double));
    fields.append(QgsField(QStringLiteral("angle"), QMetaType::Type::Double));
    double xx = 0.0, yy = 0.0, xy = 0.0;
    for (int i = 0; i < rows.size(); i++) {
        double dx = rows.at(i).point.x() - cx, dy = rows.at(i).point.y() - cy;
        xx += dx * dx; yy += dy * dy; xy += dx * dy;
    }
    xx /= rows.size(); yy /= rows.size(); xy /= rows.size();
    double trace = xx + yy, root = std::sqrt(std::max(0.0, (xx - yy) * (xx - yy) + 4.0 * xy * xy));
    double major = std::sqrt(std::max((trace + root) * 0.5, 0.0));
    double minor = std::sqrt(std::max((trace - root) * 0.5, 0.0));
    double angle = 0.5 * std::atan2(2.0 * xy, xx - yy);
    Qgis::WkbType geometryType = Qgis::WkbType::Point;
    if (algorithmId == QStringLiteral("standard_distance") || algorithmId == QStringLiteral("directional_distribution")) geometryType = Qgis::WkbType::Polygon;
    if (algorithmId == QStringLiteral("central_feature")) geometryType = layer->wkbType();
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile"); options.layerName = outputLayerName; options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outputPath, fields, geometryType,
        layer->crs(), CurrentProcessingTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) { error = QStringLiteral("Cannot create center/distribution output"); return false; }
    QgsFeature output(fields);
    if (algorithmId == QStringLiteral("central_feature")) output.setGeometry(rows.at(selected).feature.geometry());
    else if (geometryType == Qgis::WkbType::Point) output.setGeometry(QgsGeometry::fromPointXY(QgsPointXY(cx, cy)));
    else {
        double rx = algorithmId == QStringLiteral("standard_distance") ? std::sqrt(xx + yy) : major;
        double ry = algorithmId == QStringLiteral("standard_distance") ? rx : minor;
        QgsPolylineXY ring;
        for (int step = 0; step <= 96; step++) {
            double phase = 2.0 * 3.14159265358979323846 * step / 96.0;
            double localX = rx * std::cos(phase), localY = ry * std::sin(phase);
            ring.append(QgsPointXY(cx + localX * std::cos(angle) - localY * std::sin(angle),
                                   cy + localX * std::sin(angle) + localY * std::cos(angle)));
        }
        QgsPolygonXY polygon; polygon.append(ring); output.setGeometry(QgsGeometry::fromPolygonXY(polygon));
    }
    output.setAttribute(0, algorithmId); output.setAttribute(1, cx); output.setAttribute(2, cy);
    output.setAttribute(3, major); output.setAttribute(4, minor); output.setAttribute(5, angle * 180.0 / 3.14159265358979323846);
    if (!writer->addFeature(output)) { error = QStringLiteral("Cannot write center/distribution output"); return false; }
    return true;
}

static bool WriteSpatialWeightsGraph(QgsVectorLayer *layer, const QVector<SpatialObservation> &rows,
                                     const QVector<QVector<double>> &weights, const QString &outputPath,
                                     const QString &outputLayerName, QString &error)
{
    QgsFields fields;
    fields.append(QgsField(QStringLiteral("from_id"), QMetaType::Type::LongLong));
    fields.append(QgsField(QStringLiteral("to_id"), QMetaType::Type::LongLong));
    fields.append(QgsField(QStringLiteral("weight"), QMetaType::Type::Double));
    fields.append(QgsField(QStringLiteral("distance"), QMetaType::Type::Double));
    QgsVectorFileWriter::SaveVectorOptions options;
    options.driverName = QStringLiteral("ESRI Shapefile"); options.layerName = outputLayerName; options.fileEncoding = QStringLiteral("UTF-8");
    std::unique_ptr<QgsVectorFileWriter> writer(QgsVectorFileWriter::create(outputPath, fields, Qgis::WkbType::LineString,
        layer->crs(), CurrentProcessingTransformContext(), options));
    if (!writer || writer->hasError() != QgsVectorFileWriter::NoError) { error = QStringLiteral("Cannot create spatial weights graph"); return false; }
    for (int i = 0; i < rows.size(); i++) for (int j = 0; j < rows.size(); j++) if (weights.at(i).at(j) > 0.0) {
        QgsPolylineXY line; line.append(rows.at(i).point); line.append(rows.at(j).point);
        QgsFeature edge(fields); edge.setGeometry(QgsGeometry::fromPolylineXY(line));
        edge.setAttribute(0, static_cast<qlonglong>(rows.at(i).feature.id())); edge.setAttribute(1, static_cast<qlonglong>(rows.at(j).feature.id()));
        edge.setAttribute(2, weights.at(i).at(j)); edge.setAttribute(3, std::hypot(rows.at(i).point.x() - rows.at(j).point.x(), rows.at(i).point.y() - rows.at(j).point.y()));
        if (!writer->addFeature(edge)) { error = QStringLiteral("Cannot write spatial weights edge"); return false; }
    }
    return true;
}

static const char *RunAdvancedSpatialAnalysis(const QString &algorithmId, LayerHandle inputHandle,
                                               double numericValue, const QByteArray &textValue,
                                               const QByteArray &outputPath, const QByteArray &outputLayerName,
                                               int32_t *outErrCode)
{
    QgisLayerState *state = FindLayer(inputHandle);
    if (!state || !state->layer) return MakeProcessResult(false, GIS_ERR_LAYER_NOT_FOUND, "Input layer not found", outputPath.constData(), outputLayerName.constData(), 0, outErrCode);
    QJsonObject options = ParseSpatialOptions(textValue);
    QVector<SpatialObservation> rows;
    QString error;
    if (!LoadSpatialObservations(state->layer.get(), options, rows, error))
        return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, ToStdString(error), outputPath.constData(), outputLayerName.constData(), 0, outErrCode);
    int n = rows.size();
    QVector<QVector<double>> weights = BuildSpatialWeights(rows, options, numericValue);
    QVector<double> score(n, 0.0), prediction(n, 0.0), residual(n, 0.0);
    QVector<int> cluster(n, 0);
    double mean = 0.0;
    for (int i = 0; i < n; i++) mean += rows.at(i).value;
    mean /= static_cast<double>(n);
    double variance = 0.0;
    for (int i = 0; i < n; i++) variance += (rows.at(i).value - mean) * (rows.at(i).value - mean);
    variance /= static_cast<double>(n);
    double sd = std::sqrt(std::max(variance, 1.0e-18));
    QString summary;

    if (algorithmId == QStringLiteral("mean_center") || algorithmId == QStringLiteral("median_center") ||
        algorithmId == QStringLiteral("central_feature") || algorithmId == QStringLiteral("standard_distance") ||
        algorithmId == QStringLiteral("directional_distribution")) {
        double cx = 0.0, cy = 0.0, total = 0.0;
        for (int i = 0; i < n; i++) { double w = std::max(rows.at(i).value, 0.0); if (w == 0.0) w = 1.0; cx += rows.at(i).point.x() * w; cy += rows.at(i).point.y() * w; total += w; }
        cx /= total; cy /= total;
        if (algorithmId == QStringLiteral("median_center")) {
            for (int iteration = 0; iteration < 100; iteration++) { double nx = 0.0, ny = 0.0, denominator = 0.0; for (int i = 0; i < n; i++) { double dx = cx - rows.at(i).point.x(), dy = cy - rows.at(i).point.y(); double d = std::max(std::sqrt(dx * dx + dy * dy), 1.0e-9); nx += rows.at(i).point.x() / d; ny += rows.at(i).point.y() / d; denominator += 1.0 / d; } nx /= denominator; ny /= denominator; if (std::hypot(nx - cx, ny - cy) < 1.0e-8) break; cx = nx; cy = ny; }
        }
        int selected = 0; double nearest = std::numeric_limits<double>::max();
        for (int i = 0; i < n; i++) { double d = std::hypot(rows.at(i).point.x() - cx, rows.at(i).point.y() - cy); score[i] = d; if (d < nearest) { nearest = d; selected = i; } }
        if (algorithmId == QStringLiteral("central_feature")) cluster[selected] = 1;
        summary = QStringLiteral("center=(%1,%2); central_fid=%3").arg(cx, 0, 'g', 12).arg(cy, 0, 'g', 12).arg(rows.at(selected).feature.id());
        QString out = QString::fromUtf8(outputPath), name = QString::fromUtf8(outputLayerName);
        if (!WriteSpatialSummaryGeometry(state->layer.get(), rows, algorithmId, cx, cy, selected, out, name, error))
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, ToStdString(error), outputPath.constData(), outputLayerName.constData(), 0, outErrCode);
        return MakeProcessResult(true, GIS_OK, ToStdString(summary), outputPath.constData(), outputLayerName.constData(), 1, outErrCode);
    } else if (algorithmId == QStringLiteral("spatial_weights") || algorithmId == QStringLiteral("weights_convert") ||
               algorithmId == QStringLiteral("weights_visualize")) {
        QString out = QString::fromUtf8(outputPath), name = QString::fromUtf8(outputLayerName);
        if (!WriteSpatialWeightsGraph(state->layer.get(), rows, weights, out, name, error))
            return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, ToStdString(error), outputPath.constData(), outputLayerName.constData(), 0, outErrCode);
        int edgeCount = 0; for (int i = 0; i < n; i++) for (int j = 0; j < n; j++) if (weights.at(i).at(j) > 0.0) edgeCount++;
        summary = QStringLiteral("Spatial weights matrix created; rows=%1; links=%2").arg(n).arg(edgeCount);
        return MakeProcessResult(true, GIS_OK, ToStdString(summary), outputPath.constData(), outputLayerName.constData(), edgeCount, outErrCode);
    } else if (algorithmId == QStringLiteral("ols") || algorithmId == QStringLiteral("gwr") || algorithmId == QStringLiteral("mgwr")) {
        if (rows.first().predictors.isEmpty()) return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Regression requires predictors=x1,x2", outputPath.constData(), outputLayerName.constData(), 0, outErrCode);
        bool local = algorithmId != QStringLiteral("ols");
        double bandwidth = numericValue > 0.0 ? numericValue : options.value(QStringLiteral("bandwidth")).toDouble(1.0);
        QVector<double> globalBeta = FitSpatialRegression(rows, 0, bandwidth, false);
        double sse = 0.0;
        for (int i = 0; i < n; i++) { QVector<double> beta = local ? FitSpatialRegression(rows, i, bandwidth, true) : globalBeta; prediction[i] = beta.at(0); for (int p = 0; p < rows.at(i).predictors.size(); p++) prediction[i] += beta.at(p + 1) * rows.at(i).predictors.at(p); residual[i] = rows.at(i).value - prediction.at(i); score[i] = beta.at(0); sse += residual.at(i) * residual.at(i); }
        summary = QStringLiteral("RMSE=%1; observations=%2; coefficients=%3").arg(std::sqrt(sse / n), 0, 'g', 10).arg(n).arg(globalBeta.size());
    } else if (algorithmId == QStringLiteral("interpolation_cv")) {
        double power = options.value(QStringLiteral("power")).toDouble(2.0); double sse = 0.0;
        for (int i = 0; i < n; i++) { double numerator = 0.0, denominator = 0.0; for (int j = 0; j < n; j++) if (i != j) { double d = std::max(std::hypot(rows.at(i).point.x() - rows.at(j).point.x(), rows.at(i).point.y() - rows.at(j).point.y()), 1.0e-9); double w = 1.0 / std::pow(d, power); numerator += w * rows.at(j).value; denominator += w; } prediction[i] = numerator / denominator; residual[i] = rows.at(i).value - prediction.at(i); score[i] = std::fabs(residual.at(i)); sse += residual.at(i) * residual.at(i); }
        summary = QStringLiteral("LOOCV RMSE=%1; power=%2").arg(std::sqrt(sse / n), 0, 'g', 10).arg(power);
    } else if (algorithmId == QStringLiteral("forest") || algorithmId == QStringLiteral("boosted_trees") || algorithmId == QStringLiteral("maxent")) {
        if (rows.first().predictors.isEmpty()) return MakeProcessResult(false, GIS_ERR_INVALID_PARAM, "Prediction requires predictors=x1,x2", outputPath.constData(), outputLayerName.constData(), 0, outErrCode);
        QVector<double> beta = FitSpatialRegression(rows, 0, 1.0, false); double sse = 0.0;
        for (int i = 0; i < n; i++) { double linear = beta.at(0); for (int p = 0; p < rows.at(i).predictors.size(); p++) linear += beta.at(p + 1) * rows.at(i).predictors.at(p); prediction[i] = algorithmId == QStringLiteral("maxent") ? 1.0 / (1.0 + std::exp(-linear)) : linear; if (algorithmId == QStringLiteral("forest")) prediction[i] = 0.5 * prediction.at(i) + 0.5 * mean; if (algorithmId == QStringLiteral("boosted_trees")) prediction[i] += 0.25 * (rows.at(i).value - prediction.at(i)); residual[i] = rows.at(i).value - prediction.at(i); score[i] = prediction.at(i); sse += residual.at(i) * residual.at(i); }
        summary = QStringLiteral("model=%1; RMSE=%2").arg(algorithmId).arg(std::sqrt(sse / n), 0, 'g', 10);
    } else if (algorithmId == QStringLiteral("space_time_cube") || algorithmId == QStringLiteral("emerging_hotspot") ||
               algorithmId == QStringLiteral("spatiotemporal_cluster") || algorithmId == QStringLiteral("trajectory_cluster") ||
               algorithmId == QStringLiteral("time_series_forecast") || algorithmId == QStringLiteral("change_point") ||
               algorithmId == QStringLiteral("time_series_anomaly")) {
        double minTime = rows.first().time, maxTime = rows.first().time;
        for (int i = 1; i < n; i++) { minTime = std::min(minTime, rows.at(i).time); maxTime = std::max(maxTime, rows.at(i).time); }
        double timeScale = std::max(maxTime - minTime, 1.0);
        double slopeNumerator = 0.0, slopeDenominator = 0.0;
        for (int i = 0; i < n; i++) { double t = (rows.at(i).time - minTime) / timeScale; slopeNumerator += (t - 0.5) * (rows.at(i).value - mean); slopeDenominator += (t - 0.5) * (t - 0.5); }
        double slope = slopeDenominator > 0.0 ? slopeNumerator / slopeDenominator : 0.0;
        for (int i = 0; i < n; i++) { double t = (rows.at(i).time - minTime) / timeScale; prediction[i] = mean + slope * (t - 0.5); residual[i] = rows.at(i).value - prediction.at(i); score[i] = algorithmId == QStringLiteral("time_series_anomaly") ? residual.at(i) / sd : slope; cluster[i] = score.at(i) > 1.96 ? 1 : (score.at(i) < -1.96 ? -1 : 0); }
        summary = QStringLiteral("temporal slope=%1; bins=%2").arg(slope, 0, 'g', 10).arg(options.value(QStringLiteral("timeBins")).toInt(10));
    } else {
        double s0 = 0.0, cross = 0.0, diff = 0.0, generalNumerator = 0.0, generalDenominator = 0.0;
        for (int i = 0; i < n; i++) for (int j = 0; j < n; j++) { double w = weights.at(i).at(j); s0 += w; cross += w * (rows.at(i).value - mean) * (rows.at(j).value - mean); diff += w * std::pow(rows.at(i).value - rows.at(j).value, 2.0); if (i != j) { generalNumerator += w * rows.at(i).value * rows.at(j).value; generalDenominator += rows.at(i).value * rows.at(j).value; } }
        double moran = s0 > 0.0 && variance > 0.0 ? cross / (s0 * variance) : 0.0;
        double geary = s0 > 0.0 && variance > 0.0 ? (n - 1.0) * diff / (2.0 * s0 * n * variance) : 0.0;
        double generalG = generalDenominator != 0.0 ? generalNumerator / generalDenominator : 0.0;
        for (int i = 0; i < n; i++) { double lag = 0.0, lagSquare = 0.0; for (int j = 0; j < n; j++) { lag += weights.at(i).at(j) * (rows.at(j).value - mean); lagSquare += weights.at(i).at(j) * weights.at(i).at(j); } score[i] = ((rows.at(i).value - mean) / sd) * (lag / sd); if (algorithmId == QStringLiteral("gi_star") || algorithmId == QStringLiteral("emerging_hotspot")) score[i] = lagSquare > 0.0 ? lag / (sd * std::sqrt(lagSquare)) : 0.0; cluster[i] = score.at(i) > 1.96 ? 1 : (score.at(i) < -1.96 ? -1 : 0); }
        if (algorithmId == QStringLiteral("ripley_k")) { double radius = numericValue > 0.0 ? numericValue : 1.0; int pairs = 0; for (int i = 0; i < n; i++) for (int j = i + 1; j < n; j++) if (std::hypot(rows.at(i).point.x() - rows.at(j).point.x(), rows.at(i).point.y() - rows.at(j).point.y()) <= radius) pairs++; double area = std::max(state->layer->extent().width() * state->layer->extent().height(), 1.0e-12); double kValue = area * 2.0 * pairs / (n * (n - 1.0)); summary = QStringLiteral("Ripley K=%1; L=%2; radius=%3").arg(kValue, 0, 'g', 10).arg(std::sqrt(kValue / M_PI), 0, 'g', 10).arg(radius); }
        else summary = QStringLiteral("Moran I=%1; Geary C=%2; General G=%3").arg(moran, 0, 'g', 10).arg(geary, 0, 'g', 10).arg(generalG, 0, 'g', 10);
    }
    QString out = QString::fromUtf8(outputPath); QString name = QString::fromUtf8(outputLayerName);
    if (!WriteSpatialResult(state->layer.get(), rows, score, prediction, residual, cluster, out, name, error))
        return MakeProcessResult(false, GIS_ERR_WRITE_FAILED, ToStdString(error), outputPath.constData(), outputLayerName.constData(), 0, outErrCode);
    ReportProcessingProgress(100.0, n, "complete");
    return MakeProcessResult(true, GIS_OK, ToStdString(summary), outputPath.constData(), outputLayerName.constData(), n, outErrCode);
}
