//
//  CloudTransferManagerTests.swift
//  MobileOrgTests
//
//  Created by Artem Loenko on 10/10/2019.
//  Copyright © 2019 Artem Loenko.
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//

import XCTest
@testable import MobileOrg

class CloudTransferManagerTests: XCTestCase {

    private var lastKnownCloudStorageDocumentsURL: URL?
    override func tearDown() {
        self.cleanUpDocuments()
        self.cleanUpCloudDocuments()
        self.lastKnownCloudStorageDocumentsURL = nil
    }

    private func cleanUpDocuments() {
        // Clean up ~/Documents
        let path = NSString(string: "~/Documents").expandingTildeInPath
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: path) else { return }
        for filename in files {
            guard filename.starts(with: "\(type(of: self))") else { continue }
            try? FileManager.default.removeItem(atPath: "\(path)\\\(filename)")
        }
    }

    private func cleanUpCloudDocuments() {
        // Clean up iCloud storage
        guard let url = self.lastKnownCloudStorageDocumentsURL,
            let files = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return }
        for filename in files {
            guard filename.starts(with: "\(type(of: self))") else { continue }
            let filePath = url.appendingPathComponent(filename)
            try? FileManager.default.removeItem(atPath: filePath.path)
        }
    }

    // MARK: Tests

    func test_thatManagerInitializedInProperState() {
        let sut = CloudTransferManager()
        guard sut.isAvailable else {
            print("iCloud is not available in the simulator. Skipping the test.")
            return
        }

        XCTAssertFalse(sut.busy())
        XCTAssertEqual(sut.queueSize(), 0)
    }

    func test_thatManagerFailsCorrectlyOnDownloadWhenTransferContextIsMalformed() {
        self.ensureTransferContextFailureBehavior(for: TransferTypeDownload)
    }

    func test_thatManagerFailsCorrectlyOnUploadWhenTransferContextIsMailformed() {
        self.ensureTransferContextFailureBehavior(for: TransferTypeUpload)
    }

    func test_thatManagerRespectsPauseResumeOptions() {
        // Given
        let sut = CloudTransferManager()
        guard sut.isAvailable else {
            print("iCloud is not available in the simulator. Skipping the test.")
            return
        }

        // When
        sut.pause()
        let transferDelegate = MockTransferManagerDelegate()
        let transferContext = self.mockTransferContext(with: TransferTypeUpload, delegate: transferDelegate)

        // Then
        transferDelegate.onTransferComplete = { _ in XCTFail("Sut is on pause.") }
        transferDelegate.onTransferFailed = { _ in XCTFail("Sut is on pause.") }
        sut.enqueueTransfer(transferContext)

        XCTAssertTrue(sut.busy())
        XCTAssertEqual(sut.queueSize(), 1)

        var onTransferFailedWasCalled = false
        transferDelegate.onTransferComplete = { _ in XCTFail("Cannot be completed.") }
        transferDelegate.onTransferFailed = { _ in onTransferFailedWasCalled = true }
        sut.resume()
        XCTAssertTrue(onTransferFailedWasCalled)
    }

    func test_thatManagerHandlesAbortAppropriately() {
        // Given
        let sut = CloudTransferManager()
        guard sut.isAvailable else {
            print("iCloud is not available in the simulator. Skipping the test.")
            return
        }

        // When
        let transferDelegate = MockTransferManagerDelegate()
        let transferContext = self.mockTransferContext(with: TransferTypeUpload, delegate: transferDelegate)
        transferDelegate.onTransferComplete = { _ in XCTFail("Sut is not running.") }
        transferDelegate.onTransferFailed = { _ in XCTFail("Sut is not running.") }

        // Then
        sut.pause()
        sut.enqueueTransfer(transferContext)
        XCTAssertEqual(sut.queueSize(), 1)
        sut.abort()
        XCTAssertEqual(sut.queueSize(), 0)
    }

    func test_thatManagerHandlesUploadProperly() {
        self.tranferFileBetweenStorages(for: TransferTypeUpload)
    }

    func test_thatManagerHandlesDownloadProperly() {
        self.tranferFileBetweenStorages(for: TransferTypeDownload)
    }

    // MARK: Helpers

    private func tranferFileBetweenStorages(for type: TransferType) {
        // Given
        let sut = CloudTransferManager()
        guard sut.isAvailable else {
            print("iCloud is not available in the simulator. Skipping the test.")
            return
        }
        self.waitForCloudURL(for: sut)

        // When
        XCTAssertNotNil(sut.iCloudStorageDocumentsURL)
        let (localFile, remoteURL) = { () -> (String, URL) in
            if type == TransferTypeUpload {
                let tempLocalFile = self.createLocalFile()
                let tempCloudFile = (sut.iCloudStorageDocumentsURL?.appendingPathComponent(String(tempLocalFile.split(separator: "/").last!)))!
                return (tempLocalFile, tempCloudFile)
            } else {
                let tempCloudFile = self.createCloudFile(sut: sut)!
                let tempLocalFile = NSString(string: "~/Documents/\(tempCloudFile.lastPathComponent)").expandingTildeInPath
                return (tempLocalFile, tempCloudFile)
            }
        }()
        let transferDelegate = MockTransferManagerDelegate()
        let transferContext = self.mockTransferContext(
            with: type,
            delegate: transferDelegate,
            remoteURL: remoteURL,
            localFile: localFile)
        let transferExpectation = expectation(description: "Wait for the result")
        transferDelegate.onTransferFailed = { _ in XCTFail("The transfer suppose to succeed.") }
        transferDelegate.onTransferComplete = { _ in transferExpectation.fulfill() }

        // Then
        sut.enqueueTransfer(transferContext)
        wait(for: [ transferExpectation ], timeout: 1)
    }

    private func createCloudFile(sut: CloudTransferManager, with content: String? = "TestData") -> URL? {
        guard let cloudURL = sut.iCloudStorageDocumentsURL else {
            XCTFail("iCloud URL is not available.")
            return nil
        }
        let path = cloudURL.appendingPathComponent("\(type(of: self))-\(UUID().uuidString).org")
        let data = content?.data(using: .utf8)!
        FileManager.default.createFile(atPath: path.path, contents: data, attributes: nil)
        return path
    }

    private func createLocalFile(with content: String? = "TestData") -> String {
        let path = NSString(string: "~/Documents/\(type(of: self))-\(UUID().uuidString).org").expandingTildeInPath
        let data = content?.data(using: .utf8)!
        FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        return path
    }

    private func waitForCloudURL(for sut: CloudTransferManager) {
        // We have to wait a bit for a proper URL from iCloud storage...
        let iCloudStorageDocumentsURLExpectation = expectation(description: "Waiting for iCloudStorageDocumentsURL...")
        DispatchQueue.global(qos: .userInitiated).async {
            while(true) {
                guard sut.iCloudStorageDocumentsURL != nil else {
                    Thread.sleep(forTimeInterval: 0.25)
                    continue
                }
                self.lastKnownCloudStorageDocumentsURL = sut.iCloudStorageDocumentsURL
                DispatchQueue.main.async { iCloudStorageDocumentsURLExpectation.fulfill() }
                break
            }
        }
        wait(for: [ iCloudStorageDocumentsURLExpectation ], timeout: 1)
    }

    private func ensureTransferContextFailureBehavior(for type: TransferType) {
        // Given
        let sut = CloudTransferManager()
        guard sut.isAvailable else {
            print("iCloud is not available in the simulator. Skipping the test.")
            return
        }

        // When
        let transferDelegate = MockTransferManagerDelegate()
        let transferContext = self.mockTransferContext(with: type, delegate: transferDelegate)

        // Then
        transferDelegate.onTransferComplete = { _ in XCTFail("The transfer has to fail.") }
        var onTransferFailedWasCalled = false
        transferDelegate.onTransferFailed = { context in
            onTransferFailedWasCalled = true
            XCTAssertEqual(transferContext, context)
            XCTAssertFalse(transferContext.success)
            XCTAssertNotNil(transferContext.errorText)
        }

        sut.enqueueTransfer(transferContext)
        XCTAssertTrue(onTransferFailedWasCalled)
    }

    // Will always fail with default `remoteURL` and `localFile` arguments
    private func mockTransferContext(
        with type: TransferType,
        delegate: MockTransferManagerDelegate? = nil,
        remoteURL: URL? = URL(string: "unreachable:///\(UUID().uuidString)")!,
        localFile: String? = "unreachable:////\(UUID().uuidString)") -> TransferContext {
        let context = TransferContext()
        context.remoteUrl = remoteURL
        context.localFile = localFile
        context.transferType = type
        context.delegate = delegate
        return context
    }

}

private class MockTransferManagerDelegate: NSObject, TransferManagerDelegate {
    var onTransferFailed: ((_ context: TransferContext) -> Void)?
    func transferFailed(_ context: TransferContext!) { self.onTransferFailed?(context) }

    var onTransferComplete: ((_ context: TransferContext) -> Void)?
    func transferComplete(_ context: TransferContext!) { self.onTransferComplete?(context) }
}
