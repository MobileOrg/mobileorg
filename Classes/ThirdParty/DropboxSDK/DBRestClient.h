//
//  DBRestClient.h
//  DropboxSDK
//
//  Created by Brian Smith on 4/9/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//


@protocol DBRestClientDelegate;
@class DBSession;


// Error codes in the dropbox.com domain represent the HTTP status code if less than 1000
enum {
    kDBErrorGenericError = 1000,
    kDBErrorFileNotFound,
} kDBErrorCode;


@interface DBRestClient : NSObject {
    DBSession* session;
    NSMutableSet* requests;
    id<DBRestClientDelegate> delegate;
    NSString *root;
}

- (id)initWithSession:(DBSession*)session;

- (id)initWithSession:(DBSession*)aSession andRoot:(NSString *)theRoot;

/* Logs in as the user with the given email/password and stores the OAuth tokens on the session 
   object */
- (void)loginWithEmail:(NSString*)email password:(NSString*)password;

/* Loads metadata for the object at the given root/path and returns the result to the delegate as a 
   dictionary */
- (void)loadMetadata:(NSString*)path withHash:(NSString*)hash;
- (void)loadMetadata:(NSString*)path;

/* Loads the file contents at the given root/path and stores the result into destinationPath */
- (void)loadFile:(NSString *)path intoPath:(NSString *)destinationPath;

- (void)loadThumbnail:(NSString *)path ofSize:(NSString *)size intoPath:(NSString *)destinationPath;

/* Uploads a file that will be named filename to the given root/path on the server. It will upload
   the contents of the file at sourcePath */
- (void)uploadFile:(NSString*)filename toPath:(NSString*)path fromPath:(NSString *)sourcePath;

/* Creates a folder at the given root/path */
- (void)createFolder:(NSString*)path;

- (void)deletePath:(NSString*)path;

- (void)copyFrom:(NSString*)from_path toPath:(NSString *)to_path;

- (void)moveFrom:(NSString*)from_path toPath:(NSString *)to_path;

- (void)loadAccountInfo;

- (void)createAccount:(NSString *)email password:(NSString *)password firstName:(NSString *)firstName lastName:(NSString *)lastName;

@property (nonatomic, assign) id<DBRestClientDelegate> delegate;

@end




/* The delegate provides allows the user to get the result of the calls made on the DBRestClient.
   Right now, the error parameter of failed calls may be nil and [error localizedDescription] does
   not contain an error message appropriate to show to the user. */
@protocol DBRestClientDelegate <NSObject>

@optional

- (void)restClientDidLogin:(DBRestClient*)client;
- (void)restClient:(DBRestClient*)client loginFailedWithError:(NSError*)error;

- (void)restClient:(DBRestClient*)client loadedMetadata:(NSDictionary*)metadata;
- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error; 
// [error userInfo] contains the root and path of the call that failed

- (void)restClient:(DBRestClient*)client loadedAccountInfo:(NSDictionary*)metadata;
- (void)restClient:(DBRestClient*)client loadAccountInfoFailedWithError:(NSError*)error; 

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)destPath;
- (void)restClient:(DBRestClient*)client loadProgress:(CGFloat)progress forFile:(NSString*)destPath;
- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error;
// [error userInfo] contains the destinationPath

- (void)restClient:(DBRestClient*)client loadedThumbnail:(NSString*)destPath;
- (void)restClient:(DBRestClient*)client loadThumbnailFailedWithError:(NSError*)error;

- (void)restClient:(DBRestClient*)client uploadedFile:(NSString*)srcPath;
- (void)restClient:(DBRestClient*)client uploadProgress:(CGFloat)progress forFile:(NSString*)srcPath;
- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error;
// [error userInfo] contains the sourcePath

- (void)restClient:(DBRestClient*)client createdFolder:(NSDictionary*)folder;
// Folder is the metadata for the newly created folder
- (void)restClient:(DBRestClient*)client createFolderFailedWithError:(NSError*)error;
// [error userInfo] contains the root and path

- (void)restClient:(DBRestClient*)client deletedPath:(NSString *)path;
// Folder is the metadata for the newly created folder
- (void)restClient:(DBRestClient*)client deletePathFailedWithError:(NSError*)error;
// [error userInfo] contains the root and path

- (void)restClient:(DBRestClient*)client copiedPath:(NSString *)from_path toPath:(NSString *)to_path;
// Folder is the metadata for the newly created folder
- (void)restClient:(DBRestClient*)client copyPathFailedWithError:(NSError*)error;
// [error userInfo] contains the root and path
//
- (void)restClient:(DBRestClient*)client movedPath:(NSString *)from_path toPath:(NSString *)to_path;
// Folder is the metadata for the newly created folder
- (void)restClient:(DBRestClient*)client movePathFailedWithError:(NSError*)error;
// [error userInfo] contains the root and path

- (void)restClientCreatedAccount:(DBRestClient*)client;
- (void)restClient:(DBRestClient*)client createAccountFailedWithError:(NSError *)error;

@end


