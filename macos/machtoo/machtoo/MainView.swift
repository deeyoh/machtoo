//
//  MainView.swift
//  machtoo
//
//  Created by Ryan Dioneda on 10/26/26.
//

import SwiftUI

struct MainView: View {
    @State private var search = ""
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Search", text: $search)
                .textFieldStyle(.plain)
                .font(.title3)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            Text("My commands")
                .font(.title)
            
            Spacer()
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
