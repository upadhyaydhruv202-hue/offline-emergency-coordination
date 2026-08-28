<#
.SYNOPSIS
    Generates the native platform folders for the Flutter app, then runs code generation.

.DESCRIPTION
    This repository tracks only `lib/`, `test/` and the pubspec: the android/, ios/
    and windows/ directories are machine-generated and are not committed.

    `flutter create` regenerates template files - including lib/main.dart and
    test/widget_test.dart - so this script backs up the hand-written sources first
    and restores them afterwards, even if `flutter create` fails part way through.

.EXAMPLE
    cd mobile
    ./tool/bootstrap.ps1
#>

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

$backup = $null

try {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw 'flutter was not found on PATH. Install the Flutter SDK first: https://docs.flutter.dev/get-started/install'
    }

    $backup = Join-Path $env:TEMP ('drp_mobile_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $backup | Out-Null
    Write-Host "Backing up hand-written sources to $backup" -ForegroundColor Cyan

    foreach ($item in @('lib', 'test', 'tool', 'pubspec.yaml', 'analysis_options.yaml', 'README.md')) {
        if (Test-Path $item) {
            Copy-Item $item -Destination $backup -Recurse -Force
        }
    }

    try {
        Write-Host 'Generating native platform folders...' -ForegroundColor Cyan
        flutter create --platforms=android,ios,windows --project-name drp_mobile --org com.drp .

        # `flutter create` exits non-zero when it cannot symlink plugins, which on
        # Windows means Developer Mode is off. The platform folders are still
        # written, and neither `flutter analyze` nor `flutter test` needs the
        # symlinks, so this is reported rather than treated as fatal.
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "flutter create exited with code $LASTEXITCODE."
            Write-Warning 'On Windows this is usually missing symlink support. Building for a'
            Write-Warning 'device needs Developer Mode enabled:  start ms-settings:developers'
            Write-Warning 'The analyzer and the test suite work without it.'
        }
    }
    finally {
        Write-Host 'Restoring hand-written sources...' -ForegroundColor Cyan
        foreach ($item in @('lib', 'test', 'tool')) {
            $source = Join-Path $backup $item
            if (Test-Path $source) {
                if (Test-Path $item) { Remove-Item $item -Recurse -Force }
                Copy-Item $source -Destination $projectRoot -Recurse -Force
            }
        }
        # The committed analysis_options.yaml already carries the platform
        # excludes `flutter create` would add, so restoring it loses nothing.
        foreach ($item in @('pubspec.yaml', 'analysis_options.yaml', 'README.md')) {
            $source = Join-Path $backup $item
            if (Test-Path $source) { Copy-Item $source -Destination $projectRoot -Force }
        }
    }

    Write-Host 'Resolving dependencies...' -ForegroundColor Cyan
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed with exit code $LASTEXITCODE" }

    Write-Host 'Running Drift code generation...' -ForegroundColor Cyan
    dart run build_runner build
    if ($LASTEXITCODE -ne 0) { throw "build_runner failed with exit code $LASTEXITCODE" }

    Write-Host ''
    Write-Host 'Done. Next:' -ForegroundColor Green
    Write-Host '  flutter analyze'
    Write-Host '  flutter test'
    Write-Host '  flutter run --dart-define=DRP_API_BASE_URL=http://10.0.2.2:8000/api/v1'
}
finally {
    if ($backup -and (Test-Path $backup)) { Remove-Item $backup -Recurse -Force }
    Pop-Location
}
