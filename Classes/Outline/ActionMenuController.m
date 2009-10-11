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
#import "NoteListController.h"
#import "OutlineViewController.h"

@implementation ActionMenuController

@synthesize node;
@synthesize cell;
@synthesize firstNavController;
@synthesize showDocumentViewButton;
@synthesize parentController;

- (void)close {
    if (cell) {
        [cell setHighlighted:NO];
    }
    [firstNavController dismissModalViewControllerAnimated:YES];
}

- (void)addFlag:(NSString*)action andEdit:(bool)edit {
    Note *note = (Note*)[NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:[node managedObjectContext]];
    note.nodeId = [node bestId];
    note.createdAt = [NSDate date];
    note.flagAction = action;
    note.noteId = UUID();
    note.locallyModified = [NSNumber numberWithBool:true];

    Save();

    [[AppInstance() noteListController] updateNoteCount];

    if (edit) {
        [[AppInstance() noteListController] editNote:note withKeyboard:true];
        [[AppInstance() tabBarController] setSelectedIndex:1];
    }
}

- (void)onDone {
    [self addFlag:@"d" andEdit:false];
    [self close];
}

- (void)onDoneAndArchive {
    [self addFlag:@"d-a" andEdit:false];
    [self close];
}

- (void)onFlag {
    [self addFlag:@"" andEdit:false];
    [self close];
}

- (void)onFlagWithNote {
    [self addFlag:@"" andEdit:true];
    [self close];
}

- (void)onDocumentView {
    [self close];
    [parentController selectRowAtIndexPath:[parentController pathForNode:node] withType:OutlineSelectionTypeDocumentView andAnimation:YES];
}

- (void)onCancel {
    [self close];
}

- (void)layoutButtons {
    int halfButtonWidth = 130;
    int fullButtonWidth = 280;
    int buttonHeight = 40;
    int buttonVSpacing = 55;

    int leftButtonX = 0;
    int rightButtonX = 0;
    int yOffset = 0;

    switch ([[UIDevice currentDevice] orientation]) {
        case UIDeviceOrientationLandscapeLeft:
        case UIDeviceOrientationLandscapeRight:
            leftButtonX = 100;
            rightButtonX = 250;
            yOffset = 10;
            actionView.frame = CGRectMake(0, 0, 480, 320);
            break;

        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationPortraitUpsideDown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        default:
            leftButtonX = 20;
            rightButtonX = 170;
            yOffset = 40;
            actionView.frame = CGRectMake(0, 0, 320, 480);
            break;
    }

    titleField.frame = CGRectMake(leftButtonX, yOffset, fullButtonWidth, buttonHeight);
    yOffset += buttonVSpacing;

    doneButton.frame = CGRectMake(leftButtonX, yOffset, halfButtonWidth, buttonHeight);
    doneAndArchiveButton.frame = CGRectMake(rightButtonX, yOffset, halfButtonWidth, buttonHeight);
    yOffset += buttonVSpacing;

    flagButton.frame = CGRectMake(leftButtonX, yOffset, halfButtonWidth, buttonHeight);
    flagWithNoteButton.frame = CGRectMake(rightButtonX, yOffset, halfButtonWidth, buttonHeight);
    yOffset += buttonVSpacing;

    if (showDocumentViewButton) {
        documentViewButton.frame = CGRectMake(leftButtonX, yOffset, fullButtonWidth, buttonHeight);
        yOffset += buttonVSpacing;
    }

    cancelButton.frame = CGRectMake(leftButtonX, yOffset, fullButtonWidth, buttonHeight);

    [actionView setNeedsLayout];
    [actionView setNeedsDisplay];
}

- (void)loadView {
    [super loadView];

    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];

    actionView = [[UIView alloc] init];
    [actionView addSubview:self.titleField];
    [actionView addSubview:self.doneButton];
    [actionView addSubview:self.doneAndArchiveButton];
    [actionView addSubview:self.flagButton];
    [actionView addSubview:self.flagWithNoteButton];
    [actionView addSubview:self.documentViewButton];
    [actionView addSubview:self.cancelButton];

    [self.view addSubview:actionView];

    [self layoutButtons];
}

- (void)didRotate:(NSNotification *)notification {
    [self layoutButtons];
}

- (UILabel*)titleField {
    if (titleField == nil) {
        titleField = [[UILabel alloc] init];
        [titleField setText:[node headingForDisplay]];
        [titleField setTextAlignment:UITextAlignmentCenter];
        [titleField setTextColor:[UIColor whiteColor]];
        [titleField setBackgroundColor:[UIColor clearColor]];
    }
    return titleField;
}

- (UIButton*)doneButton {
    if (doneButton == nil) {
        doneButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
        [doneButton setTitle:@"Mark as Done" forState:UIControlStateNormal];
        [doneButton addTarget:self action:@selector(onDone) forControlEvents:UIControlEventTouchUpInside];
    }
    return doneButton;
}

- (UIButton*)doneAndArchiveButton {
    if (doneAndArchiveButton == nil) {
        doneAndArchiveButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
        [doneAndArchiveButton setTitle:@"...and Archive" forState:UIControlStateNormal];
        [doneAndArchiveButton addTarget:self action:@selector(onDoneAndArchive) forControlEvents:UIControlEventTouchUpInside];
    }
    return doneAndArchiveButton;
}

- (UIButton*)flagButton {
    if (flagButton == nil) {
        flagButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
        [flagButton setTitle:@"Flag item" forState:UIControlStateNormal];
        [flagButton addTarget:self action:@selector(onFlag) forControlEvents:UIControlEventTouchUpInside];
    }
    return flagButton;
}

- (UIButton*)flagWithNoteButton {
    if (flagWithNoteButton == nil) {
        flagWithNoteButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
        [flagWithNoteButton setTitle:@"...with Note" forState:UIControlStateNormal];
        [flagWithNoteButton addTarget:self action:@selector(onFlagWithNote) forControlEvents:UIControlEventTouchUpInside];
    }
    return flagWithNoteButton;
}

- (UIButton*)documentViewButton {
    if (documentViewButton == nil) {
        documentViewButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
        [documentViewButton setTitle:@"View item as a Document" forState:UIControlStateNormal];
        [documentViewButton addTarget:self action:@selector(onDocumentView) forControlEvents:UIControlEventTouchUpInside];
    }
    return documentViewButton;
}

- (UIButton*)cancelButton {
    if (cancelButton == nil) {
        cancelButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
        [cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
        [cancelButton addTarget:self action:@selector(onCancel) forControlEvents:UIControlEventTouchUpInside];
    }
    return cancelButton;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [titleField setText:[node headingForDisplay]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didRotate:)
                                                 name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [doneButton release];
    [doneAndArchiveButton release];
    [flagButton release];
    [flagWithNoteButton release];
    [documentViewButton release];
    [cancelButton release];
    [actionView release];
    [node release];
    [cell release];
    [firstNavController release];
    [parentController release];
    [super dealloc];
}

@end
