#!/bin/bash
set -euo pipefail

SCHEME="WeekView"
PROJECT="WeekView.xcodeproj"
SDK="iphonesimulator"
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro Max"

# Check that xcode-select points to Xcode.app (not CommandLineTools)
DEV_DIR=$(xcode-select -p 2>/dev/null)
if [[ "$DEV_DIR" == */CommandLineTools* ]]; then
    echo "Error: xcode-select points to CommandLineTools, not Xcode.app"
    echo "Fix with: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -sdk "$SDK" \
    -destination "$DESTINATION" \
    build \
    "$@"
