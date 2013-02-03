//
//  DropboxTransferManager.h
//  MobileOrg
//
//  Created by Richard Moreland on 9/30/09.
//  Copyright 2010 Richard Moreland.
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
#import <DropboxSDK/DropboxSDK.h>
#import "TransferManager.h"

@class TransferContext;

@interface DropboxTransferManager : TransferManager <DBRestClientDelegate> {
    NSMutableArray *transfers;
    bool active;
    bool paused;
    TransferContext *activeTransfer;
    NSURLConnection *connection;
    NSMutableData *data;
    NSNumber *fileSize;
    DBSession *dbSession;
    DBRestClient *dbClient;
}

@property (nonatomic, retain) TransferContext *activeTransfer;
@property (nonatomic, copy) NSNumber *fileSize;

+ (DropboxTransferManager*)instance;
- (void)enqueueTransfer:(TransferContext*)transfer;
- (void)pause;
- (void)resume;
- (bool)busy;
- (int)queueSize;
- (void)abort;
- (void)login:(NSObject*)rootController;
- (void)unlink;
- (BOOL)isLinked;

@end
