//
//  DataUtils.m
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

#import "DataUtils.h"
#import "GlobalUtils.h"
#import "MobileOrgAppDelegate.h"
#import "Node.h"
#import "LocalEditAction.h"
#import "Note.h"
#import "FileChecksum.h"
#import "Settings.h"
#import "OutlineViewController.h"

bool Save() {

    NSError *error;
    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Call save
    if (![managedObjectContext save:&error]) {
        return false;
    }

    return true;
}

void ClearAllFileChecksums() {

    NSFetchRequest         *request;
    NSEntityDescription    *entity;
    NSArray                *results;
    NSError                *error;
    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Initialize a request
    request = [NSFetchRequest new];

    // We are looking for FileCheckums
    entity  = [NSEntityDescription entityForName:@"FileChecksum"
                          inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];

    // Perform the query
    results = [managedObjectContext executeFetchRequest:request error:&error];

    // Delete the actions
    for (FileChecksum *checksum in results) {
        [managedObjectContext deleteObject:checksum];
    }

    // Save
    Save();

    // Clean up
    [request release];
}

NSString *ChecksumForFile(NSString *filename) {

    NSFetchRequest         *request;
    NSEntityDescription    *entity;
    NSPredicate            *predicate;
    NSArray                *results;
    NSError                *error;
    NSString               *ret = @"";
    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Initialize a request
    request = [NSFetchRequest new];

    // We are looking for a Node
    entity  = [NSEntityDescription entityForName:@"FileChecksum"
                          inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];

    // The id should match the input parameter
    predicate = [NSPredicate predicateWithFormat:@"(filename == %@)", filename];
    [request setPredicate:predicate];

    // Perform the query
    results = [managedObjectContext executeFetchRequest:request error:&error];

    // If there are results, return the first
    if (results && [results count] > 0) {
        FileChecksum *checksum = [results objectAtIndex:0];
        ret = checksum.checksum;
    }

    // Clean up
    [request release];

    // Return checksum, if any
    return ret;
}

FileChecksum *CreateChecksumForFile(NSString *filename, NSString *aChecksum) {

    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Create an action if one didn't exit
    FileChecksum *checksum = (FileChecksum*)[NSEntityDescription insertNewObjectForEntityForName:@"FileChecksum" inManagedObjectContext:managedObjectContext];
    [checksum setFilename:filename];
    [checksum setChecksum:aChecksum];

    Save();

    return checksum;
}

Node *RootNode() {
    return NodeWithFilename([[Settings instance] indexFilename]);
}

Node *ResolveNode(NSString *someId) {

    Node *ret = nil;

    if (!ret && someId && [someId length] > 3 && [someId rangeOfString:@"id:"].location == 0) {
        ret = NodeWithId([someId substringFromIndex:3]);
    }

    if (!ret && someId && [someId length] > 4 && [someId rangeOfString:@"olp:"].location == 0) {
        ret = NodeWithOutlinePath([someId substringFromIndex:4]);
    }

    if (!ret) {
        ret = NodeWithId(someId);
    }

    if (!ret) {
        ret = NodeWithOutlinePath(someId);
    }

    return ret;
}

Node *NodeWithId(NSString *nodeId) {

    NSFetchRequest         *request;
    NSEntityDescription    *entity;
    NSPredicate            *predicate;
    NSArray                *results;
    NSError                *error;
    Node                   *ret = nil;
    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Initialize a request
    request = [NSFetchRequest new];

    // We are looking for a Node
    entity  = [NSEntityDescription entityForName:@"Node"
                          inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];

    // The id should match the input parameter
    predicate = [NSPredicate predicateWithFormat:@"(nodeId == %@)", nodeId];
    [request setPredicate:predicate];

    // Perform the query
    results = [managedObjectContext executeFetchRequest:request error:&error];

    // If there are results, return the first
    if (results && [results count] > 0) {
        ret = [results objectAtIndex:0];
    }

    // Clean up
    [request release];

    // Return matching node, if any
    return ret;
}

Node *NodeWithOutlinePath(NSString *outlinePath) {

    NSFetchRequest         *request;
    NSEntityDescription    *entity;
    NSPredicate            *predicate;
    NSArray                *results;
    NSError                *error;
    Node                   *ret = nil;
    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Initialize a request
    request = [NSFetchRequest new];

    // We are looking for a Node
    entity  = [NSEntityDescription entityForName:@"Node"
                          inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];

    // The id should match the input parameter
    predicate = [NSPredicate predicateWithFormat:@"(outlinePath == %@)", outlinePath];
    [request setPredicate:predicate];

    // Perform the query
    results = [managedObjectContext executeFetchRequest:request error:&error];

    // If there are results, return the first
    if (results && [results count] > 0) {
        ret = [results objectAtIndex:0];
    }

    // Clean up
    [request release];

    // Return matching node, if any
    return ret;
}

Node *NodeWithFilename(NSString *filename) {

    NSFetchRequest         *request;
    NSEntityDescription    *entity;
    NSPredicate            *predicate;
    NSArray                *results;
    NSError                *error;
    Node                   *ret = nil;
    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Initialize a request
    request = [NSFetchRequest new];

    // We are looking for a Node
    entity  = [NSEntityDescription entityForName:@"Node"
                          inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];

    // The level should be 0, which indicates a top-level file node.
    // The title of the node should also be the input parameter filename.
    predicate = [NSPredicate predicateWithFormat:@"(indentLevel == %@) AND (heading == %@)", [NSNumber numberWithInt:0], filename];
    [request setPredicate:predicate];

    // Perform the query
    results = [managedObjectContext executeFetchRequest:request error:&error];

    // If there are results, return the first
    if (results && [results count] > 0) {
        ret = [results objectAtIndex:0];
    }

    // Clean up
    [request release];

    // Return matching node, if any
    return ret;
}

NSArray *AllFileNodes() {

    NSFetchRequest         *request;
    NSEntityDescription    *entity;
    NSPredicate            *predicate;
    NSArray                *results;
    NSError                *error;
    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Initialize a request
    request = [NSFetchRequest new];

    // We are looking for a Node
    entity  = [NSEntityDescription entityForName:@"Node"
                          inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];

    // The level should be 0, which indicates a top-level file node.
    predicate = [NSPredicate predicateWithFormat:@"(indentLevel == %@)", [NSNumber numberWithInt:0]];
    [request setPredicate:predicate];

    // Perform the query
    results = [managedObjectContext executeFetchRequest:request error:&error];

    // Clean up
    [request release];

    // Return matching nodes, if any
    return results;
}

void DeleteNode(Node *node) {

    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    [managedObjectContext deleteObject:node];

    Save();
}

void DeleteNodesWithFilename(NSString* filename) {

    Node *node;
    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    while ((node = NodeWithFilename(filename))) {
        [managedObjectContext deleteObject:node];
        Save();
    }
}

void DeleteAllNodes() {
    for (Node *node in AllFileNodes()) {
        DeleteNode(node);
    }
    Save();
}

LocalEditAction *FindOrCreateLocalEditActionForNode(NSString *actionType, Node *node, bool *created) {

    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // First, try to find an existing action
    for (LocalEditAction *action in AllLocalEditActionsForNode(node)) {
        if ([[action actionType] isEqualToString:actionType]) {
            *created = false;
            return action;
        }
    }

    // Create an action if one didn't exit
    LocalEditAction *action = (LocalEditAction*)[NSEntityDescription insertNewObjectForEntityForName:@"LocalEditAction" inManagedObjectContext:managedObjectContext];
    [action setActionType:actionType];
    [action setCreatedAt:[NSDate date]];
    [action setNodeId:[node bestId]];
    [action setOldValue:@""];
    [action setNewValue:@""];
    *created = true;

    Save();

    [[AppInstance() rootOutlineController] updateBadge];

    return action;
}

NSArray *AllLocalEditActions() {

    NSFetchRequest         *request;
    NSEntityDescription    *entity;
    NSArray                *results;
    NSError                *error;
    NSManagedObjectContext *managedObjectContext;
    NSSortDescriptor       *sortDescriptor;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Initialize a request
    request = [NSFetchRequest new];

    // We are looking for a Node
    entity  = [NSEntityDescription entityForName:@"LocalEditAction"
                          inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];

    // Sort by createdAt, ascendingly!
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"createdAt" ascending:YES];
    [request setSortDescriptors:[NSArray arrayWithObjects:sortDescriptor, nil]];
    [sortDescriptor release];

    // Perform the query
    results = [managedObjectContext executeFetchRequest:request error:&error];

    // Clean up
    [request release];

    // Return matching nodes, if any
    return results;
}

NSArray *AllLocalEditActionsForNode(Node *node) {

    NSFetchRequest         *request;
    NSEntityDescription    *entity;
    NSPredicate            *predicate;
    NSArray                *results;
    NSError                *error;
    NSManagedObjectContext *managedObjectContext;
    NSSortDescriptor       *sortDescriptor;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Initialize a request
    request = [NSFetchRequest new];

    // We are looking for a Node
    entity  = [NSEntityDescription entityForName:@"LocalEditAction"
                          inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];

    // Must match either node ID or Outline Path
    if ([node nodeId] && [node.nodeId length] > 0) {
        predicate = [NSPredicate predicateWithFormat:@"(nodeId == %@) OR (nodeId == %@)", [NSString stringWithFormat:@"id:%@", [node nodeId]] , [node outlinePath]];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"(nodeId == %@)", [node outlinePath]];
    }
    [request setPredicate:predicate];

    // Sort by createdAt, ascendingly!
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"createdAt" ascending:YES];
    [request setSortDescriptors:[NSArray arrayWithObjects:sortDescriptor, nil]];
    [sortDescriptor release];

    // Perform the query
    results = [managedObjectContext executeFetchRequest:request error:&error];

    // Clean up
    [request release];

    // Return matching nodes, if any
    return results;
}

int CountLocalEditActions() {
    NSManagedObjectContext *managedObjectContext;
    managedObjectContext = [AppInstance() managedObjectContext];

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity: [NSEntityDescription entityForName:@"LocalEditAction" inManagedObjectContext:managedObjectContext]];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(oldValue != newValue)"];
    [request setPredicate:predicate];

    NSError *error = nil;
    int count = (int)[managedObjectContext countForFetchRequest:request error:&error];

    [request release];

    return count;
}

NSString *EscapeStringForOutlinePath(NSString *input) {
    NSString *ret = input;
    ret = [ret stringByReplacingOccurrencesOfString:@":" withString:@"%3a"];
    ret = [ret stringByReplacingOccurrencesOfString:@"[" withString:@"%5b"];
    ret = [ret stringByReplacingOccurrencesOfString:@"]" withString:@"%5d"];
    ret = [ret stringByReplacingOccurrencesOfString:@"/" withString:@"%2f"];
    return ret;
}

NSString *EscapeStringForLinkTitle(NSString *input) {
    NSString *ret = input;
    ret = [ret stringByReplacingOccurrencesOfString:@"["  withString:@"%5b"];
    ret = [ret stringByReplacingOccurrencesOfString:@"]"  withString:@"%5d"];
    return ret;
}

void DeleteLocalEditActions() {

    NSFetchRequest         *request;
    NSEntityDescription    *entity;
    NSArray                *results;
    NSError                *error;
    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Initialize a request
    request = [NSFetchRequest new];

    // We are looking for a Node
    entity  = [NSEntityDescription entityForName:@"LocalEditAction"
                          inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];

    // Perform the query
    results = [managedObjectContext executeFetchRequest:request error:&error];

    // Delete the actions
    for (LocalEditAction *action in results) {
        [managedObjectContext deleteObject:action];
    }

    // Save
    Save();

    [[AppInstance() rootOutlineController] updateBadge];

    // Clean up
    [request release];
}

void DeleteLocalEditAction(LocalEditAction *action) {
    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    [managedObjectContext deleteObject:action];

    Save();

    [[AppInstance() rootOutlineController] updateBadge];
}

NSArray *AllNotes() {

    NSFetchRequest         *request;
    NSEntityDescription    *entity;
    NSArray                *results;
    NSError                *error;
    NSManagedObjectContext *managedObjectContext;
    NSSortDescriptor       *sortDescriptor;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Initialize a request
    request = [NSFetchRequest new];

    // We are looking for a Node
    entity  = [NSEntityDescription entityForName:@"Note"
                          inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];

    // Sort by createdAt, ascendingly!
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"createdAt" ascending:NO];
    [request setSortDescriptors:[NSArray arrayWithObjects:sortDescriptor, nil]];
    [sortDescriptor release];

    // Perform the query
    results = [managedObjectContext executeFetchRequest:request error:&error];

    // Clean up
    [request release];

    // Return matching nodes, if any
    return results;
}

NSArray *AllActiveNotes() {

    NSFetchRequest         *request;
    NSEntityDescription    *entity;
    NSArray                *results;
    NSError                *error;
    NSManagedObjectContext *managedObjectContext;
    NSSortDescriptor       *sortDescriptor;
    NSPredicate            *predicate;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Initialize a request
    request = [NSFetchRequest new];

    // We are looking for a Node
    entity  = [NSEntityDescription entityForName:@"Note"
                          inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];

    // Filter out deleted notes
    predicate = [NSPredicate predicateWithFormat:@"(deleted == 0)"];
    [request setPredicate:predicate];

    // Sort by createdAt, ascendingly!
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"createdAt" ascending:NO];
    [request setSortDescriptors:[NSArray arrayWithObjects:sortDescriptor, nil]];
    [sortDescriptor release];

    // Perform the query
    results = [managedObjectContext executeFetchRequest:request error:&error];

    // Clean up
    [request release];

    // Return matching nodes, if any
    return results;
}

int CountNotes() {
    NSManagedObjectContext *managedObjectContext;
    managedObjectContext = [AppInstance() managedObjectContext];

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity: [NSEntityDescription entityForName:@"Note" inManagedObjectContext:managedObjectContext]];

    NSError *error = nil;
    int count = (int)[managedObjectContext countForFetchRequest:request error:&error];

    [request release];

    return count;
}

int CountLocalNotes() {
    NSManagedObjectContext *managedObjectContext;
    managedObjectContext = [AppInstance() managedObjectContext];

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity: [NSEntityDescription entityForName:@"Note" inManagedObjectContext:managedObjectContext]];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(locallyModified == 1 AND deleted == 0)"];
    [request setPredicate:predicate];

    NSError *error = nil;
    int count = (int)[managedObjectContext countForFetchRequest:request error:&error];

    [request release];

    return count;
}

void DeleteNotes() {

    NSFetchRequest         *request;
    NSEntityDescription    *entity;
    NSArray                *results;
    NSError                *error;
    NSManagedObjectContext *managedObjectContext;

    // Get our managedObjectContext
    managedObjectContext = [AppInstance() managedObjectContext];

    // Initialize a request
    request = [NSFetchRequest new];

    // We are looking for a Note
    entity  = [NSEntityDescription entityForName:@"Note"
                          inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];

    // Perform the query
    results = [managedObjectContext executeFetchRequest:request error:&error];

    // Delete the actions
    for (Note *note in results) {
        [managedObjectContext deleteObject:note];
    }

    // Save
    Save();

    // Clean up
    [request release];
}

bool LocalNoteWithModifications(NSString *noteId) {
    NSManagedObjectContext *managedObjectContext;
    managedObjectContext = [AppInstance() managedObjectContext];

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity: [NSEntityDescription entityForName:@"Note" inManagedObjectContext:managedObjectContext]];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(locallyModified == 1) AND (noteId == %@)", noteId];
    [request setPredicate:predicate];

    NSError *error = nil;
    NSUInteger count = [managedObjectContext countForFetchRequest:request error:&error];

    [request release];

    return (count > 0);
}
