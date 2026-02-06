//
//  ImageListView.swift
//  container-manager
//
//  Image management view
//

import SwiftUI
import Foundation
import AppKit

struct ImageListView: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    let searchText: String
    
    @State private var images: [ContainerImageInfo] = []
    @State private var selectedImage: ContainerImageInfo.ID?
    @State private var isLoading = false
    @State private var showPullDialog = false
    @State private var showRemoveConfirmation = false
    @State private var filterDangling = false
    @State private var sortOption: SortOption = .name
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case size = "Size"
        case date = "Date"
    }
    
    private var filteredImages: [ContainerImageInfo] {
        var filtered = images
        
        // Apply search
        if !searchText.isEmpty {
            filtered = ContainerImageInfo.filter(filtered, repository: searchText)
        }
        
        // Apply dangling filter
        if filterDangling {
            filtered = ContainerImageInfo.filterDangling(filtered)
        }
        
        // Apply sort
        switch sortOption {
        case .name:
            filtered = ContainerImageInfo.sortByName(filtered)
        case .size:
            filtered = ContainerImageInfo.sortBySize(filtered)
        case .date:
            filtered = ContainerImageInfo.sortByDate(filtered)
        }
        
        return filtered
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button("Pull Image") {
                    showPullDialog = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Refresh") {
                    refreshImages()
                }
                .disabled(isLoading)
                
                Spacer()
                
                Toggle("Dangling Only", isOn: $filterDangling)
                
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .frame(width: 120)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            if isLoading && images.isEmpty {
                loadingView
            } else if filteredImages.isEmpty {
                emptyState
            } else {
                imageList
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(filteredImages.count) images")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !images.isEmpty {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("Total: \(ContainerImageInfo.formatSize(ContainerImageInfo.calculateTotalSize(images)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .onAppear {
            refreshImages()
        }
        .sheet(isPresented: $showPullDialog) {
            ImagePullDialog(onPull: { imageName, tag in
                pullImage(imageName, tag: tag)
            })
        }
    }
    
    // MARK: - Views
    
    private var imageList: some View {
        Table(filteredImages, selection: $selectedImage) {
            TableColumn("Repository") { image in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        if image.isDangling {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .imageScale(.small)
                        }
                        Text(image.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    if let tag = image.tag, !image.isDangling {
                        Text("Tag: \(tag)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Image ID") { image in
                Text(image.imageID.prefix(12))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 120)
            
            TableColumn("Size") { image in
                Text(image.size)
                    .font(.caption)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Actions") { image in
                HStack(spacing: 4) {
                    Button(action: { removeImage(image) }) {
                        Image(systemName: "trash")
                    }
                    .help("Remove image")
                    
                    Menu {
                        Button("Copy Name") {
                            copyToClipboard(image.displayName)
                        }
                        Button("Copy ID") {
                            copyToClipboard(image.imageID)
                        }
                        Divider()
                        Button("Tag Image...") {
                            // TODO: Show tag dialog
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            .width(60)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(searchText.isEmpty && !filterDangling ? "No Images" : "No Matching Images")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(searchText.isEmpty && !filterDangling ? "Pull an image to get started" : "Try adjusting your filters")
                .font(.body)
                .foregroundStyle(.secondary)
            
            if searchText.isEmpty && !filterDangling {
                Button("Pull Image") {
                    showPullDialog = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading images...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func refreshImages() {
        isLoading = true
        
        Task {
            if let fetchedImages = await containerMonitor.fetchImages() {
                await MainActor.run {
                    images = fetchedImages
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    images = []
                    isLoading = false
                }
            }
        }
    }
    
    private func pullImage(_ imageName: String, tag: String) {
        Task {
            let result = await containerMonitor.pullImage(imageName, tag: tag)
            
            if result?.success == true {
                // Refresh image list
                refreshImages()
            }
        }
    }
    
    private func removeImage(_ image: ContainerImageInfo) {
        Task {
            let result = await containerMonitor.removeImage(image.imageID)
            
            if result?.success == true {
                // Refresh image list
                refreshImages()
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Image Pull Dialog

struct ImagePullDialog: View {
    @Environment(\.dismiss) private var dismiss
    let onPull: (String, String) -> Void
    
    @State private var imageName = ""
    @State private var tag = "latest"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Pull Image")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Image Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("e.g., nginx, redis, postgres", text: $imageName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Tag")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("latest", text: $tag)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                
                Spacer()
                
                Button("Pull") {
                    onPull(imageName, tag)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(imageName.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// MARK: - Preview

#Preview {
    ImageListView(searchText: "")
        .environmentObject(ContainerSystemMonitor())
        .frame(width: 800, height: 600)
}

