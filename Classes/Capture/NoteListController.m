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

@implementation NoteListController

@synthesize notesArray;

- (void)refreshData {
    self.notesArray = [[AllActiveNotes() mutableCopy] autorelease];

    [[self tableView] reloadData];

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

    Note *newNote = (Note*)[NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:[AppInstance() managedObjectContext]];
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

- (void)viewDidUnload {
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
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

    if ([note isFlagEntry]) {

        static NSString *CellIdentifier = @"NoteFlaggedCell";

        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
        }

        NSString *path = [[NSBundle mainBundle] pathForResource:@"flagged" ofType:@"png"];
        UIImage *flagImage = [UIImage imageWithContentsOfFile:path];
        cell.imageView.image = flagImage;

        Node *node = ResolveNode(note.nodeId);
        cell.textLabel.text = [node headingForDisplay];

        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"YYYY-MM-dd EEE HH:mm"];
        NSString *createdAtStr = [formatter stringFromDate:[note createdAt]];
        [formatter release];

        cell.detailTextLabel.text = createdAtStr;

        cell.accessoryType = UIButtonTypeDetailDisclosure;

        return cell;

    } else {

        static NSString *CellIdentifier = @"NoteCell";

        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
        }

        NSString *path = [[NSBundle mainBundle] pathForResource:@"note_entry" ofType:@"png"];
        UIImage *flagImage = [UIImage imageWithContentsOfFile:path];
        cell.imageView.image = flagImage;

        cell.textLabel.text = [note heading];

        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"YYYY-MM-dd EEE HH:mm"];
        cell.detailTextLabel.text = [formatter stringFromDate:[note createdAt]];
        [formatter release];

        cell.accessoryType = UIButtonTypeDetailDisclosure;

        return cell;
    }
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
        noteToDelete.deleted = [NSNumber numberWithBool:true];

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
