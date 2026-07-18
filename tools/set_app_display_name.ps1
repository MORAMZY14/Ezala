param(
    [string]$AppName = "Ezla Project"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Update-GroupedText {
    param(
        [string]$RelativePath,
        [string]$Pattern,
        [string]$Value
    )

    $Path = Join-Path $ProjectRoot $RelativePath
    if (-not (Test-Path $Path)) {
        Write-Host "Skipped $RelativePath (not generated yet)"
        return
    }

    $Text = [System.IO.File]::ReadAllText($Path)
    $Updated = [regex]::Replace(
        $Text,
        $Pattern,
        { param($Match)
            return $Match.Groups[1].Value + $Value + $Match.Groups[2].Value
        },
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    if ($Updated -eq $Text) {
        Write-Host "No matching name found in $RelativePath"
        return
    }

    [System.IO.File]::WriteAllText($Path, $Updated, $Utf8NoBom)
    Write-Host "Updated $RelativePath"
}

Update-GroupedText `
    "android/app/src/main/AndroidManifest.xml" `
    '(android:label=")[^"]*(")' `
    $AppName

Update-GroupedText `
    "ios/Runner/Info.plist" `
    '(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)' `
    $AppName

Update-GroupedText `
    "ios/Runner/Info.plist" `
    '(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)' `
    $AppName

Update-GroupedText `
    "web/index.html" `
    '(<title>)[^<]*(</title>)' `
    $AppName

Update-GroupedText `
    "web/index.html" `
    '(<meta\s+name="apple-mobile-web-app-title"\s+content=")[^"]*(")' `
    $AppName

$ManifestPath = Join-Path $ProjectRoot "web/manifest.json"
if (Test-Path $ManifestPath) {
    $Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $Manifest.name = $AppName
    $Manifest.short_name = $AppName
    $Json = $Manifest | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($ManifestPath, $Json, $Utf8NoBom)
    Write-Host "Updated web/manifest.json"
} else {
    Write-Host "Skipped web/manifest.json (not generated yet)"
}

Update-GroupedText `
    "windows/runner/main.cpp" `
    '(window\.Create\(L")[^"]*(")' `
    $AppName

Update-GroupedText `
    "macos/Runner/Configs/AppInfo.xcconfig" `
    '(PRODUCT_NAME\s*=\s*)[^\r\n]*(\r?\n)' `
    $AppName

Write-Host "App display name is now '$AppName'."
Write-Host "Run: flutter clean; flutter pub get; flutter run"
