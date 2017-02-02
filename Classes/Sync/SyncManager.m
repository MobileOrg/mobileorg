//
//  SyncManager.m
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

#import "SyncManager.h"
#import "TransferManager.h"
#import "TransferContext.h"
#import "Settings.h"
#import "DataUtils.h"
#import "GlobalUtils.h"
#import "ChecksumFileParser.h"
#import "OrgFileParser.h"
#import "EditsFileParser.h"
#import "EditEntity.h"
#import "Node.h"
#import "Note.h"
#import "LocalEditAction.h"
#import "StatusViewController.h"
#import "MobileOrgAppDelegate.h"
#import "MobileOrg-Swift.h"


@interface SyncManager(private)
- (TransferManager*)transferManager;
- (bool)hasLocalChanges;
- (void)syncLocalChanges;
- (void)downloadEditsFile;
- (void)doneDownloadingEditsFile:(NSString*)editsFilename;
- (void)doneUploadingLocalChanges;
- (void)uploadEmptyEditsFile;
- (void)doneUploadingEmptyEditsFile;
- (void)syncOrgFiles;
- (void)downloadChecksumFile;
- (void)downloadOrgFiles;
- (void)downloadOrgFile:(NSString*)name;
- (void)doneDownloadingOrgFiles;
- (void)findAndFetchLinksForNode:(Node*)node;
- (void)processOrgFile:(NSString*)orgFilename withLocalFile:(NSString*)localFilename;
- (void)doneProcessingOrgFile;
- (void)applyEdits;
- (void)doneApplyingEdits;
@end

// Singleton instance
static SyncManager *gInstance = NULL;

@implementation SyncManager

@synthesize transferState;
@synthesize transferFilename;
@synthesize progressTotal, progressCurrent;

+ (SyncManager*)instance {
    @synchronized(self)
    {
        if (gInstance == NULL)
            gInstance = [[self alloc] init];
    }
    return gInstance;
}

- (id)init {
    if (self = [super init]) {
        downloadedFiles = [NSMutableArray new];
        checksumParser = [ChecksumFileParser new];
        orgFileParser = [OrgFileParser new];
        [orgFileParser setDelegate:self];
        [orgFileParser setCompletionSelector:@selector(doneProcessingOrgFile)];
        editsFileParser = [EditsFileParser new];
        [editsFileParser setDelegate:self];
        changedEditsFile = false;
    }
    return self;
}

- (TransferManager*)transferManager {
    if ([[Settings instance] serverMode] == ServerModeWebDav) {
        return (TransferManager *)[WebDavTransferManager instance];
    } else if ([[Settings instance] serverMode] == ServerModeDropbox) {
        return (TransferManager *)[DropboxTransferManager instance];
    }
    return nil;
}

// Sync process:
//
// - If there are any notes or local edit actions, we need to push them first
// - Fetch the checksum file
// - Download any changed files
// - Parse files
// - Apply edits
//
- (void)sync {
    [[StatusViewController instance] show];

    [self syncLocalChanges];
}

- (void)abort {
    [[self transferManager] abort];
    [[StatusViewController instance] hide];
}

- (void)syncDone {
    [[StatusViewController instance] setActivityMessage:@"Done"];
    [[StatusViewController instance] setActionMessage:@""];

    // TODO: Rebuild the AllTags of Settings by walking the tree
    // Perhaps add a deferSync:bool to the args, so we can do it without that overhead
    // Then call synchronize at the end

    // This is lame, we should just subscribe to SyncComplete in SearchController but I'm being lazy.
    [[AppInstance() searchController] reset];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"SyncComplete" object:nil];

    [[StatusViewController instance] hide];
}

- (bool)hasLocalChanges {
    int count = 0;
    count += CountNotes();
    count += CountLocalEditActions();
    return count > 0;
}

- (void)syncLocalChanges {

    [[StatusViewController instance] setActivityMessage:@"Syncing changes"];

    if ([self hasLocalChanges]) {
        changedEditsFile = true;
        [self downloadEditsFile];
    } else {
        changedEditsFile = false;
        [self syncOrgFiles];
    }
}

- (void)downloadEditsFile {

    currentState = SyncManagerTransferStateDownloadingEditsFile;

    // Enque a fetch request to download this Org-file
    TransferContext *context = [TransferContext new];

    context.remoteUrl    = [[Settings instance] urlForFilename:@"mobileorg.org"];
    context.localFile    = TemporaryFilename();
    context.transferType = TransferTypeDownload;
    context.delegate     = self;

    [[self transferManager] enqueueTransfer:context];

    [context release];
}

- (void)doneDownloadingEditsFile:(NSString*)editsFilename {

    [[StatusViewController instance] setActionMessage:@"Processing edits"];

    // Parse the changes file
    [editsFileParser setEditsFilename:editsFilename];
    [editsFileParser setCompletionSelector:@selector(doneProcessingEditsFile)];
    [NSThread detachNewThreadSelector:@selector(parse) toTarget:editsFileParser withObject:nil];
}

- (void)doneProcessingEditsFile {

    [[StatusViewController instance] setActionMessage:@"Merging local edits"];

    // Open a new file with a temp name
    NSString *newEditsFilename = FileWithName(@"new-mobileorg.org");
    [[NSFileManager defaultManager] createFileAtPath:newEditsFilename contents:nil attributes:nil];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:newEditsFilename];

    NSArray *editActions = AllLocalEditActions();

    // There are some assumptions here that there can't exist two
    // LocalEditActions for the same resolved node.  This should hold
    // true, as the various editing controllers are responsible for
    // reusing LEA's if possible.
    for (EditEntity *entity in [editsFileParser editEntities]) {
        // The goal is to write this out to the new mobileorg.org file
        // But we can only do so if there is no local edit action for
        // this <Node, editActionType> pair.
        //
        // If there is a matching entry, we need to ignore this one,
        // but replace the oldValue of the matching LocalEditAction
        // instance with the oldValue of this entity.  This will
        // effectively let Org mode see it as one edit event, rather
        // than a separate event based off an oldValue that was truly
        // the newValue of an old edit event.  Hope this makes sense.

        // This isn't a very smart way to do this, but it works for now.
        // We can optimize it later.
        bool existsLocalChange = false;
        for (LocalEditAction *localEdit in editActions) {
            Node *localEditNode = ResolveNode(localEdit.nodeId);
            if ([[localEditNode objectID] isEqual:[entity.node objectID]] &&
                [localEdit.actionType isEqualToString:entity.editAction]) {
                existsLocalChange = true;
                localEdit.oldValue = entity.oldValue;
                break;
            }
        }

        // Skip it if we have an LEA that matches
        if (existsLocalChange)
            continue;

        // Don't write the note if there is a CaputreNote with this ID that is locally modified
        if (LocalNoteWithModifications(entity.noteId))
            continue;

        // Don't write out the note if it is marked for deletion
        // This is caught by the LocalNoteWithModification check above, since the note will be modified + have deleted flag

        // Don't write out goofy edits where nothing changed
        if ([entity.oldValue isEqualToString:entity.newValue]) {
            continue;
        }

        // Write it out to the file
        if (!entity.editAction || [entity.editAction length] == 0) {
            // No edit action means a simple flag entry, just a flag note.. no old/new values.
            [file writeData:[[NSString stringWithFormat:@"* %@\n", entity.heading] dataUsingEncoding:NSUTF8StringEncoding]];

            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"YYYY-MM-dd EEE HH:mm"];
            NSString *createdAt = [formatter stringFromDate:entity.createdAt];
            [formatter release];

            [file writeData:[[NSString stringWithFormat:@"[%@]\n", createdAt] dataUsingEncoding:NSUTF8StringEncoding]];
            if (entity.newValue && [entity.newValue length] > 0)
                [file writeData:[[NSString stringWithFormat:@"%@\n", EscapeHeadings(entity.newValue)] dataUsingEncoding:NSUTF8StringEncoding]];
            [file writeData:[[NSString stringWithFormat:@"** Note ID: %@\n", entity.noteId] dataUsingEncoding:NSUTF8StringEncoding]];
        } else {
            [file writeData:[[NSString stringWithFormat:@"* F(%@) [[%@][%@]]\n", entity.editAction, [entity.node bestId], EscapeStringForLinkTitle([entity.node heading])] dataUsingEncoding:NSUTF8StringEncoding]];
            [file writeData:[@"** Old value\n" dataUsingEncoding:NSUTF8StringEncoding]];
            if (entity.oldValue && [entity.oldValue length] > 0)
                [file writeData:[[NSString stringWithFormat:@"%@\n", EscapeHeadings(entity.oldValue)] dataUsingEncoding:NSUTF8StringEncoding]];
            [file writeData:[@"** New value\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [file writeData:[[NSString stringWithFormat:@"%@\n", EscapeHeadings(entity.newValue)] dataUsingEncoding:NSUTF8StringEncoding]];
            [file writeData:[@"** End of edit\n" dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }

    // Write out all of the local edit actions
    for (LocalEditAction *action in editActions) {

        // Don't write out goofy edits where nothing changed
        if ([action.oldValue isEqualToString:action.newValue]) {
            continue;
        }

        Node *localEditNode = ResolveNode(action.nodeId);
        [file writeData:[[NSString stringWithFormat:@"* F(%@) [[%@][%@]]\n", action.actionType, [localEditNode bestId], EscapeStringForLinkTitle([localEditNode heading])] dataUsingEncoding:NSUTF8StringEncoding]];
        if (!action.actionType || [action.actionType length] == 0) {
            // No edit action means a simple flag entry, just a note.. no old/new values.
            [file writeData:[[NSString stringWithFormat:@"%@\n", EscapeHeadings(action.newValue)] dataUsingEncoding:NSUTF8StringEncoding]];
        } else {
            [file writeData:[@"** Old value\n" dataUsingEncoding:NSUTF8StringEncoding]];
            if (action.oldValue && [action.oldValue length] > 0)
                [file writeData:[[NSString stringWithFormat:@"%@\n", EscapeHeadings(action.oldValue)] dataUsingEncoding:NSUTF8StringEncoding]];
            [file writeData:[@"** New value\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [file writeData:[[NSString stringWithFormat:@"%@\n", EscapeHeadings(action.newValue)] dataUsingEncoding:NSUTF8StringEncoding]];
            [file writeData:[@"** End of edit\n" dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }

    // Write out all of the local notes
    for (Note *note in AllNotes()) {
        if (![note.locallyModified boolValue])
            continue;

        if ([note.deleted boolValue])
            continue;

        [file writeData:[[note orgLine] dataUsingEncoding:NSUTF8StringEncoding]];
        [file writeData:[[NSString stringWithFormat:@"** Note ID: %@\n", note.noteId] dataUsingEncoding:NSUTF8StringEncoding]];
    }

    // Close the file
    [file closeFile];

    [editsFileParser reset];
    
    if ([[Settings instance] encryptionPassword] && ![[[Settings instance] encryptionPassword] isEqualToString:@""]) {
        NSMutableData *data = [NSMutableData dataWithContentsOfFile:newEditsFilename];
        NSData *encryptedData = [data AES256EncryptWithKey:[[Settings instance] encryptionPassword]];
        [encryptedData writeToFile:newEditsFilename atomically:NO];
    }

    // Send the file back to the server
    {
        currentState = SyncManagerTransferStateUploadingLocalChanges;

        // Enque a fetch request to upload the new changes file
        TransferContext *context = [TransferContext new];

        context.remoteUrl    = [[Settings instance] urlForFilename:@"mobileorg.org"];
        context.localFile    = newEditsFilename;
        context.transferType = TransferTypeUpload;
        context.delegate     = self;

        [[self transferManager] enqueueTransfer:context];

        [context release];
    }
}

- (void)doneUploadingLocalChanges {

    // Let the checksum handling know that we changed the mobileorg.org file, so it can
    // ignore the checksum value and redownload it
    changedEditsFile = true;

    // Instead of redownloading the mobileorg.org file we just uploaded, pretend we did
    if ([[NSFileManager defaultManager] fileExistsAtPath:FileWithName(@"new-mobileorg.org")]) {
        NSError *e = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:FileWithName(@"mobileorg.org")]) {
            [[NSFileManager defaultManager] removeItemAtPath:FileWithName(@"mobileorg.org") error:&e];
        }
        [[NSFileManager defaultManager] copyItemAtPath:FileWithName(@"new-mobileorg.org") toPath:FileWithName(@"mobileorg.org") error:&e];
    }

    // If there were no errors, we can safely delete the local edit actions
    DeleteLocalEditActions();

    // Reset the note list, just in case it is viewing a note that no longer exists
    [[[AppInstance() noteListController] navigationController] popToRootViewControllerAnimated:NO];

    // If there were no errors, we can safely delete the new notes
    DeleteNotes();

    [self syncOrgFiles];
}

- (void)uploadEmptyEditsFile {

    // Try to create a dummy file and upload it
    NSString *localEditsFile = FileWithName(@"new-mobileorg.org");
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:localEditsFile]) {
            NSError *e = nil;
            [[NSFileManager defaultManager] removeItemAtPath:localEditsFile error:&e];
        }

        [[NSFileManager defaultManager] createFileAtPath:localEditsFile contents:nil attributes:nil];

        NSFileHandle *f = [NSFileHandle fileHandleForWritingAtPath:localEditsFile];
        assert(f);

        [f seekToEndOfFile];

        NSData *data = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
        
        if ([[Settings instance] encryptionPassword] && ![[[Settings instance] encryptionPassword] isEqualToString:@""]) {
            NSData *encryptedData = [data AES256EncryptWithKey:[[Settings instance] encryptionPassword]];
            [f writeData:encryptedData];
        } else {
            [f writeData:data];
        }
        
        [f closeFile];
    }
    
    currentState = SyncManagerTransferStateUploadingEmptyEditsFile;

    TransferContext *context = [TransferContext new];

    context.remoteUrl    = [[Settings instance] urlForFilename:@"mobileorg.org"];
    context.localFile    = localEditsFile;
    context.transferType = TransferTypeUpload;
    context.delegate     = self;

    [[self transferManager] enqueueTransfer:context];

    [context release];
}

- (void)doneUploadingEmptyEditsFile {
    [self downloadEditsFile];
}

- (void)syncOrgFiles {
    [[StatusViewController instance] setActivityMessage:@"Syncing Org-files"];
    [self downloadChecksumFile];
}

- (void)downloadChecksumFile {

    currentState = SyncManagerTransferStateDownloadingChecksums;

    [checksumParser reset];

    TransferContext *context = [TransferContext new];

    context.remoteUrl    = [[Settings instance] urlForFilename:@"checksums.dat"];
    context.localFile    = TemporaryFilename();
    context.transferType = TransferTypeDownload;
    context.delegate     = self;

    [[self transferManager] enqueueTransfer:context];

    [context release];
}

- (void)processChecksumFile:(NSString*)filename {

    // Parse the checksum file (this could stand to go on another thread, I suppose)
    [checksumParser parse:filename];

    int transferQueueNow = [[self transferManager] queueSize];

    // Done with checksums, now start with the Org files
    [self downloadOrgFiles];

    // Sometimes, downloadOrgFiles won't do anything if everything was cached, so just
    // move right along.
    if ([[self transferManager] queueSize] == transferQueueNow) {
        [self doneDownloadingOrgFiles];
    }
}

- (void)downloadOrgFiles {

    // Let's start downloading org files
    currentState = SyncManagerTransferStateDownloadingOrgFiles;

    // Reset the list of files we've downloaded
    [downloadedFiles removeAllObjects];

    // Fetch the index file
    [self downloadOrgFile:[[Settings instance] indexFilename]];

    // Also fetch the mobileorg.org file
    [self downloadOrgFile:@"mobileorg.org"];
}

// After we do a sync, we remove files that may not be referenced anymore
- (void)deleteOrphans {
    NSMutableArray *orphans = [NSMutableArray new];
    for (Node *node in AllFileNodes()) {
        // If we don't have an entry in the downloadedFiles list, that means it is an orphan
        if (![downloadedFiles containsObject:[node heading]]) {
            if (![orphans containsObject:node]) {
                [orphans addObject:node];
            }
        }
    }

    for (Node *node in orphans) {
        DeleteNode(node);
    }

    [orphans release];
}

- (void)doneDownloadingOrgFiles {

    // Clear files that we have but didn't download (or have cached) (orphans)
    [self deleteOrphans];

    // Delete all of the existing file checksums, they could be invalid
    ClearAllFileChecksums();

    // Create new FileChecksum entries that reflect the current state
    for (Node *node in AllFileNodes()) {
        CreateChecksumForFile(node.heading, [checksumParser.checksumPairs objectForKey:node.heading]);
    }
    
    // Clear downloaded list
    [downloadedFiles removeAllObjects];

    // Move onto the next state
    [self applyEdits];
}

- (void)findAndFetchLinksForNode:(Node*)node {
    NSMutableArray *links = [NSMutableArray new];
    [node collectLinks:links];
    for (NSString *link in links) {
        [self downloadOrgFile:link];
    }
    [links release];
}

- (void)downloadOrgFile:(NSString*)name {

    // Don't re-download files we have already downloaded this sync
    if ([downloadedFiles containsObject:name]) {
        return;
    } else {
        [downloadedFiles addObject:name];
    }

    // First, see if we have a filechecksum for this file
    bool downloadFile = true;
    NSString *existingChecksum = ChecksumForFile(name);
    if (existingChecksum) {
        NSString *newChecksum = [checksumParser.checksumPairs objectForKey:name];
        if (newChecksum) {
            if ([existingChecksum isEqualToString:newChecksum] && [existingChecksum length] > 0) {
                // Matching checksum, no need to download the file
                downloadFile = false;
            }
        }
    }

    // Since we changed the edits file, no need to redownload it
    bool dummyDownloadHack = false;
    if (changedEditsFile && [name isEqualToString:@"mobileorg.org"]) {
        downloadFile = true;
        dummyDownloadHack = true;
    }

    if (downloadFile) {

        // First, delete the existing node and associated goodies if we already had it
        DeleteNodesWithFilename(name);

        // Enque a fetch request to download this Org-file
        TransferContext *context = [TransferContext new];

        context.dummy        = dummyDownloadHack;
        context.remoteUrl    = [[Settings instance] urlForFilename:name];

        if ([name isEqualToString:@"mobileorg.org"]) {
            context.localFile    = FileWithName(@"mobileorg.org");
        } else {
            context.localFile    = TemporaryFilename();
        }
        context.transferType = TransferTypeDownload;
        context.delegate     = self;

        [[self transferManager] enqueueTransfer:context];

        [context release];

    } else {

        // We didn't have to download the file, so just go ahead and parse the links out of it and queue up additional requests
        [self findAndFetchLinksForNode:NodeWithFilename(name)];

        // If there is nothing else to do, call doneDownloadingOrgFiles
        if (![[self transferManager] busy]) {
            [self doneDownloadingOrgFiles];
        }
    }
}

- (void)processOrgFile:(NSString*)orgFilename withLocalFile:(NSString*)localFilename {
    [[StatusViewController instance] setActionMessage:[NSString stringWithFormat:@"Processing %@", orgFilename]];

    // Setup the OrgFileParser

    [orgFileParser setOrgFilename:[orgFilename stringByRemovingPercentEncoding]];
    [orgFileParser setLocalFilename:localFilename];

    // Kick it off on its own thread
    // Disable this for now, let's just do it on the main thread
    // HACK We are seeing some weird coredata issues with the multiple threads
    // Perhaps we need to use a different context and a single coordinator or something
    // Lookup multithreaded coredata issues
    //[NSThread detachNewThreadSelector:@selector(parse) toTarget:orgFileParser withObject:nil];

    NSManagedObjectContext *moc = [AppInstance() managedObjectContext];
    [orgFileParser parse: moc];

    // Pause the TransferManager, because otherwise it would try to download
    // more files while this one is processing
    // HACK re-enable this when we put the [detach] back in place above
    //[[TransferManager instance] pause];
}

// This is the callback method for when parsing is done
- (void)doneProcessingOrgFile {

    // TODO: if success, do this.  otherwise, abort then resume the transfer manager.

    // If not success then remove the entry from the checksumpairs, we want to
    // retry downloading it next sync.
    if (orgFileParser.errorStr && ![orgFileParser.errorStr isEqualToString:@""]) {
        [checksumParser.checksumPairs removeObjectForKey:NodeWithFilename([orgFileParser orgFilename]).heading];
    }
    
    // Save our database changes
    Save();

    // Find and fetch files this node links to
    [self findAndFetchLinksForNode:NodeWithFilename([orgFileParser orgFilename])];

    // The transfer manager may resume normal operation now
    // HACK re-enable this when we put the [detach] back in place above
    //[[TransferManager instance] resume];

    // Delete the org file
    if (![[orgFileParser localFilename] isEqualToString:FileWithName(@"mobileorg.org")]) {
        DeleteFile([orgFileParser localFilename]);
    }

    // If there is nothing else to do, call doneDownloadingOrgFiles
    if ([[self transferManager] queueSize] == 0) {
        [self doneDownloadingOrgFiles];
    }
}

- (void)applyEdits {

    [[StatusViewController instance] setActivityMessage:@"Applying edits"];
    [[StatusViewController instance] setActionMessage:@"Parsing changes"];

    if ([[NSFileManager defaultManager] fileExistsAtPath:FileWithName(@"mobileorg.org")]) {
        [editsFileParser setEditsFilename:FileWithName(@"mobileorg.org")];
        [editsFileParser setCompletionSelector:@selector(doneParsingEditsForApplication)];
        [NSThread detachNewThreadSelector:@selector(parse) toTarget:editsFileParser withObject:nil];
    } else {
        [self doneApplyingEdits];
    }
}

- (void)doneParsingEditsForApplication {

    DeleteNotes();

    [[StatusViewController instance] setActionMessage:@"Changing local outlines"];

    for (EditEntity *entity in [editsFileParser editEntities]) {

        if (!entity.editAction || [entity.editAction length] == 0) {
            // Handle notes

            if (entity.noteId) {
                Note *newNote = (Note*)[NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:[AppInstance() managedObjectContext]];
                [newNote setCreatedAt:entity.createdAt];
                [newNote setNoteId:entity.noteId];
                [newNote setLocallyModified:[NSNumber numberWithBool:false]];
                NSString *text = @"";
                if (entity.newValue && [entity.newValue length] > 0) {
                    text = [NSString stringWithFormat:@"%@\n%@", entity.heading, entity.newValue];
                } else {
                    text = entity.heading;
                }
                [newNote setText:text];

                NSArray *captures = [entity.heading captureComponentsMatchedByRegex:@"F\\(.*\\) \\[\\[(.*)\\]\\[.*\\]\\]"];
                if ([captures count] > 0) {
                    newNote.nodeId = [captures objectAtIndex:1];
                }
            }

            continue;
        }

        if ([entity.editAction isEqualToString:@"edit:heading"]) {
            [entity.node setHeading:entity.newValue];
        } else if ([entity.editAction isEqualToString:@"edit:body"]) {
            [entity.node setBody:entity.newValue];
        } else if ([entity.editAction isEqualToString:@"edit:tags"]) {
            [entity.node setTags:entity.newValue];

            // Tell the settings store about any potentially new tags
            // This feels a bit hacky here, it feels like the model should
            // implement this in setTags?
            {
                NSArray *tagArray = [entity.newValue componentsSeparatedByString:@":"];
                for (NSString *element in tagArray) {
                    if (element && [element length] > 0) {
                        [[Settings instance] addTag:element];
                    }
                }
            }
        } else if ([entity.editAction isEqualToString:@"edit:todo"]) {
            [entity.node setTodoState:entity.newValue];
        } else if ([entity.editAction isEqualToString:@"edit:priority"]) {
            [entity.node setPriority:entity.newValue];
        }
    }

    Save();

    [editsFileParser reset];

    DeleteFile(FileWithName(@"mobileorg.org"));

    [self doneApplyingEdits];
}

- (void)doneApplyingEdits {
    [self syncDone];
}

- (void)transferComplete:(TransferContext*)context {
    switch (currentState) {
        case SyncManagerTransferStateDownloadingEditsFile:
            [self doneDownloadingEditsFile:[context localFile]];
            break;

        case SyncManagerTransferStateUploadingEmptyEditsFile:
            [self doneUploadingEmptyEditsFile];
            break;

        case SyncManagerTransferStateUploadingLocalChanges:
            [self doneUploadingLocalChanges];
            break;

        case SyncManagerTransferStateDownloadingChecksums:
            [self processChecksumFile:[context localFile]];
            break;

        case SyncManagerTransferStateDownloadingOrgFiles:
        {
            NSString *orgFilename = nil;
            switch ([[Settings instance] serverMode]) {
                case ServerModeWebDav:
                    // We want to strip the baseUrl off of the remoteUrl and use that as the org filename
                    orgFilename = [[[context remoteUrl] absoluteString] stringByReplacingOccurrencesOfString:[[[Settings instance] baseUrl] absoluteString] withString:@""];
                    break;
                case ServerModeDropbox:
                    // Strip off the leading slash only
                    orgFilename = [[[context remoteUrl] absoluteString] substringFromIndex:1];
                    break;
                default:
                    NSLog(@"Fix me, unsupported server mode!");
                    break;
            }
            [self processOrgFile:orgFilename withLocalFile:[context localFile]];
            break;
        }
        case SyncManagerTransferStateIdle:
          break;
    }
}

- (void)transferFailed:(TransferContext*)context {
    //NSLog(@"Failed %@ with code %d", [context remoteUrl], [context statusCode]);
    switch (currentState) {
        case SyncManagerTransferStateDownloadingEditsFile:
            if ([context statusCode] == 404) {
                [self uploadEmptyEditsFile];
            } else {
                [self showAlert:@"Error syncing changes" withText:[NSString stringWithFormat:@"An error was encountered while attempting to fetch mobileorg.org from the server.  The error was:\n\n%@", [context errorText]]];

                [self abort];
            }
            break;

        case SyncManagerTransferStateUploadingEmptyEditsFile:
        {
            // Abort.. we tried to make the mobileorg.org file and couldn't
            [self showAlert:@"Error creating mobileorg.org" withText:[NSString stringWithFormat:@"An error was encountered while attempting to create mobileorg.org on the server.  The error was:\n\n%@", [context errorText]]];

            [self abort];

            break;
        }

        case SyncManagerTransferStateUploadingLocalChanges:
        {
            // Abort.. we couldn't upload local changes
            [self showAlert:@"Error uploading mobileorg.org" withText:[NSString stringWithFormat:@"An error was encountered while attempting to upload mobileorg.org to the server.  The error was:\n\n%@", [context errorText]]];

            [self abort];

            break;
        }

        case SyncManagerTransferStateDownloadingChecksums:
            if (([context statusCode] >= 400 && [context statusCode] < 600) ||
                 [[context errorText] containsString: @".tag\" = \"not_found"]) {
                // Fetch the Org files, just assume they don't have a checksum file since the server
                // gave us an error code answer
                [self downloadOrgFiles];
            } else {
                DeleteFile([context localFile]);

                [self showAlert:@"Error downloading checksums" withText:[NSString stringWithFormat:@"An error was encountered while downloading checksums.dat from the server.  This file isn't required, but the error received was unusual.  The error was:\n\n%@", [context errorText]]];

                [self abort];
            }
            break;

        case SyncManagerTransferStateDownloadingOrgFiles:
            // Only abort if we were downloading the index org file
            if ([[context.remoteUrl absoluteString] isEqualToString:[[[Settings instance] indexUrl] absoluteString]]) {

              [self showAlert:@"Error downloading Org-file" withText:[NSString stringWithFormat:@"An error was encountered while attempting to download %@ from the server.  The error was:\n\n%@", [[context remoteUrl] path], [context errorText]]];

                [self abort];

            } else {
                // Just ignore the error, we're done if this was the last file
                if ([[self transferManager] queueSize] == 0) {
                    [self doneDownloadingOrgFiles];
                }
            }

            break;
      case SyncManagerTransferStateIdle:
        break;
    }
}

- (void)updateStatus {
    if (progressTotal > 0) {
        [[StatusViewController instance] progressBar].hidden = NO;
        [[StatusViewController instance] progressBar].progress = (float)progressCurrent/(float)progressTotal;
    } else {
        [[StatusViewController instance] progressBar].hidden = YES;
    }
    [[StatusViewController instance] setActionMessage:transferFilename];
}


  - (void) showAlert:(NSString*)alertTitle withText:(NSString*)alertMessage {

  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:alertTitle message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
  [alertController addAction:ok];


  id rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
  if([rootViewController isKindOfClass:[UINavigationController class]])
    {
    rootViewController = ((UINavigationController *)rootViewController).viewControllers.firstObject;
    }
  if([rootViewController isKindOfClass:[UITabBarController class]])
    {
    rootViewController = ((UITabBarController *)rootViewController).selectedViewController;
    }
  [rootViewController presentViewController:alertController animated:YES completion:nil];


}

- (void)dealloc {
    [downloadedFiles release];
    [checksumParser release];
    [orgFileParser release];
    [editsFileParser release];
    [transferState release];
    [transferFilename release];
    [super dealloc];
}

@end
