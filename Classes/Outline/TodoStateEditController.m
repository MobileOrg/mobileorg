//
//  TodoStateEditController.m
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

#import "TodoStateEditController.h"
#import "Node.h"
#import "Settings.h"
#import "DataUtils.h"
#import "LocalEditAction.h"
#import "GlobalUtils.h"

@implementation TodoStateEditController

@synthesize node;
@synthesize editAction;
@synthesize todoStateGroups;

- (void)onClearState {
    [node setTodoState:@""];

    self.editAction.newValue = @"";

    Save();

    UpdateEditActionCount();

    [[self tableView] reloadData];

    [[self navigationController] popViewControllerAnimated:YES];
}

- (id)initWithNode:(Node*)aNode {
    if (self = [super initWithStyle:UITableViewStyleGrouped]) {
        self.node = aNode;
        self.todoStateGroups = [[Settings instance] todoStateGroups];

        bool created;
        self.editAction = FindOrCreateLocalEditActionForNode(@"edit:todo", node, &created);
        if (created) {
            self.editAction.oldValue = [node todoState];
            self.editAction.newValue = [node todoState];
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setTitle:@"Edit Todo State"];

    UIBarButtonItem *clearButton = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStylePlain target:self action:@selector(onClearState)];
    self.navigationItem.rightBarButtonItem = clearButton;
    [clearButton release];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Scroll us to the existing todo state.. that makes it easier to choose a related item
    // This is kind of ugly, but it has to search through the mess of keyword groups
    if ([node todoState] && [node.todoState length] > 0) {
        long row = NSNotFound;
        int section = 0;
        for (NSMutableArray *group in todoStateGroups) {
            long index = NSNotFound;

            NSMutableArray *todoWords = [group objectAtIndex:0];
            index = [todoWords indexOfObject:[node todoState]];
            if (index != NSNotFound) {
                row = index;
                break;
            }

            NSMutableArray *doneWords = [group objectAtIndex:1];
            index = [doneWords indexOfObject:[node todoState]];
            if (index != NSNotFound) {
                row = index + [todoWords count];
                break;
            }

            section++;
        }

        if (row != NSNotFound) {
            [[self tableView] scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
        }
    }
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
    return [todoStateGroups count];
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[todoStateGroups objectAtIndex:section] objectAtIndex:0] count] +
            [[[todoStateGroups objectAtIndex:section] objectAtIndex:1] count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *cellIdentifier = @"TagEditCell";
    NSString *todoState;

    NSArray *todoStateGroup = [todoStateGroups objectAtIndex:indexPath.section];
    if (indexPath.row < [[todoStateGroup objectAtIndex:0] count]) {
        todoState = [[todoStateGroup objectAtIndex:0] objectAtIndex:indexPath.row];
        cellIdentifier = [cellIdentifier stringByAppendingString:@"IsTodo"];
    } else {
        todoState = [[todoStateGroup objectAtIndex:1] objectAtIndex:indexPath.row-[[todoStateGroup objectAtIndex:0] count]];
        cellIdentifier = [cellIdentifier stringByAppendingString:@"IsDone"];
    }

    if ([todoState isEqualToString:[node todoState]]) {
        cellIdentifier = [cellIdentifier stringByAppendingString:@"WithCheck"];
    } else {
        cellIdentifier = [cellIdentifier stringByAppendingString:@"WithoutCheck"];
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
        if ([todoState isEqualToString:[node todoState]]) {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        }
        if ([cellIdentifier rangeOfString:@"IsTodo"].location != NSNotFound) {
            [[cell textLabel] setTextColor:[UIColor colorWithRed:0.65 green:0 blue:0 alpha:1]];
        } else {
            [[cell textLabel] setTextColor:[UIColor colorWithRed:0.25 green:0.65 blue:0 alpha:1]];
        }
    }

    [cell.textLabel setText:todoState];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *todoState;
    NSArray *todoStateGroup = [todoStateGroups objectAtIndex:indexPath.section];
    if (indexPath.row < [[todoStateGroup objectAtIndex:0] count]) {
        todoState = [[todoStateGroup objectAtIndex:0] objectAtIndex:indexPath.row];
    } else {
        todoState = [[todoStateGroup objectAtIndex:1] objectAtIndex:indexPath.row-[[todoStateGroup objectAtIndex:0] count]];
    }

    [node setTodoState:todoState];

    self.editAction.newValue = [node todoState];
    Save();

    UpdateEditActionCount();

    [tableView reloadData];

    [[self navigationController] popViewControllerAnimated:YES];
}

- (void)dealloc {
    [node release];
    [todoStateGroups release];
    [editAction release];
    [super dealloc];
}


@end

