$prayerDir = 'c:\dev\catholicdaily-flutter\assets\prayers'
$imageDir = Join-Path $prayerDir 'images'

if (-not (Test-Path $imageDir)) {
    New-Item -ItemType Directory -Path $imageDir | Out-Null
}

$patterns = @('joyful*.html', 'sorrowful*.html', 'glorious*.html', 'light*.html')
$files = @()
foreach ($pattern in $patterns) {
    $files += Get-ChildItem -Path $prayerDir -Filter $pattern
}

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $match = [regex]::Match($content, 'data:image/jpeg;base64,([^\"]+)')

    if ($match.Success) {
        $base64 = $match.Groups[1].Value
        $bytes = [Convert]::FromBase64String($base64)
        $imagePath = Join-Path $imageDir ($file.BaseName + '.jpg')
        [System.IO.File]::WriteAllBytes($imagePath, $bytes)

        $newSrc = "src=`"asset:assets/prayers/images/$($file.BaseName).jpg`""
        $content = [regex]::Replace($content, 'src="data:image/jpeg;base64,[^\"]+"', $newSrc)
        Set-Content -Path $file.FullName -Value $content -NoNewline

        Write-Host "Decoded $($file.Name) -> $imagePath"
    } else {
        Write-Host "No base64 found in $($file.Name)"
    }
}
