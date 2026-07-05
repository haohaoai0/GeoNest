# Third-Party Native Dependencies

This directory is reserved for small metadata, patches, and build notes for native GIS dependencies.

Do not put large source trees or build caches here until disk usage is planned. The F drive currently hosts the app project, but GDAL/GEOS/PROJ build outputs can become large.

QGIS/OSGeo source and build outputs are intentionally ignored by `.gitignore`.
The current production GDAL/OGR backend and the optional QGIS Core experiment
share this ignored stage root:

```text
native/third_party/qgis/QGIS
native/third_party/qgis/stage
```

The staged ABI directories currently provide GDAL/OGR, PROJ, GEOS, and SQLite
for `arm64-v8a` and `x86_64`.

Qt6/OHOS source and build products should use the separate ignored workspace:

```text
native/third_party/qt6/src
native/third_party/qt6/build-ohos
native/third_party/qt6/stage
```

`native/qt6_ohos_probe` is the small tracked verification target for staged
Qt6/OHOS libraries.

Directly shipping QGIS-linked code means the app must follow a GPL-compatible
distribution strategy.

The current HAP uses the GDAL/OGR backend by default. QGIS Core source wiring is
present, but the local QGIS master tree requires Qt6; Qt5 testing should be done
against a QGIS 3.x/Qt5 branch instead of expecting this master branch to accept a
Qt5 switch.
