//
//  freewriteApp.swift
//  freewrite
//
//  Created by thorfinn on 2/14/25.
//

import SwiftUI
import AppKit

@main
struct freewriteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("colorScheme") private var colorSchemeString: String = "light"
    
    init() {
        // Register Lato font
        if let fontURL = Bundle.main.url(forResource: "Lato-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }
    }
     
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorSchemeString == "dark" ? .dark : .light)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 600)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About \(QuireAction.aboutName)") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: QuireAction.aboutName,
                        .credits: NSAttributedString(
                            string: "\(QuireAction.aboutCredits)\nMade by \(QuireAction.aboutAuthor).\nBased on \(QuireAction.aboutBasedOn).",
                            attributes: [.font: NSFont.systemFont(ofSize: 12)]
                        ),
                    ])
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Page") { QuireAction.post(QuireAction.newPage) }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .newItem) {
                Button("Export as PDF…") { QuireAction.post(QuireAction.exportPDF) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Export Journal…") { QuireAction.post(QuireAction.exportJournal) }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { QuireAction.post(QuireAction.openSettings) }
                    .keyboardShortcut(",")
            }
            CommandMenu("Journal") {
                Button("Go…") { QuireAction.post(QuireAction.go) }
                    .keyboardShortcut("k")
                Button("History") { QuireAction.post(QuireAction.toggleHistory) }
                    .keyboardShortcut("h", modifiers: [.command, .shift])
                Button("Chat") { QuireAction.post(QuireAction.toggleChat) }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Focus This Sentence") { QuireAction.post(QuireAction.toggleSentenceFocus) }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Earlier Versions") { QuireAction.post(QuireAction.showVersions) }
            }
        }

    }
}

// Add AppDelegate to handle window configuration
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "New Page", action: #selector(dockNewPage), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(dockSettings), keyEquivalent: "")
        return menu
    }

    @objc private func dockNewPage() {
        QuireAction.post(QuireAction.newPage)
    }

    @objc private func dockSettings() {
        QuireAction.post(QuireAction.openSettings)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            // Ensure window starts in windowed mode
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
            
            // Center the window on the screen
            window.title = QuireAction.aboutName
            window.center()
        }
    }
} 
