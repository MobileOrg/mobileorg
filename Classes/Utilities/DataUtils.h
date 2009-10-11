//
//  DataUtils.h
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

#import <Foundation/Foundation.h>

@class Node;
@class LocalEditAction;
@class FileChecksum;

bool Save();

void ClearAllFileChecksums();

NSString *ChecksumForFile(NSString *filename);

FileChecksum *CreateChecksumForFile(NSString *filename, NSString *checksum);

Node *RootNode();

// Find a Node instance given an id:someid or an olp:someolp
Node *ResolveNode(NSString *someId);

// Find a Node instance with a given node id
Node *NodeWithId(NSString *nodeId);

// Find a Node instance with a given outline path
Node *NodeWithOutlinePath(NSString *outlinePath);

// Find a level-0 Node instance for a given filename
Node *NodeWithFilename(NSString *filename);

NSArray *AllFileNodes();

void DeleteNode(Node *node);

void DeleteNodesWithFilename(NSString* filename);

void DeleteAllNodes();

LocalEditAction *FindOrCreateLocalEditActionForNode(NSString *actionType, Node *node, bool *created);

NSArray *AllLocalEditActions();

NSArray *AllLocalEditActionsForNode(Node *node);

int CountLocalEditActions();

NSString *EscapeStringForOutlinePath(NSString *input);

NSString *EscapeStringForLinkTitle(NSString *input);

void DeleteLocalEditActions();

void DeleteLocalEditAction(LocalEditAction *action);

NSArray *AllNotes();

NSArray *AllActiveNotes();

int CountNotes();

int CountLocalNotes();

void DeleteNotes();

bool LocalNoteWithModifications(NSString *noteId);
