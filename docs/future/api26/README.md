# API 26 material restoration

`MaterialStyleApi26.ets` is intentionally outside `entry/src`, so the API 24
compiler bundled with DevEco Studio 6.1.1 does not resolve `uiMaterial`.

When a toolchain with API 26 support is adopted:

1. Move the implementation into `entry/src/main/ets`.
2. Restore `systemMaterial: MaterialStyleApi26.nativeMaterial()` in the
   `bindSheet` options that currently use `blurStyle`.
3. Gate construction and use by the runtime distribution OS API level so
   devices below API 26 continue using the existing blur fallback.
4. Build with the API 26 SDK while keeping the required lower
   `compatibleSdkVersion`.

An app built only with the API 24 SDK cannot activate API 26 symbols after a
device OS upgrade; a package compiled with API 26 support is required.
