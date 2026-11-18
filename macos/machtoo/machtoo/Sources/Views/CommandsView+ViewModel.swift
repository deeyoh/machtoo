//
//  CommandsView+ViewModel.swift
//  machtoo
//
//  Created by Ryan Dioneda on 11/18/26.
//

import Foundation

struct Command: Identifiable {
    let id: String
    var name: String
    var description: String
}

extension CommandsView {
    @Observable
    final class ViewModel {
        private let manager: CommandsManager
        var commands: [Command] = []
        
        init(manager: CommandsManager) {
            self.manager = manager
            self.commands = manager.getCommands()
        }
    }
}
