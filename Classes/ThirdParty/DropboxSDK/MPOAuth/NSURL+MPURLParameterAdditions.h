//
//  NSURL+MPURLParameterAdditions.h
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.08.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#ifndef __GNUC__
#define __asm__ asm
#endif

__asm__(".weak_reference _OBJC_CLASS_$_NSURL");

#import <Foundation/Foundation.h>


@interface NSURL (MPURLParameterAdditions)

- (NSURL *)urlByAddingParameters:(NSArray *)inParameters;
- (NSURL *)urlByAddingParameterDictionary:(NSDictionary *)inParameters;
- (NSURL *)urlByRemovingQuery;
- (NSString *)absoluteNormalizedString;

- (BOOL)domainMatches:(NSString *)inString;

@end
