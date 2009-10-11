//
//  NewNoteController.h
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

#import <Foundation/Foundation.h>

@class Note;

@interface NewNoteController : UIViewController <UITextViewDelegate> {
    UITextView *textField;
    UIBarButtonItem *doneButton;
    UIBarButtonItem *addButton;
    Note *note;
    bool keyboardShown;
    bool showKeyboardOnLoad;
}

@property (nonatomic, retain) UITextView *textField;
@property (nonatomic, retain) UIBarButtonItem *doneButton;
@property (nonatomic, retain) UIBarButtonItem *addButton;
@property (nonatomic, retain) Note *note;
@property (nonatomic) bool showKeyboardOnLoad;

@end
