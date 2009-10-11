//
//  TagEditController.h
//  MobileOrg
//
//  Created by Richard Moreland on 10/4/09.
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

#import <UIKit/UIKit.h>

@class Node;
@class LocalEditAction;

@interface TagEditController : UITableViewController <UITextFieldDelegate> {
    Node *node;
    NSArray *allTags;
    NSArray *primaryTags;
    LocalEditAction *editAction;
    NSString *newTagString;
}

@property (nonatomic, retain) Node *node;
@property (nonatomic, retain) NSArray *allTags;
@property (nonatomic, retain) NSArray *primaryTags;
@property (nonatomic, retain) LocalEditAction *editAction;
@property (nonatomic, copy) NSString *newTagString;

- (id)initWithNode:(Node*)aNode;

@end
