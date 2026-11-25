//
//  WebDavTests.swift
//  MobileOrg
//
//  Created by Mario Martelli on 27.04.17.
//  Copyright © 2017 Sean Escriva. All rights reserved.
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
                                    () -> (Void) in

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
                                    () -> (Void) in

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

    waitForExpectations(timeout: 5, handler: nil)
  }

  func testSyncChangesOnMobileReverse() {

    let syncExpectation = expectation(description: "Sync")
    SyncManager.instance().sync()

    let dispatchTime = DispatchTime.now() + Double(4000000000) / Double(NSEC_PER_SEC)
    DispatchQueue.main.asyncAfter (deadline: dispatchTime,
                                   execute: {
                                    () -> (Void) in

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
    
    waitForExpectations(timeout: 5, handler: nil)
  }
  
  func setUpInMemoryManagedObjectContext() -> NSManagedObjectContext {
    let path = Bundle.main.path(forResource: "MobileOrg2", ofType: "momd")
    let momURL = URL.init(fileURLWithPath: path!)
    let managedObjectModel = NSManagedObjectModel.init(contentsOf: momURL)

    let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel!)
    try! persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
    
    let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
    
    return managedObjectContext
  }
}
