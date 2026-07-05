param(
  [string]$QtSource = 'D:\GeoNestDeps\qt6\src'
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$patchRoot = Join-Path $repoRoot 'native\third_party\qt6\patches'

function Require-Path {
  param(
    [string]$Path,
    [string]$Label
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "$Label not found: $Path"
  }
}

Require-Path $QtSource 'Qt source directory'
Require-Path (Join-Path $QtSource 'qtbase\CMakeLists.txt') 'Qt qtbase source'

$patches = @(
  'qt6-6.8.3-ohos-core.patch',
  'qt6-6.8.3-ohos-storageinfo.patch',
  'qt6-6.8.3-ohos-qprocess-sigaction.patch',
  'qt6-6.8.3-ohos-modification-notices.patch'
)

foreach ($patchName in $patches) {
  $patchPath = Join-Path $patchRoot $patchName
  Require-Path $patchPath 'Qt6/OHOS patch'

  git -C $QtSource apply --check $patchPath 2>$null
  if ($LASTEXITCODE -eq 0) {
    git -C $QtSource apply $patchPath
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to apply patch: $patchPath"
    }
    Write-Output "Applied $patchName"
    continue
  }

  git -C $QtSource apply --reverse --check $patchPath 2>$null
  if ($LASTEXITCODE -eq 0) {
    Write-Output "Already applied $patchName"
    continue
  }

  throw "Patch does not apply cleanly and is not already applied: $patchPath"
}
