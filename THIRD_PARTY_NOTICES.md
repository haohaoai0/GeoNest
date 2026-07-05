# GeoNest Third-Party Notices

GeoNest 1.0.0 includes or links the components below. The corresponding
source release contains each component's complete license and copyright
notices. Nothing in this file replaces those license texts.

| Component | Version used | License |
| --- | --- | --- |
| QGIS Core | 4.1.0 development snapshot | GPL-2.0-or-later with QGIS Qt linking exception |
| Qt | 6.8.3 | LGPL-3.0-only/GPL; commercial terms apply only when separately licensed |
| GDAL/OGR | 3.11.4 | MIT-style and bundled component notices |
| GEOS | 3.13.1 | LGPL-2.1-or-later |
| PROJ | 9.8.1 | MIT |
| SQLite | 3.45.3 amalgamation | Public domain |
| Expat | 2.7.1 | MIT |
| Protocol Buffers | 3.20.3 | BSD-3-Clause |
| Zstandard | 1.5.7 | BSD-3-Clause |
| libzip | 1.11.4 | BSD-3-Clause |
| QtKeychain | 0.14.x source snapshot | BSD-3-Clause |

## QGIS

QGIS is copyright its contributors and is distributed under GNU GPL
version 2 or, at the recipient's option, a later version.

The QGIS Development Team additionally permits QGIS code to be linked
with free or commercial Qt versions and the linked combination to be
distributed. The GNU GPL remains applicable to all code in that
combination other than Qt. The authoritative exception is the
`Exception_to_GPL_for_Qt.txt` file in the accompanying QGIS source
archive.

GeoNest modifies QGIS for HarmonyOS packaging. At minimum,
`src/core/CMakeLists.txt` was changed so OHOS receives an unversioned
`libqgis_core.so`. The exact modified QGIS source tree, rather than only
an upstream link, is included in every corresponding-source release.

## Qt and GEOS relinking rights

The release uses dynamically linked Qt and GEOS shared libraries. A
recipient may replace those libraries with compatible modified builds.
GeoNest does not prohibit reverse engineering performed solely for
debugging modifications to LGPL-covered libraries.

The corresponding-source release supplies the exact Qt and GEOS source
trees used by the distributed binaries, including GeoNest's Qt/OHOS
patches and the scripts used to build them.

## Permissive-license notices

Expat is copyright (c) 1998-2000 Thai Open Source Software Center Ltd
and Clark Cooper, and copyright (c) 2001-2025 Expat maintainers.

Protocol Buffers is copyright 2008 Google Inc. All rights reserved.

Zstandard is copyright (c) Meta Platforms, Inc. and affiliates.

libzip is copyright (C) 1999-2020 Dieter Baron and Thomas Klausner.

The permissive components are provided "AS IS", without warranty of any
kind. Their complete copyright, permission, condition, and disclaimer
texts are retained in their source archives. GDAL's complete
`LICENSE.TXT`, including notices for enabled bundled code, is included
unchanged.

## Source and authoritative texts

The binary release directory contains:

- `LICENSE`, `COPYING`, this notice, and `SOURCE_OFFER.txt`;
- `GeoNest-<version>-corresponding-source.tar.gz`;
- `QGIS-<version>-geonest-source.tar.gz`;
- `Qt-6.8.3-geonest-source.tar.gz`;
- `GeoNest-native-dependencies-source.tar.gz`;
- `SOURCE-SHA256SUMS.txt` and `SOURCE-MANIFEST.txt`.

Those source archives contain the authoritative license texts shipped by
each upstream project.
