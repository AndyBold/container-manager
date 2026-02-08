//
//  ContainerCreationView.swift
//  container-manager
//
//  Multi-step wizard for creating containers
//

import SwiftUI

struct ContainerCreationView: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    @Environment(\.dismiss) var dismiss
    
    @State private var currentStep: CreationStep = .imageSelection
    @State private var config = ContainerCreationConfig()
    @State private var isCreating = false
    @State private var creationError: String?
    @State private var showingErrorAlert = false
    
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("compactMode") private var compactMode = false
    
    // Effective reduce motion (app OR system)
    private var effectiveReduceMotion: Bool {
        reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    
    // Animation based on preferences
    private var defaultAnimation: Animation? {
        guard enableAnimations else { return nil }
        return effectiveReduceMotion ? .linear(duration: 0.2) : .smooth
    }
    
    enum CreationStep: Int, CaseIterable {
        case imageSelection = 0
        case basicConfig = 1
        case ports = 2
        case volumes = 3
        case environment = 4
        case network = 5
        case review = 6
        
        var title: String {
            switch self {
            case .imageSelection: return "Select Image"
            case .basicConfig: return "Basic Configuration"
            case .ports: return "Port Mappings"
            case .volumes: return "Volume Mounts"
            case .environment: return "Environment Variables"
            case .network: return "Network"
            case .review: return "Review & Create"
            }
        }
        
        var icon: String {
            switch self {
            case .imageSelection: return "shippingbox"
            case .basicConfig: return "slider.horizontal.3"
            case .ports: return "network"
            case .volumes: return "internaldrive"
            case .environment: return "doc.text"
            case .network: return "network.badge.shield.half.filled"
            case .review: return "checkmark.circle"
            }
        }
        
        var subtitle: String {
            switch self {
            case .imageSelection: return "Choose a container image"
            case .basicConfig: return "Name and runtime settings"
            case .ports: return "Expose container ports"
            case .volumes: return "Mount persistent storage"
            case .environment: return "Set environment variables"
            case .network: return "Configure networking"
            case .review: return "Review configuration and create"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Progress bar
            progressBar
            
            Divider()
            
            // Content
            Group {
                switch currentStep {
                case .imageSelection:
                    ImageSelectionStep(config: $config)
                case .basicConfig:
                    BasicConfigStep(config: $config)
                case .ports:
                    PortMappingsStep(config: $config)
                case .volumes:
                    VolumeMountsStep(config: $config)
                case .environment:
                    EnvironmentVariablesStep(config: $config)
                case .network:
                    NetworkConfigStep(config: $config)
                case .review:
                    ReviewStep(config: $config)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
            .animation(defaultAnimation, value: currentStep)
            
            Divider()
            
            // Footer with navigation
            footerView
        }
        .frame(minWidth: 700, minHeight: 600)
        .alert("Creation Error", isPresented: $showingErrorAlert) {
            Button("OK") {
                creationError = nil
            }
        } message: {
            Text(creationError ?? "Unknown error")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Create Container")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Step \(currentStep.rawValue + 1) of \(CreationStep.allCases.count): \(currentStep.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
        }
        .padding()
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress)
                    .animation(defaultAnimation, value: currentStep)
            }
        }
        .frame(height: 4)
    }
    
    private var progress: Double {
        Double(currentStep.rawValue + 1) / Double(CreationStep.allCases.count)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            // Step info
            HStack(spacing: compactMode ? 8 : 12) {
                ForEach(CreationStep.allCases, id: \.self) { step in
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: compactMode ? 6 : 8, height: compactMode ? 6 : 8)
                }
            }
            
            Spacer()
            
            // Navigation buttons
            HStack(spacing: 12) {
                if currentStep != .imageSelection {
                    Button("Back") {
                        goToPreviousStep()
                    }
                    .keyboardShortcut("[", modifiers: [.command])
                }
                
                if currentStep == .review {
                    Button(action: createContainer) {
                        if isCreating {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .controlSize(.small)
                                Text("Creating...")
                            }
                        } else {
                            Text("Create Container")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreate || isCreating)
                    .keyboardShortcut(.return, modifiers: [.command])
                } else {
                    Button("Next") {
                        goToNextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
                    .keyboardShortcut("]", modifiers: [.command])
                }
            }
        }
        .padding()
    }
    
    // MARK: - Validation
    
    private var canProceed: Bool {
        switch currentStep {
        case .imageSelection:
            return !config.selectedImage.isEmpty
        case .basicConfig:
            return !config.containerName.isEmpty
        case .ports, .volumes, .environment, .network:
            return true // Optional steps
        case .review:
            return false // Can't proceed from review
        }
    }
    
    private var canCreate: Bool {
        !config.selectedImage.isEmpty && !config.containerName.isEmpty
    }
    
    // MARK: - Navigation
    
    private func goToNextStep() {
        guard let nextIndex = CreationStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextIndex
    }
    
    private func goToPreviousStep() {
        guard let prevIndex = CreationStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prevIndex
    }
    
    // MARK: - Container Creation
    
    private func createContainer() {
        isCreating = true
        
        Task {
            let (success, errorMessage) = await containerMonitor.createContainer(config: config)
            
            await MainActor.run {
                isCreating = false
                
                if success {
                    dismiss()
                    // Refresh container list
                    Task {
                        await containerMonitor.checkAppleContainerStatus()
                    }
                } else {
                    creationError = errorMessage ?? "Failed to create container. Check the configuration and try again."
                    showingErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContainerCreationView()
        .environmentObject(ContainerSystemMonitor())
}
