//
//  Node.m
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

#import "Node.h"
#import "LocalEditAction.h"
#import "DataUtils.h"
#import "Settings.h"
#import "GlobalUtils.h"
#import "MobileOrg-Swift.h"

@implementation Node

@dynamic body;
@dynamic heading;
@dynamic sequenceIndex;
@dynamic todoState;
@dynamic tags;
@dynamic inheritedTags;
@dynamic referencedNodeId;
@dynamic nodeId;
@dynamic outlinePath;
@dynamic indentLevel;
@dynamic readOnly;
@dynamic priority;
@dynamic parent;
@dynamic notes;
@dynamic children;

static NSString *kUnixFileLinkRegex = @"\\[\\[file:(.*\\.(?:org|txt))\\]\\[(.*)\\]\\]";


- (NSComparisonResult)sequenceIndexCompare:(Node*)obj
{
    NSComparisonResult retVal = NSOrderedSame;
    if ([self.sequenceIndex intValue] > [obj.sequenceIndex intValue])
        retVal = NSOrderedDescending;
    else if ([self.sequenceIndex intValue] < [obj.sequenceIndex intValue])
        retVal = NSOrderedAscending;
    return retVal;
}

- (NSString*)bestId {
    if (self.nodeId && [self.nodeId length] > 0) {
        return [NSString stringWithFormat:@"id:%@", self.nodeId];
    } else if (self.referencedNodeId && [self.referencedNodeId length] > 0) {
        return self.referencedNodeId;
    } else {
        return self.outlinePath;
    }
}

- (NSString*)headingForDisplay {
    return [self headingForDisplayWithHtmlLinks:NO];
}

- (NSString*)headingForDisplayWithHtmlLinks:(BOOL)withLinks {

    NSString *ret = [self heading];

    // File nodes (level 0) should just show their filename
    if ([[self indentLevel] intValue] == 0) {
        ret = [ret lastPathComponent];
    }

    // If the node is a link, show the title of the link
    if ([self isLink]) {
        NSRange link_location = [[self heading] rangeOfString:@"[["];
        NSString *link_text = [[self heading] substringFromIndex:link_location.location];
        NSRange last_location = [link_text rangeOfString:@"]]"];
        if (last_location.location != NSNotFound) {
            link_text = [link_text substringToIndex:last_location.location+last_location.length];
            ret = [[self heading] stringByReplacingOccurrencesOfString:link_text withString:[self linkTitle]];
        }
    }

    // Replace normal [[..][Title]] links with Title (or an actual link, based on withLinks)
    if (withLinks) {
        ret = [ret stringByReplacingOccurrencesOfRegex:@"\\[\\[(.+?)\\]\\[(.+?)\\]\\]" withString:@"<a href=\"$1\">$2</a>"];
    } else {
        ret = [ret stringByReplacingOccurrencesOfRegex:@"\\[\\[.+?\\]\\[(.+?)\\]\\]" withString:@"$1"];
    }

    // If the heading has <break> in it, just show the part before <break>
    NSRange break_range = [ret rangeOfString:@"<break>"];
    if (break_range.location != NSNotFound) {
        ret = [ret substringToIndex:break_range.location];
    }

    ret = [ret stringByReplacingOccurrencesOfRegex:@"<before>.*</before>" withString:@""];
    ret = [ret stringByReplacingOccurrencesOfRegex:@"<after>.*</after>" withString:@""];

    ret = [ret stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    return ret;
}

- (NSString*)beforeText {
    NSArray *ret = [self.heading captureComponentsMatchedByRegex:@"<before>(.*)</before>"];
    if ([ret count] > 0) {
        return [ret objectAtIndex:1];
    }
    return nil;
}

- (NSString*)afterText {
    NSArray *ret = [self.heading captureComponentsMatchedByRegex:@"<after>(.*)</after>"];
    if ([ret count] > 0) {
        return [ret objectAtIndex:1];
    }
    return nil;
}


- (NSString*)bodyForDisplay {
    NSString *summary = [self body];
    summary = [summary stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // Will this cause us problems if stuff comes from Windows with CRLF line endings?
    NSArray* lines = [summary componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    NSMutableArray* goodLines = [[NSMutableArray alloc] init];
    BOOL inDrawer = NO;
    for (NSString* line in lines) {
        if (!inDrawer && [line isMatchedByRegex:@"^\\s*:.+:\\s*$"] &&
            ![line isMatchedByRegex:@"^\\s*:END:\\s*$"]) {
            inDrawer = YES;
            continue;
        }
        else if ([line isMatchedByRegex:@"^\\s*:END:\\s*$"]) {
            inDrawer = NO;
            continue;  // We don't want the :END: line either.
        }

        if (! inDrawer) {
            [goodLines addObject:line];
        }
    }

    NSString *result = [goodLines componentsJoinedByString:@"\n"];
    [goodLines release];

    return result;
}

- (NSString*)completeTags {
    // This should aggregate the actual and inherited tags of this node.  This is used to determine
    // what the inherited tags will be, a child object calls completeTags on its parent for what to put
    // on the 'left hand side' of :a::b:
    //
    // The results should jsut be :a:b:c:d:

    NSString *ret = self.inheritedTags;
    if (!ret || [ret length] == 0) {
        return self.tags;
    }

    ret = [ret stringByAppendingString:self.tags];
    ret = [ret stringByReplacingOccurrencesOfString:@"::" withString:@":"];

    return ret;
}

- (NSString*)tagsForDisplay {
    // We want to display like this:
    // :no:inherited:tags:
    // :some:inherited:tags::and:some:locals
    // :just:inherited:tags::
    // :just:local:tags

    NSString *ret = self.inheritedTags;
    if (!ret || [ret length] == 0) {
        return self.tags;
    }

    if (!self.tags || [self.tags length] == 0) {
        ret = [ret stringByAppendingString:@":"];
    } else {
        ret = [ret stringByAppendingString:self.tags];
    }
    return ret;
}

- (bool)hasTag:(NSString*)tag {
    if (self.tags &&
        [self.tags length] > 0 &&
        [self.tags rangeOfString:[NSString stringWithFormat:@":%@:", tag]].location != NSNotFound) {
        return true;
    }
    return false;
}

- (bool)hasInheritedTag:(NSString*)tag {
    if (self.inheritedTags &&
        [self.inheritedTags length] > 0 &&
        [self.inheritedTags rangeOfString:[NSString stringWithFormat:@":%@:", tag]].location != NSNotFound) {
        return true;
    }
    return false;
}

- (void)toggleTag:(NSString*)tag {
    // Existing tags could be:
    // - ''
    // - ':a:'
    // - ':a:b:'
    if ([self hasTag:tag]) {
        [self removeTag:tag];
    } else {
        [self addTag:tag];
    }
}

- (void)addTag:(NSString*)tag {
    if (!self.tags || [self.tags length] == 0) {
        self.tags = [NSString stringWithFormat:@":%@:", tag];
    } else {
        self.tags = [self.tags stringByAppendingFormat:@"%@:", tag];
    }
}

- (void)removeTag:(NSString*)tag {
    // Remove :a: from the string, replace with :
    // If the string is just :, make it empty
    // If the string doesn't start with :, add it to the front
    // If the string doesn't end with :, add it to the end

    self.tags = [self.tags stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@":%@:", tag] withString:@":"];

    if ([self.tags length] == 1) {
        self.tags = @"";
    } else {
        if ([self.tags characterAtIndex:0] != ':') {
            self.tags = [NSString stringWithFormat:@":%@", self.tags];
        }

        if ([self.tags characterAtIndex:[self.tags length]-1] != ':') {
            self.tags = [self.tags stringByAppendingString:@":"];
        }
    }
}

- (NSArray*)sortedChildren {
    return [[[self children] allObjects] sortedArrayUsingSelector:@selector(sequenceIndexCompare:)];
}

// Possibilities:
// - file.org
// - other/file.org, where our file parent has no subdir/link
//   - RESULT: other/file.org
// - other/file.org, where our file parent has a subdir/link subdir/main.org
//   - RESULT: subdir/other/file.org
// - ../file.org, where our file parent has no subdir
//   - RESULT: Cannot resolve
// - ../file.org, where our file parent has a subdir/link as subdir/another/main.org
//   - RESULT: subdir/file.org
// - ../../file.org, where our file parent is subdir/another/main.org
//   - RESULT: file.org
- (NSString*)resolveLink:(NSString*)link {

    // See if the file node parent is in a subdir.  If it is, we have to use its path as the root
    NSString *root = @"";
    Node *node = self;
    while ([node parent]) {
        node = [node parent];
    }

    if (node != self || [[self indentLevel] intValue] == 0) {
        NSString *root_linkfile = [node heading];
        if ([root_linkfile rangeOfString:@"/"].location != NSNotFound) {
            root = [root_linkfile stringByReplacingOccurrencesOfString:[root_linkfile lastPathComponent] withString:@""];
        }
    }

    // Figure out how many levels we have to go up
    int upLevels = 0;
    while ([link rangeOfString:@"../"].location == 0) {
        upLevels++;
        link = [link substringFromIndex:3];
    }

    // Hack off path components from the root path for each upLevel
    for (int i = 0; i < upLevels; i++) {
        if ([root rangeOfString:@"/"].location == NSNotFound) {
            // ERROR: The link points to a path further up than our root, nothing we can do
            return nil;
        }
        root = [root stringByReplacingOccurrencesOfString:[root lastPathComponent] withString:@""];
        root = [root substringToIndex:[root length]-1];
    }

    link = [root stringByAppendingString:link];

    return link;
}

- (bool)isLink {
    NSRange linkRange = [[self heading] rangeOfRegex:kUnixFileLinkRegex];
    if (linkRange.location != NSNotFound) {
        return true;
    }
    return false;
}

// This will construct the link relative to the root of the file, sort of.  It isn't perfect yet.
- (NSString*)linkFile {
    NSArray *captures = [[self heading] captureComponentsMatchedByRegex:kUnixFileLinkRegex];
    if ([captures count] > 0) {
        return [self resolveLink:[captures objectAtIndex:1]];
    }
    return nil;
}

- (bool)isBrokenLink {
    if ([self isLink]) {
        return !NodeWithFilename([self linkFile]);
    }
    return false;
}

- (NSString*)linkTitle {
    NSRange link_location = [[self heading] rangeOfString:@"[[file:"];
    if (link_location.location != NSNotFound) {
        NSRange first_bracket_location = [[self heading] rangeOfString:@"]["];
        if (first_bracket_location.location != NSNotFound) {
            NSString *link_title = [[self heading] substringFromIndex:first_bracket_location.location+first_bracket_location.length];
            NSRange second_bracket_location = [link_title rangeOfString:@"]"];
            if (second_bracket_location.location != NSNotFound) {
                link_title = [link_title substringToIndex:second_bracket_location.location];
                return link_title;
            }
        }
    }
    return nil;
}

- (void)collectLinks:(NSMutableArray*)links {
    if ([self isLink]) {
        NSString *link = [self linkFile];
        if (![links containsObject:link]) {
            [links addObject:link];
        }
    }

    // Collect links from body text
    {
        NSArray *matches = [[self body] arrayOfCaptureComponentsMatchedByRegex:kUnixFileLinkRegex];
        for (NSArray *match in matches) {
            NSString *link = [self resolveLink:[match objectAtIndex:1]];
            if (link && [link length] > 1) {
                if (![links containsObject:link]) {
                    [links addObject:link];
                }
            }
        }
    }

    for (Node *child in [self children]) {
        [child collectLinks:links];
    }
}

- (NSString*)markupLine:(NSString*)line {
    // First, look for links of this form [[http://...][Title]]
    {
        line = [line stringByReplacingOccurrencesOfRegex:@"\\[\\[(https?:.+?)\\]\\[(.+?)\\]\\]" withString:@"<a href=\"$1\">$2</a>"];
    }

    // Then look for standalone links
    // Be careful not to turn the portion inside href="" from above into a link, so we force a space before the link.
    {
        NSString *regexString = @"(?<!'|\")(https?://[a-zA-Z0-9\\-.]+(?::(\\d+))?(?:(?:/[a-zA-Z0-9\\-._?,'+\\&%$=~*!():@#\\\\]*)+)?)";
        line = [line stringByReplacingOccurrencesOfRegex:regexString withString:@"<a href='$1'>$1</a>"];
    }

    // Any file: links that link to org files?
    {
      // FIXME: No Unix Filenames matched!
        NSString *regexString = @"\\[\\[file:([a-zA-Z0-9/\\-\\._]+\\.(?:org|txt))\\]\\[([a-zA-Z0-9/\\-_\\. '!?]+)\\]\\]";
        line = [line stringByReplacingOccurrencesOfRegex:regexString withString:@"<a href='orgfile:$1'>$2</a>"];
    }

    // Add strong for *text*
    {
        NSString *regexString = @"(?<=\\A|\\s|\\()\\*(\\w[\\w ]*)\\*(?=\\s|\\z|\\)|[\\.,:])";
        line = [line stringByReplacingOccurrencesOfRegex:regexString withString:@"<strong>$1</strong>"];
    }

    // Add em for /text/
    {
        NSString *regexString = @"(?<=\\A|\\s|\\()\\/(\\w[\\w ]*)\\/(?=\\s|\\z|\\)|[\\.,:])";
        line = [line stringByReplacingOccurrencesOfRegex:regexString withString:@"<em>$1</em>"];
    }

    // Add underline for _text_
    {
        NSString *regexString = @"(?<=\\A|\\s|\\()_(\\w[\\w ]*)_(?=\\s|\\z|\\)|[\\.,:])";
        line = [line stringByReplacingOccurrencesOfRegex:regexString withString:@"<span style='text-decoration: underline;'>$1</span>"];
    }

    // Add underline for _text_
    {
        NSString *regexString = @"(?<=\\A|\\s|\\()\\+(\\w[\\w ]*)\\+(?=\\s|\\z|\\)|[\\.,:])";
        line = [line stringByReplacingOccurrencesOfRegex:regexString withString:@"<span style='text-decoration: line-through;'>$1</span>"];
    }

    return line;
}

- (NSString*)htmlForDocumentViewLevel:(int)level {
    NSString *ret = @"";
    @try {
        NSString *title = [self headingForDisplayWithHtmlLinks:YES];
        if ([[self todoState] length] > 0) {
            if ([[Settings instance] isTodoState:[self todoState]]) {
                title = [NSString stringWithFormat:@"<span class='keyword-todo'>%@</span> %@", [self todoState], title];
            } else {
                title = [NSString stringWithFormat:@"<span class='keyword-done'>%@</span> %@", [self todoState], title];
            }
        }
        if ([[self tags] length] > 0) {
            title = [NSString stringWithFormat:@"%@<span class='tags'>%@</span>", title, [self tags]];
        }
        if (level == 0) {
            ret = [ret stringByAppendingString:@"<html><head><meta name='viewport' content='width=960, user-scalable=yes'><link rel='stylesheet' href='DocumentView.css' /><script type='text/javascript' src='DocumentView.js'></script></head><body>"];
            ret = [ret stringByAppendingFormat:@"<h1>%@</h1>", title];
        } else if (level == 1) {
            ret = [ret stringByAppendingFormat:@"<h2>%@</h2>", title];
        } else if (level == 2) {
            ret = [ret stringByAppendingFormat:@"<h3>%@</h3>", title];
        } else if (level == 3) {
            ret = [ret stringByAppendingFormat:@"<h4>%@</h4>", title];
        } else if (level == 4) {
            ret = [ret stringByAppendingFormat:@"<h5>%@</h5>", title];
        } else if (level == 5) {
            ret = [ret stringByAppendingFormat:@"<h6>%@</h6>", title];
        }

        if ([self body] && [[self body] length] > 0) {
            NSScanner *theScanner;
            theScanner = [NSScanner scannerWithString:[self body]];

            NSString *line;
            NSCharacterSet *eolSet;
            eolSet = [NSCharacterSet characterSetWithCharactersInString:@"\n"];

            [theScanner setCharactersToBeSkipped:eolSet];

            NSString *formatted_body = @"";

            bool was_pre = false;
            bool in_drawer = false;

            while ([theScanner isAtEnd] == NO) {
                if ([theScanner scanUpToCharactersFromSet:eolSet intoString:&line]) {

                    NSString *stripped_line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

                    if (stripped_line && [stripped_line length] > 0) {

                        if ([stripped_line length] > 2 && [stripped_line characterAtIndex:0] == ':' && [stripped_line characterAtIndex:[stripped_line length]-1] == ':') {
                            NSString *drawer_title = [stripped_line substringWithRange:NSMakeRange(1, [stripped_line length]-2)];
                            if (in_drawer) {
                                if ([drawer_title compare:@"END"] == NSOrderedSame) {
                                    in_drawer = false;
                                    formatted_body = [formatted_body stringByAppendingString:@"</div></div>"];
                                    continue;
                                }
                            } else {
                                // TODO: Make sure drawer_title isn't in a disallowed list
                                in_drawer = true;
                                NSString *drawerId = UUID();
                                formatted_body = [formatted_body stringByAppendingFormat:@"<div class='drawer'><span class='drawer-heading' onclick='toggleDrawer(\"%@\")'><span id='drawer-toggle-%@'>Show</span> %@</span>", drawerId, drawerId, drawer_title];
                                formatted_body = [formatted_body stringByAppendingFormat:@"<div style='display: none;' class='drawer-body' id='drawer-body-%@'>", drawerId];
                                continue;
                            }
                        }

                        if ([stripped_line characterAtIndex:0] == '#') { // It is a comment line, color it
                            if (was_pre)
                                formatted_body = [formatted_body stringByAppendingString:@"</pre>"];
                            formatted_body = [formatted_body stringByAppendingFormat:@"<span class='comment'>%@</span><br>", [self markupLine:stripped_line]];
                            continue;
                        } else if ([stripped_line characterAtIndex:0] == '|' || (!in_drawer && [stripped_line characterAtIndex:0] == ':')) { // Table or : entry
                            if (!was_pre)
                                formatted_body = [formatted_body stringByAppendingString:@"<pre>"];
                            if ([stripped_line characterAtIndex:0] == ':') {
                                if ([stripped_line length] >= 3) {
                                    // Trim off the part after ': ', make sure we dont overrun the string
                                    stripped_line = [stripped_line substringFromIndex:2];
                                } else {
                                    stripped_line = @"";
                                }
                            }
                            formatted_body = [formatted_body stringByAppendingString:[self markupLine:stripped_line]];
                            formatted_body = [formatted_body stringByAppendingString:@"\n"];
                            was_pre = true;
                            continue;
                        }
                    }

                    if (was_pre) {
                        formatted_body = [formatted_body stringByAppendingString:@"</pre>"];
                        was_pre = false;
                    }
                    line = [self markupLine:line];

                    if (!stripped_line || [stripped_line length] == 0) {
                        formatted_body = [formatted_body stringByAppendingString:@"<p>"];
                    } else {
                        formatted_body = [formatted_body stringByAppendingString:line];
                        formatted_body = [formatted_body stringByAppendingString:@"<br>"];
                    }
                }
            }

            if (was_pre)
                formatted_body = [formatted_body stringByAppendingString:@"</pre>"];

            ret = [ret stringByAppendingString:formatted_body];
        }

        if ([self isLink]) {
            // TODO: If we want document view to traverse links, we'd do it here
        } else {
            for (Node *child in [self sortedChildren]) {
                ret = [ret stringByAppendingString:[child htmlForDocumentViewLevel:level+1]];
            }
        }

        if (level == 0) {
            ret = [ret stringByAppendingString:@"</body></html>"];
        }
    } @catch (NSException *e) {
        ret = @"Error generating HTML for this node";
    }
    return ret;
}

- (NSString*)ownerFile {
    Node *node = self;
    while ([node parent]) {
        node = [node parent];
    }

    if ([[node indentLevel] intValue] == 0) {
        return [node heading];
    }

    return nil;
}

- (NSString*)bestDoneState {
    NSString *ret = @"DONE";

    // Default to the first DONE entry in the first todo state group
    NSArray *todoStateGroup = [[[Settings instance] todoStateGroups] objectAtIndex:0];
    if (todoStateGroup && [todoStateGroup count] > 1) {
        if ([[todoStateGroup objectAtIndex:1] count] > 0) {
            ret = [[todoStateGroup objectAtIndex:1] objectAtIndex:0];
        }
    }

    // But prefer to use the first DONE entry in the todo state group that owns the current todostate
    for (NSArray *todoStateGroup in [[Settings instance] todoStateGroups]) {
        if ([todoStateGroup count] > 1) {
            if ([[todoStateGroup objectAtIndex:0] containsObject:self.todoState] || [[todoStateGroup objectAtIndex:1] containsObject:self.todoState]) {
                if ([[todoStateGroup objectAtIndex:1] count] > 0) {
                    ret = [[todoStateGroup objectAtIndex:1] objectAtIndex:0];
                    break;
                }
            }
        }
    }

    return ret;
}

// MARK: Scheduled & Deadline

- (NSString *)scheduled {
    NSString *bodyWithoutDrawer = [self bodyForDisplay];
    NSArray *components = [bodyWithoutDrawer captureComponentsMatchedByRegex:@"SCHEDULED: <(\\d+-\\d+-\\d+ \\S+(.)*)>"];
    if ([components count] > 0) {
        return [components objectAtIndex:1];
    }
    return nil;
}

- (NSDate *)scheduledDate {
    if (self.scheduled.length == 0 ) { return nil; }
    return [self detectedDateInString:self.scheduled];
}

- (NSString *)deadline {
    NSString *bodyWithoutDrawer = [self bodyForDisplay];
    NSArray *components = [bodyWithoutDrawer captureComponentsMatchedByRegex:@"DEADLINE: <(\\d+-\\d+-\\d+ \\S+)>"];
    if ([components count] > 0) {
        return [components objectAtIndex:1];
    }
    return nil;
}

- (NSDate *)deadlineDate {
    if (self.deadline.length == 0 ) { return nil; }
    return [self detectedDateInString:self.deadline];
}

- (NSDate *)detectedDateInString:(NSString *)string {
    // FIXME: allocate the detector only once and reuse to improve performance
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:(NSTextCheckingTypeDate) error:nil];
    NSArray *matches = [detector matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    for (NSTextCheckingResult *match in matches) {
         if ([match resultType] == NSTextCheckingTypeDate) {
             return [match date];
         }
    }
    return nil;
}

@end
