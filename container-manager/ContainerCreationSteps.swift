//
//  ContainerCreationSteps.swift
//  container-manager
//
//  Individual step views for container creation wizard
//

import SwiftUI
import AppKit

// MARK: - Step 1: Image Selection

struct ImageSelectionStep: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    @Binding var config: ContainerCreationConfig
    @State private var availableImages: [String] = []
    @State private var isLoading = true
    @State private var searchText = ""
    
    @AppStorage("compactMode") private var compactMode = false
    
    private var filteredImages: [String] {
        if searchText.isEmpty {
            return availableImages
        }
        return availableImages.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: compactMode ? 12 : 16) {
            Text("Select a container image to use")
                .font(.headline)
            
            Text("Choose from available images on your system or pull a new one")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search images...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.top, 8)
            
            if isLoading {
                ProgressView("Loading images...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredImages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    if searchText.isEmpty {
                        Text("No images available")
                            .font(.headline)
                        
                        Text("Pull an image first using the Images tab")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No local images match your search")
                            .font(.headline)
                        
                        Text("You can use this as a custom image name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Button(action: {
                            config.selectedImage = searchText
                        }) {
                            HStack {
                                Image(systemName: config.selectedImage == searchText ? "checkmark.circle.fill" : "plus.circle.fill")
                                    .foregroundStyle(config.selectedImage == searchText ? .green : .blue)
                                Text("Use \"\(searchText)\"")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(config.selectedImage == searchText ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(config.selectedImage == searchText ? Color.green : Color.blue, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: compactMode ? 8 : 12) {
                        // Show custom image option when user has typed something
                        if !searchText.isEmpty && !filteredImages.contains(searchText) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Custom Image")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, compactMode ? 8 : 12)
                                
                                Button(action: {
                                    config.selectedImage = searchText
                                }) {
                                    HStack {
                                        Image(systemName: config.selectedImage == searchText ? "checkmark.circle.fill" : "plus.circle")
                                            .foregroundStyle(config.selectedImage == searchText ? .green : .blue)
                                            .imageScale(.large)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(searchText)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                            
                                            Text("Will be pulled during container creation")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(compactMode ? 8 : 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(config.selectedImage == searchText ? Color.green.opacity(0.1) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(config.selectedImage == searchText ? Color.green : Color.secondary.opacity(0.2), lineWidth: config.selectedImage == searchText ? 2 : 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Divider()
                                    .padding(.vertical, 4)
                                
                                Text("Local Images")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, compactMode ? 8 : 12)
                            }
                        }
                        
                        ForEach(filteredImages, id: \.self) { image in
                            ImageRow(
                                image: image,
                                isSelected: config.selectedImage == image,
                                action: {
                                    config.selectedImage = image
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .task {
            await loadImages()
        }
    }
    
    private func loadImages() async {
        isLoading = true
        
        // Fetch available images
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/container")
        process.arguments = ["images", "--format", "{{.Repository}}:{{.Tag}}"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let images = output.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.contains("<none>") }
            
            await MainActor.run {
                availableImages = images.sorted()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                availableImages = []
                isLoading = false
            }
        }
    }
}

struct ImageRow: View {
    let image: String
    let isSelected: Bool
    let action: () -> Void
    
    @AppStorage("compactMode") private var compactMode = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .imageScale(.large)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(image)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    if let (repo, tag) = parseImage(image) {
                        HStack(spacing: 8) {
                            Label(repo, systemImage: "shippingbox")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Label(tag, systemImage: "tag")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(compactMode ? 10 : 12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func parseImage(_ image: String) -> (repo: String, tag: String)? {
        let components = image.components(separatedBy: ":")
        guard components.count == 2 else { return nil }
        return (components[0], components[1])
    }
}

// MARK: - Step 2: Basic Configuration

struct BasicConfigStep: View {
    @Binding var config: ContainerCreationConfig
    @AppStorage("compactMode") private var compactMode = false
    
    var body: some View {
        Form {
            Section("Container Identity") {
                LabeledContent("Image") {
                    Text(config.selectedImage)
                        .foregroundStyle(.secondary)
                }
                
                TextField("Container Name", text: $config.containerName, prompt: Text("my-container"))
                    .textFieldStyle(.roundedBorder)
                    .help("Unique name for the container")
            }
            
            Section("Runtime Configuration") {
                TextField("Command (optional)", text: $config.command, prompt: Text("/bin/sh"))
                    .textFieldStyle(.roundedBorder)
                    .help("Override the default command")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Step 3: Port Mappings

struct PortMappingsStep: View {
    @Binding var config: ContainerCreationConfig
    @AppStorage("compactMode") private var compactMode = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: compactMode ? 12 : 16) {
            Text("Configure port mappings")
                .font(.headline)
            
            Text("Map container ports to host ports to make services accessible")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ScrollView {
                VStack(spacing: compactMode ? 8 : 12) {
                    ForEach(config.portMappings) { mapping in
                        PortMappingRow(
                            mapping: binding(for: mapping),
                            onDelete: {
                                config.portMappings.removeAll { $0.id == mapping.id }
                            }
                        )
                    }
                    
                    Button(action: addPortMapping) {
                        Label("Add Port Mapping", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            if config.portMappings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "network")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No port mappings configured")
                        .font(.headline)
                    
                    Text("Port mappings are optional. Add them if you need to access services running in the container.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }
    
    private func binding(for mapping: ContainerCreationConfig.PortMapping) -> Binding<ContainerCreationConfig.PortMapping> {
        guard let index = config.portMappings.firstIndex(where: { $0.id == mapping.id }) else {
            fatalError("Mapping not found")
        }
        return $config.portMappings[index]
    }
    
    private func addPortMapping() {
        config.portMappings.append(.init())
    }
}

struct PortMappingRow: View {
    @Binding var mapping: ContainerCreationConfig.PortMapping
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Host Port", text: $mapping.hostPort, prompt: Text("8080"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
            
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            
            TextField("Container Port", text: $mapping.containerPort, prompt: Text("80"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
            
            Picker("Protocol", selection: $mapping.protocolType) {
                Text("TCP").tag("tcp")
                Text("UDP").tag("udp")
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Remove this port mapping")
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Step 4: Volume Mounts

struct VolumeMountsStep: View {
    @Binding var config: ContainerCreationConfig
    @AppStorage("compactMode") private var compactMode = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: compactMode ? 12 : 16) {
            Text("Configure volume mounts")
                .font(.headline)
            
            Text("Mount host directories or volumes into the container for persistent storage")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ScrollView {
                VStack(spacing: compactMode ? 8 : 12) {
                    ForEach(config.volumeMounts) { mount in
                        VolumeMountRow(
                            mount: binding(for: mount),
                            onDelete: {
                                config.volumeMounts.removeAll { $0.id == mount.id }
                            }
                        )
                    }
                    
                    Button(action: addVolumeMount) {
                        Label("Add Volume Mount", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            if config.volumeMounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No volume mounts configured")
                        .font(.headline)
                    
                    Text("Volume mounts are optional. Add them to persist data or share files with the container.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }
    
    private func binding(for mount: ContainerCreationConfig.VolumeMount) -> Binding<ContainerCreationConfig.VolumeMount> {
        guard let index = config.volumeMounts.firstIndex(where: { $0.id == mount.id }) else {
            fatalError("Mount not found")
        }
        return $config.volumeMounts[index]
    }
    
    private func addVolumeMount() {
        config.volumeMounts.append(.init())
    }
}

struct VolumeMountRow: View {
    @Binding var mount: ContainerCreationConfig.VolumeMount
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Host Path")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        TextField("/path/on/host", text: $mount.hostPath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: selectHostPath) {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                        .help("Browse for folder")
                    }
                }
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Container Path")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("/path/in/container", text: $mount.containerPath)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            HStack {
                Toggle("Read-only", isOn: $mount.readOnly)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                
                Spacer()
                
                Button(action: onDelete) {
                    Label("Remove", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Remove this volume mount")
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func selectHostPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a directory to mount"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                mount.hostPath = url.path
            }
        }
    }
}

// MARK: - Step 5: Environment Variables

struct EnvironmentVariablesStep: View {
    @Binding var config: ContainerCreationConfig
    @AppStorage("compactMode") private var compactMode = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: compactMode ? 12 : 16) {
            Text("Configure environment variables")
                .font(.headline)
            
            Text("Set environment variables that will be available inside the container")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ScrollView {
                VStack(spacing: compactMode ? 8 : 12) {
                    ForEach(config.environmentVariables) { envVar in
                        EnvironmentVariableRow(
                            envVar: binding(for: envVar),
                            onDelete: {
                                config.environmentVariables.removeAll { $0.id == envVar.id }
                            }
                        )
                    }
                    
                    Button(action: addEnvironmentVariable) {
                        Label("Add Environment Variable", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            if config.environmentVariables.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No environment variables configured")
                        .font(.headline)
                    
                    Text("Environment variables are optional. Add them to configure application behavior.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }
    
    private func binding(for envVar: ContainerCreationConfig.EnvironmentVariable) -> Binding<ContainerCreationConfig.EnvironmentVariable> {
        guard let index = config.environmentVariables.firstIndex(where: { $0.id == envVar.id }) else {
            fatalError("Environment variable not found")
        }
        return $config.environmentVariables[index]
    }
    
    private func addEnvironmentVariable() {
        config.environmentVariables.append(.init())
    }
}

struct EnvironmentVariableRow: View {
    @Binding var envVar: ContainerCreationConfig.EnvironmentVariable
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("KEY", text: $envVar.key, prompt: Text("DATABASE_URL"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            
            Text("=")
                .foregroundStyle(.secondary)
            
            TextField("Value", text: $envVar.value, prompt: Text("postgres://localhost/mydb"))
                .textFieldStyle(.roundedBorder)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Remove this environment variable")
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Step 6: Network Configuration

struct NetworkConfigStep: View {
    @Binding var config: ContainerCreationConfig
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Network Configuration")
                .font(.headline)
            
            Text("Containers will use default networking. Advanced network configuration is not currently supported by Apple's container tool.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Step 7: Review & Create

struct ReviewStep: View {
    @Binding var config: ContainerCreationConfig
    @AppStorage("compactMode") private var compactMode = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compactMode ? 16 : 20) {
                Text("Review Configuration")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Basic Info
                ReviewSection(title: "Image & Identity", icon: "shippingbox") {
                    ReviewItem(label: "Image", value: config.selectedImage)
                    ReviewItem(label: "Container Name", value: config.containerName)
                }
                
                // Runtime
                if !config.command.isEmpty {
                    ReviewSection(title: "Runtime", icon: "gearshape") {
                        ReviewItem(label: "Command", value: config.command)
                    }
                }
                
                // Ports
                if !config.portMappings.isEmpty {
                    ReviewSection(title: "Port Mappings", icon: "network") {
                        ForEach(config.portMappings) { mapping in
                            ReviewItem(
                                label: "\(mapping.hostPort) → \(mapping.containerPort)",
                                value: mapping.protocolType.uppercased()
                            )
                        }
                    }
                }
                
                // Volumes
                if !config.volumeMounts.isEmpty {
                    ReviewSection(title: "Volume Mounts", icon: "internaldrive") {
                        ForEach(config.volumeMounts) { mount in
                            ReviewItem(
                                label: mount.hostPath,
                                value: "\(mount.containerPath)\(mount.readOnly ? " (ro)" : "")"
                            )
                        }
                    }
                }
                
                // Environment
                if !config.environmentVariables.isEmpty {
                    ReviewSection(title: "Environment Variables", icon: "doc.text") {
                        ForEach(config.environmentVariables) { envVar in
                            ReviewItem(label: envVar.key, value: envVar.value)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct ReviewSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    @AppStorage("compactMode") private var compactMode = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: compactMode ? 8 : 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.headline)
            }
            
            VStack(spacing: compactMode ? 4 : 6) {
                content
            }
            .padding(compactMode ? 10 : 12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct ReviewItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}
