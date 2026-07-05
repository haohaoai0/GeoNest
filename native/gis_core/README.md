# GeoNest GIS Core

This module is the native GIS core boundary for GeoNest.

Current scope:

- Provide a minimal native version probe.
- Keep the C++ API independent from ArkTS and Node-API.
- Use the same C++/Node-API boundary with either the GDAL/OGR backend or the
  QGIS Core backend.
- Build against QGIS Core with
  `-DGEONEST_USE_QGIS_CORE=ON -DQGIS_PREFIX=/path/to/qgis/stage`.

The production GIS work should stay behind stable C++ functions here. Node-API conversion belongs in `native/napi_bridge`.

Current selected backend:

- `entry/build-profile.json5` enables `GEONEST_USE_QGIS_CORE=ON`.
- `QGIS_PREFIX` points to `native/third_party/qgis/stage`.
- `QT6_PREFIX` points to `native/third_party/qt6/stage`.
- `OpenVectorLayer`, `QueryFeatures`, and `GetFeature` use
  `QgsVectorLayer` when QGIS Core is successfully staged.

QGIS Core backend status:

- `native/gis_core/src/geonest_gis_core_qgis.cpp` is wired behind
  `GEONEST_USE_QGIS_CORE=ON`.
- The local `D:\下载\QGIS-master\QGIS-master` source is QGIS 4.1.0 master and
  requires Qt6 6.4+ in its top-level CMake configuration.
- QGIS 4.1 currently requires Qt `Core`, `Gui`, `Widgets`, `Network`, `Xml`,
  `Svg`, `Concurrent`, `Test`, and `Sql`. The local Qt6/OHOS stage is still
  missing at least `Qt6Gui`, `Qt6Widgets`, and `Qt6Svg`, so `libqgis_core.so`
  is not staged yet.
- Qt5 is not a direct switch for this QGIS master tree. A Qt5 attempt should use
  a QGIS 3.x/Qt5 branch, or it becomes a larger source port.

`GDAL_PREFIX` and `QGIS_PREFIX` may point at a stage root containing ABI
subdirectories:

```text
native/third_party/qgis/stage/arm64-v8a
native/third_party/qgis/stage/x86_64
```

The CMake file automatically selects the matching ABI stage while building
`libgeonestgis.so`.
