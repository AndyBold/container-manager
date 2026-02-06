//
//  VolumeListView.swift
//  container-manager
//
//  Volume management view
//

import SwiftUI
import Foundation

struct VolumeListView: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    let searchText: String
    
    @State private var volumes: [VolumeInfo] = []
    @State private var selectedVolume: VolumeInfo.ID?
    @State private var isLoading = false
    @State private var showCreateDialog = false
    @State private var showRemoveConfirmation = false
    @State private var volumeToRemove: VolumeInfo?
    @State private var filterUnused = false
    @State private var sortOption: SortOption = .name
    @State private var volumeUsage: [String: VolumeUsageInfo] = [:]
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case driver = "Driver"
        case date = "Created"
    }
    
    private var filteredVolumes: [VolumeInfo] {
        var filtered = volumes
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = VolumeInfo.filter(filtered, name: searchText)
        }
        
        // Apply unused filter
        if filterUnused {
            filtered = VolumeInfo.filterUnused(filtered)
        }
        
        // Apply sorting
        switch sortOption {
        case .name:
            filtered = VolumeInfo.sortByName(filtered)
        case .driver:
            filtered = filtered.sorted { $0.driver < $1.driver }
        case .date:
            filtered = VolumeInfo.sortByDate(filtered)
        }
        
        return filtered
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Button(action: { showCreateDialog = true }) {
                    Label("Create Volume", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: { pruneVolumes() }) {
                    Label("Prune Unused", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Toggle(isOn: $filterUnused) {
                    Text("Unused Only")
                }
                .toggleStyle(.switch)
                
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                
                Button(action: refreshVolumes) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content
            if isLoading && volumes.isEmpty {
                loadingView
            } else if filteredVolumes.isEmpty {
                emptyView
            } else {
                volumeListView
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(filteredVolumes.count) volume\(filteredVolumes.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !filterUnused && !volumes.isEmpty {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("\(VolumeInfo.filterUnused(volumes).count) unused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .sheet(isPresented: $showCreateDialog) {
            VolumeCreateDialog { options in
                createVolume(options)
            }
        }
        .alert("Remove Volume", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if let volume = volumeToRemove {
                    removeVolume(volume)
                }
            }
        } message: {
            if let volume = volumeToRemove {
                if volume.isInUse {
                    Text("Volume '\(volume.name)' is in use by \(volume.containerCount) container(s). Are you sure you want to remove it?")
                } else {
                    Text("Are you sure you want to remove volume '\(volume.name)'? This action cannot be undone.")
                }
            }
        }
        .onAppear {
            refreshVolumes()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading volumes...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(searchText.isEmpty ? (filterUnused ? "No Unused Volumes" : "No Volumes") : "No Matching Volumes")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(searchText.isEmpty ? (filterUnused ? "All volumes are currently in use." : "No volumes have been created yet.") : "No volumes match your search.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if !filterUnused && searchText.isEmpty {
                Button("Create Volume") {
                    showCreateDialog = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var volumeListView: some View {
        Table(filteredVolumes, selection: $selectedVolume) {
            TableColumn("Name") { volume in
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.fill")
                        .foregroundStyle(volume.isInUse ? .blue : .secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(volume.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if volume.isInUse {
                            Text("\(volume.containerCount) container\(volume.containerCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .width(min: 150, ideal: 250)
            
            TableColumn("Driver") { volume in
                HStack {
                    Image(systemName: volume.isLocalDriver ? "internaldrive" : "externaldrive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(volume.driver)
                }
                .font(.caption)
            }
            .width(min: 80, ideal: 120)
            
            TableColumn("Mountpoint") { volume in
                Text(volume.mountpoint.isEmpty ? "—" : volume.mountpoint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 150, ideal: 300)
            
            TableColumn("Scope") { volume in
                Text(volume.scope)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80)
            
            TableColumn("Actions") { volume in
                HStack(spacing: 4) {
                    Button(action: { confirmRemove(volume) }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Remove volume")
                    
                    Menu {
                        Button(action: { inspectVolume(volume) }) {
                            Label("Inspect", systemImage: "info.circle")
                        }
                        
                        Button(action: { copyToClipboard(volume.name) }) {
                            Label("Copy Name", systemImage: "doc.on.doc")
                        }
                        
                        if !volume.mountpoint.isEmpty {
                            Button(action: { copyToClipboard(volume.mountpoint) }) {
                                Label("Copy Mountpoint", systemImage: "doc.on.doc")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 20)
                }
            }
            .width(60)
        }
        .contextMenu(forSelectionType: VolumeInfo.ID.self) { selection in
            if selection.count == 1, let volumeID = selection.first,
               let volume = volumes.first(where: { $0.id == volumeID }) {
                Button("Inspect") {
                    inspectVolume(volume)
                }
                
                Button("Remove", role: .destructive) {
                    confirmRemove(volume)
                }
                
                Divider()
                
                Button("Copy Name") {
                    copyToClipboard(volume.name)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func refreshVolumes() {
        isLoading = true
        
        Task {
            if let fetchedVolumes = await containerMonitor.fetchVolumes() {
                // Fetch usage for each volume
                var usage: [String: VolumeUsageInfo] = [:]
                for volume in fetchedVolumes {
                    if let volumeUsage = await containerMonitor.getVolumeUsage(volume.name) {
                        usage[volume.name] = volumeUsage
                    }
                }
                
                await MainActor.run {
                    // Update volumes with container counts
                    volumes = fetchedVolumes.map { volume in
                        let updated = volume
                        if let usageInfo = usage[volume.name] {
                            return VolumeInfo(
                                name: volume.name,
                                driver: volume.driver,
                                mountpoint: volume.mountpoint,
                                scope: volume.scope,
                                created: volume.created,
                                size: volume.size,
                                labels: volume.labels,
                                containerCount: usageInfo.containers.count
                            )
                        }
                        return updated
                    }
                    volumeUsage = usage
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    volumes = []
                    isLoading = false
                }
            }
        }
    }
    
    private func createVolume(_ options: VolumeCreateOptions) {
        Task {
            let result = await containerMonitor.createVolume(options: options)
            
            if result?.success == true {
                await MainActor.run {
                    showCreateDialog = false
                    refreshVolumes()
                }
            }
        }
    }
    
    private func confirmRemove(_ volume: VolumeInfo) {
        volumeToRemove = volume
        showRemoveConfirmation = true
    }
    
    private func removeVolume(_ volume: VolumeInfo) {
        Task {
            let result = await containerMonitor.removeVolume(volume.name, force: volume.isInUse)
            
            if result?.success == true {
                refreshVolumes()
            }
        }
    }
    
    private func pruneVolumes() {
        Task {
            let result = await containerMonitor.pruneVolumes()
            
            if result?.success == true {
                refreshVolumes()
            }
        }
    }
    
    private func inspectVolume(_ volume: VolumeInfo) {
        Task {
            if let details = await containerMonitor.inspectVolume(volume.name) {
                print("Volume details: \(details)")
                // TODO: Show inspector sheet
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Volume Create Dialog

struct VolumeCreateDialog: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (VolumeCreateOptions) -> Void
    
    @State private var volumeName = ""
    @State private var driver = "local"
    @State private var showAdvanced = false
    @State private var optionKeys: [String] = [""]
    @State private var optionValues: [String] = [""]
    @State private var labelKeys: [String] = [""]
    @State private var labelValues: [String] = [""]
    @State private var showValidationError = false
    @State private var validationMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Volume")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Volume Name")
                            .font(.headline)
                        TextField("my-volume", text: $volumeName)
                            .textFieldStyle(.roundedBorder)
                        Text("Alphanumeric characters, hyphens, and underscores only")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Driver
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Driver")
                            .font(.headline)
                        Picker("Driver", selection: $driver) {
                            Text("local").tag("local")
                            Text("nfs").tag("nfs")
                            Text("tmpfs").tag("tmpfs")
                        }
                        .pickerStyle(.segmented)
                        Text("Storage driver for the volume")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Advanced Options
                    DisclosureGroup("Advanced Options", isExpanded: $showAdvanced) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Driver Options
                            Text("Driver Options")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(0..<optionKeys.count, id: \.self) { index in
                                HStack {
                                    TextField("Key", text: Binding(
                                        get: { optionKeys[index] },
                                        set: { optionKeys[index] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    
                                    TextField("Value", text: Binding(
                                        get: { optionValues[index] },
                                        set: { optionValues[index] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    
                                    Button(action: { removeOption(at: index) }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            Button(action: addOption) {
                                Label("Add Option", systemImage: "plus.circle")
                            }
                            .buttonStyle(.link)
                            
                            Divider()
                            
                            // Labels
                            Text("Labels")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(0..<labelKeys.count, id: \.self) { index in
                                HStack {
                                    TextField("Key", text: Binding(
                                        get: { labelKeys[index] },
                                        set: { labelKeys[index] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    
                                    TextField("Value", text: Binding(
                                        get: { labelValues[index] },
                                        set: { labelValues[index] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    
                                    Button(action: { removeLabel(at: index) }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            Button(action: addLabel) {
                                Label("Add Label", systemImage: "plus.circle")
                            }
                            .buttonStyle(.link)
                        }
                        .padding(.top, 12)
                    }
                    
                    if showValidationError {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create") {
                    createVolume()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(volumeName.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }
    
    private func addOption() {
        optionKeys.append("")
        optionValues.append("")
    }
    
    private func removeOption(at index: Int) {
        guard optionKeys.count > 1 else { return }
        optionKeys.remove(at: index)
        optionValues.remove(at: index)
    }
    
    private func addLabel() {
        labelKeys.append("")
        labelValues.append("")
    }
    
    private func removeLabel(at index: Int) {
        guard labelKeys.count > 1 else { return }
        labelKeys.remove(at: index)
        labelValues.remove(at: index)
    }
    
    private func createVolume() {
        // Validate name
        guard VolumeInfo.validateName(volumeName) else {
            validationMessage = "Invalid volume name. Use only alphanumeric characters, hyphens, and underscores."
            showValidationError = true
            return
        }
        
        // Build options dictionary
        var options: [String: String]?
        let nonEmptyOptions = zip(optionKeys, optionValues)
            .filter { !$0.0.isEmpty && !$0.1.isEmpty }
        if !nonEmptyOptions.isEmpty {
            options = Dictionary(uniqueKeysWithValues: nonEmptyOptions)
        }
        
        // Build labels dictionary
        var labels: [String: String]?
        let nonEmptyLabels = zip(labelKeys, labelValues)
            .filter { !$0.0.isEmpty && !$0.1.isEmpty }
        if !nonEmptyLabels.isEmpty {
            labels = Dictionary(uniqueKeysWithValues: nonEmptyLabels)
        }
        
        let createOptions = VolumeCreateOptions(
            name: volumeName,
            driver: driver,
            options: options,
            labels: labels
        )
        
        onCreate(createOptions)
    }
}

// MARK: - Preview

#Preview {
    VolumeListView(searchText: "")
        .environmentObject(ContainerSystemMonitor())
        .frame(width: 1000, height: 700)
}
