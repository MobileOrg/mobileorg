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
    ServerModeDropbox
} ServerMode;

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

    NSString *dropboxIndex;
    
    NSString *encryptionPassword;
}

@property (nonatomic, copy) NSURL *indexUrl;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, copy) NSDate *lastSync;
@property (nonatomic, copy) NSMutableArray *primaryTags;
@property (nonatomic, retain) NSMutableArray *mutuallyExclusiveTagGroups;
@property (nonatomic, copy) NSMutableArray *allTags;
@property (nonatomic, copy) NSMutableArray *todoStateGroups;
@property (nonatomic, copy) NSMutableArray *priorities;
@property (nonatomic) AppBadgeMode appBadgeMode;
@property (nonatomic) ServerMode serverMode;
@property (nonatomic, copy) NSString *dropboxIndex;
@property (nonatomic, copy) NSString *encryptionPassword;

+ (Settings*)instance;
- (void)resetPrimaryTagsAndTodoStates;
- (void)resetAllTags;
- (void)addPrimaryTag:(NSString*)tag;
- (void)addTag:(NSString*)tag;
- (void)addMutuallyExclusiveTagGroup:(NSArray*)mutexTags;
- (void)addTodoStateGroup:(NSMutableArray*)todoStateGroup;
- (bool)isTodoState:(NSString*)state;
- (bool)isDoneState:(NSString*)state;
- (void)addPriority:(NSString*)priority;
- (bool)isPriority:(NSString*)priority;
- (NSString*)indexFilename;
- (NSURL*)baseUrl;
- (NSURL*)urlForFilename:(NSString*)filename;
- (bool)isConfiguredProperly;

@end
