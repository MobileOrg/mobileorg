//
//  TransferContext.m
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

#import "TransferContext.h"

@implementation TransferContext

@synthesize remoteUrl;
@synthesize localFile;
@synthesize transferType;
@synthesize delegate;
@synthesize statusCode;
@synthesize errorText;
@synthesize abortOnFailure;
@synthesize success;
@synthesize dummy;

- (id)init {
    if (self = [super init]) {
        self.remoteUrl = nil;
        self.localFile = @"";
        self.errorText = @"";
        self.statusCode = 0;
        self.delegate = nil;
        self.dummy = false;
    }
    return self;
}

@end
