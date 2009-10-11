//
//  ActionMenuController.h
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

#import <UIKit/UIKit.h>

@class Node;
@class OutlineViewController;

@interface ActionMenuController : UIViewController {
    UILabel *titleField;
    UIButton *doneButton;
    UIButton *doneAndArchiveButton;
    UIButton *flagButton;
    UIButton *flagWithNoteButton;
    UIButton *documentViewButton;
    UIButton *cancelButton;

    Node *node;
    UITableViewCell *cell;
    UINavigationController *firstNavController;
    OutlineViewController *parentController;

    bool showDocumentViewButton;

    UIView *actionView;
}

- (void)onDone;
- (void)onDoneAndArchive;
- (void)onFlag;
- (void)onFlagWithNote;
- (void)onDocumentView;
- (void)onCancel;

@property (nonatomic, retain) Node *node;
@property (nonatomic, retain) UITableViewCell *cell;
@property (nonatomic, retain) UINavigationController *firstNavController;
@property (nonatomic, retain) OutlineViewController *parentController;

@property (nonatomic, readonly) UILabel *titleField;
@property (nonatomic, readonly) UIButton *doneButton;
@property (nonatomic, readonly) UIButton *doneAndArchiveButton;
@property (nonatomic, readonly) UIButton *flagButton;
@property (nonatomic, readonly) UIButton *flagWithNoteButton;
@property (nonatomic, readonly) UIButton *documentViewButton;
@property (nonatomic, readonly) UIButton *cancelButton;

@property (nonatomic) bool showDocumentViewButton;

@end
