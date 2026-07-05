# Qt6/OHOS Probe

This probe defines the first concrete Qt6/OHOS product for GeoNest: a small
OHOS shared library linked against `Qt6::Core` and `Qt6::Xml`.

It is intentionally separate from the production HAP and QGIS Core path. The
goal is to prove the staged Qt6 libraries are usable by the HarmonyOS native
toolchain before QGIS Core is linked.

## Expected Qt Stage

`scripts/build_native/build_qt6_ohos.ps1` installs Qt into ABI-specific
directories:

```text
native/third_party/qt6/stage/arm64-v8a
native/third_party/qt6/stage/x86_64
```

Each ABI stage must contain at least:

```text
lib/libQt6Core.so
lib/libQt6Xml.so
lib/cmake/Qt6/Qt6Config.cmake
```

`lib64` is also accepted when a Qt build installs CMake packages and shared
libraries there.

## Build

First stage Qt6 from a Qt source tree and a host Qt build of the same version:

```powershell
scripts/build_native/build_qt6_ohos.ps1 `
  -QtSource D:\deps\qt-everywhere-src-6.8.3 `
  -HostQtPath C:\Qt\6.8.3\msvc2022_64
```

Then build the probe:

```powershell
scripts/build_native/build_qt6_ohos_probe.ps1
```

Expected probe output:

```text
native/third_party/qt6/build-geonest-qt6-probe/<abi>/libgeonestqt6probe.so
```

If the Qt configure step fails on `-no-feature-*` arguments, pass a different
`-ExtraConfigureArgs` list that matches the patched Qt/OHOS source tree being
used.
