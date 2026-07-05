param(
  [string]$GeosSource = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\sources\geos-3.13.1',
  [string]$StageRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\stage',
  [string]$BuildRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\build-geos-ohos',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string[]]$AbiFilters = @('arm64-v8a', 'x86_64')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $GeosSource)) {
  throw "GEOS source directory not found: $GeosSource"
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
  New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

  & $cmake -S $GeosSource -B $buildDir -GNinja `
    "-DCMAKE_MAKE_PROGRAM=$ninja" `
    "-DCMAKE_TOOLCHAIN_FILE=$toolchain" `
    -DCMAKE_SYSTEM_NAME=OHOS `
    "-DCMAKE_OHOS_ARCH_ABI=$abi" `
    "-DOHOS_ARCH=$abi" `
    "-DOHOS_SDK_NATIVE=$ohosNative" `
    "-DHMOS_SDK_NATIVE=$hmosNative" `
    -DCMAKE_BUILD_TYPE=Release `
    "-DCMAKE_INSTALL_PREFIX=$stageDir" `
    -DBUILD_SHARED_LIBS=ON `
    -DBUILD_TESTING=OFF `
    -DBUILD_BENCHMARKS=OFF
  if ($LASTEXITCODE -ne 0) {
    throw "GEOS configure failed for $abi"
  }

  & $cmake --build $buildDir --target install
  if ($LASTEXITCODE -ne 0) {
    throw "GEOS build failed for $abi"
  }
}
