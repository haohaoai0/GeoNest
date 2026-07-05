param(
  [string]$QtKeychainSource = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\sources\qtkeychain',
  [string]$QtStageRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qt6\stage',
  [string]$StageRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\stage',
  [string]$BuildRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\build-qtkeychain-ohos',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string[]]$AbiFilters = @('arm64-v8a', 'x86_64'),
  [switch]$ConfigureOnly
)

$ErrorActionPreference = 'Stop'

function Require-Path {
  param(
    [string]$Path,
    [string]$Label
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "$Label not found: $Path"
  }
}

function Convert-ToCMakePath {
  param([string]$Path)
  return $Path.Replace('\', '/')
}

Require-Path $QtKeychainSource 'QtKeychain source'

$cmake = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\cmake.exe'
$ninja = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\ninja.exe'
$toolchain = Join-Path $DevEcoSdkHome 'default\hms\native\build\cmake\hmos.toolchain.cmake'
$ohosNative = Join-Path $DevEcoSdkHome 'default\openharmony\native'
$hmosNative = Join-Path $DevEcoSdkHome 'default\hms\native'

foreach ($path in @($cmake, $ninja, $toolchain, $ohosNative, $hmosNative)) {
  Require-Path $path 'Required DevEco native path'
}

$cmakeCmake = Convert-ToCMakePath $cmake
$ninjaCmake = Convert-ToCMakePath $ninja
$toolchainCmake = Convert-ToCMakePath $toolchain
$ohosNativeCmake = Convert-ToCMakePath $ohosNative
$hmosNativeCmake = Convert-ToCMakePath $hmosNative
$sourceCmake = Convert-ToCMakePath $QtKeychainSource

foreach ($abi in $AbiFilters) {
  $buildDir = Join-Path $BuildRoot $abi
  $stageDir = Join-Path $StageRoot $abi
  $qtStageDir = Join-Path $QtStageRoot $abi
  $qt6Dir = Join-Path $qtStageDir 'lib\cmake\Qt6'
  $qt6CoreDir = Join-Path $qtStageDir 'lib\cmake\Qt6Core'
  $qt6DBusDir = Join-Path $qtStageDir 'lib\cmake\Qt6DBus'
  $qt6CoreToolsDir = Join-Path $qtStageDir 'lib\cmake\Qt6CoreTools'
  $qt6DBusToolsDir = Join-Path $qtStageDir 'lib\cmake\Qt6DBusTools'

  foreach ($path in @($stageDir, $qt6Dir, $qt6CoreDir, $qt6DBusDir)) {
    Require-Path $path "Required QtKeychain path for $abi"
  }

  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
  New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

  $buildDirCmake = Convert-ToCMakePath $buildDir
  $stageDirCmake = Convert-ToCMakePath $stageDir
  $qtStageDirCmake = Convert-ToCMakePath $qtStageDir
  $qt6DirCmake = Convert-ToCMakePath $qt6Dir
  $qt6CoreDirCmake = Convert-ToCMakePath $qt6CoreDir
  $qt6DBusDirCmake = Convert-ToCMakePath $qt6DBusDir
  $qt6CoreToolsDirCmake = Convert-ToCMakePath $qt6CoreToolsDir
  $qt6DBusToolsDirCmake = Convert-ToCMakePath $qt6DBusToolsDir

  & $cmakeCmake -S $sourceCmake -B $buildDirCmake -GNinja `
    "-DCMAKE_MAKE_PROGRAM=$ninjaCmake" `
    "-DCMAKE_TOOLCHAIN_FILE=$toolchainCmake" `
    -DCMAKE_SYSTEM_NAME=OHOS `
    "-DCMAKE_OHOS_ARCH_ABI=$abi" `
    "-DOHOS_ARCH=$abi" `
    "-DOHOS_SDK_NATIVE=$ohosNativeCmake" `
    "-DHMOS_SDK_NATIVE=$hmosNativeCmake" `
    -DCMAKE_BUILD_TYPE=Release `
    "-DCMAKE_INSTALL_PREFIX=$stageDirCmake" `
    "-DCMAKE_PREFIX_PATH=$stageDirCmake;$qtStageDirCmake;$qtStageDirCmake/lib/cmake" `
    -DBUILD_WITH_QT6=ON `
    -DBUILD_TEST_APPLICATION=OFF `
    -DBUILD_TRANSLATIONS=OFF `
    -DLIBSECRET_SUPPORT=OFF `
    "-DQt6_DIR=$qt6DirCmake" `
    "-DQt6Core_DIR=$qt6CoreDirCmake" `
    "-DQt6DBus_DIR=$qt6DBusDirCmake" `
    "-DQt6CoreTools_DIR=$qt6CoreToolsDirCmake" `
    "-DQt6DBusTools_DIR=$qt6DBusToolsDirCmake"
  if ($LASTEXITCODE -ne 0) {
    throw "QtKeychain configure failed for $abi"
  }

  if (-not $ConfigureOnly) {
    & $cmakeCmake --build $buildDirCmake --target install
    if ($LASTEXITCODE -ne 0) {
      throw "QtKeychain build failed for $abi"
    }
  }
}
