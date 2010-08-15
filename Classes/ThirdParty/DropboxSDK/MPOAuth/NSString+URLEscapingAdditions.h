//
//  NSString+URLEscapingAdditions.h
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.07.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#ifndef __GNUC__
#define __asm__ asm
#endif

__asm__(".weak_reference _OBJC_CLASS_$_NSURL");

#import <Foundation/Foundation.h>


@interface NSString (MPURLEscapingAdditions)

- (BOOL)isIPAddress;
- (NSString *)stringByAddingURIPercentEscapesUsingEncoding:(NSStringEncoding)inEncoding;

@end

@interface NSURL (MPURLEscapingAdditions)
- (NSString *)stringByAddingURIPercentEscapesUsingEncoding:(NSStringEncoding)inEncoding;
@end
