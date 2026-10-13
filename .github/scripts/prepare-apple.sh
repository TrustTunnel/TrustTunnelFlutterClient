#!/bin/bash
# The preparation of the iOS or macOS build on CI, run by the shared build workflow inside the build job
# (build-flutter-ios-app.yml / build-flutter-macos-app.yml of AdGuardSoftwareLimited/actions) with the project's
# Flutter SDK on PATH and PROJECT_VERSION, BUILD_NUMBER set by the workflow.
# Usage: .github/scripts/prepare-apple.sh ios|macos
set -euo pipefail
set -x
platform=${1:?ios or macos}
case "$platform" in ios|macos) ;; *) echo "platform must be ios or macos, got '$platform'" >&2; exit 1 ;; esac


# Ruby for CocoaPods.
eval "$(rbenv init - bash)"
rbenv install 3.3.10 --skip-existing
rbenv local 3.3.10
rbenv rehash
printf '%s\n' "$HOME/.rbenv/bin" "$HOME/.rbenv/shims" >> "$GITHUB_PATH"
gem install bundler -v 2.7.2
rbenv rehash
export BUNDLER_VERSION=2.7.2
(cd "$platform" && bundle config set --local path '.bundle/vendor' && bundle install)

# Flutter of the image used to live in /opt/flutter, owned by another user.
git config --global --add safe.directory /opt/flutter

# Dependencies and code generation (the package registry token is GPR_KEY); the iOS engine artifacts; CocoaPods.
make init
if [ "$platform" = ios ]; then flutter precache --ios; fi
(cd "$platform" && bundle exec pod install)

# The Xcode configuration of the Flutter tool: the version and the build number.
flutter build "$platform" --release --build-name="$PROJECT_VERSION" --build-number="$BUILD_NUMBER" --no-pub --config-only

# CocoaPods vendored frameworks may carry pre-release versions ("1.2.3-beta.4", "5.0.0+abc"), which code
# signing and App Store validation reject: keep the SemVer core of CFBundleShortVersionString and CFBundleVersion.
changed=0
while IFS= read -r -d '' plist; do
  for key in CFBundleShortVersionString CFBundleVersion; do
    value="$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || true)"
    [ -z "$value" ] && continue
    clean="${value%%[-+]*}"
    if [ "$clean" != "$value" ]; then
      echo "Sanitizing $key '$value' -> '$clean' in $plist"
      /usr/libexec/PlistBuddy -c "Set :$key $clean" "$plist"
      changed=1
    fi
  done
done < <(find "$platform/Pods" -type f -name Info.plist -path '*.framework/*' -print0)
[ "$changed" -eq 1 ] || echo "No pre-release framework versions found."
