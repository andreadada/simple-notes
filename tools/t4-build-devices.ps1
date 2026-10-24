# Local T4.2 acceptance builds (Windows host; does not install or delete apps).
# Private configuration is read from an ignored file; OAuth client IDs are public,
# but client secrets, API tokens and keystore passwords MUST NEVER be added here.
[CmdletBinding()]
param(
  [ValidateSet('both', 'windows', 'android')]
  [string]$Target = 'both',
  [string]$ConfigPath,
  [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$app = Join-Path $repo 'apps/flutter'
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
  $ConfigPath = Join-Path $repo '.t4-device-build.json'
}
if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
  throw 'Missing local OAuth IDs file. Copy tools/t4-device-build.example.json to .t4-device-build.json, then fill in both client IDs (never client secrets).'
}
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$keys = @($config.PSObject.Properties.Name)
$allowed = @('GOOGLE_DESKTOP_CLIENT_ID', 'GOOGLE_WEB_CLIENT_ID')
foreach ($key in $keys) {
  if ($key -notin $allowed) {
    throw 'Unexpected config key: only GOOGLE_DESKTOP_CLIENT_ID and GOOGLE_WEB_CLIENT_ID are supported. Do not put secrets in this file.'
  }
}
$oauthPattern = '^[0-9]+-[A-Za-z0-9_-]+[.]apps[.]googleusercontent[.]com$'
foreach ($key in $allowed) {
  $value = [string]$config.$key
  if ($value -notmatch $oauthPattern) {
    throw "Invalid or missing $key. Use the Google OAuth client ID, not a client secret or placeholder."
  }
}
if ($ValidateOnly) {
  Write-Host 'PASS: T4.2 config shape and client ID formats valid. No build or install performed.'
  return
}

# Refuse to claim a reproducible device build from a modified tracked tree.
$changes = @(& git -C $repo status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect local Git status.' }
if ($changes.Count -gt 0) {
  throw 'Tracked files changed locally. Commit or stash your work first; this tool never discards it.'
}
$commit = (& git -C $repo rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
  throw 'Unable to determine the source commit.'
}
$buildDir = Join-Path $repo 'build/t4-device-acceptance'
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

# Dart defines stored only under build/, already excluded by .gitignore.
$definesFile = Join-Path $buildDir 'dart-defines.json'
$defines = @{
  API_BASE_URL = 'https://api.notes.ddone.it'
  GOOGLE_DESKTOP_CLIENT_ID = [string]$config.GOOGLE_DESKTOP_CLIENT_ID
  GOOGLE_WEB_CLIENT_ID = [string]$config.GOOGLE_WEB_CLIENT_ID
}
[System.IO.File]::WriteAllText(
  $definesFile,
  ($defines | ConvertTo-Json -Compress),
  [System.Text.UTF8Encoding]::new($false)
)
function Invoke-Checked([string]$Program, [string[]]$Arguments) {
  & $Program @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Program failed (exit $LASTEXITCODE). Existing apps and data were not removed."
  }
}
$artifacts = @()
Push-Location $app
try {
  Invoke-Checked 'flutter' @('pub', 'get')
  Invoke-Checked 'dart' @('run', 'build_runner', 'build', '--delete-conflicting-outputs')
  if ($Target -in @('both', 'android')) {
    Invoke-Checked 'flutter' @('create', '--platforms=android', '--project-name', 'simple_notes', '.')
    $buildGradle = Get-Content -LiteralPath 'android/app/build.gradle.kts' -Raw
    if ($buildGradle -notmatch 'applicationId = "it[.]andreadada[.]simplenotes"') {
      throw 'REFUSED: Android applicationId changed. No APK built.'
    }
    Invoke-Checked 'flutter' @('build', 'apk', '--debug', "--dart-define-from-file=$definesFile")
    $apk = Join-Path $app 'build/app/outputs/flutter-apk/app-debug.apk'
    if (-not (Test-Path -LiteralPath $apk)) { throw 'Android APK missing.' }
    $outApk = Join-Path $buildDir 'simple-notes-t4.2-android-debug.apk'
    Copy-Item -LiteralPath $apk -Destination $outApk -Force
    $artifacts += $outApk
  }
  if ($Target -in @('both', 'windows')) {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
      throw 'Windows executable requires a Windows host.'
    }
    Invoke-Checked 'flutter' @('create', '--platforms=windows', '--project-name', 'simple_notes', '.')
    Invoke-Checked 'flutter' @('build', 'windows', '--release', "--dart-define-from-file=$definesFile")
    $releaseDir = Join-Path $app 'build/windows/x64/runner/Release'
    if (-not (Test-Path -LiteralPath $releaseDir)) { throw 'Windows release directory missing.' }
    $zip = Join-Path $buildDir 'simple-notes-t4.2-windows.zip'
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $zip -CompressionLevel Optimal
    $artifacts += $zip
  }
} finally {
  Pop-Location
}

# Manifest includes no account, token, note content or OAuth client ID.
$receipt = @(
  'T4.2 Local Acceptance Build'
  "Source commit: $commit"
  'API origin: https://api.notes.ddone.it'
  "Generated UTC: $([DateTime]::UtcNow.ToString('o'))"
  'Installation: NOT performed; SQLite/outbox NOT altered'
  'Android: debug signature uses the LOCAL developer keystore. Never uninstall'
  'an existing app to work around an incompatible update signature.'
)
foreach ($file in $artifacts) {
  $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
  $receipt += "$([IO.Path]::GetFileName($file))  SHA256=$hash"
}
$receiptFile = Join-Path $buildDir 'MANIFEST.txt'
[System.IO.File]::WriteAllLines($receiptFile, [string[]]$receipt)
Write-Host "PASS: local acceptance builds from commit $commit"
Write-Host "Artifacts and checksums: $buildDir"
Write-Host 'No installation, app reset, backend deployment or database action performed.'
