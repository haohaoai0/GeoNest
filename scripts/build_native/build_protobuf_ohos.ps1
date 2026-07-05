param(
  [string]$ProtobufSource = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\sources\protobuf-3.20.3',
  [string]$StageRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\stage',
  [string]$BuildRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\build-protobuf-ohos',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string[]]$AbiFilters = @('arm64-v8a', 'x86_64')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ProtobufSource)) {
  throw "Protobuf source directory not found: $ProtobufSource"
}

$protobufCmakeSource = Join-Path $ProtobufSource 'cmake'
if (-not (Test-Path -LiteralPath $protobufCmakeSource)) {
  throw "Protobuf CMake source directory not found: $protobufCmakeSource"
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

  $protobufCmakeSourceCmake = $protobufCmakeSource.Replace('\', '/')
  $buildDirCmake = $buildDir.Replace('\', '/')
  $stageDirCmake = $stageDir.Replace('\', '/')
  $cmakeCmake = $cmake.Replace('\', '/')
  $ninjaCmake = $ninja.Replace('\', '/')
  $toolchainCmake = $toolchain.Replace('\', '/')
  $ohosNativeCmake = $ohosNative.Replace('\', '/')
  $hmosNativeCmake = $hmosNative.Replace('\', '/')

  & $cmakeCmake -S $protobufCmakeSourceCmake -B $buildDirCmake -GNinja `
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
    -Dprotobuf_BUILD_SHARED_LIBS=ON `
    -Dprotobuf_BUILD_CONFORMANCE=OFF `
    -Dprotobuf_BUILD_EXAMPLES=OFF `
    -Dprotobuf_BUILD_LIBPROTOC=OFF `
    -Dprotobuf_BUILD_PROTOC_BINARIES=OFF `
    -Dprotobuf_BUILD_TESTS=OFF `
    -Dprotobuf_WITH_ZLIB=OFF
  if ($LASTEXITCODE -ne 0) {
    throw "Protobuf configure failed for $abi"
  }

  & $cmakeCmake --build $buildDirCmake --target install
  if ($LASTEXITCODE -ne 0) {
    throw "Protobuf build failed for $abi"
  }
}
