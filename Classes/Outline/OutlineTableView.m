//
//  OutlineTableView.m
//  MobileOrg
//
//  Created by Richard Moreland on 10/10/09.
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

#import "OutlineTableView.h"
#import "OutlineViewController.h"

#define MAX_TOUCH_AND_HOLD_DELTA 3

@implementation OutlineTableView

@synthesize controller;

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (timer) {
        [timer invalidate];
        [timer release];
        timer = nil;
    }

    NSSet *alltouches = [event allTouches];

    if ([alltouches count] == 1) {
        UITouch *touch = [touches anyObject];
        isInTouch = NO;
        myStartTouchPosition = [touch locationInView:self];

        timer = [[NSTimer scheduledTimerWithTimeInterval: 0.3
                                                  target: self
                                                selector: @selector(timerFired:)
                                                userInfo: nil
                                                 repeats: NO] retain];
    }

    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    CGPoint currentTouchPosition = [touch locationInView:self];

    // If the swipe tracks correctly.
    double diffx = myStartTouchPosition.x - currentTouchPosition.x + 0.1; // adding 0.1 to avoid division by zero
    double diffy = myStartTouchPosition.y - currentTouchPosition.y + 0.1; // adding 0.1 to avoid division by zero

    if(abs(diffx) > MAX_TOUCH_AND_HOLD_DELTA || abs(diffy) > MAX_TOUCH_AND_HOLD_DELTA)
    {
        if (timer) {
            [timer invalidate];
            [timer release];
            timer = nil;
        }
    }

    [super touchesMoved:touches    withEvent:event];
}

- (void)timerFired:(NSTimer *)aTimer {
    isInTouch = YES;
    NSIndexPath *indexPathAtHitPoint = [self indexPathForRowAtPoint:myStartTouchPosition];
    if (indexPathAtHitPoint) {
        [controller delayedOneFingerTouch:indexPathAtHitPoint];
        return;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (timer) {
        [timer invalidate];
        [timer release];
        timer = nil;
    }

    if (isInTouch) {
        isInTouch = NO;
        [super touchesEnded:nil withEvent:nil];
        return;
    }

    [super touchesEnded:touches withEvent:event];
}

- (void)dealloc {
    [timer release];
    [controller release];
    [super dealloc];
}

@end
