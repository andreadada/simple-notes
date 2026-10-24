# Local T4.2 acceptance builds (Windows host; does not install or delete apps).
# Private configuration is read from an ignored file; OAuth client IDs are public,
# but client secrets, API tokens and keystore passwords MUST NEVER be added here.
[CmdletBinding()]
param(
  [ValidateSet('both', 'windows', 'android')]
  [string]$Target = 'both',
  [string]$ConfigPath,
  [switch]$ValidateOnly,
  [switch]$CheckOnly,
  [switch]$RequireClean
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

# Local changes belong to the developer. Never stash, reset or discard them.
# A dirty build is allowed for T4.2, but must be marked non-reproducible.
$changes = @(& git -C $repo status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect local Git status.' }
$dirtyAtStart = $changes.Count -gt 0
if ($dirtyAtStart) {
  if ($RequireClean) {
    throw 'Local tracked files have changes. -RequireClean was requested; no build performed. Local changes were preserved.'
  }
  Write-Warning ("{0} tracked file(s) have local changes. Building the LOCAL working tree without stash/reset. The result cannot be reproduced from the commit alone." -f $changes.Count)
}
$commit = (& git -C $repo rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
  throw 'Unable to determine the source commit.'
}
if ($CheckOnly) {
  Write-Host "PASS: T4.2 preflight checked (commit $commit; local changes: $dirtyAtStart)."
  Write-Host 'No builds, installs, stash/reset or changes to app data were performed.'
  return
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
  # Avoid --delete-conflicting-outputs: never silently remove local generated edits.
  Invoke-Checked 'dart' @('run', 'build_runner', 'build')
  if ($Target -in @('both', 'android')) {
    # Only generate missing scaffolding; do not regenerate existing platform files.
    if (-not (Test-Path -LiteralPath 'android/gradlew' -PathType Leaf) -or
        -not (Test-Path -LiteralPath 'android/settings.gradle.kts' -PathType Leaf)) {
      Invoke-Checked 'flutter' @('create', '--platforms=android', '--project-name', 'simple_notes', '.')
    }
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
    if (-not (Test-Path -LiteralPath 'windows/CMakeLists.txt' -PathType Leaf) -or
        -not (Test-Path -LiteralPath 'windows/runner/CMakeLists.txt' -PathType Leaf)) {
      Invoke-Checked 'flutter' @('create', '--platforms=windows', '--project-name', 'simple_notes', '.')
    }
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

# Flutter tooling may update tracked/generated files; report this honestly.
$changesAtEnd = @(& git -C $repo status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect final local Git status.' }
$dirtyAtEnd = $changesAtEnd.Count -gt 0
if ($dirtyAtEnd) {
  Write-Warning 'Build completed with tracked local changes. Review git status before committing; no automatic restore was performed.'
}
# Manifest includes no account, token, note content or OAuth client ID.
$receipt = @(
  'T4.2 Local Acceptance Build'
  "Source HEAD: $commit"
  "Local tracked changes at start: $dirtyAtStart ($($changes.Count) file(s))"
  "Local tracked changes at end: $dirtyAtEnd ($($changesAtEnd.Count) file(s))"
  'Source reproducibility: only clean local working trees can be reproduced from HEAD'
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
Write-Host "PASS: local acceptance builds from checkout at $commit (local changes at start: $dirtyAtStart)"
Write-Host "Artifacts and checksums: $buildDir"
Write-Host 'No installation, app reset, backend deployment or database action performed.'
