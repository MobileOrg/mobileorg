//
//  OrgFileParser.m
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

#import "OrgFileParser.h"
#import "Node.h"
#import "GlobalUtils.h"
#import "DataUtils.h"
#import "Settings.h"
#import "RegexKitLite.h"

@implementation OrgFileParser

@synthesize delegate;
@synthesize completionSelector;
@synthesize orgFilename;
@synthesize localFilename;
@synthesize errorStr;

- (void)parse {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSError *error = nil;
    NSString *entireFile;
    Node *fileNode;
    NSMutableArray *nodeStack;
    NSManagedObjectContext *managedObjectContext;

    managedObjectContext = [AppInstance() managedObjectContext];

    // Setup a level-0 node for this Org-file
    fileNode = (Node*)[NSEntityDescription insertNewObjectForEntityForName:@"Node" inManagedObjectContext:managedObjectContext];
    [fileNode setHeading:orgFilename];
    [fileNode setIndentLevel:[NSNumber numberWithInt:0]];
    [fileNode setSequenceIndex:0];
    [fileNode setReadOnly:[NSNumber numberWithBool:true]];

    if (![managedObjectContext save:&error]) {
        // TODO: Error
    }

    // If this is the index node, we have to do a couple things special
    bool isIndex = false;
    if ([self.orgFilename isEqualToString:[[Settings instance] indexFilename]]) {
        isIndex = true;
        [[Settings instance] resetPrimaryTagsAndTodoStates];
    }

    // Read the entire file into memory (perhaps one day we'll do this line by line somehow?)
    entireFile = ReadPossiblyEncryptedFile(localFilename, &errorStr);
    if (errorStr) {
        entireFile = [NSString stringWithFormat:@"* Error: %@\n", errorStr];
    } else if (!entireFile) {
        entireFile = @"* Bad file encoding\n  Unable to detect file encoding, please re-save this file using UTF-8.";
        errorStr = @"Unknown encoding, re-save file as UTF-8";
    }

    // Maintain a stack of nodes for parenting use
    nodeStack = [[NSMutableArray alloc] init];

    // Add the fileNode as the first parent
    [nodeStack addObject:fileNode];

    // Parse file
    {
        NSArray *lines;
        NSString *line;
        NSMutableString *bodyBuffer = [[NSMutableString alloc] init];
        int lastNumStars = 0;
        Node *lastNode = nil;
        int sequenceIndex = 1;
        bool readOnlyFile = false;
        bool addedDefaultTodoStates = false;

        lines = [entireFile componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n"]];

        // Until we hit the end of the file
        for (int i = 0; i < [lines count]; i++) {

            if ([[NSThread currentThread] isCancelled]) {
                // TODO: Add support for cancellation
                // [self setResult:OrgFileParseResultCancelled];
                break;
            }

            line = [lines objectAtIndex:i];

            // Determine how many stars this heading has, if it is indeed a heading
            int numStars = 0;

            if ([line length] > 0) {
                while (numStars < [line length] && [line characterAtIndex:numStars] == '*') {
                    numStars++;
                }

                // Oops, it wasn't really a headling, there has to be a space following the last star!
                if (numStars >= [line length] || [line characterAtIndex:numStars] != ' ') {
                    numStars = 0;
                }
            }

            // Parse todo State keywords
            // There may be multiple liens of them!
            // Also handle:   | WORD or | WORD, ie, no todo or no done keywords
            //
            // So we store these as todoStateGroups in Settings.
            // They are composed as follows:
            //
            // todoStateGroups = {
            //   group1 = {
            //       todo = {
            //         TODO,
            //         WAITING
            //       },
            //       done = {
            //         DONE,
            //         CANCELED
            //       }
            //     },
            //   group2 = {
            //     ...
            //     },
            // }
            if (isIndex && [[[nodeStack lastObject] indentLevel] intValue] == 0) {
                NSRange keywordRange = [line rangeOfString:@"#+TODO: "];
                if (keywordRange.location != NSNotFound) {

                    // Get rid of any (t), (d), etc type shortcuts
                    line = [line stringByReplacingOccurrencesOfRegex:@"\\(\\w\\)" withString:@""];

                    // CLEANUP: This regex is a hack
                    NSArray *splitArray = [line captureComponentsMatchedByRegex:@"#\\+TODO:\\s+([\\s\\w-]*)(\\| ([\\s\\w-]*))*"];
                    if ([splitArray count] > 0) {

                        NSString *todoWords = [[splitArray objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                        NSString *doneWords = [[splitArray objectAtIndex:3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

                        // Add a new todoStateGroup
                        NSMutableArray *todoStateGroup = [NSMutableArray new];

                        // Add 2 sub arrays to it, one full of keywords for todo, the other are done keywords
                        NSMutableArray *todoStates = [NSMutableArray new];
                        NSMutableArray *doneStates = [NSMutableArray new];

                        [todoStateGroup addObject:todoStates];
                        [todoStateGroup addObject:doneStates];

                        if ([todoWords length] > 0) {
                            for (NSString *state in [todoWords componentsSeparatedByRegex:@"\\s"]) {
                                if ([state length] > 0) {
                                    [todoStates addObject:state];
                                }
                            }
                        }

                        if ([doneWords length] > 0) {
                            for (NSString *state in [doneWords componentsSeparatedByRegex:@"\\s"]) {
                                if ([state length] > 0) {
                                    [doneStates addObject:state];
                                }
                            }
                        }

                        // Add the group to the Settings instance using
                        [[Settings instance] addTodoStateGroup:todoStateGroup];

                        [todoStates release];
                        [doneStates release];
                        [todoStateGroup release];
                    }
                }
            }

            // Check for TAGS line, which is the primary index file's way to let us know which
            // tags are 'most important'.
            //
            // It may also have mutually exclusive tags, like a b { c d e } f, where only one of
            // c, d, or e may be present on a given node.
            if (isIndex && [[[nodeStack lastObject] indentLevel] intValue] == 0) {

                // Get rid of any (t), (d), etc type shortcuts
                line = [line stringByReplacingOccurrencesOfRegex:@"\\(\\w\\)" withString:@""];

                NSArray *matches = [line captureComponentsMatchedByRegex:@"^#\\+TAGS:\\s(.+)"];
                if ([matches count] > 0) {
                    NSString *tags = [NSString stringWithString:[matches objectAtIndex:1]];

                    // Remove the { } markers for mutex stuff, we'll worry about that later
                    tags = [tags stringByReplacingOccurrencesOfString:@"{ " withString:@" "];
                    tags = [tags stringByReplacingOccurrencesOfString:@" }" withString:@" "];

                    // Safe to assume that the tag list is like ":a:b:c:"
                    if ([tags characterAtIndex:0] == ':') {
                        // Nothing to do
                    } else {
                        // Otherwise, it may be like "a b c"
                        tags = [tags stringByReplacingOccurrencesOfString:@" " withString:@":"];
                        tags = [NSString stringWithFormat:@":%@:", tags];
                    }

                    // Tell the settings store about any potentially new tags
                    {
                        NSArray *tagArray = [tags componentsSeparatedByString:@":"];
                        for (NSString *tag in tagArray) {
                            [[Settings instance] addPrimaryTag:tag];
                        }
                    }

                    tags = [NSString stringWithString:[matches objectAtIndex:1]];
                    if ([tags rangeOfString:@"{"].location != NSNotFound) {
                        // Handle mutex stuff
                        // { A B C } { D E } F { G H } I { J }
                        NSArray *captures = [tags arrayOfCaptureComponentsMatchedByRegex:@"\\{ (.+?) \\}"];
                        for (NSArray *capture in captures) {
                            NSArray *mutexTags = [[capture objectAtIndex:1] componentsSeparatedByString:@" "];
                            [[Settings instance] addMutuallyExclusiveTagGroup:mutexTags];
                        }
                    }
                }
            }


            // Handle #+ALLPRIORITIES
            if (isIndex && [[[nodeStack lastObject] indentLevel] intValue] == 0) {
                NSArray *matches = [line captureComponentsMatchedByRegex:@"^#\\+ALLPRIORITIES:\\s(.+)"];
                if ([matches count] > 0) {
                    NSArray *priorities = [[matches objectAtIndex:1] componentsSeparatedByString:@" "];
                    for (NSString *priority in priorities) {
                        if ([priority length] > 0) {
                            [[Settings instance] addPriority:priority];
                        }
                    }
                }
            }

            // Check for FILETAGS lines, add those tags to the file node
            if ([[[nodeStack lastObject] indentLevel] intValue] == 0) {

                // Get rid of any (t), (d), etc type shortcuts
                line = [line stringByReplacingOccurrencesOfRegex:@"\\(\\w\\)" withString:@""];

                NSArray *matches = [line captureComponentsMatchedByRegex:@"^#\\+FILETAGS:\\s(.+)"];
                if ([matches count] > 0) {
                    NSString *tags = [matches objectAtIndex:1];
                    // Safe to assume that the tag list is like ":a:b:c:"
                    if ([tags characterAtIndex:0] == ':') {
                        // Nothing to do
                    } else {
                        // Otherwise, it may be like "a b c"
                        tags = [tags stringByReplacingOccurrencesOfString:@" " withString:@":"];
                        tags = [NSString stringWithFormat:@":%@:", tags];
                    }

                    [[nodeStack lastObject] setTags:tags];

                    // Tell the settings store about any potentially new tags
                    {
                        NSArray *tagArray = [tags componentsSeparatedByString:@":"];
                        for (NSString *element in tagArray) {
                            if (element && [element length] > 0) {
                                [[Settings instance] addTag:element];
                            }
                        }
                    }
                }
            }

            // Check for #+READONLY
            if ([[[nodeStack lastObject] indentLevel] intValue] == 0) {
                if ([line rangeOfString:@"#+READONLY"].location == 0) {
                    readOnlyFile = true;
                }
            }

            // Handle headings
            if (numStars > 0) {

                if (isIndex && !addedDefaultTodoStates) {
                    NSMutableArray *todoStateGroup = [NSMutableArray arrayWithCapacity:2];
                    [todoStateGroup addObject:[NSMutableArray arrayWithCapacity:0]];
                    [todoStateGroup addObject:[NSMutableArray arrayWithObject:@"DONEARCHIVE"]];
                    [[Settings instance] addTodoStateGroup:todoStateGroup];
                    addedDefaultTodoStates = true;
                }

                // The title is * THIS PART
                NSString *title = [[line substringFromIndex:(numStars+1)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

                // If this heading has fewer stars than the its parent, pop nodes off
                // of the nodeStack until we hit this level
                while (lastNumStars > numStars && [nodeStack count] > 0) {
                    if ([[[nodeStack lastObject] indentLevel] intValue] == lastNumStars) {
                        [nodeStack removeLastObject];
                    }
                    lastNumStars--;
                }

                // If the last heading was
                if (lastNumStars == numStars && [nodeStack count] > 0) {
                    [nodeStack removeLastObject];
                }

                // Maintain the indent level of this heading so we can see if the next heading is
                // the same level or not
                lastNumStars = numStars;

                // Increment sequence index, which helps us define the order of children
                sequenceIndex++;

                // Extract the keyword from the title, if it exists
                NSString *todoState = @"";
                NSRange spaceRange = [title rangeOfString:@" "];
                if (spaceRange.location != NSNotFound) {
                    // Make sure the title is longer than just a keyword
                    if ([title length] > spaceRange.location+1) {
                        NSString *firstWord = [title substringToIndex:spaceRange.location];
                        if ([[Settings instance] isTodoState:firstWord] ||
                            [[Settings instance] isDoneState:firstWord]) {
                            title = [title substringFromIndex:spaceRange.location+1];
                            todoState = firstWord;
                        }
                    }
                }

                // Extract priority from the title, if it exists
                NSString *priority = @"";
                NSArray *priorityCaptures = [title captureComponentsMatchedByRegex:@"\\[#([a-zA-Z0-9])\\] (.+)"];
                if ([priorityCaptures count] > 0) {
                    if ([[Settings instance] isPriority:[priorityCaptures objectAtIndex:1]]) {
                        priority = [priorityCaptures objectAtIndex:1];
                        title = [priorityCaptures objectAtIndex:2];
                    }
                }

                // Extract tags from the title, if they exist
                NSString *tags = @"";
                static NSString *tagRegExp = @"(.+?)[ \\s]+(:([@\\w\\.]+:)+)[ \\s]*$";
                NSArray *splitTagTitleArray = [title captureComponentsMatchedByRegex:tagRegExp];
                if ([splitTagTitleArray count] >= 2) {
                    title = [splitTagTitleArray objectAtIndex:1];
                    tags = [splitTagTitleArray objectAtIndex:2];

                    // Tell the settings store about any potentially new tags
                    {
                        NSArray *tagArray = [tags componentsSeparatedByString:@":"];
                        for (NSString *element in tagArray) {
                            if (element && [element length] > 0) {
                                [[Settings instance] addTag:element];
                            }
                        }
                    }
                }

                // Determine the inherited tags
                NSString *inheritedTags = [[nodeStack lastObject] completeTags];

                // Create the node's outline path
                //
                // [[olp:path/to/file%3aa.org:grandparent a%2fb/%5b#A%5d parent/heading][heading]]
                //
                // where parent had a priority cookie [#A] in the headline and you have escaped
                // the brackets with hex representations.  The grandparent heading contained
                // a/b, and the slash is transformed as well.  The file name was file:a.org, and we
                // have escaped the colon.
                //
                NSString *outlinePath = [NSString stringWithFormat:@"olp:%@:", EscapeStringForOutlinePath(orgFilename)];
                bool first = true;
                for (Node *node in nodeStack) {
                    if (first) {
                        // Skip the first node, it is the file node, which we already accounted for
                        // in the initialization of outlinePath above
                        first = false;
                        continue;
                    }
                    // Add a / between components, but not if it is the first one
                    if ([outlinePath characterAtIndex:[outlinePath length]-1] != ':') {
                        outlinePath = [outlinePath stringByAppendingString:@"/"];
                    }
                    outlinePath = [outlinePath stringByAppendingString:EscapeStringForOutlinePath([node heading])];
                }

                // Finally, add our own heading to the outline path
                if ([outlinePath characterAtIndex:[outlinePath length]-1] != ':') {
                    outlinePath = [outlinePath stringByAppendingString:@"/"];
                }
                outlinePath = [outlinePath stringByAppendingString:EscapeStringForOutlinePath(title)];

                // Create the node for this entry
                Node *node = (Node*)[NSEntityDescription insertNewObjectForEntityForName:@"Node" inManagedObjectContext:managedObjectContext];
                [node setHeading:title];
                [node setIndentLevel:[NSNumber numberWithInt:numStars]];
                [node setSequenceIndex:[NSNumber numberWithInt:sequenceIndex]];
                [node setOutlinePath:outlinePath];
                [node setTodoState:todoState];
                [node setInheritedTags:inheritedTags];
                [node setTags:tags];
                [node setPriority:priority];
                [node setReadOnly:[NSNumber numberWithBool:readOnlyFile]];
                [[nodeStack lastObject] addChildrenObject:node];

                // Push this node onto the nodeStack
                [nodeStack addObject:node];

                // For some reason when we parse biggish files, the app will behave strangly, as if we are overloading
                // it with too many changed entities.  If we called this every iteration, it would be very slow.
                // So a happy medium seems to be around 200..
                if ((sequenceIndex % 200) == 0)
                    [managedObjectContext processPendingChanges];

                // Hold onto the last used node, so we can attach body text to it
                lastNode = node;
            }

            // This handles lines that are children of a node but not headlines, thus body text.
            if (numStars == 0 && lastNode) {

                // Extract IDs
                NSRange idRange = [line rangeOfString:@":ID: "];
                if (idRange.location != NSNotFound) {
                    NSString *nodeId = [line substringFromIndex:(idRange.location+idRange.length)];
                    nodeId = [nodeId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    [lastNode setNodeId:nodeId];
                } else {
                    NSRange originalIdRange = [line rangeOfString:@":ORIGINAL_ID: "];
                    if (originalIdRange.location != NSNotFound) {
                        NSString *nodeId = [line substringFromIndex:originalIdRange.location+originalIdRange.length];
                        nodeId = [nodeId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        [lastNode setReferencedNodeId:nodeId];
                        [lastNode setReadOnly:[NSNumber numberWithBool:false]];
                    }
                }

                // Append it to the existing node body, if any
                if ([lastNode body] && [[lastNode body] length] > 0) {

                    [bodyBuffer deleteCharactersInRange:NSMakeRange(0, [bodyBuffer length])];
                    [bodyBuffer appendString:[lastNode body]];
                    [bodyBuffer appendString:@"\n"];

                    if ([line length] > 0) {
                        [bodyBuffer appendString:line];
                    }

                    [lastNode setBody:[NSString stringWithString:bodyBuffer]];

                } else {

                    if ([line length] > 0) {
                        [lastNode setBody:line];
                    } else {
                        [lastNode setBody:@""];
                    }
                }
            }
        }

        [bodyBuffer release];
    }

    // TODO: When we go back to doing the processing on another thread, we'll need this
    //[delegate performSelectorOnMainThread:completionSelector withObject:nil waitUntilDone:NO];

    // For now, just make the call the normal way
    [delegate performSelector:completionSelector withObject:nil];

    [nodeStack release];
    [pool release];
}

- (void)dealloc {
    [errorStr release];
    [orgFilename release];
    [localFilename release];
    [super dealloc];
}

@end
