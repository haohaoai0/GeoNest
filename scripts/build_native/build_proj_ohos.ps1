param(
  [string]$ProjSource = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\sources\proj-9.8.1',
  [string]$SqliteExe = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\sources\sqlite3.exe',
  [string]$StageRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\stage',
  [string]$BuildRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\build-proj-ohos',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string[]]$AbiFilters = @('arm64-v8a', 'x86_64')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ProjSource)) {
  throw "PROJ source directory not found: $ProjSource"
}
if (-not (Test-Path -LiteralPath $SqliteExe)) {
  throw "sqlite3 host executable not found: $SqliteExe"
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

  $sqliteInclude = Join-Path $stageDir 'include'
  $sqliteLib = Join-Path $stageDir 'lib\libsqlite3.so'
  if (-not (Test-Path -LiteralPath $sqliteLib)) {
    throw "SQLite must be built before PROJ. Missing: $sqliteLib"
  }

  & $cmake -S $ProjSource -B $buildDir -GNinja `
    "-DCMAKE_MAKE_PROGRAM=$ninja" `
    "-DCMAKE_TOOLCHAIN_FILE=$toolchain" `
    -DCMAKE_SYSTEM_NAME=OHOS `
    "-DCMAKE_OHOS_ARCH_ABI=$abi" `
    "-DOHOS_ARCH=$abi" `
    "-DOHOS_SDK_NATIVE=$ohosNative" `
    "-DHMOS_SDK_NATIVE=$hmosNative" `
    -DCMAKE_BUILD_TYPE=Release `
    "-DCMAKE_INSTALL_PREFIX=$stageDir" `
    "-DCMAKE_PREFIX_PATH=$stageDir" `
    "-DSQLite3_INCLUDE_DIR=$sqliteInclude" `
    "-DSQLite3_LIBRARY=$sqliteLib" `
    "-DEXE_SQLITE3=$SqliteExe" `
    -DNLOHMANN_JSON_ORIGIN=internal `
    -DENABLE_TIFF=OFF `
    -DENABLE_CURL=OFF `
    -DBUILD_TESTING=OFF `
    -DBUILD_APPS=OFF `
    -DBUILD_EXAMPLES=OFF
  if ($LASTEXITCODE -ne 0) {
    throw "PROJ configure failed for $abi"
  }

  & $cmake --build $buildDir --target install
  if ($LASTEXITCODE -ne 0) {
    throw "PROJ build failed for $abi"
  }
}
