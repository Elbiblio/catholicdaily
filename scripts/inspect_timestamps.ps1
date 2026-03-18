$timestamps = 1775260800, 1955865600, 1963987200
foreach ($ts in $timestamps) {
  $utc = [DateTimeOffset]::FromUnixTimeSeconds($ts).UtcDateTime
  $local = [DateTimeOffset]::FromUnixTimeSeconds($ts).LocalDateTime
  Write-Output "ts=$ts utc=$($utc.ToString('yyyy-MM-dd HH:mm:ss')) local=$($local.ToString('yyyy-MM-dd HH:mm:ss'))"
}
