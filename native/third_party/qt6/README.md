# Qt6 Native Dependency Workspace

This directory is reserved for Qt6 source, build caches, and staged OHOS
artifacts used by the QGIS Core experiment.

Expected local layout when there is enough space under the repo:

```text
native/third_party/qt6/src
native/third_party/qt6/build-ohos
native/third_party/qt6/stage
native/third_party/qt6/build-geonest-qt6-probe
```

`src`, `build-ohos`, `stage`, and `build-geonest-qt6-probe` can become large and
should stay out of normal source review. The tracked scripts and probe source
are enough to recreate the product when a Qt source tree or prebuilt Qt6/OHOS
package is available.

On machines where the project drive is tight, keep the Qt source archive,
source tree, and build cache outside the repo, for example:

```text
D:\GeoNestDeps\qt6\qt-everywhere-src-6.8.3.tar.xz
D:\GeoNestDeps\qt6\src
D:\GeoNestDeps\qt6\build-ohos
D:\GeoNestDeps\qt6\host
```

The tracked `patches` directory contains the minimal Qt 6.8.3 qtbase changes
needed for the current Core/Xml OHOS build. Apply them with
`scripts\build_native\apply_qt6_ohos_patches.ps1` after extracting a fresh Qt
source tree. The modification-notice patch marks every changed Qt file with the
change date. Every release also archives the exact patched Qt tree and its
`LICENSES` directory beside the APP/HAP; a patch set alone is not treated as
the complete corresponding source.

Then pass `-QtSource D:\GeoNestDeps\qt6\src -BuildRoot
D:\GeoNestDeps\qt6\build-ohos -HostQtPath D:\GeoNestDeps\qt6\host` to
`scripts\build_native\build_qt6_ohos.ps1`.
