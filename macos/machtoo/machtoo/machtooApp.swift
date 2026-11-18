//
//  machtooApp.swift
//  machtoo
//
//  Created by Ryan Dioneda on 10/26/26.
//

import SwiftUI
import AppKit

@main
struct machtooApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}


final class SearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?
    private var core: MachtooCore?
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        do {
            core = try MachtooCore()
            installKeyMonitor()
            showPanel()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Unable to start Machtoo"
            alert.informativeText =
                "The application's Zig core app could not be created."
            alert.alertStyle = .critical
            alert.runModal()
            
            NSApplication.shared.terminate(nil)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        removeKeyMonitor()
        core = nil
    }

    @MainActor
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }

        NSLog("[Keyboard] Installing local key monitor")
        keyMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp]
        ) { [weak self] event in
            // Log before isolation/focus checks so a skipped event is visible.
            // Only key metadata is logged, never the user's typed text.
            NSLog("[Keyboard] Monitor received type=\(event.type.rawValue) keycode=\(event.keyCode) mainThread=\(Thread.isMainThread)")
            // AppKit delivers local event-monitor callbacks on the main thread.
            let handled = MainActor.assumeIsolated {
                guard let self, let panel = self.panel else {
                    NSLog("[Keyboard] Skipped: no panel")
                    return false
                }
                guard panel.isKeyWindow, event.window === panel else {
                    NSLog("[Keyboard] Skipped: panelIsKey=\(panel.isKeyWindow) eventMatchesPanel=\(event.window === panel)")
                    return false
                }
                guard let core = self.core else {
                    NSLog("[Keyboard] Skipped: no core")
                    return false
                }

                // Let the native text editor finish an active IME/dead-key
                // composition before offering shortcuts to the core.
                if let editor = panel.firstResponder as? NSTextView,
                   editor.hasMarkedText() {
                    NSLog("[Keyboard] Skipped: text composition active")
                    return false
                }

                NSLog("[Keyboard] Forwarding to MachtooCore")
                return core.handleKeyEvent(event)
            }
            return handled ? nil : event
        }
    }

    @MainActor
    private func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }

    func showPanel() {
        guard let core else { return }
        let content = MainView(commands: core.getCommands())

        let panel = SearchPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 850,
                height: 600
            ),
            styleMask: [
                .borderless,
                .nonactivatingPanel,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        panel.contentView = NSHostingView(rootView: content)

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        panel.isFloatingPanel = true
        panel.level = .floating

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]

        panel.center()
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
    }
}
