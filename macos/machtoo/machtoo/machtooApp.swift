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

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        do {
            print("HERE")
            core = try MachtooCore()
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
        core = nil
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
