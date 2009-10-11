//
//  PriorityEditController.m
//  MobileOrg
//
//  Created by Richard Moreland on 10/11/09.
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

#import "PriorityEditController.h"
#import "Node.h"
#import "Settings.h"
#import "DataUtils.h"
#import "LocalEditAction.h"

@implementation PriorityEditController

@synthesize node;
@synthesize editAction;
@synthesize priorities;

- (void)onClearPriority {
    node.priority = @"";
    self.editAction.newValue = @"";
    Save();
    [[self tableView] reloadData];
}

- (id)initWithNode:(Node*)aNode {
    if (self = [super initWithStyle:UITableViewStyleGrouped]) {
        self.node = aNode;
        self.priorities = [[Settings instance] priorities];
        self.priorities = [self.priorities sortedArrayUsingSelector:@selector(compare:)];

        bool created;
        self.editAction = FindOrCreateLocalEditActionForNode(@"edit:priority", node, &created);
        if (created) {
            self.editAction.oldValue = [node priority];
            self.editAction.newValue = [node priority];
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setTitle:@"Edit Priority"];

    UIBarButtonItem *clearButton = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStylePlain target:self action:@selector(onClearPriority)];
    self.navigationItem.rightBarButtonItem = clearButton;
    [clearButton release];
}

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
    return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [priorities count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *CellIdentifier = @"PriorityEditCellWithoutCheck";
    NSString *priority = [priorities objectAtIndex:[indexPath row]];

    if ([node.priority isEqualToString:priority]) {
        CellIdentifier = @"PriorityEditCellWithCheck";
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        if ([node.priority isEqualToString:priority]) {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        }
    }

    [cell.textLabel setText:priority];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *priority = [priorities objectAtIndex:[indexPath row]];
    node.priority = priority;

    self.editAction.newValue = priority;

    Save();

    [tableView reloadData];
}

- (void)dealloc {
    [node release];
    [priorities release];
    [editAction release];
    [super dealloc];
}

@end
