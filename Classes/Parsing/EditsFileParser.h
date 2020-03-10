//
//  EditsFileParser.h
//  MobileOrg
//
//  Created by Richard Moreland on 10/3/09.
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

@interface EditsFileParser : NSObject {
    __unsafe_unretained id delegate;
    SEL completionSelector;
    NSString *editsFilename;
    NSMutableArray *editEntities;
}

@property (nonatomic, assign) id delegate;
@property (nonatomic) SEL completionSelector;
@property (nonatomic, copy) NSString *editsFilename;
@property (nonatomic, retain) NSMutableArray *editEntities;

- (void)parse;
- (void)reset;

@end
