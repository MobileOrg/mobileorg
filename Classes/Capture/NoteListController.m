//
//  NoteListController.m
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

#import "NoteListController.h"
#import "NewNoteController.h"
#import "Note.h"
#import "Node.h"
#import "DataUtils.h"
#import "GlobalUtils.h"
#import "MobileOrg-Swift.h"

@implementation NoteListController

@synthesize notesArray;

- (void)refreshData {
    self.notesArray = [[AllActiveNotes() mutableCopy] autorelease];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self tableView] reloadData];
    });
    int noteCount = CountLocalNotes();
    if (noteCount > 0) {
        self.navigationController.tabBarItem.badgeValue = [[NSNumber numberWithInt:noteCount] stringValue];
    } else {
        self.navigationController.tabBarItem.badgeValue = nil;
    }

    UpdateAppBadge();

    if ([self.notesArray count] > 0) {
        self.navigationItem.leftBarButtonItem.enabled = YES;
    } else {
        self.navigationItem.leftBarButtonItem.enabled = NO;
    }
}

- (void)onSyncComplete {
    [self refreshData];
}

- (void)stopEditing {
    if ([self isEditing]) {
        self.navigationItem.leftBarButtonItem = editButton;
        [self setEditing:NO animated:YES];
    }
}

- (void)addNote {

    [self stopEditing];

    Note *newNote = (Note*)[NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:PersistenceStack.shared.moc];
    [newNote setCreatedAt:[NSDate date]];
    [newNote setNoteId:UUID()];
    [newNote setLocallyModified:[NSNumber numberWithBool:true]];

    Save();

    [self editNote:newNote withKeyboard:true];

    [self updateNoteCount];
}

- (void)updateNoteCount {
    [self refreshData];
}

- (void)edit {
    if ([self isEditing]) {
        [self stopEditing];
    } else {
        [self setEditing:YES animated:YES];
        self.navigationItem.leftBarButtonItem = doneButton;
    }
}

- (void)editNote:(Note*)note withKeyboard:(bool)keyboard {

    [self.navigationController popToRootViewControllerAnimated:NO];

    NewNoteController *newNoteController = [[NewNoteController alloc] initWithNibName:nil bundle:nil];
    newNoteController.note = note;
    newNoteController.showKeyboardOnLoad = keyboard;

    // TODO: Store that we are about to be editing this note..? maybe
    // Rethink this
    //[SettingsController storeSelectedNote:note];

    // Push the detail view controller.
    [self.navigationController pushViewController:newNoteController animated:YES];

    [newNoteController release];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    [self.tableView registerClass:[OutlineCell class] forCellReuseIdentifier:[OutlineCell reuseIdentifier]];

    addButton = [[UIBarButtonItem alloc]
                 initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addNote)];
    self.navigationItem.rightBarButtonItem = addButton;

    editButton = [[UIBarButtonItem alloc]
                  initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(edit)];

    doneButton = [[UIBarButtonItem alloc]
                  initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(edit)];
    self.navigationItem.leftBarButtonItem = editButton;

    // Subscribe to onSyncComplete messages (only the root controller needs to do this)
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onSyncComplete)
                                                 name:@"SyncComplete"
                                               object:nil];

    [self refreshData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self refreshData];

    // TODO: Store in the session that there is no selected note
    //[SettingsController storeSelectedNote:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopEditing];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

    // Release any cached data, images, etc that aren't in use.
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [notesArray count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    Note *note = (Note*)[notesArray objectAtIndex:indexPath.row];

    NSString *title = ^NSString *{
        if ([note isFlagEntry]) {
            Node *node = ResolveNode(note.nodeId);
            return node.headingForDisplay;
        }
        return note.heading;
    }();
    UIImage *image = ^UIImage *{
        NSString *resourceName = [note isFlagEntry] ? @"flagged" : @"note_entry";
        NSString *path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png"];
        return [UIImage imageWithContentsOfFile:path];
    }();

    OutlineCell *cell = [tableView dequeueReusableCellWithIdentifier:[OutlineCell reuseIdentifier]];
    [cell updateWithTitle:title
                      note:nil
                    status:nil
                      done:false
                  priority:nil
                      tags:nil
                 scheduled:nil
                  deadline:nil
                 createdAt:[note createdAt]];
    cell.imageView.image = image;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Note *note = (Note*)[notesArray objectAtIndex:indexPath.row];
    [self editNote:note withKeyboard:false];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    Note *note = (Note*)[notesArray objectAtIndex:indexPath.row];
    [self editNote:note withKeyboard:false];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {

        Note *noteToDelete = [notesArray objectAtIndex:indexPath.row];

        noteToDelete.locallyModified = [NSNumber numberWithBool:true];
        noteToDelete.removed = [NSNumber numberWithBool:true];

        Save();

        [notesArray removeObjectAtIndex:[indexPath row]];

        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];

        [self refreshData];

        if ([notesArray count] == 0) {
            [self stopEditing];
            self.navigationItem.leftBarButtonItem.enabled = NO;
        }
    }
}

- (void)dealloc {

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"SyncComplete"
                                                  object:nil];

    [notesArray release];
    [editButton release];
    [doneButton release];
    [addButton release];
    [super dealloc];
}

@end
