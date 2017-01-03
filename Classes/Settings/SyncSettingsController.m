//
//  SyncSettingsController.m
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

#import "SyncSettingsController.h"
#import "SettingsController.h"
#import "Settings.h"
#import "DataUtils.h"
#import "GlobalUtils.h"
#import "SearchController.h"
#import "OutlineViewController.h"
#import "SessionManager.h"
#import "MobileOrgAppDelegate.h"
#import "MobileOrg-Swift.h"

@implementation SyncSettingsController

enum {
    ServerModeGroup,
    ServerSettingsGroup,
    NumGroups
};

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setTitle:@"Sync"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[self tableView] reloadData];
    [[self tableView] setNeedsDisplay];
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
    return NumGroups;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case ServerModeGroup:
            return 2;
            break;
        case ServerSettingsGroup:
            if ([[Settings instance] serverMode] == ServerModeDropbox) {
                return 2;
            } else {
                return 3;
            }
            break;
        default:
            break;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == ServerModeGroup) {
        
        static NSString *CellIdentifier = @"SyncSettingsCell";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
        }
        
        if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
            [cell setSeparatorInset:UIEdgeInsetsZero];
        }
        
        switch (indexPath.row) {
            case 0:
                [[cell textLabel] setText:@"Dropbox"];
                
                if ([[Settings instance] serverMode] == ServerModeDropbox)
                    cell.accessoryType = UITableViewCellAccessoryCheckmark;
                else
                    cell.accessoryType = UITableViewCellAccessoryNone;
                
                break;
            case 1:
                [[cell textLabel] setText:@"WebDAV"];
                
                if ([[Settings instance] serverMode] == ServerModeWebDav)
                    cell.accessoryType = UITableViewCellAccessoryCheckmark;
                else
                    cell.accessoryType = UITableViewCellAccessoryNone;
                
                break;
        }
        
        return cell;
        
    } else if (indexPath.section == ServerSettingsGroup) {
        
        if ([[Settings instance] serverMode] == ServerModeWebDav) {
            
            static NSString *CellIdentifier = @"SettingsConfigurationCell";
            
            UITextField *textField;
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            
            if (cell == nil) {
                
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
                
                if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
                    [cell setSeparatorInset:UIEdgeInsetsZero];
                }
                
                [[cell detailTextLabel] setText:@" "];
                cell.detailTextLabel.hidden = YES;
                textField = [[UITextField alloc] init];
                
                //[[cell viewWithTag:3] removeFromSuperview];
                //indexFile.tag = 3;
                
                [textField setClearButtonMode:UITextFieldViewModeWhileEditing];
                [textField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
                [textField setAutocorrectionType:UITextAutocorrectionTypeNo];
                [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
                
                textField.translatesAutoresizingMaskIntoConstraints = NO;
                [cell.contentView addSubview:textField];
                
                [cell addConstraint:[NSLayoutConstraint constraintWithItem:textField attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:cell.textLabel attribute:NSLayoutAttributeTrailing multiplier:1 constant:8]];
                
                [cell addConstraint:[NSLayoutConstraint constraintWithItem:textField attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:cell.contentView attribute:NSLayoutAttributeTop multiplier:1 constant:8]];
                
                [cell addConstraint:[NSLayoutConstraint constraintWithItem:textField attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:cell.contentView attribute:NSLayoutAttributeBottom multiplier:1 constant:-8]];
                
                [cell addConstraint:[NSLayoutConstraint constraintWithItem:textField attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:cell.detailTextLabel attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
                
                textField.textAlignment = NSTextAlignmentRight;
                
                //textField.delegate = self;
                
                
            } else {
                textField = (UITextField*)[cell.contentView viewWithTag:1];
            }
            
            
            // Set up each cell...
            
            switch (indexPath.row) {
                case 0:
                    [textField addTarget:self action:@selector(serverUrlChanged:) forControlEvents:(UIControlEventValueChanged | UIControlEventEditingDidEnd)];
                    [textField setKeyboardType:UIKeyboardTypeURL];
                    [textField setDelegate:self];
                    [textField setTag:1];
                    [[cell textLabel] setText:@"URL"];
                    [textField setPlaceholder:@"Enter URL"];
                    textField.text = [[[Settings instance] indexUrl] absoluteString];
                    break;
                case 1:
                    [textField addTarget:self action:@selector(usernameChanged:) forControlEvents:(UIControlEventEditingDidEnd | UIControlEventEditingDidEnd)];
                    [textField setDelegate:self];
                    [textField setTag:2];
                    [[cell textLabel] setText:@"Username"];
                    [textField setPlaceholder:@"Enter Username"];
                    textField.text = [[Settings instance] username];
                    break;
                case 2:
                    [textField addTarget:self action:@selector(passwordChanged:) forControlEvents:(UIControlEventEditingDidEnd | UIControlEventEditingDidEnd)];
                    [textField setDelegate:self];
                    [textField setTag:3];
                    [[cell textLabel] setText:@"Password"];
                    [textField setPlaceholder:@"Enter Password"];
                    [textField setSecureTextEntry:YES];
                    textField.text = [[Settings instance] password];
                    break;
                default:
                    break;
            }
            return cell;
            
        } else if ([[Settings instance] serverMode] == ServerModeDropbox) {
            
            if (indexPath.row == 0) {
                static NSString *CellIdentifier = @"SettingsDropboxConfigurationCell";
                
                UITextField *indexFile;
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                if (cell == nil) {
                    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
                    
                    [[cell detailTextLabel] setText:@" "];
                    cell.detailTextLabel.hidden = YES;
                    indexFile = [[UITextField alloc] init];
                    
                    //[[cell viewWithTag:3] removeFromSuperview];
                    //indexFile.tag = 3;
                    
                    [indexFile setClearButtonMode:UITextFieldViewModeWhileEditing];
                    [indexFile setAutocorrectionType:UITextAutocorrectionTypeNo];
                    [indexFile setAutocapitalizationType:UITextAutocapitalizationTypeNone];
                    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
                    
                    indexFile.translatesAutoresizingMaskIntoConstraints = NO;
                    [cell.contentView addSubview:indexFile];
                    
                    [cell addConstraint:[NSLayoutConstraint constraintWithItem:indexFile attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:cell.textLabel attribute:NSLayoutAttributeTrailing multiplier:1 constant:8]];
                    
                    [cell addConstraint:[NSLayoutConstraint constraintWithItem:indexFile attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:cell.contentView attribute:NSLayoutAttributeTop multiplier:1 constant:8]];
                    
                    [cell addConstraint:[NSLayoutConstraint constraintWithItem:indexFile attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:cell.contentView attribute:NSLayoutAttributeBottom multiplier:1 constant:-8]];
                    
                    [cell addConstraint:[NSLayoutConstraint constraintWithItem:indexFile attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:cell.detailTextLabel attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
                    
                    indexFile.textAlignment = NSTextAlignmentRight;
                    
                    indexFile.delegate = self;
                    
                    
                } else {
                    indexFile = (UITextField*)[cell.contentView viewWithTag:1];
                }
                
                [indexFile addTarget:self action:@selector(dropboxIndexChanged:) forControlEvents:(UIControlEventValueChanged | UIControlEventEditingDidEnd)];
                [indexFile setKeyboardType:UIKeyboardTypeURL];
                [indexFile setDelegate:self];
                [indexFile setTag:1];
                [[cell textLabel] setText:@"Index File"];
                indexFile.text = [[Settings instance] dropboxIndex];
                
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
                
                [cell.textLabel setTextAlignment:NSTextAlignmentCenter];
                
                return cell;
            }
        }
    }
    return nil;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == ServerSettingsGroup) {
        return @"For help on configuration, visit http://mobileorg.ncogni.to ?????";
    } else {
        return @"";
    }
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == ServerModeGroup) {
        if (indexPath.row == 0)
            [[Settings instance] setServerMode:(ServerModeDropbox)];
        
        if (indexPath.row == 1)
            [[Settings instance] setServerMode:(ServerModeWebDav)];
        
        [self resetAppData];
        
        [[self tableView] reloadData];
        [[self tableView] setNeedsDisplay];
    }
    
    if (indexPath.section == ServerSettingsGroup && [[Settings instance] serverMode] == ServerModeDropbox) {
        
        if (indexPath.row == 1) {
            
            [[[self tableView] cellForRowAtIndexPath:indexPath] setSelected:YES animated:YES];
            
            if ([[DropboxTransferManager instance] isLinked]) {
                [[DropboxTransferManager instance] unlink];
                [[self tableView] reloadData];
                [[self tableView] setNeedsDisplay];
            } else {
                [[DropboxTransferManager instance] login:self];
                // FIXME: State change is not reflected in UI
                [[self tableView] reloadData];
                [[self tableView] setNeedsDisplay];
            }
            
            [[[self tableView] cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];
        }
    }
}

- (void)dropboxIndexChanged:(id)sender {
    UITextField *textField = (UITextField*)sender;
    NSLog(@"dropboxIndexChanged to: %@", textField.text);
    [[Settings instance] setDropboxIndex:textField.text];
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
- (void)serverUrlChanged:(id)sender {
    UITextField *textField = (UITextField*)sender;
    
    if ([[textField text] rangeOfRegex:@"http.*\\.(?:org|txt)$"].location == NSNotFound) {
        
        UIAlertController *alert = [UIAlertController
                                    alertControllerWithTitle:@"Invalid path"
                                    message:@"This setting should be the complete URL to a .org file on a WebDAV server.  For instance, http://www.example.com/private/org/index.org"
                                    preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action")
                                       style:UIAlertActionStyleCancel
                                       handler:nil];
        [alert addAction:cancelAction];
        [self presentViewController:alert animated:YES completion:nil];
        
        [textField setText:@""];
        [textField setPlaceholder:@"Enter valid URL"];
    }
    
    if (![[textField text] isEqualToString:[[[Settings instance] indexUrl] absoluteString]]) {
        if ([[textField text] length] > 0) {
            // The user just changed URLs.  Let's see if they had any local changes.
            // We need to warn them that that the changes they have made will likely
            // not apply to the new data.
            if (CountLocalEditActions() > 0) {
                UIAlertController *alert = [UIAlertController
                                            alertControllerWithTitle:@"Proceed with Change?"
                                            message:@"Changing the URL to another set of files may invalidate the local changes you have made.  You may want to sync with the old URL first instead.\n\nProceed to change URL"
                                            preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction *okAction = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"OK", @"ok action")
                                           style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action)
                                           {
                                               [self applyNewServerUrl:pendingNewIndexUrl];;
                                           }];
                
                UIAlertAction *cancelAction = [UIAlertAction
                                               actionWithTitle:NSLocalizedString(@"Cancel", @"cancel action")
                                               style:UIAlertActionStyleCancel
                                               handler:^(UIAlertAction *action)
                                               {
                                                   urlTextField.text = [[[Settings instance] indexUrl] absoluteString];
                                                   urlTextField = nil;
                                               }];
                
                [alert addAction:cancelAction];
                [alert addAction:okAction];
                [self presentViewController:alert animated:YES completion:nil];
                
                [pendingNewIndexUrl release];
                pendingNewIndexUrl = [textField.text copy];
                urlTextField = textField;
                return;
            }
        }
        
        [self applyNewServerUrl:textField.text];
    }
}


- (void)applyNewServerUrl:(NSString*)url {
    // Store the new URL
    [[Settings instance] setIndexUrl:[NSURL URLWithString:url]];
    
    [self resetAppData];
}


- (void)usernameChanged:(id)sender {
    UITextField *textField = (UITextField*)sender;
    [[Settings instance] setUsername:textField.text];
}

- (void)passwordChanged:(id)sender {
    UITextField *textField = (UITextField*)sender;
    [[Settings instance] setPassword:textField.text];
}

- (void)dealloc {
    [pendingNewIndexUrl release];
    [super dealloc];
}
@end
