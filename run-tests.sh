#!/bin/bash
# Standalone tests for Quire logic. Does not need the full Xcode test bundle.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/freewrite"
if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
else
    SDK="$(xcrun --sdk macosx --show-sdk-path)"
fi
OUT="$(mktemp -d /tmp/quire-tests.XXXXXX)"
trap 'rm -rf "$OUT"' EXIT

echo "Compiling tests..."
swiftc -sdk "$SDK" -target arm64-apple-macos14.0 -parse-as-library \
    "$SRC/ImageStore.swift" \
    "$SRC/MarkdownExtras.swift" \
    "$SRC/MermaidFlow.swift" \
    "$SRC/WritingFocus.swift" \
    "$SRC/CommandGo.swift" \
    "$SRC/JournalContext.swift" \
    "$SRC/JournalStats.swift" \
    "$SRC/JournalImport.swift" \
    "$SRC/OllamaSettings.swift" \
    "$SRC/QuireAction.swift" \
    "$SRC/LocalAgent.swift" \
    "$SRC/Prompts.swift" \
    "$SRC/QuietTools.swift" \
    "$SRC/WritingPreferences.swift" \
    "$SRC/WritingGoal.swift" \
    "$SRC/TypewriterScroll.swift" \
    "$SRC/EditorDictation.swift" \
    "$SRC/VoiceNote.swift" \
    "$SRC/JournalInsights.swift" \
    "$SRC/JournalTags.swift" \
    "$SRC/JournalApply.swift" \
    "$SRC/JournalContinuity.swift" \
    "$SRC/JournalFolder.swift" \
    "$SRC/PageVersions.swift" \
    "$SRC/PageCompare.swift" \
    "$SRC/JournalExport.swift" \
    "$SRC/CaptureDevices.swift" \
    "$SRC/PageLock.swift" \
    "$SRC/QuietSounds.swift" \
    "$SRC/SoftMarkdown.swift" \
    "$SRC/JournalLock.swift" \
    "$SRC/WritingSpark.swift" \
    "$SRC/ImageAnnotator.swift" \
    "$ROOT/run-tests-main.swift" \
    -o "$OUT/quire-tests" \
    -framework AppKit -framework SwiftUI -framework Combine -framework LocalAuthentication -framework AVFoundation

echo "Running tests..."
"$OUT/quire-tests"
echo "All standalone tests passed."
