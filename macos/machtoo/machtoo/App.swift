//
//  App.swift
//  machtoo
//
//  Created by Ryan Dioneda on 11/18/26.
//

import SwiftUI
import AppKit

@main
struct MachtooApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: MachtooAppDelegate
    
    var body: some Scene {
        Settings {
            // delegate creates panel instead and puts view inside it
            EmptyView()
        }
    }
}

final class MachtooAppDelegate: NSObject, NSApplicationDelegate {
    private var apiCore: MachtooApiCore?
    private var panel: NSPanel?
    
    private var commandsManager: CommandsManager?
    private var keyEventListener: KeyEventListener?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            self.apiCore = try MachtooApiCore()
            guard let core = self.apiCore else { return }
            
            self.commandsManager = CommandsManager(appHandle: core.handle)
            guard let commandsManager = self.commandsManager else { return }
            
            let panel = createBasePanel()
            panel.contentView = NSHostingView(
                rootView: CommandsView(manager: commandsManager)
            )
            
            self.panel = panel
            panel.makeKeyAndOrderFront(nil)
            
            self.keyEventListener = KeyEventListener(appHandle: core.handle)
            guard let keyEventListener = self.keyEventListener else { return }
            
            keyEventListener.installKeyMonitor(on: panel)
            
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
        self.apiCore = nil
    }
    
    /// Creates the base NSPanel that will contain primary views
    private func createBasePanel() -> NSPanel {
        let panel = MachtooPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [
                .borderless,
//                .closable,
//                .titled,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.center()
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        
//        panel.titleVisibility = .hidden
//        panel.titlebarAppearsTransparent = true
//        
//        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
//        panel.standardWindowButton(.zoomButton)?.isHidden = true

        return panel
    }
}

final class MachtooPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
