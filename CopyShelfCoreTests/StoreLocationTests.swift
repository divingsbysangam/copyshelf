import Foundation
import SwiftData
import Testing
@testable import CopyShelfCore

struct StoreLocationTests {
    @Test func defaultURLIsOwnNamespaceWithoutOpeningStore() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = StoreLocation().storeURL
        #expect(url == support.appendingPathComponent("CopyShelf/CopyShelf.store"))
        #expect(Array(url.pathComponents.suffix(2)) == ["CopyShelf", "CopyShelf.store"])
        #expect(!url.pathComponents.contains("default.store"))
        #expect(!url.pathComponents.contains(where: { $0.lowercased().contains("bufferfly") || $0.lowercased().contains("luganskyy") }))
    }

    @Test func configurationsDisableExternalContainers() {
        let disk = StoreLocation(applicationSupport: URL(fileURLWithPath: "/unused-fixture")).diskConfiguration()
        let memory = StoreLocation.memoryConfiguration()
        for configuration in [disk, memory] {
            #expect(configuration.cloudKitContainerIdentifier == nil)
            #expect(configuration.groupAppContainerIdentifier == nil)
            // SwiftData's public policy wrappers do not conform to Equatable.
            // Compare their diagnostic representation with the explicit .none policy.
            #expect(String(reflecting: configuration.cloudKitDatabase) == String(reflecting: ModelConfiguration.CloudKitDatabase.none))
            #expect(String(reflecting: configuration.groupContainer) == String(reflecting: ModelConfiguration.GroupContainer.none))
        }
        #expect(!disk.isStoredInMemoryOnly)
        #expect(memory.isStoredInMemoryOnly)
        #expect(disk.url == URL(fileURLWithPath: "/unused-fixture/CopyShelf/CopyShelf.store"))
    }

    @Test func preparesOwnerOnlyDirectoryIdempotently() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("CopyShelfTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: base) }
        let location = StoreLocation(applicationSupport: base)
        try location.prepareDirectory()
        try location.prepareDirectory()
        let attributes = try FileManager.default.attributesOfItem(atPath: location.directory.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        #expect(!FileManager.default.fileExists(atPath: location.storeURL.path))
    }

    @Test func refusesSymbolicLinkDirectory() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("CopyShelfTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let target = base.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o755])
        let location = StoreLocation(applicationSupport: base)
        try FileManager.default.createSymbolicLink(at: location.directory, withDestinationURL: target)
        #expect(throws: CocoaError.self) { try location.prepareDirectory() }
        let permissions = try FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o755)
    }
}
