//
//  OrgfileParserTests.swift
//  MobileOrg
//
//  Created by Mario Martelli on 19.12.16.
//
//

import XCTest
import CoreData

class OrgfileParserTests: XCTestCase {
  var moc:NSManagedObjectContext?
  var url:URL!


  // Tackles bug described in:
  // https://github.com/MobileOrg/mobileorg/issues/62
  func testParseOrgFileSkippingHeadingBug() {
    let parser = OrgFileParser()
    parser.localFilename = url.relativePath
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




  func setUpInMemoryManagedObjectContext() -> NSManagedObjectContext {
    let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle.main])!

    let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
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
    let bundle = Bundle(for: type(of: self))
    url = bundle.url(forResource: "headingskip", withExtension: "org")
  }

  override func tearDown() {

    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }

}
