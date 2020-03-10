//
//  DetailsViewController.m
//  MobileOrg
//
//  Created by Richard Moreland on 10/1/09.
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
//  Configuration of Details page:
//  - Section 1
//    - Heading
//    - Second heading line after <break> (if present)
//    - Body summary
//  - Section 2
//    - Todo state
//    - Tags
//  - Section 3
//    - View as document
//    - Add a reference note
//
//  TODO
//
//  - For cells that are empty (like no body text), show very dimly
//    'Tap to edit' or something to indicate you can edit.
//

#import "DetailsViewController.h"
#import "Node.h"
#import "NodeTextEditController.h"
#import "TagEditController.h"
#import "TodoStateEditController.h"
#import "PriorityEditController.h"
#import "OutlineViewController.h"
#import "SearchController.h"
#import "OutlineState.h"
#import "SessionManager.h"
#import "DataUtils.h"
#import "ActionMenuController.h"
#import "MobileOrg-Swift.h"

typedef enum {
    DetailsViewSectionText,
    DetailsViewSectionProperties,
    DetailsViewSectionActions,
    DetailsViewSectionCount
} DetailsViewSections;

typedef enum {
    DetailsViewPropertiesTodoState,
    DetailsViewPropertiesPriority,
    DetailsViewPropertiesTags,
    DetailsViewPropertiesCount
} DetailsViewProperties;

@interface DetailsViewController(private)
- (void)refreshData;
- (void)updateSiblingButtons;
- (void)showDocumentView;
- (void)changeNode:(Node*)aNode;
@end

@implementation DetailsViewController

@synthesize node;
@synthesize editTarget;

//
// Private methods
//
- (void)refreshData {
    [self setTitle:[editTarget headingForDisplay]];
    [[self tableView] reloadData];
    [self updateSiblingButtons];
}

- (void)updateSiblingButtons {
    Node *parent = [node parent];
    if (parent) {
        NSArray *sortedChildren = [parent sortedChildren];

        int index = 0;
        for (Node *child in sortedChildren) {
            if ([[[[child objectID] URIRepresentation] absoluteString] compare:[[[node objectID] URIRepresentation] absoluteString]] == NSOrderedSame) {
                // Found ourselves in the parent's child list
                break;
            }
            index++;
        }

        [segmented setEnabled:(index > 0) forSegmentAtIndex:0];
        [segmented setEnabled:(index < [sortedChildren count] - 1) forSegmentAtIndex:1];
    } else {
        [segmented setEnabled:NO forSegmentAtIndex:0];
        [segmented setEnabled:NO forSegmentAtIndex:1];
    }

    if ([[node children] count] > 0 || ([node isLink] && ![node isBrokenLink])) {
        [segmented setEnabled:YES forSegmentAtIndex:2];
    } else {
        [segmented setEnabled:NO forSegmentAtIndex:2];
    }
}

- (void)gotoSibling:(int)which {
    Node *parent = [node parent];
    if (parent) {
        NSArray *sortedChildren = [parent sortedChildren];

        int index = 0;
        for (Node *child in sortedChildren) {
            if ([[[[child objectID] URIRepresentation] absoluteString] compare:[[[node objectID] URIRepresentation] absoluteString]] == NSOrderedSame) {
                // Found ourselves in the parent's child list
                break;
            }
            index++;
        }

        int new_index = (index + which) % [sortedChildren count];
        [self changeNode:[sortedChildren objectAtIndex:new_index]];

        // Save session
        OutlineState *state = [OutlineState new];
        state.selectedChildIndex = new_index;
        state.selectionType = OutlineSelectionTypeDetails;
        [[SessionManager instance] replaceTopOutlineState:state];

        [self refreshData];
    }
}

- (void)gotoChildren {
    NSArray *viewControllers = [[self navigationController] viewControllers];

    // We can only pop ourselves off and push a new one if there was a controller above us, too
    if ([viewControllers count] < 2)
        return;

    id c = [viewControllers objectAtIndex:[viewControllers count]-2];

    if ([c class] == [OutlineViewController class] || [c class] == [SearchController class]) {
        NSIndexPath *path = [c pathForNode:node];
        if (path) {
            [[self navigationController] popViewControllerAnimated:NO];
            [[SessionManager instance] popOutlineStateToLevel:(int)[self.navigationController.viewControllers indexOfObject:self]-1];
            [c selectRowAtIndexPath:path withType:OutlineSelectionTypeExpandOutline andAnimation:YES];
        }
    }
}

- (void)segmentAction:(id)sender {
    switch ([segmented selectedSegmentIndex]) {
        case 0:
            [self gotoSibling:-1];
            break;
        case 1:
            [self gotoSibling:1];
            break;
        case 2:
            [self gotoChildren];
            break;
    }
}

- (void)showDocumentView {
    PreviewViewController *controller = [[PreviewViewController alloc] initWith:node];
    [self.navigationController pushViewController:controller animated:YES];

    OutlineState *state = [OutlineState new];
    state.selectionType = OutlineSelectionTypeDocumentView;
    [[SessionManager instance] pushOutlineState:state];
}

- (void)changeNode:(Node*)aNode {
    self.node = aNode;
    self.editTarget = aNode;

    if (aNode.referencedNodeId && [aNode.referencedNodeId length] > 0) {
        Node *targetNode = ResolveNode(aNode.referencedNodeId);
        if (targetNode) {
            self.editTarget = targetNode;
        }
    }
}

//
// Primary methods
//
- (id)initWithNode:(Node*)aNode {
    if (self = [super initWithStyle:UITableViewStyleGrouped]) {
        [self changeNode:aNode];
    }
    return self;
}

- (void)restore:(NSArray*)outlineStates {
    if ([outlineStates count] > 0) {

        OutlineState *thisState = [OutlineState fromDictionary:[outlineStates objectAtIndex:0]];

        switch (thisState.selectionType) {
            case OutlineSelectionTypeDocumentView:
            {
                PreviewViewController *controller = [[PreviewViewController alloc] initWith:node positionToScroll:thisState.scrollPositionY];
                [self.navigationController pushViewController:controller animated:NO];
                break;
            }
            default:
            break;
        }
    }
}

- (void)refreshTableWithNotification:(NSNotification *)notification
{
  [self refreshData];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.cellLayoutMarginsFollowReadableWidth = NO;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshTableWithNotification:) name:@"RefreshTable" object:nil];


    NSMutableArray* buttons = [[NSMutableArray alloc] initWithCapacity:2];
    UIImage *image1 = [UIImage imageNamed:@"up.png"];
    UIImage *image2 = [UIImage imageNamed:@"down.png"];
    UIImage *image3 = [UIImage imageNamed:@"children.png"];
    [buttons addObject:image1];
    [buttons addObject:image2];
    [buttons addObject:image3];

    segmented = [[UISegmentedControl alloc] initWithItems:buttons];
    segmented.frame = CGRectMake(0, 0, 110, 30);
    segmented.momentary = YES;
    [segmented addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];

    UIBarButtonItem* container_item = [[UIBarButtonItem alloc] initWithCustomView:segmented];
    self.navigationItem.rightBarButtonItem = container_item;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshData];

    [[SessionManager instance] popOutlineStateToLevel:(int)[self.navigationController.viewControllers indexOfObject:self]];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return DetailsViewSectionCount;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case DetailsViewSectionText:
            return 2; // Maybe 3 if there is a break?
            break;
        case DetailsViewSectionProperties:
            return DetailsViewPropertiesCount;
            break;
        case DetailsViewSectionActions:
            return 2;
            break;
    }
    return 0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    switch ([indexPath section]) {
        case DetailsViewSectionText:
        {
            if ([indexPath row] == 0) {

                static NSString *CellIdentifier = @"DetailsViewTextCellHeading";

                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                if (cell == nil) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
                } else {

                }

                // TODO: If there is a break, show it as the detail text
                [[cell textLabel] setText:[node headingForDisplay]];
                //if ([node hasBreak]) {
                //    [[cell detailTextLabel] setText:[node breakLine]];
                //}

                if (![[node readOnly] boolValue]) {
                    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
                }

                return cell;

            } else {

                if ([[editTarget body] length] > 0) {

                    static NSString *CellIdentifier = @"DetailsViewTextCellBody";

                    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
                        [[cell textLabel] setFont:[UIFont systemFontOfSize:13.0]];
                    } else {

                    }

                    // TODO: Show a nicer body summary, sans drawers
                    [[cell textLabel] setText:[editTarget bodyForDisplay]];

                    if (![[node readOnly] boolValue]) {
                        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
                    }

                    return cell;

                } else {

                    static NSString *CellIdentifier = @"DetailsViewTextCellBodyEmpty";

                    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
                        [[cell textLabel] setFont:[UIFont italicSystemFontOfSize:13.0]];
                        [[cell textLabel] setTextColor:[UIColor mo_grayColor]];
                    } else {

                    }

                    [[cell textLabel] setText:@"No body text"];

                    if (![[node readOnly] boolValue]) {
                        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
                    }

                    return cell;
                }
            }
        }

        case DetailsViewSectionProperties:
        {
            NSString *CellIdentifier = @"DetailsViewPropertyCell";

            if (indexPath.row == DetailsViewPropertiesTodoState && [[editTarget todoState] length] == 0) {
                CellIdentifier = [CellIdentifier stringByAppendingString:@"Empty"];
            } else if (indexPath.row == DetailsViewPropertiesPriority && [[editTarget priority] length] == 0) {
                CellIdentifier = [CellIdentifier stringByAppendingString:@"Empty"];
            }  else if (indexPath.row == DetailsViewPropertiesTags && [[editTarget tagsForDisplay] length] == 0) {
                CellIdentifier = [CellIdentifier stringByAppendingString:@"Empty"];
            }

            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier];
                [[cell detailTextLabel] setFont:[UIFont systemFontOfSize:13.0]];
            } else {

            }

            if ([indexPath row] == DetailsViewPropertiesTodoState) {
                [[cell textLabel] setText:@"Todo State"];
                if ([[editTarget todoState] length] > 0) {
                    [[cell detailTextLabel] setText:[editTarget todoState]];
                } else {
                    [[cell detailTextLabel] setText:@"None"];
                    [[cell detailTextLabel] setTextColor:[UIColor mo_grayColor]];
                    [[cell detailTextLabel] setFont:[UIFont italicSystemFontOfSize:13.0]];
                }
            } else if ([indexPath row] == DetailsViewPropertiesPriority) {
                [[cell textLabel] setText:@"Priority"];
                if ([[editTarget priority] length] > 0) {
                    [[cell detailTextLabel] setText:[editTarget priority]];
                } else {
                    [[cell detailTextLabel] setText:@"None"];
                    [[cell detailTextLabel] setTextColor:[UIColor mo_grayColor]];
                    [[cell detailTextLabel] setFont:[UIFont italicSystemFontOfSize:13.0]];
                }
            } else if ([indexPath row] == DetailsViewPropertiesTags) {
                [[cell textLabel] setText:@"Tags"];
                if ([[editTarget tagsForDisplay] length] > 0) {
                    [[cell detailTextLabel] setText:[editTarget tagsForDisplay]];
                } else {
                    [[cell detailTextLabel] setText:@"None"];
                    [[cell detailTextLabel] setTextColor:[UIColor mo_grayColor]];
                    [[cell detailTextLabel] setFont:[UIFont italicSystemFontOfSize:13.0]];
                }
            }

            if (![[node readOnly] boolValue]) {
                [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
            }

            return cell;
        }

        case DetailsViewSectionActions:
        {
            static NSString *CellIdentifier = @"DetailsViewActionCell";

            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            } else {

            }

            if ([indexPath row] == 0) {
                cell.textLabel.text = @"View as Document";
            } else if ([indexPath row] == 1) {
                cell.textLabel.text = @"Flag this Node";
            }

            [cell.textLabel setTextAlignment:NSTextAlignmentCenter];
            [cell.textLabel setTextColor:[UIColor mo_tertiaryTextColor]];

            return cell;
        }
    }

    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == DetailsViewSectionActions && indexPath.row == 0) {
        [[[self tableView] cellForRowAtIndexPath:indexPath] setSelected:YES animated:YES];
        [self showDocumentView];
        [[[self tableView] cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];
        return;
    } else if (indexPath.section == DetailsViewSectionActions && indexPath.row == 1) {
      
        ActionMenuController *controller = [[ActionMenuController alloc] init];
        [controller setNode:editTarget];
        [controller setShowDocumentViewButton:false];
        [controller showActionSheet:self on:[tableView cellForRowAtIndexPath:indexPath]];

        [[[self tableView] cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];
        return;
    }

    if ([[node readOnly] boolValue]) {
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }

    if ([indexPath section] == DetailsViewSectionText && [indexPath row] == 0) {
        NodeTextEditController *controller = [[NodeTextEditController alloc] initWithNode:editTarget andEditProperty:NodeTextEditPropertyHeading];
        [[self navigationController] pushViewController:controller animated:YES];
    } else if ([indexPath section] == DetailsViewSectionText && [indexPath row] == 1) {
        NodeTextEditController *controller = [[NodeTextEditController alloc] initWithNode:editTarget andEditProperty:NodeTextEditPropertyBody];
        [[self navigationController] pushViewController:controller animated:YES];
    } else if ([indexPath section] == DetailsViewSectionProperties && [indexPath row] == DetailsViewPropertiesTodoState) {
        TodoStateEditController *controller = [[TodoStateEditController alloc] initWithNode:editTarget];
        [[self navigationController] pushViewController:controller animated:YES];
    } else if ([indexPath section] == DetailsViewSectionProperties && [indexPath row] == DetailsViewPropertiesPriority) {
        PriorityEditController *controller = [[PriorityEditController alloc] initWithNode:editTarget];
        [[self navigationController] pushViewController:controller animated:YES];
    } else if ([indexPath section] == DetailsViewSectionProperties && [indexPath row] == DetailsViewPropertiesTags) {
        TagEditController *controller = [[TagEditController alloc] initWithNode:editTarget];
        [[self navigationController] pushViewController:controller animated:YES];
    }
}

@end
