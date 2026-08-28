#!/usr/bin/env bash
#
# Generates the native platform folders for the Flutter app, then runs code
# generation. See tool/bootstrap.ps1 for the Windows equivalent.
#
# `flutter create` regenerates template files - including lib/main.dart - so the
# hand-written sources are backed up first and restored afterwards.

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter was not found on PATH. Install the Flutter SDK first:" >&2
  echo "  https://docs.flutter.dev/get-started/install" >&2
  exit 1
fi

backup="$(mktemp -d)"
trap 'rm -rf "$backup"' EXIT

echo "Backing up hand-written sources to $backup"
for item in lib test tool pubspec.yaml analysis_options.yaml README.md; do
  [ -e "$item" ] && cp -R "$item" "$backup/"
done

# Restores the hand-written sources even if `flutter create` fails part way
# through, which would otherwise leave the template files in place.
restore_sources() {
  echo "Restoring hand-written sources..."
  for item in lib test tool; do
    if [ -e "$backup/$item" ]; then
      rm -rf "$item"
      cp -R "$backup/$item" .
    fi
  done
  # The committed analysis_options.yaml already carries the platform excludes
  # `flutter create` would add, so restoring it loses nothing.
  for item in pubspec.yaml analysis_options.yaml README.md; do
    [ -e "$backup/$item" ] && cp -f "$backup/$item" .
  done
}
trap 'restore_sources; rm -rf "$backup"' EXIT

echo "Generating native platform folders..."
flutter create --platforms=android,ios,linux,macos,windows \
  --project-name drp_mobile --org com.drp .

restore_sources
trap 'rm -rf "$backup"' EXIT

echo "Resolving dependencies..."
flutter pub get

echo "Running Drift code generation..."
dart run build_runner build

cat <<'EOF'

Done. Next:
  flutter analyze
  flutter test
  flutter run --dart-define=DRP_API_BASE_URL=http://10.0.2.2:8000/api/v1
EOF
