//
//  VolumeListView.swift
//  container-manager
//
//  Volume management view
//

import SwiftUI

struct VolumeListView: View {
    let searchText: String
    @State private var volumes: [VolumeInfo] = [] // Placeholder
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Volumes")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Volume management coming soon")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Button("Create Volume") {
                // TODO: Show create volume dialog
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Volume Info Model

struct VolumeInfo: Identifiable {
    let id = UUID()
    let name: String
    let driver: String
    let mountpoint: String
    let created: String
}

// MARK: - Preview

#Preview {
    VolumeListView(searchText: "")
        .frame(width: 800, height: 600)
}
