//
//  OutlineViewController.m
//  MobileOrg
//
//  Created by Richard Moreland on 9/30/09.
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

#import "OutlineViewController.h"
#import "DataUtils.h"
#import "TableUtils.h"
#import "Node.h"
#import "SyncManager.h"
#import "DetailsViewController.h"
#import "Settings.h"
#import "SessionManager.h"
#import "OutlineState.h"
#import "DocumentViewController.h"
#import "ActionMenuController.h"
#import "OutlineTableView.h"

//
// Private interface
//
@interface OutlineViewController(private)
- (bool)refreshData;
- (bool)isTopmostOutline;
- (void)onSync;
- (void)onSyncComplete;
@end

@implementation OutlineViewController

//
// Properties
//
@synthesize root;
@synthesize nodes;

//
// Private methods
//
- (bool)refreshData {

    if ([self root]) {

        // Fetch children from coredata
        [self setNodes:[[self root] sortedChildren]];

        // Rebuild table contents
        [[self tableView] reloadData];

        // Refresh the title
        if ([self isTopmostOutline]) {
            [self setTitle:@"Outlines"];
        } else {
            [self setTitle:[[self root] headingForDisplay]];
        }

        [self updateBadge];

        return true;

    } else {
        [self setTitle:@"Outlines"];
        [self updateBadge];
        [[self tableView] reloadData];
        return false;
    }
}

// Is this controller the topmost?
- (bool)isTopmostOutline {
    return [[[self navigationController] viewControllers] objectAtIndex:0] == self;
}

// Kick off a sync
- (void)onSync {
    if ([self.nodes count] > 0) {
        [[self tableView] scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
    [[SyncManager instance] sync];
}

- (void)onSyncComplete {
    [self setRoot:RootNode()];
    [self refreshData];
}

- (void)goHome {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (id)selectRowAtIndexPath:(NSIndexPath*)indexPath withType:(OutlineSelectionType)selectionType andAnimation:(bool)animation {

    Node *node = [[self nodes] objectAtIndex:[indexPath row]];

    // Resolve links here
    if ([node isLink]) {
        // TODO: If we're going to let users link using id or olp vs. just file: links, this is where.
        // Perhaps we should do:  node = [node linkedNode];
        Node *newNode = NodeWithFilename([node linkFile]);
        if (newNode) {
            node = newNode;
        }
    }

    // Force the type to be details if there are no children
    if ([[node children] count] == 0 && (selectionType == OutlineSelectionTypeDontCare || selectionType == OutlineSelectionTypeExpandOutline)) {
        selectionType = OutlineSelectionTypeDetails;
    }

    // Save state
    {
        OutlineState *state = [OutlineState new];
        state.selectedChildIndex = indexPath.row;
        state.selectionType = selectionType;
        [[SessionManager instance] pushOutlineState:state];
        [state release];
    }

    id ret = nil;

    switch (selectionType) {
        case OutlineSelectionTypeExpandOutline:
        {
            OutlineViewController *controller = [[[OutlineViewController alloc] initWithRootNode:node] autorelease];
            [[self navigationController] pushViewController:controller animated:animation];
            ret = controller;
            break;
        }
        case OutlineSelectionTypeDetails:
        {
            DetailsViewController *controller = [[[DetailsViewController    alloc] initWithNode:node] autorelease];
            [[self navigationController] pushViewController:controller animated:animation];
            ret = controller;
            break;
        }
        case OutlineSelectionTypeDocumentView:
        {
            DocumentViewController *controller = [[[DocumentViewController alloc] init] autorelease];
            [controller setNode:node];
            [[self navigationController] pushViewController:controller animated:animation];
            ret = controller;
            break;
        }
    }

    return ret;
}

- (NSIndexPath*)pathForNode:(Node*)node {
    int index = [[self nodes] indexOfObject:node];
    if (index >= 0 && index < [nodes count]) {
        return [NSIndexPath indexPathForRow:index inSection:0];
    }
    return nil;
}

- (void)updateBadge {
    // Update the badge to indicate how many unsynced edits we've got
    if ([[self.navigationController.viewControllers objectAtIndex:0] class] == [self class]) {
        int numLocalEdits = CountLocalEditActions();
        if (numLocalEdits > 0) {
            self.navigationController.tabBarItem.badgeValue = [[NSNumber numberWithInt:numLocalEdits] stringValue];
            self.navigationItem.leftBarButtonItem.enabled = YES;
        } else {
            self.navigationController.tabBarItem.badgeValue = nil;
            self.navigationItem.leftBarButtonItem.enabled = NO;
        }
    }
}

- (void)setHasConnectivity:(bool)flag {
    hasConnectivity = flag;

    if (hasConnectivity && [[Settings instance] isConfiguredProperly]) {
        syncButton.enabled = YES;
    } else {
        syncButton.enabled = NO;
    }
}

- (void)restore:(NSArray*)outlineStates {

    [self refreshData];

    if ([outlineStates count] > 0) {
        OutlineState *thisState = [OutlineState fromDictionary:[outlineStates objectAtIndex:0]];
        NSArray *newStates = [outlineStates subarrayWithRange:NSMakeRange(1, [outlineStates count]-1)];
        NSIndexPath *path = [NSIndexPath indexPathForRow:thisState.selectedChildIndex inSection:0];

        id controller = [self selectRowAtIndexPath:path withType:thisState.selectionType andAnimation:NO];
        if ([controller respondsToSelector:@selector(restore:)]) {
            [controller restore:newStates];
        }

        // We should set the new doc view's scrollY here.. this is kind of ugly.
        // It'd be better to refactor this so each object restores its own state
        // rather than letting the one above him do it.
        if ([controller respondsToSelector:@selector(setScrollTo:)]) {
            [controller setScrollTo:thisState.scrollPositionY];
        }

        [[self tableView] reloadData];
        [[self tableView] setNeedsDisplay];
        [[self tableView] scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    }
}

- (void)reset {
    [self goHome];
    self.root = nil;
    self.nodes = nil;
    [self refreshData];
}

- (void)delayedOneFingerTouch:(NSIndexPath*)path {
    Node *node = [[self nodes] objectAtIndex:path.row];
    if (node) {

        // TODO?
        //[self setFlaggingPath:path];

        // TODO: This isn't good, I think this making a whole nother cell.
        UITableViewCell *cell = [[self tableView] cellForRowAtIndexPath:path];

        ActionMenuController *controller = [[[ActionMenuController alloc] initWithNibName:nil bundle:nil] autorelease];
        [controller setNode:node];
        [controller setCell:cell];
        [controller setShowDocumentViewButton:true];
        [controller setFirstNavController:[self navigationController]];
        [controller setParentController:self];
        [self presentModalViewController:controller animated:YES];

        if (cell) {
            [cell setHighlighted:YES];
        }
    } else {
        // TODO: This isn't good, I think this is making a whole nother cell.
        UITableViewCell *cell = [[self tableView] cellForRowAtIndexPath:path];
        if (cell) {
            [cell setHighlighted:NO];
        }
    }
}

//
// Initialization
//
// Primary init method
- (id)initWithRootNode:(Node*)node {
    if (self = [super initWithStyle:UITableViewStylePlain]) {
        [self setRoot:node];
        hasConnectivity = false;
    }
    return self;
}

- (void)loadView {
    self.tableView = [[OutlineTableView alloc] init];
    OutlineTableView *v = (OutlineTableView*)self.tableView;
    [v setController:self];
}

- (void)viewDidLoad {

    [super viewDidLoad];

    // Initialization is a bit different if we are the topmost outline or not.
    if ([self isTopmostOutline]) {

        // Add sync button
        syncButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                   target:self
                                                                   action:@selector(onSync)];

        self.navigationItem.rightBarButtonItem = syncButton;

        // Subscribe to onSyncComplete messages (only the root controller needs to do this)
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onSyncComplete)
                                                     name:@"SyncComplete"
                                                   object:nil];

    } else {
        if ([self root]) {

            homeButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"home.png"] style:UIBarButtonItemStylePlain target:self action:@selector(goHome)];
            self.navigationItem.rightBarButtonItem = homeButton;
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];

    // Enable/disable sync button if appropriate
    if (hasConnectivity && [[Settings instance] isConfiguredProperly]) {
        syncButton.enabled = YES;
    } else {
        syncButton.enabled = NO;
    }

    // TODO: Show 'you need to set it up' or 'you need to sync' overlay if appropriate

    // Save our state by getting rid of anything above us in the session
    [[SessionManager instance] popOutlineStateToLevel:[self.navigationController.viewControllers indexOfObject:self]];

    // TODO: For now, just always refresh when we're going to display
    // Perhaps this isn't the best thing, it'd be nice if we didn't call
    // this unless it was necessary.
    //
    // How can we know it was necessary?  Well, if there was an 'EditHappened'
    // notification with a node id, we could see if our node was involved.
    //
    // Just have to be careful, since an edit far above us (say a tag change)
    // could affect us. (inherited)
    //
    [self refreshData];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

    // Release any cached data, images, etc that aren't in use.
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [nodes count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *cellIdentifier;
    Node *node;
    UITableViewCell *cell;

    // Extract the node from our array
    node = [[self nodes] objectAtIndex:[indexPath row]];

    // Various node configurations have different cell identifiers for reuse
    cellIdentifier = OutlineCellIdentifierForNode(node);

    // Setup the cell using our helper methods
    cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
        SetupOutlineCellForNode(cell, node);
    }

    PopulateOutlineCellForNode(cell, node);

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    Node *node = [[self nodes] objectAtIndex:[indexPath row]];
    return RowHeightForOutlineCellForNode(node);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self selectRowAtIndexPath:indexPath
                      withType:OutlineSelectionTypeExpandOutline
                  andAnimation:YES];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self selectRowAtIndexPath:indexPath
                      withType:OutlineSelectionTypeDetails
                  andAnimation:YES];
}

- (void)dealloc {

    if ([self isTopmostOutline]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:@"SyncComplete"
                                                      object:nil];
    }

    [nodes release];
    [root release];
    [syncButton release];
    [homeButton release];
    [super dealloc];
}

@end
