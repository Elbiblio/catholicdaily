$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$outputDir = Join-Path $repoRoot "verification\comprehensive-readings-audit"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resolverLog = Join-Path $outputDir "resolver-$timestamp.log"
$displayedSamplesLog = Join-Path $outputDir "displayed-samples-$timestamp.log"
$demoConfigLog = Join-Path $outputDir "demo-config-$timestamp.log"
$massFlowRegionLog = Join-Path $outputDir "mass-flow-region-$timestamp.log"
$flutterCommandPath = (Get-Command flutter -ErrorAction Stop).Source
if ([string]::IsNullOrWhiteSpace($flutterCommandPath)) {
  throw "Unable to resolve the flutter command path."
}

function Invoke-FlutterTest {
  param(
    [Parameter(Mandatory = $true)]
    [string] $TestPath,
    [Parameter(Mandatory = $true)]
    [string] $LogPath
  )

  Write-Host "Running: flutter test $TestPath"
  Write-Host "Log:     $LogPath"

  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $output = & $flutterCommandPath test $TestPath 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  $output | Tee-Object -FilePath $LogPath -ErrorAction Stop | Out-Host

  if ($exitCode -isnot [int]) {
    Write-Host "Audit failed because flutter did not report a valid exit code. Log written to $LogPath"
    return 1
  }

  return $exitCode
}

Write-Host "Comprehensive readings audit"
Write-Host "Repo: $repoRoot"

Push-Location $repoRoot
try {
  $exitCode = Invoke-FlutterTest `
    -TestPath "test/data/services/comprehensive_resolver_audit_test.dart" `
    -LogPath $resolverLog
  if ($exitCode -ne 0) {
    Write-Host "Audit failed with exit code $exitCode. Log written to $resolverLog"
    exit $exitCode
  }

  $exitCode = Invoke-FlutterTest `
    -TestPath "test/data/services/displayed_readings_source_sample_test.dart" `
    -LogPath $displayedSamplesLog
  if ($exitCode -ne 0) {
    Write-Host "Audit failed with exit code $exitCode. Log written to $displayedSamplesLog"
    exit $exitCode
  }

  $exitCode = Invoke-FlutterTest `
    -TestPath "test/demo_launch_config_test.dart" `
    -LogPath $demoConfigLog
  if ($exitCode -ne 0) {
    Write-Host "Audit failed with exit code $exitCode. Log written to $demoConfigLog"
    exit $exitCode
  }

  $exitCode = Invoke-FlutterTest `
    -TestPath "test/widgets/mass_flow_region_header_test.dart" `
    -LogPath $massFlowRegionLog
  if ($exitCode -ne 0) {
    Write-Host "Audit failed with exit code $exitCode. Log written to $massFlowRegionLog"
    exit $exitCode
  }

  Write-Host "Audit passed."
  Write-Host "Resolver log:          $resolverLog"
  Write-Host "Displayed samples log: $displayedSamplesLog"
  Write-Host "Demo config log:       $demoConfigLog"
  Write-Host "Mass flow region log:  $massFlowRegionLog"
  exit 0
} finally {
  Pop-Location
}
