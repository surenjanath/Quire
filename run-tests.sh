#!/bin/bash
# Standalone tests for Quire logic. Does not need the full Xcode test bundle.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/freewrite"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
OUT="$(mktemp -d /tmp/quire-tests.XXXXXX)"
trap 'rm -rf "$OUT"' EXIT

echo "Compiling tests..."
swiftc -sdk "$SDK" -target arm64-apple-macos14.0 -parse-as-library \
    "$SRC/ImageStore.swift" \
    "$SRC/MarkdownExtras.swift" \
    "$SRC/MermaidFlow.swift" \
    "$SRC/WritingFocus.swift" \
    "$SRC/QuietTools.swift" \
    "$SRC/WritingPreferences.swift" \
    "$SRC/WritingGoal.swift" \
    "$SRC/TypewriterScroll.swift" \
    "$SRC/EditorDictation.swift" \
    "$SRC/VoiceNote.swift" \
    "$SRC/JournalTags.swift" \
    "$SRC/JournalFolder.swift" \
    "$SRC/JournalLock.swift" \
    "$SRC/WritingSpark.swift" \
    "$SRC/ImageAnnotator.swift" \
    "$ROOT/run-tests-main.swift" \
    -o "$OUT/quire-tests" \
    -framework AppKit -framework SwiftUI -framework LocalAuthentication

echo "Running tests..."
"$OUT/quire-tests"
echo "All standalone tests passed."
