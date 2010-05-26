//
//  DBRestRequest.m
//  DropboxSDK
//
//  Created by Brian Smith on 4/9/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//

// TODO: Download to a temp file until entire file has downloaded

#import "DBRequest.h"
#import "JSON.h"


static id networkRequestDelegate = nil;

@implementation DBRequest

+ (void)setNetworkRequestDelegate:(id<DBNetworkRequestDelegate>)delegate {
    networkRequestDelegate = delegate;
}

- (id)initWithURLRequest:(NSURLRequest*)aRequest andInformTarget:(id)aTarget selector:(SEL)aSelector {
    if ((self = [super init])) {
        request = [aRequest retain];
        target = aTarget;
        selector = aSelector;
        
        urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
        [networkRequestDelegate networkRequestStarted];
    }
    return self;
}

- (void) dealloc {
    [urlConnection cancel];
    
    [request release];
    [urlConnection release];
    [fileHandle release];
    [userInfo release];
    [response release];
    [resultFilename release];
    [resultData release];
    [error release];
    [super dealloc];
}

@synthesize failureSelector;
@synthesize downloadProgressSelector;
@synthesize uploadProgressSelector;
@synthesize userInfo;
@synthesize request;
@synthesize response;
@synthesize downloadProgress;
@synthesize uploadProgress;
@synthesize resultData;
@synthesize resultFilename;
@synthesize error;

- (NSString*)resultString {
    return [[[NSString alloc] 
             initWithData:resultData encoding:NSUTF8StringEncoding]
            autorelease];
}

- (NSObject*)resultJSON {
    return [[self resultString] JSONValue];
} 

- (NSInteger)statusCode {
    return [response statusCode];
}

- (void)cancel {
    [urlConnection cancel];
    target = nil;
}

#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)aResponse {
    response = [(NSHTTPURLResponse*)aResponse retain];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data {
    if (resultFilename) {
        NSFileManager* fileManager = [[[NSFileManager alloc] init] autorelease];
        if (![fileManager fileExistsAtPath:resultFilename]) {
            BOOL success = [fileManager createFileAtPath:resultFilename contents:nil attributes:nil];
            if (!success) {
                NSLog(@"DBRequest#connection:didReceiveData: Error creating file at path: %@", resultFilename);
                return;
            }
        }
        
        if (fileHandle == nil) {
            fileHandle = [[NSFileHandle fileHandleForWritingAtPath:resultFilename] retain];
        }
        [fileHandle writeData:data];
    } else {
        if (resultData == nil) {
            resultData = [NSMutableData new];
        }
        [resultData appendData:data];
    }
    
    bytesDownloaded += [data length];
    NSInteger contentLength = [[[response allHeaderFields] objectForKey:@"Content-Length"] intValue];
    downloadProgress = (CGFloat)bytesDownloaded / (CGFloat)contentLength;
    if (downloadProgressSelector) {
        [target performSelector:downloadProgressSelector withObject:self];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection {
    [fileHandle closeFile];
    
    [target performSelector:selector withObject:self];
    
    [networkRequestDelegate networkRequestStopped];
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)anError {
    [fileHandle closeFile];
    error = [anError retain];
    bytesDownloaded = 0;
    downloadProgress = 0;
    uploadProgress = 0;
    
    SEL sel = failureSelector ? failureSelector : selector;
    [target performSelector:sel withObject:self];

    [networkRequestDelegate networkRequestStopped];
}

- (void)connection:(NSURLConnection*)connection didSendBodyData:(NSInteger)bytesWritten 
    totalBytesWritten:(NSInteger)totalBytesWritten 
    totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    
    uploadProgress = (CGFloat)totalBytesWritten / (CGFloat)totalBytesExpectedToWrite;
    if (uploadProgressSelector) {
        [target performSelector:uploadProgressSelector withObject:self];
    }
}

@end
