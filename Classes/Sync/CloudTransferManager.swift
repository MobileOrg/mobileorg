//
//  ICloudTransferManager.swift
//  MobileOrg
//
//  Created by Artem Loenko on 08/10/2019.
//  Copyright © 2019 Artem Loenko. All rights reserved.
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

import Foundation

final class CloudTransferManager: NSObject {

    @objc public var iCloudStorageDocumentsURL: URL? { return self.containerURL }
    @objc public let indexFilename = "index.org" // FIXME: customizable via Settings?

    private var transfers = [ TransferContext ]()
    private var activeTransfer: TransferContext? = nil
    private var paused = false
    private var active = false

    override init() {
        super.init()
        self.obtainContainer()
    }

    @objc var isAvailable: Bool {
        return self.ubiquityIdentityToken != nil
    }

    // MARK: Private functions

    // Reflects the current state of iCloud account
    private var ubiquityIdentityToken: NSObjectProtocol? {
        assert(Thread.isMainThread)
        return FileManager.default.ubiquityIdentityToken
    }

    // We populate it in the init but the execution is asynchronous, can be nil if you are too fast
    private var containerURL: URL?

    // This function is called during the initalization of the class
    // No fatalErrors here, please, or it will be impossible to run an application to access the data
    private func obtainContainer() {
        guard self.containerURL == nil else { return }
        DispatchQueue.global().async {
            // If you specify nil for this parameter, this method returns the first container listed in the com.apple.developer.ubiquity-container-identifiers entitlement array
            let url = FileManager.default.url(forUbiquityContainerIdentifier: nil)
            guard let documentURL = url?.appendingPathComponent("Documents") else { return }
            if !FileManager.default.fileExists(atPath: documentURL.path) {
                do {
                    try FileManager.default.createDirectory(at: documentURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    UIAlertController.show("iCloud Error", message: error.localizedDescription)
                    return
                }
            }
            // Start pre-synchronization
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: documentURL)
            } catch {
                UIAlertController.show("iCloud Error", message: error.localizedDescription)
            }
            DispatchQueue.main.async { self.containerURL = documentURL }
        }
    }

    // MARK: Processing requests

    private func dispatchNextTransfer() {
        guard !self.paused else { return }
        guard let syncManager = SyncManager.instance(),
            self.transfers.count > 0,
            self.transfers.first?.remoteUrl != nil,
            !self.active else { return }

        let activeTransfer = transfers.removeFirst()
        activeTransfer.success = true
        syncManager.transferFilename = activeTransfer.remoteUrl.lastPathComponent
        syncManager.progressTotal = 0
        syncManager.updateStatus()
        self.active = true
        self.processRequest(activeTransfer)
    }

    private func processRequest(_ transfer: TransferContext) {
        self.activeTransfer = transfer
        guard self.containerURL != nil else {
            transfer.errorText = "Cannot reach iCloud storage.";
            transfer.success = false
            self.requestFinished(transfer)
            return
        }
        guard !transfer.dummy else {
            transfer.success = true
            self.requestFinished(transfer)
            return
        }

        guard let remoteURL = transfer.remoteUrl.path.removingPercentEncoding else {
            fatalError("Cannot create remote URL from \(transfer.remoteUrl.path)")
        }
        guard let localURL = transfer.localFile.removingPercentEncoding else {
            fatalError("Cannot create local URL from \(String(describing: transfer.localFile))")
        }
        switch transfer.transferType {
        case TransferTypeDownload:
            self.downloadFile(from: remoteURL, to: localURL)
        case TransferTypeUpload:
            self.uploadFile(to: remoteURL, from: localURL)
        default:
            fatalError("Unsupported transfer type: \(transfer.transferType)")
        }
    }

    private func requestFinished(_ transfer: TransferContext) {
        if !transfer.success && transfer.abortOnFailure { self.transfers.removeAll() }
        if transfer.success {
            transfer.delegate.transferComplete?(transfer)
        } else {
            transfer.delegate.transferFailed?(transfer)
        }
        self.active = false
        self.activeTransfer = nil
        self.dispatchNextTransfer()
    }

    // MARK: Upload & download

    private func uploadFile(to: String, from: String) {
        guard let activeTransfer = self.activeTransfer else {
            fatalError("The active transfer is expected but does not exist.")
        }
        defer { self.requestFinished(activeTransfer) }

        do {
            assert(FileManager.default.fileExists(atPath: from))
            assert(FileManager.default.isReadableFile(atPath: from))
            // FIXME: move to the background thread
            if FileManager.default.fileExists(atPath: to) {
                try FileManager.default.removeItem(atPath: to)
            }
            try FileManager.default.copyItem(atPath: from, toPath: to)
        } catch {
            activeTransfer.success = false
            activeTransfer.errorText = error.localizedDescription
            print(error.localizedDescription)
        }

        SyncManager.instance()?.progressTotal = 100
        SyncManager.instance()?.progressCurrent = 100
        SyncManager.instance()?.updateStatus()
        activeTransfer.success = true
    }

    private func downloadFile(from: String, to: String) {
        guard let activeTransfer = self.activeTransfer else {
            fatalError("The active transfer is expected but does not exist.")
        }
        defer { self.requestFinished(activeTransfer) }

        do {
            // FIXME: move to the background thread
            try FileManager.default.copyItem(atPath: from, toPath: to)
        } catch {
            activeTransfer.success = false
            activeTransfer.errorText = error.localizedDescription
            print(error.localizedDescription)
        }

        SyncManager.instance()?.progressTotal = 100
        SyncManager.instance()?.progressCurrent = 100
        SyncManager.instance()?.updateStatus()
        activeTransfer.success = true
    }

}

// Mimic TransferManager conformance
extension CloudTransferManager {
    @objc static let instance = CloudTransferManager()

    @objc func enqueueTransfer(_ transfer: TransferContext) {
        self.transfers.append(transfer)
        ShowStatusView()
        self.dispatchNextTransfer()
    }

    @objc func resume() {
        self.paused = false
        self.dispatchNextTransfer()
    }

    @objc func pause() { self.paused = true }
    @objc func busy() -> Bool { return (transfers.count > 0 || active) }
    @objc func queueSize() -> Int { return self.transfers.count }
    @objc func abort() { self.transfers.removeAll() }
}
