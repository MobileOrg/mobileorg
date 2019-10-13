//
//  NodeTests.m
//  MobileOrg
//
//  Created by Mario Martelli on 11.12.16.
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


  NSString *path = [[NSBundle mainBundle] pathForResource:@"MobileOrg2" ofType:@"momd"];
  NSURL *momURL = [NSURL fileURLWithPath:path];
  self.model_ = [[NSManagedObjectModel alloc] initWithContentsOfURL:momURL];

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

- (void)testIsLink {
  Node *node = (Node *)[NSEntityDescription insertNewObjectForEntityForName:@"Node"
                                                     inManagedObjectContext:context_];

  node.heading = @"[[file:persönlich.org][persönlich.org]]";
  XCTAssertTrue(node.isLink);
}

- (void)testScheduledAndDeadlineRemovedFromMiddleOfBodyInDisplayedBody {
  Node *node = (Node *)[NSEntityDescription insertNewObjectForEntityForName:@"Node"
                                                     inManagedObjectContext:context_];
  node.body = @"foo \n DEADLINE: <2020-01-01 Tue> SCHEDULED: <2020-01-01 Sat> \n baz \n";

  XCTAssertEqualObjects(@"foo \n baz", [node bodyForDisplay],
                       @"The text outside the scheduled & deadline notes should be concatenated.", nil);
}

@end
