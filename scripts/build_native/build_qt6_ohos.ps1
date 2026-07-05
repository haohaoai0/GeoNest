param(
  [string]$QtSource = '',
  [string]$HostQtPath = '',
  [string]$StageRoot = '',
  [string]$BuildRoot = '',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string[]]$AbiFilters = @('arm64-v8a', 'x86_64'),
  [string]$QtTargetMkspec = 'linux-clang',
  [string[]]$QtSubmodules = @('qtbase'),
  [string[]]$ExtraConfigureArgs = @('-no-feature-gui', '-no-feature-widgets', '-no-feature-opengl'),
  [string[]]$ExtraCMakeArgs = @('-DFEATURE_gui=OFF', '-DFEATURE_widgets=OFF', '-DFEATURE_opengl=OFF'),
  [string[]]$OpenHarmonyCompileDefinitions = @('OPENHARMONY'),
  [switch]$ConfigureOnly
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
if ([string]::IsNullOrWhiteSpace($QtSource)) {
  $QtSource = Join-Path $repoRoot 'native\third_party\qt6\src'
}
if ([string]::IsNullOrWhiteSpace($StageRoot)) {
  $StageRoot = Join-Path $repoRoot 'native\third_party\qt6\stage'
}
if ([string]::IsNullOrWhiteSpace($BuildRoot)) {
  $BuildRoot = Join-Path $repoRoot 'native\third_party\qt6\build-ohos'
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

function Resolve-QtSourceRoot {
  param([string]$SourcePath)

  Require-Path $SourcePath 'Qt source directory'
  $resolved = (Resolve-Path -LiteralPath $SourcePath).Path
  $topLevelConfigure = Join-Path $resolved 'configure.bat'
  $topLevelQtBase = Join-Path $resolved 'qtbase\CMakeLists.txt'
  $qtBaseCore = Join-Path $resolved 'src\corelib'

  if ((Test-Path -LiteralPath $topLevelConfigure) -or (Test-Path -LiteralPath $topLevelQtBase)) {
    return $resolved
  }

  if ((Test-Path -LiteralPath (Join-Path $resolved 'CMakeLists.txt')) -and
      (Test-Path -LiteralPath $qtBaseCore)) {
    return $resolved
  }

  throw "Qt source must be a qt-everywhere source tree or a qtbase checkout: $SourcePath"
}

function Require-ConfiguredBuild {
  param([string]$BuildDirectory)

  Require-Path (Join-Path $BuildDirectory 'build.ninja') 'Configured Qt Ninja build file'
}

if ([string]::IsNullOrWhiteSpace($HostQtPath)) {
  throw 'HostQtPath is required. Qt cross-builds need host tools from the same Qt version, for example C:\Qt\6.8.3\msvc2022_64.'
}

$qtSourceRoot = Resolve-QtSourceRoot $QtSource
Require-Path $HostQtPath 'Host Qt path'

$cmake = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\cmake.exe'
$ninja = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\ninja.exe'
$cmakeBin = Split-Path -Parent $cmake
$toolchain = Join-Path $DevEcoSdkHome 'default\hms\native\build\cmake\hmos.toolchain.cmake'
$ohosSdkPath = Join-Path $DevEcoSdkHome 'default\openharmony'
$ohosNative = Join-Path $DevEcoSdkHome 'default\openharmony\native'
$hmosNative = Join-Path $DevEcoSdkHome 'default\hms\native'
$ohosLlvmBin = Join-Path $ohosNative 'llvm\bin'
$ohosClang = Join-Path $ohosLlvmBin 'clang.exe'
$ohosClangXX = Join-Path $ohosLlvmBin 'clang++.exe'

foreach ($path in @($cmake, $ninja, $toolchain, $ohosSdkPath, $ohosNative, $hmosNative, $ohosLlvmBin, $ohosClang, $ohosClangXX)) {
  Require-Path $path 'Required DevEco native path'
}

$env:PATH = "$cmakeBin;$ohosLlvmBin;$env:PATH"

$qtSourceCmake = Convert-ToCMakePath $qtSourceRoot
$hostQtCmake = Convert-ToCMakePath ((Resolve-Path -LiteralPath $HostQtPath).Path)
$cmakeCmake = Convert-ToCMakePath $cmake
$ninjaCmake = Convert-ToCMakePath $ninja
$toolchainCmake = Convert-ToCMakePath $toolchain
$ohosNativeCmake = Convert-ToCMakePath $ohosNative
$hmosNativeCmake = Convert-ToCMakePath $hmosNative

$configureBat = Join-Path $qtSourceRoot 'configure.bat'
$configureScript = Join-Path $qtSourceRoot 'configure'
$hasConfigure = (Test-Path -LiteralPath $configureBat) -or (Test-Path -LiteralPath $configureScript)
$isQtEverywhereSource = Test-Path -LiteralPath (Join-Path $qtSourceRoot 'qtbase\CMakeLists.txt')
$openHarmonyCompileFlags = ($OpenHarmonyCompileDefinitions | ForEach-Object { "-D$_" }) -join ' '

foreach ($abi in $AbiFilters) {
  $env:OHOS_SDK_PATH = $ohosSdkPath
  $env:OHOS_ARCH = $abi

  $buildDir = Join-Path $BuildRoot $abi
  $stageDir = Join-Path $StageRoot $abi
  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
  New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

  $buildDirCmake = Convert-ToCMakePath $buildDir
  $stageDirCmake = Convert-ToCMakePath $stageDir

  $targetMkspecArg = ''
  if (-not [string]::IsNullOrWhiteSpace($QtTargetMkspec)) {
    $targetMkspecArg = "-DQT_QMAKE_TARGET_MKSPEC=$QtTargetMkspec"
  }

  if ($hasConfigure) {
    $configure = $configureBat
    if (-not (Test-Path -LiteralPath $configure)) {
      $configure = $configureScript
    }

    $configureArgs = @(
      '-prefix', $stageDirCmake,
      '-release',
      '-shared',
      '-opensource',
      '-confirm-license',
      '-nomake', 'examples',
      '-nomake', 'tests',
      '-qt-host-path', $hostQtCmake
    )
    if ($isQtEverywhereSource) {
      $configureArgs += @('-submodules', ($QtSubmodules -join ','))
    }
    $configureArgs += $ExtraConfigureArgs
    $configureArgs += @(
      '--',
      "-DCMAKE_MAKE_PROGRAM=$ninjaCmake",
      "-DCMAKE_TOOLCHAIN_FILE=$toolchainCmake",
      '-DCMAKE_SYSTEM_NAME=OHOS',
      "-DCMAKE_OHOS_ARCH_ABI=$abi",
      "-DOHOS_ARCH=$abi",
      "-DOHOS_SDK_NATIVE=$ohosNativeCmake",
      "-DHMOS_SDK_NATIVE=$hmosNativeCmake",
      "-DCMAKE_C_FLAGS_INIT=$openHarmonyCompileFlags",
      "-DCMAKE_CXX_FLAGS_INIT=$openHarmonyCompileFlags",
      '-DQT_INSTALL_CONFIG_INFO_FILES=ON'
    )
    if (-not [string]::IsNullOrWhiteSpace($targetMkspecArg)) {
      $configureArgs += $targetMkspecArg
    }

    Push-Location $buildDir
    try {
      & $configure @configureArgs
      if ($LASTEXITCODE -ne 0) {
        throw "Qt configure failed for $abi"
      }
      Require-ConfiguredBuild $buildDir
    } finally {
      Pop-Location
    }
  } else {
    $cmakeArgs = @(
      '-S', $qtSourceCmake,
      '-B', $buildDirCmake,
      '-GNinja',
      "-DCMAKE_MAKE_PROGRAM=$ninjaCmake",
      "-DCMAKE_TOOLCHAIN_FILE=$toolchainCmake",
      '-DCMAKE_SYSTEM_NAME=OHOS',
      "-DCMAKE_OHOS_ARCH_ABI=$abi",
      "-DOHOS_ARCH=$abi",
      "-DOHOS_SDK_NATIVE=$ohosNativeCmake",
      "-DHMOS_SDK_NATIVE=$hmosNativeCmake",
      "-DCMAKE_C_FLAGS_INIT=$openHarmonyCompileFlags",
      "-DCMAKE_CXX_FLAGS_INIT=$openHarmonyCompileFlags",
      '-DCMAKE_BUILD_TYPE=Release',
      "-DCMAKE_INSTALL_PREFIX=$stageDirCmake",
      "-DQT_HOST_PATH=$hostQtCmake",
      '-DQT_BUILD_EXAMPLES_BY_DEFAULT=OFF',
      '-DQT_BUILD_TESTS_BY_DEFAULT=OFF',
      '-DQT_INSTALL_CONFIG_INFO_FILES=ON'
    )
    if (-not [string]::IsNullOrWhiteSpace($targetMkspecArg)) {
      $cmakeArgs += $targetMkspecArg
    }
    if ($QtSubmodules.Count -gt 0) {
      $cmakeArgs += "-DQT_BUILD_SUBMODULES=$($QtSubmodules -join ';')"
    }
    $cmakeArgs += $ExtraCMakeArgs

    & $cmakeCmake @cmakeArgs
    if ($LASTEXITCODE -ne 0) {
      throw "Qt CMake configure failed for $abi"
    }
    Require-ConfiguredBuild $buildDir
  }

  if (-not $ConfigureOnly) {
    & $cmakeCmake --build $buildDirCmake --target install
    if ($LASTEXITCODE -ne 0) {
      throw "Qt build/install failed for $abi"
    }
  }

  if (-not $ConfigureOnly) {
    Require-AnyPath @(
      (Join-Path $stageDir 'lib\cmake\Qt6\Qt6Config.cmake'),
      (Join-Path $stageDir 'lib64\cmake\Qt6\Qt6Config.cmake')
    ) "Expected Qt6 CMake package for $abi" | Out-Null

    Require-AnyPath @(
      (Join-Path $stageDir 'lib\libQt6Core.so'),
      (Join-Path $stageDir 'lib64\libQt6Core.so')
    ) "Expected Qt6Core library for $abi" | Out-Null

    Require-AnyPath @(
      (Join-Path $stageDir 'lib\libQt6Xml.so'),
      (Join-Path $stageDir 'lib64\libQt6Xml.so')
    ) "Expected Qt6Xml library for $abi" | Out-Null
  }
}
