# QGIS Core Probe

This directory is an opt-in experiment for using QGIS C++ Core code behind the
GeoNest native GIS boundary.

It is not enabled in the production HAP build by default. The app can build
`libgeonestgis.so` against QGIS Core by passing
`-DGEONEST_USE_QGIS_CORE=ON -DQGIS_PREFIX=/path/to/qgis/stage` to
`entry/src/main/cpp/CMakeLists.txt`.

## Why This Is Separate

- QGIS is distributed under the GNU GPL. If GeoNest ships QGIS-derived or
  QGIS-linked code, the app distribution must be managed on a GPL-compatible
  path.
- QGIS Core is not a small standalone Shapefile parser. It depends on Qt,
  GDAL/OGR, GEOS, PROJ, and provider infrastructure.
- HarmonyOS NDK support must be proven before replacing the current native
  backend.

Official references:

- QGIS license: https://qgis.org/license/
- QGIS build instructions: https://github.com/qgis/QGIS/blob/master/INSTALL.md

## Probe Goal

The first probe target is intentionally small:

1. Start `QgsApplication`.
2. Open a vector layer through `QgsVectorLayer` and the OGR provider.
3. Read layer metadata, fields, extent, CRS, and a few features.
4. Exit cleanly without exposing QGIS objects to ArkTS.

If this works with the target native toolchain, the result can be adapted into
`native/gis_core` while keeping the existing C ABI and Node-API bridge stable.

## Expected Layout

Do not vendor a full QGIS checkout into the app source tree by default. Use a
separate dependency workspace or the ignored path below:

```text
native/third_party/qgis/QGIS
native/third_party/qgis/stage
```

`stage` should contain a QGIS install or staged build with headers and
libraries. GeoNest's HAP build expects ABI-specific stages:

```text
stage/arm64-v8a/include/qgis/qgsapplication.h
stage/arm64-v8a/lib/libqgis_core.so
stage/x86_64/include/qgis/qgsapplication.h
stage/x86_64/lib/libqgis_core.so
```

## Configure Example

```powershell
cmake -S native/qgis_core_probe `
  -B output/qgis_core_probe `
  -DQGIS_PREFIX=F:/HarmonyProjects/GeoNest/native/third_party/qgis/stage `
  -DCMAKE_PREFIX_PATH=F:/HarmonyProjects/GeoNest/native/third_party/qgis/stage

cmake --build output/qgis_core_probe
```

Run the probe with a local vector file:

```powershell
output/qgis_core_probe/geonest_qgis_vector_probe.exe `
  entry/src/main/resources/rawfile/landuse.shp
```

For HarmonyOS, the same source should be configured with the HarmonyOS NDK
toolchain after Qt and QGIS Core have been cross-compiled or otherwise staged.

## Promotion Criteria

Move this from probe to production only after all items are true:

- QGIS Core, Qt, GDAL, GEOS, and PROJ build for every target ABI.
- The resulting native libraries are small enough for the HAP target.
- App licensing and source distribution are prepared for GPL obligations.
- Startup, open-layer, query-feature, and shutdown behavior are stable.
- The ArkTS-facing JSON contract remains compatible with `GisNativeBridge.ets`.
