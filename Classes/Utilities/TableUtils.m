//
//  TableUtils.m
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

#import "TableUtils.h"
#import "Node.h"
#import "RoundedLabel.h"
#import "Settings.h"
#import "DataUtils.h"

typedef enum {
    OutlineCellViewTagHeading = 1,
    OutlineCellViewTagBeforeText,
    OutlineCellViewTagBodySummary,
    OutlineCellViewTagTodoState,
    OutlineCellViewTagTags,
    OutlineCellViewTagPriority,
} OutlineCellViewTag;

// TODO:
// We want the heading to be the targetNode's heading always
// But we also want to find out if there is before/after text
// If there is:
// - After text replaces the body text
// - Before text: Goes in a new row at the very top
// - So heading for display always strips out before/after

NSString *OutlineCellIdentifierForNode(Node *node) {
    NSString *ret = @"OutlineCell";

    Node *targetNode = node;
    if (node.referencedNodeId && [node.referencedNodeId length] > 0) {
        Node *n = ResolveNode(node.referencedNodeId);
        if (n) {
            targetNode = n;
        }
    }

    NSString *body = [targetNode bodyForDisplay];
    NSString *afterText = [node afterText];
    if (afterText && [afterText length] > 0) {
        body = afterText;
    }

    if ([[node beforeText] length] > 0) {
        ret = [ret stringByAppendingString:@":withBeforeText"];
    }

    if ([body length] > 0) {
        ret = [ret stringByAppendingString:@":withBodySummary"];
    }

    if ([[targetNode todoState] length] > 0) {
        ret = [ret stringByAppendingFormat:@":withTodoState%@", [targetNode todoState]];
    }

    if ([[targetNode tags] length] > 0 || [[targetNode inheritedTags] length] > 0) {
        ret = [ret stringByAppendingString:@":withTags"];
    }

    if ([targetNode isBrokenLink]) {
        ret = [ret stringByAppendingString:@":isBrokenLink"];
    }

    if ([[targetNode priority] length] > 0) {
        ret = [ret stringByAppendingFormat:@":withPriority"];
    }

    return ret;
}

void SetupOutlineCellForNode(UITableViewCell *cell, Node *node, UITableView *tableView) {

    int yOffset = 3;
    int xOffset = tableView.separatorInset.left;

    // Get a reference to the original node
    // This is necessary for agenda views
    Node *targetNode = node;
    if (node.referencedNodeId && [node.referencedNodeId length] > 0) {
        Node *n = ResolveNode(node.referencedNodeId);
        if (n) {
            targetNode = n;
        }
    }

    // <before> text
    if ([[cell reuseIdentifier] rangeOfString:@":withBeforeText"].location != NSNotFound) {
        UILabel *beforeLabel;
        beforeLabel       = [[[UILabel alloc] initWithFrame:CGRectMake(xOffset, yOffset, 300, 20)] autorelease];
        beforeLabel.tag   = OutlineCellViewTagBeforeText;
        beforeLabel.font  = [UIFont systemFontOfSize:13.0];
        beforeLabel.textColor = [UIColor darkGrayColor];
        beforeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:beforeLabel];

        yOffset += 19;
    }

    // Heading label
    {
        int x = xOffset;
        if ([[cell reuseIdentifier] rangeOfString:@":withPriority"].location != NSNotFound) {
            x += 30;
        }

        UILabel *headingLabel;
        headingLabel      = [[[UILabel alloc] initWithFrame:CGRectMake(x, yOffset, 300, 20)] autorelease];
        headingLabel.tag  = OutlineCellViewTagHeading;
        headingLabel.font = [UIFont boldSystemFontOfSize:15.0];
        headingLabel.textColor = [UIColor blackColor];
        headingLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:headingLabel];
    }

    // Priority label
    if ([[cell reuseIdentifier] rangeOfString:@":withPriority"].location != NSNotFound) {

        UILabel *priorityLabel;
        priorityLabel      = [[[UILabel alloc] initWithFrame:CGRectMake(xOffset, yOffset, 30, 20)] autorelease];
        priorityLabel.tag  = OutlineCellViewTagPriority;
        priorityLabel.font = [UIFont systemFontOfSize:13.0];
        priorityLabel.textColor = [UIColor lightGrayColor];
        [cell.contentView addSubview:priorityLabel];
    }

    // Todo State and Tags labels
    {
        bool hasTodoState = ([[cell reuseIdentifier] rangeOfString:@":withTodoState"].location != NSNotFound);
        bool hasTags      = ([[cell reuseIdentifier] rangeOfString:@":withTags"].location != NSNotFound);

        if (hasTodoState || hasTags) {

            yOffset += 22;

            if (hasTodoState) {
                RoundedLabel *todoStateLabel;
                todoStateLabel       = [[[RoundedLabel alloc] initWithFrame:CGRectMake(xOffset, yOffset, 83, 20)] autorelease];
                todoStateLabel.tag   = OutlineCellViewTagTodoState;
                todoStateLabel.backgroundColor = [UIColor whiteColor];
                todoStateLabel.color = [UIColor colorWithRed:0.65 green:0 blue:0 alpha:1];

                if ([[targetNode todoState] length] > 0) {
                    todoStateLabel.text = [node todoState];
                    if ([[Settings instance] isDoneState:[targetNode todoState]])
                        todoStateLabel.color = [UIColor colorWithRed:0.25 green:0.65 blue:0 alpha:1];
                }

                [cell.contentView addSubview:todoStateLabel];
            }

            if (hasTags) {
                UILabel *tagLabel;
                tagLabel      = [[[UILabel alloc] initWithFrame:CGRectMake(100, yOffset+1, 220, 15)] autorelease];
                tagLabel.tag  = OutlineCellViewTagTags;
                tagLabel.font = [UIFont boldSystemFontOfSize:10.0];
                tagLabel.textColor = [UIColor colorWithRed:0.5 green:0.58 blue:0.682 alpha:1.0];
                tagLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:tagLabel];
            }
        }
    }

    // Body summary label
    if ([[cell reuseIdentifier] rangeOfString:@":withBodySummary"].location != NSNotFound) {

        yOffset += 22;

        UILabel *bodySummaryLabel;
        bodySummaryLabel      = [[[UILabel alloc] initWithFrame:CGRectMake(xOffset, yOffset, 300, 15)] autorelease];
        bodySummaryLabel.tag  = OutlineCellViewTagBodySummary;
        bodySummaryLabel.font = [UIFont systemFontOfSize:13.0];
        bodySummaryLabel.textColor = [UIColor darkGrayColor];
        bodySummaryLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:bodySummaryLabel];
    }

    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
}

void PopulateOutlineCellForNode(UITableViewCell *cell, Node *node) {

    Node *targetNode = node;
    if (node.referencedNodeId && [node.referencedNodeId length] > 0) {
        Node *n = ResolveNode(node.referencedNodeId);
        if (n) {
            targetNode = n;
        }
    }

    NSString *body = [targetNode bodyForDisplay];
    NSString *afterText = [node afterText];
    if (afterText && [afterText length] > 0) {
        body = afterText;
    }

    if ([[cell reuseIdentifier] rangeOfString:@":withBeforeText"].location != NSNotFound) {
        UILabel *beforeLabel = (UILabel*)[cell.contentView viewWithTag:OutlineCellViewTagBeforeText];
        beforeLabel.text = [node beforeText];
    }

    // Heading label
    UILabel *headingLabel = (UILabel*)[cell.contentView viewWithTag:OutlineCellViewTagHeading];
    [headingLabel setText:[targetNode headingForDisplay]];
    if ([node isLink] || [[node children] count] > 0) {
        [headingLabel setText:[NSString stringWithFormat:@"%@...", [headingLabel text]]];
    }

    // Priority
    if ([[cell reuseIdentifier] rangeOfString:@":withPriority"].location != NSNotFound) {
        UILabel *priorityLabel = (UILabel*)[cell.contentView viewWithTag:OutlineCellViewTagPriority];
        [priorityLabel setText:[NSString stringWithFormat:@"[#%@]", [targetNode priority]]];
    }

    // Body summary
    if ([[cell reuseIdentifier] rangeOfString:@":withBodySummary"].location != NSNotFound) {
        UILabel *bodySummaryLabel = (UILabel*)[cell.contentView viewWithTag:OutlineCellViewTagBodySummary];
        [bodySummaryLabel setText:body];
    }

    // Tags
    if ([[cell reuseIdentifier] rangeOfString:@":withTags"].location != NSNotFound) {
        UILabel *tagLabel = (UILabel*)[cell.contentView viewWithTag:OutlineCellViewTagTags];
        [tagLabel setText:[targetNode tagsForDisplay]];
    }

    // Todo state
    if ([[cell reuseIdentifier] rangeOfString:@":withTodoState"].location != NSNotFound) {
        RoundedLabel *todoStateLabel = (RoundedLabel*)[cell.contentView viewWithTag:OutlineCellViewTagTodoState];
        todoStateLabel.text = [targetNode todoState];
    }
}

float RowHeightForOutlineCellForNode(Node *node) {

    float height = 40;

    NSString *identifier = OutlineCellIdentifierForNode(node);

    if ([identifier rangeOfString:@":withBeforeText"].location != NSNotFound) {
        height += 18;
    }

    if ([identifier rangeOfString:@":withBodySummary"].location != NSNotFound) {
        height += 13;
    }

    if ([identifier rangeOfString:@":withTags"].location != NSNotFound ||
        [identifier rangeOfString:@":withTodoState"].location != NSNotFound) {
        height += 18;
    }

    return height;
}
