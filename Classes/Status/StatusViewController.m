//
//  StatusViewController.m
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

#import "StatusViewController.h"
#import "GlobalUtils.h"
#import "MobileOrg-Swift.h"

static StatusViewController *gInstance = NULL;

@implementation StatusViewController

+ (StatusViewController*)instance {
    @synchronized(self) {
        if (gInstance == NULL)
            gInstance = [[self alloc] init];
    }
    return gInstance;
}

- (void)show {
    if (![[self view] superview]) {
        [[AppInstance() window] addSubview:self.view];
        [[AppInstance() window] bringSubviewToFront:self.view];
    }
}

- (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[self view] superview]) {
            [self.view removeFromSuperview];
        }
    });
}

- (void)handleRotate {
    if ([[UIDevice currentDevice] orientation] == lastOrientation) {
        return;
    }

    switch ([[UIDevice currentDevice] orientation]) {
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationUnknown:
            return;
        case UIDeviceOrientationPortraitUpsideDown:
            [self.view setTransform:CGAffineTransformMakeRotation(M_PI)];
            [self.view setFrame:[[UIScreen mainScreen] bounds]];
            statusView.center = CGPointMake(self.view.frame.size.width/2, self.view.frame.size.height/2);
            break;
        case UIDeviceOrientationLandscapeLeft:
            [self.view setTransform:CGAffineTransformMakeRotation(M_PI/2)];
            [self.view setFrame:[[UIScreen mainScreen] bounds]];
            statusView.center = CGPointMake(self.view.frame.size.height/2, self.view.frame.size.width/2+20);
            break;
        case UIDeviceOrientationLandscapeRight:
            [self.view setTransform:CGAffineTransformMakeRotation(-M_PI/2)];
            [self.view setFrame:[[UIScreen mainScreen] bounds]];
            statusView.center = CGPointMake(self.view.frame.size.height/2, self.view.frame.size.width/2+20);
            break;
        case UIDeviceOrientationPortrait:
        default:
            [self.view setTransform:CGAffineTransformMakeRotation(0)];
            [self.view setFrame:[[UIScreen mainScreen] bounds]];
            statusView.center = CGPointMake(self.view.frame.size.width/2, self.view.frame.size.height/2);
            break;
    }

    lastOrientation = [[UIDevice currentDevice] orientation];
}

- (void)didRotate:(NSNotification *)notification {
    [self handleRotate];
}

- (void)loadView {
    [super loadView];

    lastOrientation = UIDeviceOrientationPortrait;

    self.view.backgroundColor = [UIColor mo_lightLightGrayColor];

    statusView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 220)];
    statusView.center = CGPointMake(self.view.frame.size.width/2, self.view.frame.size.height/2);

    [statusView addSubview:self.actionLabel];
    [statusView addSubview:self.activityLabel];
    [statusView addSubview:self.progressBar];
    // TODO: When we add abort back in, add this
    // [statusView addSubview:self.abortButton];

    [[self view] addSubview:statusView];

    [self handleRotate];
}

- (UILabel *)activityLabel {
    if (activityLabel == nil) {
        activityLabel = [[UILabel alloc] initWithFrame:CGRectMake(-50, 0, 300, 40)];
        activityLabel.textAlignment = NSTextAlignmentCenter;
        activityLabel.font = [UIFont boldSystemFontOfSize:20.0];
        activityLabel.textColor = [UIColor mo_lightGrayColor];
        activityLabel.backgroundColor = [UIColor clearColor];
        activityLabel.lineBreakMode = NSLineBreakByWordWrapping;
        activityLabel.numberOfLines = 0;
        activityLabel.text = @"Unknown activity";
    }
    return activityLabel;
}

- (NSString *)activityMessage {
    return self.activityLabel.text;
}

- (void)setActivityMessage:(NSString *)aMessage {
  dispatch_async(dispatch_get_main_queue(), ^{
    self.activityLabel.text = aMessage;
  });
}

- (UILabel *)actionLabel {
    if (actionLabel == nil) {
        actionLabel = [[UILabel alloc] initWithFrame:CGRectMake(-50, 30, 300, 40)];
        actionLabel.textAlignment = NSTextAlignmentCenter;
        actionLabel.font = [UIFont systemFontOfSize:14.0];
        actionLabel.textColor = [UIColor mo_lightGrayColor];
        actionLabel.backgroundColor = [UIColor clearColor];
        actionLabel.lineBreakMode = NSLineBreakByWordWrapping;
        actionLabel.numberOfLines = 0;
        actionLabel.text = @"";
    }
    return actionLabel;
}

- (NSString *)actionMessage {
    return self.actionLabel.text;
}

- (void)setActionMessage:(NSString *)aMessage {
  dispatch_async(dispatch_get_main_queue(), ^{
    self.actionLabel.text = aMessage;
  });
}

- (UIButton*)abortButton {
    if (abortButton == nil) {
        abortButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
        abortButton.frame = CGRectMake(40, 100, 120, 40);
        [abortButton setTitle:@"Abort" forState:UIControlStateNormal];
        [abortButton addTarget:self action:@selector(abort) forControlEvents:UIControlEventTouchUpInside];
    }
    return abortButton;
}

- (void)abort {
    //[[self abortButton] setEnabled:NO];
    //MobileOrgAppDelegate *appDelegate = (MobileOrgAppDelegate *)[[UIApplication sharedApplication] delegate];
    //[[appDelegate transferManager] abort];
}

- (UIProgressView*)progressBar {
    if (progressBar == nil) {
        progressBar = [[[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault] retain];
        progressBar.frame = CGRectMake(20, 75, 160, 40);
    }
    return progressBar;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self handleRotate];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didRotate:)
                                                 name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification object:nil];
}


- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

    // Release any cached data, images, etc that aren't in use.
}

- (void)dealloc {
    [statusView release];
    [super dealloc];
}

@end
