//
//  NetworkListView.swift
//  container-manager
//
//  Network management view
//

import SwiftUI

struct NetworkListView: View {
    let searchText: String
    @State private var networks: [NetworkInfo] = [] // Placeholder
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Networks")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Network management coming soon")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Button("Create Network") {
                // TODO: Show create network dialog
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Network Info Model

struct NetworkInfo: Identifiable {
    let id = UUID()
    let name: String
    let driver: String
    let scope: String
    let subnet: String?
}

// MARK: - Preview

#Preview {
    NetworkListView(searchText: "")
        .frame(width: 800, height: 600)
}
