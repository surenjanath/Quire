#!/bin/bash
# Builds Freewrite.app without requiring the full Xcode IDE.
#
# Uses the Swift toolchain + macOS SDK bundled with Xcode Command Line Tools
# (swiftc, codesign) to compile the sources and hand-assemble an .app bundle,
# bypassing `xcodebuild` (which requires the full Xcode.app).
#
# Known limitations vs. a real Xcode build:
#   - No app icon: asset-catalog compilation needs `actool`, which ships only
#     with full Xcode, not the Command Line Tools. The app runs fine without it.
#   - Ad-hoc code signature (`codesign -s -`) instead of a Developer ID/Apple
#     Development certificate. Entitlements (sandbox, camera, mic, speech) are
#     still embedded and should still be honored by TCC.
#
# Usage:
#   ./build.sh            # build to build/Freewrite.app
#   ./build.sh --install  # also copy the result to /Applications and (re)launch it

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build"
SRC_DIR="$BUILD_DIR/.src"
APP="$BUILD_DIR/Freewrite.app"

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
   "$ROOT/freewrite/JournalLock.swift" \
   "$ROOT/freewrite/JournalChrome.swift" \
   "$ROOT/freewrite/TypewriterScroll.swift" \
   "$ROOT/freewrite/MarkdownExtras.swift" \
   "$ROOT/freewrite/JournalTags.swift" \
   "$ROOT/freewrite/MermaidFlow.swift" \
   "$ROOT/freewrite/ImageAnnotator.swift" \
   "$ROOT/freewrite/WritingGoal.swift" \
   "$ROOT/freewrite/ImageStore.swift" \
   "$ROOT/freewrite/AdvancedPanels.swift" \
   "$ROOT/freewrite/OllamaService.swift" \
   "$ROOT/freewrite/OllamaPanelView.swift" \
   "$ROOT/freewrite/SettingsView.swift" \
   "$ROOT/freewrite/VoiceDictationService.swift" \
   "$SRC_DIR/"
python3 - "$SRC_DIR/ContentView.swift" <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()
src = src.replace("\n#Preview {\n    ContentView()\n}\n", "\n")
open(path, "w").write(src)
PY

SDK=$(xcrun --sdk macosx --show-sdk-path)

echo "Compiling..."
swiftc -O \
    -sdk "$SDK" \
    -target arm64-apple-macos14.0 \
    -parse-as-library \
    "$SRC_DIR/freewriteApp.swift" "$SRC_DIR/ContentView.swift" "$SRC_DIR/VideoPlayerView.swift" "$SRC_DIR/VideoRecordingView.swift" \
    "$SRC_DIR/Prompts.swift" "$SRC_DIR/AppSettingsKeys.swift" "$SRC_DIR/WritingPreferences.swift" "$SRC_DIR/EditorDictation.swift" "$SRC_DIR/JournalInsights.swift" "$SRC_DIR/WritingSpark.swift" "$SRC_DIR/VoiceNote.swift" "$SRC_DIR/JournalFolder.swift" "$SRC_DIR/JournalLock.swift" "$SRC_DIR/JournalChrome.swift" "$SRC_DIR/TypewriterScroll.swift" "$SRC_DIR/MarkdownExtras.swift" "$SRC_DIR/JournalTags.swift" "$SRC_DIR/MermaidFlow.swift" "$SRC_DIR/ImageAnnotator.swift" "$SRC_DIR/WritingGoal.swift" "$SRC_DIR/ImageStore.swift" "$SRC_DIR/AdvancedPanels.swift" "$SRC_DIR/OllamaService.swift" "$SRC_DIR/OllamaPanelView.swift" "$SRC_DIR/SettingsView.swift" "$SRC_DIR/VoiceDictationService.swift" \
    -o "$APP/Contents/MacOS/freewrite" \
    -framework SwiftUI -framework AppKit -framework AVFoundation -framework Speech -framework Combine -framework PDFKit -framework LocalAuthentication

echo "Assembling app bundle..."
cp "$ROOT/freewrite/default.md" "$APP/Contents/Resources/"
cp "$ROOT/freewrite/fonts/Lato-Regular.ttf" "$APP/Contents/Resources/"

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
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
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

echo "Built: $APP"

if [[ "${1:-}" == "--install" ]]; then
    echo "Installing to /Applications..."
    pkill -x freewrite 2>/dev/null || true
    rm -rf "/Applications/Freewrite.app"
    cp -R "$APP" "/Applications/Freewrite.app"
    open "/Applications/Freewrite.app"
    echo "Installed and launched: /Applications/Freewrite.app"
fi
