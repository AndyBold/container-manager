//
//  ContainerCreationConfig.swift
//  container-manager
//
//  Container creation configuration model
//

import Foundation

/// Configuration for creating a new container
struct ContainerCreationConfig {
    var selectedImage: String = ""
    var containerName: String = ""
    var command: String = ""
    
    var portMappings: [PortMapping] = []
    var volumeMounts: [VolumeMount] = []
    var environmentVariables: [EnvironmentVariable] = []
    
    struct PortMapping: Identifiable {
        let id = UUID()
        var hostPort: String = ""
        var containerPort: String = ""
        var protocolType: String = "tcp"
    }
    
    struct VolumeMount: Identifiable {
        let id = UUID()
        var hostPath: String = ""
        var containerPath: String = ""
        var readOnly: Bool = false
    }
    
    struct EnvironmentVariable: Identifiable {
        let id = UUID()
        var key: String = ""
        var value: String = ""
    }
}
