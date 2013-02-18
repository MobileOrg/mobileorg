//
//  DocumentViewController.m
//  MobileOrg
//
//  Created by Richard Moreland on 10/6/09.
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

#import "DocumentViewController.h"
#import "Node.h"
#import "DataUtils.h"
#import "OutlineState.h"
#import "SessionManager.h"

@implementation DocumentViewController

@synthesize webView;
@synthesize node;
@synthesize level;
@synthesize scrollTo;

- (void)restore:(NSArray*)outlineStates {

    if ([outlineStates count] > 0) {

        OutlineState *thisState = [OutlineState fromDictionary:[outlineStates objectAtIndex:0]];
        NSArray *newStates = [outlineStates subarrayWithRange:NSMakeRange(1, [outlineStates count]-1)];

        switch (thisState.selectionType) {
            case OutlineSelectionTypeDocumentView:
            {
                DocumentViewController *controller = [[DocumentViewController alloc] initWithNibName:nil bundle:nil];
                [controller setNode:node];
                [controller setScrollTo:thisState.scrollPositionY];
                [self.navigationController pushViewController:controller animated:NO];
                [controller restore:newStates];
                [controller release];
                break;
            }
        }
    }
}

// On view will appear, start this
// On disappear, stop it
// On timer fire, update the top of the stack's scroll position
- (void)onTimer:(NSTimer*)timer {
    OutlineState *topState = [[SessionManager instance] topOutlineState];
    topState.scrollPositionY = [[webView stringByEvaluatingJavaScriptFromString: @"scrollY"] intValue];
    [[SessionManager instance] replaceTopOutlineState:topState];
}

- (void)loadView {

    [self setTitle:[node headingForDisplay]];

    webView = [[UIWebView alloc] init];
    webView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;

    timer = nil;

    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *url = [NSURL fileURLWithPath:path];

    Node *content_node = node;
    if ([node isLink]) {
        content_node = NodeWithFilename([node linkFile]);
        if (!content_node) {
            content_node = node;
        }
    }

    [webView loadHTMLString:[content_node htmlForDocumentViewLevel:0] baseURL:url];
    [webView setScalesPageToFit:YES];
    [webView setDelegate:self];
    [webView setDataDetectorTypes:UIDataDetectorTypeNone];
    [self setView:webView];
}

- (DocumentViewController*)pushOrgFile:(NSString*)fileName withAnimation:(bool)animation {

    Node *nextNode = NodeWithFilename(fileName);

    if (nextNode) {

        OutlineState *state = [[OutlineState new] autorelease];
        state.selectedLink = fileName;
        state.selectionType = OutlineSelectionTypeDocumentView;
        [[SessionManager instance] pushOutlineState:state];

        DocumentViewController *newController = [[[DocumentViewController alloc] initWithNibName:nil bundle:nil] autorelease];
        [newController setNode:nextNode];
        [self.navigationController pushViewController:newController animated:animation];

        return newController;
    }

    return nil;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {

    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        if ([[[request URL] scheme] compare:@"orgfile"] == NSOrderedSame) {
            // Push a new doc view controller, and find the org file for this file
            NSString *resolved_link = [node resolveLink:[[request URL] resourceSpecifier]];
            if (resolved_link && [self pushOrgFile:resolved_link withAnimation:true]) {
                //NSLog(@"open org file %@\n", [[request URL] resourceSpecifier]);
            } else {
                //NSLog(@"could not open org file %@\n", [[request URL] resourceSpecifier]);
            }
            return NO;
        } else {
            [[UIApplication sharedApplication] openURL:[request URL]];
            //if (![[UIApplication sharedApplication] openURL:[request URL]])
            //    NSLog(@"%@%@",@"Failed to open url:",[[request URL] description]);
            return NO;
        }
    }
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView {

    // Check if we need to scroll this somewhere.
    if (scrollTo != 0) {

        // Scroll to the position.
        [webView stringByEvaluatingJavaScriptFromString:
         [NSString stringWithFormat: @"window.scrollTo(0, %d);",
          scrollTo]];

        scrollTo = 0;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    // Update the view with current data before it is displayed.
    [super viewWillAppear:animated];

    // Get rid of anything else in the stored tree that has level > ours
    [[SessionManager instance] popOutlineStateToLevel:[self.navigationController.viewControllers indexOfObject:self]];

    timer = [[NSTimer scheduledTimerWithTimeInterval: 1.0
                                              target: self
                                            selector: @selector(onTimer:)
                                            userInfo: nil
                                             repeats: YES] retain];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [timer invalidate];
    [timer release];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;

    [webView release];
}

- (void)dealloc {
    [node release];
    [webView release];
    [super dealloc];
}

@end
