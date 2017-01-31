//
//  SearchController.m
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

#import "SearchController.h"
#import "Node.h"
#import "OutlineViewController.h"
#import "Settings.h"
#import "DetailsViewController.h"
#import "MobileOrgAppDelegate.h"
#import "DataUtils.h"
#import "GlobalUtils.h"

@implementation SearchController

@synthesize search_bar;
@synthesize nodesArray;

- (void)reset {
    [self.navigationController popToRootViewControllerAnimated:NO];
    [nodesArray removeAllObjects];
    search_bar.text = @"";
    [[self tableView] reloadData];
}

- (NSIndexPath*)pathForNode:(Node*)node {
    int index = (int)[[self nodesArray] indexOfObject:node];
    if (index >= 0 && index < [nodesArray count]) {
        return [NSIndexPath indexPathForRow:index inSection:0];
    }
    return nil;
}

- (id)selectRowAtIndexPath:(NSIndexPath*)indexPath withType:(OutlineSelectionType)selectionType andAnimation:(bool)animation {

    Node *node = (Node *)[nodesArray objectAtIndex:indexPath.row];

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
            DetailsViewController *controller = [[[DetailsViewController alloc] initWithNode:node] autorelease];
            [[self navigationController] pushViewController:controller animated:animation];
            ret = controller;
            break;
        }
      default:
            break;
    }

    return ret;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.cellLayoutMarginsFollowReadableWidth = NO;

    [self setTitle:@"Search"];

    search_bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 20, 320, 100)];
    search_bar.autocorrectionType = UITextAutocorrectionTypeNo;
    search_bar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    search_bar.delegate = self;
    search_bar.showsCancelButton = YES;
    search_bar.showsScopeBar = YES;
    search_bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    // TODO: When in a focused search, tint nav bar grey, tint search bar grey, add toolbar icon to 'Remove Filter' or something
    // Or perhaps just show an additional bar under the scope

    NSMutableArray *scopes = [[NSMutableArray alloc] init];
    [scopes addObject: NSLocalizedString(@"All", @"Search everything")];
    [scopes addObject: NSLocalizedString(@"Text", @"Search node text only")];
    [scopes addObject: NSLocalizedString(@"Tags", @"Search tags only")];
    [scopes addObject: NSLocalizedString(@"Todo State", @"Search todo state only")];
    search_bar.scopeButtonTitles = scopes;
    search_bar.selectedScopeButtonIndex = 0;
    [scopes release];

    self.tableView.tableHeaderView = search_bar;
}

- (void)performSearch:(NSString*)term {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Node" inManagedObjectContext:[AppInstance() managedObjectContext]];
    [request setEntity:entity];

    NSNumber *predLevel = [[NSNumber alloc] initWithInt:0];
    NSPredicate *predicate = nil;

    switch (search_bar.selectedScopeButtonIndex) {
        case 0:
            predicate = [NSPredicate predicateWithFormat:
                         @"(heading contains[cd] %@) OR (body contains[cd] %@) OR (tags contains[cd] %@) OR (todoState contains[cd] %@)", term, term, term, term];
            break;
        case 1:
            predicate = [NSPredicate predicateWithFormat:
                         @"(heading contains[cd] %@) OR (body contains[cd] %@)", term, term];
            break;
        case 2:
            predicate = [NSPredicate predicateWithFormat:
                         @"(tags contains[cd] %@)", term];
            break;
        case 3:
            predicate = [NSPredicate predicateWithFormat:
                         @"(todoState contains[cd] %@)", term];
            break;
    }
    [request setPredicate:predicate];
    [predLevel release];

    NSError *error;
    NSMutableArray *mutableFetchResults = [[[AppInstance() managedObjectContext] executeFetchRequest:request error:&error] mutableCopy];
    if (mutableFetchResults == nil) {
        // TODO: Error
    }

    // Get rid of nodes that are owned by the agenda, they are by definition duplicates
    NSMutableArray *nodesToRemove = [[NSMutableArray alloc] init];
    for (Node *node in mutableFetchResults) {
        if ([[node ownerFile] compare:@"agendas.org"] == NSOrderedSame) {
            [nodesToRemove addObject:node];
        }
    }
    for (Node *node in nodesToRemove) {
        [mutableFetchResults removeObject:node];
    }
    [nodesToRemove release];

    [self setNodesArray:mutableFetchResults];

    [[self tableView] reloadData];

    [mutableFetchResults release];
    [request release];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self performSearch:[searchBar text]];
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    if (![searchBar isFirstResponder] && [[searchBar text] length] > 0) {
        [self performSearch:[searchBar text]];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([searchText length] == 0 && ![searchBar isFirstResponder]) {
        [self setNodesArray:nil];
        [[self tableView] reloadData];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[self tableView] reloadData];
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
    return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [nodesArray count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *CellIdentifier = @"Cell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }

    // Set up the cell...
    Node *node = [nodesArray objectAtIndex:indexPath.row];
    cell.textLabel.text = [node headingForDisplay];

    NSMutableArray *context = [[NSMutableArray alloc] init];
    Node *parent = [node parent];
    while (parent) {
        [context addObject:parent];
        parent = [parent parent];
    }

    NSString *context_str = @"";
    for (int i = (int)[context count]-1; i >= 0; i--) {
        if ([context_str length] > 0) {
            context_str = [NSString stringWithFormat:@"%@ > %@", context_str, [[context objectAtIndex:i] headingForDisplay]];
        } else {
            context_str = [[context objectAtIndex:i] headingForDisplay];
        }
    }

    if ([context_str length] == 0) {
        context_str = @"Root";
    }
    [context release];

    cell.detailTextLabel.text = context_str;
    cell.accessoryType = UIButtonTypeDetailDisclosure;

    // TODO: It'd be nice to use the fancy cells here

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self selectRowAtIndexPath:indexPath withType:OutlineSelectionTypeExpandOutline andAnimation:YES];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self selectRowAtIndexPath:indexPath withType:OutlineSelectionTypeDetails andAnimation:YES];
}

- (void)dealloc {
    [search_bar release];
    [nodesArray release];
    [super dealloc];
}

@end
