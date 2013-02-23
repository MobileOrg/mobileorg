//
//  TagEditController.m
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

#import "TagEditController.h"
#import "Node.h"
#import "Settings.h"
#import "DataUtils.h"
#import "LocalEditAction.h"
#import "GlobalUtils.h"

@implementation TagEditController

@synthesize node;
@synthesize editAction;
@synthesize allTags, primaryTags;
@synthesize newTagString;

- (void)commitNewTag {
    [[Settings instance] addTag:newTagString];

    self.allTags = [[Settings instance] allTags];
    self.allTags = [self.allTags sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

    if ([node hasInheritedTag:newTagString]) {
        return;
    }

    [node addTag:newTagString];

    self.editAction.newValue = [node tags];
    Save();

    UpdateEditActionCount();

    [[self tableView] reloadData];
}

// Delegate method for when a new tag is entered
- (void)textFieldDidEndEditing:(UITextField*)aTextField {
    self.newTagString = aTextField.text;
    [aTextField resignFirstResponder];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    switch(buttonIndex) {
        case 0:
            self.newTagString = nil;
            break;
        case 1:
            [self commitNewTag];
            break;
    }
}

- (void)onAddTag {

    // From: http://junecloud.com/journal/code/displaying-a-password-or-text-entry-prompt-on-the-iphone.html

    UIAlertView *passwordAlert = [[UIAlertView alloc] initWithTitle:@"Add New Tag" message:@"\n\n\n"
                                                           delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel",nil) otherButtonTitles:NSLocalizedString(@"OK",nil), nil];

    UILabel *passwordLabel = [[UILabel alloc] initWithFrame:CGRectMake(12,40,260,25)];
    passwordLabel.font = [UIFont systemFontOfSize:16];
    passwordLabel.textColor = [UIColor whiteColor];
    passwordLabel.backgroundColor = [UIColor clearColor];
    passwordLabel.shadowColor = [UIColor blackColor];
    passwordLabel.shadowOffset = CGSizeMake(0,-1);
    passwordLabel.textAlignment = UITextAlignmentCenter;
    passwordLabel.text = @"Enter new tag name and press OK";
    [passwordAlert addSubview:passwordLabel];

    UIImageView *passwordImage = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AlertTextField" ofType:@"png"]]];
    passwordImage.frame = CGRectMake(11,79,262,31);
    [passwordAlert addSubview:passwordImage];

    UITextField *passwordField = [[UITextField alloc] initWithFrame:CGRectMake(16,83,252,25)];
    passwordField.font = [UIFont systemFontOfSize:18];
    passwordField.backgroundColor = [UIColor whiteColor];
    passwordField.secureTextEntry = NO;
    passwordField.keyboardAppearance = UIKeyboardAppearanceAlert;
    passwordField.autocorrectionType = UITextAutocorrectionTypeNo;
    passwordField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    passwordField.delegate = self;
    passwordField.enablesReturnKeyAutomatically = YES;
    [passwordField becomeFirstResponder];
    [passwordAlert addSubview:passwordField];

    [passwordAlert setTransform:CGAffineTransformMakeTranslation(0,109)];
    [passwordAlert show];
    [passwordAlert release];
    [passwordField release];
    [passwordImage release];
    [passwordLabel release];
}

- (id)initWithNode:(Node*)aNode {
    if (self = [super initWithStyle:UITableViewStyleGrouped]) {
        self.node = aNode;
        self.allTags = [[Settings instance] allTags];
        self.allTags = [self.allTags sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
        self.primaryTags = [[Settings instance] primaryTags];
        self.primaryTags = [self.primaryTags sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

        bool created;
        self.editAction = FindOrCreateLocalEditActionForNode(@"edit:tags", node, &created);
        if (created) {
            self.editAction.oldValue = [node tags];
            self.editAction.newValue = [node tags];
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setTitle:@"Edit Tags"];

    // Add sync button
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                               target:self
                                                               action:@selector(onAddTag)];
    self.navigationItem.rightBarButtonItem = addButton;
    [addButton release];
}

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    if ([[[self editAction] oldValue] isEqualToString:[[self editAction] newValue]]) {
        DeleteLocalEditAction([self editAction]);
        self.editAction = nil;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
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

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return [primaryTags count];
    } else if (section == 1) {
        return [allTags count];
    }
    return 0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *CellIdentifier = @"TagEditCellWithoutCheck";
    NSString *tag = @"";
    if (indexPath.section == 0) {
        tag = [primaryTags objectAtIndex:[indexPath row]];
    } else if (indexPath.section == 1) {
        tag = [allTags objectAtIndex:[indexPath row]];
    }

    if ([node hasInheritedTag:tag]) {
        CellIdentifier = @"TagEditCellWithInheritedTag";
    } else if ([node hasTag:tag]) {
        CellIdentifier = @"TagEditCellWithCheck";
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        if ([node hasInheritedTag:tag]) {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
            [[cell textLabel] setTextColor:[UIColor lightGrayColor]];
        } else if ([node hasTag:tag]) {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        }
    }

    [cell.textLabel setText:tag];

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {

    NSString *title = nil;
    switch (section) {
        case 0:
            title = @"Primary tags";
            break;
        case 1:
            title = @"Other tags";
            break;
    }
    return title;
};

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *tag = @"";
    if (indexPath.section == 0) {
        tag = [primaryTags objectAtIndex:[indexPath row]];
    } else if (indexPath.section == 1) {
        tag = [allTags objectAtIndex:[indexPath row]];
    }

    if ([node hasInheritedTag:tag]) {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
        return;
    }

    [node toggleTag:tag];

    if ([node hasTag:tag]) {
        for (NSArray *mutexTagGroup in [[Settings instance] mutuallyExclusiveTagGroups]) {
            if ([mutexTagGroup containsObject:tag]) {
                // Remove the tags that this one is a part of
                for (NSString *otherTag in mutexTagGroup) {
                    if (![tag isEqualToString:otherTag]) {
                        [node removeTag:otherTag];
                    }
                }
            }
        }
    }

    self.editAction.newValue = [node tags];
    Save();

    UpdateEditActionCount();

    [tableView reloadData];
}

- (void)dealloc {
    [node release];
    [allTags release];
    [primaryTags release];
    [editAction release];
    self.newTagString = nil;
    [super dealloc];
}

@end

