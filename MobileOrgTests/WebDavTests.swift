//
//  WebDavTests.swift
//  MobileOrg
//
//  Created by Mario Martelli on 27.04.17.
//  Copyright © 2017 Sean Escriva. All rights reserved.
//

import XCTest
import CoreData

@testable import MobileOrg

class WebDavTests: XCTestCase {
  var moc:NSManagedObjectContext?

  override func setUp() {
    super.setUp()

    let context = setUpInMemoryManagedObjectContext()
    moc = context


    PersistenceStack.shared.moc = moc!

    Settings.instance().serverMode = ServerModeWebDav
    Settings.instance().username = "schnuddelhuddel"
    Settings.instance().password = "schnuddelhuddel"
    Settings.instance().indexUrl = URL(string:  "https://mobileOrgWebDav.schnuddelhuddel.de:32773/index.org")

  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }

//  func testWebDAVSync() {
//
//    SyncManager.instance().sync()
//
//    // Sync is async, so we have to wait for completion
//    sleep(4)
//
//    do {
//      let fetchRequest = NSFetchRequest<Node>(entityName: "Node")
//      // fetchRequest.predicate = NSPredicate (format: "heading == %@", "on Level 1.1.1.5")
//
//      let nodes = try self.moc!.fetch(fetchRequest)
//
//      XCTAssertEqual(nodes.count, 136)
//
//    } catch _ { XCTFail() }
//
//  }

  func setUpInMemoryManagedObjectContext() -> NSManagedObjectContext {
    let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle.main])!

    let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
    try! persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)

    let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
    
    return managedObjectContext
  }
}
