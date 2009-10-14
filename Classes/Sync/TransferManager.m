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
#include <neon/ne_auth.h>

@interface TransferManager(private)
- (void)dispatchNextTransfer;
- (void)processRequest:(TransferContext*)context;
@end

// Singleton instance
static TransferManager *gInstance = NULL;

@implementation TransferManager

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
        ne_sock_init();
        active = false;
        paused = false;
        sess = nil;
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
            TransferContext *context = [transfers objectAtIndex:0];

            // Retain it, since we need it to outlive the thread
            [context retain];

            // Dequeue it off the front
            [transfers removeObjectAtIndex:0];

            // Update status view text
            [[SyncManager instance] setTransferFilename:[[[context remoteUrl] absoluteString] lastPathComponent]];
            [[SyncManager instance] setProgressTotal:0];
            [[SyncManager instance] updateStatus];

            // We are now active, no more transfers until this one is done
            active = true;

            // Kick it off in another thread
            [NSThread detachNewThreadSelector:@selector(processRequest:) toTarget:self withObject:context];
        }
    } else {
        // If there are no more transfers, we don't need the status view
        HideStatusView();
    }
}

static int my_auth(void *userdata, const char *realm, int attempts, char *username, char *password) {
    if (![[Settings instance] username] || ![[Settings instance] password])
        return attempts;
    strncpy(username, [[[Settings instance] username] cStringUsingEncoding:NSUTF8StringEncoding], NE_ABUFSIZ);
    strncpy(password, [[[Settings instance] password] cStringUsingEncoding:NSUTF8StringEncoding], NE_ABUFSIZ);
    return attempts;
}

static int my_verify_ssl(void *userdata, int failures, const ne_ssl_certificate *cert) {
    return 0;
}

static void my_notify_status(void *userdata, ne_session_status status, const ne_session_status_info *info) {

    SyncManager *mgr = [SyncManager instance];

    static NSString* statusStrings[6] = {
        @"Performing DNS lookup",
        @"Connecting to host",
        @"Connected to host",
        @"Sending data",
        @"Receiving data",
        @"Disconnected"
    };

    [mgr setTransferState:statusStrings[status]];

    switch (status) {
        case ne_status_sending:
        case ne_status_recving:
            [mgr setProgressTotal:info->sr.total];
            [mgr setProgressCurrent:info->sr.progress];
            break;
    }

    [mgr performSelectorOnMainThread:@selector(updateStatus) withObject:nil waitUntilDone:NO];
}

// TODO: Cleanup
- (void)processRequest:(TransferContext*)context {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    int port = 80;
    if ([[[context remoteUrl] scheme] compare:@"https"] == NSOrderedSame) {
        port = 443;
    }
    if ([[[context remoteUrl] port] intValue] != 0) {
        port = [[[context remoteUrl] port] intValue];
    }

    if (!sess ||
        [[[context remoteUrl] scheme] compare:lastScheme] != NSOrderedSame ||
        [[[context remoteUrl] host] compare:lastHost] != NSOrderedSame ||
        port != lastPort) {

        if (sess) {
            // :( For some reason, if you connect to me.com, then try to destroy the session,
            // it hangs in the destroy.  I have no idea why.
            if ([lastHost rangeOfRegex:@"\\.me\\.com$"].location == NSNotFound &&
                [lastHost rangeOfRegex:@"\\.mac\\.com$"].location == NSNotFound) {
                ne_session_destroy(sess);
            }
        }

        sess = ne_session_create([[[context remoteUrl] scheme] cStringUsingEncoding:NSUTF8StringEncoding],
                                 [[[context remoteUrl] host] cStringUsingEncoding:NSUTF8StringEncoding],
                                 port);

        lastScheme = [[[context remoteUrl] scheme] copy];
        lastHost = [[[context remoteUrl] host] copy];
        lastPort = port;
    }

    ne_set_server_auth(sess, my_auth, nil);
    ne_ssl_set_verify(sess, my_verify_ssl, nil);
    ne_set_notifier(sess, my_notify_status, nil);
    ne_set_read_timeout(sess, 30);
    ne_set_connect_timeout(sess, 30);

    ne_request *req = nil;
    int ret = NE_ERROR;
    context.success = false;

    switch (context.transferType) {
        case TransferTypeDownload:
        {
            NSMutableData *outputBuffer = [[NSMutableData alloc] init];
            size_t count = 0;
            char buf[8192];

            req = ne_request_create(sess, "GET", [[[context remoteUrl] path] cStringUsingEncoding:NSUTF8StringEncoding]);

        retry:
            ret = ne_begin_request(req);

            if (ret == NE_OK) {
                [outputBuffer setLength:0];
                while ((ret = ne_read_response_block(req, buf, sizeof(buf))) > 0) {
                    count += ret;
                    [outputBuffer appendBytes:buf length:ret];

                    if ([[NSThread currentThread] isCancelled]) {
                        context.errorText = @"User cancelled request";
                        context.success = false;
                        ret = NE_ERROR;
                        goto abort;
                    }
                }

                if (ret == NE_OK) {
                    ret = ne_end_request(req);
                    if (ret == NE_RETRY) {
                        goto retry;
                    } else if (ret == NE_OK) {
                        if ([outputBuffer writeToFile:[context localFile] atomically:YES]) {
                            context.success = true;
                        }
                    }
                }
            }

        abort:
            [outputBuffer release];

            break;
        }

        case TransferTypeUpload:
        {
            NSData *buffer = [NSData dataWithContentsOfFile:[context localFile]];
            if (buffer) {
                req = ne_request_create(sess, "PUT", [[[context remoteUrl] path] cStringUsingEncoding:NSUTF8StringEncoding]);
                ne_set_request_body_buffer(req, [buffer bytes], [buffer length]);
                ret = ne_request_dispatch(req);
                if (ret == NE_OK) {
                    context.success = true;
                }
            }
            break;
        }
        default:
            assert(0);
            break;
    }

    if (ret != NE_OK && [context.errorText length] == 0) {
        context.errorText = [NSString stringWithCString:ne_get_error(sess) encoding:NSUTF8StringEncoding];
    }

    context.statusCode = ne_get_status(req)->code;
    if (context.statusCode >= 400 && context.statusCode < 600) {
        context.success = false;
        if ([context.errorText length] == 0) {
            switch (context.statusCode) {
                case 404:
                    context.errorText = [NSString stringWithFormat:@"404: File not found: %@", [context.remoteUrl path]];
                    break;
                case 403:
                    context.errorText = [NSString stringWithFormat:@"403: Forbidden: %@", [context.remoteUrl path]];
                    break;
                default:
                    context.errorText = [NSString stringWithFormat:@"HTTP Error Code: %d for path: %@", context.statusCode, [context.remoteUrl path]];
                    break;
            }
        }
    }

    if (req) {
        ne_request_destroy(req);
    }

    [self performSelectorOnMainThread:@selector(requestFinished:) withObject:context waitUntilDone:NO];

    [pool release];
}

- (void)requestFinished:(TransferContext*)context {

    if (!context.success && context.abortOnFailure) {
        [transfers removeAllObjects];
    }

    if (context.success) {
        [[context delegate] transferComplete:context];
    } else {
        [[context delegate] transferFailed:context];
    }

    active = false;

    [context release];

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
    [transfers removeAllObjects];
    active = false;
}

- (void)dealloc {
    [transfers release];
    [super dealloc];
}

@end
