//
//  NewNoteController.m
//  MobileOrg
//
//  Created by Richard Moreland on 10/6/09.
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

#import "NewNoteController.h"
#import "Note.h"
#import "DataUtils.h"
#import "GlobalUtils.h"
#import "MobileOrgAppDelegate.h"
#import "NoteListController.h"

@implementation NewNoteController

@synthesize textField;
@synthesize note;
@synthesize doneButton, addButton;
@synthesize showKeyboardOnLoad;

- (void)save:(bool)giveUpKeyboard {
    if (!note.text || [note.text compare:textField.text] != NSOrderedSame) {
        note.text = textField.text;
        note.createdAt = [NSDate date];
        note.locallyModified = [NSNumber numberWithBool:true];
        Save();
    }

    if (giveUpKeyboard)
        [textField resignFirstResponder];
}

- (void)save {
    [self save:true];
}

- (void)textViewDidChange:(UITextView *)textView {
    [self save:false];
}

- (void)add {
    [self save:true];

    Note *newNote = (Note*)[NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:[note managedObjectContext]];
    [newNote setCreatedAt:[NSDate date]];
    [newNote setNoteId:UUID()];
    [newNote setLocallyModified:[NSNumber numberWithBool:true]];

    Save();

    [[AppInstance() noteListController] updateNoteCount];
    [[AppInstance() noteListController] editNote:newNote withKeyboard:true];
}

- (void)done {
}

// Call this method somewhere in your view controller setup code.
- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasHidden:)
                                                 name:UIKeyboardDidHideNotification object:nil];
}

- (void)unregisterForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardDidShowNotification object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardDidHideNotification object:nil];
}

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
    textField = [[UITextView alloc] init];
    [textField setScrollEnabled:YES];
    [textField setScrollsToTop:YES];
    [textField setFont:[UIFont systemFontOfSize:14.0]];
    [textField setDelegate:self];
    [self setView:textField];
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    if (keyboardShown)
        return;

    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;

    // Get the height of the Navigation Bar
    CGRect rect = self.navigationController.navigationBar.frame;
    float y = rect.size.height + rect.origin.y;

    // Substract keyboard and navigation bar
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(y, 0.0, kbSize.height, 0.0);
    textField.contentInset = contentInsets;
    textField.scrollIndicatorInsets = contentInsets;

    // If text view is hidden by keyboard, scroll it so it's visible
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    if (!CGRectContainsPoint(aRect, self.view.frame.origin) ) {
        [textField scrollRectToVisible:self.view.frame animated:YES];
    }

    keyboardShown = YES;

    self.navigationItem.rightBarButtonItem = doneButton;
}


// Called when the UIKeyboardDidHideNotification is sent
- (void)keyboardWasHidden:(NSNotification*)aNotification
{
    // Get the height of the Navigation Bar
    CGRect rect = self.navigationController.navigationBar.frame;
    float y = rect.size.height + rect.origin.y;

    // Substract keyboard and navigation bar
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(y, 0.0, 0.0, 0.0);

    textField.contentInset = contentInsets;
    textField.scrollIndicatorInsets = contentInsets;

    keyboardShown = NO;

    self.navigationItem.rightBarButtonItem = addButton;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];

    [textField setText:[note text]];

    if ([note isFlagEntry]) {
        if (!note.text || [note.text length] == 0) {
            self.title = @"New flagging note";
            [textField becomeFirstResponder];
        } else {
            self.title = @"Edit flagging note";
        }
    } else {
        if (!note.text || [note.text length] == 0) {
            self.title = @"New note";
            [textField becomeFirstResponder];
        } else {
            self.title = @"Edit note";
        }
    }

    addButton = [[UIBarButtonItem alloc]
                 initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(add)];

    doneButton = [[UIBarButtonItem alloc]
                  initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(save)];

    if (self.showKeyboardOnLoad) {
        [textField becomeFirstResponder];
        self.navigationItem.rightBarButtonItem = doneButton;
    } else {
        self.navigationItem.rightBarButtonItem = addButton;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self save:!self.showKeyboardOnLoad];
    [self registerForKeyboardNotifications];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self unregisterForKeyboardNotifications];
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
    [note release];
    [doneButton release];
    [addButton release];
    [textField release];
    [super dealloc];
}

@end
