//
//  ICloudTransferManager.swift
//  MobileOrg
//
//  Created by Artem Loenko on 08/10/2019.
//  Copyright © 2019 Sean Escriva. All rights reserved.
//

import Foundation

final class ICloudTransferManager: NSObject {

    override init() {
        super.init()
        self.obtainContainer()
    }

    @objc var isAvailable: Bool {
        // FIXME: handle the case and show a warning that iCloud is not available
        return self.ubiquityIdentityToken != nil
    }

    // MARK: Private

    // Reflects the current state of iCloud account
    private var ubiquityIdentityToken: NSObjectProtocol? {
        assert(Thread.isMainThread)
        return FileManager.default.ubiquityIdentityToken
    }

    // We populate it in the init but the execution is asynchronous, can be nil if you are too fast
    private var containerURL: URL?

    private func obtainContainer() {
        guard self.containerURL == nil else { return }
        DispatchQueue.global().async {
            // If you specify nil for this parameter, this method returns the first container listed in the com.apple.developer.ubiquity-container-identifiers entitlement array
            let url = FileManager.default.url(forUbiquityContainerIdentifier: nil)
            DispatchQueue.main.async {
                self.containerURL = url
            }
        }
    }

}

// Mimic TransferManager conformance
extension ICloudTransferManager {
    @objc static let instance = ICloudTransferManager()
}
