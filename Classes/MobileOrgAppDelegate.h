//
//  MobileOrgAppDelegate.h
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

#import <CoreData/CoreData.h>

@class OutlineViewController;
@class NoteListController;
@class SearchController;
@class SettingsController;
@class Reachability;

@interface MobileOrgAppDelegate : NSObject <UIApplicationDelegate> {

    NSManagedObjectModel *managedObjectModel;
    NSManagedObjectContext *managedObjectContext;
    NSPersistentStoreCoordinator *persistentStoreCoordinator;

    UITabBarController *tabBarController;

    OutlineViewController *rootOutlineController;
    UINavigationController *rootOutlineNavigationController;

    NoteListController *noteListController;
    UINavigationController *noteListNavigationController;

    SearchController *searchController;
    UINavigationController *searchNavigationController;

    SettingsController *settingsController;
    UINavigationController *settingsNavigationController;

    UIWindow *window;

    Reachability *internetReach;
}

@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, readonly) UITabBarController *tabBarController;

@property (nonatomic, readonly) OutlineViewController *rootOutlineController;
@property (nonatomic, readonly) UINavigationController *rootOutlineNavigationController;

@property (nonatomic, readonly) NoteListController *noteListController;
@property (nonatomic, readonly) UINavigationController *noteListNavigationController;

@property (nonatomic, readonly) SearchController *searchController;
@property (nonatomic, readonly) UINavigationController *searchNavigationController;

@property (nonatomic, readonly) SettingsController *settingsController;
@property (nonatomic, readonly) UINavigationController *settingsNavigationController;

@property (nonatomic, retain) Reachability *internetReach;

- (NSString *)applicationDocumentsDirectory;

@end

