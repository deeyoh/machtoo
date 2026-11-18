//
//  MachtooApiCore.swift
//  machtoo
//
//  Created by Ryan Dioneda on 11/18/26.
//

import MachtooKit

enum CoreError: Error {
    case appInitFail
}

/// Initializes the App API pointer Zig core uses. Only responsible
/// for storing the pointer .
final class MachtooApiCore {
    var handle: OpaquePointer
    
    init() throws {
        guard let handle = machtoo_app_create() else {
            throw CoreError.appInitFail
        }
        self.handle = handle
    }
    
    deinit {
        machtoo_app_destroy(handle)
    }
}
