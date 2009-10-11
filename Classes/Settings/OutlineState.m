//
//  SessionContext.m
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

#import "OutlineState.h"

@implementation OutlineState

@synthesize selectionType;
@synthesize selectedChildIndex;
@synthesize scrollPositionY;
@synthesize selectedLink;

- (NSDictionary*)toDictionary {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSString stringWithFormat:@"%d", selectionType], @"SelectionType",
                          [NSString stringWithFormat:@"%d", selectedChildIndex], @"SelectedChild",
                          [NSString stringWithFormat:@"%d", scrollPositionY], @"ScrollY",
                          selectedLink, @"SelectedLink",
                          nil];
    return dict;
}

+ (OutlineState*)fromDictionary:(NSDictionary*)dict {
    OutlineState *state = [[OutlineState new] autorelease];
    state.selectionType = [[dict valueForKey:@"SelectionType"] intValue];
    state.selectedChildIndex = [[dict valueForKey:@"SelectedChild"] intValue];
    state.scrollPositionY = [[dict valueForKey:@"ScrollY"] intValue];
    state.selectedLink = [dict valueForKey:@"SelectedLink"];
    return state;
}

@end
