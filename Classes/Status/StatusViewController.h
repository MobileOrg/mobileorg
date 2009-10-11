//
//  StatusViewController.h
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

#import <UIKit/UIKit.h>


@interface StatusViewController : UIViewController {
    UIView *statusView;
    UILabel *activityLabel;
    UILabel *actionLabel;
    UIProgressView *progressBar;
    UIButton *abortButton;
    UIDeviceOrientation lastOrientation;
}

@property (nonatomic, readonly) UILabel *activityLabel;
@property (nonatomic, readonly) UILabel *actionLabel;
@property (nonatomic, readonly) UIButton *abortButton;
@property (nonatomic, readonly) UIProgressView *progressBar;

@property (nonatomic, copy) NSString *activityMessage;
@property (nonatomic, copy) NSString *actionMessage;

+ (StatusViewController*)instance;
- (void)show;
- (void)hide;

@end
