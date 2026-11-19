//
//  CoreApiManaging.swift
//  machtoo
//
//  Created by Ryan Dioneda on 11/18/26.
//

protocol CoreApiManaging {
    var appHandle: OpaquePointer { get }
    init(appHandle: OpaquePointer)
}
