//
//  PersistenceStack.swift
//  MobileOrg
//
//  Created by Mario Martelli on 28.04.17.
//  Copyright © 2017 Mario Martelli. All rights reserved.
//

import Foundation
import CoreData

@objc final class PersistenceStack:NSObject {

  static let shared = PersistenceStack()

  var moc:NSManagedObjectContext

  private override init() {
    self.moc = AppInstance().managedObjectContext
  }
}

