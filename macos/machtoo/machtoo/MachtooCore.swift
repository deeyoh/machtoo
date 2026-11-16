//
//  MachtooCore.swift
//  machtoo
//
//  Created by Ryan Dioneda on 11/14/26.
//

import MachtooKit

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

    private static func copyString(_ value: MachtooKit.ApiString) -> String {
        guard let pointer = value.ptr, value.len > 0 else {
            return ""
        }

        // Copy length-delimited UTF-8; these strings are not NUL-terminated.
        let bytes = UnsafeBufferPointer(start: pointer, count: value.len)
        return String(decoding: bytes, as: UTF8.self)
    }
}
