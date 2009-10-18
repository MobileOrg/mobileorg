//
//  TransferManager.m
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

#import "TransferManager.h"
#import "TransferContext.h"
#import "StatusUtils.h"
#import "SyncManager.h"
#import "Settings.h"

@interface TransferManager(private)
- (void)dispatchNextTransfer;
- (void)processRequest:(TransferContext*)context;
- (void)requestFinished:(TransferContext *)context;
@end

// Singleton instance
static TransferManager *gInstance = NULL;

@implementation TransferManager

@synthesize activeTransfer;
@synthesize fileSize;

+ (TransferManager*)instance {
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

    connection = nil;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:context.remoteUrl cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30];
    if (context.transferType == TransferTypeDownload) {
        [request setHTTPMethod:@"GET"];
    } else {
        [request setHTTPMethod:@"PUT"];
        [request setHTTPBody:[NSData dataWithContentsOfFile:context.localFile]];
    }

    if (!request) {
        // TODO: Call error
        return;
    }

    [data setLength:0];

    connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (!connection) {
        // TODO: call error
        return;
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection*)aConnection {
    [connection release];
    connection = nil;

    if (activeTransfer.statusCode >= 400 && activeTransfer.statusCode < 600) {
        switch (activeTransfer.statusCode) {
            case 401:
                activeTransfer.errorText = @"401: Bad username or password";
                break;
            case 403:
                activeTransfer.errorText = [NSString stringWithFormat:@"403: File not found: %@", [[activeTransfer remoteUrl] path]];
                break;
            case 404:
                activeTransfer.errorText = [NSString stringWithFormat:@"404: File not found: %@", [[activeTransfer remoteUrl] path]];
                break;
            default:
                activeTransfer.errorText = [NSString stringWithFormat:@"%d: Unknown error for file: %@", activeTransfer.statusCode, [[activeTransfer remoteUrl] path]];
                break;
        }
        activeTransfer.success = false;
    } else {
        if (activeTransfer.transferType == TransferTypeDownload) {
            activeTransfer.success = [data writeToFile:[activeTransfer localFile] atomically:YES];
        } else if (activeTransfer.transferType == TransferTypeUpload) {
            activeTransfer.success = true;
        }
    }

    [self requestFinished:activeTransfer];
}

- (void)connection:(NSURLConnection*)aConnection didFailWithError:(NSError*)error {
    [connection release];
    connection = nil;

    activeTransfer.success = false;
    [self requestFinished:activeTransfer];
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response {

    activeTransfer.statusCode = [ (NSHTTPURLResponse*)response statusCode];

    [data setLength:0];
    self.fileSize = [NSNumber numberWithLongLong:[response expectedContentLength]];
}

- (void)connection:(NSURLConnection*)aConnection didReceiveData:(NSData*)someData {
    [data appendData:someData];

    SyncManager *mgr = [SyncManager instance];
    [mgr setProgressTotal:[self.fileSize intValue]];
    [mgr setProgressCurrent:[data length]];
    [mgr updateStatus];
}

-(void)connection:(NSURLConnection*)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge*)challenge {
    if ([challenge previousFailureCount] == 0) {
        NSURLCredential *newCredential;
        newCredential = [NSURLCredential credentialWithUser:[[Settings instance] username]
                                                   password:[[Settings instance] password]
                                                persistence:NSURLCredentialPersistenceForSession];
        [[challenge sender] useCredential:newCredential
               forAuthenticationChallenge:challenge];
    } else {
        [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
        activeTransfer.success = false;
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
    if (connection) {
        [connection cancel];
    }
    [transfers removeAllObjects];
    active = false;
}

- (void)dealloc {
    [data release];
    self.activeTransfer = nil;
    [transfers release];
    [super dealloc];
}

@end
