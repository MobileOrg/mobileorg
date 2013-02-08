//
//  MobileOrgAppDelegate.m
//  MobileOrg
//
//  Created by Richard Moreland on 9/30/09.
//  Copyright 2009 Richard Moreland.
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

#ifndef __GNUC__
#define __asm__ asm
#endif

__asm__(".weak_reference _OBJC_CLASS_$_NSURL");

#import "MobileOrgAppDelegate.h"
#import "OutlineViewController.h"
#import "NoteListController.h"
#import "SearchController.h"
#import "SettingsController.h"
#import "DataUtils.h"
#import "Reachability.h"
#import "SessionManager.h"

@interface MobileOrgAppDelegate(private)
- (void)updateInterfaceWithReachability:(Reachability*)curReach;
@end

@implementation MobileOrgAppDelegate

@synthesize window;
@synthesize internetReach;

#pragma mark -
#pragma mark Application lifecycle

- (void)applicationDidFinishLaunching:(UIApplication *)application {

    NSArray *tabViewControllers = [NSArray arrayWithObjects:
                                   self.rootOutlineNavigationController,
                                   self.noteListNavigationController,
                                   self.searchNavigationController,
                                   self.settingsNavigationController,
                                   nil];
    [[self tabBarController] setViewControllers:tabViewControllers];

    self.rootOutlineNavigationController.tabBarItem.image = [UIImage imageNamed:@"outline.png"];
    self.noteListNavigationController.tabBarItem.image = [UIImage imageNamed:@"inbox.png"];
    self.searchNavigationController.tabBarItem.image = [UIImage imageNamed:@"search.png"];
    self.settingsNavigationController.tabBarItem.image = [UIImage imageNamed:@"settings.png"];

    [window addSubview:[[self tabBarController] view]];

    [self.noteListController updateNoteCount];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification object: nil];

    internetReach = [[Reachability reachabilityForInternetConnection] retain];
    [internetReach startNotifer];
    [self updateInterfaceWithReachability:internetReach];

    [[SessionManager instance] restore];

    [window makeKeyAndVisible];
}

/**
 applicationWillTerminate: saves changes in the application's managed object context before the application terminates.
 */
- (void)applicationWillTerminate:(UIApplication *)application {

    [[SessionManager instance] storeCurrentTab];

    NSError *error = nil;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            /*
             Replace this implementation with code to handle the error appropriately.

             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

#pragma mark -
#pragma mark User Interface

- (UITabBarController*)tabBarController {
    if (tabBarController == nil) {
        tabBarController = [[UITabBarController alloc] init];
    }
    return tabBarController;
}

- (OutlineViewController*)rootOutlineController {
    if (rootOutlineController == nil) {
        rootOutlineController = [[OutlineViewController alloc] initWithRootNode:RootNode()];
    }
    return rootOutlineController;
}

- (UINavigationController*)rootOutlineNavigationController {
    if (rootOutlineNavigationController == nil) {
        rootOutlineNavigationController = [[UINavigationController alloc] initWithRootViewController:[self rootOutlineController]];
    }
    return rootOutlineNavigationController;
}

- (NoteListController*)noteListController {
    if (noteListController == nil) {
        noteListController = [[NoteListController alloc] initWithStyle:UITableViewStylePlain];
        noteListController.title = @"Capture";
    }
    return noteListController;
}

- (UINavigationController*)noteListNavigationController {
    if (noteListNavigationController == nil) {
        noteListNavigationController = [[UINavigationController alloc] initWithRootViewController:self.noteListController];
    }
    return noteListNavigationController;
}

- (SearchController*)searchController {
    if (searchController == nil) {
        searchController = [[SearchController alloc] initWithStyle:UITableViewStylePlain];
        searchController.title = @"Search";
    }
    return searchController;
}

- (UINavigationController*)searchNavigationController {
    if (searchNavigationController == nil) {
        searchNavigationController = [[UINavigationController alloc] initWithRootViewController:self.searchController];
    }
    return searchNavigationController;
}

- (SettingsController*)settingsController {
    if (settingsController == nil) {
        settingsController = [[SettingsController alloc] initWithStyle:UITableViewStyleGrouped];
        settingsController.title = @"Settings";
    }
    return settingsController;
}

- (UINavigationController*)settingsNavigationController {
    if (settingsNavigationController == nil) {
        settingsNavigationController = [[UINavigationController alloc] initWithRootViewController:self.settingsController];
    }
    return settingsNavigationController;
}

- (void)updateInterfaceWithReachability:(Reachability*)curReach {
    if(curReach == internetReach) {
        NetworkStatus netStatus = [curReach currentReachabilityStatus];
        if (netStatus == NotReachable) {
            [[self rootOutlineController] setHasConnectivity:NO];
        } else {
            [[self rootOutlineController] setHasConnectivity:YES];
        }
    }
}

- (void)reachabilityChanged:(NSNotification*)note {
    Reachability* curReach = [note object];
    NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
    [self updateInterfaceWithReachability: curReach];
}

#pragma mark -
#pragma mark Core Data stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *) managedObjectContext {

    if (managedObjectContext != nil) {
        return managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    return managedObjectContext;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created by merging all of the models found in the application bundle.
 */
- (NSManagedObjectModel *)managedObjectModel {

    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];
    return managedObjectModel;
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {

    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }

    NSURL *storeUrl = [NSURL fileURLWithPath: [[self applicationDocumentsDirectory] stringByAppendingPathComponent: @"MobileOrg.sqlite"]];

    NSError *error;
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];

    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];

    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:options error:&error]) {
        // Handle error
    }

    return persistentStoreCoordinator;
}

#pragma mark -
#pragma mark Application's Documents directory

/**
 Returns the path to the application's Documents directory.
 */
- (NSString *)applicationDocumentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

#pragma mark -
#pragma mark Memory management

- (void)dealloc {

    [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:kReachabilityChangedNotification];

    [rootOutlineController release];
    [rootOutlineNavigationController release];

    [tabBarController release];

    [managedObjectContext release];
    [managedObjectModel release];
    [persistentStoreCoordinator release];

    [internetReach release];

    [window release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        if ([[DBSession sharedSession] isLinked]) {
            NSLog(@"App linked successfully!");
            // At this point you can start making API calls
        }
        [[self settingsController] loginDone:[[DBSession sharedSession] isLinked]];
        return YES;
    }
    // Add whatever other url handling code your app requires here
    return NO;
}
@end
