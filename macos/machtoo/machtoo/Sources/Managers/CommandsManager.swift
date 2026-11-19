//
//  CommandsManager.swift
//  machtoo
//
//  Created by Ryan Dioneda on 11/18/26.
//

import Foundation
import MachtooKit

@MainActor
final class CommandsManager: CoreApiManaging {
    let appHandle: OpaquePointer
    
    required init(appHandle: OpaquePointer) {
        self.appHandle = appHandle
    }
    
    func getCommands() -> [Command] {
        let capacity = machtoo_app_read_commands(self.appHandle, nil, 0)
        let buffer = UnsafeMutablePointer<ApiCommand>.allocate(capacity: capacity)
        defer { buffer.deallocate() }
        
        let total = machtoo_app_read_commands(self.appHandle, buffer, capacity)
        precondition(total == capacity, "Command storage changed during a read")
        
        var commands: [Command] = []
        for idx in 0..<total {
            let record = buffer[idx]
            let command = Command(
                id: Self.copyString(record.id),
                name: Self.copyString(record.name),
                description: Self.copyString(record.description)
            )
            commands.append(command)
        }
        
        return commands
    }
    
    private static func copyString(_ value: ApiString) -> String {
        guard let pointer = value.ptr, value.len > 0 else {
            return ""
        }
        
        let bytes = UnsafeBufferPointer(start: pointer, count: value.len)
        return String(decoding: bytes, as: UTF8.self)
    }
}
