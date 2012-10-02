//
//  DropboxTransferManager.m
//  MobileOrg
//
//  Created by Richard Moreland on 9/30/09.
//  Copyright 2010 Richard Moreland.
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

#import "DropboxTransferManager.h"
#import "TransferContext.h"
#import "StatusUtils.h"
#import "SyncManager.h"
#import "Settings.h"
#import <DropBoxSDK/DropBoxSDK.h>

// Just #define APP_SECRET "xxx" and APP_KEY @"yyy" in this file
#import "DropboxKeys.h"

@interface DropboxTransferManager(private)
- (void)dispatchNextTransfer;
- (void)processRequest:(TransferContext*)context;
- (void)requestFinished:(TransferContext *)context;
@end

// Singleton instance
static DropboxTransferManager *gInstance = NULL;

@implementation DropboxTransferManager

@synthesize activeTransfer;
@synthesize fileSize;

+ (DropboxTransferManager*)instance {
    @synchronized(self)
    {
        if (gInstance == NULL)
            gInstance = [[self alloc] init];
    }
    return gInstance;
}

- (id)init {
    if (self = [super init]) {
        transfers = [NSMutableArray new];
        activeTransfer = nil;
        active = false;
        paused = false;
        data = [[NSMutableData alloc] init];
        dbSession = [[DBSession alloc] initWithAppKey:APP_KEY appSecret:APP_SECRET root:kDBRootAppFolder];
        [DBSession setSharedSession:dbSession];
        dbClient = [[DBRestClient alloc] initWithSession:dbSession];
        dbClient.delegate = self;
    }
    return self;
}

- (void)enqueueTransfer:(TransferContext *)context {

    // Add the transfer to the queue
    [transfers addObject:context];

    // Make sure the status window is visible
    ShowStatusView();

    // Try to kick off this transfer
    [self dispatchNextTransfer];
}

- (void)dispatchNextTransfer {
    if (paused)
        return;

    if ([transfers count] > 0) {
        if (!active) {

            // The context at index 0 is what we're about to transfer
            self.activeTransfer = [transfers objectAtIndex:0];

            // Transfers are successful until proven otherwise
            activeTransfer.success = true;

            // Dequeue it off the front
            [transfers removeObjectAtIndex:0];

            // Update status view text
            [[SyncManager instance] setTransferFilename:[[[self.activeTransfer remoteUrl] absoluteString] lastPathComponent]];
            [[SyncManager instance] setProgressTotal:0];
            [[SyncManager instance] updateStatus];

            // We are now active, no more transfers until this one is done
            active = true;

            [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

            [self processRequest:activeTransfer];
        }
    } else {
        // If there are no more transfers, we don't need the status view
        HideStatusView();
    }
}

- (void)processRequest:(TransferContext *)context {

    if (![self isLinked]) {
        activeTransfer.errorText = @"Not logged in, please login from the Settings page.";
        activeTransfer.success = false;
        [self requestFinished:activeTransfer];
        return;
    }

    if (context.dummy) {
        activeTransfer.success = true;
        [self requestFinished:activeTransfer];
        return;
    }

    NSString *path = [[context.remoteUrl absoluteString] stringByReplacingOccurrencesOfString:@"dropbox:///" withString:@"/"];

    if (context.transferType == TransferTypeDownload) {
        [dbClient loadFile:path intoPath:context.localFile];
    } else {
        [dbClient uploadFile:path toPath:@"/" fromPath:context.localFile];
    }
}

- (void)requestFinished:(TransferContext*)context {

    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

    if (!context.success && context.abortOnFailure) {
        [transfers removeAllObjects];
    }

    if (context.success) {
        [[context delegate] transferComplete:context];
    } else {
        [[context delegate] transferFailed:context];
    }

    active = false;

    self.activeTransfer = nil;

    [self dispatchNextTransfer];
}

- (void)pause {
    paused = true;
}

- (void)resume {
    paused = false;
    [self dispatchNextTransfer];
}

- (bool)busy {
    return ([transfers count] > 0 || active);
}

- (int)queueSize {
    return [transfers count];
}

- (void)abort {
    // TODO
    //if (connection) {
    //    [connection cancel];
    //}
    [transfers removeAllObjects];
    active = false;
}

- (void)login:(UIViewController*)rootController {
    if (![[DBSession sharedSession] isLinked]) {
        [[DBSession sharedSession] linkFromController:rootController];
    }
}

- (void)unlink {
    [dbSession unlinkAll];
}

- (BOOL)isLinked {
    return [dbSession isLinked];
}

- (void)dealloc {
    [data release];
    self.activeTransfer = nil;
    [transfers release];
    [super dealloc];
}

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata
{
    NSLog(@"ERROR testing delegate method called that shouldn't be: %s", __FUNCTION__);
}

- (void)restClient:(DBRestClient*)client loadedAccountInfo:(DBAccountInfo*)account
{
    NSLog(@"ERROR testing delegate method called that shouldn't be: %s", __FUNCTION__);
}

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)destPath
{
    activeTransfer.success = true;
    [self requestFinished:activeTransfer];
}

- (void)restClient:(DBRestClient*)client loadProgress:(CGFloat)progress forFile:(NSString*)destPath
{
    SyncManager *mgr = [SyncManager instance];
    [mgr setProgressTotal:100];
    [mgr setProgressCurrent:(progress * 100.0f)];
    [mgr updateStatus];
}

- (void)restClient:(DBRestClient*)client uploadedFile:(NSString*)sourcePath from:(NSString*)srcPath metadata:(DBMetadata *)metadata
{
    activeTransfer.success = true;
    [self requestFinished:activeTransfer];
}

- (void)restClient:(DBRestClient*)client uploadProgress:(CGFloat)progress forFile:(NSString*)destPath
{
    SyncManager *mgr = [SyncManager instance];
    [mgr setProgressTotal:100];
    [mgr setProgressCurrent:(progress * 100.0f)];
    [mgr updateStatus];
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error
{
    activeTransfer.errorText = @"Unexpected error";
    activeTransfer.success = false;
    [self requestFinished:activeTransfer];
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error
{
    activeTransfer.errorText = @"Unexpected error";
    activeTransfer.success = false;
    [self requestFinished:activeTransfer];
}

@end
