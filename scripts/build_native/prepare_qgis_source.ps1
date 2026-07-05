param(
  [string]$Destination = 'F:\HarmonyProjects\GeoNest\native\third_party\qgis\QGIS',
  [string]$Repository = 'https://github.com/qgis/QGIS.git',
  [string]$Branch = 'master'
)

$ErrorActionPreference = 'Stop'

if (Test-Path -LiteralPath $Destination) {
  throw "Destination already exists: $Destination"
}

$parent = Split-Path -Parent $Destination
if (-not (Test-Path -LiteralPath $parent)) {
  New-Item -ItemType Directory -Path $parent | Out-Null
}

git clone --depth 1 --filter=blob:none --sparse --branch $Branch $Repository $Destination
Push-Location $Destination
try {
  git sparse-checkout set CMakeLists.txt cmake src/core src/providers/ogr resources
} finally {
  Pop-Location
}

Write-Host "QGIS sparse source checkout prepared at $Destination"
Write-Host "Build QGIS Core into native/third_party/qgis/stage before configuring native/qgis_core_probe."
