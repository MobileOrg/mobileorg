//
//  DBRestClient.m
//  DropboxSDK
//
//  Created by Brian Smith on 4/9/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//

#import "DBRestClient.h"
#import "DBRequest.h"
#import "DBSession.h"
#import "MPOAuthURLRequest.h"
#import "MPURLRequestParameter.h"
#import "MPOAuthSignatureParameter.h"
#import "NSString+URLEscapingAdditions.h"
#include <assert.h>


@interface DBRestClient ()

- (NSMutableURLRequest*)requestWithProtocol:(NSString*)protocol host:(NSString*)host path:(NSString*)path 
    parameters:(NSDictionary*)params;

- (NSMutableURLRequest*)requestWithProtocol:(NSString*)protocol host:(NSString*)host path:(NSString*)path 
    parameters:(NSDictionary*)params method:(NSString*)method;

// This method escapes all URI escape characters except /
- (NSString*)escapePath:(NSString*)path;

@end


NSError *convertRequestToError(DBRequest *request)
{
    NSError *error = nil;

    if (request.error || request.statusCode != 200) {
        if (request.error) {
            error = [NSError errorWithDomain:request.error.domain 
                                code:request.error.code userInfo:(NSDictionary*)request.userInfo];
        } else {
            NSDictionary* userInfo = nil;
            // To get error userInfo, first try and make sense of the response as JSON, if that
            // fails then send back the string as an error message
            NSString* resultString = [request resultString];
            if ([resultString length] > 0) {
                @try {
                    NSObject* resultJSON = [request resultJSON];
                    if ([resultJSON isKindOfClass:[NSDictionary class]]) {
                        userInfo = (NSDictionary*)resultJSON;
                    }
                } @catch (NSException* e) {
                    userInfo = [NSDictionary dictionaryWithObject:resultString forKey:@"errorMessage"];
                }
            }
            error = [NSError errorWithDomain:@"dropbox.com" code:request.statusCode userInfo:userInfo];
        }
    }
    
    return error;
}



@implementation DBRestClient

- (id)initWithSession:(DBSession*)aSession
{
    return [self initWithSession:aSession andRoot:@"dropbox"];
}

- (id)initWithSession:(DBSession*)aSession andRoot:(NSString *)theRoot
{
    root = theRoot;

    if ((self = [super init])) {
        session = [aSession retain];
        requests = [[NSMutableSet alloc] init];
    }
    return self;
}


- (void)dealloc {
    [requests release];
    [session release];
    [super dealloc];
}



@synthesize delegate;


- (void)loginWithEmail:(NSString*)email password:(NSString*)password {
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
            email, @"email",
            password, @"password", nil];

    NSURLRequest* urlRequest = [self requestWithProtocol:@"https" host:kDBDropboxAPIHost 
            path:@"/token" parameters:params];
	NSLog(@"%@", urlRequest);
    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLogin:)]
         autorelease];

    [requests addObject:request];
}



- (void)requestDidLogin:(DBRequest*)request {
    NSError *error = convertRequestToError(request);

    if (error) {
        if ([delegate respondsToSelector:@selector(restClient:loginFailedWithError:)]) {
            [delegate restClient:self loginFailedWithError:error];
        }
    } else {
        NSDictionary* result = (NSDictionary*)request.resultJSON;
        NSString* token = [result objectForKey:@"token"];
        NSString* secret = [result objectForKey:@"secret"];
        [session updateAccessToken:token accessTokenSecret:secret];
        if ([delegate respondsToSelector:@selector(restClientDidLogin:)]) {
            [delegate restClientDidLogin:self];
        }
    }

    [requests removeObject:request];
}




- (void)loadMetadata:(NSString*)path withHash:(NSString*)hash
{
    NSDictionary* params = nil;
    if (hash) {
        params = [NSDictionary dictionaryWithObject:hash forKey:@"hash"];
    }
    
    NSString* fullPath = [NSString stringWithFormat:@"/metadata/%@%@", root, path];
    NSURLRequest* urlRequest = 
        [self requestWithProtocol:@"http" host:kDBDropboxAPIHost path:fullPath parameters:params];
    
    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadMetadata:)]
         autorelease];
    
    request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:root, @"root", path, @"path", nil];

    [requests addObject:request];
}

- (void)loadMetadata:(NSString*)path
{
    [self loadMetadata:path withHash:nil];
}


- (void)requestDidLoadMetadata:(DBRequest*)request
{
    NSError *error = convertRequestToError(request);

    if (error) {
        if ([delegate respondsToSelector:@selector(restClient:loadMetadataFailedWithError:)]) {
            [delegate restClient:self loadMetadataFailedWithError:error];
        }
    } else {
        [self performSelectorInBackground:@selector(parseMetadataWithRequest:) withObject:request];
    }

    [requests removeObject:request];
}


- (void)parseMetadataWithRequest:(DBRequest*)request {
    NSAutoreleasePool* pool = [NSAutoreleasePool new];
    
    NSDictionary* result = (NSDictionary*)[request resultJSON];
    [self performSelectorOnMainThread:@selector(didParseMetadata:) withObject:result waitUntilDone:NO];
    
    [pool drain];
}


- (void)didParseMetadata:(NSDictionary*)metadata {
    if ([delegate respondsToSelector:@selector(restClient:loadedMetadata:)]) {
        [delegate restClient:self loadedMetadata:metadata];
    }
}



- (void)loadFile:(NSString *)path intoPath:(NSString *)destinationPath
{
    NSString* fullPath = [NSString stringWithFormat:@"/files/%@%@", root, path];
    
    NSURLRequest* urlRequest = 
        [self requestWithProtocol:@"https" host:kDBDropboxAPIContentHost path:fullPath parameters:nil];
    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadFile:)]
         autorelease];
    request.resultFilename = destinationPath;
    request.downloadProgressSelector = @selector(requestLoadProgress:);
    request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            root, @"root", 
            path, @"path", 
            destinationPath, @"destinationPath", nil];
    [requests addObject:request];
}


- (void)requestLoadProgress:(DBRequest*)request {
    if ([delegate respondsToSelector:@selector(restClient:loadProgress:forFile:)]) {
        [delegate restClient:self loadProgress:request.downloadProgress forFile:request.resultFilename];
    }
}


- (void)requestDidLoadFile:(DBRequest*)request {
    NSError *error = convertRequestToError(request);

    if (error) {
        if ([delegate respondsToSelector:@selector(restClient:loadFileFailedWithError:)]) {
            [delegate restClient:self loadFileFailedWithError:error];
        }
    } else {
        if ([delegate respondsToSelector:@selector(restClient:loadedFile:)]) {
            [delegate restClient:self loadedFile:request.resultFilename];
        }
    }

    [requests removeObject:request];
}



- (void)loadThumbnail:(NSString *)path ofSize:(NSString *)size intoPath:(NSString *)destinationPath 
{
    NSString* fullPath = [NSString stringWithFormat:@"/thumbnails/%@%@", root, path];
    NSDictionary *params = nil;

    if(size) {
        params = [NSDictionary dictionaryWithObjectsAndKeys: size, @"size", nil];
    }
    
    NSURLRequest* urlRequest = 
        [self requestWithProtocol:@"http" host:kDBDropboxAPIContentHost path:fullPath parameters:params];

    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadThumbnail:)]
         autorelease];

    request.resultFilename = destinationPath;
    request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            root, @"root", 
            path, @"path", 
            destinationPath, @"destinationPath", nil];
    [requests addObject:request];
}



- (void)requestDidLoadThumbnail:(DBRequest*)request
{
    NSError *error = convertRequestToError(request);

    if (error) {
        if ([delegate respondsToSelector:@selector(restClient:loadThumbnailFailedWithError:)]) {
            [delegate restClient:self loadThumbnailFailedWithError:error];
        }
    } else {
        if ([delegate respondsToSelector:@selector(restClient:loadedThumbnail:)]) {
            [delegate restClient:self loadedThumbnail:request.resultFilename];
        }
    }

    [requests removeObject:request];
}




NSString *createFakeSignature(DBSession *session, NSArray *params, NSString *filename, NSURL *baseUrl)
{
    NSArray* extraParams = [MPURLRequestParameter parametersFromDictionary:
            [NSDictionary dictionaryWithObject:filename forKey:@"file"]];
    
    NSMutableArray* paramList = [NSMutableArray arrayWithArray:params];
    [paramList addObjectsFromArray:extraParams];
    [paramList sortUsingSelector:@selector(compare:)];
    NSString* paramString = [MPURLRequestParameter parameterStringForParameters:paramList];
    
    MPOAuthURLRequest* oauthRequest = 
        [[[MPOAuthURLRequest alloc] initWithURL:baseUrl andParameters:paramList] autorelease];
    oauthRequest.HTTPMethod = @"POST";
    MPOAuthSignatureParameter *signatureParameter = 
        [[[MPOAuthSignatureParameter alloc] 
                initWithText:paramString andSecret:session.credentialStore.signingKey 
                forRequest:oauthRequest usingMethod:session.credentialStore.signatureMethod]
          autorelease];

    return [signatureParameter URLEncodedParameterString];
}

NSMutableURLRequest *createRealRequest(DBSession *session, NSArray *params, NSString *urlString, NSString *signatureText)
{
    NSMutableArray *paramList = [NSMutableArray arrayWithArray:params];
    // Then rebuild request using that signature
    [paramList sortUsingSelector:@selector(compare:)];
    NSMutableString* realParamString = [[[NSMutableString alloc] initWithString:
            [MPURLRequestParameter parameterStringForParameters:paramList]]
            autorelease];
    [realParamString appendFormat:@"&%@", signatureText];
    
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", urlString, realParamString]];
    NSMutableURLRequest* urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = @"POST";

    return urlRequest;
}


BOOL addFileUploadToRequest(NSMutableURLRequest *urlRequest, NSString *filename, NSString *sourcePath)
{
    // Create input stream
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    NSString* stringBoundary = [(NSString*)CFUUIDCreateString(NULL, uuid) autorelease];
    CFRelease(uuid);

    NSString* contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",stringBoundary];
    [urlRequest addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    NSString* tempFilename = 
        [NSString stringWithFormat: @"%.0f.txt", [NSDate timeIntervalSinceReferenceDate] * 1000.0];
    NSString *tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:tempFilename];

    //setting up the body
    NSMutableData* bodyData = [NSMutableData data];
    [bodyData appendData:
            [[NSString stringWithFormat:@"--%@\r\n", stringBoundary] 
             dataUsingEncoding:NSUTF8StringEncoding]];

    // Add data to upload
    [bodyData appendData:
            [[NSString stringWithFormat:
                @"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\n", filename] 
             dataUsingEncoding:NSUTF8StringEncoding]];
    [bodyData appendData:
            [[NSString stringWithString:@"Content-Type: application/octet-stream\r\n\r\n"] 
             dataUsingEncoding:NSUTF8StringEncoding]];
             
    if (![[NSFileManager defaultManager] createFileAtPath:tempFilePath contents:bodyData attributes:nil]) {
        NSLog(@"DBRestClient#uploadFileToRoot:path:filename:fromPath: failed to create file");
        return NO;
    }

    NSFileHandle* bodyFile = [NSFileHandle fileHandleForWritingAtPath:tempFilePath];
    [bodyFile seekToEndOfFile];

    if ([[NSFileManager defaultManager] fileExistsAtPath:sourcePath]) {
        NSFileHandle* readFile = [NSFileHandle fileHandleForReadingAtPath:sourcePath];
        NSData* readData;
        while ((readData = [readFile readDataOfLength:1024 * 512]) != nil && [readData length] > 0) {
            [bodyFile writeData:readData];
        }
        [readFile closeFile];
    } else {
        NSLog(@"DBRestClient#uploadFileToRoot:path:filename:fromPath: unable to open sourceFile");
    }
    
    [bodyFile writeData:
            [[NSString stringWithFormat:@"\r\n--%@--\r\n", stringBoundary] 
             dataUsingEncoding:NSUTF8StringEncoding]];
    NSString* contentLength = [NSString stringWithFormat: @"%qu", [bodyFile offsetInFile]];
    [urlRequest addValue:contentLength forHTTPHeaderField: @"Content-Length"];    
    [bodyFile closeFile];
    
    urlRequest.HTTPBodyStream = [NSInputStream inputStreamWithFileAtPath:tempFilePath];

    return YES;
}



- (void)uploadFile:(NSString*)filename toPath:(NSString*)path fromPath:(NSString *)sourcePath
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:sourcePath]) {
        NSDictionary* userInfo = [NSDictionary dictionaryWithObject:sourcePath forKey:@"sourcePath"];
        NSError* error = 
            [NSError errorWithDomain:@"dropbox.com" code:kDBErrorFileNotFound userInfo:userInfo];
        if ([delegate respondsToSelector:@selector(restClient:uploadFileFailedWithError:)]) {
            [delegate restClient:self uploadFileFailedWithError:error];
        }
        return;
    }

    // path is the directory the file will be uploaded to, make sure it doesn't have a trailing /
    // (unless it's the root dir) and is properly escaped
    NSString* trimmedPath;
    if ([path length] > 1 && [path characterAtIndex:[path length]-1] == '/') {
        trimmedPath = [path substringToIndex:[path length]-1];
    } else {
        trimmedPath = path;
    }
    NSString* escapedPath = [self escapePath:trimmedPath];
    
    NSString* urlString = [NSString stringWithFormat:@"https://%@/%@/files/%@%@", 
            kDBDropboxAPIContentHost, kDBDropboxAPIVersion, root, escapedPath];
    NSURL* baseUrl = [NSURL URLWithString:urlString];
    NSArray* params = [session.credentialStore oauthParameters];

    NSString *signatureText = createFakeSignature(session, params, filename, baseUrl);

    NSMutableURLRequest *urlRequest = createRealRequest(session, params, urlString, signatureText);
   
    if(addFileUploadToRequest(urlRequest, filename, sourcePath)) {
        DBRequest* request = 
            [[[DBRequest alloc] 
              initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidUploadFile:)]
             autorelease];
        request.uploadProgressSelector = @selector(requestUploadProgress:);
        request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                root, @"root", 
                path, @"path", 
                sourcePath, @"sourcePath", nil];
        [requests addObject:request];
    } else {
        NSDictionary* userInfo = [NSDictionary dictionaryWithObject:sourcePath forKey:@"sourcePath"];
        NSError* error = 
            [NSError errorWithDomain:@"dropbox.com" code:kDBErrorGenericError userInfo:userInfo];
        if ([delegate respondsToSelector:@selector(restClient:uploadFileFailedWithError:)]) {
            [delegate restClient:self uploadFileFailedWithError:error];
        }
    }
}


- (void)requestUploadProgress:(DBRequest*)request {
    if ([delegate respondsToSelector:@selector(restClient:uploadProgress:forFile:)]) {
        NSString* sourcePath = [(NSDictionary*)request.userInfo objectForKey:@"sourcePath"];
        [delegate restClient:self uploadProgress:request.uploadProgress forFile:sourcePath];
    }
}


- (void)requestDidUploadFile:(DBRequest*)request {
    NSError *error = convertRequestToError(request);

    if (error) {
        if ([delegate respondsToSelector:@selector(restClient:uploadFileFailedWithError:)]) {
            [delegate restClient:self uploadFileFailedWithError:error];
        }
    } else {
        NSString* filename = [(NSDictionary*)request.userInfo objectForKey:@"sourcePath"];
        if ([delegate respondsToSelector:@selector(restClient:uploadedFile:)]) {
            [delegate restClient:self uploadedFile:filename];
        }
    }

    [requests removeObject:request];
}



- (void)moveFrom:(NSString*)from_path toPath:(NSString *)to_path
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
            root, @"root",
            from_path, @"from_path",
            to_path, @"to_path", nil];
            
    NSMutableURLRequest* urlRequest = 
        [self requestWithProtocol:@"http" host:kDBDropboxAPIHost path:@"/fileops/copy"
                parameters:params method:@"POST"];

    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidMovePath:)]
         autorelease];

    request.userInfo = params;
    [requests addObject:request];
}



- (void)requestDidMovePath:(DBRequest*)request {
    NSError *error = convertRequestToError(request);

    if (error) {
        if ([delegate respondsToSelector:@selector(restClient:movePathFailedWithError:)]) {
            [delegate restClient:self movePathFailedWithError:error];
        }
    } else {
        NSDictionary *params = (NSDictionary *)request.userInfo;

        if ([delegate respondsToSelector:@selector(restClient:movedPath:toPath:)]) {
            [delegate restClient:self movedPath:[params valueForKey:@"from_path"] 
                        toPath:[params valueForKey:@"to_path"]];
        }
    }

    [requests removeObject:request];
}


- (void)copyFrom:(NSString*)from_path toPath:(NSString *)to_path
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
            root, @"root",
            from_path, @"from_path",
            to_path, @"to_path", nil];
            
    NSMutableURLRequest* urlRequest = 
        [self requestWithProtocol:@"http" host:kDBDropboxAPIHost path:@"/fileops/copy"
                parameters:params method:@"POST"];

    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidCopyPath:)]
         autorelease];

    request.userInfo = params;
    [requests addObject:request];
}



- (void)requestDidCopyPath:(DBRequest*)request {
    NSError *error = convertRequestToError(request);

    if (error) {
        if ([delegate respondsToSelector:@selector(restClient:copyPathFailedWithError:)]) {
            [delegate restClient:self copyPathFailedWithError:error];
        }
    } else {
        NSDictionary *params = (NSDictionary *)request.userInfo;

        if ([delegate respondsToSelector:@selector(restClient:copiedPath:toPath:)]) {
            [delegate restClient:self copiedPath:[params valueForKey:@"from_path"] 
                        toPath:[params valueForKey:@"to_path"]];
        }
    }

    [requests removeObject:request];
}


- (void)deletePath:(NSString*)path
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
            root, @"root",
            path, @"path", nil];
            
    NSMutableURLRequest* urlRequest = 
        [self requestWithProtocol:@"http" host:kDBDropboxAPIHost path:@"/fileops/delete" 
                parameters:params method:@"POST"];

    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidDeletePath:)]
         autorelease];

    request.userInfo = path;
    [requests addObject:request];
}



- (void)requestDidDeletePath:(DBRequest*)request {
    NSError *error = convertRequestToError(request);

    if (error) {
        if ([delegate respondsToSelector:@selector(restClient:deletePathFailedWithError:)]) {
            [delegate restClient:self deletePathFailedWithError:error];
        }
    } else {
        if ([delegate respondsToSelector:@selector(restClient:deletedPath:)]) {
            [delegate restClient:self deletedPath:(NSString *)request.userInfo];
        }
    }

    [requests removeObject:request];
}




- (void)createFolder:(NSString*)path
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
            root, @"root",
            path, @"path", nil];
            
    NSString* fullPath = @"/fileops/create_folder";
    NSMutableURLRequest* urlRequest = 
        [self requestWithProtocol:@"http" host:kDBDropboxAPIHost path:fullPath 
                parameters:params method:@"POST"];
    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidCreateDirectory:)]
         autorelease];
    request.userInfo = params;
    [requests addObject:request];
}



- (void)requestDidCreateDirectory:(DBRequest*)request {
    NSError *error = convertRequestToError(request);

    if (error) {
        if ([delegate respondsToSelector:@selector(restClient:createFolderFailedWithError:)]) {
            [delegate restClient:self createFolderFailedWithError:error];
        }
    } else {
        NSDictionary* result = (NSDictionary*)[request resultJSON];
        if ([delegate respondsToSelector:@selector(restClient:createdFolder:)]) {
            [delegate restClient:self createdFolder:result];
        }
    }

    [requests removeObject:request];
}



- (void)loadAccountInfo
{
    NSURLRequest* urlRequest = 
        [self requestWithProtocol:@"http" host:kDBDropboxAPIHost path:@"/account/info" parameters:nil];
    
    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadAccountInfo:)]
         autorelease];
    
    request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:root, @"root", nil];

    [requests addObject:request];
}


- (void)requestDidLoadAccountInfo:(DBRequest*)request
{
    NSError *error = convertRequestToError(request);

    if (error) {
        if ([delegate respondsToSelector:@selector(restClient:loadAccountInfoFailedWithError:)]) {
            [delegate restClient:self loadAccountInfoFailedWithError:error];
        }
    } else {
        NSDictionary* result = (NSDictionary*)[request resultJSON];
        if ([delegate respondsToSelector:@selector(restClient:loadedAccountInfo:)]) {
            [delegate restClient:self loadedAccountInfo:result];
        }
    }

    [requests removeObject:request];
}

- (void)createAccount:(NSString *)email password:(NSString *)password firstName:(NSString *)firstName lastName:(NSString *)lastName
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
                            email, @"email",
                            password, @"password",
                            firstName, @"first_name",
                            lastName, @"last_name", nil];
    
    NSString* fullPath = @"/account";
    NSMutableURLRequest* urlRequest = 
    [self requestWithProtocol:@"https" host:kDBDropboxAPIHost path:fullPath 
                   parameters:params method:@"POST"];
    
    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidCreateAccount:)]
            autorelease];

    request.userInfo = params;
    
    [requests addObject:request];
}

- (void)requestDidCreateAccount:(DBRequest *)request
{
    NSError *error = convertRequestToError(request);

    if(error) {
        if([delegate respondsToSelector:@selector(restClient:createAccountFailedWithError:)]) {
            [delegate restClient:self createAccountFailedWithError:error];
        }
    } else {
        if ([delegate respondsToSelector:@selector(restClientCreatedAccount:)]) {
            [delegate restClientCreatedAccount:self];
        }
    }
    
    [requests removeObject:request];
}


#pragma mark private methods


- (NSMutableURLRequest*)requestWithProtocol:(NSString*)protocol host:(NSString*)host path:(NSString*)path 
    parameters:(NSDictionary*)params {
    
    return [self requestWithProtocol:protocol host:host path:path parameters:params method:nil];
}



- (NSMutableURLRequest*)requestWithProtocol:(NSString*)protocol host:(NSString*)host path:(NSString*)path 
    parameters:(NSDictionary*)params method:(NSString*)method {
    
    NSString* escapedPath = [self escapePath:path];
    NSString* urlString = [NSString stringWithFormat:@"%@://%@/%@%@", 
                                        protocol, host, kDBDropboxAPIVersion, escapedPath];
    NSURL* url = [NSURL URLWithString:urlString];
    
    NSArray* paramList = [session.credentialStore oauthParameters];
    if ([params count] > 0) {
        NSArray* extraParams = [MPURLRequestParameter parametersFromDictionary:params];
        paramList = [paramList arrayByAddingObjectsFromArray:extraParams];
    }
    MPOAuthURLRequest* oauthRequest = 
        [[[MPOAuthURLRequest alloc] initWithURL:url andParameters:paramList] autorelease];
    if (method) {
        oauthRequest.HTTPMethod = method;
    }
    NSMutableURLRequest* urlRequest = [oauthRequest 
            urlRequestSignedWithSecret:session.credentialStore.signingKey 
            usingMethod:session.credentialStore.signatureMethod];
    return urlRequest;
}


- (NSString*)escapePath:(NSString*)path {
    CFStringEncoding encoding = CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding);
	NSString *escapedPath = 
        (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                            (CFStringRef)path,
															NULL,
															(CFStringRef)@":?=,!$&'()*+;[]@#",
															encoding);
	
	return [escapedPath autorelease];


}


@end
