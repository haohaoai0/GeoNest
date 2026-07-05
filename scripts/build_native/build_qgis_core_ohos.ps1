param(
  [string]$QgisSource = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\sources\QGIS-master',
  [string]$StageRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\stage',
  [string]$QtStageRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qt6\stage',
  [string]$BuildRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\build-ohos',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string[]]$AbiFilters = @('arm64-v8a', 'x86_64'),
  [switch]$ConfigureOnly
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $QgisSource)) {
  throw "QGIS source directory not found: $QgisSource"
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

$wingetLinks = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
$wingetPackages = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
$packagedFlex = $null
$packagedBison = $null
if (Test-Path -LiteralPath $wingetPackages) {
  $packagedFlex = Get-ChildItem -LiteralPath $wingetPackages -Recurse -Filter 'win_flex.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
  $packagedBison = Get-ChildItem -LiteralPath $wingetPackages -Recurse -Filter 'win_bison.exe' -ErrorAction SilentlyContinue | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.DirectoryName 'data\m4sugar\m4sugar.m4')
  } | Select-Object -First 1
}
$flex = $packagedFlex
if ($null -eq $flex) {
  $flex = Get-Command win_flex, flex -ErrorAction SilentlyContinue | Select-Object -First 1
}
$bison = $packagedBison
if ($null -eq $bison) {
  $bison = Get-Command win_bison, bison -ErrorAction SilentlyContinue | Select-Object -First 1
}
if ($null -eq $flex) {
  $flexPath = Join-Path $wingetLinks 'win_flex.exe'
  if (Test-Path -LiteralPath $flexPath) {
    $flex = Get-Item -LiteralPath $flexPath
  }
}
if ($null -eq $bison) {
  $bisonPath = Join-Path $wingetLinks 'win_bison.exe'
  if (Test-Path -LiteralPath $bisonPath) {
    $bison = Get-Item -LiteralPath $bisonPath
  }
}

if ($null -eq $flex) {
  throw "Flex is required to configure QGIS Core. Install winflexbison or put flex/win_flex on PATH."
}
if ($null -eq $bison) {
  throw "Bison is required to configure QGIS Core. Install winflexbison or put bison/win_bison on PATH."
}

$flexExe = $flex.Source
if ([string]::IsNullOrWhiteSpace($flexExe)) {
  $flexExe = $flex.FullName
}
$bisonExe = $bison.Source
if ([string]::IsNullOrWhiteSpace($bisonExe)) {
  $bisonExe = $bison.FullName
}

foreach ($abi in $AbiFilters) {
  $buildDir = Join-Path $BuildRoot $abi
  $stageDir = Join-Path $StageRoot $abi
  $qtStageDir = Join-Path $QtStageRoot $abi
  $qt6Dir = Join-Path $qtStageDir 'lib\cmake\Qt6'
  $qt6CoreDir = Join-Path $qtStageDir 'lib\cmake\Qt6Core'
  $qt6Core5CompatDir = Join-Path $qtStageDir 'lib\cmake\Qt6Core5Compat'
  $qt6DBusDir = Join-Path $qtStageDir 'lib\cmake\Qt6DBus'
  $qt6GuiDir = Join-Path $qtStageDir 'lib\cmake\Qt6Gui'
  $qt6WidgetsDir = Join-Path $qtStageDir 'lib\cmake\Qt6Widgets'
  $qt6NetworkDir = Join-Path $qtStageDir 'lib\cmake\Qt6Network'
  $qt6XmlDir = Join-Path $qtStageDir 'lib\cmake\Qt6Xml'
  $qt6PrintSupportDir = Join-Path $qtStageDir 'lib\cmake\Qt6PrintSupport'
  $qt6SvgDir = Join-Path $qtStageDir 'lib\cmake\Qt6Svg'
  $qt6SvgWidgetsDir = Join-Path $qtStageDir 'lib\cmake\Qt6SvgWidgets'
  $qt6ConcurrentDir = Join-Path $qtStageDir 'lib\cmake\Qt6Concurrent'
  $qt6TestDir = Join-Path $qtStageDir 'lib\cmake\Qt6Test'
  $qt6SqlDir = Join-Path $qtStageDir 'lib\cmake\Qt6Sql'
  $qt6KeychainDir = Join-Path $stageDir 'lib\cmake\Qt6Keychain'
  $qtHostPath = 'D:\GeoNestDeps\qt6\host'
  $qtHostCmakeDir = Join-Path $qtHostPath 'lib\cmake'
  $qtHostCoreToolsDir = Join-Path $qtHostCmakeDir 'Qt6CoreTools'
  $projInclude = Join-Path $stageDir 'include'
  $projLib = Join-Path $stageDir 'lib\libproj.so'
  $geosInclude = Join-Path $stageDir 'include'
  $geosLib = Join-Path $stageDir 'lib\libgeos_c.so'
  $gdalInclude = Join-Path $stageDir 'include'
  $gdalLib = Join-Path $stageDir 'lib\libgdal.so'
  $gdalDir = Join-Path $stageDir 'lib\cmake\gdal'
  $expatInclude = Join-Path $stageDir 'include'
  $expatLib = Join-Path $stageDir 'lib\libexpat.so'
  $expatDir = Join-Path $stageDir 'lib\cmake\expat-2.7.1'
  $libZipInclude = Join-Path $stageDir 'include'
  $libZipLib = Join-Path $stageDir 'lib\libzip.so'
  $libZipDir = Join-Path $stageDir 'lib\cmake\libzip'
  $protobufInclude = Join-Path $stageDir 'include'
  $protobufLib = Join-Path $stageDir 'lib\libprotobuf.so'
  $protobufLiteLib = Join-Path $stageDir 'lib\libprotobuf-lite.so'
  $protobufDir = Join-Path $stageDir 'lib\cmake\protobuf'
  $protocExe = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\sources\protoc-3.20.3-win64\bin\protoc.exe'
  $sqliteInclude = Join-Path $stageDir 'include'
  $sqliteLib = Join-Path $stageDir 'lib\libsqlite3.so'
  $zstdInclude = Join-Path $stageDir 'include'
  $zstdLib = Join-Path $stageDir 'lib\libzstd.so'
  $zlibInclude = Join-Path $DevEcoSdkHome 'default\openharmony\native\sysroot\usr\include'
  $zlibLib = Join-Path $DevEcoSdkHome 'default\openharmony\native\sysroot\usr\lib\aarch64-linux-ohos\libz.so'
  if ($abi -eq 'x86_64') {
    $zlibLib = Join-Path $DevEcoSdkHome 'default\openharmony\native\sysroot\usr\lib\x86_64-linux-ohos\libz.so'
  }
  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
  New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

  foreach ($path in @($qt6Dir, $qt6CoreDir, $qt6Core5CompatDir, $qt6DBusDir, $qt6GuiDir, $qt6WidgetsDir, $qt6NetworkDir, $qt6XmlDir, $qt6PrintSupportDir, $qt6SvgDir, $qt6SvgWidgetsDir, $qt6ConcurrentDir, $qt6TestDir, $qt6SqlDir, $qt6KeychainDir, $qtHostCoreToolsDir, $projLib, $geosLib, $gdalLib, $gdalDir, $expatLib, $expatDir, $libZipLib, $libZipDir, $protobufLib, $protobufLiteLib, $protobufDir, $protocExe, $sqliteLib, $zstdLib, $zlibLib)) {
    if (-not (Test-Path -LiteralPath $path)) {
      throw "Required QGIS dependency path not found for ${abi}: $path"
    }
  }

  $qgisSourceCmake = $QgisSource.Replace('\', '/')
  $buildDirCmake = $buildDir.Replace('\', '/')
  $stageDirCmake = $stageDir.Replace('\', '/')
  $qtStageDirCmake = $qtStageDir.Replace('\', '/')
  $qt6DirCmake = $qt6Dir.Replace('\', '/')
  $qt6CoreDirCmake = $qt6CoreDir.Replace('\', '/')
  $qt6Core5CompatDirCmake = $qt6Core5CompatDir.Replace('\', '/')
  $qt6DBusDirCmake = $qt6DBusDir.Replace('\', '/')
  $qt6GuiDirCmake = $qt6GuiDir.Replace('\', '/')
  $qt6WidgetsDirCmake = $qt6WidgetsDir.Replace('\', '/')
  $qt6NetworkDirCmake = $qt6NetworkDir.Replace('\', '/')
  $qt6XmlDirCmake = $qt6XmlDir.Replace('\', '/')
  $qt6PrintSupportDirCmake = $qt6PrintSupportDir.Replace('\', '/')
  $qt6SvgDirCmake = $qt6SvgDir.Replace('\', '/')
  $qt6SvgWidgetsDirCmake = $qt6SvgWidgetsDir.Replace('\', '/')
  $qt6ConcurrentDirCmake = $qt6ConcurrentDir.Replace('\', '/')
  $qt6TestDirCmake = $qt6TestDir.Replace('\', '/')
  $qt6SqlDirCmake = $qt6SqlDir.Replace('\', '/')
  $qt6KeychainDirCmake = $qt6KeychainDir.Replace('\', '/')
  $qtHostPathCmake = $qtHostPath.Replace('\', '/')
  $qtHostCmakeDirCmake = $qtHostCmakeDir.Replace('\', '/')
  $qtHostCoreToolsDirCmake = $qtHostCoreToolsDir.Replace('\', '/')
  $cmakeCmake = $cmake.Replace('\', '/')
  $ninjaCmake = $ninja.Replace('\', '/')
  $toolchainCmake = $toolchain.Replace('\', '/')
  $ohosNativeCmake = $ohosNative.Replace('\', '/')
  $hmosNativeCmake = $hmosNative.Replace('\', '/')
  $projIncludeCmake = $projInclude.Replace('\', '/')
  $projLibCmake = $projLib.Replace('\', '/')
  $geosIncludeCmake = $geosInclude.Replace('\', '/')
  $geosLibCmake = $geosLib.Replace('\', '/')
  $gdalIncludeCmake = $gdalInclude.Replace('\', '/')
  $gdalLibCmake = $gdalLib.Replace('\', '/')
  $gdalDirCmake = $gdalDir.Replace('\', '/')
  $expatIncludeCmake = $expatInclude.Replace('\', '/')
  $expatLibCmake = $expatLib.Replace('\', '/')
  $expatDirCmake = $expatDir.Replace('\', '/')
  $libZipIncludeCmake = $libZipInclude.Replace('\', '/')
  $libZipLibCmake = $libZipLib.Replace('\', '/')
  $libZipDirCmake = $libZipDir.Replace('\', '/')
  $protobufIncludeCmake = $protobufInclude.Replace('\', '/')
  $protobufLibCmake = $protobufLib.Replace('\', '/')
  $protobufLiteLibCmake = $protobufLiteLib.Replace('\', '/')
  $protobufDirCmake = $protobufDir.Replace('\', '/')
  $protocExeCmake = $protocExe.Replace('\', '/')
  $sqliteIncludeCmake = $sqliteInclude.Replace('\', '/')
  $sqliteLibCmake = $sqliteLib.Replace('\', '/')
  $zstdIncludeCmake = $zstdInclude.Replace('\', '/')
  $zstdLibCmake = $zstdLib.Replace('\', '/')
  $zlibIncludeCmake = $zlibInclude.Replace('\', '/')
  $zlibLibCmake = $zlibLib.Replace('\', '/')
  $flexExeCmake = $flexExe.Replace('\', '/')
  $bisonExeCmake = $bisonExe.Replace('\', '/')

  & $cmakeCmake -S $qgisSourceCmake -B $buildDirCmake -GNinja `
    "-DCMAKE_MAKE_PROGRAM=$ninjaCmake" `
    "-DCMAKE_TOOLCHAIN_FILE=$toolchainCmake" `
    -DCMAKE_SYSTEM_NAME=OHOS `
    "-DCMAKE_OHOS_ARCH_ABI=$abi" `
    "-DOHOS_ARCH=$abi" `
    "-DOHOS_SDK_NATIVE=$ohosNativeCmake" `
    "-DHMOS_SDK_NATIVE=$hmosNativeCmake" `
    -DCMAKE_BUILD_TYPE=Release `
    "-DCMAKE_INSTALL_PREFIX=$stageDirCmake" `
    "-DCMAKE_PREFIX_PATH=$stageDirCmake;$qtStageDirCmake" `
    "-DQt6_DIR=$qt6DirCmake" `
    "-DQt6Core_DIR=$qt6CoreDirCmake" `
    "-DQt6Core5Compat_DIR=$qt6Core5CompatDirCmake" `
    "-DQt6DBus_DIR=$qt6DBusDirCmake" `
    "-DQt6Gui_DIR=$qt6GuiDirCmake" `
    "-DQt6Widgets_DIR=$qt6WidgetsDirCmake" `
    "-DQt6Network_DIR=$qt6NetworkDirCmake" `
    "-DQt6Xml_DIR=$qt6XmlDirCmake" `
    "-DQt6PrintSupport_DIR=$qt6PrintSupportDirCmake" `
    "-DQt6Svg_DIR=$qt6SvgDirCmake" `
    "-DQt6SvgWidgets_DIR=$qt6SvgWidgetsDirCmake" `
    "-DQt6Concurrent_DIR=$qt6ConcurrentDirCmake" `
    "-DQt6Test_DIR=$qt6TestDirCmake" `
    "-DQt6Sql_DIR=$qt6SqlDirCmake" `
    "-DQt6Keychain_DIR=$qt6KeychainDirCmake" `
    "-DQT_HOST_PATH=$qtHostPathCmake" `
    "-DQT_HOST_PATH_CMAKE_DIR=$qtHostCmakeDirCmake" `
    "-DQt6CoreTools_DIR=$qtHostCoreToolsDirCmake" `
    "-DPROJ_INCLUDE_DIR=$projIncludeCmake" `
    "-DPROJ_LIBRARY=$projLibCmake" `
    "-DGEOS_INCLUDE_DIR=$geosIncludeCmake" `
    "-DGEOS_LIBRARY=$geosLibCmake" `
    "-DGDAL_INCLUDE_DIR=$gdalIncludeCmake" `
    "-DGDAL_LIBRARY=$gdalLibCmake" `
    "-DGDAL_DIR=$gdalDirCmake" `
    "-DEXPAT_INCLUDE_DIR=$expatIncludeCmake" `
    "-DEXPAT_LIBRARY=$expatLibCmake" `
    "-DEXPAT_DIR=$expatDirCmake" `
    "-DLIBZIP_INCLUDE_DIR=$libZipIncludeCmake" `
    "-DLIBZIP_CONF_INCLUDE_DIR=$libZipIncludeCmake" `
    "-DLIBZIP_LIBRARY=$libZipLibCmake" `
    "-DLibZip_DIR=$libZipDirCmake" `
    "-DProtobuf_DIR=$protobufDirCmake" `
    "-Dprotobuf_DIR=$protobufDirCmake" `
    "-DProtobuf_INCLUDE_DIR=$protobufIncludeCmake" `
    "-DProtobuf_LIBRARY=$protobufLibCmake" `
    "-DProtobuf_LITE_LIBRARY=$protobufLiteLibCmake" `
    "-DProtobuf_PROTOC_EXECUTABLE=$protocExeCmake" `
    "-DPROTOBUF_INCLUDE_DIR=$protobufIncludeCmake" `
    "-DPROTOBUF_LIBRARY=$protobufLibCmake" `
    "-DPROTOBUF_LITE_LIBRARY=$protobufLiteLibCmake" `
    "-DPROTOBUF_PROTOC_EXECUTABLE=$protocExeCmake" `
    "-DSQLITE3_INCLUDE_DIR=$sqliteIncludeCmake" `
    "-DSQLITE3_LIBRARY=$sqliteLibCmake" `
    "-DSQLite3_INCLUDE_DIR=$sqliteIncludeCmake" `
    "-DSQLite3_LIBRARY=$sqliteLibCmake" `
    "-DZSTD_INCLUDE_DIR=$zstdIncludeCmake" `
    "-DZSTD_LIBRARY=$zstdLibCmake" `
    "-DZLIB_INCLUDE_DIR=$zlibIncludeCmake" `
    "-DZLIB_LIBRARY=$zlibLibCmake" `
    "-DFLEX_EXECUTABLE=$flexExeCmake" `
    "-DBISON_EXECUTABLE=$bisonExeCmake" `
    -DWITH_CORE=ON `
    -DWITH_DESKTOP=OFF `
    -DWITH_GUI=OFF `
    -DWITH_3D=OFF `
    -DWITH_BINDINGS=OFF `
    -DWITH_SERVER=OFF `
    -DWITH_ANALYSIS=OFF `
    -DWITH_QGIS_PROCESS=OFF `
    -DWITH_QUICK=OFF `
    -DWITH_QTPOSITIONING=OFF `
    -DWITH_QTSERIALPORT=OFF `
    -DWITH_QTWEBENGINE=OFF `
    -DWITH_AUTH=OFF `
    -DWITH_GRASS=OFF `
    -DWITH_POSTGRESQL=OFF `
    -DWITH_SPATIALITE=OFF `
    -DWITH_EPT=OFF `
    -DWITH_COPC=ON `
    -DWITH_DRACO=OFF `
    -DWITH_PDAL=OFF `
    -DWITH_SFCGAL=OFF `
    -DWITH_GEOGRAPHICLIB=OFF `
    -DWITH_EXIV2=OFF `
    -DWITH_PDF4QT=OFF `
    -DWITH_I18N=OFF `
    -DWITH_INTERNAL_SPATIALINDEX=ON

  if ($LASTEXITCODE -ne 0) {
    throw "QGIS Core configure failed for $abi"
  }

  if (-not $ConfigureOnly) {
    & $cmakeCmake --build $buildDirCmake --target qgis_core
    if ($LASTEXITCODE -ne 0) {
      throw "QGIS Core build failed for $abi"
    }

    $coreInstallScript = Join-Path $buildDir 'src\core\cmake_install.cmake'
    if (-not (Test-Path -LiteralPath $coreInstallScript)) {
      throw "QGIS Core install script not found for ${abi}: $coreInstallScript"
    }
    $coreInstallScriptCmake = $coreInstallScript.Replace('\', '/')
    & $cmakeCmake -P $coreInstallScriptCmake
    if ($LASTEXITCODE -ne 0) {
      throw "QGIS Core stage failed for $abi"
    }

    $qgsApplicationHeader = Join-Path $stageDir 'include\qgis\qgsapplication.h'
    $qgisCoreLib = Join-Path $stageDir 'lib\libqgis_core.so'
    if (-not (Test-Path -LiteralPath $qgsApplicationHeader)) {
      throw "QGIS Core staged header not found for ${abi}: $qgsApplicationHeader"
    }
    if (-not (Test-Path -LiteralPath $qgisCoreLib)) {
      throw "QGIS Core staged library not found for ${abi}: $qgisCoreLib"
    }

    $qgisCoreLibItem = Get-Item -LiteralPath $qgisCoreLib
    if (($qgisCoreLibItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $qgisCoreLibItem.Length -eq 0) {
      $versionedCoreLib = Get-ChildItem -LiteralPath (Join-Path $stageDir 'lib') -Filter 'libqgis_core.so.*' |
        Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
      if ($null -eq $versionedCoreLib) {
        throw "QGIS Core staged library is a symlink placeholder and no versioned library was found for $abi"
      }
      Remove-Item -LiteralPath $qgisCoreLib -Force
      Copy-Item -LiteralPath $versionedCoreLib.FullName -Destination $qgisCoreLib -Force
    }
  }
}
