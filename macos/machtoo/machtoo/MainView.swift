//
//  MainView.swift
//  machtoo
//
//  Created by Ryan Dioneda on 10/26/26.
//

import SwiftUI
import MachtooKit

struct MainView: View {
    @State private var search = ""
    @FocusState private var isSearchFocused: Bool
    @State private var result: Int32?
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Search", text: $search)
                .focused($isSearchFocused)
                .textFieldStyle(.plain)
                .font(.title3)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: search) { _, newValue in
                    guard let number = Int32(newValue) else {
                        result = nil
                        return
                    }
                    result = machtoo_add(number, 20)
                }
            
            Spacer()
            
            if let result {
                Text("Result: \(result)")
                    .font(.title)
            }
            
            Spacer()
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
    MainView()
}
