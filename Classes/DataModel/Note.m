//
//  Note.m
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

#import "Note.h"
#import "Node.h"
#import "DataUtils.h"
#import "GlobalUtils.h"

@implementation Note

@dynamic text;
@dynamic createdAt;
@dynamic nodeId;
@dynamic noteId;
@dynamic locallyModified;
@dynamic deleted;

- (NSString*)heading {
    // If it is a flag entry, the flag part is the title, the rest is the body
    if ([self isFlagEntry]) {
        Node *node = ResolveNode(self.nodeId);
        return [NSString stringWithFormat:@"F() [[%@][%@]]", self.nodeId, [node headingForDisplay]];
    }

    if (!self.text || [self.text length] == 0) {
        return @"No title";
    }

    NSRange rangeOfFirstNewline = [self.text rangeOfString:@"\n"];
    if (rangeOfFirstNewline.location != NSNotFound) {
        return [self.text substringToIndex:rangeOfFirstNewline.location];
    } else {
        return self.text;
    }
}

- (NSString*)body {
    // If it is a flag entry, the flag part is the title, the rest is the body
    if ([self isFlagEntry]) {
        return [self text];
    }

    if (!self.text || [self.text length] == 0) {
        return @"";
    }
    NSRange rangeOfFirstNewline = [self.text rangeOfString:@"\n"];
    if (rangeOfFirstNewline.location != NSNotFound && [self.text length] > rangeOfFirstNewline.location+1) {
        return [self.text substringFromIndex:rangeOfFirstNewline.location+1];
    } else {
        return @"";
    }
}

- (bool)isFlagEntry {
    return self.nodeId && [self.nodeId length] > 0;
}

// * first line of the note
//   [2009-09-09 Wed 09:25]
//   Rest of the note
- (NSString*)orgLine {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY-MM-dd EEE HH:mm"];
    NSString *timestamp = [formatter stringFromDate:[self createdAt]];
    [formatter release];

    NSString *bodyStr = [self body];
    if (bodyStr && [bodyStr length] > 0) {
        // Make the body text indented by 2 spaces on each line
        // Actually, don't do this.  It makes it easier to later figure out what the original
        // intent was.
        // bodyStr = [bodyStr stringByReplacingOccurrencesOfString:@"\n" withString:@"\n  "];

        // Then get rid of any extra spaces or newlines at the ends
        bodyStr = [bodyStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // Make sure none of the lines start with *
        bodyStr = EscapeHeadings(bodyStr);

        return [NSString stringWithFormat:@"* %@\n[%@]\n%@\n", [self heading], timestamp, bodyStr];
    } else {
        return [NSString stringWithFormat:@"* %@\n[%@]\n", [self heading], timestamp];
    }
}

@end
