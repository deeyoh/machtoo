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

final class MachtooCore {
    private var handle: OpaquePointer?
    
    init() throws {
        print("INIT")
        guard let handle = machtoo_app_create() else {
            throw MachtooCoreError.appInitFailed
        }
        self.handle = handle
    }

    deinit {
        guard let handle else {
            print("NO HANDLE")
            return
        }
        
        print("machtooCore.deinit happening")
        
        machtoo_app_destroy(handle)
        self.handle = nil
    }
}
