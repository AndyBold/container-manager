//
//  ContainerListView.swift
//  container-manager
//
//  Comprehensive container list view for desktop app
//

import SwiftUI
import AppKit

struct ContainerListView: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    let searchText: String
    
    @AppStorage("defaultViewMode") private var defaultViewMode = "list"
    @AppStorage("showInspectorPanel") private var defaultShowInspector = true
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("compactMode") private var compactMode = false
    
    @State private var selectedContainerID: ContainerInfo.ID?
    @State private var selectedContainerIDs: Set<ContainerInfo.ID> = []
    @State private var viewMode: ViewMode = .list
    @State private var filterStatus: FilterStatus = .all
    @State private var sortOrder: SortOrder = .name
    @State private var showInspector = true
    @State private var showBatchConfirmation = false
    @State private var batchOperation: BatchOperation?
    @State private var isBatchOperating = false
    @State private var showingCreationWizard = false
    
    // Effective reduce motion (app OR system)
    private var effectiveReduceMotion: Bool {
        reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    
    // Animation based on preferences
    private var defaultAnimation: Animation? {
        guard enableAnimations else { return nil }
        return effectiveReduceMotion ? .linear(duration: 0.2) : .smooth
    }
    
    private var springAnimation: Animation? {
        guard enableAnimations else { return nil }
        return effectiveReduceMotion ? .linear(duration: 0.2) : .spring(response: 0.3, dampingFraction: 0.7)
    }
    
    private var selectedContainer: ContainerInfo? {
        guard let selectedContainerID else { return nil }
        return filteredContainers.first { $0.id == selectedContainerID }
    }
    
    private var selectedContainers: [ContainerInfo] {
        filteredContainers.filter { selectedContainerIDs.contains($0.id) }
    }
    
    enum BatchOperation {
        case start
        case stop
        case restart
        case remove
        
        var title: String {
            switch self {
            case .start: return "Start Containers"
            case .stop: return "Stop Containers"
            case .restart: return "Restart Containers"
            case .remove: return "Remove Containers"
            }
        }
        
        var message: String {
            switch self {
            case .start: return "Are you sure you want to start the selected containers?"
            case .stop: return "Are you sure you want to stop the selected containers?"
            case .restart: return "Are you sure you want to restart the selected containers?"
            case .remove: return "Are you sure you want to remove the selected containers? This action cannot be undone."
            }
        }
        
        var confirmButtonText: String {
            switch self {
            case .start: return "Start"
            case .stop: return "Stop"
            case .restart: return "Restart"
            case .remove: return "Remove"
            }
        }
        
        var isDestructive: Bool {
            self == .remove
        }
    }
    
    enum ViewMode: String, CaseIterable {
        case list = "List"
        case grid = "Grid"
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            }
        }
    }
    
    enum FilterStatus: String, CaseIterable {
        case all = "All"
        case running = "Running"
        case stopped = "Stopped"
        
        var systemImage: String {
            switch self {
            case .all: return "circle.grid.3x3"
            case .running: return "checkmark.circle.fill"
            case .stopped: return "stop.circle.fill"
            }
        }
    }
    
    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case status = "Status"
        case created = "Created"
        
        var systemImage: String {
            switch self {
            case .name: return "textformat"
            case .status: return "circle.fill"
            case .created: return "clock"
            }
        }
    }
    
    private var filteredContainers: [ContainerInfo] {
        var containers = containerMonitor.containers
        
        // Apply search filter
        if !searchText.isEmpty {
            containers = containers.filter { container in
                container.name.localizedCaseInsensitiveContains(searchText) ||
                (container.image?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply status filter
        switch filterStatus {
        case .all:
            break
        case .running:
            containers = containers.filter { container in
                let status = container.status.lowercased()
                return status == "running" || status == "up" || status.contains("running")
            }
        case .stopped:
            containers = containers.filter { container in
                let status = container.status.lowercased()
                return status == "stopped" || status == "exited" || status.contains("exit")
            }
        }
        
        // Apply sort
        switch sortOrder {
        case .name:
            containers.sort { $0.name < $1.name }
        case .status:
            containers.sort { $0.status < $1.status }
        case .created:
            containers.sort { ($0.created ?? "") < ($1.created ?? "") }
        }
        
        return containers
    }
    
    var body: some View {
        HSplitView {
            // Main container list
            VStack(spacing: compactMode ? 0 : 0) {
                // Batch actions toolbar (appears when items are selected)
                if !selectedContainerIDs.isEmpty {
                    batchActionsToolbar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Toolbar
                HStack(spacing: compactMode ? 12 : 16) {
                    // Filter status
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Filter Items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Filter", selection: $filterStatus) {
                            ForEach(FilterStatus.allCases, id: \.self) { status in
                                Label(status.rawValue, systemImage: status.systemImage)
                                    .tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 200)
                    }

                    Spacer()

                    // Sort order
                    VStack(alignment: .leading, spacing: 4) {
                        Text(" ")
                            .font(.caption)
                        Menu {
                            Picker("Sort By", selection: $sortOrder) {
                                ForEach(SortOrder.allCases, id: \.self) { order in
                                    Label(order.rawValue, systemImage: order.systemImage)
                                        .tag(order)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                        .frame(width: 80)
                    }

                    // View mode
                    VStack(alignment: .leading, spacing: 4) {
                        Text("View Mode")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("View Mode", selection: $viewMode) {
                            ForEach(ViewMode.allCases, id: \.self) { mode in
                                Image(systemName: mode.icon)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 80)
                    }

                    // Create container
                    VStack(alignment: .leading, spacing: 4) {
                        Text(" ")
                            .font(.caption)
                        Button(action: { showingCreationWizard = true }) {
                            Label("New", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Create New Container")
                    }
                    
                    // Toggle inspector
                    VStack(alignment: .leading, spacing: 4) {
                        Text(" ")
                            .font(.caption)
                        Button(action: { showInspector.toggle() }) {
                            Image(systemName: "sidebar.right")
                        }
                        .help("Toggle Inspector")
                    }
                }
                .padding()
                .background(.background)
                
                Divider()
                
                // Content
                if filteredContainers.isEmpty {
                    emptyStateView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    Group {
                        switch viewMode {
                        case .list:
                            listView
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        case .grid:
                            gridView
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .animation(defaultAnimation, value: viewMode)
                }
            }
            .frame(minWidth: 400)
            
            // Inspector panel
            if showInspector {
                ContainerInspectorView(container: .constant(selectedContainer))
                    .frame(width: 300)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(springAnimation, value: showInspector)
        .animation(defaultAnimation, value: filteredContainers.count)
        .onAppear {
            // Initialize state from settings
            viewMode = ViewMode(rawValue: defaultViewMode) ?? .list
            showInspector = defaultShowInspector
        }
        .onChange(of: viewMode) { _, newValue in
            // Persist view mode changes
            defaultViewMode = newValue.rawValue
        }
        .onChange(of: showInspector) { _, newValue in
            // Persist inspector visibility changes
            defaultShowInspector = newValue
        }
        .alert(batchOperation?.title ?? "Batch Operation", isPresented: $showBatchConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button(batchOperation?.confirmButtonText ?? "Confirm", role: batchOperation?.isDestructive == true ? .destructive : nil) {
                if let operation = batchOperation {
                    performBatchOperation(operation)
                }
            }
        } message: {
            Text(batchOperation?.message ?? "")
        }
        .sheet(isPresented: $showingCreationWizard) {
            ContainerCreationView()
                .environmentObject(containerMonitor)
        }
    }
    
    // MARK: - Batch Actions Toolbar
    
    private var batchActionsToolbar: some View {
        HStack(spacing: compactMode ? 12 : 16) {
            // Selection count
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                Text("\(selectedContainerIDs.count) selected")
                    .font(.headline)
            }
            
            Spacer()
            
            // Batch actions
            if isBatchOperating {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .controlSize(.small)
                    Text("Processing...")
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    Button(action: {
                        batchOperation = .start
                        showBatchConfirmation = true
                    }) {
                        Label("Start", systemImage: "play.fill")
                    }
                    .help("Start selected containers")
                    
                    Button(action: {
                        batchOperation = .stop
                        showBatchConfirmation = true
                    }) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .help("Stop selected containers")
                    
                    Button(action: {
                        batchOperation = .restart
                        showBatchConfirmation = true
                    }) {
                        Label("Restart", systemImage: "arrow.clockwise")
                    }
                    .help("Restart selected containers")
                    
                    Divider()
                        .frame(height: 20)
                    
                    Button(action: {
                        batchOperation = .remove
                        showBatchConfirmation = true
                    }) {
                        Label("Remove", systemImage: "trash")
                    }
                    .foregroundStyle(.red)
                    .help("Remove selected containers")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            
            // Clear selection
            Button(action: {
                selectedContainerIDs.removeAll()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Clear selection")
        }
        .padding(.horizontal)
        .padding(.vertical, compactMode ? 8 : 12)
        .background(.blue.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(.blue.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - List View
    
    private var listView: some View {
        Table(filteredContainers, selection: $selectedContainerIDs) {
            TableColumn("Name") { container in
                HStack(spacing: 8) {
                    Image(systemName: statusIcon(for: container))
                        .foregroundStyle(statusColor(for: container))
                        .imageScale(.medium)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(container.name)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if let image = container.image {
                            Text(image)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Status") { container in
                StatusBadge(status: container.status)
            }
            .width(min: 100, ideal: 120)
            
            TableColumn("Ports/Address") { container in
                if let ports = container.ports {
                    Text(ports)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("-")
                        .foregroundStyle(.tertiary)
                }
            }
            .width(min: 120, ideal: 150)
            
            TableColumn("Created") { container in
                if let created = container.created {
                    Text(created)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("-")
                        .foregroundStyle(.tertiary)
                }
            }
            .width(min: 100, ideal: 120)
            
            TableColumn("Actions") { container in
                ContainerActionsMenu(container: container)
                    .environmentObject(containerMonitor)
            }
            .width(40)
        }
        .contextMenu(forSelectionType: ContainerInfo.ID.self) { items in
            if items.count == 1 {
                if let container = filteredContainers.first(where: { items.contains($0.id) }) {
                    ContainerContextMenu(container: container)
                        .environmentObject(containerMonitor)
                }
            } else if items.count > 1 {
                Button("Start Selected (\(items.count))") {
                    batchOperation = .start
                    showBatchConfirmation = true
                }
                Button("Stop Selected (\(items.count))") {
                    batchOperation = .stop
                    showBatchConfirmation = true
                }
                Button("Restart Selected (\(items.count))") {
                    batchOperation = .restart
                    showBatchConfirmation = true
                }
                Divider()
                Button("Remove Selected (\(items.count))", role: .destructive) {
                    batchOperation = .remove
                    showBatchConfirmation = true
                }
            }
        }
        .onChange(of: selectedContainerIDs) { _, newValue in
            // Update single selection for inspector
            selectedContainerID = newValue.first
        }
    }
    
    // MARK: - Grid View
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 250, maximum: 300), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredContainers) { container in
                    ContainerCardView(
                        container: container,
                        isSelected: selectedContainerID == container.id
                    )
                    .environmentObject(containerMonitor)
                    .onTapGesture {
                        selectedContainerID = container.id
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: compactMode ? 12 : 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: compactMode ? 50 : 60))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: enableAnimations ? .default : .default.speed(0))
            
            Text(emptyStateTitle)
                .font(.title2)
                .fontWeight(.medium)
            
            Text(emptyStateMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if containerMonitor.status != .running {
                Button("Start Container Service") {
                    containerMonitor.startContainerService()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(compactMode ? 16 : 24)
    }
    
    private var emptyStateTitle: String {
        if containerMonitor.status != .running {
            return "Service Not Running"
        } else if !searchText.isEmpty {
            return "No Containers Found"
        } else {
            return "No Containers"
        }
    }
    
    private var emptyStateMessage: String {
        if containerMonitor.status != .running {
            return "Start the container service to view and manage containers"
        } else if !searchText.isEmpty {
            return "No containers match your search criteria"
        } else {
            return "Create or import a container to get started"
        }
    }
    
    // MARK: - Batch Operations
    
    private func performBatchOperation(_ operation: BatchOperation) {
        let containers = selectedContainers
        guard !containers.isEmpty else { return }
        
        isBatchOperating = true
        
        Task {
            var successCount = 0
            var failureCount = 0
            
            for container in containers {
                let success: Bool
                switch operation {
                case .start:
                    success = await containerMonitor.startContainer(named: container.name)
                case .stop:
                    success = await containerMonitor.stopContainer(named: container.name)
                case .restart:
                    success = await containerMonitor.restartContainer(named: container.name)
                case .remove:
                    success = await containerMonitor.removeContainer(named: container.name)
                }
                
                if success {
                    successCount += 1
                } else {
                    failureCount += 1
                    print("Failed to \(operation.confirmButtonText.lowercased()) container \(container.name)")
                }
                
                // Small delay between operations to avoid overwhelming the system
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            await MainActor.run {
                isBatchOperating = false
                selectedContainerIDs.removeAll()
                
                // Show notification with results
                if failureCount == 0 {
                    print("✓ Successfully \(operation.confirmButtonText.lowercased())ed \(successCount) container(s)")
                } else {
                    print("⚠ Completed with \(successCount) success(es) and \(failureCount) failure(s)")
                }
            }
            
            // Refresh container list
            await containerMonitor.checkAppleContainerStatus()
        }
    }
    
    // MARK: - Helpers
    
    private func statusIcon(for container: ContainerInfo) -> String {
        switch container.status.lowercased() {
        case let status where status == "running" || status == "up" || status.contains("running"):
            return "checkmark.circle.fill"
        case let status where status == "exited" || status == "stopped" || status.contains("exit"):
            return "stop.circle.fill"
        case "paused":
            return "pause.circle.fill"
        case "restarting":
            return "arrow.clockwise.circle.fill"
        default:
            return "circle.fill"
        }
    }
    
    private func statusColor(for container: ContainerInfo) -> Color {
        switch container.status.lowercased() {
        case let status where status == "running" || status == "up" || status.contains("running"):
            return .green
        case let status where status == "exited" || status == "stopped" || status.contains("exit"):
            return .red
        case "paused":
            return .orange
        case "restarting":
            return .yellow
        default:
            return .secondary
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String
    
    @AppStorage("enableAnimations") private var enableAnimations = true
    
    private var color: Color {
        switch status.lowercased() {
        case let s where s == "running" || s == "up" || s.contains("running"):
            return .green
        case let s where s == "exited" || s == "stopped" || s.contains("exit"):
            return .red
        case "paused":
            return .orange
        case "restarting":
            return .yellow
        default:
            return .secondary
        }
    }
    
    private var isRunning: Bool {
        let s = status.lowercased()
        return s == "running" || s == "up" || s.contains("running")
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if isRunning {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .opacity(enableAnimations ? 0.8 : 1.0)
                    .symbolEffect(.pulse, options: enableAnimations ? .repeating : .default.speed(0))
            }
            
            Text(status.capitalized)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(color.opacity(0.15), in: Capsule())
    }
}

// MARK: - Container Card View (for Grid)

struct ContainerCardView: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    let container: ContainerInfo
    let isSelected: Bool
    
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("compactMode") private var compactMode = false
    
    @State private var isHovered = false
    
    // Effective reduce motion (app OR system)
    private var effectiveReduceMotion: Bool {
        reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    
    // Animation based on preferences
    private var hoverAnimation: Animation? {
        guard enableAnimations else { return nil }
        return effectiveReduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.2)
    }
    
    private var isRunning: Bool {
        let status = container.status.lowercased()
        return status == "running" || status == "up" || status.contains("running")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: compactMode ? 8 : 12) {
            // Header
            HStack {
                Image(systemName: isRunning ? "checkmark.circle.fill" : "stop.circle.fill")
                    .foregroundStyle(isRunning ? .green : .red)
                    .imageScale(.large)
                    .symbolEffect(.pulse, options: isRunning && enableAnimations ? .repeating : .default.speed(0))
                
                Spacer()
                
                if isHovered || isSelected {
                    ContainerActionsMenu(container: container)
                        .environmentObject(containerMonitor)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            
            // Container name
            Text(container.name)
                .font(.headline)
                .lineLimit(1)
            
            // Image
            if let image = container.image {
                Text(image)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Status
            HStack {
                StatusBadge(status: container.status)
                
                Spacer()
                
                if let ports = container.ports {
                    Label(ports, systemImage: "network")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(compactMode ? 12 : 16)
        .frame(height: compactMode ? 140 : 160)
        .background(
            RoundedRectangle(cornerRadius: compactMode ? 10 : 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compactMode ? 10 : 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered && enableAnimations ? (effectiveReduceMotion ? 1.01 : 1.02) : 1.0)
        .animation(hoverAnimation, value: isHovered)
        .animation(hoverAnimation, value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview("Container List - List View") {
    let monitor = ContainerSystemMonitor()
    
    return ContainerListView(searchText: "")
        .environmentObject(monitor)
        .frame(width: 900, height: 600)
}

#Preview("Container List - Empty") {
    let monitor = ContainerSystemMonitor()
    
    return ContainerListView(searchText: "")
        .environmentObject(monitor)
        .frame(width: 900, height: 600)
}
