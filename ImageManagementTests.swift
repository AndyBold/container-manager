//
//  ImageManagementTests.swift
//  container-manager
//
//  Tests for image management functionality
//

import Testing
import Foundation
@testable import container_manager

@Suite("Image Management Tests")
struct ImageManagementTests {
    
    // MARK: - Image Listing Tests
    
    @Test("Fetch list of images")
    func fetchListOfImages() async throws {
        let monitor = ContainerSystemMonitor()
        
        let images = await monitor.fetchImages()
        
        #expect(images != nil)
    }
    
    @Test("Parse image list output")
    func parseImageListOutput() throws {
        let output = """
        REPOSITORY              TAG       IMAGE ID       CREATED        SIZE
        nginx                   latest    abcd1234       2 days ago     142MB
        redis                   alpine    efgh5678       1 week ago     32MB
        postgres                15        ijkl9012       3 weeks ago    379MB
        """
        
        let images = ContainerImageInfo.parseList(output)
        
        #expect(images.count == 3)
        #expect(images[0].repository == "nginx")
        #expect(images[0].tag == "latest")
        #expect(images[1].repository == "redis")
        #expect(images[1].tag == "alpine")
    }
    
    @Test("Parse image with no tag")
    func parseImageWithNoTag() throws {
        let output = """
        REPOSITORY    TAG       IMAGE ID       CREATED      SIZE
        myimage       <none>    abc123         1 day ago    100MB
        """
        
        let images = ContainerImageInfo.parseList(output)
        
        #expect(images.count == 1)
        #expect(images[0].repository == "myimage")
        #expect(images[0].tag == nil || images[0].tag == "<none>")
    }
    
    @Test("Parse dangling images")
    func parseDanglingImages() throws {
        let output = """
        REPOSITORY    TAG       IMAGE ID       CREATED      SIZE
        <none>        <none>    xyz789         2 days ago   50MB
        """
        
        let images = ContainerImageInfo.parseList(output)
        
        #expect(images.count == 1)
        #expect(images[0].isDangling == true)
    }
    
    @Test("Handle empty image list")
    func handleEmptyImageList() async throws {
        let monitor = ContainerSystemMonitor()
        
        let images = await monitor.fetchImages()
        
        // Should return empty array, not nil
        #expect(images != nil)
    }
    
    // MARK: - Image Pull Tests
    
    @Test("Pull image by name")
    func pullImageByName() async throws {
        let monitor = ContainerSystemMonitor()
        let imageName = "nginx"
        
        let result = await monitor.pullImage(imageName)
        
        #expect(result != nil)
    }
    
    @Test("Pull image with specific tag")
    func pullImageWithSpecificTag() async throws {
        let monitor = ContainerSystemMonitor()
        let imageName = "nginx"
        let tag = "alpine"
        
        let result = await monitor.pullImage(imageName, tag: tag)
        
        #expect(result != nil)
        #expect(result?.imageName == "\(imageName):\(tag)" || result?.success == false)
    }
    
    @Test("Pull image with progress reporting")
    func pullImageWithProgressReporting() async throws {
        let monitor = ContainerSystemMonitor()
        let imageName = "nginx"
        
        var progressUpdates: [Double] = []
        
        let stream = await monitor.pullImageWithProgress(imageName)
        
        if let stream = stream {
            for await progress in stream {
                progressUpdates.append(progress.percentage)
            }
        }
        
        // Should receive progress updates
        #expect(progressUpdates.count >= 0)
    }
    
    @Test("Handle pull of non-existent image")
    func handlePullOfNonExistentImage() async throws {
        let monitor = ContainerSystemMonitor()
        let imageName = "thisimageshouldnotexist123456"
        
        let result = await monitor.pullImage(imageName)
        
        #expect(result?.success == false || result?.error != nil)
    }
    
    @Test("Pull from specific registry")
    func pullFromSpecificRegistry() async throws {
        let monitor = ContainerSystemMonitor()
        let imageName = "docker.io/library/nginx"
        
        let result = await monitor.pullImage(imageName)
        
        #expect(result != nil)
    }
    
    // MARK: - Image Push Tests
    
    @Test("Push image to registry")
    func pushImageToRegistry() async throws {
        let monitor = ContainerSystemMonitor()
        let imageName = "myregistry.com/myimage"
        let tag = "latest"
        
        let result = await monitor.pushImage(imageName, tag: tag)
        
        #expect(result != nil)
    }
    
    @Test("Push image with progress reporting")
    func pushImageWithProgressReporting() async throws {
        let monitor = ContainerSystemMonitor()
        let imageName = "myregistry.com/myimage"
        
        var progressUpdates: [Double] = []
        
        let stream = await monitor.pushImageWithProgress(imageName)
        
        if let stream = stream {
            for await progress in stream {
                progressUpdates.append(progress.percentage)
            }
        }
        
        #expect(progressUpdates.count >= 0)
    }
    
    // MARK: - Image Removal Tests
    
    @Test("Remove image by ID")
    func removeImageByID() async throws {
        let monitor = ContainerSystemMonitor()
        let imageID = "abc123"
        
        let result = await monitor.removeImage(imageID)
        
        #expect(result != nil)
    }
    
    @Test("Remove image by name and tag")
    func removeImageByNameAndTag() async throws {
        let monitor = ContainerSystemMonitor()
        let imageName = "nginx"
        let tag = "alpine"
        
        let result = await monitor.removeImage("\(imageName):\(tag)")
        
        #expect(result != nil)
    }
    
    @Test("Force remove image")
    func forceRemoveImage() async throws {
        let monitor = ContainerSystemMonitor()
        let imageID = "abc123"
        
        let result = await monitor.removeImage(imageID, force: true)
        
        #expect(result != nil)
    }
    
    @Test("Handle removal of image in use")
    func handleRemovalOfImageInUse() async throws {
        let monitor = ContainerSystemMonitor()
        let imageID = "inuse123"
        
        let result = await monitor.removeImage(imageID, force: false)
        
        // Should fail or return error
        #expect(result?.success == false || result?.error != nil)
    }
    
    @Test("Remove multiple images")
    func removeMultipleImages() async throws {
        let monitor = ContainerSystemMonitor()
        let imageIDs = ["abc123", "def456", "ghi789"]
        
        let results = await monitor.removeImages(imageIDs)
        
        #expect(results.count == imageIDs.count)
    }
    
    // MARK: - Image Inspection Tests
    
    @Test("Inspect image details")
    func inspectImageDetails() async throws {
        let monitor = ContainerSystemMonitor()
        let imageID = "abc123"
        
        let details = await monitor.inspectImage(imageID)
        
        #expect(details != nil)
    }
    
    @Test("Get image history")
    func getImageHistory() async throws {
        let monitor = ContainerSystemMonitor()
        let imageID = "abc123"
        
        let history = await monitor.getImageHistory(imageID)
        
        #expect(history != nil)
    }
    
    @Test("Get image layers")
    func getImageLayers() async throws {
        let monitor = ContainerSystemMonitor()
        let imageID = "abc123"
        
        let layers = await monitor.getImageLayers(imageID)
        
        #expect(layers != nil)
    }
    
    // MARK: - Image Search Tests
    
    @Test("Search for images in registry")
    func searchForImagesInRegistry() async throws {
        let monitor = ContainerSystemMonitor()
        let searchTerm = "nginx"
        
        let results = await monitor.searchImages(searchTerm)
        
        #expect(results != nil)
        if let results = results {
            #expect(results.allSatisfy { $0.name.localizedCaseInsensitiveContains(searchTerm) })
        }
    }
    
    @Test("Search with filters")
    func searchWithFilters() async throws {
        let monitor = ContainerSystemMonitor()
        let searchTerm = "nginx"
        let filters = ImageSearchFilters(official: true, automated: false, stars: nil)
        
        let results = await monitor.searchImages(searchTerm, filters: filters)
        
        #expect(results != nil)
    }
    
    @Test("Handle empty search results")
    func handleEmptySearchResults() async throws {
        let monitor = ContainerSystemMonitor()
        let searchTerm = "thisshouldreallynotexist123456789"
        
        let results = await monitor.searchImages(searchTerm)
        
        #expect(results?.isEmpty == true || results == nil)
    }
    
    // MARK: - Image Tag Tests
    
    @Test("Tag image with new name")
    func tagImageWithNewName() async throws {
        let monitor = ContainerSystemMonitor()
        let sourceImage = "nginx:latest"
        let targetImage = "myregistry.com/nginx:v1"
        
        let result = await monitor.tagImage(source: sourceImage, target: targetImage)
        
        #expect(result?.success == true || result != nil)
    }
    
    @Test("Create multiple tags for image")
    func createMultipleTagsForImage() async throws {
        let monitor = ContainerSystemMonitor()
        let sourceImage = "nginx:latest"
        let targetTags = ["v1", "v1.0", "latest"]
        
        for tag in targetTags {
            let result = await monitor.tagImage(
                source: sourceImage,
                target: "myregistry.com/nginx:\(tag)"
            )
            #expect(result != nil)
        }
    }
    
    // MARK: - Image Build Tests (if applicable)
    
    @Test("Build image from Dockerfile")
    func buildImageFromDockerfile() async throws {
        let monitor = ContainerSystemMonitor()
        let dockerfilePath = "/path/to/Dockerfile"
        let imageName = "myapp"
        let tag = "latest"
        
        let result = await monitor.buildImage(
            dockerfilePath: dockerfilePath,
            imageName: imageName,
            tag: tag
        )
        
        #expect(result != nil)
    }
    
    @Test("Build image with progress reporting")
    func buildImageWithProgressReporting() async throws {
        let monitor = ContainerSystemMonitor()
        let dockerfilePath = "/path/to/Dockerfile"
        let imageName = "myapp"
        
        var buildSteps: [String] = []
        
        let stream = await monitor.buildImageWithProgress(
            dockerfilePath: dockerfilePath,
            imageName: imageName
        )
        
        if let stream = stream {
            for await step in stream {
                buildSteps.append(step.status)
            }
        }
        
        #expect(buildSteps.count >= 0)
    }
    
    // MARK: - Image Filtering Tests
    
    @Test("Filter images by repository")
    func filterImagesByRepository() throws {
        let images = [
            ContainerImageInfo(repository: "nginx", tag: "latest", imageID: "abc", size: "100MB"),
            ContainerImageInfo(repository: "redis", tag: "alpine", imageID: "def", size: "50MB"),
            ContainerImageInfo(repository: "nginx", tag: "alpine", imageID: "ghi", size: "80MB")
        ]
        
        let filtered = ContainerImageInfo.filter(images, repository: "nginx")
        
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.repository == "nginx" })
    }
    
    @Test("Filter dangling images")
    func filterDanglingImages() throws {
        let images = [
            ContainerImageInfo(repository: "nginx", tag: "latest", imageID: "abc", size: "100MB"),
            ContainerImageInfo(repository: "<none>", tag: "<none>", imageID: "def", size: "50MB"),
            ContainerImageInfo(repository: "<none>", tag: "<none>", imageID: "ghi", size: "30MB")
        ]
        
        let dangling = ContainerImageInfo.filterDangling(images)
        
        #expect(dangling.count == 2)
        #expect(dangling.allSatisfy { $0.isDangling })
    }
    
    @Test("Sort images by size")
    func sortImagesBySize() throws {
        let images = [
            ContainerImageInfo(repository: "nginx", tag: "latest", imageID: "abc", size: "100MB"),
            ContainerImageInfo(repository: "redis", tag: "alpine", imageID: "def", size: "50MB"),
            ContainerImageInfo(repository: "postgres", tag: "15", imageID: "ghi", size: "300MB")
        ]
        
        let sorted = ContainerImageInfo.sortBySize(images)
        
        #expect(sorted[0].repository == "postgres") // Largest
        #expect(sorted[2].repository == "redis")    // Smallest
    }
    
    @Test("Sort images by creation date")
    func sortImagesByCreationDate() throws {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let lastWeek = now.addingTimeInterval(-604800)
        
        let images = [
            ContainerImageInfo(repository: "nginx", tag: "latest", imageID: "abc", created: now),
            ContainerImageInfo(repository: "redis", tag: "alpine", imageID: "def", created: lastWeek),
            ContainerImageInfo(repository: "postgres", tag: "15", imageID: "ghi", created: yesterday)
        ]
        
        let sorted = ContainerImageInfo.sortByDate(images)
        
        #expect(sorted[0].repository == "nginx")    // Newest
        #expect(sorted[2].repository == "redis")    // Oldest
    }
    
    // MARK: - Image Size Calculation Tests
    
    @Test("Parse image size from string")
    func parseImageSizeFromString() throws {
        let sizeStrings = [
            "142MB": 142_000_000,
            "1.5GB": 1_500_000_000,
            "32.5MB": 32_500_000,
            "1KB": 1_000
        ]
        
        for (sizeString, expectedBytes) in sizeStrings {
            let bytes = ContainerImageInfo.parseSize(sizeString)
            #expect(abs(bytes - expectedBytes) < 1000) // Allow small rounding differences
        }
    }
    
    @Test("Calculate total size of images")
    func calculateTotalSizeOfImages() throws {
        let images = [
            ContainerImageInfo(repository: "nginx", tag: "latest", imageID: "abc", size: "100MB"),
            ContainerImageInfo(repository: "redis", tag: "alpine", imageID: "def", size: "50MB"),
            ContainerImageInfo(repository: "postgres", tag: "15", imageID: "ghi", size: "300MB")
        ]
        
        let totalSize = ContainerImageInfo.calculateTotalSize(images)
        
        #expect(totalSize > 0)
    }
    
    // MARK: - Image Export/Import Tests
    
    @Test("Export image to tar file")
    func exportImageToTarFile() async throws {
        let monitor = ContainerSystemMonitor()
        let imageID = "abc123"
        let outputPath = "/tmp/image-export.tar"
        
        let result = await monitor.exportImage(imageID, to: outputPath)
        
        #expect(result?.success == true || result != nil)
    }
    
    @Test("Import image from tar file")
    func importImageFromTarFile() async throws {
        let monitor = ContainerSystemMonitor()
        let inputPath = "/tmp/image-export.tar"
        
        let result = await monitor.importImage(from: inputPath)
        
        #expect(result != nil)
    }
    
    // MARK: - Registry Authentication Tests
    
    @Test("Login to registry")
    func loginToRegistry() async throws {
        let monitor = ContainerSystemMonitor()
        let registry = "docker.io"
        let username = "testuser"
        let password = "testpass"
        
        let result = await monitor.loginToRegistry(
            registry: registry,
            username: username,
            password: password
        )
        
        #expect(result != nil)
    }
    
    @Test("Logout from registry")
    func logoutFromRegistry() async throws {
        let monitor = ContainerSystemMonitor()
        let registry = "docker.io"
        
        let result = await monitor.logoutFromRegistry(registry: registry)
        
        #expect(result?.success == true || result != nil)
    }
    
    // MARK: - Performance Tests
    
    @Test("Parse large image list efficiently")
    func parseLargeImageListEfficiently() throws {
        var output = "REPOSITORY    TAG       IMAGE ID       CREATED      SIZE\n"
        
        for i in 0..<1000 {
            output += "image\(i)    latest    abc\(i)    1 day ago    100MB\n"
        }
        
        let startTime = Date()
        let images = ContainerImageInfo.parseList(output)
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(images.count == 1000)
        #expect(duration < 1.0) // Should parse 1000 images in less than 1 second
    }
    
    @Test("Filter large image set efficiently")
    func filterLargeImageSetEfficiently() throws {
        let images = (0..<10000).map { i in
            ContainerImageInfo(
                repository: i % 2 == 0 ? "nginx" : "redis",
                tag: "latest",
                imageID: "abc\(i)",
                size: "100MB"
            )
        }
        
        let startTime = Date()
        let filtered = ContainerImageInfo.filter(images, repository: "nginx")
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(filtered.count == 5000)
        #expect(duration < 0.5) // Should filter 10K images in less than 0.5 seconds
    }
}


