param(
  [string]$GdalSource = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\sources\gdal-3.11.4',
  [string]$StageRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\stage',
  [string]$BuildRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\build-gdal-ohos',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string[]]$AbiFilters = @('arm64-v8a', 'x86_64')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $GdalSource)) {
  throw "GDAL source directory not found: $GdalSource"
}

$cmake = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\cmake.exe'
$ninja = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\ninja.exe'
$toolchain = Join-Path $DevEcoSdkHome 'default\hms\native\build\cmake\hmos.toolchain.cmake'
$ohosNative = Join-Path $DevEcoSdkHome 'default\openharmony\native'
$hmosNative = Join-Path $DevEcoSdkHome 'default\hms\native'

foreach ($abi in $AbiFilters) {
  $buildDir = Join-Path $BuildRoot $abi
  $stageDir = Join-Path $StageRoot $abi
  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

  $includeDir = Join-Path $stageDir 'include'
  $sqliteLib = Join-Path $stageDir 'lib\libsqlite3.so'
  $projLib = Join-Path $stageDir 'lib\libproj.so'
  $geosLib = Join-Path $stageDir 'lib\libgeos_c.so'
  $geosDir = Join-Path $stageDir 'lib\cmake\GEOS'
  $geosHeader = Join-Path $includeDir 'geos_c.h'

  if (-not (Test-Path -LiteralPath $sqliteLib)) {
    throw "SQLite must be built before GDAL. Missing: $sqliteLib"
  }
  if (-not (Test-Path -LiteralPath $projLib)) {
    throw "PROJ must be built before GDAL. Missing: $projLib"
  }
  if (-not (Test-Path -LiteralPath $geosLib)) {
    throw "GEOS must be built before GDAL. Missing: $geosLib"
  }
  if (-not (Test-Path -LiteralPath $geosHeader)) {
    throw "GEOS header not found: $geosHeader"
  }

  $geosVersionMatch = Select-String -LiteralPath $geosHeader -Pattern '^\s*#define\s+GEOS_VERSION\s+"([^"]+)"' | Select-Object -First 1
  if ($null -eq $geosVersionMatch) {
    throw "Unable to read GEOS_VERSION from: $geosHeader"
  }
  $geosVersion = $geosVersionMatch.Matches[0].Groups[1].Value

  $gdalSourceCmake = $GdalSource.Replace('\', '/')
  $buildDirCmake = $buildDir.Replace('\', '/')
  $stageDirCmake = $stageDir.Replace('\', '/')
  $cmakeCmake = $cmake.Replace('\', '/')
  $ninjaCmake = $ninja.Replace('\', '/')
  $toolchainCmake = $toolchain.Replace('\', '/')
  $ohosNativeCmake = $ohosNative.Replace('\', '/')
  $hmosNativeCmake = $hmosNative.Replace('\', '/')
  $includeDirCmake = $includeDir.Replace('\', '/')
  $sqliteLibCmake = $sqliteLib.Replace('\', '/')
  $projLibCmake = $projLib.Replace('\', '/')
  $geosLibCmake = $geosLib.Replace('\', '/')
  $geosDirCmake = $geosDir.Replace('\', '/')

  & $cmakeCmake -S $gdalSourceCmake -B $buildDirCmake -GNinja `
    "-USQLite3_HAS_*" `
    "-DCMAKE_MAKE_PROGRAM=$ninjaCmake" `
    "-DCMAKE_TOOLCHAIN_FILE=$toolchainCmake" `
    -DCMAKE_SYSTEM_NAME=OHOS `
    "-DCMAKE_OHOS_ARCH_ABI=$abi" `
    "-DOHOS_ARCH=$abi" `
    "-DOHOS_SDK_NATIVE=$ohosNativeCmake" `
    "-DHMOS_SDK_NATIVE=$hmosNativeCmake" `
    -DCMAKE_BUILD_TYPE=Release `
    "-DCMAKE_INSTALL_PREFIX=$stageDirCmake" `
    "-DCMAKE_PREFIX_PATH=$stageDirCmake" `
    -DBUILD_SHARED_LIBS=ON `
    -DBUILD_TESTING=OFF `
    -DBUILD_PYTHON_BINDINGS=OFF `
    -DBUILD_APPS=OFF `
    -DGDAL_BUILD_OPTIONAL_DRIVERS=OFF `
    -DOGR_BUILD_OPTIONAL_DRIVERS=OFF `
    -DGDAL_ENABLE_DRIVER_GTIFF=OFF `
    -DGDAL_ENABLE_DRIVER_MEM=ON `
    -DGDAL_ENABLE_DRIVER_RAW=ON `
    -DGDAL_ENABLE_DRIVER_VRT=ON `
    -DOGR_ENABLE_DRIVER_GEOJSON=ON `
    -DOGR_ENABLE_DRIVER_GPKG=ON `
    -DOGR_ENABLE_DRIVER_MEM=ON `
    -DOGR_ENABLE_DRIVER_SHAPE=ON `
    -DOGR_ENABLE_DRIVER_SQLITE=ON `
    -DOGR_ENABLE_DRIVER_VRT=ON `
    -DGDAL_USE_EXTERNAL_LIBS=ON `
    -DGDAL_USE_INTERNAL_LIBS=WHEN_NO_EXTERNAL `
    -DGDAL_FIND_PACKAGE_PROJ_MODE=MODULE `
    -DGDAL_USE_PROJ=ON `
    "-DPROJ_INCLUDE_DIR=$includeDirCmake" `
    "-DPROJ_LIBRARY=$projLibCmake" `
    -DGDAL_USE_GEOS=ON `
    "-DGEOS_DIR=$geosDirCmake" `
    "-DGEOS_VERSION=$geosVersion" `
    "-DGEOS_INCLUDE_DIR=$includeDirCmake" `
    "-DGEOS_LIBRARY=$geosLibCmake" `
    -DGDAL_USE_SQLITE3=ON `
    "-DSQLite3_INCLUDE_DIR=$includeDirCmake" `
    "-DSQLite3_LIBRARY=$sqliteLibCmake" `
    -DGDAL_USE_CURL=OFF `
    -DGDAL_USE_EXPAT=OFF `
    -DGDAL_USE_ICONV=OFF `
    -DGDAL_USE_LIBXML2=OFF `
    -DGDAL_USE_OPENSSL=OFF `
    -DGDAL_USE_PCRE2=OFF `
    -DGDAL_USE_SPATIALITE=OFF `
    -DGDAL_USE_TIFF=OFF
  if ($LASTEXITCODE -ne 0) {
    throw "GDAL configure failed for $abi"
  }

  & $cmakeCmake --build $buildDirCmake --target install
  if ($LASTEXITCODE -ne 0) {
    throw "GDAL build failed for $abi"
  }
}
