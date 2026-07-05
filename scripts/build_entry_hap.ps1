param(
  [string]$DevEcoSdkHome = 'D:\DevEco Studio\sdk',
  [string]$HvigorWrapper = 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat',
  [string]$DevEcoJavaHome = 'D:\DevEco Studio\jbr'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $DevEcoSdkHome)) {
  throw "DevEco SDK home not found: $DevEcoSdkHome"
}

if (-not (Test-Path -LiteralPath $HvigorWrapper)) {
  throw "Hvigor wrapper not found: $HvigorWrapper"
}

if (Test-Path -LiteralPath $DevEcoJavaHome) {
  $env:JAVA_HOME = $DevEcoJavaHome
  $env:PATH = (Join-Path $DevEcoJavaHome 'bin') + ';' + $env:PATH
}

$env:DEVECO_SDK_HOME = $DevEcoSdkHome
& $HvigorWrapper --mode module -p module=entry -p product=default -p buildMode=release assembleHap --no-daemon
