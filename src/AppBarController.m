/**
 * @file AppBarController.m
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

#import "AppBarController.h"

@interface AppBarController () <NSTouchBarDelegate>
@end

@implementation AppBarController
{
    NSMutableDictionary *_items;
}

- (id)init
{
    self = [super init];
    if (nil == self)
        return nil;

    _items = [[NSMutableDictionary alloc] init];

    return self;
}

- (void)dealloc
{
    [_items release];

    [super dealloc];
}

- (void)awakeFromNib //add stuff here to set new defaults or widgets
{
    self.touchBar.defaultItemIdentifiers = [NSArray arrayWithObjects: //Default Set
        @"NowPlaying",
        @"Dock",
        @"Todo",
        @"Control",
        @"Weather",
        @"Lock",
        nil];
    self.touchBar.customizationAllowedItemIdentifiers = [NSArray arrayWithObjects: //add new widgets here
        @"Dock",
        @"EscKey",
        @"NowPlaying",
        @"Todo",
        @"Control",
        @"Weather",
        @"Clock",
        @"Lock",
        @"Backlight",
        @"MicMute",
        NSTouchBarItemIdentifierFlexibleSpace,
        nil];

    [super awakeFromNib];
}

- (NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar
    makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
    NSTouchBarItem *item = [_items objectForKey:identifier];
    if (nil == item)
    {
        NSArray *components = [identifier componentsSeparatedByString:@" "];
        NSString *widgetClass = [[components objectAtIndex:0] stringByAppendingString:@"Widget"];
        item = [[[NSClassFromString(widgetClass) alloc] initWithIdentifier:identifier] autorelease];
        [_items setObject:item forKey:identifier];
    }
    return item;
}
@end
