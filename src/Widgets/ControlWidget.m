/**
 * @file ControlWidget.m
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

#import "ControlWidget.h"
#import "Appearance.h"
#import "AudioControl.h"
#import "Brightness.h"
#import "CBBlueLightClient.h"
#import "KeyEvent.h"
#import "NSTouchBar+SystemModal.h"
#import "NowPlaying.h"
#import "TouchBarController.h"
#import "NSSegmentedControl+Utils.h"

#define MaxPanDistance                  50.0

@interface ControlWidgetPopoverBarButton : NSButton
@end

@implementation ControlWidgetPopoverBarButton
- (NSSize)intrinsicContentSize
{
    NSSize size = [super intrinsicContentSize];
    size.width = 64;
    return size;
}
@end

@interface ControlWidgetPopoverBarScrubber : NSScrubber
@end

@implementation ControlWidgetPopoverBarScrubber
- (NSSize)intrinsicContentSize
{
    NSSize size = [super intrinsicContentSize];
    size.width = 90;
    return size;
}
@end

@interface ControlWidgetPopoverBarSlider : NSSlider
@end

@implementation ControlWidgetPopoverBarSlider
- (NSSize)intrinsicContentSize
{
    NSSize size = [super intrinsicContentSize];
    size.width = 250;
    return size;
}
@end

@interface ControlWidgetBrightnessBarController : TouchBarController
    <NSScrubberDataSource, NSScrubberDelegate>
@property (retain) CBBlueLightClient *blueLightClient;
@property (retain) IBOutlet NSButton *nightShiftButton;
@property (retain) NSTimer *timer;
@end

@implementation ControlWidgetBrightnessBarController
+ (id)controller
{
    if (@available(macOS 10.14, *))
        return [self controllerWithNibNamed:@"BrightnessBar-Mojave"];
    else
        return [self controllerWithNibNamed:@"BrightnessBar"];
}

- (id)init
{
    self = [super init];
    if (nil == self)
        return nil;

    self.blueLightClient = [[[CBBlueLightClient alloc] init] autorelease];
    [self.blueLightClient setStatusNotificationBlock:^{
        [self performSelectorOnMainThread:@selector(resetNightShift) withObject:nil waitUntilDone:NO];
    }];

    return self;
}

- (void)dealloc
{
    self.blueLightClient = nil;
    self.nightShiftButton = nil;
    self.timer = nil;

    [super dealloc];
}

- (void)awakeFromNib
{
    NSScrubber *scrubber;
    NSSliderTouchBarItem *sliderItem;

    scrubber = (id)[self.touchBar itemForIdentifier:@"AppearanceScrubber"].view;
    [scrubber registerClass:[NSScrubberImageItemView class] forItemIdentifier:@""];
    scrubber.dataSource = self;
    scrubber.delegate = self;
    scrubber.selectionOverlayStyle = [NSScrubberSelectionStyle outlineOverlayStyle];

    sliderItem = [self.touchBar itemForIdentifier:@"BrightnessSlider"];
    sliderItem.slider.minValue = 0;
    sliderItem.slider.maxValue = 1;
    sliderItem.slider.altIncrementValue = 1.0 / 16;
    sliderItem.minimumValueAccessory.behavior = NSSliderAccessoryBehavior.valueStepBehavior;
    sliderItem.maximumValueAccessory.behavior = NSSliderAccessoryBehavior.valueStepBehavior;

#if 0
    sliderItem = [self.touchBar itemForIdentifier:@"KeyboardBrightnessSlider"];
    sliderItem.slider.minValue = 0;
    sliderItem.slider.maxValue = 1;
    sliderItem.slider.altIncrementValue = 1.0 / 16;
    sliderItem.minimumValueAccessory.behavior = NSSliderAccessoryBehavior.valueStepBehavior;
    sliderItem.maximumValueAccessory.behavior = NSSliderAccessoryBehavior.valueStepBehavior;
#endif

    [super awakeFromNib];
}

- (BOOL)presentWithPlacement:(NSInteger)placement
{
    NSScrubber *scrubber;
    NSSliderTouchBarItem *item;
    double value;

    scrubber = (id)[self.touchBar itemForIdentifier:@"AppearanceScrubber"].view;
    scrubber.selectedIndex = (NSInteger)GetAppearance();

    value = GetDisplayBrightness(0);
    if (isnan(value))
        value = 0.5;

    item = [self.touchBar itemForIdentifier:@"BrightnessSlider"];
    item.slider.doubleValue = value;

    [self resetNightShift];

#if 0
    value = GetKeyboardBrightness();
    if (isnan(value))
        value = 0.5;

    item = [self.touchBar itemForIdentifier:@"KeyboardBrightnessSlider"];
    item.slider.doubleValue = value;
#endif

    [self resetTimer];

    return [super presentWithPlacement:placement];
}

- (void)dismiss
{
    [self.timer invalidate];
    self.timer = nil;

    [super dismiss];
}

- (void)resetTimer
{
    [self.timer invalidate];
    self.timer = [NSTimer
        scheduledTimerWithTimeInterval:3
        target:self
        selector:@selector(dismiss)
        userInfo:nil
        repeats:NO];
}

- (IBAction)nightShiftButtonClick:(id)sender
{
    [self resetTimer];

    switch ([sender state])
    {
    case NSControlStateValueOn:
        [self.blueLightClient setEnabled:YES];
        break;
    case NSControlStateValueOff:
        [self.blueLightClient setEnabled:NO];
        break;
    default:
        NSLog(@"nightShiftButtonClick: %d", (int)[sender state]);
        break;
    }
}

- (IBAction)brightnessSliderAction:(id)sender
{
    [self resetTimer];

    NSSliderTouchBarItem *item = [self.touchBar itemForIdentifier:@"BrightnessSlider"];
    SetDisplayBrightness(0, item.slider.doubleValue);
}

- (void)resetNightShift
{
    CBBlueLightStatus status;
    if ([self.blueLightClient getBlueLightStatus:&status])
        self.nightShiftButton.state = status.enabled ? NSControlStateValueOn : NSControlStateValueOff;
}

- (NSInteger)numberOfItemsForScrubber:(NSScrubber *)scrubber
{
    return 2;
}

- (NSScrubberItemView *)scrubber:(NSScrubber *)scrubber viewForItemAtIndex:(NSInteger)index
{
    NSScrubberImageItemView *itemView = [scrubber makeItemWithIdentifier:@"" owner:nil];
    itemView.image = [NSImage imageNamed:0 == index ? @"AppearanceLight" : @"AppearanceDark"];
    return itemView;
}

- (void)scrubber:(NSScrubber *)scrubber didSelectItemAtIndex:(NSInteger)selectedIndex
{
    [self resetTimer];

    SetAppearance((Appearance)selectedIndex);
}

#if 0
- (IBAction)keyboardBrightnessSliderAction:(id)sender
{
    [self resetTimer];

    NSSliderTouchBarItem *item = [self.touchBar itemForIdentifier:@"KeyboardBrightnessSlider"];
    SetKeyboardBrightness(item.slider.doubleValue);
}
#endif
@end

@interface ControlWidgetVolumeBarController : TouchBarController
@property (retain) NSTimer *timer;
@end

@implementation ControlWidgetVolumeBarController
+ (id)controller
{
    return [self controllerWithNibNamed:@"VolumeBar"];
}

- (void)dealloc
{
    self.timer = nil;

    [super dealloc];
}

- (void)awakeFromNib
{
    NSSliderTouchBarItem *item = [self.touchBar itemForIdentifier:@"VolumeSlider"];
    item.slider.minValue = 0;
    item.slider.maxValue = 1;
    item.slider.altIncrementValue = 1.0 / 16;
    item.minimumValueAccessory.behavior = NSSliderAccessoryBehavior.valueStepBehavior;
    item.maximumValueAccessory.behavior = NSSliderAccessoryBehavior.valueStepBehavior;

    [super awakeFromNib];
}

- (BOOL)presentWithPlacement:(NSInteger)placement
{
    double value = [AudioControl sharedInstanceOutput].volume;
    if (isnan(value))
        value = 0.5;

    NSSliderTouchBarItem *item = [self.touchBar itemForIdentifier:@"VolumeSlider"];
    item.slider.doubleValue = value;

    [self resetTimer];

    return [super presentWithPlacement:placement];
}

- (void)dismiss
{
    [self.timer invalidate];
    self.timer = nil;

    [super dismiss];
}

- (void)resetTimer
{
    [self.timer invalidate];
    self.timer = [NSTimer
        scheduledTimerWithTimeInterval:3
        target:self
        selector:@selector(dismiss)
        userInfo:nil
        repeats:NO];
}

- (IBAction)volumeSliderAction:(id)sender
{
    [self resetTimer];

    NSSliderTouchBarItem *item = [self.touchBar itemForIdentifier:@"VolumeSlider"];
    [AudioControl sharedInstanceOutput].volume = item.slider.doubleValue;
    [AudioControl sharedInstanceOutput].mute = item.slider.doubleValue < 1.0 / (16 * 4);
}
@end

@interface ControlWidgetLevelView : NSView
@property (getter=value, setter=setValue:) double value;
@property (getter=indicatorWidth, setter=setIndicatorWidth:) CGFloat indicatorWidth;
@property (assign) CGFloat inset;
@property (retain) NSColor *backgroundColor;
@property (retain) NSColor *foregroundColor;
@end

@implementation ControlWidgetLevelView
{
    double _value;
    CGFloat _indicatorWidth;
    NSInteger _tag;
}

- (void)dealloc
{
    self.backgroundColor = nil;
    self.foregroundColor = nil;

    [super dealloc];
}

- (void)drawRect:(NSRect)rect
{
    NSColor *backgroundColor = self.backgroundColor;
    NSColor *foregroundColor = self.foregroundColor;

    if (nil == backgroundColor)
        backgroundColor = [NSColor clearColor];
    if (nil == foregroundColor)
    {
        if (@available(macOS 10.14, *))
            foregroundColor = [NSColor controlAccentColor];
        else
            foregroundColor = [NSColor systemBlueColor];
    }

    rect = self.bounds;

    [backgroundColor setFill];
    NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);

    CGFloat inset = self.inset;
    rect = NSInsetRect(rect, inset, inset);

    CGFloat indicatorWidth = self.indicatorWidth;
    if (0 > indicatorWidth)
    {
        CGFloat maxX = NSMaxX(rect);
        indicatorWidth = -indicatorWidth;
        rect.size.width = MIN(indicatorWidth, rect.size.width);
        rect.origin.x = maxX - rect.size.width;
    }
    else if (0 < indicatorWidth)
        rect.size.width = MIN(indicatorWidth, rect.size.width);

    [foregroundColor set];
    CGFloat level = self.value;
    CGFloat x = rect.origin.x + level * rect.size.width;
    CGFloat y = rect.origin.y + level * rect.size.height;
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:rect.origin];
    [path lineToPoint:NSMakePoint(x, NSMinY(rect))];
    [path lineToPoint:NSMakePoint(x, y)];
    [path closePath];
    [path fill];
}

- (double)value
{
    return _value;
}

- (void)setValue:(double)value
{
    if (_value == value)
        return;

    _value = value;
    [self setNeedsDisplay:YES];
}

- (CGFloat)indicatorWidth
{
    return _indicatorWidth;
}

- (void)setIndicatorWidth:(CGFloat)value
{
    if (_indicatorWidth == value)
        return;

    _indicatorWidth = value;
    [self setNeedsDisplay:YES];
}

- (NSInteger)tag
{
    return _tag;
}

- (void)setTag:(NSInteger)value
{
    _tag = value;
}
@end

@interface ControlWidgetView : NSView
@end

@implementation ControlWidgetView
- (NSSize)intrinsicContentSize
{
    return [[self.subviews firstObject] intrinsicContentSize];
}

- (void)resizeSubviewsWithOldSize:(NSSize)size
{
    NSView *view = [self.subviews lastObject];
    NSRect rect = view.frame;
    rect.origin.y = (self.bounds.size.height - rect.size.height) / 2;
    view.frame = rect;
}
@end

@interface ControlWidget ()
@property (retain) ControlWidgetBrightnessBarController *brightnessBarController;
@property (retain) ControlWidgetVolumeBarController *volumeBarController;
@end

@implementation ControlWidget
{
    NSInteger _pressKind;
    CGFloat _xmin, _xmax;
}

- (void)commonInit
{
    self.brightnessBarController = [ControlWidgetBrightnessBarController controller];
    self.volumeBarController = [ControlWidgetVolumeBarController controller];

    NSPressGestureRecognizer *shortPress = [[[NSPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(shortPressAction:)] autorelease];
    shortPress.allowedTouchTypes = NSTouchTypeMaskDirect;
    shortPress.minimumPressDuration = ShortPressDuration;
    
    NSPressGestureRecognizer *longPress = [[[NSPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(longPressAction:)] autorelease];
    longPress.allowedTouchTypes = NSTouchTypeMaskDirect;
    longPress.minimumPressDuration = SuperLongPressDuration;

    NSSegmentedControl *control = [NSSegmentedControl
       //you can add more buttons here (add to the array), this is where you arrange button icons
        segmentedControlWithImages:[NSArray arrayWithObjects:
            [NSImage imageNamed:@"KeyboardBrightnessUp"],
            [self playPauseImage],
            [NSImage imageNamed:@"BrightnessUp"],
            [NSImage imageNamed:NSImageNameTouchBarAudioOutputVolumeHighTemplate],
            [self volumeMuteImage],
            nil]
        trackingMode:NSSegmentSwitchTrackingMomentary
        target:self
        action:@selector(click:)];
    control.translatesAutoresizingMaskIntoConstraints = NO;
    control.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    control.tag = 'ctrl';

    ControlWidgetLevelView *level = [[[ControlWidgetLevelView alloc]
        initWithFrame:NSMakeRect(0, 0, MaxPanDistance, 20)] autorelease];
    level.wantsLayer = YES;
    level.layer.cornerRadius = 4.0;
    level.layer.borderWidth = 1.0;
    level.layer.borderColor = [[NSColor systemGrayColor] CGColor];
    level.translatesAutoresizingMaskIntoConstraints = NO;
    level.autoresizingMask = NSViewNotSizable;
    level.value = 0.5;
    level.inset = 4;
    level.tag = 'levl';
    level.hidden = YES;

    NSView *view = [[[ControlWidgetView alloc] initWithFrame:NSZeroRect] autorelease];
    [view addGestureRecognizer:shortPress];
    [view addSubview:control];
    [view addSubview:level];

    self.customizationLabel = @"Control";
    self.view = view;

    [NowPlaying sharedInstance];
    [AudioControl sharedInstanceOutput];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self];

    self.brightnessBarController = nil;
    self.volumeBarController = nil;

    [super dealloc];
}

- (void)viewWillAppear
{
    [[NSNotificationCenter defaultCenter]
        addObserver:self
        selector:@selector(nowPlayingNotification:)
        name:NowPlayingStateNotification
        object:nil];
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

- (NSImage *)playPauseImage
{
    BOOL playing = [NowPlaying sharedInstance].playing;
    return [NSImage imageNamed:playing ?
        NSImageNameTouchBarPauseTemplate : NSImageNameTouchBarPlayTemplate];
}

- (NSImage *)volumeMuteImage
{
    BOOL mute = [AudioControl sharedInstanceOutput].mute;
    return [NSImage imageNamed:mute ? @"VolumeMuteOn" : @"VolumeMuteOff"];
}

- (void)nowPlayingNotification:(NSNotification *)notification
{
    NSSegmentedControl *control = [self.view viewWithTag:'ctrl'];
    //change which segment (button) displays the play/pause image
    [control setImage:[self playPauseImage] forSegment:1];
}

- (void)audioControlNotification:(NSNotification *)notification
{
    NSSegmentedControl *control = [self.view viewWithTag:'ctrl'];
    //change which segment (button) displays the mute/unmute image
    [control setImage:[self volumeMuteImage] forSegment:4];
}

- (void)click:(id)sender
{
    NSSegmentedControl *control = sender;
    switch (control.selectedSegment)
    {
    case 0:
        break;
    case 1:
        PostAuxKeyPress(NX_KEYTYPE_PLAY);
        break;
    case 2:
        [self.brightnessBarController present];
        break;
    case 3:
        [self.volumeBarController present];
        break;
    case 4:
        [AudioControl sharedInstanceOutput].mute = ![AudioControl sharedInstanceOutput].mute;
        break;
    }
}

- (void)shortPressAction:(NSGestureRecognizer *)recognizer
{
    switch (recognizer.state)
    {
    case NSGestureRecognizerStateBegan:
        [self shortPressBegan:recognizer];
        break;
    case NSGestureRecognizerStateChanged:
        [self shortPressChanged:recognizer];
        break;
    case NSGestureRecognizerStateEnded:
    case NSGestureRecognizerStateCancelled:
        [self shortPressEnded:recognizer];
        break;
    default:
        return;
    }
}

- (void)shortPressBegan:(NSGestureRecognizer *)recognizer
{
    if (0 != _pressKind)
        return;

    NSSegmentedControl *control = [self.view viewWithTag:'ctrl'];
    ControlWidgetLevelView *level = [self.view viewWithTag:'levl'];
    NSPoint point = [recognizer locationInView:control];
    NSInteger segment = [control segmentForX:point.x];
    double value;

    switch (segment)
    {
    case 0:
        _pressKind = 'keyb';
        value = 0.5;
        break;
    case 1:
        _pressKind = 'play';
        value = 0.5;
        break;
    case 2:
        _pressKind = 'brgt';
        value = GetDisplayBrightness(0);
        break;
    case 3:
        _pressKind = 'audi';
        value = [AudioControl sharedInstanceOutput].volume;
        break;
    default:
        return;
    }

    if (isnan(value))
        value = 0.5;
    _xmin = point.x - MaxPanDistance * value;
    _xmax = _xmin + MaxPanDistance;

    //if no sliders, remember to insert here
    if ('play' == _pressKind || 'keyb' == _pressKind)
        return;

    control.hidden = YES;
    level.hidden = NO;
    level.value = value;
}

- (void)shortPressChanged:(NSGestureRecognizer *)recognizer
{
    if (0 == _pressKind)
        return;

    NSSegmentedControl *control = [self.view viewWithTag:'ctrl'];
    ControlWidgetLevelView *level = [self.view viewWithTag:'levl'];
    NSPoint point = [recognizer locationInView:self.view];
    point.x = MAX(point.x, _xmin);
    point.x = MIN(point.x, _xmax);
    double value = (point.x - _xmin) / MaxPanDistance;

    //modify this for different 'slide' buttons
    switch (_pressKind)
    {
            //remember to change segments!
    case 'keyb':
        if (0.25 > value)
            [control setImage:[NSImage imageNamed:@"KeyboardBrightnessDown"] forSegment:0];
        else if (0.25 <= value && value <= 0.75)
            [control setImage:[NSImage imageNamed:@"KeyboardBrightnessUp"] forSegment:0];
        else
            [control setImage:[NSImage imageNamed:@"KeyboardBrightnessMax"] forSegment:0];
        break;
    case 'play':
        if (0.25 > value)
            [control setImage:[NSImage imageNamed:NSImageNameTouchBarSkipBackTemplate] forSegment:1];
        else if (0.25 <= value && value <= 0.75)
            [control setImage:[self playPauseImage] forSegment:1];
        else
            [control setImage:[NSImage imageNamed:NSImageNameTouchBarSkipAheadTemplate] forSegment:1];
        break;
    case 'brgt':
        level.value = isnan(value) ? 0.5 : value;
        SetDisplayBrightness(0, value);
        break;
    case 'audi':
        level.value = isnan(value) ? 0.5 : value;
        [AudioControl sharedInstanceOutput].volume = value;
        [AudioControl sharedInstanceOutput].mute = value < 1.0 / (16 * 4);
        break;
    }
}

- (void)shortPressEnded:(NSGestureRecognizer *)recognizer
{
    if (0 == _pressKind)
        return;

    NSSegmentedControl *control = [self.view viewWithTag:'ctrl'];
    ControlWidgetLevelView *level = [self.view viewWithTag:'levl'];
    NSPoint point = [recognizer locationInView:self.view];
    point.x = MAX(point.x, _xmin);
    point.x = MIN(point.x, _xmax);
    double value = (point.x - _xmin) / MaxPanDistance;

    switch (_pressKind)
    {
    case 'keyb':
        if (0.25 > value)
        {
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_DOWN);
        }
        else if (0.25 <= value && value <= 0.75)
            ;
        else
        {
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
            PostAuxKeyPress(NX_KEYTYPE_ILLUMINATION_UP);
        }
        [control setImage:[NSImage imageNamed:@"KeyboardBrightnessUp"] forSegment:0];
        break;
    case 'play':
        if (0.25 > value)
            PostAuxKeyPress(NX_KEYTYPE_PREVIOUS);
        else if (0.25 <= value && value <= 0.75)
            ;
        else
            PostAuxKeyPress(NX_KEYTYPE_NEXT);
        [control setImage:[self playPauseImage] forSegment:1];
        break;
    default:
        control.hidden = NO;
        level.hidden = YES;
        break;
    }

    _pressKind = 0;
}

@end
