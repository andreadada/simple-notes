# Clear local TEST data only AFTER server reset; no uninstall on Android.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('windows','android')]
  [string]$Target,
  [switch]$Execute,
  [string]$DatabasePath,
  [string]$AndroidSerial,
  [string]$ConfirmText
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Execute -and $ConfirmText -ne 'ERASE_SIMPLE_NOTES_TEST_WORKSPACE') {
  throw 'REFUSED: -ConfirmText ERASE_SIMPLE_NOTES_TEST_WORKSPACE is required.'
}
if ($Target -eq 'windows') {
  if (Get-Process -Name 'simple_notes' -ErrorAction SilentlyContinue) {
    throw 'Close the Simple Notes Windows app before resetting local data.'
  }
  $matches = @()
  if (-not [string]::IsNullOrWhiteSpace($DatabasePath)) {
    if (-not (Test-Path -LiteralPath $DatabasePath -PathType Leaf)) {
      throw 'Specified SQLite path not found.'
    }
    $matches = @(Get-Item -LiteralPath $DatabasePath)
  } else {
    $roots = @($env:APPDATA, $env:LOCALAPPDATA) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
    foreach ($root in $roots) {
      $matches += @(Get-ChildItem -LiteralPath $root -Filter 'simple_notes.sqlite' -File -Recurse -ErrorAction SilentlyContinue)
    }
    $matches = @($matches | Sort-Object FullName -Unique)
  }
  if ($matches.Count -ne 1) {
    Write-Host "Found $($matches.Count) SQLite candidates:"
    foreach ($item in $matches) { Write-Host $item.FullName }
    throw 'REFUSED: specify exactly one Simple Notes SQLite database using -DatabasePath.'
  }
  $db = $matches[0].FullName
  if ([IO.Path]::GetFileName($db) -ne 'simple_notes.sqlite') {
    throw 'REFUSED: expected simple_notes.sqlite file.'
  }
  $files = @($db, "$db-wal", "$db-shm") | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
  Write-Host "Windows SQLite TEST data: $db"
  foreach ($file in $files) { Write-Host "  $file" }
  if (-not $Execute) {
    Write-Host 'PREVIEW_ONLY: no files removed.'
    return
  }
  foreach ($file in $files) { Remove-Item -LiteralPath $file -Force -ErrorAction Stop }
  Write-Host 'WINDOWS_LOCAL_DATA_ERASED. Other app files/tokens were not touched.'
  return
}
$adb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
if (-not (Test-Path -LiteralPath $adb -PathType Leaf)) {
  throw 'ADB not found under LOCALAPPDATA Android SDK.'
}
$lines = @(& $adb devices)
if ($LASTEXITCODE -ne 0) { throw 'adb devices failed.' }
$devices = @()
foreach ($line in $lines) {
  if ($line -match '^([A-Za-z0-9._:-]+)\s+device$') {
    $devices += $Matches[1]
  }
}
if (-not [string]::IsNullOrWhiteSpace($AndroidSerial)) {
  if ($AndroidSerial -notin $devices) { throw 'Requested Android device is not connected.' }
  $serial = $AndroidSerial
} elseif ($devices.Count -eq 1) {
  $serial = $devices[0]
} else {
  throw 'REFUSED: connect exactly one Android device, or use -AndroidSerial.'
}
Write-Host "Android device: $serial"
Write-Host 'Target: it.andreadada.simplenotes (wipes app storage, including Google login, but retains APK)'
if (-not $Execute) {
  Write-Host 'PREVIEW_ONLY: no Android data removed.'
  return
}
$result = @(& $adb -s $serial shell pm clear 'it.andreadada.simplenotes')
if ($LASTEXITCODE -ne 0 -or ($result -join '') -notmatch 'Success') {
  throw "Android local reset failed: $($result -join '; ')"
}
Write-Host 'ANDROID_LOCAL_DATA_ERASED. APK remains installed.'
