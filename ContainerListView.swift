//
//  ContainerListView.swift
//  container-manager
//
//  Comprehensive container list view for desktop app
//

import SwiftUI

struct ContainerListView: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    let searchText: String
    
    @State private var selectedContainerID: ContainerInfo.ID?
    @State private var viewMode: ViewMode = .list
    @State private var filterStatus: FilterStatus = .all
    @State private var sortOrder: SortOrder = .name
    @State private var showInspector = true
    
    private var selectedContainer: ContainerInfo? {
        guard let selectedContainerID else { return nil }
        return filteredContainers.first { $0.id == selectedContainerID }
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
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    // Filter status
                    Picker("Filter", selection: $filterStatus) {
                        ForEach(FilterStatus.allCases, id: \.self) { status in
                            Label(status.rawValue, systemImage: status.systemImage)
                                .tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    
                    Spacer()
                    
                    // Sort order
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
                    
                    // View mode
                    Picker("View Mode", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Image(systemName: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                    
                    // Toggle inspector
                    Button(action: { showInspector.toggle() }) {
                        Image(systemName: "sidebar.right")
                    }
                    .help("Toggle Inspector")
                }
                .padding()
                .background(.background)
                
                Divider()
                
                // Content
                if filteredContainers.isEmpty {
                    emptyStateView
                } else {
                    Group {
                        switch viewMode {
                        case .list:
                            listView
                        case .grid:
                            gridView
                        }
                    }
                }
            }
            .frame(minWidth: 400)
            
            // Inspector panel
            if showInspector {
                ContainerInspectorView(container: .constant(selectedContainer))
                    .frame(width: 300)
            }
        }
    }
    
    // MARK: - List View
    
    private var listView: some View {
        Table(filteredContainers, selection: $selectedContainerID) {
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
        .contextMenu(forSelectionType: ContainerInfo.self) { items in
            if items.count == 1, let container = items.first {
                ContainerContextMenu(container: container)
                    .environmentObject(containerMonitor)
            } else if items.count > 1 {
                Button("Start Selected (\(items.count))") {
                    // TODO: Batch operations
                }
                Button("Stop Selected (\(items.count))") {
                    // TODO: Batch operations
                }
                Divider()
                Button("Remove Selected (\(items.count))", role: .destructive) {
                    // TODO: Batch operations
                }
            }
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
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
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
        .padding()
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
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(color)
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
    
    @State private var isHovered = false
    
    private var isRunning: Bool {
        let status = container.status.lowercased()
        return status == "running" || status == "up" || status.contains("running")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: isRunning ? "checkmark.circle.fill" : "stop.circle.fill")
                    .foregroundStyle(isRunning ? .green : .red)
                    .imageScale(.large)
                
                Spacer()
                
                if isHovered || isSelected {
                    ContainerActionsMenu(container: container)
                        .environmentObject(containerMonitor)
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
        .padding()
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
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
