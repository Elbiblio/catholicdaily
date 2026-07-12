$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$outputDir = Join-Path $repoRoot "verification\comprehensive-readings-audit"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logPath = Join-Path $outputDir "exact-text-local-extract-$timestamp.log"
$flutterCommandPath = (Get-Command flutter -ErrorAction Stop).Source
if ([string]::IsNullOrWhiteSpace($flutterCommandPath)) {
  throw "Unable to resolve the flutter command path."
}

Write-Host "Exact displayed reading text audit"
Write-Host "Repo: $repoRoot"
Write-Host "Log:  $logPath"
Write-Host "Report: verification\comprehensive-readings-audit\exact-text-local-extract-report.json"

Push-Location $repoRoot
try {
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $output = & $flutterCommandPath test `
      --dart-define=RUN_EXACT_TEXT_AUDIT=true `
      test/data/services/displayed_readings_exact_text_audit_test.dart 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  $output | Tee-Object -FilePath $logPath -ErrorAction Stop | Out-Host

  if ($exitCode -isnot [int]) {
    Write-Host "Exact text audit failed because flutter did not report a valid exit code."
    exit 1
  }

  exit $exitCode
} finally {
  Pop-Location
}
