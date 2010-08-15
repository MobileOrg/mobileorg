//
//  MPOAuthAuthenticationMethod.h
//  MPOAuthConnection
//
//  Created by Karl Adam on 09.12.19.
//  Copyright 2009 matrixPointer. All rights reserved.
//

#ifndef __GNUC__
#define __asm__ asm
#endif

__asm__(".weak_reference _OBJC_CLASS_$_NSURL");

#import <Foundation/Foundation.h>

extern NSString * const MPOAuthAccessTokenURLKey;

@class MPOAuthAPI;

@interface MPOAuthAuthenticationMethod : NSObject {
	MPOAuthAPI								*oauthAPI_;
	NSURL									*oauthGetAccessTokenURL_;
	NSTimer									*refreshTimer_;
}

@property (nonatomic, readwrite, assign) MPOAuthAPI *oauthAPI;
@property (nonatomic, readwrite, retain) NSURL *oauthGetAccessTokenURL;

- (id)initWithAPI:(MPOAuthAPI *)inAPI forURL:(NSURL *)inURL;
- (id)initWithAPI:(MPOAuthAPI *)inAPI forURL:(NSURL *)inURL withConfiguration:(NSDictionary *)inConfig;
- (void)authenticate;

- (void)setTokenRefreshInterval:(NSTimeInterval)inTimeInterval;
- (void)refreshAccessToken;
@end
