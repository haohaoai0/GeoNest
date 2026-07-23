param(
  [string]$FreeXlSource = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\sources\freexl-2.0.0',
  [string]$StageRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\stage',
  [string]$BuildRoot = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\build-freexl-ohos',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string[]]$AbiFilters = @('arm64-v8a', 'x86_64')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $FreeXlSource)) {
  throw "FreeXL 2.0.0 source directory not found: $FreeXlSource. Download the official freexl-2.0.0 archive from https://www.gaia-gis.it/fossil/freexl and extract it here."
}

$clang = Join-Path $DevEcoSdkHome 'default\openharmony\native\llvm\bin\clang.exe'
$sysroot = Join-Path $DevEcoSdkHome 'default\openharmony\native\sysroot'
if (-not (Test-Path -LiteralPath $clang)) {
  throw "HarmonyOS clang not found: $clang"
}

foreach ($abi in $AbiFilters) {
  $target = if ($abi -eq 'arm64-v8a') { 'aarch64-linux-ohos' } elseif ($abi -eq 'x86_64') {
    'x86_64-linux-ohos'
  } else {
    throw "Unsupported FreeXL ABI: $abi"
  }
  $buildDir = Join-Path $BuildRoot $abi
  $stageDir = Join-Path $StageRoot $abi
  $includeDir = Join-Path $stageDir 'include'
  $libDir = Join-Path $stageDir 'lib'
  New-Item -ItemType Directory -Force -Path $buildDir, $includeDir, $libDir | Out-Null

  $configHeader = Join-Path $buildDir 'config.h'
  @'
#define OMIT_XMLDOC 1
#define HAVE_INTTYPES_H 1
#define HAVE_MATH_H 1
#define HAVE_MEMORY_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDIO_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRINGS_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#define HAVE_STRCASECMP 1
#define HAVE_STRNCASECMP 1
#define HAVE_STRERROR 1
#define HAVE_STRFTIME 1
#define HAVE_STRSTR 1
#define STDC_HEADERS 1
#define PACKAGE "freexl"
#define PACKAGE_NAME "FreeXL"
#define PACKAGE_VERSION "2.0.0"
#define VERSION "2.0.0"
'@ | Set-Content -LiteralPath $configHeader -Encoding utf8

  $outputLib = Join-Path $libDir 'libfreexl.so.3.2.0'
  & $clang `
    -target $target `
    "--sysroot=$sysroot" `
    -fPIC -O2 -shared `
    "-I$($FreeXlSource)\headers" `
    "-I$buildDir" `
    "-Wl,-soname,libfreexl.so.3" `
    "-o$outputLib" `
    "$(Join-Path $FreeXlSource 'src\freexl.c')" `
    -lm
  if ($LASTEXITCODE -ne 0) {
    throw "FreeXL build failed for $abi"
  }

  Copy-Item -Force -LiteralPath (Join-Path $FreeXlSource 'headers\freexl.h') -Destination $includeDir
  Copy-Item -Force -LiteralPath $outputLib -Destination (Join-Path $libDir 'libfreexl.so.3')
  Copy-Item -Force -LiteralPath $outputLib -Destination (Join-Path $libDir 'libfreexl.so')
}
