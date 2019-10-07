//
//  Settings.h
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

#import <Foundation/Foundation.h>

typedef enum {
    AppBadgeModeUnknown = 0,
    AppBadgeModeNone,
    AppBadgeModeTotal
} AppBadgeMode;

typedef enum {
    ServerModeUnknown = 0,
    ServerModeWebDav,
    ServerModeDropbox,
    ServerModeICloud
} ServerMode;

typedef enum {
    LaunchTabOutline = 0,
    LaunchTabCapture,
} LaunchTab;

@interface Settings : NSObject {
    NSURL *indexUrl;

    NSString *username;
    NSString *password;

    NSDate *lastSync;

    NSMutableArray *primaryTags;
    NSMutableArray *mutuallyExclusiveTagGroups;
    NSMutableArray *allTags;
    NSMutableArray *todoStateGroups;
    NSMutableArray *priorities;

    AppBadgeMode appBadgeMode;

    ServerMode serverMode;
    
    LaunchTab launchTab;

    NSString *dropboxIndex;
    
    NSString *encryptionPassword;
}

@property (nonatomic, copy, nullable) NSURL *indexUrl;
@property (nonatomic, copy, nullable) NSString *username;
@property (nonatomic, copy, nullable) NSString *password;
@property (nonatomic, copy, nullable) NSDate *lastSync;
@property (nonatomic, copy, nullable) NSMutableArray *primaryTags;
@property (nonatomic, retain,nullable) NSMutableArray *mutuallyExclusiveTagGroups;
@property (nonatomic, copy,nullable) NSMutableArray *allTags;
@property (nonatomic, copy,nullable) NSMutableArray *todoStateGroups;
@property (nonatomic, copy,nullable) NSMutableArray *priorities;
@property (nonatomic) AppBadgeMode appBadgeMode;
@property (nonatomic) ServerMode serverMode;
@property (nonatomic) LaunchTab launchTab;
@property (nonatomic, copy, nullable) NSString *dropboxIndex;
@property (nonatomic, copy, nullable) NSString *encryptionPassword;

+ (nonnull Settings*)instance;
- (void)resetPrimaryTagsAndTodoStates;
- (void)resetAllTags;
- (void)addPrimaryTag:(nonnull NSString*)tag;
- (void)addTag:(nonnull NSString*)tag;
- (void)addMutuallyExclusiveTagGroup:(nonnull NSArray*)mutexTags;
- (void)addTodoStateGroup:(nonnull NSMutableArray*)todoStateGroup;
- (bool)isTodoState:(nonnull NSString*)state;
- (bool)isDoneState:(nonnull NSString*)state;
- (void)addPriority:(nonnull NSString*)priority;
- (bool)isPriority:(nonnull NSString*)priority;
- (nullable NSString*)indexFilename;
- (nullable NSURL*)baseUrl;
- (nullable NSURL*)urlForFilename:(nonnull NSString*)filename;
- (bool)isConfiguredProperly;

@end
