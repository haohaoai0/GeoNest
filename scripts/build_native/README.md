# Native Build Scripts

This directory is reserved for repeatable native dependency builds.

Dependency order:

1. zlib
2. sqlite
3. libexpat
4. PROJ
5. GEOS
6. GDAL/OGR
7. Qt6 Core/Gui/Widgets/Network/Xml/Svg/Concurrent/Test/Sql for OHOS
8. QGIS Core
9. GeoNest native bridge

Current selected HAP backend:

- `entry/build-profile.json5` enables `GEONEST_USE_QGIS_CORE=ON`.
- `QGIS_PREFIX` points to `native/third_party/qgis/stage`.
- `QT6_PREFIX` points to `native/third_party/qt6/stage`.
- `entry/src/main/cpp/CMakeLists.txt` selects `stage/<abi>` automatically and
  copies the runtime libraries beside `libgeonestgis.so`.
- This backend will not configure until `libqgis_core.so`, QGIS headers, and
  the required Qt components are staged for every ABI.

Fallback GDAL backend:

- Passing `-DGEONEST_USE_GDAL=ON -DGDAL_PREFIX=...` still selects the GDAL/OGR
  implementation.
- `build_gdal_ohos.ps1` builds GDAL/OGR 3.11.4 with the minimal vector driver
  set used by GeoNest: Shapefile, GeoJSON, SQLite, GeoPackage, VRT, MEM, plus
  PROJ and GEOS support.

QGIS Core backend:

- Use `prepare_qgis_source.ps1` to create a sparse QGIS source checkout under the ignored `native/third_party/qgis` path.
- Build or stage Qt + QGIS Core separately.
- Configure `native/qgis_core_probe` with `-DQGIS_PREFIX=...`.
- Shipping QGIS-linked code needs a GPL-compatible distribution plan.

Current QGIS backend wiring and blocker:

- `QGIS_PREFIX` points to `native/third_party/qgis/stage`.
- The HAP CMake selects `stage/<abi>` automatically.
- `build_qgis_core_ohos.ps1` configures a minimal QGIS Core build from
  `D:\下载\QGIS-master\QGIS-master`.
- The local QGIS master tree is QGIS 4.1.0 and currently requires Qt6 6.4+.
  Its top-level CMake requires `Core`, `Gui`, `Widgets`, `Network`, `Xml`,
  `Svg`, `Concurrent`, `Test`, and `Sql`, even when `WITH_GUI=OFF`.
- The current Qt6/OHOS stage is still missing at least `Qt6Gui`,
  `Qt6Widgets`, and `Qt6Svg`, so QGIS Core cannot be installed yet.
- Qt5 may still be worth testing through a QGIS 3.x/Qt5 source branch, but this
  master tree is not Qt5-ready by a simple CMake flag.

Before running the QGIS build script, the machine needs Flex/Bison and the QGIS
Core dependency stack staged for HarmonyOS: Qt, PROJ, GEOS, GDAL, EXPAT,
LibZip, nlohmann-json, SQLite, Protobuf, and ZLIB.

Qt6/OHOS product path:

- `apply_qt6_ohos_patches.ps1`: applies the minimal Qt 6.8.3/OpenHarmony
  qtbase patches tracked under `native/third_party/qt6/patches`. These patches
  are based on the Qt5/OpenHarmony reference direction but kept to Core-level
  OHOS/musl differences needed by this experiment.

  ```powershell
  .\scripts\build_native\apply_qt6_ohos_patches.ps1 -QtSource D:\GeoNestDeps\qt6\src
  ```

- `build_qt6_host_tools.ps1`: builds a same-version host Qt from the Qt6 source
  tree if no host Qt is available. Qt cross-builds need these host tools before
  the OHOS target configure. On this machine the VS C++ install is incomplete,
  so the working host tools came from Qt's official 6.8.3
  `win64_msvc2022_64` qtbase package extracted to `D:\GeoNestDeps\qt6\host`.
  If a complete host compiler is available, with the current D: layout:

  ```powershell
  .\scripts\build_native\build_qt6_host_tools.ps1
  ```

- `build_qt6_ohos.ps1`: stages Qt6 from a Qt source tree plus a same-version
  host Qt build into `native/third_party/qt6/stage/<abi>`.
  The script defaults `-QtTargetMkspec linux-clang` because upstream Qt6 does
  not ship an OpenHarmony mkspec. The Qt5/OpenHarmony reference port adds an
  `oh-clang` mkspec plus QPA/ArkTS bridge patches; those are still required for
  a full GUI port. DevEco clang already defines `__OHOS__`; the script adds
  `OPENHARMONY` but intentionally does not force `__MUSL__`, because upstream
  Qt6 uses that macro to select libc-internal symbols that OHOS does not export.
- If the project drive does not have enough space for Qt source/build caches,
  place them on D: and pass explicit paths:

  ```powershell
  .\scripts\build_native\build_qt6_ohos.ps1 `
    -QtSource D:\GeoNestDeps\qt6\src `
    -BuildRoot D:\GeoNestDeps\qt6\build-ohos `
    -HostQtPath D:\GeoNestDeps\qt6\host
  ```

- `build_qt6_ohos_probe.ps1`: builds `native/qt6_ohos_probe` against the staged
  Qt to prove `Qt6::Core` and `Qt6::Xml` can link with the HarmonyOS toolchain.
- The probe output is
  `native/third_party/qt6/build-geonest-qt6-probe/<abi>/libgeonestqt6probe.so`.

Dependency scripts currently added:

- `build_sqlite_ohos.ps1`: builds SQLite amalgamation into `stage/<abi>`.
- `build_proj_ohos.ps1`: builds PROJ into `stage/<abi>` after SQLite.
- `build_geos_ohos.ps1`: builds GEOS into `stage/<abi>`.
- `build_gdal_ohos.ps1`: builds the default GDAL/OGR backend into `stage/<abi>`.
- `build_expat_ohos.ps1`: builds EXPAT for the optional QGIS Core route.
- `build_libzip_ohos.ps1`: builds LibZip for the optional QGIS Core route.
- `build_protobuf_ohos.ps1`: builds Protobuf for the optional QGIS Core route.
