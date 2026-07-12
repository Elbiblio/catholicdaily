$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$outputDir = Join-Path $repoRoot "verification\comprehensive-readings-audit"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resolverLog = Join-Path $outputDir "resolver-$timestamp.log"
$testPath = "test/data/services/comprehensive_resolver_audit_test.dart"
$flutterCommandPath = (Get-Command flutter -ErrorAction Stop).Source
if ([string]::IsNullOrWhiteSpace($flutterCommandPath)) {
  throw "Unable to resolve the flutter command path."
}

Write-Host "Comprehensive readings audit"
Write-Host "Repo: $repoRoot"
Write-Host "Log:  $resolverLog"
Write-Host "Running: flutter test $testPath"

Push-Location $repoRoot
try {
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    & $flutterCommandPath test $testPath 2>&1 |
      Tee-Object -FilePath $resolverLog -ErrorAction Stop
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  if ($exitCode -isnot [int]) {
    Write-Host "Audit failed because flutter did not report a valid exit code. Log written to $resolverLog"
    $exitCode = 1
  }

  if ($exitCode -eq 0) {
    Write-Host "Audit passed. Log written to $resolverLog"
  } else {
    Write-Host "Audit failed with exit code $exitCode. Log written to $resolverLog"
  }

  exit $exitCode
} finally {
  Pop-Location
}
