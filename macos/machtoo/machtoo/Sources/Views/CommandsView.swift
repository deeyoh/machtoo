//
//  CommandsView.swift
//  machtoo
//
//  Created by Ryan Dioneda on 11/18/26.
//

import Foundation
import SwiftUI

struct CommandsView: View {
    @State private var viewModel: ViewModel
    @State private var search = ""
    @FocusState private var isSearchFocused: Bool
    
    init(manager: CommandsManager) {
        _viewModel = State(
            initialValue: ViewModel(manager: manager)
        )
    }
    
    private var filteredCommands: [Command] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.commands }
        
        return viewModel.commands.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.description.localizedCaseInsensitiveContains(query)
            || $0.id.localizedCaseInsensitiveContains(query)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            CommandSearchField(search: $search)
            
            CommandsContent(
                commands: filteredCommands,
                hasStoredCommands: !viewModel.commands.isEmpty
            )
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .task {
            isSearchFocused = true
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background{
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .gesture(WindowDragGesture())
        }
    }
}

private struct CommandsContent: View {
    let commands: [Command]
    let hasStoredCommands: Bool
    
    var body: some View {
        if commands.isEmpty {
            ContentUnavailableView(
                hasStoredCommands
                    ? "No matching commands"
                    : "No commands stored",
                systemImage: "terminal",
                description: Text(
                    hasStoredCommands
                    ? "Try another search."
                    : "Add a command file to your configuration directory."
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(commands) { command in
                CommandRow(command: command)
            }
            .scrollContentBackground(.hidden)
        }
    }
}

private struct CommandSearchField: View {
    @Binding var search: String
    
    var body: some View {
        TextField("Search commands...", text: $search)
            .textFieldStyle(.roundedBorder)
    }
}

private struct CommandRow: View {
    let command: Command
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(command.name)
                .font(.headline)
            Text(command.description)
                .foregroundStyle(.secondary)
        }
    }
}
