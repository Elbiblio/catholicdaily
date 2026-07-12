$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$outputDir = Join-Path $repoRoot "verification\comprehensive-readings-audit"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resolverLog = Join-Path $outputDir "resolver-$timestamp.log"
$testPath = "test/data/services/comprehensive_resolver_audit_test.dart"

Write-Host "Comprehensive readings audit"
Write-Host "Repo: $repoRoot"
Write-Host "Log:  $resolverLog"
Write-Host "Running: flutter test $testPath"

Push-Location $repoRoot
try {
  flutter test $testPath 2>&1 | Tee-Object -FilePath $resolverLog
  $exitCode = $LASTEXITCODE

  if ($exitCode -eq 0) {
    Write-Host "Audit passed. Log written to $resolverLog"
  } else {
    Write-Host "Audit failed with exit code $exitCode. Log written to $resolverLog"
  }

  exit $exitCode
} finally {
  Pop-Location
}
