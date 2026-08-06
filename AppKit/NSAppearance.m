/*
 This file is part of Osxie.

 Copyright (C) 2019 Lubos Dolezel

 Osxie is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Osxie is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Osxie.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <AppKit/NSAppearance.h>

NSString *const NSAppearanceNameAqua = @"NSAppearanceNameAqua";
NSString *const NSAppearanceNameDarkAqua = @"NSAppearanceNameDarkAqua";
NSString *const NSAppearanceNameSystem = @"NSAppearanceNameSystem";
NSString *const NSAppearanceNameTouchBar = @"NSAppearanceNameTouchBar";
NSString *const NSAppearanceNameLightContent = @"NSAppearanceNameLightContent";
NSString *const NSAppearanceNameVibrantDark = @"NSAppearanceNameVibrantDark";
NSString *const NSAppearanceNameVibrantLight = @"NSAppearanceNameVibrantLight";
NSString *const NSAppearanceNameAccessibilityHighContrastAqua =
        @"NSAppearanceNameAccessibilityAqua";
NSString *const NSAppearanceNameAccessibilityHighContrastDarkAqua =
        @"NSAppearanceNameAccessibilityDarkAqua";
NSString *const NSAppearanceNameAccessibilityHighContrastSystem =
        @"NSAppearanceNameAccessibilityHighContrastSystem";
NSString *const NSAppearanceNameAccessibilityHighContrastVibrantLight =
        @"NSAppearanceNameAccessibilityVibrantLight";
NSString *const NSAppearanceNameAccessibilityHighContrastVibrantDark =
        @"NSAppearanceNameAccessibilityVibrantDark";

NSString *const NSAppearanceNameControlStrip =
        @"NSAppearanceNameControlStrip"; // Undocumented

@implementation NSAppearance

@synthesize name = _name;

static NSAppearance *_currentAppearance = nil;

+ (NSAppearance *) appearanceNamed: (NSAppearanceName) name {
    if (name == nil) {
        name = NSAppearanceNameAqua;
    }
    NSAppearance *appearance = [[[NSAppearance alloc] init] autorelease];
    appearance->_name = [name copy];
    return appearance;
}
+ (NSAppearance *) currentAppearance {
    return [self appearanceNamed: NSAppearanceNameAqua];
}

+ (NSAppearance *) currentDrawingAppearance {
    return [self currentAppearance];
}

+ (NSAppearance *) effectiveAppearance {
    return [self currentAppearance];
}

+ (NSAppearanceName) bestMatchFromAppearancesWithNames:
        (NSArray *) appearances
{
    if (appearances == nil || [appearances count] == 0) {
        return NSAppearanceNameAqua;
    }
    for (NSString *name in appearances) {
        if ([name isKindOfClass: [NSString class]]) {
            return name;
        }
    }
    return NSAppearanceNameAqua;
}

- (instancetype) init {
    self = [super init];
    if (self) {
        _name = [NSAppearanceNameAqua copy];
    }
    return self;
}

- (void) dealloc {
    [_name release];
    [super dealloc];
}

- (NSAppearanceName) name {
    return _name;
}

- (BOOL) allowsVibrancy {
    return NO;
}

- (NSAppearanceName) bestMatchFromAppearancesWithNames:
        (NSArray *) appearances
{
    if (appearances == nil || [appearances count] == 0) {
        return [[_name copy] autorelease];
    }
    for (NSString *name in appearances) {
        if ([name isKindOfClass: [NSString class]] &&
            [name isEqualToString: _name]) {
            return [[_name copy] autorelease];
        }
    }
    return [appearances objectAtIndex: 0];
}

- (void) performAsCurrentDrawingAppearance: (void (^)(void)) block {
    if (block != NULL) {
        block();
    }
}

- (void) encodeWithCoder: (NSCoder *) aCoder {
    [aCoder encodeObject: _name forKey: @"NSAppearanceName"];
}

- (id) copyWithZone: (NSZone *) zone {
    return [[[NSAppearance alloc] init] autorelease];
}

- (id) initWithCoder: (NSCoder *) aDecoder {
    self = [super init];
    if (self) {
        _name = [[aDecoder decodeObjectForKey: @"NSAppearanceName"] copy];
        if (_name == nil) {
            _name = [NSAppearanceNameAqua copy];
        }
    }
    return self;
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

@end
