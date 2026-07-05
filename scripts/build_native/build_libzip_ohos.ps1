param(
  [string]$LibZipSource = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\sources\libzip-1.11.4',
  [string]$StageRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\stage',
  [string]$BuildRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\build-libzip-ohos',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string[]]$AbiFilters = @('arm64-v8a', 'x86_64')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $LibZipSource)) {
  throw "LibZip source directory not found: $LibZipSource"
}

$cmake = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\cmake.exe'
$ninja = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\ninja.exe'
$toolchain = Join-Path $DevEcoSdkHome 'default\hms\native\build\cmake\hmos.toolchain.cmake'
$ohosNative = Join-Path $DevEcoSdkHome 'default\openharmony\native'
$hmosNative = Join-Path $DevEcoSdkHome 'default\hms\native'
$zlibInclude = Join-Path $DevEcoSdkHome 'default\openharmony\native\sysroot\usr\include'

foreach ($abi in $AbiFilters) {
  $buildDir = Join-Path $BuildRoot $abi
  $stageDir = Join-Path $StageRoot $abi
  $zlibLib = Join-Path $DevEcoSdkHome "default\openharmony\native\sysroot\usr\lib\aarch64-linux-ohos\libz.so"
  if ($abi -eq 'x86_64') {
    $zlibLib = Join-Path $DevEcoSdkHome "default\openharmony\native\sysroot\usr\lib\x86_64-linux-ohos\libz.so"
  }

  if (-not (Test-Path -LiteralPath $zlibLib)) {
    throw "ZLIB library not found for ${abi}: $zlibLib"
  }

  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
  New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

  $libZipSourceCmake = $LibZipSource.Replace('\', '/')
  $buildDirCmake = $buildDir.Replace('\', '/')
  $stageDirCmake = $stageDir.Replace('\', '/')
  $cmakeCmake = $cmake.Replace('\', '/')
  $ninjaCmake = $ninja.Replace('\', '/')
  $toolchainCmake = $toolchain.Replace('\', '/')
  $ohosNativeCmake = $ohosNative.Replace('\', '/')
  $hmosNativeCmake = $hmosNative.Replace('\', '/')
  $zlibIncludeCmake = $zlibInclude.Replace('\', '/')
  $zlibLibCmake = $zlibLib.Replace('\', '/')

  & $cmakeCmake -S $libZipSourceCmake -B $buildDirCmake -GNinja `
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
    -DBUILD_DOC=OFF `
    -DBUILD_EXAMPLES=OFF `
    -DBUILD_OSSFUZZ=OFF `
    -DBUILD_REGRESS=OFF `
    -DBUILD_TOOLS=OFF `
    -DENABLE_BZIP2=OFF `
    -DENABLE_COMMONCRYPTO=OFF `
    -DENABLE_GNUTLS=OFF `
    -DENABLE_LZMA=OFF `
    -DENABLE_MBEDTLS=OFF `
    -DENABLE_OPENSSL=OFF `
    -DENABLE_WINDOWS_CRYPTO=OFF `
    -DENABLE_ZSTD=OFF `
    "-DZLIB_INCLUDE_DIR=$zlibIncludeCmake" `
    "-DZLIB_LIBRARY=$zlibLibCmake"
  if ($LASTEXITCODE -ne 0) {
    throw "LibZip configure failed for $abi"
  }

  & $cmakeCmake --build $buildDirCmake --target install
  if ($LASTEXITCODE -ne 0) {
    throw "LibZip build failed for $abi"
  }
}
