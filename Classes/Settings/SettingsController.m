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
#import "SyncSettingsController.h"
#import "Settings.h"
#import "DataUtils.h"
#import "GlobalUtils.h"
#import "SearchController.h"
#import "OutlineViewController.h"
#import "SessionManager.h"
#import "MobileOrgAppDelegate.h"
#import "MobileOrg-Swift.h"

@implementation SettingsController

enum {
    ServerModeGroup,
    SettingsGroup,
    EncryptionGroup,
    AppInfoGroup,
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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    NSString *title = nil;
    switch (section) {
        case ServerModeGroup:
            break;
        case SettingsGroup:
            break;
        case EncryptionGroup:
            title = NSLocalizedString(@"Encryption", @"Encryption config");
            break;
        case AppInfoGroup:
            title = NSLocalizedString(@"App Info", @"App info title");
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
        case SettingsGroup:
            return 2;
            break;
        case EncryptionGroup:
            return 1;
            break;
        case AppInfoGroup:
            return 2;
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
    if (section == EncryptionGroup) {
        return @"If you have configured Org-mode to use encryption, enter your encryption password above.";
    } else {
        return @"";
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == ServerModeGroup) {
        
        SyncSettingsController *syncSettingsViewController = [[SyncSettingsController alloc] initWithStyle:UITableViewStyleGrouped];
        [self.navigationController pushViewController:syncSettingsViewController animated:YES];
        
        [syncSettingsViewController release];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == ServerModeGroup) {
        
        static NSString *CellIdentifier = @"ServerModeConfigurationSell";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
            
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            [[cell textLabel] setText:@"Sync"];
            
            
        }
        if ([[Settings instance] serverMode] == ServerModeDropbox)
            [[cell detailTextLabel] setText:@"Dropbox"];
        else if ([[Settings instance] serverMode] == ServerModeWebDav)
            [[cell detailTextLabel] setText:@"WebDAV"];
        else
            [[cell detailTextLabel] setText:@""];
        return cell;
        
    } else if (indexPath.section == AppInfoGroup) {
        static NSString *CellIdentifier = @"SettingsSimpleCell";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
            [[cell detailTextLabel] setAdjustsFontSizeToFitWidth:YES];
            [[cell detailTextLabel] setFont:[UIFont systemFontOfSize:14.0]];
            [[cell detailTextLabel] setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleRightMargin];
        }
        
        // Set up the cell...
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
            [cell setSeparatorInset:UIEdgeInsetsZero];
        }
        
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
                    
                    appBadgeSwitch = [[[UISwitch alloc] init] autorelease];
                    cell.accessoryView = appBadgeSwitch;
                    
                    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
                    
                } else {
                    appBadgeSwitch = (UISwitch*)[cell.contentView viewWithTag:1];
                }
                
                if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
                    [cell setSeparatorInset:UIEdgeInsetsZero];
                }
                
                [appBadgeSwitch addTarget:self action:@selector(appBadgeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                [[cell textLabel] setText:@"Show app badge"];
                [appBadgeSwitch setOn:([[Settings instance] appBadgeMode] == AppBadgeModeTotal)];
                
                return cell;
            }
            case 1:
            {
                static NSString *CellIdentifier = @"SettingsLaunchTabCell";
                
                UISwitch *launchTabSwitch = nil;
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                if (cell == nil) {
                    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
                    
                    launchTabSwitch = [[[UISwitch alloc] init] autorelease];
                    cell.accessoryView = launchTabSwitch;
                    
                    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
                } else {
                    launchTabSwitch = (UISwitch*)[cell.contentView viewWithTag:1];
                }
                
                if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
                    [cell setSeparatorInset:UIEdgeInsetsZero];
                }
                
                [launchTabSwitch addTarget:self action:@selector(launchTabSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                [[cell textLabel] setText:@"AutoCapture Mode"];
                [launchTabSwitch setOn:([[Settings instance] launchTab] == LaunchTabCapture)];
                
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
                
                UITextField *encryptionKey;
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                if (cell == nil) {
                    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
                    
                    [[cell detailTextLabel] setText:@" "];
                    cell.detailTextLabel.hidden = YES;
                    encryptionKey = [[UITextField alloc] init];
                    
                    //[[cell viewWithTag:3] removeFromSuperview];
                    //indexFile.tag = 3;
                    
                    [encryptionKey setClearButtonMode:UITextFieldViewModeWhileEditing];
                    [encryptionKey setAutocapitalizationType:UITextAutocapitalizationTypeNone];
                    [encryptionKey setAutocorrectionType:UITextAutocorrectionTypeNo];
                    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
                    
                    encryptionKey.translatesAutoresizingMaskIntoConstraints = NO;
                    [cell.contentView addSubview:encryptionKey];
                    
                    [cell addConstraint:[NSLayoutConstraint constraintWithItem:encryptionKey attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:cell.textLabel attribute:NSLayoutAttributeTrailing multiplier:1 constant:8]];
                    
                    [cell addConstraint:[NSLayoutConstraint constraintWithItem:encryptionKey attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:cell.contentView attribute:NSLayoutAttributeTop multiplier:1 constant:8]];
                    
                    [cell addConstraint:[NSLayoutConstraint constraintWithItem:encryptionKey attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:cell.contentView attribute:NSLayoutAttributeBottom multiplier:1 constant:-8]];
                    
                    [cell addConstraint:[NSLayoutConstraint constraintWithItem:encryptionKey attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:cell.detailTextLabel attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
                    
                    encryptionKey.textAlignment = NSTextAlignmentRight;
                    
                    encryptionKey.delegate = self;
                    
                    
                } else {
                    encryptionKey = (UITextField*)[cell.contentView viewWithTag:1];
                }
                
                [encryptionKey addTarget:self action:@selector(encryptionPasswordChanged:) forControlEvents:(UIControlEventValueChanged | UIControlEventEditingDidEnd)];
                [encryptionKey setKeyboardType:UIKeyboardTypeDefault];
                [encryptionKey setDelegate:self];
                [encryptionKey setSecureTextEntry:YES];
                [encryptionKey setTag:1];
                [[cell textLabel] setText:@"Password"];
                [encryptionKey setPlaceholder:@"Enter Password"];
                encryptionKey.text = [[Settings instance] encryptionPassword];
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
        }
        
        // Set up the cell...
        if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
            [cell setSeparatorInset:UIEdgeInsetsZero];
        }
        
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        switch (indexPath.row) {
            case 0:
                [[cell textLabel] setText:@"Richard Moreland"];
                [[cell detailTextLabel] setText:@"Original Author"];
                break;
            case 1:
                [[cell textLabel] setText:@"Sean Escriva"];
                [[cell detailTextLabel] setText:@"Development and Organization"];
                break;
            case 2:
                [[cell textLabel] setText:@"Alex Rodich"];
                [[cell detailTextLabel] setText:@"Development and Organization"];
                break;
            case 3:
                [[cell textLabel] setText:@"Carsten Dominik"];
                [[cell detailTextLabel] setText:@"Design and Emacs integration"];
                break;
            case 4:
                [[cell textLabel] setText:@"Greg Newman"];
                [[cell detailTextLabel] setText:@"Updated app icon"];
                break;
            case 5:
                [[cell textLabel] setText:@"Christophe Bataillon"];
                [[cell detailTextLabel] setText:@"Original app icon"];
                break;
            case 6:
                [[cell textLabel] setText:@"Joseph Wain of glyphish.com"];
                [[cell detailTextLabel] setText:@"Creative Commons Attribution icons"];
                break;
            case 7:
                [[cell textLabel] setText:@"Chris Trompette"];
                [[cell detailTextLabel] setText:@"Dropbox API work and fixes"];
                break;
            case 8:
                [[cell textLabel] setText:@"Sean Allred"];
                [[cell detailTextLabel] setText:@"Auto capture mode and fixes"];
                break;
        }
        
        return cell;
    }
    
    return nil;
}

- (void)appBadgeSwitchChanged:(id)sender {
    UISwitch *appBadgeSwitch = (UISwitch*)sender;
    if ([appBadgeSwitch isOn]) {
        [[Settings instance] setAppBadgeMode:AppBadgeModeTotal];
    } else {
        [[Settings instance] setAppBadgeMode:AppBadgeModeNone];
    }
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

- (void)encryptionPasswordChanged:(id)sender {
    UITextField *textField = (UITextField*)sender;
    [[Settings instance] setEncryptionPassword:textField.text];
}

- (void)launchTabSwitchChanged:(id)sender {
    UISwitch *launchTabSwitch = (UISwitch*)sender;
    if ([launchTabSwitch isOn]) {
        [[Settings instance] setLaunchTab:LaunchTabCapture];
    } else {
        [[Settings instance] setLaunchTab:LaunchTabOutline];
    }
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:@"SyncComplete"];
    [super dealloc];
    NSLog(@"Deallocated settings view");
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (void)loginDone:(BOOL)successful {
    [[self tableView] reloadData];
    [[self tableView] setNeedsDisplay];
}
@end
