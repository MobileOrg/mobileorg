//
//  OrgfileParserTests.swift
//  MobileOrg
//
//  Created by Mario Martelli on 19.12.16.
//  © 2016 Mario Martelli
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

class OrgfileParserTests: XCTestCase {
  var moc:NSManagedObjectContext?

  // Tackles bug described in:
  // https://github.com/MobileOrg/mobileorg/issues/96
  func testParseOrgFileDisregardDelimiter() {
    let parser = OrgFileParser()

    let bundle = Bundle(for: type(of: self))

    // Parse the index file (here are the todo keywords stored for processing)
    let indexUrl = bundle.url(forResource: "index", withExtension: "org")
    parser.localFilename = indexUrl?.relativePath
    parser.orgFilename = "index.org"
    parser.parse(moc)

    // now parse the todo list
    let url = bundle.url(forResource: "TodoList", withExtension: "org")
    parser.localFilename = url?.relativePath
    parser.orgFilename = "TodoList.org"
    parser.parse(moc)

    let settings = Settings.instance()
    if let keywordsMetaArray = settings.todoStateGroups {
      for case let keywordsArray as Array<Array<String>> in keywordsMetaArray {
        for keywords in keywordsArray {
          for keyword in keywords {
            if keyword == "|" {
              XCTFail()
            }
          }
        }
      }
    }
    else {
      XCTFail()
    }
  }
  



  // Parse OrgFiles for todo-keywords of different kind
  func testParseOrgFileDifferentTodoWords() {
    let parser = OrgFileParser()

    let bundle = Bundle(for: type(of: self))

    // Parse the index file (here are the todo keywords stored for processing)
    let indexUrl = bundle.url(forResource: "index", withExtension: "org")
    parser.localFilename = indexUrl?.relativePath
    parser.orgFilename = "index.org"
    parser.parse(moc)

    // now parse the todo list
    let url = bundle.url(forResource: "TodoList", withExtension: "org")
    parser.localFilename = url?.relativePath
    parser.orgFilename = "TodoList.org"
    parser.parse(moc)

    do {
      // Test todo state (waiting)
      let fetchRequest = NSFetchRequest<Node>(entityName: "Node")
      fetchRequest.predicate = NSPredicate (format: "heading == %@", "on Level 1.1.1.5")

      var nodes = try moc!.fetch(fetchRequest)
      if nodes.count == 1,
        let node = nodes.first {
        XCTAssertEqual(node.todoState, "WAITING")
      } else {
        XCTFail()
      }

      // Test done state (works for me)
      fetchRequest.predicate = NSPredicate (format: "heading == %@", "on Level 1.1.1.3")
      nodes = try moc!.fetch(fetchRequest)
      if nodes.count == 1,
        let node = nodes.first {
        XCTAssertEqual(node.todoState, "WORKS-FOR-ME")
      } else {
        XCTFail()
      }
    } catch _ { XCTFail() }
  }


  // Tackles bug described in:
  // https://github.com/MobileOrg/mobileorg/issues/86
  func testParseOrgFileDefaultTodoWordsBug() {
    let parser = OrgFileParser()

    let bundle = Bundle(for: type(of: self))
    let url = bundle.url(forResource: "defaultTodoWords", withExtension: "org")
    parser.localFilename = url?.relativePath

    parser.orgFilename = "index.org"
    parser.parse(moc)

    // If we reach this point without a crash, then the test was successful
  }



  // Tackles bug described in:
  // https://github.com/MobileOrg/mobileorg/issues/62
  func testParseOrgFileSkippingHeadingBug() {
    let parser = OrgFileParser()
    let bundle = Bundle(for: type(of: self))
    let url = bundle.url(forResource: "headingskip", withExtension: "org")

    parser.localFilename = url?.relativePath
    parser.orgFilename = "Heading"
    parser.parse(moc)

    try! moc?.save()

    let fetchRequest = NSFetchRequest<Node>(entityName: "Node")
    fetchRequest.predicate = NSPredicate (format: "outlinePath == %@", "olp:Heading:MobileOrg Missing Features/Localisation")

    do {
      let nodes = try moc!.fetch(fetchRequest)

      XCTAssertEqual(nodes.count, 1)


    } catch _ { XCTFail() }

  }

  func testParseOrgFileSkippingHeadingBugTheRealOne() {
    let parser = OrgFileParser()
    let bundle = Bundle(for: type(of: self))
    let url = bundle.url(forResource: "MobileOrgTestingSample", withExtension: "org")

    parser.localFilename = url?.relativePath
    parser.orgFilename = "Heading"
    parser.parse(moc)

    try! moc?.save()

    let fetchRequest = NSFetchRequest<Node>(entityName: "Node")
    fetchRequest.predicate = NSPredicate (format: "heading == %@", "Third node with a todo list [1/3]")

    do {
      let nodes = try moc!.fetch(fetchRequest)
      XCTAssertEqual(nodes.count, 1)
      if let node = nodes.first {
        XCTAssertEqual(node.outlinePath, "olp:Heading:Third node with a todo list %5b1%2f3%5d")
      } else {
        XCTFail()
      }
    } catch _ { XCTFail() }
    
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

  override func setUp() {
    super.setUp()
    let context = setUpInMemoryManagedObjectContext()
    moc = context
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDown() {

    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }

}
