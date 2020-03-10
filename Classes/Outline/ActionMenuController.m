//
//  ActionMenuController.m
//  MobileOrg
//
//  Created by Richard Moreland on 10/10/09.
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

#import "ActionMenuController.h"
#import "Node.h"
#import "MobileOrgAppDelegate.h"
#import "GlobalUtils.h"
#import "DataUtils.h"
#import "Note.h"
#import "OutlineViewController.h"
#import "LocalEditAction.h"
#import "MobileOrg-Swift.h"

@implementation ActionMenuController

@synthesize node;
@synthesize showDocumentViewButton;
@synthesize parentController;


- (void)addFlag:(NSString*)action andEdit:(bool)edit {
    Note *note = (Note*)[NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:[node managedObjectContext]];
    note.nodeId = [node bestId];
    note.createdAt = [NSDate date];
    note.noteId = UUID();
    note.locallyModified = [NSNumber numberWithBool:true];
  
    Save();
  
    [[AppInstance() noteListViewController] updateNoteCount];
  
    if (edit) {
        [[AppInstance() noteListViewController] editWithNote:note];
        [[AppInstance() tabBarController] setSelectedIndex:1];
    }
}

- (void)setTodoState:(NSString*)newState {
    bool created;
    LocalEditAction *action = FindOrCreateLocalEditActionForNode(@"edit:todo", node, &created);
  
    if (created) {
        action.oldValue = [node todoState];
    }
  
    action.updatedValue = newState;
    action.nodeId = [node bestId];
  
    node.todoState = newState;
  
    Save();
}

- (void)showActionSheet:(UIViewController*)controller on:(UIView *)presentingView {
  
    UIAlertController * flagActionSheet =   [UIAlertController
        alertControllerWithTitle: [node headingForDisplay]
        message:nil
        preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction* markDoneAction = [UIAlertAction
        actionWithTitle:@"Mark as Done"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action)
        {
            [self setTodoState:[self.node bestDoneState]];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshTable" object:nil userInfo:nil];
        }];
  
    UIAlertAction* markDoneArchiveAction = [UIAlertAction
        actionWithTitle:@"Mark as Done and Archive"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action)
        {
            [self setTodoState:@"DONEARCHIVE"];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshTable" object:nil userInfo:nil];
        }];
  
    UIAlertAction* flagAction = [UIAlertAction
        actionWithTitle:@"Flag Item"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action)
        {
            [self addFlag:@"" andEdit:false];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshTable" object:nil userInfo:nil];
        }];
  
    UIAlertAction* flagWithNoteAction = [UIAlertAction
        actionWithTitle:@"Flag Item with Note"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action)
        {
            [self addFlag:@"" andEdit:true];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshTable" object:nil userInfo:nil];
        }];
  
    UIAlertAction* cancel = [UIAlertAction
        actionWithTitle:@"Cancel"
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {}];
  
    [flagActionSheet addAction:markDoneAction];
    [flagActionSheet addAction:markDoneArchiveAction];
    [flagActionSheet addAction:flagAction];
    [flagActionSheet addAction:flagWithNoteAction];
  
    if (showDocumentViewButton) {
        UIAlertAction* showDocumentAction = [UIAlertAction
            actionWithTitle:@"View item as a Document"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction * action)
            {
                [self.parentController selectRowAtIndexPath:[self.parentController pathForNode:self.node] withType:OutlineSelectionTypeDocumentView andAnimation:YES];
            }];
      
        [flagActionSheet addAction:showDocumentAction];
    }

    [flagActionSheet addAction:cancel];

    [[flagActionSheet popoverPresentationController] setSourceView:presentingView];
    [controller presentViewController:flagActionSheet animated:YES completion:nil];
}

@end
