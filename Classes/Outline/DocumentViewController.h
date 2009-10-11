//
//  DocumentViewController.h
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

#import <UIKit/UIKit.h>

@class Node;

@interface DocumentViewController : UIViewController <UIWebViewDelegate> {
    UIWebView *webView;
    Node *node;
    int level;
    NSTimer *timer;
    int scrollTo;
}

@property (nonatomic, retain) UIWebView *webView;
@property (nonatomic, retain) Node *node;
@property (nonatomic) int level;
@property (nonatomic) int scrollTo;

- (void)restore:(NSArray*)outlineStates;

@end
