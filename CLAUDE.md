# Quire (Freewrite fork) — Technical Documentation for AI Agents

> **⚠️ IMPORTANT FOR AI AGENTS**: This file (`AGENTS.md`) and `CLAUDE.md` are clones and must be kept in sync.
>
> Update both files when changes are **substantial** and meaningfully affect future agent understanding (for example: architecture, data flow, storage/permissions, threading behavior, user-facing workflows, or major bug fixes).
>
> For minor tweaks (small UI polish, copy edits, tiny refactors), updates are optional. Do **not** churn these docs on every small code change.
>
> If one file is updated, mirror the same change in the other file immediately.

## Product Vision & User Experience

### What is Freewrite?

The shipped Dock name is **Quire**. Internally and on disk this is still the Freewrite tree (`app.humansongs.freewrite`, `~/Documents/Freewrite/`).

Freewrite is a **distraction-free writing environment** for macOS designed around the concept of stream-of-consciousness writing and video journaling. The core philosophy is to remove barriers between thought and writing by creating a minimalist, opinionated interface that prioritizes the act of writing over formatting, organization, or editing.

### User Experience Philosophy

**Core Principles:**
1. **No Backspace (Optional)**: Users can disable the backspace key to encourage forward-thinking writing without self-editing
2. **Timed Sessions**: Built-in timer (default 15 minutes) creates focused writing sprints
3. **Auto-Everything**: Auto-save, auto-new-entry, auto-timestamp - the app manages logistics so users can focus on writing
4. **Local-First**: All data stays on the user's machine in plain markdown files they can access directly
5. **Minimal UI**: Most UI elements hide during timed sessions, leaving only the text

### Use Cases

**Primary Use Case - Stream of Consciousness Writing:**
- Users open the app and start writing immediately (no "New Document" dialog)
- The app creates a new entry automatically at the start of each day
- Writing is saved continuously with no manual save action
- Timer creates urgency and prevents over-editing
- Backspace disable forces forward momentum in thinking

**Secondary Use Case - Video Journaling:**
- Quick video capture for visual thoughts/ideas
- Video entries stored alongside text entries in chronological history
- One-click recording with built-in timer
- Local storage ensures privacy for personal video journals

**Tertiary Use Case - AI-Assisted Reflection:**
- "Chat" button sends writing to ChatGPT or Claude
- Prompts designed to help users reflect on and understand their writing
- AI provides feedback, questions, or analysis of stream-of-consciousness text

**Hidden Power Feature - Long-Form Writing:**
- Despite minimalist interface, supports full markdown
- Entries can be exported as PDFs
- Font and size customization for comfort during long sessions
- Dark mode for night writing

## Overview

Freewrite is a native macOS writing application built with SwiftUI that allows users to write text entries and record video entries. All data is stored locally in `~/Documents/Freewrite/`.

## Architecture

### Technology Stack
- **Framework**: SwiftUI (macOS)
- **Minimum macOS Version**: 14.0
- **Language**: Swift 5.0
- **Build System**: Xcode
- **Media**: AVFoundation for camera/video recording

### Project Structure

```
freewrite/
├── freewrite.xcodeproj/          # Xcode project file
├── freewrite/
│   ├── freewriteApp.swift        # App entry point
│   ├── ContentView.swift         # Main view (2200+ lines)
│   ├── VideoRecordingView.swift  # Video recording interface
│   ├── VideoPlayerView.swift     # Video playback interface
│   ├── OllamaService.swift       # Local Ollama HTTP client (model list, multi-turn chat, pull)
│   ├── OllamaPanelView.swift     # Offline AI chat side panel (chat bubbles, follow-ups, personas)
│   ├── VoiceDictationService.swift # Mic-only speech-to-text for editor + chat follow-ups
│   ├── WritingPreferences.swift  # Sanitize persisted font/size/timer values
│   ├── EditorDictation.swift     # Combine editor snapshot + live speech transcript
│   ├── JournalInsights.swift     # On-this-day, weekly window, session recap, month heatmap
│   ├── WritingSpark.swift        # Daily empty-page prompt (stable for the whole day)
│   ├── VoiceNote.swift           # Voice-note markdown, m4a storage, recorder
│   ├── JournalTags.swift         # #tag extraction + suggestions
│   ├── JournalApply.swift        # Put an Ollama reply on the page without wiping images
│   ├── JournalContinuity.swift   # Yesterday's last sentence on an empty page
│   ├── JournalContext.swift      # Ground Ollama in related journal pages
│   ├── OllamaSettings.swift      # Thinking, temperature, context, system prompt
│   ├── QuireAction.swift         # Menu/toolbar notifications + About copy
│   ├── LocalAgent.swift          # Claude Code / Codex CLI jobs + streaming
│   ├── AgentPanelView.swift      # Side panel to watch Claude Code / Codex write
│   ├── MermaidFlow.swift         # Offline mermaid flowchart parse + strip
│   ├── ImageAnnotator.swift      # Draw-on-screenshot canvas
│   ├── WritingGoal.swift         # Optional daily word-goal meter
│   ├── JournalFolder.swift       # Default or user-picked journal root (security-scoped bookmark)
│   ├── JournalLock.swift         # Optional Touch ID / password launch gate
│   ├── JournalChrome.swift       # History month grid + voice-note play strip
│   ├── TypewriterScroll.swift    # Center the caret in the editor while typing
│   ├── WritingFocus.swift        # Idle fade, favorite fonts, IME lock, sentence focus
│   ├── CommandGo.swift           # ⌘K go palette: commands + journal pages
│   ├── PageVersions.swift        # Snapshots before Chat / agent apply
│   ├── PageCompare.swift         # Now vs After before Insert / Replace
│   ├── JournalExport.swift       # Zip markdown + Media + Versions
│   ├── CaptureDevices.swift      # Camera / mic pick
│   ├── PageLock.swift            # Per-page Touch ID gate
│   ├── QuietSounds.swift         # Typewriter ticks + room tone
│   ├── SoftMarkdown.swift        # Dim markdown markers
│   ├── SettingsView.swift        # Settings: Chat (agents + tone + Ollama) and Writing
│   ├── Prompts.swift             # Default AI prompts + Ollama persona presets
│   ├── AppSettingsKeys.swift     # Shared UserDefaults keys/defaults
│   └── freewrite.entitlements    # App permissions
├── build.sh                       # CLI-only build (swiftc + codesign) when Xcode isn't installed
├── CLAUDE.md                     # This file
└── AGENTS.md                     # Duplicate of this file
```

**Xcode project note**: the target uses a `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), so any
`.swift` file dropped under `freewrite/freewrite/` is automatically included in the build — no
manual `.pbxproj` editing needed when adding new source files.

## Data Model

### Entry Types

```swift
enum EntryType {
    case text
    case video
}

struct HumanEntry: Identifiable {
    let id: UUID
    let date: String              // Display format: "MMM d" (e.g., "Feb 20")
    let filename: String          // Format: [UUID]-[YYYY-MM-DD-HH-mm-ss].md
    var previewText: String       // First 30 chars or "Video Entry"
    var entryType: EntryType      // .text or .video
    var videoFilename: String?    // Format: [UUID]-[YYYY-MM-DD-HH-mm-ss].mov
}
```

### File Storage

**Location**: `~/Documents/Freewrite/`

**Text Entries**:
- Format: Markdown (.md)
- Naming: `[UUID]-[YYYY-MM-DD-HH-mm-ss].md`
- Content: Plain UTF-8 text
- Example: `[6910BBDE-75FC-415C-ABB9-C76644B037B2]-[2026-02-20-08-01-04].md`

**Video Entries**:
- Format: QuickTime Movie (.mov)
- Naming: `[UUID]-[YYYY-MM-DD-HH-mm-ss].mov`
- Metadata: Corresponding `.md` file with "Video Entry" text in `~/Documents/Freewrite/`
- Storage layout: `~/Documents/Freewrite/Videos/[UUID]-[YYYY-MM-DD-HH-mm-ss]/`
- Directory contents:
  - `[UUID]-[YYYY-MM-DD-HH-mm-ss].mov`
  - `thumbnail.jpg`
  - `transcript.md` (optional; speech transcript for that recording)
- Example directory: `~/Documents/Freewrite/Videos/[6910BBDE-75FC-415C-ABB9-C76644B037B2]-[2026-02-20-08-01-04]/`

## Key Components

### ContentView.swift

The main view containing all UI and business logic.

#### State Variables (Selection)

```swift
@State private var entries: [HumanEntry] = []           // All loaded entries
@State private var text: String = ""                    // Current text editor content
@State private var selectedEntryId: UUID? = nil         // Currently selected entry
@State private var showingVideoRecording = false        // Video recording overlay visibility
@State private var currentVideoURL: URL? = nil          // Video playback URL
@State private var showingSidebar = false               // History sidebar visibility
@State private var colorScheme: ColorScheme = .light    // Light/dark theme
@State private var fontSize: CGFloat = 18               // Text size (16-26px)
@State private var selectedFont: String = "Lato-Regular"// Current font
@State private var timerIsRunning = false               // Timer state
@State private var timeRemaining: Int = 900             // Timer (seconds)
@State private var backspaceDisabled = false            // Backspace lock
```

#### Core Functions

**Entry Management**:
- `loadExistingEntries()` - Loads all .md and .mov files from documents directory
- `createNewEntry()` - Creates new text entry
- `saveEntry(entry:)` - Saves text to .md file
- `loadEntry(entry:)` - Loads text or video for display
- `deleteEntry(entry:)` - Moves entry and associated files to the macOS Trash (see `moveToTrash`)
- `saveVideoEntry(from:)` - Saves recorded video and creates metadata

**Important**: When modifying the `entries` array from async contexts, wrap in `DispatchQueue.main.async` to prevent collection mutation crashes.

### VideoRecordingView.swift

Handles camera access and video recording.

#### CameraManager Class

```swift
class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: Int = 0
    @Published var permissionGranted = false

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
}
```

**Key Methods**:
- `setupCamera()` - Configures AVCaptureSession with video/audio inputs
- `startRecording(to:)` - Begins recording to temporary file
- `stopRecording()` - Stops recording and triggers completion handler
- `cleanup()` - Releases camera resources

**Critical**: Always use `beginConfiguration()` and `commitConfiguration()` when modifying AVCaptureSession to prevent crashes.
**UI Pattern**: The recorder is rendered as an immersive edge-to-edge overlay with a transparent bottom nav and a floating circular record control.

### VideoPlayerView.swift

Simple AVKit-based video player for playback.

```swift
struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
}
```

## UI Layout

### Main Interface

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                    Text Editor Area                     │
│              (or Video Player if video)                 │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  Bottom Nav Bar:                                        │
│  [16px] • [Lato] • [Arial] • [System] • [Serif] • ...  │
│  ... [15:00] • [🎥] • [Chat] • [Backspace] • [...]     │
└─────────────────────────────────────────────────────────┘
```

### Sidebar (History)

```
┌──────────────┐
│   History    │
├──────────────┤
│ 📹 Video...  │ ← Video entry with thumbnail
│ Feb 20       │
├──────────────┤
│ This is a... │ ← Text entry with preview
│ Feb 19       │
├──────────────┤
│ Another ...  │
│ Feb 18       │
└──────────────┘
```

## Navigation Bar Items

### Left Side (Font Controls)
- **Font Size**: Cycles through [16, 18, 20, 22, 24, 26]px
- **Font Selection**: Lato, Arial, System, Serif, Random
- Hover changes cursor to pointing hand
- **Video Mode Left Slot**: Replaced by `Copy Transcript` when viewing a video entry

### Right Side (Utilities)
- **Timer**: Shows time remaining, click to start/stop, double-click to reset
- **Video Camera (🎥)**: Opens immersive video recording overlay
- **Chat**: Opens AI chat menu (ChatGPT/Claude integration)
- **Backspace Toggle**: Enable/disable backspace key
- **Fullscreen**: Toggle fullscreen mode
- **New Entry**: Creates new text entry
- **Theme Toggle**: 🌙/☀️ for dark/light mode
- **History**: 🕐 Shows/hides sidebar

## Video Recording Flow

1. User clicks video camera icon (🎥)
2. Camera icon switches to a small spinner while preflight runs
3. App requests/validates **all required permissions**: camera + microphone + speech recognition
4. If any permission is missing, recorder is **not** presented; a compact popover above the camera icon explains what is missing and links to System Settings
5. Once camera session is fully ready (plus a short presentation delay), `VideoRecordingView` is rendered via `.overlay` on top of `ContentView` with animations disabled for open/close (plain swap, no transition)
6. Camera preview fills the entire window content area edge-to-edge
7. Transparent bottom nav appears over video with: `Close`, recording status, recording control text (`Start Recording` / `Stop Recording`), and timer
8. User clicks "Start Recording"
   - Recording begins to temp file
   - Timer starts counting up
   - Button changes to "Stop Recording"
9. User clicks "Stop Recording"
   - Recording stops
   - Speech transcript is finalized (spacing + sentence endings/capitalization)
   - `onRecordingComplete` closure called with temp URL + finalized transcript
10. `saveVideoEntry(from:transcript:)` called
   - Creates per-entry video directory in `~/Documents/Freewrite/Videos/[UUID]-[date]/`
   - Video copied from temp to `~/Documents/Freewrite/Videos/[UUID]-[date]/[UUID]-[date].mov`
   - Thumbnail generated once and saved to `~/Documents/Freewrite/Videos/[UUID]-[date]/thumbnail.jpg`
   - Transcript saved to `~/Documents/Freewrite/Videos/[UUID]-[date]/transcript.md` when available
   - Metadata file created: `[UUID]-[date].md` with "Video Entry"
   - Entry added to `entries` array (on main thread), selected immediately, and loaded into the main view
   - Playback starts automatically with audio enabled
   - Overlay dismissed
11. If user clicks `Close` while recording, the temp recording is discarded and no entry is created; recorder dismisses first, then camera cleanup runs on disappear

## Video Playback Flow

1. User clicks video entry in sidebar
2. `loadEntry(entry:)` checks `entry.entryType`
3. If `.video`:
   - Sets `currentVideoURL` to video file path
   - Clears `text`
4. Main view checks `if let videoURL = currentVideoURL`
5. Shows `VideoPlayerView(videoURL:)` instead of TextEditor
6. Video auto-plays muted with standard AVKit controls

## Entry Loading Logic

On app launch (`onAppear`):

1. `loadExistingEntries()` called
2. Reads all files from `~/Documents/Freewrite/`
3. Filters for canonical `.md` entries and derives expected `.mov` name from each `.md`
4. For each `.md` file:
   - Extracts UUID and date from filename via regex
   - Checks for corresponding `.mov` in this order:
     - `~/Documents/Freewrite/Videos/[entry-base]/[entry].mov` (current layout)
     - `~/Documents/Freewrite/Videos/[entry].mov` (legacy flat layout)
     - `~/Documents/Freewrite/[entry].mov` (oldest legacy layout)
   - Creates `HumanEntry` with appropriate type
5. Sorts entries by date (newest first)
6. Applies launch selection rules in order:
   - If newest entry is a video entry: create a new text entry and select it (never open directly into video on app launch)
   - Else if no entries: create welcome entry
   - Else if no empty entry exists for today (and app is not in the single-welcome-entry state): create a new empty entry
   - Else select the most recent empty entry from today (or the welcome entry if it's the only entry)

## Auto-Save Behavior

Text is auto-saved on every change:

```swift
.onChange(of: text) { _ in
    if let currentId = selectedEntryId,
       let currentEntry = entries.first(where: { $0.id == currentId }) {
        saveEntry(entry: currentEntry)
    }
}
```

## Permissions

Required entitlements in `freewrite.entitlements`:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.device.camera</key>
<true/>
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.personal-information.speech-recognition</key>
<true/>
```

`com.apple.security.network.client` is required for the Ollama integration — App Sandbox blocks
all outgoing sockets, including `localhost`, without it.

Privacy usage descriptions (in Xcode project build settings):

```
INFOPLIST_KEY_NSCameraUsageDescription = "Freewrite needs camera access to record video entries."
INFOPLIST_KEY_NSMicrophoneUsageDescription = "Freewrite needs microphone access to record voice notes, video entries, and dictated text."
INFOPLIST_KEY_NSSpeechRecognitionUsageDescription = "Freewrite uses speech recognition to transcribe voice notes, video entries, and dictated text."
```

## Technical Nuances & Implementation Details

### Threading Model

The app uses a **hybrid threading approach**:

1. **Main Thread**: All UI updates and `@State` mutations
2. **Global Queue**: File I/O operations (reading/writing markdown files)
3. **AVFoundation Queue**: Camera setup and video capture

**Critical Threading Issue**:
SwiftUI's `ForEach` creates an enumerator over the `entries` array. If you modify this array (insert, remove, replace) while the enumerator is active, you get `NSGenericException: Collection was mutated while being enumerated`.

**Solution Pattern**:
```swift
// When in async context (camera completion handler, DispatchQueue callback):
DispatchQueue.main.async {
    self.entries.insert(newEntry, at: 0)  // Safe
}

// When in loadExistingEntries:
let loadedEntries = mdFiles.compactMap { ... }  // Work on local copy
entries = loadedEntries  // Assign once to @State
// Now safe to check entries.contains, entries.first, etc.
```

### File System Architecture

**Why UUID + Timestamp Naming?**

The filename format `[UUID]-[YYYY-MM-DD-HH-mm-ss].md` serves multiple purposes:

1. **UUID**: Ensures global uniqueness even if multiple devices sync to same folder
2. **Timestamp**: Human-readable sorting in Finder without opening files
3. **Brackets**: Makes regex extraction reliable: `\\[(.*?)\\]` and `\\[(\\d{4}-\\d{2}-\\d{2}-\\d{2}-\\d{2}-\\d{2})\\]`

**File Loading Algorithm**:

```swift
// 1. Get all files
let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, ...)
let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

// 2. Parse each .md file
let entriesWithDates = mdFiles.compactMap { fileURL -> (entry, date, content)? in
    // Extract UUID from filename using regex
    let uuidMatch = filename.range(of: "\\[(.*?)\\]", options: .regularExpression)
    let uuid = UUID(uuidString: String(filename[uuidMatch].dropFirst().dropLast()))

    // Extract timestamp
    let dateMatch = filename.range(of: "\\[(\\d{4}-\\d{2}-\\d{2}-\\d{2}-\\d{2}-\\d{2})\\]", ...)
    let dateString = String(filename[dateMatch].dropFirst().dropLast())

    // Parse date for sorting
    dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
    let fileDate = dateFormatter.date(from: dateString)

    // Check for corresponding video
    let videoFilename = filename.replacingOccurrences(of: ".md", with: ".mov")
    let hasVideo = hasVideoAsset(for: videoFilename) // checks current + legacy locations

    // Read content for preview
    let content = try String(contentsOf: fileURL, encoding: .utf8)
    let preview = content.replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
    let truncated = preview.isEmpty ? "" : String(preview.prefix(30)) + "..."

    return (entry: HumanEntry(...), date: fileDate, content: content)
}

// 3. Sort by actual date (not display date)
entries = entriesWithDates
    .sorted { $0.date > $1.date }  // Newest first
    .map { $0.entry }
```

**Why separate .md and .mov files instead of embedding?**

- User can open .md files in any text editor
- Video files can be played in QuickTime independently
- Easier to backup/sync text separately from large video files
- Transparent file format for user ownership
- Per-entry video directories keep each recording's media + thumbnail together

### Auto-Save State Machine

The app implements **continuous auto-save** with debouncing:

```swift
.onChange(of: text) { _ in
    if let currentId = selectedEntryId,
       let currentEntry = entries.first(where: { $0.id == currentId }) {
        saveEntry(entry: currentEntry)
    }
}
```

**State Transitions**:
1. User types character → `text` state updates
2. `.onChange` fires immediately
3. `saveEntry()` writes to disk synchronously (fast on SSD)
4. No loading spinner needed (happens in <10ms)

**Edge Case**: What if user switches entries before save completes?

```swift
Button(action: {
    if selectedEntryId != entry.id {
        // Save current entry BEFORE switching
        if let currentId = selectedEntryId,
           let currentEntry = entries.first(where: { $0.id == currentId }) {
            saveEntry(entry: currentEntry)
        }

        selectedEntryId = entry.id
        loadEntry(entry: entry)
    }
})
```

This ensures no data loss on rapid entry switching.

### Timer Implementation Details

The timer is **not a countdown** - it's a visual focus tool:

```swift
@State private var timeRemaining: Int = 900  // 15 minutes default
@State private var timerIsRunning = false

let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

.onReceive(timer) { _ in
    if timerIsRunning && timeRemaining > 0 {
        timeRemaining -= 1
    } else if timeRemaining == 0 {
        timerIsRunning = false
        // Show bottom nav again when timer expires
        bottomNavOpacity = 1.0
    }
}
```

**UI Behavior During Timer**:
- When timer starts: Bottom nav fades out after 1 second
- While running: Nav only appears on hover
- When timer ends: Nav fades back in

This creates **immersion** - the UI disappears, leaving only text and timer.

**Timer Adjustment**:
- Scroll wheel over timer: Adjust in 5-minute increments
- Click: Start/pause
- Double-click: Reset to 15 minutes

```swift
NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
    if isHoveringTimer {
        let scrollBuffer = event.deltaY * 0.25
        if abs(scrollBuffer) >= 0.1 {
            let currentMinutes = timeRemaining / 60
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, ...)
            let direction = -scrollBuffer > 0 ? 5 : -5
            let newMinutes = currentMinutes + direction
            let roundedMinutes = (newMinutes / 5) * 5
            timeRemaining = roundedMinutes * 60
        }
    }
    return event
}
```

### Backspace Disable Mechanism

**Implementation**:
```swift
@State private var backspaceDisabled = false

NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    if backspaceDisabled && (event.keyCode == 51 || event.keyCode == 117) {
        return nil  // Swallow the event
    }
    return event
}
```

**macOS Key Codes**:
- 51: Delete/Backspace key
- 117: Forward delete (fn+delete)

**Why this matters**: Forces users to write without editing, embracing imperfection and maintaining flow state.

### Video Recording Architecture

**AVFoundation Setup Sequence**:

```swift
// 1. Create session
captureSession = AVCaptureSession()

// 2. Get devices
let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
let audioDevice = AVCaptureDevice.default(for: .audio)

// 3. Create inputs
let videoInput = try AVCaptureDeviceInput(device: videoDevice)
let audioInput = try AVCaptureDeviceInput(device: audioDevice)

// 4. CRITICAL: Begin configuration
captureSession?.beginConfiguration()

// 5. Configure session
captureSession?.sessionPreset = .high
captureSession?.addInput(videoInput)
captureSession?.addInput(audioInput)

// 6. Add output
videoOutput = AVCaptureMovieFileOutput()
captureSession?.addOutput(videoOutput!)
audioDataOutput = AVCaptureAudioDataOutput()
audioDataOutput?.setSampleBufferDelegate(self, queue: speechQueue)
captureSession?.addOutput(audioDataOutput!)

// 7. CRITICAL: Commit configuration
captureSession?.commitConfiguration()

// 8. Start running on background thread
DispatchQueue.global(qos: .userInitiated).async {
    self.captureSession?.startRunning()
}
```

**Startup/Teardown Safety Rule**:
- Trigger camera setup from a single lifecycle path (avoid duplicate `checkPermissions()` calls for the same view presentation).
- Call `startRunning()` only once per configured session startup path.
- Guard setup with a dedicated in-flight flag (e.g. `isSettingUpSession`) so repeated permission callbacks/onAppear events cannot run parallel setup work.
- Attach/bind `AVCaptureVideoPreviewLayer` only after `startRunning()` completes to avoid concurrent session mutations during startup.
- During teardown, prefer `stopRunning()` + releasing references over removing inputs/outputs while the session may still be transitioning states.

**Why `beginConfiguration()` / `commitConfiguration()`?**

AVCaptureSession maintains internal arrays of inputs/outputs. When you call `addInput()` or `addOutput()`, it mutates these arrays. If the session is actively running or if another thread is enumerating these arrays (for validation, etc.), you get collection mutation crash.

`beginConfiguration()` tells the session: "I'm about to make multiple changes, don't validate or enumerate until I'm done."

`commitConfiguration()` tells the session: "I'm done, now validate everything and update internal state."

**Recording Flow**:

```swift
// Start recording
videoOutput.startRecording(to: tempURL, recordingDelegate: self)

// Delegate callback when done
func fileOutput(_ output: AVCaptureFileOutput,
                didFinishRecordingTo outputFileURL: URL,
                from connections: [AVCaptureConnection],
                error: Error?) {
    DispatchQueue.main.async {
        self.onRecordingComplete?(outputFileURL)
    }
}
```

**Temporary File Strategy**:
- Record to temp directory: `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")`
- On completion: Copy to permanent location
- Why? If recording fails, temp file is auto-cleaned by OS

### Speech Transcription (Speech Framework)

Speech transcription in `VideoRecordingView` is implemented with Apple's `Speech` framework and runs in the background during recording:

1. Request speech auth with `SFSpeechRecognizer.requestAuthorization`.
2. Keep camera/video recording on `AVCaptureMovieFileOutput`.
3. Add `AVCaptureAudioDataOutput` to the same capture session and stream sample buffers to speech recognition.
4. Feed sample buffers into `SFSpeechAudioBufferRecognitionRequest` (`appendAudioSampleBuffer`).
5. Build partial + committed transcript text while recording (no live caption overlay rendered).
6. Finalize transcript on stop and persist it as `transcript.md` in that entry's video directory.

Key details:
- Camera, microphone, and speech recognition permissions are all required before opening the recorder.
- If any permission is denied, the app keeps the user in the writing view and shows a compact camera-icon popover with the missing permission(s).
- Transcription is started on recording start and stopped on recording stop.
- Final transcript formatting is applied at stop to improve readability before saving/copying.
- Video playback nav exposes `Copy Transcript` for saved video entries with a transcript file.
- App sandbox requires `com.apple.security.personal-information.speech-recognition` entitlement plus `NSSpeechRecognitionUsageDescription`.

### Video Thumbnail Generation Nuances

```swift
func generateVideoThumbnail(from url: URL) -> NSImage? {
    let asset = AVAsset(url: url)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true  // CRITICAL

    let cgImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 1), ...)
    return NSImage(cgImage: cgImage, size: NSSize(...))
}
```

**`appliesPreferredTrackTransform = true`**:

Videos recorded on front-facing camera are often rotated 90°. The video file contains a transform matrix that says "rotate this video when playing." Without `appliesPreferredTrackTransform`, the thumbnail would be sideways.

**Performance Note**: Thumbnails are generated once when a recording is saved and persisted as `thumbnail.jpg` in each entry's video directory. Sidebar rows load precomputed image files instead of extracting frames from `.mov` during render. For older entries without thumbnails, the app lazily generates once and saves for subsequent loads.

### Text Editor Header Behavior

Every entry starts with `\n\n` (two newlines):

```swift
TextEditor(text: Binding(
    get: { text },
    set: { newValue in
        if !newValue.hasPrefix("\n\n") {
            text = "\n\n" + newValue.trimmingCharacters(in: .newlines)
        } else {
            text = newValue
        }
    }
))
```

**Why?** Creates visual breathing room at top of page. All entries look like they start mid-page, not cramped at the top edge.

### Entry Creation Logic

**Complex Decision Tree**:

```swift
if entries.isEmpty {
    // First time user → create welcome entry
    createNewEntry()
} else if !hasEmptyEntryToday && !hasOnlyWelcomeEntry {
    // No empty entry for today → create new entry
    createNewEntry()
} else {
    // Select most recent empty entry from today
    if let todayEntry = entries.first(where: { isFromTodayAndEmpty }) {
        selectedEntryId = todayEntry.id
        loadEntry(entry: todayEntry)
    } else if hasOnlyWelcomeEntry {
        // Only have welcome entry → select it
        selectedEntryId = entries[0].id
        loadEntry(entry: entries[0])
    }
}
```

**Date Comparison Complexity**:

Display dates are "MMM d" (e.g., "Feb 20") without year. To check "is this from today?":

```swift
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "MMM d"
if let entryDate = dateFormatter.date(from: entry.date) {
    // entryDate is now "Feb 20" in year 1 (default year)
    // Need to add current year to compare
    var components = calendar.dateComponents([.year, .month, .day], from: entryDate)
    components.year = calendar.component(.year, from: Date())

    if let entryDateWithYear = calendar.date(from: components) {
        let entryDayStart = calendar.startOfDay(for: entryDateWithYear)
        let todayStart = calendar.startOfDay(for: Date())
        return calendar.isDate(entryDayStart, inSameDayAs: todayStart)
    }
}
```

This handles edge cases like February 29th on non-leap years.

### Font System

**Available Fonts**:
```swift
let standardFonts = ["Lato-Regular", "Arial", ".AppleSystemUIFont", "Times New Roman"]
let availableFonts = NSFontManager.shared.availableFontFamilies
```

**Random Font Button**:
- Picks random font from `availableFonts` (excludes standardFonts)
- Shows current random font in button: "Random [FontName]"
- Clicking again picks new random font

**Font Rendering**:
```swift
.font(.custom(selectedFont, size: fontSize))
```

`.custom()` falls back to system font if font not found, so app is resilient to missing fonts.

### Line Spacing Calculation

```swift
var lineHeight: CGFloat {
    let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
    let defaultLineHeight = getLineHeight(font: font)
    return (fontSize * 1.5) - defaultLineHeight
}

func getLineHeight(font: NSFont) -> CGFloat {
    let layoutManager = NSLayoutManager()
    return layoutManager.defaultLineHeight(for: font)
}
```

**Formula**: Target line height is 1.5× font size. Subtract natural line height to get spacing to add.

Example: 18px font → target 27px line height → natural 21px → add 6px spacing

This creates **generous vertical rhythm** for readability during long writing sessions.

### Chat Integration

**Prompts**:
```swift
let aiChatPrompt = "You are a writing coach. Help me understand what I wrote below and ask me questions about it:\n\n"
let claudePrompt = "You are a thoughtful writing partner. Read what I wrote and help me explore the ideas further:\n\n"
```

**URL Encoding**:
```swift
let fullText = aiChatPrompt + "\n\n" + trimmedText
if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
   let url = URL(string: "https://chat.openai.com/?prompt=" + encodedText) {
    NSWorkspace.shared.open(url)
}
```

**Length Handling**:
- URLs >6000 chars fail in some browsers
- If too long, shows "Copy Prompt" button instead
- Copies to clipboard for manual paste

**Prompts are user-editable**: `aiChatPrompt`/`claudePrompt` are no longer hardcoded constants.
`ContentView` computes `effectiveChatGPTPrompt` / `effectiveClaudePrompt` / `effectiveOllamaPrompt`
from `@AppStorage` values (`AppSettingsKeys.customChatGPTPrompt` etc.) that fall back to
`PromptLibrary.defaultChatGPTPrompt` / `.defaultClaudePrompt` / `.defaultOllamaPrompt`
(`Prompts.swift`) when empty. Edited via the Settings sheet (see below).

### AI Chat: Offline (Ollama)

Alongside ChatGPT/Claude (which open a browser tab with a URL-encoded prompt), the Chat popover
has an **"Ollama (Offline)"** option that talks to a local Ollama server over HTTP — no browser,
no account, no data leaving the machine. Unlike the ChatGPT/Claude paths, it isn't gated by the
6000-char URL-length check (there's no URL involved), only by the same "guide text" / "write ≥350
chars first" gating that governs whether chat is offered at all.

It's a real **multi-turn conversation**, not a single one-shot Q&A: after the initial reflection,
the user can type follow-up questions and the model replies with the full conversation as context.

**`OllamaService.swift`** (`@MainActor final class OllamaService: ObservableObject`):
- `@Published var messages: [OllamaChatMessage]` — the full transcript (`OllamaChatMessage` has
  `role: .user | .assistant` and `content: String`), rendered as chat bubbles by the panel
- `fetchModels(endpoint:)` — `GET {endpoint}/api/tags`, populates `availableModels: [String]`
- `startConversation(endpoint:model:initialPrompt:)` — resets `messages` to a single user turn,
  then streams the assistant's reply
- `sendFollowUp(endpoint:model:text:)` — appends a user turn to the existing `messages`, then
  streams the assistant's reply
- Both funnel into `streamAssistantReply(endpoint:model:)` (private): `POST {endpoint}/api/chat`
  with `stream: true` and the **entire message history** as `messages: [{role, content}]` — Ollama's
  `/api/chat` is stateless per-request, so the client resends the whole transcript each turn. Reads
  `URLSession.bytes(for:).lines`, decodes each line as `{"message":{"role":"assistant","content":"..."},"done":false}`,
  appending `content` fragments onto the in-progress assistant message in `messages` as they arrive
  (true token-by-token streaming). On failure, removes the empty assistant placeholder it had
  appended so a failed turn doesn't leave a dangling empty bubble.
- `resetConversation()` / `cancel()` — clear/cancel respectively
- URL building (`apiURL(endpoint:path:)`) trims a trailing `/` and uses `URL.appendingPathComponent`
  rather than `URLComponents` — **do not** build the request URL via
  `URLComponents.path = ...; components.url`, since `URLComponents.url` returns `nil` whenever the
  resulting path doesn't start with `/` and there's a host component (RFC 3986); this was a real
  bug caught during development (endpoint "http://localhost:11434" produced a nil URL).

**`OllamaPanelView.swift`**: side panel matching the History sidebar's visual language (fixed
width, header/divider/scroll-body/footer), inserted into `ContentView`'s outer `HStack` alongside
the History sidebar, gated on `showingOllamaPanel`. Mutually exclusive with the History sidebar
(opening one closes the other).
- Body renders `service.messages` as chat bubbles (`bubble(for:)`) — user turns right-aligned/
  accent-tinted, assistant turns left-aligned/gray, auto-scrolling to the bottom
  (`ScrollViewReader` + `.onChange(of: service.messages)`) as new content streams in.
- Message content is rendered through `markdownText(_:)`, which tries
  `AttributedString(markdown:options: .init(interpretedSyntax: .full))` and falls back to plain
  `Text` if parsing fails — so headings/bold/lists/links in a response render properly instead of
  showing raw `**`/`#` characters.
- Header has a model picker (persisted via `AppSettingsKeys.ollamaModel`), refresh button, and (once
  a conversation has started) a "New Chat" button that calls `resetConversation()` + restarts.
- Footer has an "Ask a follow-up..." `TextField` (multi-line, `axis: .vertical`) in one compose
  row with the mic (dictate), a `wand.and.stars` menu (Continue / Tighten / Ask — the quick-start
  canned prompts, folded into an icon menu instead of their own row of text buttons), and Send.
  Below that, a second row — Stop (while streaming) / Copy / Undo / Insert / a "More" menu
  (Replace, Note) — acts on the **last assistant message** (`lastAssistantMessage`), not the whole
  transcript. That row only renders at all when there's something for it to do
  (`service.isStreaming || canUndo || hasReplyContent`), and Copy/Insert/More only render once
  `hasReplyContent` is true, so the panel doesn't show a row of disabled buttons before the first
  reply exists. `hasReplyContent` checks trimmed non-emptiness, not `lastAssistantMessage != nil` —
  the assistant slot is non-nil (an empty placeholder) from the moment a reply starts streaming,
  before any tokens arrive. Insert appends, Replace rewrites the visible page (image markdown
  stays), Note adds the first sentence as `>> …`. Undo puts the page back. Suggested `#tags` from
  repeated words on the page sit above those buttons. Highlight text before opening Chat to ground
  Continue / Tighten / Ask in that passage.
- Switching the model picker mid-conversation calls `restart()` (reset + start fresh) rather than
  continuing the old transcript with a different model.

`ContentView.startOllamaChat()` builds the initial prompt (`effectiveOllamaPrompt + "\n\n" +
currentChatSourceText()`) and opens the panel; the panel's own `onAppear` fetches models and
kicks off the first generation.

### Settings (SettingsView.swift)

The writing bar (words, timer, Chat, New, Settings), the ••• menu, ⌘,, and Quire → Settings
open a panel overlay on the page. Never use `Settings { }` or `Window("Settings")` —
macOS draws every letter twice (Folderer, Pageage, Lockk). Do not put a gear in the
window title bar. Writing / Chat / About pills, grouped cards, switches on the right.
Do not put a `TabView` in this panel. The Dock icon is `Resources/AppIcon.icns`; `./build.sh`
writes `build/Quire.app` and `build/Quire.zip`.
- **Chat** tab: Claude Code / Codex paths, one shared tone (`PromptLibrary.effectiveTone` —
  prefers a custom Ollama tone, then leftover Claude/ChatGPT values), Ollama endpoint + test,
  default model, thinking (`off` / `on` / `low` / `medium` / `high` / `max`), temperature,
  context size, and the Ollama system prompt. Show/hide thinking lives only in the Chat ••• menu.
- **Writing** tab: folder, page toggles, lock, camera/mic, extras (images, graph, notes, mermaid)
- **About** tab: the room, Surenjanath (email + GitHub), journal folder, privacy,
  what’s included, shortcuts. Copy lives on `QuireAction`.

### Sidebar Search & Writing Streak

The History sidebar (`ContentView.swift`) is `280pt` wide (was `200pt`, widened to fit the search
field and streak badge comfortably) and has:
- A **search field** (`sidebarSearchQuery` state) filtering `entries` via
  `matchesSearch(_:query:)` — matches on `previewText`, `date`, and (for a non-empty query) the
  full entry content read from disk, or the video transcript for video entries. Filtered list is
  `filteredSidebarEntries`; not indexed/cached, matching the app's existing "just read the file"
  style in `loadExistingEntries()` — fine at personal-journal entry counts.
- A **streak badge** (`writingStreak` computed property, "🔥 N") next to the "History" header —
  counts consecutive days backward from today (or from yesterday if today has no entry yet, so an
  in-progress day doesn't zero the streak) using each entry's parsed filename timestamp.
- A **pin/favorite star** per row (`pinnedEntryIDs: Set<String>`, persisted to `UserDefaults` key
  `"pinnedEntryIDs"` as an array of UUID strings — not file-based, since entry files themselves
  aren't touched). `filteredSidebarEntries` does a **stable** sort (`Array.sorted` is
  stability-guaranteed since Swift 5) that bubbles pinned entries to the top while preserving the
  existing date-desc order within each group. `togglePin(_:)` toggles membership + persists;
  `deleteEntry` also removes the id from the set so it doesn't leak.

### Word Count

`currentWordCount` (computed from `text`, whitespace-split) is shown in the bottom-right utility
bar just before the timer, only when viewing a text entry (hidden for video entries where there's
no text editor).

### Font Controls (Dropdowns)

The font-size and font-family controls in the bottom-left nav are `Menu`s (`.menuStyle(.borderlessButton)`),
not a row of always-visible buttons — replaced to save horizontal space. Font-size menu lists
`fontSizes` with a checkmark on the current value; font-family menu has Lato/Arial/System/Serif/Random,
same actions as before. `currentFontDisplayName` maps `selectedFont` back to a friendly label for
the menu's own title (falls back to `currentRandomFont` when a random font is active).

### Export Formats

The sidebar's per-entry export icon is a `Menu` (was a single PDF-export button): "Export as PDF"
(unchanged, `exportEntryAsPDF`), "Export as Markdown", and "Export as Text" — the latter two both
go through `exportEntryAsPlainFile(entry:fileExtension:contentType:)`, which just writes the
entry's raw stored content (already Markdown) under the chosen extension/UTType.

### Ollama Model Pull

`OllamaPanelView`'s empty-models state (`OllamaService.availableModels.isEmpty`) offers an inline
pull instead of only telling the user to run a terminal command: a text field for the model name +
"Pull" button, calling `OllamaService.pullModel(endpoint:name:)`. That method streams
`POST {endpoint}/api/pull` (`{"name":..., "stream": true}`), decoding each line as
`{"status":"...", "completed":N, "total":M}` / `{"error":"..."}` chunks into `@Published var
pullStatus` / `pullProgress` (`Double?`, `completed/total`) / `pullError`, and calls
`fetchModels(endpoint:)` again on success so the newly pulled model shows up in the picker
immediately. `cancelPull()` cancels the in-flight pull `Task`.

### Ollama Chat Persistence

Each entry's Ollama conversation is saved to its own JSON file at
`~/Documents/Freewrite/Chats/[entry-base].json` (same `[UUID]-[timestamp]` base as the entry's
`.md`/video-directory naming — see `chatHistoryURL(for:)`), containing the full
`[OllamaChatMessage]` transcript (`OllamaChatMessage` is `Codable`). `ContentView.startOllamaChat()`
loads any existing history and calls `ollamaService.restoreConversation(_:)` *before* showing the
panel; `OllamaPanelView.refreshModels()` detects a non-empty `service.messages` on first appearance
and marks itself started without regenerating. Saving happens on
`.onChange(of: ollamaService.isStreaming)` transitioning to `false` (i.e., once each turn finishes
streaming) rather than on every token, to avoid excessive disk I/O. `deleteEntry` also deletes the
matching chat JSON file.

**Race avoided**: `OllamaPanelView`'s model picker auto-selects a default model on first load,
which would normally fire `.onChange(of: selectedModel) { restart() }` and wipe a just-restored
conversation. A `suppressModelChangeRestart` flag set right before that programmatic assignment
(and consumed by the very next `onChange` firing) distinguishes "we picked this" from "the user
picked this" so only an explicit user-initiated model switch mid-conversation triggers a restart.

### Voice Dictation for Follow-ups

`VoiceDictationService.swift` is a small, self-contained `SFSpeechRecognizer` +
`AVAudioEngine`-based dictation service — deliberately separate from `VideoRecordingView`'s speech
transcription, which is tied to an `AVCaptureSession`/camera. This one taps the default microphone
input directly (`audioEngine.inputNode.installTap`), feeds buffers into a
`SFSpeechAudioBufferRecognitionRequest`, and publishes live partial results as `transcript`. The mic
button in `OllamaPanelView`'s footer toggles it; while recording, `transcript` is mirrored live into
`followUpText` (`.onChange(of: dictation.transcript)`) so the user sees it fill in as they talk, and
can still edit before sending. No new entitlements needed — `com.apple.security.device.audio-input`
and `com.apple.security.personal-information.speech-recognition` already exist for video recording.

### Ollama Persona Presets

`OllamaPersona` (`Prompts.swift`): `.defaultTone` (`promptOverride == nil`, meaning "use whatever
prompt Settings has configured"), `.therapist`, `.devilsAdvocate`, `.hypeFriend` — each with its own
full prompt text. A `Menu` next to the model picker in `OllamaPanelView` lets the user swap tone
mid-session without opening Settings; `effectivePrompt` composes
`(selectedPersona.promptOverride ?? basePrompt) + "\n\n" + sourceText`, and switching persona calls
`restart()` (a persona change only makes sense as a fresh conversation, not applied retroactively).

### Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+N | New entry |
| Cmd+, | Settings |
| Ctrl+Cmd+F | Fullscreen |
| Cmd+Shift+H | History sidebar |
| Cmd+Shift+T | Start / pause timer |
| Cmd+Shift+D | Light / dark theme |
| Cmd+Shift+B | Backspace lock |
| Cmd+Shift+M | Dictate into the current text entry |
| Cmd+Shift+A | Record a voice note (audio file + live transcript) |
| Cmd+Shift+O | Open Ollama chat (gated by `canOfferOllamaChat()`) |
| Cmd+Shift+R | Weekly Ollama review of the last 7 days |
| Cmd+K | Go: commands and journal search |
| Cmd+Shift+L | Focus this sentence |
| Cmd+Shift+Y | Toggle typewriter scroll |

Cmd+Shift+O and Cmd+Shift+T are hidden buttons on the root view. The others are attached to the
matching bottom-nav controls. Cmd+Shift+O is still gated by the same "guide text" / "write ≥350
chars first" checks the Chat popover uses.

### Editor Dictation

`VoiceDictationService` (already used for Ollama follow-ups) can also fill the main `TextEditor`.
"Dictate" in the ⋯ menu (text entries only, ⌘⇧M) snapshots `text` when recording starts, then
applies `EditorDictation.combining(base:transcript:)` as partial results arrive so spoken words
replace themselves without eating already-typed text. Dictation stops when the user creates a new
entry, opens the video recorder, or switches to a video entry. Since the ⋯ menu closes as soon as
you pick an item, the menu label toggling to "Stop Dictation" isn't visible once recording starts —
a pulsing red dot + "Dictating" (or "Recording voice note", which takes priority since Voice Note
also turns dictation on underneath it) shows in the bottom-right utility row for as long as either
is active (`recordingIndicatorLabel`). Any future ⋯-menu toggle that keeps running after the menu
closes should get the same kind of persistent indicator, not just a menu-label change no one sees.

### Writing Preference Persistence

Font family, font size, backspace lock, and the *configured* timer length (`preferredTimerSeconds`)
are stored in `UserDefaults` via `AppSettingsKeys`. The live countdown is still `@State` so a
running timer does not write disk every second. On launch, `timeRemaining` is restored from
`preferredTimerSeconds`. Double-clicking the timer still resets both to 15:00. Scroll-wheel
adjustments update both the live timer and the persisted preferred length. Invalid stored values
are sanitized by `WritingPreferences`.

### On This Day, Weekly Review, Session Recap, Typewriter

- **On this day**: History sidebar shows a banner when an older entry shares today's month/day. Clicking it opens that entry. Date math lives in `JournalInsights.swift` and reads wall-clock parts from the canonical filename so time zones cannot shift the day.
- **Weekly Review**: Chat menu and History both offer "Weekly Review" (shortcut Cmd+Shift+R). It compiles the last 7 days of text + video transcripts, skips the welcome guide / empty files, and opens Ollama with `PromptLibrary.defaultWeeklyReviewPrompt`. It does not overwrite that day's per-entry chat history (`ollamaChatEntryId` is nil).
- **Session recap**: When the timer reaches 0, a short overlay shows words written this session and the configured duration, then fades.
- **Typewriter**: Font menu toggle (persisted via `AppSettingsKeys.typewriterMode`). While on, `TypewriterScroll` insets the `NSTextView` and keeps the caret vertically centered.
- **Daily spark**: Empty-page placeholder comes from `WritingSpark.prompt(for:)` and stays the same all day.
- **History calendar**: Month heatmap in the History sidebar. Days with entries are outlined; click jumps to that day's latest note.
- **Voice notes**: "Voice Note" in the ⋯ menu (⌘⇧A) records an `.m4a` under `Media/[entry-base]/` and prepends `[voice note](…)` while live dictation fills the page. A play strip appears when an entry has voice clips. A pulsing red dot + label in the bottom-right utility row shows while it (or plain dictation) is recording — see Editor Dictation above.
- **Journal folder**: Settings → Writing can point at any folder via a security-scoped bookmark (`journalFolderBookmark`). Videos and Chats stay under that root. Reset returns to `~/Documents/Freewrite` (or the sandbox container equivalent). Changing folder reloads History.
- **Touch ID lock**: Settings → Writing toggle. Off by default. When on, launch shows a lock overlay and prompts for Touch ID or the Mac password before loading entries. This is a gate only — files on disk stay plain markdown.
- **Tags**: `#river` chips appear under the page. Clicking one searches History for that tag. Headings (`# Title`) are ignored.
- **Mermaid**: Settings → Writing. Fence a chart as a mermaid code block (`graph TD` / `A[Start] --> B`). A quiet strip under the page lists the edges.
- **Draw on screenshots**: With images on, click a thumbnail to ink on it. Save burns the strokes into the PNG.
- **Daily word goal**: Settings → Writing. 0 hides it. Otherwise History shows today's words toward the goal.
- **Privacy blur**: Eye button / ⌘⇧P covers the page in public. ⌘F finds in the current entry. Trash asks before deleting, then moves the entry (and its video/chat assets) to the macOS Trash via `moveToTrash` rather than a permanent delete — recoverable from Finder, falling back to a real delete only if Trash itself is unavailable for that path. ChatGPT/Claude URLs encode `&`. Saves debounce on a 1s timer. Settings can match the Mac appearance; theme toggle no longer recreates the editor.
- **Idle fade**: Settings → Writing. After eight seconds without typing, the bottom bar hides. Hover the bottom edge to bring it back.
- **Bottom bar**: Words, timer, Chat, New, and icons stay in the row. Dictate, voice, images, and privacy live under the ⋯ menu. Image markdown and leftover screenshot paths are hidden from the page.
- **Tests**: `./run-tests.sh` compiles the logic files without Xcode and must print `PASS`. Word count and find use the visible page (no image markdown). A line like `Start → Write` becomes a mermaid strip when Advanced diagrams are on.
- **Grounded Ollama**: Chat packs the current page plus related past entries. The system prompt tells the model to use only that text, skip the stock greeting, and keep reasoning in thinking. Follow-ups re-search the journal. Continue / Tighten / Ask sit under the composer. Highlight a passage first to talk about just that. Insert / Replace / Note put the reply on the page (stock greeting stripped; images stay). Undo restores the page. Repeated words become suggested `#tags`. Settings can set thinking, temperature, and context.
- **Claude Code / Codex**: Chat menu opens a side panel (`AgentPanelView`). Reflect / Improve / Diagram / Ask stream into the panel. Copy / Undo / Insert / a "More" menu (Replace, Note) put the reply on the page — that row only appears once there's a reply or an undo available, not as disabled buttons up front. Follow-ups resend the journal plus your question. Paths live in Settings → Chat. The journal is sent on stdin. Mermaid turns on if a chart comes back. SVG fences are saved under Media.
- **Go (⌘K)**: A small sheet for commands (Chat, Claude Code, New, Settings…) and a search of past pages. Journal → Go. Type a word from an old page to jump there. Random page is in the list.
- **Page versions**: Chat Insert/Replace/Note and Claude Code / Codex snapshot the page first under `Versions/[entry-base]/`. Last 20. Restore from Go → Earlier versions, Journal menu, or ⋯. Restore snapshots the current page first. Images stay via `MarkdownExtras.restoringImageLines`.
- **Compare then apply**: Insert / Replace / Note open Now vs After (`ApplyCompareView`). Put on page confirms. `PageCompare.swift`.
- **Journal zip**: File → Export Journal. `JournalExport` copies `*.md`, `Media/`, `Versions/`. Skips Videos and Chats. `ditto -c -k`.
- **Capture devices**: Settings → Writing camera / mic pickers. `CaptureDevices` + `CameraManager.setupCamera`. Voice notes still use the Mac input.
- **Per-page lock**: History lock icon. `PageLock` stores UUIDs. Touch ID to open or unlock. Disk stays markdown.
- **Quiet sounds**: Typewriter `Tink` and generated room tone. Off by default.
- **Soft markdown**: Dim markers via `SoftMarkdown.markerRanges`. Font menu + Settings.
- **Sentence focus (⌘⇧L)**: Dims every sentence except the one under the caret, like iA Writer. Font menu toggle. Stays off until you turn it on.
- **Yesterday continue**: An empty page can show yesterday's last sentence. Click it to start from there.
- **Favorite fonts**: Font menu → Add to favorites. Starred faces sit at the top.
- **IME-safe backspace lock**: Delete still works while composing Japanese/Chinese marked text.

### PDF Export Implementation

```swift
func exportEntryAsPDF(entry: HumanEntry) {
    let savePanel = NSSavePanel()
    savePanel.title = extractTitleFromContent(content, date: entry.date)
    savePanel.allowedContentTypes = [.pdf]

    if savePanel.runModal() == .OK {
        let pdfData = createPDF(from: content)
        try pdfData.write(to: savePanel.url!)
    }
}
```

**Title Extraction**:
- Takes first 4 words of content
- Removes punctuation
- Falls back to "Entry [date]" if content empty

### Theme System

```swift
@State private var colorScheme: ColorScheme = .light

// Apply to entire window
.preferredColorScheme(colorScheme)

// Persisted to UserDefaults
UserDefaults.standard.set(colorScheme == .light ? "light" : "dark", forKey: "colorScheme")
```

**Colors**:
- Light mode text: `Color(red: 0.20, green: 0.20, blue: 0.20)` (dark gray, not black, easier on eyes)
- Dark mode text: `Color(red: 0.9, green: 0.9, blue: 0.9)` (off-white, not pure white)

## Common Pitfalls

### Deletes Go to Trash, Not `removeItem`

`deleteEntry`, `deleteChatHistory`, and `deleteVideoAssets` all route through `moveToTrash(_:)`,
which calls `FileManager.trashItem(at:resultingItemURL:)` first and only falls back to a permanent
`removeItem` if Trash itself throws. This is the Apple-recommended pattern for App Sandbox apps
deleting user files, and it means an accidental delete — the one destructive action in Quire with
no in-app Undo — is recoverable from Finder. Video assets are trashed as a whole managed directory
(video + thumbnail + transcript together) rather than as scattered individual files, so a restore
brings the entry back intact. When adding a new kind of per-entry file, delete it through
`moveToTrash`, not `fileManager.removeItem` directly.

### Local Agent Process I/O: Drain Both Pipes

`LocalAgent.run` (Claude Code / Codex) must install a `readabilityHandler` on **both** the stdout
and stderr pipes before calling `process.run()`, and only remove them after `waitUntilExit()`. A
pipe's kernel buffer is small (~64KB); if only stdout is drained live, a CLI that writes a lot to
stderr (progress, deprecation warnings, telemetry) can block on its next write once that buffer
fills, and `waitUntilExit()` blocks forever waiting for a child that is itself blocked — a silent,
uncancelable hang with no error surfaced to the UI. Any future `Process` + `Pipe` usage that streams
a long-running CLI should drain every pipe concurrently, not just the one you plan to render.

### Collection Mutation Crashes

**Problem**: Modifying `entries` array while SwiftUI is enumerating it.

**Solution**:
```swift
// BAD
entries.insert(newEntry, at: 0)

// GOOD (from async context)
DispatchQueue.main.async {
    self.entries.insert(newEntry, at: 0)
}
```

### AVCaptureSession Crashes

**Problem**: Session internals can crash with `Collection ... was mutated while being enumerated` when session startup/teardown overlaps (for example duplicate setup/start calls or mutating inputs/outputs during active transitions).

**Solution**:
```swift
captureSession?.beginConfiguration()
// Add/remove inputs and outputs here
captureSession?.sessionPreset = .high
captureSession?.addInput(videoInput)
captureSession?.commitConfiguration()
```

Also:
```swift
// Avoid duplicate startup paths for the same presentation
// and avoid repeated startRunning() calls on the same setup cycle.

if session.isRunning {
    session.stopRunning()
}
// Release session/output references without input/output removal churn.
```

### Speech Recognition Request: One Queue Only

`CameraManager.speechRecognitionRequest` (`SFSpeechAudioBufferRecognitionRequest`) is fed audio
buffers from `captureOutput(_:didOutput:from:)`, which `AVCaptureAudioDataOutput` calls on
`speechQueue` (the queue passed to `setSampleBufferDelegate(_:queue:)`). It's also the thing that
gets created/torn down when live captions turn on/off (`startLiveCaptionRecognitionIfNeeded` /
`stopLiveCaptionRecognition`), which happens from main-thread-driven paths (permission callbacks,
`setCaptionsEnabled`, the recognition task's own result handler). Reading it on one queue while
writing it on another with no synchronization is the same class of bug `captureSession` /
`videoOutput` avoid by being touched only on `sessionQueue` — so `speechRecognitionRequest`'s
writes are dispatched onto `speechQueue` too (`speechQueue.async { self?.speechRecognitionRequest
= ... }`), matching where the delegate callback reads it. `speechRecognitionTask` and the caption
text buffers don't need this — they're never touched from `speechQueue`, only from main-thread
paths.

### File Path Issues

Always use absolute paths:
```swift
let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Freewrite")
let fileURL = documentsDirectory.appendingPathComponent(filename)
```

## Build Configuration

**Scheme**: freewrite
**Configuration**: Debug or Release
**Build Command**:
```bash
xcodebuild -project freewrite.xcodeproj -scheme freewrite -configuration Debug build
```

**Clean Build**:
```bash
xcodebuild -project freewrite.xcodeproj -scheme freewrite -configuration Debug clean build
```

## Testing Video Feature

1. Build and run app
2. Grant camera/microphone permissions when prompted
3. Click video camera icon in bottom nav
4. Click "Start Recording" (turns red)
5. Record for a few seconds
6. Click "Stop Recording"
7. Recorder overlay closes, new video entry is selected, and video opens immediately playing muted
8. Click video entry to play it

## Video Thumbnail Generation

```swift
func generateVideoThumbnail(from url: URL) -> NSImage? {
    let asset = AVAsset(url: url)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true

    let cgImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 1), actualTime: nil)
    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
}
```

Generated at save time and stored in the per-entry video directory; sidebar loads this cached image file.

## Feature Flags / Settings

Stored in `UserDefaults`:
- `colorScheme`: "light" or "dark"
- `selectedFont`, `fontSize`, `backspaceDisabled`, `preferredTimerSeconds`, `typewriterMode` (`AppSettingsKeys`)
- Advanced (off by default): `advancedImages`, `advancedGraph`, `advancedAnnotations`

Session-only:
- Live `timeRemaining` countdown (restored from `preferredTimerSeconds` on launch)

## Future Development Notes

### Adding New Entry Types

1. Add case to `EntryType` enum
2. Update `HumanEntry` with relevant properties
3. Modify `loadExistingEntries()` to detect new file type
4. Update `loadEntry()` to handle new type
5. Add UI in main view for new entry type
6. Update `deleteEntry()` to clean up new file types

### Adding New Navigation Items

Add to bottom nav in ContentView.swift around line 500-950:

```swift
Text("•")
    .foregroundColor(.gray)

Button(action: {
    // Your action
}) {
    Image(systemName: "icon.name") // or Text("Label")
        .foregroundColor(isHovering ? textHoverColor : textColor)
}
.buttonStyle(.plain)
.onHover { hovering in
    isHovering = hovering
    isHoveringBottomNav = hovering
    if hovering {
        NSCursor.pointingHand.push()
    } else {
        NSCursor.pop()
    }
}
```

## Debugging

Enable console output in Xcode to see:
- File loading: "Processing: [filename]"
- Entry creation: "Successfully created video entry"
- Errors: "Error saving video entry: ..."

Check `~/Documents/Freewrite/` in Finder to verify files are being created.

## Code Organization

- **Lines 1-130**: Imports, models, state variables
- **Lines 130-430**: Computed properties and helpers
- **Lines 430-1200**: Main view body and UI
- **Lines 1200-1400**: Helper functions (save, load, delete, etc.)

## Key SwiftUI Patterns Used

- `@State` for local view state
- `@StateObject` for CameraManager
- `.overlay { if showingVideoRecording { ... } }` for immersive video recording
- `.onChange(of:)` for auto-save
- `.onAppear` for initialization
- `ForEach(entries)` with `Identifiable` for list rendering
- Conditional views: `if currentVideoURL != nil { VideoPlayerView } else { TextEditor }`

## Possible next (do not start unless asked)

These still fit the blank page. Prefer one slice at a time. Skip cloud sync, other platforms, vendor-per-tab Settings, and publishing.

1. **Notarize** — Developer ID / Apple notarization. Needs the author's signing identity. Do not fake it. (upstream #92)

Public copy of this list lives in `README.md` (“What could come next”). Keep them in sync if you add or drop an item.

## Summary

Freewrite is a straightforward macOS writing app with video recording capabilities. All data is local, no backend required. The main complexity is in:

1. Proper file management and UUID-based naming
2. Thread-safe array mutations for entries
3. AVFoundation camera setup with proper configuration blocks
4. Conditional rendering between text and video content

When making changes, always:
- Test with actual video recording
- Check for collection mutation crashes
- Verify files are created in correct location
- Ensure privacy permissions are properly configured
