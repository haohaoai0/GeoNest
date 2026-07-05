param(
  [string]$ZstdSource = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\sources\zstd-1.5.7',
  [string]$StageRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\stage',
  [string]$BuildRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\build-zstd-ohos',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string[]]$AbiFilters = @('arm64-v8a', 'x86_64')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ZstdSource)) {
  throw "Zstd source directory not found: $ZstdSource"
}

$zstdCmakeSource = Join-Path $ZstdSource 'build\cmake'
if (-not (Test-Path -LiteralPath $zstdCmakeSource)) {
  throw "Zstd CMake source directory not found: $zstdCmakeSource"
}

$cmake = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\cmake.exe'
$ninja = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\ninja.exe'
$toolchain = Join-Path $DevEcoSdkHome 'default\hms\native\build\cmake\hmos.toolchain.cmake'
$ohosNative = Join-Path $DevEcoSdkHome 'default\openharmony\native'
$hmosNative = Join-Path $DevEcoSdkHome 'default\hms\native'

foreach ($path in @($cmake, $ninja, $toolchain, $ohosNative, $hmosNative)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Required DevEco native path not found: $path"
  }
}

foreach ($abi in $AbiFilters) {
  $buildDir = Join-Path $BuildRoot $abi
  $stageDir = Join-Path $StageRoot $abi
  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
  New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

  $zstdCmakeSourceCmake = $zstdCmakeSource.Replace('\', '/')
  $buildDirCmake = $buildDir.Replace('\', '/')
  $stageDirCmake = $stageDir.Replace('\', '/')
  $cmakeCmake = $cmake.Replace('\', '/')
  $ninjaCmake = $ninja.Replace('\', '/')
  $toolchainCmake = $toolchain.Replace('\', '/')
  $ohosNativeCmake = $ohosNative.Replace('\', '/')
  $hmosNativeCmake = $hmosNative.Replace('\', '/')

  & $cmakeCmake -S $zstdCmakeSourceCmake -B $buildDirCmake -GNinja `
    "-DCMAKE_MAKE_PROGRAM=$ninjaCmake" `
    "-DCMAKE_TOOLCHAIN_FILE=$toolchainCmake" `
    -DCMAKE_SYSTEM_NAME=OHOS `
    "-DCMAKE_OHOS_ARCH_ABI=$abi" `
    "-DOHOS_ARCH=$abi" `
    "-DOHOS_SDK_NATIVE=$ohosNativeCmake" `
    "-DHMOS_SDK_NATIVE=$hmosNativeCmake" `
    -DCMAKE_BUILD_TYPE=Release `
    "-DCMAKE_INSTALL_PREFIX=$stageDirCmake" `
    -DZSTD_BUILD_SHARED=ON `
    -DZSTD_BUILD_STATIC=OFF `
    -DZSTD_BUILD_DICTBUILDER=OFF `
    -DZSTD_BUILD_PROGRAMS=OFF `
    -DZSTD_BUILD_TESTS=OFF `
    -DZSTD_LEGACY_SUPPORT=OFF
  if ($LASTEXITCODE -ne 0) {
    throw "Zstd configure failed for $abi"
  }

  & $cmakeCmake --build $buildDirCmake --target install
  if ($LASTEXITCODE -ne 0) {
    throw "Zstd build failed for $abi"
  }
}
