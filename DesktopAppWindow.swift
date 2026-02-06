//
//  DesktopAppWindow.swift
//  container-manager
//
//  Desktop application main window
//

import SwiftUI

struct DesktopAppWindow: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    @State private var selectedSection: SidebarSection = .containers
    @State private var searchText = ""
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(selectedSection: $selectedSection)
        } detail: {
            // Main content area
            DetailContentView(section: selectedSection, searchText: $searchText)
                .environmentObject(containerMonitor)
        }
        .navigationTitle("Container Manager")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Search
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                
                Spacer()
                
                // Service status indicator
                ServiceStatusIndicator()
                    .environmentObject(containerMonitor)
                
                // Refresh button
                Button(action: {
                    containerMonitor.checkContainerStatus()
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(containerMonitor.isOperating)
            }
        }
    }
}

// MARK: - Sidebar Section Enum

enum SidebarSection: String, CaseIterable, Identifiable {
    case containers = "Containers"
    case images = "Images"
    case volumes = "Volumes"
    case networks = "Networks"
    case stats = "Stats"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .containers: return "shippingbox.fill"
        case .images: return "square.stack.3d.up.fill"
        case .volumes: return "externaldrive.fill"
        case .networks: return "network"
        case .stats: return "chart.xyaxis.line"
        case .settings: return "gear"
        }
    }
    
    var badge: Int? {
        // Can be used to show counts
        return nil
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selectedSection: SidebarSection
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    
    var body: some View {
        List(selection: $selectedSection) {
            Section("Management") {
                ForEach(SidebarSection.allCases.filter { $0 != .stats && $0 != .settings }) { section in
                    NavigationLink(value: section) {
                        Label {
                            HStack {
                                Text(section.rawValue)
                                Spacer()
                                if let badge = sectionBadge(for: section) {
                                    Text("\(badge)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: section.icon)
                        }
                    }
                }
            }
            
            Section("Monitoring") {
                NavigationLink(value: SidebarSection.stats) {
                    Label("Stats", systemImage: SidebarSection.stats.icon)
                }
            }
            
            Section {
                NavigationLink(value: SidebarSection.settings) {
                    Label("Settings", systemImage: SidebarSection.settings.icon)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        .listStyle(.sidebar)
    }
    
    private func sectionBadge(for section: SidebarSection) -> Int? {
        switch section {
        case .containers:
            return containerMonitor.containers.isEmpty ? nil : containerMonitor.containers.count
        default:
            return nil
        }
    }
}

// MARK: - Detail Content View

struct DetailContentView: View {
    let section: SidebarSection
    @Binding var searchText: String
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    
    var body: some View {
        Group {
            switch section {
            case .containers:
                ContainerListView(searchText: searchText)
            case .images:
                ImageListView(searchText: searchText)
            case .volumes:
                VolumeListView(searchText: searchText)
            case .networks:
                NetworkListView(searchText: searchText)
            case .stats:
                StatsView()
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

// MARK: - Service Status Indicator

struct ServiceStatusIndicator: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    
    var body: some View {
        Menu {
            Button(containerMonitor.status == .running ? "Stop Service" : "Start Service") {
                if containerMonitor.status == .running {
                    containerMonitor.stopContainerService()
                } else {
                    containerMonitor.startContainerService()
                }
            }
            .disabled(containerMonitor.isOperating || containerMonitor.status == .error)
            
            Divider()
            
            Text("Last updated: \(containerMonitor.lastUpdated, style: .relative) ago")
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(containerMonitor.status.color)
                    .frame(width: 8, height: 8)
                
                Text(containerMonitor.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
        }
        .menuIndicator(.hidden)
    }
}

// MARK: - Previews

#Preview("Desktop Window") {
    DesktopAppWindow()
        .environmentObject(ContainerSystemMonitor())
        .frame(width: 1000, height: 700)
}

#Preview("Sidebar") {
    NavigationSplitView {
        SidebarView(selectedSection: .constant(.containers))
            .environmentObject(ContainerSystemMonitor())
    } detail: {
        Text("Detail View")
    }
}
