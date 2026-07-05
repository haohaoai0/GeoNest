[CmdletBinding()]
param(
  [string]$ProjectRoot = '',
  [string]$BuildRoot = 'D:\GeoNestBuild\GeoNestReleaseSrc',
  [string]$ArtifactRoot = '',
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string]$HvigorWrapper = 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat',
  [string]$DevEcoJavaHome = 'D:\DevEco Studio\jbr',
  [string]$QgisSource = 'D:\下载\QGIS-master\QGIS-master',
  [string]$QtSource = 'D:\GeoNestDeps\qt6\src',
  [string]$NativeSourceRoot = '',
  [string]$SigningStore = $env:GEONEST_SIGNING_STORE,
  [string]$SigningProfile = $env:GEONEST_SIGNING_PROFILE,
  [string]$SigningCertificate = $env:GEONEST_SIGNING_CERTIFICATE,
  [string]$SigningAlias = $env:GEONEST_SIGNING_ALIAS,
  [string]$SigningPassword = $env:GEONEST_SIGNING_PASSWORD,
  [switch]$SkipSync,
  [switch]$SkipSignatureVerification
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
  param([string]$Message)
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-FullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Assert-FileExists {
  param(
    [string]$Path,
    [string]$Description
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "$Description not found: $Path"
  }
}

function Assert-DirectoryExists {
  param(
    [string]$Path,
    [string]$Description
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "$Description not found: $Path"
  }
}

function Remove-BuildDirectory {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  $resolvedPath = Get-FullPath $Path
  $resolvedBuildRoot = Get-FullPath $BuildRoot
  $buildRootPrefix = $resolvedBuildRoot + '\'
  if (-not $resolvedPath.StartsWith($buildRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove a path outside BuildRoot: $resolvedPath"
  }

  Write-Step "Removing generated directory: $resolvedPath"
  Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}

function Invoke-NativeCommand {
  param(
    [string]$Description,
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$WorkingDirectory,
    [string]$LogPath
  )

  Write-Step $Description
  Push-Location -LiteralPath $WorkingDirectory
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    # Windows PowerShell 5.1 wraps native stderr as ErrorRecord objects. Hvigor
    # writes warnings to stderr, so command success must be decided by exit code.
    $ErrorActionPreference = 'Continue'
    if ([string]::IsNullOrWhiteSpace($LogPath)) {
      & $FilePath @Arguments
    } else {
      & $FilePath @Arguments 2>&1 |
        ForEach-Object {
          if ($_ -is [System.Management.Automation.ErrorRecord]) {
            $_.Exception.Message
          } else {
            $_.ToString()
          }
        } |
        Tee-Object -FilePath $LogPath
    }
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
    Pop-Location
  }

  if ($exitCode -ne 0) {
    throw "$Description failed with exit code $exitCode"
  }
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = Get-FullPath $ProjectRoot
$BuildRoot = Get-FullPath $BuildRoot
if ([string]::IsNullOrWhiteSpace($NativeSourceRoot)) {
  $NativeSourceRoot = Join-Path $ProjectRoot 'native\third_party\qgis\sources'
}
$QgisSource = Get-FullPath $QgisSource
$QtSource = Get-FullPath $QtSource
$NativeSourceRoot = Get-FullPath $NativeSourceRoot
if ([string]::IsNullOrWhiteSpace($ArtifactRoot)) {
  $ArtifactRoot = Join-Path $ProjectRoot 'output\release'
}
$ArtifactRoot = Get-FullPath $ArtifactRoot

Assert-DirectoryExists $ProjectRoot 'Project root'
Assert-DirectoryExists $QgisSource 'Modified QGIS source'
Assert-DirectoryExists $QtSource 'Modified Qt source'
Assert-DirectoryExists $NativeSourceRoot 'Native dependency source root'
Assert-DirectoryExists $DevEcoSdkHome 'DevEco SDK'
Assert-FileExists $HvigorWrapper 'Hvigor wrapper'
Assert-DirectoryExists $DevEcoJavaHome 'DevEco Java runtime'
if (
  [string]::IsNullOrWhiteSpace($SigningStore) -or
  [string]::IsNullOrWhiteSpace($SigningProfile) -or
  [string]::IsNullOrWhiteSpace($SigningCertificate) -or
  [string]::IsNullOrWhiteSpace($SigningAlias)
) {
  throw 'Set GEONEST_SIGNING_STORE, GEONEST_SIGNING_PROFILE, GEONEST_SIGNING_CERTIFICATE, and GEONEST_SIGNING_ALIAS before a release build.'
}
Assert-FileExists $SigningStore 'Release keystore'
Assert-FileExists $SigningProfile 'Release profile'
Assert-FileExists $SigningCertificate 'Release certificate'

$projectPrefix = $ProjectRoot + '\'
$buildPrefix = $BuildRoot + '\'
if (
  $BuildRoot.Equals($ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
  $BuildRoot.StartsWith($projectPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
  $ProjectRoot.StartsWith($buildPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
  $BuildRoot.Equals([System.IO.Path]::GetPathRoot($BuildRoot), [System.StringComparison]::OrdinalIgnoreCase)
) {
  throw "BuildRoot must be a dedicated directory outside ProjectRoot: $BuildRoot"
}

$rootBuildProfile = Join-Path $ProjectRoot 'build-profile.json5'
$appDescriptor = Join-Path $ProjectRoot 'AppScope\app.json5'
Assert-FileExists $rootBuildProfile 'Project build profile'
Assert-FileExists $appDescriptor 'Application descriptor'

$profileText = Get-Content -Raw -LiteralPath $rootBuildProfile
$requiredSigningValues = @('"name": "default"', '"type": "HarmonyOS"', '"signingConfig": "default"', '"name": "release"')
foreach ($requiredValue in $requiredSigningValues) {
  if (-not $profileText.Contains($requiredValue)) {
    throw "Release signing configuration is incomplete. Missing from build-profile.json5: $requiredValue"
  }
}

$appText = Get-Content -Raw -LiteralPath $appDescriptor
$versionNameMatch = [regex]::Match($appText, '"versionName"\s*:\s*"([^"]+)"')
$versionCodeMatch = [regex]::Match($appText, '"versionCode"\s*:\s*(\d+)')
$bundleNameMatch = [regex]::Match($appText, '"bundleName"\s*:\s*"([^"]+)"')
if (-not $versionNameMatch.Success -or -not $versionCodeMatch.Success -or -not $bundleNameMatch.Success) {
  throw 'Unable to read bundleName, versionName, or versionCode from AppScope/app.json5'
}
$versionName = $versionNameMatch.Groups[1].Value
$versionCode = $versionCodeMatch.Groups[1].Value
$bundleName = $bundleNameMatch.Groups[1].Value

$keytool = Join-Path $DevEcoJavaHome 'bin\keytool.exe'
$java = Join-Path $DevEcoJavaHome 'bin\java.exe'
$signTool = Join-Path $DevEcoSdkHome 'default\openharmony\toolchains\lib\hap-sign-tool.jar'
Assert-FileExists $keytool 'keytool'
Assert-FileExists $java 'Java executable'
Assert-FileExists $signTool 'HarmonyOS signing tool'

if (-not [string]::IsNullOrWhiteSpace($SigningPassword)) {
  Write-Step "Validating release keystore alias '$signingAlias'"
  & $keytool -list -keystore $SigningStore -storetype PKCS12 -storepass $SigningPassword -alias $SigningAlias | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to open the release keystore or find alias '$SigningAlias'"
  }
} else {
  Write-Host 'Keystore preflight skipped. Set GEONEST_SIGNING_PASSWORD to enable it; Hvigor will still validate the encrypted signing configuration.'
}

$buildParent = Split-Path -Parent $BuildRoot
if (-not (Test-Path -LiteralPath $buildParent)) {
  New-Item -ItemType Directory -Path $buildParent -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $BuildRoot)) {
  New-Item -ItemType Directory -Path $BuildRoot -Force | Out-Null
}

if (-not $SkipSync) {
  Write-Step "Mirroring source into the dedicated build directory: $BuildRoot"
  $excludedDirectories = @(
    (Join-Path $ProjectRoot '.git'),
    (Join-Path $ProjectRoot '.hvigor'),
    (Join-Path $ProjectRoot '.idea'),
    (Join-Path $ProjectRoot '.agents'),
    (Join-Path $ProjectRoot '.playwright-cli'),
    (Join-Path $ProjectRoot 'build'),
    (Join-Path $ProjectRoot 'output'),
    (Join-Path $ProjectRoot 'entry\.idea'),
    (Join-Path $ProjectRoot 'entry\build'),
    (Join-Path $ProjectRoot 'entry\.cxx'),
    (Join-Path $ProjectRoot 'native\third_party\qgis'),
    (Join-Path $ProjectRoot 'native\third_party\qt6')
  )
  $robocopyArguments = @(
    $ProjectRoot,
    $BuildRoot,
    '/MIR',
    '/COPY:DAT',
    '/DCOPY:DAT',
    '/R:2',
    '/W:2',
    '/XJ',
    '/NFL',
    '/NDL',
    '/NP',
    '/XD'
  ) + $excludedDirectories
  $robocopyArguments += @(
    '/XF',
    'geonest_*.jpeg',
    'geonest_*_hilog.txt'
  )
  & robocopy @robocopyArguments
  $robocopyExitCode = $LASTEXITCODE
  if ($robocopyExitCode -gt 7) {
    throw "Source mirroring failed with robocopy exit code $robocopyExitCode"
  }
}

$tempBuildProfile = Join-Path $BuildRoot 'build-profile.json5'
Assert-FileExists $tempBuildProfile 'Mirrored build profile'
Remove-BuildDirectory (Join-Path $BuildRoot 'entry\.cxx')
Remove-BuildDirectory (Join-Path $BuildRoot 'entry\build')
Remove-BuildDirectory (Join-Path $BuildRoot '.hvigor')
Remove-BuildDirectory (Join-Path $BuildRoot 'build')

$releaseStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$releaseName = "GeoNest-$versionName-$versionCode-$releaseStamp"
$releaseDirectory = Join-Path $ArtifactRoot $releaseName
New-Item -ItemType Directory -Path $releaseDirectory -Force | Out-Null

$legalPayloadDirectory = Join-Path $BuildRoot 'entry\src\main\resources\rawfile\licenses'
New-Item -ItemType Directory -Path $legalPayloadDirectory -Force | Out-Null
$legalPayloadFiles = @(
  'LICENSE',
  'COPYING',
  'THIRD_PARTY_NOTICES.md',
  'SOURCE_OFFER.txt'
)
$legalPayloadSections = @()
foreach ($legalFileName in $legalPayloadFiles) {
  $legalSourcePath = Join-Path $ProjectRoot $legalFileName
  Assert-FileExists $legalSourcePath "Legal file '$legalFileName'"
  Copy-Item -LiteralPath $legalSourcePath -Destination (Join-Path $legalPayloadDirectory $legalFileName) -Force
  $legalPayloadSections += "===== $legalFileName =====`r`n`r`n" +
    (Get-Content -LiteralPath $legalSourcePath -Raw)
}

$thirdPartyLicenseDirectory = Join-Path $legalPayloadDirectory 'third_party'
New-Item -ItemType Directory -Path $thirdPartyLicenseDirectory -Force | Out-Null
$thirdPartyLicenseSources = @(
  @((Join-Path $QgisSource 'COPYING'), 'QGIS-COPYING.txt'),
  @((Join-Path $QgisSource 'Exception_to_GPL_for_Qt.txt'), 'QGIS-Qt-linking-exception.txt'),
  @((Join-Path $QtSource 'LICENSES\LGPL-3.0-only.txt'), 'Qt-LGPL-3.0-only.txt'),
  @((Join-Path $QtSource 'LICENSES\GPL-2.0-only.txt'), 'Qt-GPL-2.0-only.txt'),
  @((Join-Path $QtSource 'LICENSES\GPL-3.0-only.txt'), 'Qt-GPL-3.0-only.txt'),
  @((Join-Path $QtSource 'LICENSES\Qt-GPL-exception-1.0.txt'), 'Qt-GPL-exception-1.0.txt'),
  @((Join-Path $NativeSourceRoot 'expat-2.7.1\COPYING'), 'Expat-COPYING.txt'),
  @((Join-Path $NativeSourceRoot 'gdal-3.11.4\LICENSE.TXT'), 'GDAL-LICENSE.txt'),
  @((Join-Path $NativeSourceRoot 'geos-3.13.1\COPYING'), 'GEOS-COPYING.txt'),
  @((Join-Path $NativeSourceRoot 'libzip-1.11.4\LICENSE'), 'libzip-LICENSE.txt'),
  @((Join-Path $NativeSourceRoot 'proj-9.8.1\COPYING'), 'PROJ-COPYING.txt'),
  @((Join-Path $NativeSourceRoot 'protobuf-3.20.3\LICENSE'), 'Protobuf-LICENSE.txt'),
  @((Join-Path $NativeSourceRoot 'zstd-1.5.7\LICENSE'), 'Zstandard-LICENSE.txt'),
  @((Join-Path $NativeSourceRoot 'qtkeychain\COPYING'), 'QtKeychain-COPYING.txt')
)
foreach ($licenseSourcePair in $thirdPartyLicenseSources) {
  $licenseSourcePath = $licenseSourcePair[0]
  $licenseFileName = $licenseSourcePair[1]
  Assert-FileExists $licenseSourcePath "Third-party license '$licenseFileName'"
  Copy-Item -LiteralPath $licenseSourcePath -Destination (Join-Path $thirdPartyLicenseDirectory $licenseFileName) -Force
  $legalPayloadSections += "===== third_party/$licenseFileName =====`r`n`r`n" +
    (Get-Content -LiteralPath $licenseSourcePath -Raw)
}
[System.IO.File]::WriteAllText(
  (Join-Path $BuildRoot 'entry\src\main\resources\rawfile\OPEN_SOURCE_NOTICES.txt'),
  [string]::Join("`r`n`r`n", $legalPayloadSections),
  [System.Text.UTF8Encoding]::new($false)
)

$env:JAVA_HOME = $DevEcoJavaHome
$env:PATH = (Join-Path $DevEcoJavaHome 'bin') + ';' + $env:PATH
$env:DEVECO_SDK_HOME = $DevEcoSdkHome

$buildLog = Join-Path $releaseDirectory 'build.log'
$hvigorArguments = @(
  '--mode', 'project',
  '-p', 'product=default',
  '-p', 'buildMode=release',
  'assembleApp',
  '--no-daemon',
  '--no-incremental'
)
Invoke-NativeCommand `
  -Description 'Building signed GeoNest release APP and HAP' `
  -FilePath $HvigorWrapper `
  -Arguments $hvigorArguments `
  -WorkingDirectory $BuildRoot `
  -LogPath $buildLog

$builtAppDirectory = Join-Path $BuildRoot 'build\outputs\default'
$builtApps = @(
  Get-ChildItem -LiteralPath $builtAppDirectory -File -Filter '*-signed.app' -ErrorAction SilentlyContinue
)
if ($builtApps.Count -ne 1) {
  throw "Expected exactly one signed release APP in $builtAppDirectory, found $($builtApps.Count)"
}
$builtApp = $builtApps[0].FullName
$builtHap = Join-Path $BuildRoot 'entry\build\default\outputs\default\entry-default-signed.hap'
Assert-FileExists $builtApp 'Signed release APP'
Assert-FileExists $builtHap 'Signed release HAP'

$releaseApp = Join-Path $releaseDirectory 'GeoNest-release-signed.app'
$releaseHap = Join-Path $releaseDirectory 'GeoNest-release-signed.hap'
Copy-Item -LiteralPath $builtApp -Destination $releaseApp -Force
Copy-Item -LiteralPath $builtHap -Destination $releaseHap -Force

$signatureVerified = $false
if (-not $SkipSignatureVerification) {
  $verifiedCertificate = Join-Path $releaseDirectory '.verified-cert-chain.cer'
  $verifiedProfile = Join-Path $releaseDirectory '.verified-profile.p7b'
  $verificationLog = Join-Path $releaseDirectory 'signature-verification.log'
  try {
    Invoke-NativeCommand `
      -Description 'Verifying the signed release HAP' `
      -FilePath $java `
      -Arguments @(
        '-jar', $signTool,
        'verify-app',
        '-inFile', $releaseHap,
        '-outCertChain', $verifiedCertificate,
        '-outProfile', $verifiedProfile
      ) `
      -WorkingDirectory $releaseDirectory `
      -LogPath $verificationLog

    Assert-FileExists $verifiedProfile 'Profile extracted from signed HAP'
    $configuredProfileHash = (Get-FileHash -LiteralPath $SigningProfile -Algorithm SHA256).Hash
    $embeddedProfileHash = (Get-FileHash -LiteralPath $verifiedProfile -Algorithm SHA256).Hash
    if (-not $configuredProfileHash.Equals($embeddedProfileHash, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw 'The profile embedded in the signed HAP does not match GeoNestRelease.p7b'
    }
    $signatureVerified = $true
  } finally {
    Remove-Item -LiteralPath $verifiedCertificate -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $verifiedProfile -Force -ErrorAction SilentlyContinue
  }
}

$releaseLegalFiles = @()
foreach ($legalFileName in $legalPayloadFiles) {
  $legalSourcePath = Join-Path $ProjectRoot $legalFileName
  $legalReleasePath = Join-Path $releaseDirectory $legalFileName
  Copy-Item -LiteralPath $legalSourcePath -Destination $legalReleasePath -Force
  $releaseLegalFiles += $legalReleasePath
}
$releaseLicenseDirectory = Join-Path $releaseDirectory 'licenses'
New-Item -ItemType Directory -Path $releaseLicenseDirectory -Force | Out-Null
foreach ($licenseSourcePair in $thirdPartyLicenseSources) {
  $licenseSourcePath = $licenseSourcePair[0]
  $licenseFileName = $licenseSourcePair[1]
  $licenseReleasePath = Join-Path $releaseLicenseDirectory $licenseFileName
  Copy-Item -LiteralPath $licenseSourcePath -Destination $licenseReleasePath -Force
  $releaseLegalFiles += $licenseReleasePath
}

$sourcePackager = Join-Path $ProjectRoot 'scripts\package_corresponding_source.ps1'
Assert-FileExists $sourcePackager 'Corresponding-source packager'
Write-Step 'Packaging complete corresponding source'
& $sourcePackager `
  -ProjectRoot $ProjectRoot `
  -OutputDirectory $releaseDirectory `
  -VersionName $versionName `
  -QgisSource $QgisSource `
  -QtSource $QtSource `
  -NativeSourceRoot $NativeSourceRoot
if ($LASTEXITCODE -ne 0) {
  throw "Corresponding-source packaging failed with exit code $LASTEXITCODE"
}

$sourceArchives = @(
  Get-ChildItem -LiteralPath $releaseDirectory -File -Filter '*-source.tar.gz' |
    Sort-Object Name
)
if ($sourceArchives.Count -ne 4) {
  throw "Expected four corresponding-source archives, found $($sourceArchives.Count)"
}
$sourceMetadataFiles = @(
  (Join-Path $releaseDirectory 'SOURCE-SHA256SUMS.txt'),
  (Join-Path $releaseDirectory 'SOURCE-MANIFEST.txt')
)
foreach ($sourceMetadataFile in $sourceMetadataFiles) {
  Assert-FileExists $sourceMetadataFile 'Corresponding-source metadata'
}

$appHash = (Get-FileHash -LiteralPath $releaseApp -Algorithm SHA256).Hash
$hapHash = (Get-FileHash -LiteralPath $releaseHap -Algorithm SHA256).Hash
$checksumFiles = @($releaseApp, $releaseHap)
$checksumFiles += $releaseLegalFiles
$checksumFiles += @($sourceArchives | ForEach-Object { $_.FullName })
$checksumFiles += $sourceMetadataFiles
$checksumLines = @()
foreach ($checksumFile in $checksumFiles) {
  $checksumHash = (Get-FileHash -LiteralPath $checksumFile -Algorithm SHA256).Hash
  $checksumLines += "$checksumHash  $([System.IO.Path]::GetFileName($checksumFile))"
}
[System.IO.File]::WriteAllText(
  (Join-Path $releaseDirectory 'SHA256SUMS.txt'),
  [string]::Join("`r`n", $checksumLines) + "`r`n",
  [System.Text.UTF8Encoding]::new($false)
)

$sourceArtifactManifest = @()
foreach ($sourceArchive in $sourceArchives) {
  $sourceArtifactManifest += [ordered]@{
    file = $sourceArchive.Name
    sha256 = (Get-FileHash -LiteralPath $sourceArchive.FullName -Algorithm SHA256).Hash
    size = $sourceArchive.Length
  }
}

$manifest = [ordered]@{
  bundleName = $bundleName
  versionName = $versionName
  versionCode = [int64]$versionCode
  product = 'default'
  buildMode = 'release'
  signingAlias = $SigningAlias
  signatureVerified = $signatureVerified
  generatedAt = (Get-Date).ToString('o')
  artifacts = @(
    [ordered]@{
      file = [System.IO.Path]::GetFileName($releaseApp)
      sha256 = $appHash
      size = (Get-Item -LiteralPath $releaseApp).Length
    },
    [ordered]@{
      file = [System.IO.Path]::GetFileName($releaseHap)
      sha256 = $hapHash
      size = (Get-Item -LiteralPath $releaseHap).Length
    }
  )
  sourceArtifacts = $sourceArtifactManifest
  sourceManifest = 'SOURCE-MANIFEST.txt'
  sourceChecksums = 'SOURCE-SHA256SUMS.txt'
  license = 'GPL-2.0-or-later'
  thirdPartyLicenses = 'licenses/'
}
$manifestJson = $manifest | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText(
  (Join-Path $releaseDirectory 'release-manifest.json'),
  $manifestJson + [Environment]::NewLine,
  [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::WriteAllText(
  (Join-Path $ArtifactRoot 'latest.txt'),
  $releaseDirectory + [Environment]::NewLine,
  [System.Text.UTF8Encoding]::new($false)
)

Write-Step 'Release build completed'
Write-Host "Artifacts: $releaseDirectory" -ForegroundColor Green
Write-Host "APP SHA-256: $appHash"
Write-Host "HAP SHA-256: $hapHash"
