#!/bin/zsh
# Builds a release DMG for other Macs: dist/TwodayNote-<version>.dmg
#   - universal binary (Apple silicon and Intel)
#   - signed with a "Developer ID Application" certificate when the keychain
#     has one (hardened runtime), otherwise ad hoc
#   - notarized and stapled when NOTARY_PROFILE names a notarytool keychain
#     profile (xcrun notarytool store-credentials <name> ...), Developer ID only
# The version comes from CFBundleShortVersionString in Info.plist.in.
#
# Usage: tools/release.sh
set -euo pipefail
here=${0:A:h:h}
name=TwodayNote
version=$(plutil -extract CFBundleShortVersionString raw "$here/Info.plist.in")
scratch="$HOME/Library/Developer/$name/universal"
dist="$here/dist"
dmg="$dist/$name-$version.dmg"

echo "building $name $version (arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64 --package-path "$here" --scratch-path "$scratch" 2>&1 \
  | grep -E "error:|Build complete" || true
bin="$scratch/out/Products/Release/$name"
[[ -x "$bin" ]] || { echo "build failed: no binary at $bin"; exit 1; }
stale=$(find "$here/Sources" -name '*.swift' -newer "$bin" | head -1)
[[ -z "$stale" ]] || { echo "build failed: binary is older than $stale"; exit 1; }

# The app bundle, laid out like build.sh does.
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
app="$stage/$name.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/$name"
sed -e "s/__BUILD__/$(date +%Y%m%d%H%M)/" "$here/Info.plist.in" > "$app/Contents/Info.plist"
[[ -f "$here/Resources/AppIcon.icns" ]] || "$here/tools/make_icon.sh"
cp -X "$here/Resources/AppIcon.icns" "$app/Contents/Resources/"
# The logo and name at the top of the popover, as build.sh copies them.
cp -X "$here/Brand/$name-lockup-light.svg" "$here/Brand/$name-lockup-dark.svg" "$app/Contents/Resources/"
xattr -cr "$app"

identity=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Developer ID Application: [^"]*"' | tr -d '"' || true)
if [[ -n "$identity" ]]; then
  codesign --force --options runtime --timestamp --sign "$identity" "$app"
else
  identity="-"
  codesign --force --sign - "$app"
fi
codesign --verify --strict "$app"
echo "signed: $identity, archs: $(lipo -archs "$app/Contents/MacOS/$name")"

# The disk image: the app plus a shortcut to drag it into Applications.
ln -s /Applications "$stage/Applications"
mkdir -p "$dist"
rm -f "$dmg"
hdiutil create -quiet -volname "$name" -srcfolder "$stage" -fs HFS+ -format UDZO "$dmg"

if [[ -n "${NOTARY_PROFILE:-}" && "$identity" != "-" ]]; then
  codesign --force --timestamp --sign "$identity" "$dmg"
  xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$dmg"
  echo "notarized"
elif [[ "$identity" == "-" ]]; then
  echo "not notarized: people open it with Privacy & Security > Open Anyway (see README)"
fi

echo "wrote $dmg"
shasum -a 256 "$dmg"
