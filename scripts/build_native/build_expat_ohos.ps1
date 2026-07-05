param(
  [string]$ExpatSource = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\sources\expat-2.7.1',
  [string]$StageRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\stage',
  [string]$BuildRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\build-expat-ohos',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string[]]$AbiFilters = @('arm64-v8a', 'x86_64')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ExpatSource)) {
  throw "EXPAT source directory not found: $ExpatSource"
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

  $expatSourceCmake = $ExpatSource.Replace('\', '/')
  $buildDirCmake = $buildDir.Replace('\', '/')
  $stageDirCmake = $stageDir.Replace('\', '/')
  $cmakeCmake = $cmake.Replace('\', '/')
  $ninjaCmake = $ninja.Replace('\', '/')
  $toolchainCmake = $toolchain.Replace('\', '/')
  $ohosNativeCmake = $ohosNative.Replace('\', '/')
  $hmosNativeCmake = $hmosNative.Replace('\', '/')

  & $cmakeCmake -S $expatSourceCmake -B $buildDirCmake -GNinja `
    "-DCMAKE_MAKE_PROGRAM=$ninjaCmake" `
    "-DCMAKE_TOOLCHAIN_FILE=$toolchainCmake" `
    -DCMAKE_SYSTEM_NAME=OHOS `
    "-DCMAKE_OHOS_ARCH_ABI=$abi" `
    "-DOHOS_ARCH=$abi" `
    "-DOHOS_SDK_NATIVE=$ohosNativeCmake" `
    "-DHMOS_SDK_NATIVE=$hmosNativeCmake" `
    -DCMAKE_BUILD_TYPE=Release `
    "-DCMAKE_INSTALL_PREFIX=$stageDirCmake" `
    -DBUILD_SHARED_LIBS=ON `
    -DEXPAT_SHARED_LIBS=ON `
    -DEXPAT_BUILD_DOCS=OFF `
    -DEXPAT_BUILD_EXAMPLES=OFF `
    -DEXPAT_BUILD_PKGCONFIG=ON `
    -DEXPAT_BUILD_TESTS=OFF `
    -DEXPAT_BUILD_TOOLS=OFF
  if ($LASTEXITCODE -ne 0) {
    throw "EXPAT configure failed for $abi"
  }

  & $cmakeCmake --build $buildDirCmake --target install
  if ($LASTEXITCODE -ne 0) {
    throw "EXPAT build failed for $abi"
  }
}
