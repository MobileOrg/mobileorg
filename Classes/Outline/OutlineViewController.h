//
//  OutlineViewController.h
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

#import <UIKit/UIKit.h>

@class Node;

typedef enum {
    OutlineSelectionTypeDontCare,
    OutlineSelectionTypeExpandOutline,
    OutlineSelectionTypeDetails,
    OutlineSelectionTypeDocumentView,
} OutlineSelectionType;

// A UITableViewController that displays the children of a single Node
@interface OutlineViewController : UITableViewController {

    // Root node, the node whose children are displayed
    Node *root;

    // Children of root Node, sorted by sequenceIndex
    NSArray *nodes;

    // UI components
    UIBarButtonItem *syncButton;
    UIBarButtonItem *homeButton;

    // The app delegate will let us know when we have connectivity, so
    // we can enable/disable sync button
    bool hasConnectivity;
}

@property (nonatomic, retain) Node *root;
@property (nonatomic, retain) NSArray *nodes;

- (id)initWithRootNode:(Node*)node;
- (id)selectRowAtIndexPath:(NSIndexPath*)indexPath withType:(OutlineSelectionType)selectionType andAnimation:(bool)animation;
- (NSIndexPath*)pathForNode:(Node*)node;
- (void)updateBadge;
- (void)setHasConnectivity:(bool)flag;
- (void)restore:(NSArray*)outlineStates;
- (void)reset;
- (void)delayedOneFingerTouch:(NSIndexPath*)path;

@end
