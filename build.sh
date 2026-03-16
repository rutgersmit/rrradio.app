#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

echo "Building rrradio..."

xcodebuild \
  -project "$PROJECT_DIR/rrradio.xcodeproj" \
  -scheme rrradio \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR/Release"

APP="$BUILD_DIR/Release/rrradio.app"

if [ -d "$APP" ]; then
  echo ""
  echo "Build succeeded: $APP"
  echo "Opening..."
  open "$APP"
else
  echo "Build output not found at $APP"
  exit 1
fi
