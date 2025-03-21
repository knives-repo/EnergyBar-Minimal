/**
 * @file ControlWidget.h
 *
 * @copyright 2018-2019 Bill Zissimopoulos
 */
/*
 * This file is part of EnergyBar.
 *
 * You can redistribute it and/or modify it under the terms of the GNU
 * General Public License version 3 as published by the Free Software
 * Foundation.
 */

#import <Cocoa/Cocoa.h>
#import "CustomWidget.h"

@interface ControlWidget : CustomWidget
@property (retain) NSImage *KeyboardBrightnessMax;
@property (retain) NSImage *KeyboardBrightnessDown;
@end
