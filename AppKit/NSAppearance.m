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
#import <Foundation/NSString.h>
#import <stdlib.h>
#import <unistd.h>
#import <pwd.h>

static BOOL _systemPrefersDark() {
    static int cached = -1;
    if (cached != -1)
        return cached;

    // Honor an explicit override set by the launcher.
    const char *override = getenv("OSXIE_APPEARANCE");
    if (override != NULL && strcmp(override, "DarkAqua") == 0) {
        cached = 1;
        return cached;
    }
    if (override != NULL && strcmp(override, "Aqua") == 0) {
        cached = 0;
        return cached;
    }

    // Fall back to the DE's global configuration. The guest container can
    // reach the host's KDE settings through /Volumes/SystemRoot (host root).
    // The XDG portal derives org.freedesktop.appearance color-scheme from the
    // [Colors:View] background luminance, so parse it the same way.
    const char *home = getenv("HOME");
    struct passwd *pw = getpwuid(getuid());
    const char *pwDir = (pw != NULL) ? pw->pw_dir : NULL;

    const char *candidates[4] = {0};
    int n = 0;
    if (home != NULL) {
        char *p = malloc(strlen(home) + 32);
        sprintf(p, "%s/.config/kdeglobals", home);
        candidates[n++] = p;
        char *q = malloc(strlen(home) + 64);
        sprintf(q, "/Volumes/SystemRoot%s/.config/kdeglobals", home);
        candidates[n++] = q;
    }
    if (pwDir != NULL && (home == NULL || strcmp(pwDir, home) != 0)) {
        char *p = malloc(strlen(pwDir) + 64);
        sprintf(p, "/Volumes/SystemRoot%s/.config/kdeglobals", pwDir);
        candidates[n++] = p;
    }

    for (int i = 0; i < n; i++) {
        const char *path = candidates[i];
        FILE *f = fopen(path, "r");
        if (f == NULL)
            continue;

        // Look for the first "BackgroundNormal=r,g,b" under [Colors:View].
        BOOL inColorsView = NO;
        char line[512];
        int r = 0, g = 0, b = 0;
        BOOL found = NO;
        while (fgets(line, sizeof(line), f) != NULL) {
            if (line[0] == '[') {
                inColorsView = (strncmp(line, "[Colors:View]", 14) == 0);
                continue;
            }
            if (!inColorsView)
                continue;
            if (strncmp(line, "BackgroundNormal=", 17) == 0) {
                if (sscanf(line + 17, "%d,%d,%d", &r, &g, &b) == 3)
                    found = YES;
                break;
            }
        }
        fclose(f);
        if (found) {
            cached = ((r + g + b) / 3 < 128) ? 1 : 0;
            break;
        }
    }
    free((void *) candidates[0]);
    free((void *) candidates[1]);
    free((void *) candidates[2]);

    if (cached == -1)
        cached = 0;
    return cached;
}

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
    NSAppearanceName name = _systemPrefersDark() ? NSAppearanceNameDarkAqua
                                                  : NSAppearanceNameAqua;
    return [self appearanceNamed: name];
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
