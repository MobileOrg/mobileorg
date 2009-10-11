//
//  NodeTextEditController.m
//  MobileOrg
//
//  Created by Richard Moreland on 10/2/09.
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

#import "NodeTextEditController.h"
#import "Node.h"
#import "LocalEditAction.h"
#import "DataUtils.h"

@implementation NodeTextEditController

@synthesize editProperty;
@synthesize node;
@synthesize valueBeforeEditing;
@synthesize editAction;

- (void)onDone {
    [textView resignFirstResponder];
}

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

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    if (keyboardShown)
        return;

    // Resize the scroll view (which is the root view of the window)
    switch ([[UIDevice currentDevice] orientation]) {
        case UIDeviceOrientationLandscapeLeft:
        case UIDeviceOrientationLandscapeRight:
            [[self view] setFrame:CGRectMake(0, 0, 480, 135)];
            break;

        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationPortraitUpsideDown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        default:
            [[self view] setFrame:CGRectMake(0, 0, 320, 220)];
            break;
    }

    // Scroll the active text field into view.
    [textView scrollRangeToVisible:NSMakeRange([textView.text length], 0)];

    doneButton.enabled = YES;

    keyboardShown = YES;
}


// Called when the UIKeyboardDidHideNotification is sent
- (void)keyboardWasHidden:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];

    // Get the size of the keyboard.
    NSValue* aValue = [info objectForKey:UIKeyboardBoundsUserInfoKey];
    CGSize keyboardSize = [aValue CGRectValue].size;

    // Reset the height of the scroll view to its original value
    CGRect viewFrame = [[self view] frame];
    viewFrame.size.height += keyboardSize.height;
    viewFrame.size.height -= 55;
    [[self view] setFrame:viewFrame];

    doneButton.enabled = NO;

    keyboardShown = NO;
}

- (id)initWithNode:(Node*)aNode andEditProperty:(NodeTextEditPropertyType)property {
    if (self = [super init]) {
        self.node = aNode;
        self.editProperty = property;
        keyboardShown = NO;
        indentLevel = 0;
        valueBeforeEditing = nil;
    }
    return self;
}

- (void)loadView {
    textView = [[UITextView alloc] init];
    [textView setScrollEnabled:YES];
    [textView setScrollsToTop:YES];
    [textView setFont:[UIFont systemFontOfSize:14.0]];
    [textView setDelegate:self];
    [self setView:textView];

    bool created;

    // TODO: make the setText calls use this instead
    // [self unindentText:[node heading]] etc

    if (self.editProperty == NodeTextEditPropertyHeading) {
        [self setTitle:@"Edit Heading"];
        [textView setText:[node heading]];
        [self setValueBeforeEditing:[node heading]];
        [self setEditAction:FindOrCreateLocalEditActionForNode(@"edit:heading", node, &created)];
    } else if (self.editProperty == NodeTextEditPropertyBody) {
        [self setTitle:@"Edit Body"];
        [textView setText:[node body]];
        [self setValueBeforeEditing:[node body]];
        [self setEditAction:FindOrCreateLocalEditActionForNode(@"edit:body", node, &created)];
    }

    if (!self.valueBeforeEditing) {
        self.valueBeforeEditing = @"";
    }

    if (created) {
        self.editAction.oldValue = valueBeforeEditing;
        self.editAction.newValue = valueBeforeEditing;
    }

    doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(onDone)];
    doneButton.enabled = NO;
    self.navigationItem.rightBarButtonItem = doneButton;

    Save();
}

// Sent right after the user starts to change, but right before the change is made
- (void)textViewDidBeginEditing:(UITextView *)textView {
}

- (NSString*)unindentText:(NSString*)input {

    indentLevel = 9999;

    NSArray *lines = [textView.text componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSArray *captures = [line captureComponentsMatchedByRegex:@"( +).+"];
        if ([captures count] > 0) {
            int spaces = [[captures objectAtIndex:0] length];
            if (spaces < indentLevel)
                indentLevel = spaces;
        }
    }

    for (NSString *line in lines) {
        // TODO: Do the unindention
    }

    return nil;
}

- (NSString*)reindentedText {
    if (indentLevel == 0) {
        return textView.text;
    } else {
        NSString *newText = @"";
        NSArray *lines = [textView.text componentsSeparatedByString:@"\n"];
        for (NSString *line in lines) {
            for (int i = 0; i < indentLevel; i++) {
                newText = [newText stringByAppendingString:@" "];
            }
            newText = [newText stringByAppendingFormat:@"%@\n", line];
        }
        return newText;
    }
}

// Sent right after a change has been made
- (void)textViewDidChange:(UITextView *)aTextView {
    [self.editAction setNewValue:aTextView.text];

    if (self.editProperty == NodeTextEditPropertyHeading) {
        [node setHeading:aTextView.text];
    } else if (self.editProperty == NodeTextEditPropertyBody) {
        [node setBody:aTextView.text];
    }

    Save();
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self registerForKeyboardNotifications];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [self unregisterForKeyboardNotifications];

    if ([self.editAction.oldValue isEqualToString:self.editAction.newValue]) {
        DeleteLocalEditAction([self editAction]);
        self.editAction = nil;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
}

- (void)dealloc {
    [valueBeforeEditing release];
    [editAction release];
    [node release];
    [textView release];
    [doneButton release];
    [super dealloc];
}

@end
