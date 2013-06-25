//
//  EditsFileParser.m
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

#import "EditsFileParser.h"
#import "EditEntity.h"
#import "DataUtils.h"
#import "GlobalUtils.h"
#import "RegexKitLite.h"

@implementation EditsFileParser

@synthesize delegate;
@synthesize completionSelector;
@synthesize editsFilename;
@synthesize editEntities;

- (id)init {
    if (self = [super init]) {
        NSMutableArray *newArray = [NSMutableArray new];
        self.editEntities = newArray;
        [newArray release];
    }
    return self;
}

- (void)parse {

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSString *errorStr = nil;
    NSString *entireFile;

    // Read the entire file into memory (perhaps one day we'll do this line by line somehow?)
    if ([[NSFileManager defaultManager] fileExistsAtPath:editsFilename]) {        
        entireFile = ReadPossiblyEncryptedFile(editsFilename, &errorStr);
        if (errorStr) {
            entireFile = [NSString stringWithFormat:@"* Error: %@\n", errorStr];
        } else if (!entireFile) {
            entireFile = @"* Bad file encoding\n  Unable to detect file encoding, please re-save this file using UTF-8.";
            errorStr = @"Unknown encoding, re-save file as UTF-8";
        }
    } else {
        entireFile = @"";
    }

    // Get rid of any existing edits
    [[self editEntities] removeAllObjects];

    // Parse file
    {
        // * F(edit:heading) [[id:...][section title]]
        // ** Old value
        // Some old content
        // ** New value
        // Some new content
        static NSString *FlagRegex = @"F\\((edit:.+)\\) \\[\\[(.+)\\]\\[(.+)\\]\\]";

        NSArray *lines;
        NSString *line;
        NSArray *captures;
        bool awaitingOldValue = false;
        bool awaitingNewValue = false;
        bool awaitingTimestampForNonEditNode = false;
        bool awaitingBodyTextForNonEditNode = false;

        lines = [entireFile componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n"]];
        
        // Until we hit the end of the file
        for (int i = 0; i < [lines count]; i++) {

            if ([[NSThread currentThread] isCancelled]) {
                // TODO: Add support for cancellation
                // [self setResult:EditsFileParseResultCancelled];
                break;
            }

            line = [lines objectAtIndex:i];

            // See if it is a flag line
            captures = [line captureComponentsMatchedByRegex:FlagRegex];
            if ([captures count] > 0) {

                // About to start a new editEntry, but strip off whitespace that may be
                // between entities here, it is wrongly attached to the last entitie's newValue.
                if ([editEntities count] > 0) {
                    EditEntity *lastEntity = [editEntities lastObject];
                    int lastNonspaceChar;
                    for (lastNonspaceChar = [lastEntity.newValue length]-1; lastNonspaceChar >= 0; lastNonspaceChar--) {
                        char c = [lastEntity.newValue characterAtIndex:lastNonspaceChar];
                        if (c != '\n' && c != '\r' && c != ' ' && c != '\t' && c != 0) {
                            break;
                        }
                    }
                    if (lastNonspaceChar >= 0 && lastNonspaceChar < [lastEntity.newValue length]-1) {
                        lastEntity.newValue = [lastEntity.newValue substringToIndex:lastNonspaceChar+1];
                    }
                }

                Node *node = ResolveNode([captures objectAtIndex:2]);

                EditEntity *entity = [[EditEntity alloc] init];
                [entity setEditAction:[captures objectAtIndex:1]];
                [entity setNode:node];
                [editEntities addObject:entity];
                [entity release];

                awaitingOldValue = false;

                // We await a new value by default, since F() entries have neither
                // old or new values, we just store the note in the new value slot.
                // This would be cleaner if notes were something like F(newnote) with
                // an empty oldvalue and only a newvalue.
                awaitingNewValue = true;

                awaitingTimestampForNonEditNode = false;
                awaitingBodyTextForNonEditNode = false;

            } else if ([line rangeOfString:@"* "].location == 0) {

                // About to start a new editEntry, but strip off whitespace that may be
                // between entities here, it is wrongly attached to the last entitie's newValue.
                if ([editEntities count] > 0) {
                    EditEntity *lastEntity = [editEntities lastObject];
                    int lastNonspaceChar;
                    for (lastNonspaceChar = [lastEntity.newValue length]-1; lastNonspaceChar >= 0; lastNonspaceChar--) {
                        char c = [lastEntity.newValue characterAtIndex:lastNonspaceChar];
                        if (c != '\n' && c != '\r' && c != ' ' && c != '\t' && c != 0) {
                            break;
                        }
                    }
                    if (lastNonspaceChar >= 0 && lastNonspaceChar < [lastEntity.newValue length]-1) {
                        lastEntity.newValue = [lastEntity.newValue substringToIndex:lastNonspaceChar+1];
                    }
                }

                // This means we are in a note or otherwise non-edit section of the outline
                // In this case, we want to make a simple edit entry with no actionType, and
                // get ready to accept the body

                if ([line length] > 2) {
                    EditEntity *entity = [[EditEntity alloc] init];
                    [entity setEditAction:@""];
                    [entity setHeading:[line substringFromIndex:2]];
                    [editEntities addObject:entity];
                    [entity release];

                    awaitingTimestampForNonEditNode = true;
                    awaitingBodyTextForNonEditNode = false;
                }

            } else if ([editEntities count] > 0) {

                if (awaitingTimestampForNonEditNode) {

                    NSString *bareDate = [NSString stringWithString:line];
                    bareDate = [bareDate stringByReplacingOccurrencesOfString:@"[" withString:@""];
                    bareDate = [bareDate stringByReplacingOccurrencesOfString:@"]" withString:@""];

                    NSDateFormatter *df = [NSDateFormatter new];
                    [df setDateFormat:@"yyyy-MM-dd EEE HH:mm"];
                    NSDate *date = [df dateFromString:bareDate];

                    [[editEntities lastObject] setCreatedAt:date];

                    [df release];

                    awaitingTimestampForNonEditNode = false;
                    awaitingBodyTextForNonEditNode = true;

                    continue;
                }
                if ([line rangeOfString:@"** Note ID: "].location == 0) {
                    [[editEntities lastObject] setNoteId:[line substringFromIndex:12]];
                    continue;
                }

                if (awaitingBodyTextForNonEditNode) {
                    NSString *v = [[editEntities lastObject] newValue];
                    if (v && [v length] > 0) {
                        v = [v stringByAppendingFormat:@"\n%@", line];
                    } else {
                        v = line;
                    }
                    [[editEntities lastObject] setNewValue:v];
                    continue;
                }

                if ([line isEqualToString:@"** Old value"]) {
                    awaitingOldValue = true;
                    awaitingNewValue = false;
                    continue;
                } else if ([line isEqualToString:@"** New value"]) {
                    awaitingOldValue = false;
                    awaitingNewValue = true;
                    continue;
                } else if ([line isEqualToString:@"** End of edit"]) {
                    awaitingOldValue = false;
                    awaitingNewValue = false;
                    continue;
                }

                if (awaitingOldValue) {
                    NSString *v = [[editEntities lastObject] oldValue];
                    if (v && [v length] > 0) {
                        v = [v stringByAppendingFormat:@"\n%@", line];
                    } else {
                        v = line;
                    }
                    [[editEntities lastObject] setOldValue:v];
                } else if (awaitingNewValue) {
                    NSString *v = [[editEntities lastObject] newValue];
                    if (v && [v length] > 0) {
                        v = [v stringByAppendingFormat:@"\n%@", line];
                    } else {
                        v = line;
                    }
                    [[editEntities lastObject] setNewValue:v];
                }
            }
        }
    }

    // Trim off whitespace at the end of the the last object's newValue
    if ([editEntities count] > 0) {
        EditEntity *lastEntity = [editEntities lastObject];
        int lastNonspaceChar;
        for (lastNonspaceChar = [lastEntity.newValue length]-1; lastNonspaceChar >= 0; lastNonspaceChar--) {
            char c = [lastEntity.newValue characterAtIndex:lastNonspaceChar];
            if (c != '\n' && c != '\r' && c != ' ' && c != '\t' && c != 0) {
                break;
            }
        }
        if (lastNonspaceChar >= 0 && lastNonspaceChar < [lastEntity.newValue length]-1) {
            lastEntity.newValue = [lastEntity.newValue substringToIndex:lastNonspaceChar+1];
        }
    }

    [delegate performSelectorOnMainThread:completionSelector withObject:nil waitUntilDone:NO];

    [pool release];
}

- (void)reset {
    [editEntities removeAllObjects];
    self.editsFilename = nil;
}

- (void)dealloc {
    [editEntities release];
    [editsFilename release];
    [super dealloc];
}

@end
