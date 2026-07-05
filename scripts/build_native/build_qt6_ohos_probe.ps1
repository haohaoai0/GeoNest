param(
  [string]$QtStageRoot = '',
  [string]$BuildRoot = '',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string[]]$AbiFilters = @('arm64-v8a', 'x86_64'),
  [switch]$ConfigureOnly
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
if ([string]::IsNullOrWhiteSpace($QtStageRoot)) {
  $QtStageRoot = Join-Path $repoRoot 'native\third_party\qt6\stage'
}
if ([string]::IsNullOrWhiteSpace($BuildRoot)) {
  $BuildRoot = Join-Path $repoRoot 'native\third_party\qt6\build-geonest-qt6-probe'
}

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

function Require-AnyPath {
  param(
    [string[]]$Paths,
    [string]$Label
  )

  foreach ($path in $Paths) {
    if (Test-Path -LiteralPath $path) {
      return $path
    }
  }

  throw "$Label not found. Checked: $($Paths -join ', ')"
}

$probeSource = Join-Path $repoRoot 'native\qt6_ohos_probe'
Require-Path $probeSource 'Qt6/OHOS probe source'

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
$probeSourceCmake = Convert-ToCMakePath $probeSource

foreach ($abi in $AbiFilters) {
  $qtPrefix = Join-Path $QtStageRoot $abi
  Require-Path $qtPrefix "Qt6/OHOS stage for $abi"

  Require-AnyPath @(
    (Join-Path $qtPrefix 'lib\cmake\Qt6\Qt6Config.cmake'),
    (Join-Path $qtPrefix 'lib64\cmake\Qt6\Qt6Config.cmake')
  ) "Qt6 CMake package for $abi" | Out-Null
  $qt6Dir = Split-Path -Parent (Require-AnyPath @(
    (Join-Path $qtPrefix 'lib\cmake\Qt6\Qt6Config.cmake'),
    (Join-Path $qtPrefix 'lib64\cmake\Qt6\Qt6Config.cmake')
  ) "Qt6 CMake package for $abi")
  $qt6CoreDir = Split-Path -Parent (Require-AnyPath @(
    (Join-Path $qtPrefix 'lib\cmake\Qt6Core\Qt6CoreConfig.cmake'),
    (Join-Path $qtPrefix 'lib64\cmake\Qt6Core\Qt6CoreConfig.cmake')
  ) "Qt6Core CMake package for $abi")
  $qt6XmlDir = Split-Path -Parent (Require-AnyPath @(
    (Join-Path $qtPrefix 'lib\cmake\Qt6Xml\Qt6XmlConfig.cmake'),
    (Join-Path $qtPrefix 'lib64\cmake\Qt6Xml\Qt6XmlConfig.cmake')
  ) "Qt6Xml CMake package for $abi")

  $buildDir = Join-Path $BuildRoot $abi
  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

  $buildDirCmake = Convert-ToCMakePath $buildDir
  $qtPrefixCmake = Convert-ToCMakePath $qtPrefix
  $qt6DirCmake = Convert-ToCMakePath $qt6Dir
  $qt6CoreDirCmake = Convert-ToCMakePath $qt6CoreDir
  $qt6XmlDirCmake = Convert-ToCMakePath $qt6XmlDir
  $qtCmakeRoot = Convert-ToCMakePath (Split-Path -Parent $qt6Dir)
  $prefixPath = "$qtPrefixCmake;$qtCmakeRoot"

  & $cmakeCmake -S $probeSourceCmake -B $buildDirCmake -GNinja `
    "-DCMAKE_MAKE_PROGRAM=$ninjaCmake" `
    "-DCMAKE_TOOLCHAIN_FILE=$toolchainCmake" `
    -DCMAKE_SYSTEM_NAME=OHOS `
    "-DCMAKE_OHOS_ARCH_ABI=$abi" `
    "-DOHOS_ARCH=$abi" `
    "-DOHOS_SDK_NATIVE=$ohosNativeCmake" `
    "-DHMOS_SDK_NATIVE=$hmosNativeCmake" `
    -DCMAKE_BUILD_TYPE=Release `
    "-DQT6_PREFIX=$qtPrefixCmake" `
    "-DCMAKE_PREFIX_PATH=$prefixPath" `
    "-DQt6_DIR=$qt6DirCmake" `
    "-DQt6Core_DIR=$qt6CoreDirCmake" `
    "-DQt6Xml_DIR=$qt6XmlDirCmake"

  if ($LASTEXITCODE -ne 0) {
    throw "Qt6/OHOS probe configure failed for $abi"
  }

  if (-not $ConfigureOnly) {
    & $cmakeCmake --build $buildDirCmake
    if ($LASTEXITCODE -ne 0) {
      throw "Qt6/OHOS probe build failed for $abi"
    }

    $probeLib = Join-Path $buildDir 'libgeonestqt6probe.so'
    Require-Path $probeLib "Qt6/OHOS probe library for $abi"
  }
}
