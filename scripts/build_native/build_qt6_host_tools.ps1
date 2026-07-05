param(
  [string]$QtSource = 'D:\GeoNestDeps\qt6\src',
  [string]$BuildDir = 'D:\GeoNestDeps\qt6\build-host',
  [string]$InstallPrefix = 'D:\GeoNestDeps\qt6\host',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string]$VcVars64 = '',
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

function Convert-ToCMakePath {
  param([string]$Path)
  return $Path.Replace('\', '/')
}

function Convert-ToCmdArgument {
  param([string]$Argument)

  if ([string]::IsNullOrEmpty($Argument)) {
    return '""'
  }

  if ($Argument -match '[\s"&|<>^]') {
    return '"' + $Argument.Replace('"', '\"') + '"'
  }

  return $Argument
}

function Invoke-VcVarsCommand {
  param(
    [string]$WorkingDirectory,
    [string]$Executable,
    [string[]]$Arguments,
    [string]$FailureMessage
  )

  $cmdArgs = ($Arguments | ForEach-Object { Convert-ToCmdArgument $_ }) -join ' '
  $command = '"' + $VcVars64 + '" >NUL && cd /d "' + $WorkingDirectory + '" && "' + $Executable + '" ' + $cmdArgs
  & cmd.exe /d /c $command
  if ($LASTEXITCODE -ne 0) {
    throw $FailureMessage
  }
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

if ([string]::IsNullOrWhiteSpace($VcVars64)) {
  $VcVars64 = Require-AnyPath @(
    'C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat',
    'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat',
    'C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat',
    'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat'
  ) 'VS 2022 vcvars64.bat'
}

$qtSourceRoot = Resolve-QtSourceRoot $QtSource
Require-Path $VcVars64 'VS vcvars64.bat'

$cmake = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\cmake.exe'
$ninja = Join-Path $DevEcoSdkHome 'default\openharmony\native\build-tools\cmake\bin\ninja.exe'
Require-Path $cmake 'CMake'
Require-Path $ninja 'Ninja'

$cmakeBin = Split-Path -Parent $cmake
$env:PATH = "$cmakeBin;$env:PATH"

$configureBat = Join-Path $qtSourceRoot 'configure.bat'
Require-Path $configureBat 'Qt configure.bat'

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path $InstallPrefix | Out-Null

$isQtEverywhereSource = Test-Path -LiteralPath (Join-Path $qtSourceRoot 'qtbase\CMakeLists.txt')
$installPrefixCmake = Convert-ToCMakePath (Resolve-Path -LiteralPath $InstallPrefix).Path
$ninjaCmake = Convert-ToCMakePath (Resolve-Path -LiteralPath $ninja).Path

$configureArgs = @(
  '-prefix', $installPrefixCmake,
  '-release',
  '-opensource',
  '-confirm-license',
  '-nomake', 'examples',
  '-nomake', 'tests'
)
if ($isQtEverywhereSource) {
  $configureArgs += @('-submodules', 'qtbase')
}
$configureArgs += @(
  '--',
  '-GNinja',
  "-DCMAKE_MAKE_PROGRAM=$ninjaCmake",
  '-DQT_BUILD_EXAMPLES_BY_DEFAULT=OFF',
  '-DQT_BUILD_TESTS_BY_DEFAULT=OFF',
  '-DQT_INSTALL_CONFIG_INFO_FILES=ON'
)

Invoke-VcVarsCommand $BuildDir $configureBat $configureArgs 'Host Qt configure failed'

if (-not $ConfigureOnly) {
  $buildArgs = @('--build', '.', '--target', 'install', '--parallel')
  Invoke-VcVarsCommand $BuildDir $cmake $buildArgs 'Host Qt build/install failed'

  Require-AnyPath @(
    (Join-Path $InstallPrefix 'lib\cmake\Qt6\Qt6Config.cmake'),
    (Join-Path $InstallPrefix 'lib64\cmake\Qt6\Qt6Config.cmake')
  ) 'Installed host Qt6 CMake package' | Out-Null

  Require-AnyPath @(
    (Join-Path $InstallPrefix 'bin\moc.exe'),
    (Join-Path $InstallPrefix 'libexec\moc.exe')
  ) 'Installed host Qt moc' | Out-Null
}
