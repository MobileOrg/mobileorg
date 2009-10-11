//
//  SessionManager.m
//  MobileOrg
//
//  Created by Richard Moreland on 10/7/09.
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

#import "SessionManager.h"
#import "OutlineState.h"
#import "GlobalUtils.h"
#import "MobileOrgAppDelegate.h"
#import "Settings.h"

static SessionManager *gInstance   = NULL;
static NSString *kOutlineStatesKey = @"OutlineStates";
static NSString *kWhichTabKey      = @"WhichTab";

@implementation SessionManager

@synthesize outlineStates;
@synthesize isRestoring;

+ (SessionManager*)instance {
    @synchronized(self) {
        if (gInstance == NULL)
            gInstance = [[self alloc] init];
    }
    return gInstance;
}

- (id)init {
    if (self = [super init]) {
        NSMutableArray *existingStates = [[[NSUserDefaults standardUserDefaults] objectForKey:kOutlineStatesKey] mutableCopy];
        if (existingStates) {
            self.outlineStates = existingStates;
            [existingStates release];
        } else {
            self.outlineStates = [[NSMutableArray new] autorelease];
            self.isRestoring = false;
        }
    }
    return self;
}

- (void)restore {
    isRestoring = true;

    // Restore the outline selections
    [[AppInstance() rootOutlineController] restore:outlineStates];

    // Restore the right tab
    [self restoreCurrentTab];

    isRestoring = false;
}

- (void)reset {
    [self.outlineStates removeAllObjects];
    [self saveOutlineState];
}

- (bool)isSearchMode {
    return [[AppInstance() tabBarController] selectedIndex] == 2;
}

- (void)restoreCurrentTab {
    int whichTab = [[[NSUserDefaults standardUserDefaults] objectForKey:kWhichTabKey] intValue];

    if (![[Settings instance] indexUrl] || [[[[Settings instance] indexUrl] absoluteString] length] == 0) {
        whichTab = 3; // Settings
    }

    [[AppInstance() tabBarController] setSelectedIndex:whichTab];
}

- (void)storeCurrentTab {
    int whichTab = [[AppInstance() tabBarController] selectedIndex];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:whichTab] forKey:kWhichTabKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)pushOutlineState:(OutlineState*)state {
    if (!isRestoring && ![self isSearchMode]) {
        [outlineStates addObject:[state toDictionary]];
        [self saveOutlineState];
    }
}

- (void)popOutlineStateToLevel:(int)level {
    if (!isRestoring && ![self isSearchMode]) {
        while ([self.outlineStates count] > level) {
            [self.outlineStates removeLastObject];
        }
        [self saveOutlineState];
    }
}

- (OutlineState*)topOutlineState {
    return [OutlineState fromDictionary:[self.outlineStates lastObject]];
}

- (void)replaceTopOutlineState:(OutlineState*)newState {
    if (!isRestoring && ![self isSearchMode]) {
        [self.outlineStates removeLastObject];
        [self.outlineStates addObject:[newState toDictionary]];
        [self saveOutlineState];
    }
}

- (void)saveOutlineState {
    [[NSUserDefaults standardUserDefaults] setObject:self.outlineStates forKey:kOutlineStatesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setSelectedNote:(Note*)note {
    // TODO
}

- (void)dealloc {
    [outlineStates release];
    [super dealloc];
}

@end
