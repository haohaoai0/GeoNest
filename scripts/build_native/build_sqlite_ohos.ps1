param(
  [string]$SourceZip = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\sources\sqlite-amalgamation-3450300.zip',
  [string]$StageRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\stage',
  [string]$BuildRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\build-sqlite-ohos',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string[]]$AbiFilters = @('arm64-v8a', 'x86_64')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceZip)) {
  throw "SQLite source zip not found: $SourceZip"
}

$sourceRoot = Split-Path -Parent $SourceZip
$sqliteDir = Join-Path $sourceRoot 'sqlite-amalgamation-3450300'
if (-not (Test-Path -LiteralPath $sqliteDir)) {
  Expand-Archive -LiteralPath $SourceZip -DestinationPath $sourceRoot -Force
}

$cmake = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\cmake.exe'
$ninja = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\ninja.exe'
$toolchain = Join-Path $DevEcoSdkHome 'default\hms\native\build\cmake\hmos.toolchain.cmake'
$ohosNative = Join-Path $DevEcoSdkHome 'default\openharmony\native'
$hmosNative = Join-Path $DevEcoSdkHome 'default\hms\native'
$sqliteCmake = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\cmake\sqlite'

foreach ($abi in $AbiFilters) {
  $buildDir = Join-Path $BuildRoot $abi
  $stageDir = Join-Path $StageRoot $abi
  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
  New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

  & $cmake -S $sqliteCmake -B $buildDir -GNinja `
    "-DCMAKE_MAKE_PROGRAM=$ninja" `
    "-DCMAKE_TOOLCHAIN_FILE=$toolchain" `
    -DCMAKE_SYSTEM_NAME=OHOS `
    "-DCMAKE_OHOS_ARCH_ABI=$abi" `
    "-DOHOS_ARCH=$abi" `
    "-DOHOS_SDK_NATIVE=$ohosNative" `
    "-DHMOS_SDK_NATIVE=$hmosNative" `
    -DCMAKE_BUILD_TYPE=Release `
    "-DCMAKE_INSTALL_PREFIX=$stageDir" `
    "-DSQLITE_AMALGAMATION_DIR=$sqliteDir"

  & $cmake --build $buildDir --target install
}
