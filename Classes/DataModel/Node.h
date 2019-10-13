//
//  Node.h
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

@class LocalEditAction;

@interface Node :  NSManagedObject
{
}

@property (nonatomic, retain) NSString * body;
@property (nonatomic, retain) NSString * heading;
@property (nonatomic, retain) NSNumber * sequenceIndex;
@property (nonatomic, retain) NSString * todoState;
@property (nonatomic, retain) NSString * tags;
@property (nonatomic, retain) NSString * inheritedTags;
@property (nonatomic, retain) NSString * referencedNodeId;
@property (nonatomic, retain) NSString * nodeId;
@property (nonatomic, retain) NSString * outlinePath;
@property (nonatomic, retain) NSNumber * indentLevel;
@property (nonatomic, retain) NSNumber * readOnly;
@property (nonatomic, retain) NSString * priority;
@property (nonatomic, retain) Node * parent;
@property (nonatomic, retain) NSSet* notes;
@property (nonatomic, retain) NSSet* children;

- (NSString*)bestId;
- (NSString*)headingForDisplay;
- (NSString*)headingForDisplayWithHtmlLinks:(BOOL)withLinks;
- (NSString*)beforeText;
- (NSString*)afterText;
- (NSString*)bodyForDisplay;
- (NSString*)completeTags;
- (NSString*)tagsForDisplay;
- (bool)hasTag:(NSString*)tag;
- (bool)hasInheritedTag:(NSString*)tag;
- (void)toggleTag:(NSString*)tag;
- (void)addTag:(NSString*)tag;
- (void)removeTag:(NSString*)tag;
- (NSArray*)sortedChildren;
- (NSString*)resolveLink:(NSString*)link;
- (bool)isLink;
- (NSString*)linkFile;
- (bool)isBrokenLink;
- (NSString*)linkTitle;
- (void)collectLinks:(NSMutableArray*)links;
- (NSString*)htmlForDocumentViewLevel:(int)level;
- (NSString*)ownerFile;
- (NSString*)bestDoneState;

- (NSString *)scheduled;
- (NSDate *)scheduledDate;
- (NSString *)deadline;
- (NSDate *)deadlineDate;

@end


@interface Node (CoreDataGeneratedAccessors)

- (void)addChildrenObject:(Node *)value;
- (void)removeChildrenObject:(Node *)value;
- (void)addChildren:(NSSet *)value;
- (void)removeChildren:(NSSet *)value;

@end

