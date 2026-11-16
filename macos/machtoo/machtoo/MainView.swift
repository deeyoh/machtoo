//
//  MainView.swift
//  machtoo
//
//  Created by Ryan Dioneda on 10/26/26.
//

import SwiftUI
import AppKit

struct MainView: View {
    let commands: [CommandViewModel]

    @State private var search = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredCommands: [CommandViewModel] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return commands }

        return commands.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.description.localizedCaseInsensitiveContains(query)
                || $0.id.localizedCaseInsensitiveContains(query)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Search", text: $search)
                .focused($isSearchFocused)
                .textFieldStyle(.plain)
                .font(.title3)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if filteredCommands.isEmpty {
                ContentUnavailableView(
                    commands.isEmpty ? "No commands stored" : "No matching commands",
                    systemImage: "terminal",
                    description: Text(
                        commands.isEmpty
                            ? "Add a command file to your configuration directory."
                            : "Try another search."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(filteredCommands) { command in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(command.name)
                                    .font(.headline)
                                Text(command.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            // Temporary control to test normal application teardown.
            Button("Quit Machtoo") {
                NSApplication.shared.terminate(nil)
            }
        }
        .task {
            isSearchFocused = true
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .gesture(WindowDragGesture())
        }
    }
}

#Preview {
    // MainView(commands: [
    //     CommandViewModel(
    //         id: "example.rebase",
    //         name: "Rebase changes",
    //         description: "Move changes onto a different revision."
    //     )
    // ])
}
