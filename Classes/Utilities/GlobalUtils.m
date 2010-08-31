//
//  GlobalUtils.m
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

#import "GlobalUtils.h"
#import "Settings.h"
#import "MobileOrgAppDelegate.h"
#import "OutlineViewController.h"

MobileOrgAppDelegate *AppInstance() {
    return (MobileOrgAppDelegate*)[[UIApplication sharedApplication] delegate];
}

NSString *UUID() {
    CFUUIDRef uuidObj = CFUUIDCreate(nil);
    NSString *uuidString = (NSString*)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
    return [uuidString autorelease];
}

NSString *FileWithName(NSString *name) {
    return [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:name];
}

NSString *TemporaryFilename() {
    return [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:UUID()];
}

void DeleteFile(NSString *filename) {
    NSFileManager *NSFm = [NSFileManager defaultManager];
    if ([NSFm fileExistsAtPath:filename]) {
        NSError *e;
        [NSFm removeItemAtPath:filename error:&e];
    }
}

void UpdateEditActionCount() {
    [[AppInstance() rootOutlineController] updateBadge];
}

// Get rid of any '*' characters in column zero by padding them with space in column 0.
// This changes what the user entered, but they shouldn't have done it in the first place.
NSString *EscapeHeadings(NSString *original) {
    NSString *ret = [NSString stringWithString:original];
    if ([original length] > 0) {
        if ([original characterAtIndex:0] == '*') {
            ret = [NSString stringWithFormat:@" %@", original];
        }
    }
    ret = [ret stringByReplacingOccurrencesOfString:@"\n*" withString:@"\n *"];
    return ret;
}

void UpdateAppBadge() {
    int count = 0;
    if ([[Settings instance] appBadgeMode] == AppBadgeModeTotal) {
        count += [[[AppInstance() noteListController] navigationController].tabBarItem.badgeValue intValue];
        count += [[[AppInstance() rootOutlineController] navigationController].tabBarItem.badgeValue intValue];
    }
    [UIApplication sharedApplication].applicationIconBadgeNumber = count;
}

// http://stackoverflow.com/questions/2576356/how-does-one-get-ui-user-interface-idiom-to-work-with-iphone-os-sdk-3-2
BOOL IsIpad() {
#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 30200)
    if ([[UIDevice currentDevice] respondsToSelector: @selector(userInterfaceIdiom)])
        return ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad);
#endif
    return NO;
}
