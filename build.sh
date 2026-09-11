#!/bin/bash
# Builds Freewrite.app without requiring the full Xcode IDE.
#
# Uses the Swift toolchain + macOS SDK bundled with Xcode Command Line Tools
# (swiftc, codesign) to compile the sources and hand-assemble an .app bundle,
# bypassing `xcodebuild` (which requires the full Xcode.app).
#
# Known limitations vs. a real Xcode build:
#   - Ad-hoc code signature (`codesign -s -`) instead of a Developer ID/Apple
#     Development certificate. First launch on another Mac: right-click the app
#     and choose Open. Entitlements (sandbox, camera, mic, speech) are embedded.
#
# Usage:
#   ./build.sh            # build to build/Quire.app and build/Quire.zip
#   ./build.sh --install  # also copy to /Applications/Quire.app and launch it

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build"
SRC_DIR="$BUILD_DIR/.src"
APP="$BUILD_DIR/Quire.app"

if ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "error: swiftc not found. Install Xcode Command Line Tools: xcode-select --install" >&2
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$SRC_DIR"

# swiftc (unlike xcodebuild) chokes on the #Preview macro, which needs a
# plugin that only ships with full Xcode. Strip it from a throwaway copy of
# ContentView.swift so the real source in freewrite/ is never touched.
cp "$ROOT/freewrite/freewriteApp.swift" \
   "$ROOT/freewrite/ContentView.swift" \
   "$ROOT/freewrite/VideoPlayerView.swift" \
   "$ROOT/freewrite/VideoRecordingView.swift" \
   "$ROOT/freewrite/Prompts.swift" \
   "$ROOT/freewrite/AppSettingsKeys.swift" \
   "$ROOT/freewrite/WritingPreferences.swift" \
   "$ROOT/freewrite/EditorDictation.swift" \
   "$ROOT/freewrite/JournalInsights.swift" \
   "$ROOT/freewrite/WritingSpark.swift" \
   "$ROOT/freewrite/VoiceNote.swift" \
   "$ROOT/freewrite/JournalFolder.swift" \
   "$ROOT/freewrite/PageVersions.swift" \
   "$ROOT/freewrite/PageCompare.swift" \
   "$ROOT/freewrite/JournalExport.swift" \
   "$ROOT/freewrite/CaptureDevices.swift" \
   "$ROOT/freewrite/PageLock.swift" \
   "$ROOT/freewrite/QuietSounds.swift" \
   "$ROOT/freewrite/SoftMarkdown.swift" \
   "$ROOT/freewrite/JournalLock.swift" \
   "$ROOT/freewrite/JournalChrome.swift" \
   "$ROOT/freewrite/TypewriterScroll.swift" \
   "$ROOT/freewrite/MarkdownExtras.swift" \
   "$ROOT/freewrite/JournalTags.swift" \
   "$ROOT/freewrite/JournalApply.swift" \
   "$ROOT/freewrite/JournalContinuity.swift" \
   "$ROOT/freewrite/MermaidFlow.swift" \
   "$ROOT/freewrite/ImageAnnotator.swift" \
   "$ROOT/freewrite/WritingGoal.swift" \
   "$ROOT/freewrite/QuietTools.swift" \
   "$ROOT/freewrite/WritingFocus.swift" \
   "$ROOT/freewrite/CommandGo.swift" \
   "$ROOT/freewrite/JournalContext.swift" \
   "$ROOT/freewrite/JournalStats.swift" \
   "$ROOT/freewrite/JournalImport.swift" \
   "$ROOT/freewrite/OllamaSettings.swift" \
   "$ROOT/freewrite/QuireAction.swift" \
   "$ROOT/freewrite/LocalAgent.swift" \
   "$ROOT/freewrite/ImageStore.swift" \
   "$ROOT/freewrite/AdvancedPanels.swift" \
   "$ROOT/freewrite/OllamaService.swift" \
   "$ROOT/freewrite/OllamaPanelView.swift" \
   "$ROOT/freewrite/AgentPanelView.swift" \
   "$ROOT/freewrite/SettingsView.swift" \
   "$ROOT/freewrite/VoiceDictationService.swift" \
   "$ROOT/freewrite/PageNarrator.swift" \
   "$SRC_DIR/"
python3 - "$SRC_DIR/ContentView.swift" <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()
src = src.replace("\n#Preview {\n    ContentView()\n}\n", "\n")
open(path, "w").write(src)
PY

# macOS 27 SDK's SwiftUI @State macro plugin is missing from CLT.
# Prefer 26.5 when present so `swiftc` can still build the app.
if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
else
    SDK=$(xcrun --sdk macosx --show-sdk-path)
fi

echo "Compiling..."
swiftc -O \
    -sdk "$SDK" \
    -target arm64-apple-macos14.0 \
    -parse-as-library \
    "$SRC_DIR/freewriteApp.swift" "$SRC_DIR/ContentView.swift" "$SRC_DIR/VideoPlayerView.swift" "$SRC_DIR/VideoRecordingView.swift" \
    "$SRC_DIR/Prompts.swift" "$SRC_DIR/AppSettingsKeys.swift" "$SRC_DIR/WritingPreferences.swift" "$SRC_DIR/EditorDictation.swift" "$SRC_DIR/JournalInsights.swift" "$SRC_DIR/WritingSpark.swift" "$SRC_DIR/VoiceNote.swift" "$SRC_DIR/JournalFolder.swift" "$SRC_DIR/PageVersions.swift" "$SRC_DIR/PageCompare.swift" "$SRC_DIR/JournalExport.swift" "$SRC_DIR/CaptureDevices.swift" "$SRC_DIR/PageLock.swift" "$SRC_DIR/QuietSounds.swift" "$SRC_DIR/SoftMarkdown.swift" "$SRC_DIR/JournalLock.swift" "$SRC_DIR/JournalChrome.swift" "$SRC_DIR/TypewriterScroll.swift" "$SRC_DIR/MarkdownExtras.swift" "$SRC_DIR/JournalTags.swift" "$SRC_DIR/JournalApply.swift" "$SRC_DIR/JournalContinuity.swift" "$SRC_DIR/MermaidFlow.swift" "$SRC_DIR/ImageAnnotator.swift" "$SRC_DIR/WritingGoal.swift" "$SRC_DIR/QuietTools.swift" "$SRC_DIR/WritingFocus.swift" "$SRC_DIR/CommandGo.swift" "$SRC_DIR/JournalContext.swift" "$SRC_DIR/JournalStats.swift" "$SRC_DIR/JournalImport.swift" "$SRC_DIR/OllamaSettings.swift" "$SRC_DIR/QuireAction.swift" "$SRC_DIR/LocalAgent.swift" "$SRC_DIR/ImageStore.swift" "$SRC_DIR/AdvancedPanels.swift" "$SRC_DIR/OllamaService.swift" "$SRC_DIR/OllamaPanelView.swift" "$SRC_DIR/AgentPanelView.swift" "$SRC_DIR/SettingsView.swift" "$SRC_DIR/VoiceDictationService.swift" "$SRC_DIR/PageNarrator.swift" \
    -o "$APP/Contents/MacOS/freewrite" \
    -framework SwiftUI -framework AppKit -framework AVFoundation -framework Speech -framework Combine -framework PDFKit -framework LocalAuthentication

echo "Assembling app bundle..."
cp "$ROOT/freewrite/default.md" "$APP/Contents/Resources/"
cp "$ROOT/freewrite/fonts/Lato-Regular.ttf" "$APP/Contents/Resources/"
cp "$ROOT/freewrite/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>freewrite</string>
    <key>CFBundleIdentifier</key>
    <string>app.humansongs.freewrite</string>
    <key>CFBundleName</key>
    <string>Quire</string>
    <key>CFBundleDisplayName</key>
    <string>Quire</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Surenjanath</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSCameraUsageDescription</key>
    <string>Quire needs camera access to record video entries.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Quire needs microphone access to record voice notes, video entries, and dictated text.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Quire uses speech recognition to transcribe voice notes, video entries, and dictated text.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Signing..."
codesign --force --deep -s - --entitlements "$ROOT/freewrite/freewrite.entitlements" "$APP"

echo "Packaging..."
DIST="$BUILD_DIR/Quire-dist"
rm -rf "$DIST"
mkdir -p "$DIST"
cp -R "$APP" "$DIST/Quire.app"
cp "$ROOT/freewrite/Resources/How to install.txt" "$DIST/How to install.txt"
ditto -c -k --norsrc --keepParent "$DIST" "$BUILD_DIR/Quire.zip"
# Old path some docs still mention
rm -rf "$BUILD_DIR/Freewrite.app"
cp -R "$APP" "$BUILD_DIR/Freewrite.app"

echo "Built: $APP"
echo "Zip:   $BUILD_DIR/Quire.zip"

if [[ "${1:-}" == "--install" ]]; then
    echo "Installing to /Applications..."
    rm -rf "/Applications/Quire.app"
    cp -R "$APP" "/Applications/Quire.app"
    open "/Applications/Quire.app"
    echo "Installed and launched: /Applications/Quire.app"
fi
