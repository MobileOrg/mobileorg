//
//  TransferContext.h
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

#ifndef __GNUC__
#define __asm__ asm
#endif

__asm__(".weak_reference _OBJC_CLASS_$_NSURL");

#import <Foundation/Foundation.h>
#import "TransferManagerDelegate.h"

typedef enum {
    TransferTypeDownload,
    TransferTypeUpload
} TransferType;

@interface TransferContext : NSObject {
    NSURL *remoteUrl;
    NSString *localFile;
    TransferType transferType;
    __unsafe_unretained id<TransferManagerDelegate> delegate;
    NSString *errorText;
    bool success;
    bool abortOnFailure;
    int statusCode;
    bool dummy;
}

@property (nonatomic, copy) NSURL *remoteUrl;
@property (nonatomic, copy) NSString *localFile;
@property (nonatomic) TransferType transferType;
@property (nonatomic, assign) id<TransferManagerDelegate> delegate;
@property (nonatomic) int statusCode;
@property (nonatomic, copy) NSString *errorText;
@property (nonatomic) bool abortOnFailure;
@property (nonatomic) bool success;
@property (nonatomic) bool dummy;

@end
