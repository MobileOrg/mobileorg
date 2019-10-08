//
//  ICloudTransferManager.swift
//  MobileOrg
//
//  Created by Artem Loenko on 08/10/2019.
//  Copyright © 2019 Sean Escriva. All rights reserved.
//

import Foundation

final class ICloudTransferManager: NSObject {

}

// Mimic TransferManager conformance
extension ICloudTransferManager {
    @objc static let instance = ICloudTransferManager()
}
