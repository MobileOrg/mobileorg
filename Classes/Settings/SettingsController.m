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

#ifndef __GNUC__
#define __asm__ asm
#endif

__asm__(".weak_reference _OBJC_CLASS_$_NSURL");

#import "SettingsController.h"
#import "Settings.h"
#import "DataUtils.h"
#import "GlobalUtils.h"
#import "SearchController.h"
#import "OutlineViewController.h"
#import "SessionManager.h"
#import "MobileOrgAppDelegate.h"
#import "DropboxTransferManager.h"

@implementation SettingsController

enum {
    ServerModeGroup,
    ServerSettingsGroup,
    AppInfoGroup,
    SettingsGroup,
    EncryptionGroup,
    CreditsGroup,
    NumGroups
};

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
    return NumGroups;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {

    NSString *title = nil;
    switch (section) {
        case ServerModeGroup:
            title = NSLocalizedString(@"Server Config", @"Server configuration title");
            break;
        case ServerSettingsGroup:
            break;
        case AppInfoGroup:
            title = NSLocalizedString(@"App Info", @"App info title");
            break;
        case SettingsGroup:
            title = NSLocalizedString(@"Settings", @"App settings");
            break;
        case EncryptionGroup:
            title = NSLocalizedString(@"Encryption", @"Encryption config");
            break;            
        case CreditsGroup:
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
        case ServerModeGroup:
            return 1;
            break;
        case ServerSettingsGroup:
            if ([[Settings instance] serverMode] == ServerModeDropbox) {
                return 2;
            } else {
                return 3;
            }
            break;
        case AppInfoGroup:
            return 2;
            break;
        case SettingsGroup:
            return 1;
            break;
        case EncryptionGroup:
            return 1;
            break;
        case CreditsGroup:
            return 5;
            break;            
        default:
            break;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == ServerSettingsGroup) {
        return @"For help on configuration, visit http://mobileorg.ncogni.to";
    } else if (section == EncryptionGroup) {
        return @"If you have configured Org-mode to use encryption, enter your encryption password above.";
    } else {
        return @"";
    }
}

// From Nick @ http://iphoneincubator.com/blog/windows-views/how-to-create-a-data-entry-screen
- (NSArray*)entryFields {
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:3];
    NSInteger tag = 1;
    UIView *aView;
    while (aView = [self.view viewWithTag:tag]) {
        if (aView && [[aView class] isSubclassOfClass:[UIResponder class]]) {
            [ret addObject:aView];
        }
        tag++;
    }
    return ret;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == ServerModeGroup) {

        static NSString *CellIdentifier = @"ServerModeConfigurationSell";

        UISegmentedControl *modeSwitch;
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier] autorelease];

            NSMutableArray *options = [[NSMutableArray alloc] initWithCapacity:2];
            [options addObject:@"WebDAV"];
            [options addObject:@"Dropbox"];

            modeSwitch = [[[UISegmentedControl alloc] initWithItems:options] autorelease];
            
            // TODO: Make this resize when the orientation changes
            if (IsIpad())
                modeSwitch.frame = CGRectMake(44, 0, 680, 48);                
            else
                modeSwitch.frame = CGRectMake(9, 0, 302, 48);

            [options release];

            [cell addSubview:modeSwitch];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];

        } else {
            modeSwitch = (UISegmentedControl*)[cell.contentView viewWithTag:1];
        }

        [modeSwitch addTarget:self action:@selector(modeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        [modeSwitch setSelectedSegmentIndex:[[Settings instance] serverMode]-1];

        return cell;


    } else if (indexPath.section == ServerSettingsGroup) {

        if ([[Settings instance] serverMode] == ServerModeWebDav) {

            static NSString *CellIdentifier = @"SettingsConfigurationCell";

            UITextField *newLabel;
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier] autorelease];
                if (IsIpad())
                    newLabel = [[[UITextField alloc] initWithFrame:CGRectMake(130,13,200,25)] autorelease];
                else
                    newLabel = [[[UITextField alloc] initWithFrame:CGRectMake(100,13,200,25)] autorelease];
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
                    [newLabel setTag:1];
                    [[cell textLabel] setText:@"URL"];
                    newLabel.text = [[[Settings instance] indexUrl] absoluteString];
                    break;
                case 1:
                    [newLabel addTarget:self action:@selector(usernameChanged:) forControlEvents:(UIControlEventEditingDidEnd | UIControlEventEditingDidEnd)];
                    [newLabel setDelegate:self];
                    [newLabel setTag:2];
                    [[cell textLabel] setText:@"Username"];
                    newLabel.text = [[Settings instance] username];
                    break;
                case 2:
                    [newLabel addTarget:self action:@selector(passwordChanged:) forControlEvents:(UIControlEventEditingDidEnd | UIControlEventEditingDidEnd)];
                    [newLabel setDelegate:self];
                    [newLabel setTag:3];
                    [[cell textLabel] setText:@"Password"];
                    [newLabel setSecureTextEntry:YES];
                    newLabel.text = [[Settings instance] password];
                    break;
                default:
                    break;
            }
            return cell;

        } else if ([[Settings instance] serverMode] == ServerModeDropbox) {

            if (indexPath.row == 0) {
                static NSString *CellIdentifier = @"SettingsDropboxConfigurationCell";

                UITextField *newLabel;
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                if (cell == nil) {
                    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier] autorelease];
                    if (IsIpad())
                        newLabel = [[[UITextField alloc] initWithFrame:CGRectMake(130,13,200,25)] autorelease];
                    else
                        newLabel = [[[UITextField alloc] initWithFrame:CGRectMake(100,13,200,25)] autorelease];
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

		[newLabel addTarget:self action:@selector(dropboxIndexChanged:) forControlEvents:(UIControlEventValueChanged | UIControlEventEditingDidEnd)];
		[newLabel setKeyboardType:UIKeyboardTypeURL];
		[newLabel setDelegate:self];
		[newLabel setTag:1];
		[[cell textLabel] setText:@"Index File"];
		newLabel.text = [[Settings instance] dropboxIndex];

                return cell;
            } else {
                static NSString *CellIdentifier = @"SettingsDropboxButtonCell";

                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                if (cell == nil) {
                    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
                } else {

                }

                if ([[DropboxTransferManager instance] isLinked]) {
                    cell.textLabel.text = @"Unlink from Dropbox";
                    [cell.textLabel setTextColor:[UIColor colorWithRed:0.543 green:0.306 blue:0.435 alpha:1.0]];
                } else {
                    cell.textLabel.text = @"Log in to Dropbox";
                    [cell.textLabel setTextColor:[UIColor colorWithRed:0.243 green:0.306 blue:0.435 alpha:1.0]];
                }

                [cell.textLabel setTextAlignment:UITextAlignmentCenter];

                return cell;
            }
        }
    } else if (indexPath.section == AppInfoGroup) {
        static NSString *CellIdentifier = @"SettingsSimpleCell";

        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier] autorelease];
            [[cell detailTextLabel] setAdjustsFontSizeToFitWidth:YES];
            [[cell detailTextLabel] setFont:[UIFont systemFontOfSize:14.0]];
            [[cell detailTextLabel] setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleRightMargin];
        }

        // Set up the cell...
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];

        if (indexPath.row == 0) {
            [[cell textLabel] setText:@"Version"];
#ifdef FOR_APP_STORE
            [cell.detailTextLabel setText:[NSString stringWithFormat:@"MobileOrg %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]]];
#else
            [cell.detailTextLabel setText:[NSString stringWithFormat:@"MobileOrg %@ (build %@)", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
#endif
        } else if (indexPath.row == 1) {
            [[cell textLabel] setText:@"Last Sync"];
            NSDate *last_sync = [[Settings instance] lastSync];
            if (last_sync) {
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                [formatter setDateFormat:@"YYYY-MM-dd EEE HH:mm"];
                [cell.detailTextLabel setText:[formatter stringFromDate:last_sync]];
                [formatter release];
            } else {
                [cell.detailTextLabel setText:@"Not yet synced"];
            }
        }

        return cell;

    } else if (indexPath.section == SettingsGroup) {

        switch (indexPath.row) {
            case 0:
            {
                static NSString *CellIdentifier = @"SettingsAppBadgeCell";

                UISwitch *appBadgeSwitch = nil;
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                if (cell == nil) {
                    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
                    if (IsIpad())
                        appBadgeSwitch = [[[UISwitch alloc] initWithFrame:CGRectMake(620,10,200,25)] autorelease];
                    else
                        appBadgeSwitch = [[[UISwitch alloc] initWithFrame:CGRectMake(200,10,200,25)] autorelease];
                    [cell addSubview:appBadgeSwitch];
                    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
                    [[cell textLabel] setFont:[UIFont boldSystemFontOfSize:15.0]];
                } else {
                    appBadgeSwitch = (UISwitch*)[cell.contentView viewWithTag:1];
                }

                [appBadgeSwitch addTarget:self action:@selector(appBadgeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                [[cell textLabel] setText:@"Show app badge"];
                [appBadgeSwitch setOn:([[Settings instance] appBadgeMode] == AppBadgeModeTotal)];

                return cell;
            }
            default:
                break;
        }

    } else if (indexPath.section == EncryptionGroup) {
        
        switch (indexPath.row) {
            case 0:
            {
                static NSString *CellIdentifier = @"SettingsEncPassKey";
                
                UITextField *newLabel;
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                if (cell == nil) {
                    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier] autorelease];
                    if (IsIpad())
                        newLabel = [[[UITextField alloc] initWithFrame:CGRectMake(130,13,200,25)] autorelease];
                    else
                        newLabel = [[[UITextField alloc] initWithFrame:CGRectMake(100,13,200,25)] autorelease];
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
                
                [newLabel addTarget:self action:@selector(encryptionPasswordChanged:) forControlEvents:(UIControlEventValueChanged | UIControlEventEditingDidEnd)];
                [newLabel setKeyboardType:UIKeyboardTypeDefault];
                [newLabel setDelegate:self];
                [newLabel setSecureTextEntry:YES];
                [newLabel setTag:1];
                [[cell textLabel] setText:@"Password"];
                newLabel.text = [[Settings instance] encryptionPassword];
                return cell;                
            }
            default:
                break;
        }
                
    } else if (indexPath.section == CreditsGroup) {
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

- (void)resetAppData {

    // Session. Clear the saved state
    [[SessionManager instance] reset];
        
    // Clear search
    [[AppInstance() searchController] reset];

    // Delete all nodes
    DeleteAllNodes();

    // Clear outline view
    [[AppInstance() rootOutlineController] reset];

    // Get rid of custom todo state, tags, etc
    [[Settings instance] resetPrimaryTagsAndTodoStates];
    [[Settings instance] resetAllTags];

    // Reset last sync time
    [[Settings instance] setLastSync:nil];
}

- (void)applyNewServerUrl:(NSString*)url {
    // Store the new URL
    [[Settings instance] setIndexUrl:[NSURL URLWithString:url]];

    [self resetAppData];
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

    if ([[textField text] rangeOfRegex:@"http.*\\.(?:org|txt)$"].location == NSNotFound) {
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

        [self applyNewServerUrl:textField.text];
    }
}

- (void)usernameChanged:(id)sender {
    UITextField *textField = (UITextField*)sender;
    [[Settings instance] setUsername:textField.text];
}

- (void)passwordChanged:(id)sender {
    UITextField *textField = (UITextField*)sender;
    [[Settings instance] setPassword:textField.text];
}

- (void)encryptionPasswordChanged:(id)sender {
    UITextField *textField = (UITextField*)sender;
    [[Settings instance] setEncryptionPassword:textField.text];    
}

- (void)dropboxIndexChanged:(id)sender {
    UITextField *textField = (UITextField*)sender;
    [[Settings instance] setDropboxIndex:textField.text];
}

- (void)appBadgeSwitchChanged:(id)sender {
    UISwitch *appBadgeSwitch = (UISwitch*)sender;
    if ([appBadgeSwitch isOn]) {
        [[Settings instance] setAppBadgeMode:AppBadgeModeTotal];
    } else {
        [[Settings instance] setAppBadgeMode:AppBadgeModeNone];
    }
}

- (void)modeSwitchChanged:(id)sender {
    UISegmentedControl *modeSwitch = (UISegmentedControl*)sender;
    if ([[Settings instance] serverMode] != (1 + [modeSwitch selectedSegmentIndex])) {
        [[Settings instance] setServerMode:(1 + [modeSwitch selectedSegmentIndex])];
        [self resetAppData];
    }
    [[self tableView] reloadData];
    [[self tableView] setNeedsDisplay];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 46;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
    // AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
    // [self.navigationController pushViewController:anotherViewController];
    // [anotherViewController release];

    if (indexPath.section == ServerSettingsGroup && [[Settings instance] serverMode] == ServerModeDropbox) {

        if (indexPath.row == 1) {

            [[[self tableView] cellForRowAtIndexPath:indexPath] setSelected:YES animated:YES];

            if ([[DropboxTransferManager instance] isLinked]) {
                [[DropboxTransferManager instance] unlink];
                [[self tableView] reloadData];
                [[self tableView] setNeedsDisplay];
            } else {
                [[DropboxTransferManager instance] login:self];
                [[self tableView] reloadData];
                [[self tableView] setNeedsDisplay];
                //[[self tableView] cellForRowAtIndexPath:indexPath].textLabel.text = @"Logging in...";
            }

            [[[self tableView] cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];
        }
    }
}

- (void)dealloc {

    [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:@"SyncComplete"];
    [pendingNewIndexUrl release];
    [super dealloc];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {

    bool resign = true;

    // Find the next entry field
    for (UIView *view in [self entryFields]) {
        if (view.tag == (textField.tag + 1)) {
            [view becomeFirstResponder];
            resign = false;
            break;
        }
    }

    if (resign)
        [textField resignFirstResponder];

    return YES;
}

- (void)loginDone:(BOOL)successful {
    [[self tableView] reloadData];
    [[self tableView] setNeedsDisplay];
}
@end
