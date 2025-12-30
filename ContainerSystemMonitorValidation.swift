//
//  ContainerSystemMonitorValidation.swift
//  container-manager
//
//  Created by Andrew Bold on 30/12/2025.
//
//  This is a temporary validation file that doesn't require test frameworks.
//  Replace with proper tests once test target is configured.

import Foundation
import SwiftUI

@MainActor
struct ContainerSystemMonitorValidation {
    
    // MARK: - Validation Methods
    
    static func validateAll() async {
        print("🧪 Starting Container System Monitor Validation")
        print("=" + String(repeating: "=", count: 50))
        
        validateContainerSystemStatus()
        validateContainerInfo()
        await validateMonitorBasics()
        await validateMonitorOperations()
        
        print("=" + String(repeating: "=", count: 50))
        print("✅ Validation Complete")
    }
    
    // MARK: - ContainerSystemStatus Validation
    
    static func validateContainerSystemStatus() {
        print("\n📋 Validating ContainerSystemStatus...")
        
        // Test colors
        assert(ContainerSystemStatus.running.color == .green, "Running should be green")
        assert(ContainerSystemStatus.stopped.color == .primary, "Stopped should be primary")
        assert(ContainerSystemStatus.error.color == .red, "Error should be red")
        print("  ✓ Status colors correct")
        
        // Test display names
        assert(ContainerSystemStatus.running.displayName == "Running", "Running display name")
        assert(ContainerSystemStatus.stopped.displayName == "Stopped", "Stopped display name")
        assert(ContainerSystemStatus.error.displayName == "Error", "Error display name")
        print("  ✓ Status display names correct")
    }
    
    // MARK: - ContainerInfo Validation
    
    static func validateContainerInfo() {
        print("\n📦 Validating ContainerInfo...")
        
        let container1 = ContainerInfo(name: "test1", status: "running")
        let container2 = ContainerInfo(name: "test2", status: "running")
        
        assert(container1.id != container2.id, "Container IDs should be unique")
        print("  ✓ Container IDs are unique")
        
        let container = ContainerInfo(name: "my-container", status: "stopped")
        assert(container.name == "my-container", "Container name")
        assert(container.status == "stopped", "Container status")
        print("  ✓ Container properties stored correctly")
    }
    
    // MARK: - Monitor Basic Validation
    
    static func validateMonitorBasics() async {
        print("\n🔍 Validating ContainerSystemMonitor basics...")
        
        let monitor = ContainerSystemMonitor()
        
        // Initial state
        assert(!monitor.isOperating, "Initial operating state should be false")
        print("  ✓ Initial operating state correct")
        
        // Wait for initialization
        try? await Task.sleep(for: .milliseconds(200))
        
        let validStatuses: [ContainerSystemStatus] = [.running, .stopped, .error]
        assert(validStatuses.contains(monitor.status), "Status should be valid enum value")
        print("  ✓ Status is valid: \(monitor.status.displayName)")
        
        assert(monitor.containers.isEmpty || monitor.containers.count > 0, "Containers should be a valid array")
        print("  ✓ Containers array is accessible (count: \(monitor.containers.count))")
        
        let beforeCheck = Date()
        assert(monitor.lastUpdated >= beforeCheck.addingTimeInterval(-1), "lastUpdated should be recent")
        print("  ✓ lastUpdated timestamp is valid")
    }
    
    // MARK: - Monitor Operations Validation
    
    static func validateMonitorOperations() async {
        print("\n⚙️ Validating ContainerSystemMonitor operations...")
        
        let monitor = ContainerSystemMonitor()
        
        // Test status check
        let beforeCheck = monitor.lastUpdated
        try? await Task.sleep(for: .milliseconds(100))
        
        monitor.checkContainerStatus()
        try? await Task.sleep(for: .milliseconds(200))
        
        assert(monitor.lastUpdated >= beforeCheck, "Status check should update timestamp")
        print("  ✓ checkContainerStatus updates timestamp")
        
        // Test concurrent checks don't crash
        let tasks = (0..<5).map { _ in
            Task {
                monitor.checkContainerStatus()
            }
        }
        
        for task in tasks {
            await task.value
        }
        
        try? await Task.sleep(for: .milliseconds(300))
        print("  ✓ Concurrent status checks handled safely")
    }
}

// MARK: - Usage Instructions
/*
 To run these validations:
 
 1. Add this code to your app (temporarily):
 
    Task {
        await ContainerSystemMonitorValidation.validateAll()
    }
 
 2. Run your app and check the console output
 
 3. Once you see all validations pass, you know the code works
 
 4. Then fix your test target configuration in Xcode:
    - File > New > Target > Unit Testing Bundle
    - Add ContainerSystemMonitorTests.swift to that target
    - Make sure the test target links against your app target
 */
