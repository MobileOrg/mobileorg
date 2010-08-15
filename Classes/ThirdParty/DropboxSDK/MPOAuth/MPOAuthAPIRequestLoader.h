//
//  MPOAuthAPIRequestLoader.h
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.05.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#ifndef __GNUC__
#define __asm__ asm
#endif

__asm__(".weak_reference _OBJC_CLASS_$_NSURL");

#import <Foundation/Foundation.h>

extern NSString * const MPOAuthNotificationRequestTokenReceived;
extern NSString * const MPOAuthNotificationRequestTokenRejected;
extern NSString * const MPOAuthNotificationAccessTokenReceived;
extern NSString * const MPOAuthNotificationAccessTokenRejected;
extern NSString * const MPOAuthNotificationAccessTokenRefreshed;
extern NSString * const MPOAuthNotificationErrorHasOccurred;

@protocol MPOAuthCredentialStore;
@protocol MPOAuthParameterFactory;

@class MPOAuthURLRequest;
@class MPOAuthURLResponse;
@class MPOAuthCredentialConcreteStore;

@interface MPOAuthAPIRequestLoader : NSObject {
	MPOAuthCredentialConcreteStore	*_credentials;
	MPOAuthURLRequest				*_oauthRequest;
	MPOAuthURLResponse				*_oauthResponse;
	NSMutableData					*_dataBuffer;
	NSString						*_dataAsString;
	NSError							*_error;
	id								_target;
	SEL								_action;
}

@property (nonatomic, readwrite, retain) id <MPOAuthCredentialStore, MPOAuthParameterFactory> credentials;
@property (nonatomic, readwrite, retain) MPOAuthURLRequest *oauthRequest;
@property (nonatomic, readwrite, retain) MPOAuthURLResponse *oauthResponse;
@property (nonatomic, readonly, retain) NSData *data;
@property (nonatomic, readonly, retain) NSString *responseString;
@property (nonatomic, readwrite, assign) id target;
@property (nonatomic, readwrite, assign) SEL action;

- (id)initWithURL:(NSURL *)inURL;
- (id)initWithRequest:(MPOAuthURLRequest *)inRequest;

- (void)loadSynchronously:(BOOL)inSynchronous;

@end

