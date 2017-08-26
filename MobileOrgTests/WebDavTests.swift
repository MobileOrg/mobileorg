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
    Settings.instance().encryptionPassword = "SchnuddelHuddel"

  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }

  func testWebDAVSync() {

    let syncExpectation = expectation(description: "Sync")
    SyncManager.instance().sync()

    let dispatchTime = DispatchTime.now() + Double(4000000000) / Double(NSEC_PER_SEC)
    DispatchQueue.main.asyncAfter (deadline: dispatchTime,
                                   execute: {
                                    (Void) -> (Void) in

                                    do {
                                      let fetchRequest = NSFetchRequest<Node>(entityName: "Node")
                                      // fetchRequest.predicate = NSPredicate (format: "heading == %@", "on Level 1.1.1.5")

                                      let nodes = try self.moc!.fetch(fetchRequest)
                                      syncExpectation.fulfill()
                                      XCTAssertEqual(nodes.count, 136)

                                    } catch _ { XCTFail() }
    })

    waitForExpectations(timeout: 4, handler: nil)

  }

  func testSyncChangesOnMobile() {

    let syncExpectation = expectation(description: "Sync")
    SyncManager.instance().sync()

    let dispatchTime = DispatchTime.now() + Double(4000000000) / Double(NSEC_PER_SEC)
    DispatchQueue.main.asyncAfter (deadline: dispatchTime,
                                   execute: {
                                    (Void) -> (Void) in

                                    do {

                                      let fetchRequest = NSFetchRequest<Node>(entityName: "Node")
                                      fetchRequest.predicate = NSPredicate (format: "heading == %@", "Seamless integration of Cloud services")

                                      let nodes = try self.moc!.fetch(fetchRequest)
                                      print(nodes.count)
                                      if nodes.count == 0 {
                                        XCTFail()
                                        return
                                      }

                                      // Make local changes and sync again
                                      let tagEditController = TagEditController(node: nodes.first!)

                                      tagEditController?.recentTagString = "Test456"
                                      tagEditController?.commitNewTag()

                                      Save()

                                      SyncManager.instance().sync()
                                      syncExpectation.fulfill()
                                      XCTAssertEqual(nodes.first?.tags, ":Test456:")

                                    } catch _ { XCTFail() }
    })

    waitForExpectations(timeout: 4, handler: nil)
  }

  func testSyncChangesOnMobileReverse() {

    let syncExpectation = expectation(description: "Sync")
    SyncManager.instance().sync()

    let dispatchTime = DispatchTime.now() + Double(4000000000) / Double(NSEC_PER_SEC)
    DispatchQueue.main.asyncAfter (deadline: dispatchTime,
                                   execute: {
                                    (Void) -> (Void) in

                                    do {

                                      let fetchRequest = NSFetchRequest<Node>(entityName: "Node")
                                      fetchRequest.predicate = NSPredicate (format: "heading == %@", "Seamless integration of Cloud services")

                                      let nodes = try self.moc!.fetch(fetchRequest)

                                      if nodes.count == 0 {
                                        XCTFail()
                                        return
                                      }

                                      // Make local changes and sync again
                                      let tagEditController = TagEditController(node: nodes.first!)

                                      tagEditController?.recentTagString = ""
                                      tagEditController?.commitNewTag()
                                      
                                      Save()
                                      
                                      SyncManager.instance().sync()
                                      syncExpectation.fulfill()
                                      XCTAssertEqual(nodes.first?.tags, "::")
                                      
                                    } catch _ { XCTFail() }
    })
    
    waitForExpectations(timeout: 4, handler: nil)
  }
  
  func setUpInMemoryManagedObjectContext() -> NSManagedObjectContext {
    let path = Bundle.main.path(forResource: "MobileOrg2", ofType: "momd")
    let momURL = URL.init(fileURLWithPath: path!)
    let managedObjectModel = NSManagedObjectModel.init(contentsOf: momURL)

    let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
    try! persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
    
    let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
    
    return managedObjectContext
  }
}
