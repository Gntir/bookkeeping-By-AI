# 从 pubspec.yaml 读版本号 + release_note.txt 读更新说明，生成 release.json（供后端版本接口读取）
$root = $PSScriptRoot
$ver = (Select-String -Path "$root\mobile\pubspec.yaml" -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
$note = [IO.File]::ReadAllText("$root\release_note.txt").Trim()
$note = $note -replace '"', '\"' -replace '\r?\n', ' '
$json = '{"version": "' + $ver + '", "note": "' + $note + '"}'
[IO.File]::WriteAllText("$root\release.json", $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "release.json generated: version=$ver"
