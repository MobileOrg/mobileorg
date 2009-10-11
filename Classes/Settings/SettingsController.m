//
//  SettingsController.m
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

#import "SettingsController.h"
#import "Settings.h"
#import "DataUtils.h"
#import "GlobalUtils.h"
#import "SearchController.h"
#import "OutlineViewController.h"
#import "SessionManager.h"
#import "MobileOrgAppDelegate.h"

@implementation SettingsController

- (void)onSyncComplete {
    [[Settings instance] setLastSync:[NSDate date]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setTitle:@"Settings"];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onSyncComplete)
                                                 name:@"SyncComplete"
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[self tableView] reloadData];
    [[self tableView] setNeedsDisplay];
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

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {

    NSString *title = nil;
    switch (section) {
        case 0:
            title = NSLocalizedString(@"Server Config", @"Server configuration title");
            break;
        case 1:
            title = NSLocalizedString(@"App Info", @"App info title");
            break;
        case 2:
            title = NSLocalizedString(@"Credits", @"Credits title");
            break;
        default:
            break;
    }
    return title;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return 3;
            break;
        case 1:
            return 2;
            break;
        case 2:
            return 5;
            break;
        default:
            break;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == 0) {

        static NSString *CellIdentifier = @"SettingsConfigurationCell";

        UITextField *newLabel;
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier] autorelease];
            newLabel = [[[UITextField alloc] initWithFrame:CGRectMake(100,13,200,25)] autorelease];
            [newLabel setTag:1];
            [newLabel setAdjustsFontSizeToFitWidth:YES];
            [newLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleRightMargin];
            [newLabel setAutocorrectionType:UITextAutocorrectionTypeNo];
            [newLabel setClearButtonMode:UITextFieldViewModeWhileEditing];
            [newLabel setAutocapitalizationType:UITextAutocapitalizationTypeNone];
            [cell addSubview:newLabel];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];

            CGRect detailFrame = [[cell detailTextLabel] frame];
            detailFrame.origin.y -= 1;
            [[cell detailTextLabel] setFrame:detailFrame];
        } else {
            newLabel = (UITextField*)[cell.contentView viewWithTag:1];
        }

        // Set up the cell...

        switch (indexPath.row) {
            case 0:
                [newLabel addTarget:self action:@selector(serverUrlChanged:) forControlEvents:(UIControlEventValueChanged | UIControlEventEditingDidEnd)];
                [newLabel setKeyboardType:UIKeyboardTypeURL];
                [newLabel setDelegate:self];
                [[cell textLabel] setText:@"URL"];
                newLabel.text = [[[Settings instance] indexUrl] absoluteString];
                break;
            case 1:
                [newLabel addTarget:self action:@selector(usernameChanged:) forControlEvents:(UIControlEventEditingDidEnd | UIControlEventEditingDidEnd)];
                [newLabel setDelegate:self];
                [[cell textLabel] setText:@"Username"];
                newLabel.text = [[Settings instance] username];
                break;
            case 2:
                [newLabel addTarget:self action:@selector(passwordChanged:) forControlEvents:(UIControlEventEditingDidEnd | UIControlEventEditingDidEnd)];
                [newLabel setDelegate:self];
                [[cell textLabel] setText:@"Password"];
                [newLabel setSecureTextEntry:YES];
                newLabel.text = [[Settings instance] password];
                break;
            default:
                break;
        }
        return cell;

    } else if (indexPath.section == 1) {
        static NSString *CellIdentifier = @"SettingsSimpleCell";

        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        UILabel *newLabel;
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier] autorelease];

            newLabel = [[[UILabel alloc] initWithFrame:CGRectMake(100,15,200,20)] autorelease];
            [newLabel setAdjustsFontSizeToFitWidth:YES];
            [newLabel setTag:1];
            [newLabel setFont:[UIFont systemFontOfSize:14.0]];
            [newLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleRightMargin];
            [cell addSubview:newLabel];

            CGRect detailFrame = [[cell detailTextLabel] frame];
            detailFrame.origin.y -= 5;
            [[cell detailTextLabel] setFrame:detailFrame];
        } else {
            newLabel = (UILabel*)[cell.contentView viewWithTag:1];
        }

        // Set up the cell...
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];

        if (indexPath.row == 0) {
            [[cell textLabel] setText:@"Version"];
            [newLabel setText:[NSString stringWithFormat:@"MobileOrg %@ (build %@)", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
        } else if (indexPath.row == 1) {
            [[cell textLabel] setText:@"Last Sync"];
            NSDate *last_sync = [[Settings instance] lastSync];
            if (last_sync) {
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                [formatter setDateFormat:@"YYYY-MM-dd EEE HH:mm"];
                [newLabel setText:[formatter stringFromDate:last_sync]];
                [formatter release];
            } else {
                [newLabel setText:@"Not yet synced"];
            }
        }

        return cell;

    } else if (indexPath.section == 2) {
        static NSString *CellIdentifier = @"SettingsCreditsCell";

        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
            [[cell textLabel] setFont:[UIFont boldSystemFontOfSize:14.0]];
            [[cell detailTextLabel] setFont:[UIFont systemFontOfSize:12.0]];
        }

        // Set up the cell...
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];

        switch (indexPath.row) {
            case 0:
                [[cell textLabel] setText:@"Richard Moreland"];
                [[cell detailTextLabel] setText:@"Design and development"];
                break;
            case 1:
                [[cell textLabel] setText:@"Carsten Dominik"];
                [[cell detailTextLabel] setText:@"Design and Emacs integration"];
                break;
            case 2:
                [[cell textLabel] setText:@"Greg Newman"];
                [[cell detailTextLabel] setText:@"Updated app icon"];
                break;
            case 3:
                [[cell textLabel] setText:@"Christophe Bataillon"];
                [[cell detailTextLabel] setText:@"Original app icon"];
                break;
            case 4:
                [[cell textLabel] setText:@"Joseph Wain of glyphish.com"];
                [[cell detailTextLabel] setText:@"Creative Commons Attribution icons"];
                break;
        }

        return cell;
    }

    return nil;
}

- (void)applyNewServerUrl:(NSString*)url {

    // Store the new URL
    [[Settings instance] setIndexUrl:[NSURL URLWithString:url]];

    // Clear search
    [[AppInstance() searchController] reset];

    // Delete all nodes
    DeleteAllNodes();

    // Clear outline view
    [[AppInstance() rootOutlineController] reset];

    // Get rid of custom todo state, tags, etc
    [[Settings instance] resetPrimaryTagsAndTodoStates];
    [[Settings instance] resetAllTags];

    // Session. Clear the saved state
    [[SessionManager instance] reset];
}

// This is the callback for when we are asking the user if they want to proceed with changing the URL
// If we use more of these, add some sort of state to the class so we can determine what handler we are.
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    switch(buttonIndex) {
        case 0:
            urlTextField.text = [[[Settings instance] indexUrl] absoluteString];
            urlTextField = nil;
            break;
        case 1:
            [self applyNewServerUrl:pendingNewIndexUrl];
            break;
    }
}

- (void)serverUrlChanged:(id)sender {
    UITextField *textField = (UITextField*)sender;

    if ([[textField text] rangeOfRegex:@"http.*\\.org$"].location == NSNotFound) {
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle:@"Invalid path"
                              message:@"This setting should be the complete URL to a .org file on a WebDAV server.  For instance, http://www.example.com/private/org/index.org"
                              delegate:nil
                              cancelButtonTitle:@"Cancel"
                              otherButtonTitles:nil];
        [alert show];
        [alert autorelease];
    }

    if (![[textField text] isEqualToString:[[[Settings instance] indexUrl] absoluteString]]) {
        if ([[textField text] length] > 0) {
            // The user just changed URLs.  Let's see if they had any local changes.
            // We need to warn them that that the changes they have made will likely
            // not apply to the new data.
            if (CountLocalEditActions() > 0) {
                UIAlertView *alert = [[UIAlertView alloc]
                                      initWithTitle:@"Proceed with Change?"
                                      message:@"Changing the URL to another set of files may invalidate the local changes you have made.  You may want to sync with the old URL first instead.\n\nProceed to change URL?"
                                      delegate:self
                                      cancelButtonTitle:@"No"
                                      otherButtonTitles:@"Yes", nil];
                [alert show];
                [alert autorelease];

                [pendingNewIndexUrl release];
                pendingNewIndexUrl = [textField.text copy];
                urlTextField = textField;
                return;
            }
        }
    }

    [self applyNewServerUrl:textField.text];
}

- (void)usernameChanged:(id)sender {
    UITextField *textField = (UITextField*)sender;
    [[Settings instance] setUsername:textField.text];
}

- (void)passwordChanged:(id)sender {
    UITextField *textField = (UITextField*)sender;
    [[Settings instance] setPassword:textField.text];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 46;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
    // AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
    // [self.navigationController pushViewController:anotherViewController];
    // [anotherViewController release];
}

- (void)dealloc {

    [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:@"SyncComplete"];
    [pendingNewIndexUrl release];
    [super dealloc];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
