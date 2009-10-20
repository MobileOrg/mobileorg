//
//  ChecksumFileParser.m
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

#import "ChecksumFileParser.h"

@implementation ChecksumFileParser

@synthesize checksumPairs;

- (id)init {
    if (self = [super init]) {
        self.checksumPairs = [NSMutableDictionary new];
    }
    return self;
}

- (void)reset {
    [self.checksumPairs removeAllObjects];
}

- (void)parse:(NSString*)filename {
    [checksumPairs removeAllObjects];

    NSError *error = nil;
    NSString *entireFile = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        //NSLog(@"Failed to read contents of file because: %@ (%@)", [error description], [error userInfo]);
        entireFile = @"";
    }

    NSScanner *theScanner;
    theScanner = [NSScanner scannerWithString:entireFile];

    NSString *line;
    NSCharacterSet *eolSet;
    eolSet = [NSCharacterSet characterSetWithCharactersInString:@"\n"];

    [theScanner setCharactersToBeSkipped:eolSet];

    // Handle md5 output from osx, md5sum from linux, and shasum output
    // Be careful not to die if there's a bad line (like if you md5sum'd * with dirs in it
    while ([theScanner isAtEnd] == NO) {
        if ([theScanner scanUpToCharactersFromSet:eolSet intoString:&line]) {
            if (line && [line length] > 0) {
                // shasum
                // 40 chars of checksum, 2 spaces, filename
                // 4c05152c39bcc402ea99851c01e3849060a9d3a1  MainWindow.xib

                // md5 on osx
                // MD5 (filename) = 32hex chars
                // MD5 (Icon.png) = 476d45ce45fc0658bbda13137bc60205

                // md5sum on linux
                // 32hex chars, 2 spaces, filename
                // e5d34d894456a55345977fc617e79a17  org-contribute.org

                static NSString *shasumRegex = @"([a-f0-9]{40})  (.+)";
                static NSString *md5sumRegex = @"([a-f0-9]+)  (.+)";
                static NSString *osxmd5Regex = @"MD5 \\((.+)\\) = ([a-f0-9]{32})";

                NSString *checksum = nil, *filename = nil;
                NSArray *matches = nil;

                matches = [line componentsSeparatedByRegex:shasumRegex];
                if ([matches count] == 3) {
                    checksum = [matches objectAtIndex:1];
                    filename = [matches objectAtIndex:2];
                } else {
                    matches = [line componentsSeparatedByRegex:md5sumRegex];
                    if ([matches count] == 3) {
                        checksum = [matches objectAtIndex:1];
                        filename = [matches objectAtIndex:2];
                    } else {
                        matches = [line componentsSeparatedByRegex:osxmd5Regex];
                        if ([matches count] == 4) {
                            // NOTE: Filename and checksum are swapped
                            filename = [matches objectAtIndex:1];
                            checksum = [matches objectAtIndex:2];
                        }
                    }
                }

                if (checksum && filename) {
                    [checksumPairs setObject:checksum forKey:filename];
                }
            }
        }
    }
}

- (void)dealloc {
    self.checksumPairs = nil;
    [super dealloc];
}

@end
