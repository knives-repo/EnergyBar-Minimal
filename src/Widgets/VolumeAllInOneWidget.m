/**
 * @file VolumeAllInOneWidget.m
 *
 * @copyright 2020 Nicolas Bonamy
 */
/*
 * This file is part of EnergyBar.
 *
 * You can redistribute it and/or modify it under the terms of the GNU
 * General Public License version 3 as published by the Free Software
 * Foundation.
 */

#import "VolumeAllInOneWidget.h"
#import "ImageTitleView.h"
#import "AudioControl.h"
#import "BezelWindow.h"
#import "KeyEvent.h"
#import "EnergyBar-Prefix.pch"

#define VOLUME_OFF 0.05
#define VOLUME_LOW 0.333
#define VOLUME_MED 0.666

@interface VolumeAllInOneWidgetView : ImageTitleView
@end

@implementation VolumeAllInOneWidgetView
- (NSSize)intrinsicContentSize
{
    return NSMakeSize(WIDGET_STANDARD_WIDTH, NSViewNoIntrinsicMetric);
}
@end

@interface VolumeAllInOneWidget() {
    int lastSlidePosition;
    BOOL modified;
}
@property (retain) NSImage *volumeOff;
@property (retain) NSImage *volumeOffMute;
@property (retain) NSImage *volumeLow;
@property (retain) NSImage *volumeLowMute;
@property (retain) NSImage *volumeMedium;
@property (retain) NSImage *volumeMediumMute;
@property (retain) NSImage *volumeHigh;
@property (retain) NSImage *volumeHighMute;
@end

@implementation VolumeAllInOneWidget

- (void)commonInit
{
    [super commonInit:YES];
    [self setImageSize:WIDGET_STANDARD_IMAGE_SIZE];
    
    self.customizationLabel = @"Volume All-in-one";
    
    self.volumeOff = [NSImage imageNamed:@"AudioVolumeOff"];
    self.volumeOffMute = [NSImage imageNamed:@"AudioVolumeOffMute"];
    self.volumeLow = [NSImage imageNamed:@"AudioVolumeLow"];
    self.volumeLowMute = [NSImage imageNamed:@"AudioVolumeLowMute"];
    self.volumeMedium = [NSImage imageNamed:@"AudioVolumeMed"];
    self.volumeMediumMute = [NSImage imageNamed:@"AudioVolumeMedMute"];
    self.volumeHigh = [NSImage imageNamed:@"AudioVolumeHigh"];
    self.volumeHighMute = [NSImage imageNamed:@"AudioVolumeHighMute"];
    
    [AudioControl sharedInstanceOutput];
    [self setVolumeImage];

}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
     removeObserver:self];
    
    [super dealloc];
}

- (void)viewWillAppear
{
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(audioControlNotification:)
     name:AudioControlNotification
     object:nil];
}

- (void)viewDidDisappear
{
    [[NSNotificationCenter defaultCenter]
     removeObserver:self];
}

- (void)audioControlNotification:(NSNotification *)notification
{
    [self setVolumeImage];
}

- (void)setVolumeImage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        double volume = [AudioControl sharedInstanceOutput].volume;
        BOOL mute = [AudioControl sharedInstanceOutput].mute;
        if (mute) {
            if (volume < VOLUME_OFF) {
                [self setImage:self.volumeOffMute];
            } else if (volume < VOLUME_LOW) {
                [self setImage:self.volumeLowMute];
            } else if (volume < VOLUME_MED) {
                [self setImage:self.volumeMediumMute];
            } else {
                [self setImage:self.volumeHighMute];
            }
        } else {
            if (volume < VOLUME_OFF) {
                [self setImage:self.volumeOff];
            } else if (volume < VOLUME_LOW) {
                [self setImage:self.volumeLow];
            } else if (volume < VOLUME_MED) {
                [self setImage:self.volumeMedium];
            } else {
                [self setImage:self.volumeHigh];
            }
        }
    });
}

- (void)shortPressBegan:(NSGestureRecognizer *)recognizer
{
    // get active segment
    NSPoint point = [recognizer locationInView:self.view];
    lastSlidePosition = point.x;
    modified = NO;
    
    // hide bezel window
    [BezelWindow hide];
}

- (void)shortPressChanged:(NSGestureRecognizer *)recognizer
{
    // speed this down
    NSPoint point = [recognizer locationInView:self.view];
    int positionDelta = point.x - lastSlidePosition;
    if (abs(positionDelta) < 5) {
        return;
    }
    
    // record new position that triggered a change
    lastSlidePosition = point.x;
    modified = YES;

    // process
    if (positionDelta < 0) {
        PostAuxKeyPress(NX_KEYTYPE_SOUND_DOWN);
    } else if (positionDelta > 0) {
        PostAuxKeyPress(NX_KEYTYPE_SOUND_UP);
    }
    
    // update
    [self setVolumeImage];
}

- (void)shortPressEnded:(NSGestureRecognizer *)recognizer
{
    // key up
    if (modified == NO) {
        PostAuxKeyPress(NX_KEYTYPE_MUTE);
    }
}

@end
