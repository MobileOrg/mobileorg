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

    self.editAction.updatedValue = [node tags];
    Save();

    UpdateEditActionCount();

    [[self tableView] reloadData];
}

// Delegate method for when a new tag is entered
- (void)textFieldDidEndEditing:(UITextField*)aTextField {
    self.newTagString = aTextField.text;
    [aTextField resignFirstResponder];
}

- (void)onAddTag {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"New Tag" message:@"Enter a new tag" preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
                                                   NSArray * textfields = alertController.textFields;
                                                   UITextField * newTag = textfields[0];
                                                   if (newTag.text != nil) {
                                                       self.newTagString = newTag.text;
                                                       [self commitNewTag];
                                                   }
                                               }];

    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       [alertController dismissViewControllerAnimated:YES completion:nil];
                                                   }];

    [alertController addAction:ok];
    [alertController addAction:cancel];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @" New Tag";
    }];


    id rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
    if([rootViewController isKindOfClass:[UINavigationController class]])
      {
        rootViewController = ((UINavigationController *)rootViewController).viewControllers.firstObject;
      }
    if([rootViewController isKindOfClass:[UITabBarController class]])
      {
        rootViewController = ((UITabBarController *)rootViewController).selectedViewController;
      }
    [rootViewController presentViewController:alertController animated:YES completion:nil];
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
            self.editAction.updatedValue = [node tags];
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

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
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

    self.editAction.updatedValue = [node tags];
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

