# Bump pubspec.yaml version build number (+N) by 1, keep base version.
# Called by build_apk.cmd before flutter build, so every APK can install over the previous one.
$path = "D:\traeproj\JZproject\mobile\pubspec.yaml"
$text = [IO.File]::ReadAllText($path)
if ($text -match 'version:\s*([\d.]+)(?:\+(\d+))?') {
    $base = $Matches[1]
    $build = if ($Matches[2]) { [int]$Matches[2] + 1 } else { 1 }
    $text = $text -replace 'version:[^\r\n]+', "version: $base+$build"
    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
    Write-Output "Version bumped to: $base+$build"
} else {
    Write-Output "WARN: version line not found in pubspec.yaml, skip bump"
}
