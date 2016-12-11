//
//  NodeTests.m
//  MobileOrg
//
//  Created by Mario Martelli on 11.12.16.
//
//

#import <XCTest/XCTest.h>
#import "Node.h"

@interface NodeTest : XCTestCase {
  NSManagedObjectModel* model_;
  NSPersistentStoreCoordinator* coordinator_;
  NSManagedObjectContext* context_;
}

@property (nonatomic, retain) NSManagedObjectModel* model_;
@property (nonatomic, retain) NSPersistentStoreCoordinator* coordinator_;
@property (nonatomic, retain) NSManagedObjectContext* context_;

@end

@implementation NodeTest

@synthesize model_;
@synthesize coordinator_;
@synthesize context_;

- (BOOL)shouldRunOnMainThread {
    // By default NO, but if you have a UI test or test dependent on running on the main thread return YES
  return NO;
}

- (void)setUp {
    // Run at start of all tests in the class
  self.model_ = [NSManagedObjectModel mergedModelFromBundles:nil];
  self.coordinator_ = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model_];
  self.context_ = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSMainQueueConcurrencyType];
  [context_ setPersistentStoreCoordinator:coordinator_];
}

- (void)tearDown {
    // Run at end of all tests in the class
}

- (void)testDrawerGetsHiddenInDisplayedBody {
  Node *node = (Node *)[NSEntityDescription insertNewObjectForEntityForName:@"Node"
                                                     inManagedObjectContext:context_];
  node.body = @"   :DRAWER:  \n   foo   \n   :END:   \n   bar\n";

  XCTAssertEqualObjects(@"   bar", [node bodyForDisplay],
                       @"The text outside the drawer should not change.", nil);
}

- (void)testMultipleDrawersGetHiddenInDisplayedBody {
  Node *node = (Node *)[NSEntityDescription insertNewObjectForEntityForName:@"Node"
                                                     inManagedObjectContext:context_];
  node.body = @"   :DRAWER:  \n   foo   \n   :END:   \n   :DRAWER2: \n bar \n :END: \n baz\n";

  XCTAssertEqualObjects(@" baz", [node bodyForDisplay],
                       @"The text outside the drawer should not change.", nil);
}

- (void)testDrawersRemovedFromMiddleOfBodyInDisplayedBody {
  Node *node = (Node *)[NSEntityDescription insertNewObjectForEntityForName:@"Node"
                                                     inManagedObjectContext:context_];
  node.body = @"foo \n :DRAWER: \n bar \n :END: \n baz \n";

  XCTAssertEqualObjects(@"foo \n baz", [node bodyForDisplay],
                       @"The text outside the drawer should be concatenated.", nil);
}

@end
