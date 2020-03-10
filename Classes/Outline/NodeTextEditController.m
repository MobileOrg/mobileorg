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
#import "GlobalUtils.h"
#import "MobileOrg-Swift.h"


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
    textView.contentInset = contentInsets;
    textView.scrollIndicatorInsets = contentInsets;

        // If text view is hidden by keyboard, scroll it so it's visible
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    if (!CGRectContainsPoint(aRect, self.view.frame.origin) ) {
        [textView scrollRectToVisible:self.view.frame animated:YES];
    }

    // Scroll the active text field into view.
    [textView scrollRangeToVisible:NSMakeRange([textView.text length], 0)];

    doneButton.enabled = YES;

    keyboardShown = YES;
}


// Called when the UIKeyboardDidHideNotification is sent
- (void)keyboardWasHidden:(NSNotification*)aNotification
{
        // Get the height of the Navigation Bar
    CGRect rect = self.navigationController.navigationBar.frame;
    float y = rect.size.height + rect.origin.y;

        // Substract keyboard and navigation bar
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(y, 0.0, 0.0, 0.0);

    textView.contentInset = contentInsets;
    textView.scrollIndicatorInsets = contentInsets;

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
    double fontSize = IsIpad() ? 18.0 : 14.0;
    [textView setFont:[UIFont fontWithName:@"Menlo-Regular" size:fontSize]];

    [textView setDelegate:self];
    [self setView:textView];

    bool created = false;

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
        self.editAction.updatedValue = valueBeforeEditing;
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
            int spaces = (int)[[captures objectAtIndex:0] length];
            if (spaces < indentLevel)
                indentLevel = spaces;
        }
    }

    // TODO: Do the unindention
    //    for (NSString *line in lines) {
    //    }

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
    [self.editAction setUpdatedValue:aTextView.text];

    if (self.editProperty == NodeTextEditPropertyHeading) {
        [node setHeading:aTextView.text];
    } else if (self.editProperty == NodeTextEditPropertyBody) {
        [node setBody:aTextView.text];
    }

    UpdateEditActionCount();

    Save();
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self registerForKeyboardNotifications];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [self unregisterForKeyboardNotifications];

    if ([self.editAction.oldValue isEqualToString:self.editAction.updatedValue]) {
        DeleteLocalEditAction([self editAction]);
        self.editAction = nil;
    }
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
