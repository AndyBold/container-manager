//
//  ContentView.swift
//  container-manager
//
//  Created by Andrew Bold on 30/12/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    @State private var showStopConfirmation = false
    @State private var hasShownInitialPrompt = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with status
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(containerMonitor.status.color)
                    .imageScale(.large)
                
                VStack(alignment: .leading) {
                    Text("Container System")
                        .font(.headline)
                    Text(containerMonitor.status.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Prompt banner when stopped
            if containerMonitor.status == .stopped && !hasShownInitialPrompt {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Service is not running")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack(spacing: 8) {
                        Button("Start Service") {
                            hasShownInitialPrompt = true
                            containerMonitor.startContainerService()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(containerMonitor.isOperating)
                        
                        Button("Dismiss") {
                            hasShownInitialPrompt = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                
                Divider()
            }
            
            // Container list or empty state
            if !containerMonitor.containers.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Containers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        ForEach(containerMonitor.containers) { container in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Image(systemName: "cube.fill")
                                        .foregroundStyle(.blue)
                                        .imageScale(.small)
                                    Text(container.name)
                                        .font(.body)
                                }
                                if !container.status.isEmpty {
                                    Text(container.status)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 20)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 200)
            } else if containerMonitor.status == .running {
                Text("No containers running")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding()
            } else if containerMonitor.status == .stopped {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Container service is not running")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    Button("Start Service") {
                        containerMonitor.startContainerService()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(containerMonitor.isOperating)
                }
                .padding()
            } else if containerMonitor.status == .error {
                Text("Error checking container status")
                    .font(.body)
                    .foregroundStyle(.red)
                    .padding()
            }
            
            Divider()
            
            // Footer with actions
            VStack(spacing: 4) {
                HStack {
                    Text("Last updated: \(containerMonitor.lastUpdated, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                
                HStack {
                    Button("Refresh") {
                        containerMonitor.checkContainerStatus()
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(containerMonitor.isOperating)
                    
                    Spacer()
                    
                    // Service control button
                    if containerMonitor.status == .running {
                        if showStopConfirmation {
                            HStack(spacing: 4) {
                                Button("Confirm Stop", role: .destructive) {
                                    showStopConfirmation = false
                                    containerMonitor.stopContainerService()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .controlSize(.small)
                                .disabled(containerMonitor.isOperating)
                                
                                Button("Cancel") {
                                    showStopConfirmation = false
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        } else {
                            Button("Stop Service") {
                                showStopConfirmation = true
                            }
                            .disabled(containerMonitor.isOperating)
                        }
                    } else if containerMonitor.status == .stopped {
                        Button("Start Service") {
                            containerMonitor.startContainerService()
                        }
                        .disabled(containerMonitor.isOperating)
                    }
                    
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: .command)
                }
            }
            .padding()
        }
        .frame(width: 300)
        .onChange(of: containerMonitor.status) { oldValue, newValue in
            // Reset prompt state when service stops
            if newValue == .stopped && oldValue == .running {
                hasShownInitialPrompt = false
                showStopConfirmation = false
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ContainerSystemMonitor())
}
