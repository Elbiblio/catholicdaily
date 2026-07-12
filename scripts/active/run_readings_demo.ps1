param(
  [string] $Date = "2026-10-01",
  [string] $Region = "NG",
  [string] $BibleVersion = "rsvce",
  [string] $Device = "emulator-5554",
  [switch] $Resident
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$flutterCommandPath = (Get-Command flutter -ErrorAction Stop).Source
if ([string]::IsNullOrWhiteSpace($flutterCommandPath)) {
  throw "Unable to resolve the flutter command path."
}

Write-Host "Launching Catholic Daily readings demo"
Write-Host "Repo:    $repoRoot"
Write-Host "Device:  $Device"
Write-Host "Date:    $Date"
Write-Host "Region:  $Region"
Write-Host "Version: $BibleVersion"

Push-Location $repoRoot
try {
  $flutterArgs = @(
    "run",
    "-d",
    $Device,
    "--dart-define=CATHOLIC_DAILY_DEMO_SCREEN=mass",
    "--dart-define=CATHOLIC_DAILY_DEMO_DATE=$Date",
    "--dart-define=CATHOLIC_DAILY_DEMO_REGION=$Region",
    "--dart-define=CATHOLIC_DAILY_DEMO_BIBLE_VERSION=$BibleVersion"
  )
  if (-not $Resident) {
    $flutterArgs += "--no-resident"
  }

  & $flutterCommandPath @flutterArgs
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
