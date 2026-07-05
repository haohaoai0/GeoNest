[CmdletBinding()]
param(
  [string]$ProjectRoot = '',
  [Parameter(Mandatory = $true)]
  [string]$OutputDirectory,
  [string]$VersionName = 'development',
  [string]$QgisSource = 'D:\下载\QGIS-master\QGIS-master',
  [string]$QtSource = 'D:\GeoNestDeps\qt6\src',
  [string]$NativeSourceRoot = '',
  [string]$QtVersion = '6.8.3',
  [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Assert-Directory {
  param(
    [string]$Path,
    [string]$Description
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "$Description not found: $Path"
  }
}

function Invoke-SourceArchive {
  param(
    [string]$ArchivePath,
    [string]$SourceRoot,
    [string[]]$Items,
    [string[]]$ExcludePatterns
  )

  if (Test-Path -LiteralPath $ArchivePath) {
    Remove-Item -LiteralPath $ArchivePath -Force
  }

  $arguments = @('-czf', $ArchivePath)
  foreach ($pattern in $ExcludePatterns) {
    $arguments += "--exclude=$pattern"
  }
  $arguments += @('-C', $SourceRoot)
  $arguments += $Items

  & $script:TarExecutable @arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to create corresponding-source archive: $ArchivePath"
  }
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = Get-FullPath $ProjectRoot
$OutputDirectory = Get-FullPath $OutputDirectory
$QgisSource = Get-FullPath $QgisSource
$QtSource = Get-FullPath $QtSource
if ([string]::IsNullOrWhiteSpace($NativeSourceRoot)) {
  $NativeSourceRoot = Join-Path $ProjectRoot 'native\third_party\qgis\sources'
}
$NativeSourceRoot = Get-FullPath $NativeSourceRoot

Assert-Directory $ProjectRoot 'GeoNest project root'
Assert-Directory $QgisSource 'Exact modified QGIS source tree'
Assert-Directory $QtSource 'Exact Qt source tree'
Assert-Directory $NativeSourceRoot 'Native dependency source root'

$requiredProjectFiles = @(
  'LICENSE',
  'COPYING',
  'THIRD_PARTY_NOTICES.md',
  'SOURCE_OFFER.txt',
  'scripts\build_native\build_qgis_core_ohos.ps1',
  'scripts\build_native\build_qt6_ohos.ps1',
  'entry\src\main\cpp\CMakeLists.txt'
)
foreach ($relativePath in $requiredProjectFiles) {
  $requiredPath = Join-Path $ProjectRoot $relativePath
  if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
    throw "Required corresponding-source file not found: $requiredPath"
  }
}

$requiredNativeSources = @(
  'expat-2.7.1',
  'gdal-3.11.4',
  'geos-3.13.1',
  'libzip-1.11.4',
  'proj-9.8.1',
  'protobuf-3.20.3',
  'qtkeychain',
  'sqlite-amalgamation-3450300',
  'zstd-1.5.7'
)
foreach ($directoryName in $requiredNativeSources) {
  Assert-Directory (Join-Path $NativeSourceRoot $directoryName) "Native dependency source '$directoryName'"
}

$tarCommand = Get-Command tar.exe -ErrorAction SilentlyContinue
if ($null -eq $tarCommand) {
  throw 'tar.exe is required to create corresponding-source archives'
}
$script:TarExecutable = $tarCommand.Source

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
  New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$safeVersion = $VersionName -replace '[^0-9A-Za-z._-]', '-'
$qgisVersion = 'snapshot'
$qgisCmakePath = Join-Path $QgisSource 'CMakeLists.txt'
$qgisCmakeText = Get-Content -LiteralPath $qgisCmakePath -Raw
$qgisMajorMatch = [regex]::Match($qgisCmakeText, 'CPACK_PACKAGE_VERSION_MAJOR\s+"([^"]+)"')
$qgisMinorMatch = [regex]::Match($qgisCmakeText, 'CPACK_PACKAGE_VERSION_MINOR\s+"([^"]+)"')
$qgisPatchMatch = [regex]::Match($qgisCmakeText, 'CPACK_PACKAGE_VERSION_PATCH\s+"([^"]+)"')
if ($qgisMajorMatch.Success -and $qgisMinorMatch.Success -and $qgisPatchMatch.Success) {
  $qgisVersion = $qgisMajorMatch.Groups[1].Value + '.' +
    $qgisMinorMatch.Groups[1].Value + '.' + $qgisPatchMatch.Groups[1].Value
}

$geonestArchive = Join-Path $OutputDirectory "GeoNest-$safeVersion-corresponding-source.tar.gz"
$qgisArchive = Join-Path $OutputDirectory "QGIS-$qgisVersion-geonest-source.tar.gz"
$qtArchive = Join-Path $OutputDirectory "Qt-$QtVersion-geonest-source.tar.gz"
$nativeArchive = Join-Path $OutputDirectory 'GeoNest-native-dependencies-source.tar.gz'

if ($ValidateOnly) {
  Write-Host 'Corresponding-source inputs are complete.'
  Write-Host "GeoNest: $ProjectRoot"
  Write-Host "QGIS: $QgisSource"
  Write-Host "Qt: $QtSource"
  Write-Host "Native dependencies: $NativeSourceRoot"
  return
}

$projectExcludes = @(
  './.git',
  './.hvigor',
  './.idea',
  './.agents',
  './.playwright-cli',
  './build',
  './output',
  './oh_modules',
  './node_modules',
  './entry/build',
  './entry/.cxx',
  './entry/.idea',
  './native/third_party/qgis',
  './native/third_party/qt6/src',
  './native/third_party/qt6/build-ohos',
  './native/third_party/qt6/stage',
  './native/third_party/qt6/build-geonest-qt6-probe',
  './geonest_*.jpeg',
  './geonest_*_hilog.txt',
  './entry/src/main/resources/rawfile/HarmonyOS_Sans_SC_Regular.ttf',
  './local.properties',
  './build-profile.json5'
)

Write-Host 'Creating GeoNest corresponding source archive...'
Invoke-SourceArchive `
  -ArchivePath $geonestArchive `
  -SourceRoot $ProjectRoot `
  -Items @('.') `
  -ExcludePatterns $projectExcludes

Write-Host 'Creating exact modified QGIS source archive...'
Invoke-SourceArchive `
  -ArchivePath $qgisArchive `
  -SourceRoot $QgisSource `
  -Items @('.') `
  -ExcludePatterns @('.git', 'build', 'build-*')

Write-Host 'Creating exact Qt source archive...'
Invoke-SourceArchive `
  -ArchivePath $qtArchive `
  -SourceRoot $QtSource `
  -Items @('.') `
  -ExcludePatterns @('.git', 'build', 'build-*')

Write-Host 'Creating native dependency source archive...'
Invoke-SourceArchive `
  -ArchivePath $nativeArchive `
  -SourceRoot $NativeSourceRoot `
  -Items $requiredNativeSources `
  -ExcludePatterns @('.git', 'build', 'build-*')

$archives = @($geonestArchive, $qgisArchive, $qtArchive, $nativeArchive)
$checksumLines = @()
foreach ($archive in $archives) {
  $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
  $checksumLines += "$hash  $([System.IO.Path]::GetFileName($archive))"
}
[System.IO.File]::WriteAllLines(
  (Join-Path $OutputDirectory 'SOURCE-SHA256SUMS.txt'),
  $checksumLines,
  [System.Text.UTF8Encoding]::new($false)
)

$qgisOhOsChange = Join-Path $QgisSource 'src\core\CMakeLists.txt'
$qgisOhOsHash = (Get-FileHash -LiteralPath $qgisOhOsChange -Algorithm SHA256).Hash
$manifestLines = @(
  'GeoNest corresponding source manifest',
  "GeoNest version: $VersionName",
  "QGIS version from source: $qgisVersion development snapshot",
  "Qt version: $QtVersion",
  '',
  'The QGIS input was an exact source snapshot without Git metadata.',
  'Its complete source archive is authoritative for this release.',
  "Modified QGIS file: src/core/CMakeLists.txt",
  "Modified QGIS file SHA-256: $qgisOhOsHash",
  '',
  'Archives:',
  $([string]::Join([Environment]::NewLine, ($archives | ForEach-Object {
    [System.IO.Path]::GetFileName($_)
  }))),
  '',
  'Build and installation scripts are in the GeoNest archive.',
  'Original upstream license files are retained in every dependency archive.'
)
[System.IO.File]::WriteAllLines(
  (Join-Path $OutputDirectory 'SOURCE-MANIFEST.txt'),
  $manifestLines,
  [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Corresponding source created in: $OutputDirectory"
