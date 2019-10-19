//
//  Note.h
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

@class Node;

NS_ASSUME_NONNULL_BEGIN;

@interface Note :  NSManagedObject

@property (nonatomic, retain, nullable) NSString * text;
@property (nonatomic, retain, nullable) NSDate * createdAt;
@property (nonatomic, retain, nullable) NSString * nodeId;
@property (nonatomic, retain) NSString * noteId;
@property (nonatomic, retain, nullable) NSNumber * locallyModified;
@property (nonatomic, retain, nullable) NSNumber * removed;

- (NSString*)heading;
- (NSString*)body;
- (bool)isFlagEntry;
- (NSString*)orgLine;

@end

NS_ASSUME_NONNULL_END;
