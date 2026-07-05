# GeoNest Node-API Bridge

This module converts ArkTS calls into stable native GIS calls.

Current scope:

- Register `libgeonestgis.so`.
- Export `getNativeVersion()` and `getCoreProfile()` for the first ArkTS-to-C++ probe.

Later GIS APIs should keep large feature data paged and simplified before crossing the Node-API boundary.
