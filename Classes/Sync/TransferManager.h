//
//  TransferManager.h
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

#import <Foundation/Foundation.h>

@class TransferContext;

@interface TransferManager : NSObject {
    NSMutableArray *transfers;
    bool active;
    bool paused;
    TransferContext *activeTransfer;
    NSURLConnection *connection;
    NSMutableData *data;
    NSNumber *fileSize;
}

@property (nonatomic, retain) TransferContext *activeTransfer;
@property (nonatomic, copy) NSNumber *fileSize;

+ (TransferManager*)instance;
- (void)enqueueTransfer:(TransferContext*)transfer;
- (void)pause;
- (void)resume;
- (bool)busy;
- (int)queueSize;
- (void)abort;

@end
