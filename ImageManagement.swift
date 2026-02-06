//
//  ImageManagement.swift
//  container-manager
//
//  Image management functionality
//

import Foundation

// MARK: - Image Info Model

struct ContainerImageInfo: Identifiable, Equatable {
    let id = UUID()
    let repository: String
    let tag: String?
    let imageID: String
    let size: String
    let created: Date?
    
    var isDangling: Bool {
        return repository == "<none>" && (tag == nil || tag == "<none>")
    }
    
    var displayName: String {
        if let tag = tag, tag != "<none>" {
            return "\(repository):\(tag)"
        }
        return repository
    }
    
    // MARK: - Initializers
    
    init(repository: String, tag: String?, imageID: String, size: String, created: Date? = nil) {
        self.repository = repository
        self.tag = tag
        self.imageID = imageID
        self.size = size
        self.created = created
    }
    
    init(repository: String, tag: String, imageID: String, size: String) {
        self.repository = repository
        self.tag = tag
        self.imageID = imageID
        self.size = size
        self.created = nil
    }
    
    init(repository: String, tag: String, imageID: String, created: Date) {
        self.repository = repository
        self.tag = tag
        self.imageID = imageID
        self.size = "0B"
        self.created = created
    }
    
    // MARK: - Parsing
    
    static func parseList(_ output: String) -> [ContainerImageInfo] {
        let lines = output.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }
        
        var images: [ContainerImageInfo] = []
        var isFirstLine = true
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // Skip header line
            if isFirstLine {
                isFirstLine = false
                continue
            }
            
            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 5 else { continue }
            
            let repository = components[0]
            let tag = components[1] == "<none>" ? nil : components[1]
            let imageID = components[2]
            let size = components[4]
            
            images.append(ContainerImageInfo(
                repository: repository,
                tag: tag,
                imageID: imageID,
                size: size,
                created: nil
            ))
        }
        
        return images
    }
    
    // MARK: - Filtering
    
    static func filter(_ images: [ContainerImageInfo], repository: String) -> [ContainerImageInfo] {
        return images.filter { $0.repository.localizedCaseInsensitiveContains(repository) }
    }
    
    static func filterDangling(_ images: [ContainerImageInfo]) -> [ContainerImageInfo] {
        return images.filter { $0.isDangling }
    }
    
    // MARK: - Sorting
    
    static func sortBySize(_ images: [ContainerImageInfo]) -> [ContainerImageInfo] {
        return images.sorted { parseSize($0.size) > parseSize($1.size) }
    }
    
    static func sortByDate(_ images: [ContainerImageInfo]) -> [ContainerImageInfo] {
        return images.sorted { ($0.created ?? .distantPast) > ($1.created ?? .distantPast) }
    }
    
    static func sortByName(_ images: [ContainerImageInfo]) -> [ContainerImageInfo] {
        return images.sorted { $0.displayName < $1.displayName }
    }
    
    // MARK: - Size Parsing
    
    static func parseSize(_ sizeString: String) -> Int {
        let uppercased = sizeString.uppercased()
        let numberString = sizeString.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")).inverted).joined()
        guard let number = Double(numberString) else { return 0 }
        
        if uppercased.contains("GB") {
            return Int(number * 1_000_000_000)
        } else if uppercased.contains("MB") {
            return Int(number * 1_000_000)
        } else if uppercased.contains("KB") {
            return Int(number * 1_000)
        } else if uppercased.contains("B") {
            return Int(number)
        }
        
        return Int(number)
    }
    
    static func calculateTotalSize(_ images: [ContainerImageInfo]) -> Int {
        return images.reduce(0) { $0 + parseSize($1.size) }
    }
    
    static func formatSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - Equatable
    
    static func == (lhs: ContainerImageInfo, rhs: ContainerImageInfo) -> Bool {
        return lhs.repository == rhs.repository &&
               lhs.tag == rhs.tag &&
               lhs.imageID == rhs.imageID
    }
}

// MARK: - Image Operation Result

struct ImageOperationResult {
    let success: Bool
    let error: String?
    let imageName: String?
    
    init(success: Bool, error: String? = nil, imageName: String? = nil) {
        self.success = success
        self.error = error
        self.imageName = imageName
    }
}

// MARK: - Image Progress

struct ImageProgress {
    let percentage: Double
    let currentLayer: String?
    let totalLayers: Int?
    let status: String
}

// MARK: - Image Details

struct ImageDetails {
    let id: String
    let tags: [String]
    let size: Int
    let created: Date
    let architecture: String
    let os: String
    let labels: [String: String]?
}

// MARK: - Image History Entry

struct ImageHistoryEntry: Identifiable {
    let id = UUID()
    let layerID: String
    let created: Date
    let createdBy: String
    let size: Int
    let comment: String?
}

// MARK: - Image Search Result

struct ImageSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let stars: Int
    let official: Bool
    let automated: Bool
}

struct ImageSearchFilters {
    let official: Bool?
    let automated: Bool?
    let stars: Int?
}

// MARK: - Container System Monitor Extension

extension ContainerSystemMonitor {
    
    /// Fetch list of images
    func fetchImages() async -> [ContainerImageInfo]? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            // Apple's container tool uses 'container image list' (or 'container image ls')
            let command = "\(containerPath) image list"
            process.arguments = ["-c", command]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    return ContainerImageInfo.parseList(output)
                }
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorMessage = String(data: errorData, encoding: .utf8) {
                    print("Error fetching images: \(errorMessage)")
                }
            }
            
            return []
        } catch {
            print("Error fetching images: \(error)")
            return nil
        }
    }
    
    /// Pull an image
    func pullImage(_ imageName: String, tag: String = "latest") async -> ImageOperationResult? {
        guard let containerPath = containerPath else {
            return ImageOperationResult(success: false, error: "Container path not found")
        }
        
        let fullImageName = tag.isEmpty ? imageName : "\(imageName):\(tag)"
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) image pull \(fullImageName)"
            process.arguments = ["-c", command]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()
            
            let success = process.terminationStatus == 0
            
            if !success {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return ImageOperationResult(success: false, error: errorMessage, imageName: fullImageName)
            }
            
            return ImageOperationResult(success: true, imageName: fullImageName)
            
        } catch {
            return ImageOperationResult(success: false, error: error.localizedDescription)
        }
    }
    
    /// Pull image with progress
    func pullImageWithProgress(_ imageName: String, tag: String = "latest") async -> AsyncStream<ImageProgress>? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        let fullImageName = tag.isEmpty ? imageName : "\(imageName):\(tag)"
        
        return AsyncStream { continuation in
            Task {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/sh")
                    
                    let command = "\(containerPath) image pull \(fullImageName)"
                    process.arguments = ["-c", command]
                    
                    // Set up environment
                    var environment = ProcessInfo.processInfo.environment
                    if let existingPath = environment["PATH"] {
                        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
                    } else {
                        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                    }
                    process.environment = environment
                    
                    let outputPipe = Pipe()
                    process.standardOutput = outputPipe
                    process.standardError = outputPipe
                    
                    outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                        let data = fileHandle.availableData
                        
                        if data.isEmpty {
                            continuation.finish()
                            return
                        }
                        
                        if let output = String(data: data, encoding: .utf8) {
                            // Parse progress from output
                            // This is a simplified version - actual parsing depends on output format
                            continuation.yield(ImageProgress(
                                percentage: 0,
                                currentLayer: nil,
                                totalLayers: nil,
                                status: output.trimmingCharacters(in: .whitespacesAndNewlines)
                            ))
                        }
                    }
                    
                    try process.run()
                    
                    process.terminationHandler = { _ in
                        continuation.finish()
                    }
                    
                } catch {
                    print("Error pulling image with progress: \(error)")
                    continuation.finish()
                }
            }
        }
    }
    
    /// Push an image
    func pushImage(_ imageName: String, tag: String = "latest") async -> ImageOperationResult? {
        guard let containerPath = containerPath else {
            return ImageOperationResult(success: false, error: "Container path not found")
        }
        
        let fullImageName = tag.isEmpty ? imageName : "\(imageName):\(tag)"
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) image push \(fullImageName)"
            process.arguments = ["-c", command]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()
            
            let success = process.terminationStatus == 0
            
            if !success {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return ImageOperationResult(success: false, error: errorMessage)
            }
            
            return ImageOperationResult(success: true, imageName: fullImageName)
            
        } catch {
            return ImageOperationResult(success: false, error: error.localizedDescription)
        }
    }
    
    /// Push image with progress
    func pushImageWithProgress(_ imageName: String, tag: String = "latest") async -> AsyncStream<ImageProgress>? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        let fullImageName = tag.isEmpty ? imageName : "\(imageName):\(tag)"
        
        return AsyncStream { continuation in
            Task {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/sh")
                    
                    let command = "\(containerPath) image push \(fullImageName)"
                    process.arguments = ["-c", command]
                    
                    // Set up environment
                    var environment = ProcessInfo.processInfo.environment
                    if let existingPath = environment["PATH"] {
                        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
                    } else {
                        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                    }
                    process.environment = environment
                    
                    let outputPipe = Pipe()
                    process.standardOutput = outputPipe
                    process.standardError = outputPipe
                    
                    outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                        let data = fileHandle.availableData
                        
                        if data.isEmpty {
                            continuation.finish()
                            return
                        }
                        
                        if let output = String(data: data, encoding: .utf8) {
                            // Parse progress from output
                            // This is a simplified version - actual parsing depends on output format
                            continuation.yield(ImageProgress(
                                percentage: 0,
                                currentLayer: nil,
                                totalLayers: nil,
                                status: output.trimmingCharacters(in: .whitespacesAndNewlines)
                            ))
                        }
                    }
                    
                    try process.run()
                    
                    process.terminationHandler = { _ in
                        continuation.finish()
                    }
                    
                } catch {
                    print("Error pushing image with progress: \(error)")
                    continuation.finish()
                }
            }
        }
    }
    
    /// Remove an image
    func removeImage(_ imageID: String, force: Bool = false) async -> ImageOperationResult? {
        guard let containerPath = containerPath else {
            return ImageOperationResult(success: false, error: "Container path not found")
        }
        
        // Apple's container tool uses 'container image delete' or 'container image rm'
        let commands = force ? ["image delete -f", "image rm -f"] : ["image delete", "image rm"]
        
        for cmd in commands {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                
                let command = "\(containerPath) \(cmd) \(imageID)"
                process.arguments = ["-c", command]
                
                // Set up environment
                var environment = ProcessInfo.processInfo.environment
                if let existingPath = environment["PATH"] {
                    environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
                } else {
                    environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                }
                process.environment = environment
                
                let errorPipe = Pipe()
                process.standardError = errorPipe
                
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    return ImageOperationResult(success: true)
                }
            } catch {
                continue
            }
        }
        
        return ImageOperationResult(success: false, error: "Failed to remove image")
    }
    
    /// Remove multiple images
    func removeImages(_ imageIDs: [String], force: Bool = false) async -> [ImageOperationResult] {
        var results: [ImageOperationResult] = []
        
        for imageID in imageIDs {
            if let result = await removeImage(imageID, force: force) {
                results.append(result)
            } else {
                results.append(ImageOperationResult(success: false, error: "Failed to remove \(imageID)"))
            }
        }
        
        return results
    }
    
    /// Tag an image
    func tagImage(source: String, target: String) async -> ImageOperationResult? {
        guard let containerPath = containerPath else {
            return ImageOperationResult(success: false, error: "Container path not found")
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) tag \(source) \(target)"
            process.arguments = ["-c", command]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            try process.run()
            process.waitUntilExit()
            
            let success = process.terminationStatus == 0
            return ImageOperationResult(success: success)
            
        } catch {
            return ImageOperationResult(success: false, error: error.localizedDescription)
        }
    }
    
    /// Inspect image details
    func inspectImage(_ imageID: String) async -> ImageDetails? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) inspect \(imageID)"
            process.arguments = ["-c", command]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if !data.isEmpty {
                    // Parse JSON output - simplified for now
                    return ImageDetails(
                        id: imageID,
                        tags: [],
                        size: 0,
                        created: Date(),
                        architecture: "amd64",
                        os: "linux",
                        labels: nil
                    )
                }
            }
            
            return nil
        } catch {
            print("Error inspecting image: \(error)")
            return nil
        }
    }
    
    /// Get image history
    func getImageHistory(_ imageID: String) async -> [ImageHistoryEntry]? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) history \(imageID)"
            process.arguments = ["-c", command]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if String(data: data, encoding: .utf8) != nil {
                    // Parse history output
                    return []
                }
            }
            
            return []
        } catch {
            print("Error getting image history: \(error)")
            return nil
        }
    }
    
    /// Get image layers
    func getImageLayers(_ imageID: String) async -> [String]? {
        guard containerPath != nil else {
            return nil
        }
        
        // Layers info can be extracted from inspect command
        if await inspectImage(imageID) != nil {
            return []
        }
        
        return nil
    }
    
    /// Search for images
    func searchImages(_ searchTerm: String, filters: ImageSearchFilters? = nil) async -> [ImageSearchResult]? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) search \(searchTerm)"
            process.arguments = ["-c", command]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // Parse search results
                    var results: [ImageSearchResult] = []
                    let lines = output.components(separatedBy: .newlines)
                    
                    for (index, line) in lines.enumerated() {
                        if index == 0 || line.trimmingCharacters(in: .whitespaces).isEmpty {
                            continue
                        }
                        
                        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if components.count >= 1 {
                            results.append(ImageSearchResult(
                                name: components[0],
                                description: components.count > 1 ? components[1] : "",
                                stars: 0,
                                official: false,
                                automated: false
                            ))
                        }
                    }
                    
                    return results
                }
            }
            
            return []
        } catch {
            print("Error searching images: \(error)")
            return nil
        }
    }
    
    /// Build image from Dockerfile
    func buildImage(dockerfilePath: String, imageName: String, tag: String = "latest") async -> ImageOperationResult? {
        guard let containerPath = containerPath else {
            return ImageOperationResult(success: false, error: "Container path not found")
        }
        
        let fullImageName = "\(imageName):\(tag)"
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) build -t \(fullImageName) -f \(dockerfilePath) ."
            process.arguments = ["-c", command]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()
            
            let success = process.terminationStatus == 0
            
            if !success {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return ImageOperationResult(success: false, error: errorMessage)
            }
            
            return ImageOperationResult(success: true, imageName: fullImageName)
            
        } catch {
            return ImageOperationResult(success: false, error: error.localizedDescription)
        }
    }
    
    /// Build image with progress
    func buildImageWithProgress(dockerfilePath: String, imageName: String, tag: String = "latest") async -> AsyncStream<ImageProgress>? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        let fullImageName = "\(imageName):\(tag)"
        
        return AsyncStream { continuation in
            Task {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/sh")
                    
                    let command = "\(containerPath) build -t \(fullImageName) -f \(dockerfilePath) ."
                    process.arguments = ["-c", command]
                    
                    // Set up environment
                    var environment = ProcessInfo.processInfo.environment
                    if let existingPath = environment["PATH"] {
                        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
                    } else {
                        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                    }
                    process.environment = environment
                    
                    let outputPipe = Pipe()
                    process.standardOutput = outputPipe
                    process.standardError = outputPipe
                    
                    outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                        let data = fileHandle.availableData
                        
                        if data.isEmpty {
                            continuation.finish()
                            return
                        }
                        
                        if let output = String(data: data, encoding: .utf8) {
                            continuation.yield(ImageProgress(
                                percentage: 0,
                                currentLayer: nil,
                                totalLayers: nil,
                                status: output.trimmingCharacters(in: .whitespacesAndNewlines)
                            ))
                        }
                    }
                    
                    try process.run()
                    
                    process.terminationHandler = { _ in
                        continuation.finish()
                    }
                    
                } catch {
                    print("Error building image with progress: \(error)")
                    continuation.finish()
                }
            }
        }
    }
    
    /// Export image to tar file
    func exportImage(_ imageID: String, to outputPath: String) async -> ImageOperationResult? {
        guard let containerPath = containerPath else {
            return ImageOperationResult(success: false, error: "Container path not found")
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) save \(imageID) -o \(outputPath)"
            process.arguments = ["-c", command]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            try process.run()
            process.waitUntilExit()
            
            let success = process.terminationStatus == 0
            return ImageOperationResult(success: success)
            
        } catch {
            return ImageOperationResult(success: false, error: error.localizedDescription)
        }
    }
    
    /// Import image from tar file
    func importImage(from inputPath: String) async -> ImageOperationResult? {
        guard let containerPath = containerPath else {
            return ImageOperationResult(success: false, error: "Container path not found")
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) load -i \(inputPath)"
            process.arguments = ["-c", command]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            
            try process.run()
            process.waitUntilExit()
            
            let success = process.terminationStatus == 0
            
            if success {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    return ImageOperationResult(success: true, imageName: output.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
            
            return ImageOperationResult(success: success)
            
        } catch {
            return ImageOperationResult(success: false, error: error.localizedDescription)
        }
    }
    
    /// Login to registry
    func loginToRegistry(registry: String, username: String, password: String) async -> ImageOperationResult? {
        guard let containerPath = containerPath else {
            return ImageOperationResult(success: false, error: "Container path not found")
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "echo '\(password)' | \(containerPath) login \(registry) -u \(username) --password-stdin"
            process.arguments = ["-c", command]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            try process.run()
            process.waitUntilExit()
            
            let success = process.terminationStatus == 0
            return ImageOperationResult(success: success)
            
        } catch {
            return ImageOperationResult(success: false, error: error.localizedDescription)
        }
    }
    
    /// Logout from registry
    func logoutFromRegistry(registry: String) async -> ImageOperationResult? {
        guard let containerPath = containerPath else {
            return ImageOperationResult(success: false, error: "Container path not found")
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) logout \(registry)"
            process.arguments = ["-c", command]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            try process.run()
            process.waitUntilExit()
            
            let success = process.terminationStatus == 0
            return ImageOperationResult(success: success)
            
        } catch {
            return ImageOperationResult(success: false, error: error.localizedDescription)
        }
    }
}
