//
//  MachtooCore.swift
//  machtoo
//
//  Created by Ryan Dioneda on 11/14/26.
//

import MachtooKit
import AppKit

enum MachtooCoreError: Error {
    case appInitFailed
}

struct CommandViewModel: Identifiable {
    let id: String
    let name: String
    let description: String
}

final class MachtooCore {
    private var handle: OpaquePointer?
    
    init() throws {
        guard let handle = machtoo_app_create() else {
            throw MachtooCoreError.appInitFailed
        }
        self.handle = handle
    }

    deinit {
        guard let handle else {
            return
        }
        
        machtoo_app_destroy(handle)
        self.handle = nil
    }

    /// Reads and copies borrowed strings synchronously on the main actor.
    /// All future storage mutations must also be serialized on this actor.
    @MainActor
    func getCommands() -> [CommandViewModel] {
        guard let handle else {
            return []
        }

        let capacity = machtoo_app_read_commands(handle, nil, 0)

        let buffer = UnsafeMutablePointer<MachtooKit.ApiCommand>.allocate(
            capacity: capacity
        )
        defer { buffer.deallocate() }

        let total = machtoo_app_read_commands(handle, buffer, capacity)

        precondition(total == capacity, "Command storage changed during a read")

        var commands: [CommandViewModel] = []
        for index in 0..<total {
            let record = buffer[index]

            let command = CommandViewModel(
                id: Self.copyString(record.id),
                name: Self.copyString(record.name),
                description: Self.copyString(record.description)
            )

            commands.append(command)
        }

        return commands
    }

    /// Normalizes native input for Zig. Physical-key translation and binding
    /// lookup belong to the core; true means the native event was consumed.
    @MainActor
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        NSLog("[Keyboard] Entered MachtooCore.handleKeyEvent")
        guard let handle else {
            NSLog("[Keyboard] Skipped: core handle is nil")
            return false
        }

        let action: MachtooKeyActionVariant
        switch event.type {
        case .keyDown:
            NSLog("[Keyboard] Decoding keyDown, repeat=\(event.isARepeat)")
            // The current C API has no repeat action. Leave repeats to native
            // controls rather than executing a binding as another fresh press.
            guard !event.isARepeat else { return false }
            action = MACHTOO_KEY_PRESS
        case .keyUp:
            action = MACHTOO_KEY_RELEASE
        default:
            return false
        }

        NSLog("[Keyboard] Action decoded; translating modifiers")
        let mods = Self.translateModifiers(event.modifierFlags)
        NSLog("[Keyboard] Modifiers translated: \(mods); constructing C event")
        let input = MachtooKeyEvent(
            action: action,
            native_keycode: UInt32(event.keyCode),
            mods: mods
        )
        NSLog("[Keyboard] Calling Zig: type=\(event.type.rawValue) keycode=\(input.native_keycode) mods=\(input.mods)")
        let handled = machtoo_app_key_event(handle, input)
        NSLog("[Keyboard] Zig returned handled=\(handled)")
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

    private static func copyString(_ value: MachtooKit.ApiString) -> String {
        guard let pointer = value.ptr, value.len > 0 else {
            return ""
        }

        // Copy length-delimited UTF-8; these strings are not NUL-terminated.
        let bytes = UnsafeBufferPointer(start: pointer, count: value.len)
        return String(decoding: bytes, as: UTF8.self)
    }
}
