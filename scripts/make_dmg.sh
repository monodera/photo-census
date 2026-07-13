#!/bin/bash
# Release ビルドを ad-hoc 署名して dmg にまとめる。
# 使い方: ./scripts/make_dmg.sh [version]  (省略時 "dev")
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-dev}"
BUILD_DIR="build"
APP="$BUILD_DIR/Build/Products/Release/PhotoCensus.app"
DMG="PhotoCensus-$VERSION.dmg"

xcodegen generate --spec PhotoCensus/project.yml --project PhotoCensus

xcodebuild -project PhotoCensus/PhotoCensus.xcodeproj \
  -scheme PhotoCensus -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY=- MARKETING_VERSION="${VERSION#v}" build

codesign --force --deep --sign - "$APP"

STAGING="$BUILD_DIR/dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "PhotoCensus" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
echo "Created $DMG"
