$prayerDir = 'c:\dev\catholicdaily-flutter\assets\prayers'
Get-ChildItem -Path $prayerDir -Filter '*.html' | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match 'data:image/jpg') {
        $content = $content -replace 'data:image/jpg', 'data:image/jpeg'
        Set-Content -Path $_.FullName -Value $content -NoNewline
        Write-Host "Updated" $_.Name
    }
}
