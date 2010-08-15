//
//  MPOAuthURLRequest.h
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


@interface MPOAuthURLRequest : NSObject {
@private
	NSURL			*_url;
	NSString		*_httpMethod;
	NSURLRequest	*_urlRequest;
	NSMutableArray	*_parameters;
}

@property (nonatomic, readwrite, retain) NSURL *url;
@property (nonatomic, readwrite, retain) NSString *HTTPMethod;
@property (nonatomic, readonly, retain) NSURLRequest *urlRequest;
@property (nonatomic, readwrite, retain) NSMutableArray *parameters;

- (id)initWithURL:(NSURL *)inURL andParameters:(NSArray *)parameters;
- (id)initWithURLRequest:(NSURLRequest *)inRequest;

- (void)addParameters:(NSArray *)inParameters;

- (NSMutableURLRequest*)urlRequestSignedWithSecret:(NSString *)inSecret usingMethod:(NSString *)inScheme;

@end
