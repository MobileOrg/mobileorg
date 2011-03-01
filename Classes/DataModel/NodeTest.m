#import <GHUnitIOS/GHUnit.h>
#import "Node.h"

@interface NodeTest : GHTestCase {
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

- (void)setUpClass {
    // Run at start of all tests in the class
    self.model_ = [NSManagedObjectModel mergedModelFromBundles:nil];
    self.coordinator_ = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model_];
    self.context_ = [[NSManagedObjectContext alloc] init];
    [context_ setPersistentStoreCoordinator:coordinator_];
}

- (void)tearDownClass {
    // Run at end of all tests in the class
    [context_ release];
    [coordinator_ release];
}

- (void)setUp {
    // Run before each test method
}

- (void)tearDown {
    // Run after each test method
}

- (void)testDrawerGetsHiddenInDisplayedBody {
    Node *node = (Node *)[NSEntityDescription insertNewObjectForEntityForName:@"Node"
                                                       inManagedObjectContext:context_];
    node.body = @"   :DRAWER:  \n   foo   \n   :END:   \n   bar\n";

    GHAssertEqualObjects(@"   bar", [node bodyForDisplay],
                         @"The text outside the drawer should not change.", nil);
}

- (void)testMultipleDrawersGetHiddenInDisplayedBody {
    Node *node = (Node *)[NSEntityDescription insertNewObjectForEntityForName:@"Node"
                                                       inManagedObjectContext:context_];
    node.body = @"   :DRAWER:  \n   foo   \n   :END:   \n   :DRAWER2: \n bar \n :END: \n baz\n";

    GHAssertEqualObjects(@" baz", [node bodyForDisplay],
                         @"The text outside the drawer should not change.", nil);
}

- (void)testDrawersRemovedFromMiddleOfBodyInDisplayedBody {
    Node *node = (Node *)[NSEntityDescription insertNewObjectForEntityForName:@"Node"
                                                       inManagedObjectContext:context_];
    node.body = @"foo \n :DRAWER: \n bar \n :END: \n baz \n";

    GHAssertEqualObjects(@"foo \n baz", [node bodyForDisplay],
                         @"The text outside the drawer should be concatenated.", nil);
}

@end
