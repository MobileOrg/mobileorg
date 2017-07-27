//
//  RoundedLabel.m
//  MobileOrg
//
//  Created by Richard Moreland on 9/19/09.
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

#import "RoundedLabel.h"

@implementation RoundedLabel

@synthesize color;

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        label      = [[[UILabel alloc] init] autorelease];
        label.font = [UIFont boldSystemFontOfSize:10.0];
        label.textColor = [UIColor whiteColor];
        label.backgroundColor = [UIColor colorWithRed:0.52 green:0 blue:0 alpha:1];
        [self addSubview:label];

        [self setColor:[UIColor blueColor]];
        [self setBackgroundColor:[UIColor whiteColor]];
    }
    return self;
}

void CGContextAddRoundRect(CGContextRef context, CGRect rect, float radius)
{
    CGContextMoveToPoint(context, rect.origin.x, rect.origin.y + radius);
    CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y + rect.size.height - radius);
    CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + rect.size.height - radius,
                    radius, M_PI / 4, M_PI / 2, 1);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width - radius,
                            rect.origin.y + rect.size.height);
    CGContextAddArc(context, rect.origin.x + rect.size.width - radius,
                    rect.origin.y + rect.size.height - radius, radius, M_PI / 2, 0.0f, 1);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y + radius);
    CGContextAddArc(context, rect.origin.x + rect.size.width - radius, rect.origin.y + radius,
                    radius, 0.0f, -M_PI / 2, 1);
    CGContextAddLineToPoint(context, rect.origin.x + radius, rect.origin.y);
    CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + radius, radius,
                    -M_PI / 2, M_PI, 1);
}

- (void)drawRect:(CGRect)rect {
    if ([[self text] length] > 0) {
        [label setBackgroundColor:color];
        CGContextRef c = UIGraphicsGetCurrentContext();
        if (c != nil)  {
            [color set];
            CGContextAddRoundRect(c, pillRect, 5);
            CGContextFillPath(c);
        }
    }
}

- (NSString*)text {
    return [label text];
}

- (void)setText:(NSString *)text {
    [label setText:text];

    // CGSize textSize = CGSizeMake(self.bounds.size.width, 1979);
    CGSize maximumLabelSize = CGSizeMake(self.frame.size.width, FLT_MAX);
    CGSize size = [text boundingRectWithSize:maximumLabelSize
                                options:NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin
                                  attributes:nil context:nil].size;
//    CGSize size = [text sizeWithFont:[label font]
//                   constrainedToSize:textSize
//                       lineBreakMode:NSLineBreakByWordWrapping];

    CGRect bounds = self.bounds;
    bounds.size = size;

    [label setFrame:CGRectMake(2, 2, size.width, size.height)];

    pillRect.origin = self.bounds.origin;
    pillRect.size.height = size.height + 4;
    pillRect.size.width = size.width + 4;
}

- (void)dealloc {
    [super dealloc];
}

@end
