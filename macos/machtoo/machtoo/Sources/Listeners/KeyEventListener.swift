//
//  KeyEventListener.swift
//  machtoo
//
//  Created by Ryan Dioneda on 11/18/26.
//

import AppKit
import MachtooKit

@MainActor
final class KeyEventListener: CoreApiManaging {
    let appHandle: OpaquePointer
    var keyMonitor: Any?
    
    required init(appHandle: OpaquePointer) {
        self.appHandle = appHandle
        self.keyMonitor = nil
    }
    
    ///  Installs NSEvent local monitor on the given panel to inspect key events.
    ///  The panel argument should be the main panel.
    func installKeyMonitor(on panel: NSPanel) {
        guard keyMonitor == nil else { return }
        
        keyMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp]
        ) { event in
            
            let handled = MainActor.assumeIsolated {
                guard panel.isKeyWindow, event.window === panel else {
                    return false
                }
                
                if let editor = panel.firstResponder as? NSTextView,
                   editor.hasMarkedText() { return false }
                
                return self.handleKeyEvent(event)
            }
            return handled ? nil : event
        }
    }
    
    func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }
    
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        NSLog("[Keyboard] Entered KeyEventListener.handleKeyEvent")
        
        let action: MachtooKeyActionVariant
        switch event.type {
        case .keyDown:
            NSLog("[Keyboard] Decoding keyDown, repeat=\(event.isARepeat)")
            
            // Current C API has no repeat action.
            guard !event.isARepeat else { return false }
            action = MACHTOO_KEY_PRESS
        case .keyUp:
            action = MACHTOO_KEY_RELEASE
        default:
            return false
        }
        
        let mods = Self.translateModifiers(event.modifierFlags)
        let input = MachtooKeyEvent(
            action: action,
            native_keycode: UInt32(event.keyCode),
            mods: mods
        )
        
        let handled = machtoo_app_key_event(self.appHandle, input)
        return handled
    }
    
    private static func translateModifiers(
        _ flags: NSEvent.ModifierFlags
    ) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.shift) {
            mods |= UInt32(MACHTOO_MOD_SHIFT)
        }
        if flags.contains(.control) {
            mods |= UInt32(MACHTOO_MOD_CONTROL)
        }
        if flags.contains(.option) {
            mods |= UInt32(MACHTOO_MOD_ALT)
        }
        if flags.contains(.command) {
            mods |= UInt32(MACHTOO_MOD_SUPER)
        }
        return mods
    }
}
