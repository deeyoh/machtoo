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
        Settings¡ {
            EmptyView()
        }
    }
}


final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        showPanel()
    }

    func showPanel() {
        let content = MainView()

        let panel = NSPanel(
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
        panel.orderFrontRegardless()

        self.panel = panel
    }
}
