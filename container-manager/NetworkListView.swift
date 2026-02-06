//
//  NetworkListView.swift
//  container-manager
//
//  Network management view
//

import SwiftUI
import Foundation

struct NetworkListView: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    let searchText: String
    
    @State private var networks: [NetworkInfo] = []
    @State private var selectedNetwork: NetworkInfo.ID?
    @State private var isLoading = false
    @State private var showCreateDialog = false
    @State private var showRemoveConfirmation = false
    @State private var networkToRemove: NetworkInfo?
    @State private var filterUserDefined = false
    @State private var sortOption: SortOption = .name
    @State private var showInspector = false
    @State private var inspectedNetwork: NetworkInfo?
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case driver = "Driver"
        case date = "Created"
    }
    
    private var filteredNetworks: [NetworkInfo] {
        var filtered = networks
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = NetworkInfo.filter(filtered, name: searchText)
        }
        
        // Apply user-defined filter
        if filterUserDefined {
            filtered = NetworkInfo.filterUserDefined(filtered)
        }
        
        // Apply sorting
        switch sortOption {
        case .name:
            filtered = NetworkInfo.sortByName(filtered)
        case .driver:
            filtered = NetworkInfo.sortByDriver(filtered)
        case .date:
            filtered = NetworkInfo.sortByDate(filtered)
        }
        
        return filtered
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Button(action: { showCreateDialog = true }) {
                    Label("Create Network", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: { pruneNetworks() }) {
                    Label("Prune Unused", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Toggle(isOn: $filterUserDefined) {
                    Text("User-Defined Only")
                }
                .toggleStyle(.switch)
                
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                
                Button(action: refreshNetworks) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content
            if isLoading && networks.isEmpty {
                loadingView
            } else if filteredNetworks.isEmpty {
                emptyView
            } else {
                networkListView
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(filteredNetworks.count) network\(filteredNetworks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !filterUserDefined && !networks.isEmpty {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("\(NetworkInfo.filterUserDefined(networks).count) user-defined")
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
            NetworkCreateDialog { options in
                createNetwork(options)
            }
        }
        .sheet(isPresented: $showInspector) {
            if let network = inspectedNetwork {
                NetworkInspectorSheet(network: network)
            }
        }
        .alert("Remove Network", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if let network = networkToRemove {
                    removeNetwork(network)
                }
            }
        } message: {
            if let network = networkToRemove {
                if network.isDefaultNetwork {
                    Text("Cannot remove default network '\(network.name)'. This is a system network.")
                } else if network.containerCount > 0 {
                    Text("Network '\(network.name)' is in use by \(network.containerCount) container(s). Are you sure you want to remove it?")
                } else {
                    Text("Are you sure you want to remove network '\(network.name)'? This action cannot be undone.")
                }
            }
        }
        .onAppear {
            refreshNetworks()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading networks...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(searchText.isEmpty ? (filterUserDefined ? "No User-Defined Networks" : "No Networks") : "No Matching Networks")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(searchText.isEmpty ? (filterUserDefined ? "All networks are system default networks." : "No networks have been created yet.") : "No networks match your search.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if !filterUserDefined && searchText.isEmpty {
                Button("Create Network") {
                    showCreateDialog = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var networkListView: some View {
        Table(filteredNetworks, selection: $selectedNetwork) {
            TableColumn("Name") { network in
                HStack(spacing: 8) {
                    Image(systemName: network.isDefaultNetwork ? "lock.shield.fill" : "network")
                        .foregroundStyle(network.isDefaultNetwork ? .orange : .blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(network.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if network.containerCount > 0 {
                            Text("\(network.containerCount) container\(network.containerCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .width(min: 150, ideal: 200)
            
            TableColumn("Network ID") { network in
                Text(network.shortID)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 120)
            
            TableColumn("Driver") { network in
                HStack {
                    Image(systemName: driverIcon(for: network.driver))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(network.driver)
                }
                .font(.caption)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Subnet") { network in
                Text(network.subnet ?? "—")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 150)
            
            TableColumn("Gateway") { network in
                Text(network.gateway ?? "—")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 130)
            
            TableColumn("Scope") { network in
                Text(network.scope)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80)
            
            TableColumn("Actions") { network in
                HStack(spacing: 4) {
                    Button(action: { confirmRemove(network) }) {
                        Image(systemName: "trash")
                            .foregroundStyle(network.isDefaultNetwork ? .gray : .red)
                    }
                    .buttonStyle(.plain)
                    .disabled(network.isDefaultNetwork)
                    .help(network.isDefaultNetwork ? "Cannot remove default network" : "Remove network")
                    
                    Menu {
                        Button(action: { inspectNetwork(network) }) {
                            Label("Inspect", systemImage: "info.circle")
                        }
                        
                        Divider()
                        
                        Button(action: { copyToClipboard(network.name) }) {
                            Label("Copy Name", systemImage: "doc.on.doc")
                        }
                        
                        Button(action: { copyToClipboard(network.networkID) }) {
                            Label("Copy Network ID", systemImage: "doc.on.doc")
                        }
                        
                        if let subnet = network.subnet {
                            Button(action: { copyToClipboard(subnet) }) {
                                Label("Copy Subnet", systemImage: "doc.on.doc")
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
        .contextMenu(forSelectionType: NetworkInfo.ID.self) { selection in
            if selection.count == 1, let networkID = selection.first,
               let network = networks.first(where: { $0.id == networkID }) {
                Button("Inspect") {
                    inspectNetwork(network)
                }
                
                if !network.isDefaultNetwork {
                    Button("Remove", role: .destructive) {
                        confirmRemove(network)
                    }
                }
                
                Divider()
                
                Button("Copy Name") {
                    copyToClipboard(network.name)
                }
                
                Button("Copy Network ID") {
                    copyToClipboard(network.networkID)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func driverIcon(for driver: String) -> String {
        switch driver {
        case "bridge":
            return "arrow.triangle.branch"
        case "host":
            return "server.rack"
        case "overlay":
            return "square.stack.3d.up"
        case "macvlan":
            return "hifispeaker.2"
        default:
            return "network"
        }
    }
    
    // MARK: - Actions
    
    private func refreshNetworks() {
        isLoading = true
        
        Task {
            if let fetchedNetworks = await containerMonitor.fetchNetworks() {
                await MainActor.run {
                    networks = fetchedNetworks
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    networks = []
                    isLoading = false
                }
            }
        }
    }
    
    private func createNetwork(_ options: NetworkCreateOptions) {
        Task {
            let result = await containerMonitor.createNetwork(options: options)
            
            if result?.success == true {
                await MainActor.run {
                    showCreateDialog = false
                    refreshNetworks()
                }
            }
        }
    }
    
    private func confirmRemove(_ network: NetworkInfo) {
        guard !network.isDefaultNetwork else {
            return
        }
        networkToRemove = network
        showRemoveConfirmation = true
    }
    
    private func removeNetwork(_ network: NetworkInfo) {
        Task {
            let result = await containerMonitor.removeNetwork(network.name)
            
            if result?.success == true {
                refreshNetworks()
            }
        }
    }
    
    private func pruneNetworks() {
        Task {
            let result = await containerMonitor.pruneNetworks()
            
            if result?.success == true {
                refreshNetworks()
            }
        }
    }
    
    private func inspectNetwork(_ network: NetworkInfo) {
        Task {
            if let details = await containerMonitor.inspectNetwork(network.name) {
                await MainActor.run {
                    inspectedNetwork = details
                    showInspector = true
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Network Create Dialog

struct NetworkCreateDialog: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (NetworkCreateOptions) -> Void
    
    @State private var networkName = ""
    @State private var driver = "bridge"
    @State private var subnet = ""
    @State private var gateway = ""
    @State private var ipRange = ""
    @State private var isInternal = false
    @State private var enableIPv6 = false
    @State private var showValidationError = false
    @State private var validationMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Network")
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
                        Text("Network Name")
                            .font(.headline)
                        TextField("my-network", text: $networkName)
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
                            Text("bridge").tag("bridge")
                            Text("host").tag("host")
                            Text("overlay").tag("overlay")
                            Text("macvlan").tag("macvlan")
                        }
                        .pickerStyle(.segmented)
                        Text("Network driver for container connectivity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Network Configuration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Network Configuration")
                            .font(.headline)
                        
                        TextField("Subnet (CIDR)", text: $subnet)
                            .textFieldStyle(.roundedBorder)
                            .disabled(driver == "host")
                        Text("Example: 172.28.0.0/16")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("Gateway", text: $gateway)
                            .textFieldStyle(.roundedBorder)
                            .disabled(driver == "host" || subnet.isEmpty)
                        Text("Example: 172.28.0.1")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("IP Range (optional)", text: $ipRange)
                            .textFieldStyle(.roundedBorder)
                            .disabled(driver == "host" || subnet.isEmpty)
                        Text("Example: 172.28.5.0/24")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Options
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Options")
                            .font(.headline)
                        
                        Toggle("Internal Network", isOn: $isInternal)
                        Text("Restrict external access to this network")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 20)
                        
                        Toggle("Enable IPv6", isOn: $enableIPv6)
                        Text("Enable IPv6 networking")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 20)
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
                    createNetwork()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(networkName.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 650)
    }
    
    private func createNetwork() {
        // Validate name
        showValidationError = false
        
        // Validate subnet if provided
        if !subnet.isEmpty {
            guard NetworkInfo.validateSubnet(subnet) else {
                validationMessage = "Invalid subnet format. Use CIDR notation (e.g., 172.28.0.0/16)"
                showValidationError = true
                return
            }
        }
        
        // Validate gateway if provided
        if !gateway.isEmpty {
            guard NetworkInfo.validateIPAddress(gateway) else {
                validationMessage = "Invalid gateway IP address format."
                showValidationError = true
                return
            }
        }
        
        // Validate IP range if provided
        if !ipRange.isEmpty {
            guard NetworkInfo.validateSubnet(ipRange) else {
                validationMessage = "Invalid IP range format. Use CIDR notation (e.g., 172.28.5.0/24)"
                showValidationError = true
                return
            }
        }
        
        let options = NetworkCreateOptions(
            name: networkName,
            driver: driver,
            subnet: subnet.isEmpty ? nil : subnet,
            gateway: gateway.isEmpty ? nil : gateway,
            ipRange: ipRange.isEmpty ? nil : ipRange,
            internal: isInternal,
            enableIPv6: enableIPv6,
            options: nil,
            labels: nil
        )
        
        onCreate(options)
    }
}

// MARK: - Network Inspector Sheet

struct NetworkInspectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let network: NetworkInfo
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: network.isDefaultNetwork ? "lock.shield.fill" : "network")
                        .font(.title2)
                        .foregroundStyle(network.isDefaultNetwork ? .orange : .blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(network.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(network.networkID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                
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
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Basic Information
                    InspectorSection(title: "Basic Information") {
                        InspectorRow(label: "Name", value: network.name, copyable: true)
                        InspectorRow(label: "Network ID", value: network.networkID, copyable: true)
                        InspectorRow(label: "Short ID", value: network.shortID, copyable: true)
                        InspectorRow(label: "Driver", value: network.driver)
                        InspectorRow(label: "Scope", value: network.scope)
                        
                        if network.containerCount > 0 {
                            InspectorRow(
                                label: "Containers",
                                value: "\(network.containerCount)"
                            )
                        }
                    }
                    
                    // Network Configuration
                    if network.subnet != nil || network.gateway != nil || network.ipRange != nil {
                        InspectorSection(title: "Network Configuration") {
                            if let subnet = network.subnet {
                                InspectorRow(label: "Subnet", value: subnet, copyable: true)
                            }
                            
                            if let gateway = network.gateway {
                                InspectorRow(label: "Gateway", value: gateway, copyable: true)
                            }
                            
                            if let ipRange = network.ipRange {
                                InspectorRow(label: "IP Range", value: ipRange, copyable: true)
                            }
                        }
                    }
                    
                    // Options
                    InspectorSection(title: "Options") {
                        InspectorRow(
                            label: "Internal",
                            value: network.internal ? "Yes" : "No"
                        )
                        InspectorRow(
                            label: "IPv6",
                            value: network.enableIPv6 ? "Yes" : "No"
                        )
                        InspectorRow(
                            label: "System",
                            value: network.isDefaultNetwork ? "Yes" : "No"
                        )
                    }
                    
                    // Labels
                    if let labels = network.labels, !labels.isEmpty {
                        InspectorSection(title: "Labels") {
                            ForEach(Array(labels.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                InspectorRow(label: key, value: value)
                            }
                        }
                    }
                    
                    // Metadata
                    if let created = network.created {
                        InspectorSection(title: "Metadata") {
                            InspectorRow(label: "Created", value: formatDate(created))
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Button(action: { copyToClipboard(network.networkID) }) {
                    Label("Copy Network ID", systemImage: "doc.on.doc")
                }
                
                if let subnet = network.subnet {
                    Button(action: { copyToClipboard(subnet) }) {
                        Label("Copy Subnet", systemImage: "doc.on.doc")
                    }
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Preview

#Preview {
    NetworkListView(searchText: "")
        .environmentObject(ContainerSystemMonitor())
        .frame(width: 1000, height: 700)
}
