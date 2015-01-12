//
//  MTProgressindicator.h
//  cTiVo
//
//  Created by Scott Buchanan on 12/12/12.
//  Copyright (c) 2012 Scott Buchanan. All rights reserved.
//
// Simple determinant progress bar with two overlaid text items (left and right)
#import <Cocoa/Cocoa.h>

@interface MTProgressindicator : NSTableCellView

@property (nonatomic, readwrite) IBOutlet NSTextField *leftText, *rightText;
@property (nonatomic) float leftRightRatio;
@property (nonatomic) double doubleValue;  // % length of colored section
@property (nonatomic, strong) NSColor *barColor, *foregroundTextColor;
@property (nonatomic, assign) BOOL displayProgress;

@end
