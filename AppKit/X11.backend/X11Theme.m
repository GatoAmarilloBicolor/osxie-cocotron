/* Copyright (c) 2026 Osxie

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. */

#import "X11Theme.h"
#import <AppKit/NSColor.h>
#import <Foundation/NSString.h>
#import <stdlib.h>
#import <stdio.h>
#import <string.h>
#import <pwd.h>
#import <unistd.h>

// Cached key/value view of the host DE configuration. Entries are of the
// form "Section/key" (KDE) or "GTK/key" (GNOME settings.ini).
static char *_themeCache[256];
static int _themeCacheCount = 0;

static char *_sectionForRole(NSString *role) {
    if ([role isEqualToString: @"Selection"])
        return "Colors:Selection";
    if ([role isEqualToString: @"Window"])
        return "Colors:Window";
    if ([role isEqualToString: @"Button"])
        return "Colors:Button";
    if ([role isEqualToString: @"View"])
        return "Colors:View";
    if ([role isEqualToString: @"Complement"])
        return "Colors:Complementary";
    if ([role isEqualToString: @"Tooltip"])
        return "Colors:Tooltip";
    return NULL;
}

static void _cacheSet(const char *key, const char *value) {
    if (_themeCacheCount >= 256)
        return;
    char *entry = malloc(strlen(key) + strlen(value) + 2);
    sprintf(entry, "%s=%s", key, value);
    _themeCache[_themeCacheCount++] = entry;
}

// Fills `out` with candidate paths for a config file reachable from the guest
// container (HOME, then the same through the host root /Volumes/SystemRoot).
// Also tries the real /home/<user> path when HOME is set to /Users/<user>.
// Returns the number of candidates stored (max 5).
static int _configCandidates(const char *filename, char **out, int outMax) {
    const char *home = getenv("HOME");
    struct passwd *pw = getpwuid(getuid());
    const char *pwDir = (pw != NULL) ? pw->pw_dir : NULL;
    int n = 0;

    if (home != NULL) {
        if (n < outMax) {
            out[n] = malloc(strlen(home) + strlen(filename) + 48);
            sprintf(out[n], "%s/%s", home, filename);
            n++;
        }
        if (n < outMax) {
            out[n] = malloc(strlen(home) + strlen(filename) + 64);
            sprintf(out[n], "/Volumes/SystemRoot%s/%s", home, filename);
            n++;
        }
    }
    if (pwDir != NULL && (home == NULL || strcmp(pwDir, home) != 0)) {
        if (n < outMax) {
            out[n] = malloc(strlen(pwDir) + strlen(filename) + 64);
            sprintf(out[n], "/Volumes/SystemRoot%s/%s", pwDir, filename);
            n++;
        }
    }
    // When HOME=/Users/<user> (osxie macOS path), also try /home/<user>/...
    // which is the real host path where KDE/GNOME store their configs.
    if (home != NULL && strncmp(home, "/Users/", 7) == 0) {
        const char *realHome = home + 6; // /Users/foo -> /home/foo
        // Check both /home/<user> and /Volumes/SystemRoot/home/<user>
        if (n < outMax) {
            out[n] = malloc(strlen(realHome) + strlen(filename) + 48);
            sprintf(out[n], "/home%s/%s", realHome, filename);
            n++;
        }
        if (n < outMax) {
            out[n] = malloc(strlen(realHome) + strlen(filename) + 64);
            sprintf(out[n], "/Volumes/SystemRoot/home%s/%s", realHome, filename);
            n++;
        }
    }
    return n;
}

// Parses one config file into the cache. Returns YES on first existing file.
static BOOL _parseIniFile(const char *path, const char *prefix) {
    FILE *f = fopen(path, "r");
    if (f == NULL) {
        if (getenv("OSXIE_TRACE_THEME"))
            fprintf(stderr, "[TRACE] X11Theme _parseIniFile: fopen(%s) FAILED\n", path);
        return NO;
    }
    if (getenv("OSXIE_TRACE_THEME"))
        fprintf(stderr, "[TRACE] X11Theme _parseIniFile: fopen(%s) OK, parsing\n", path);

    char line[512];
    char currentSection[64] = "";
    while (fgets(line, sizeof(line), f) != NULL) {
        if (line[0] == '[') {
            char *end = strchr(line, ']');
            if (end != NULL) {
                size_t len = end - line - 1;
                if (len < sizeof(currentSection)) {
                    memcpy(currentSection, line + 1, len);
                    currentSection[len] = 0;
                }
            }
            continue;
        }
        char *eq = strchr(line, '=');
        if (eq == NULL)
            continue;
        *eq = 0;
        char k[128];
        snprintf(k, sizeof(k), "%s%s/%s", prefix, currentSection, line);
        char *v = eq + 1;
        size_t vl = strlen(v);
        while (vl > 0 && (v[vl - 1] == '\n' || v[vl - 1] == '\r'))
            v[--vl] = 0;
        _cacheSet(k, v);
    }
    fclose(f);
    return YES;
}

// Returns a static string for "key", or NULL. Parses KDE kdeglobals and, as a
// fallback for GNOME-only hosts, GTK settings.ini.
static const char *_themeValue(const char *key) {
    for (int i = 0; i < _themeCacheCount; i++) {
        if (strncmp(_themeCache[i], key, strlen(key)) == 0 &&
            _themeCache[i][strlen(key)] == '=')
            return _themeCache[i] + strlen(key) + 1;
    }

    char *kdePaths[5] = {0};
    int kdeN = _configCandidates(".config/kdeglobals", kdePaths, 5);
    if (getenv("OSXIE_TRACE_THEME")) {
        fprintf(stderr, "[TRACE] X11Theme: HOME=%s, tried %d kde paths:\n", getenv("HOME"), kdeN);
        for (int i = 0; i < kdeN; i++)
            fprintf(stderr, "[TRACE]   %s\n", kdePaths[i]);
    }
    for (int i = 0; i < kdeN; i++) {
        if (_parseIniFile(kdePaths[i], ""))
            break;
    }
    for (int i = 0; i < kdeN; i++)
        free(kdePaths[i]);

    char *gtkPaths[5] = {0};
    int gtkN = _configCandidates(".config/gtk-3.0/settings.ini", gtkPaths, 5);
    for (int i = 0; i < gtkN; i++) {
        if (_parseIniFile(gtkPaths[i], "GTK/"))
            break;
    }
    for (int i = 0; i < gtkN; i++)
        free(gtkPaths[i]);

    for (int i = 0; i < _themeCacheCount; i++) {
        if (strncmp(_themeCache[i], key, strlen(key)) == 0 &&
            _themeCache[i][strlen(key)] == '=')
            return _themeCache[i] + strlen(key) + 1;
    }
    return NULL;
}

static BOOL _parseRGB(const char *s, float *r, float *g, float *b) {
    if (s == NULL)
        return NO;
    int ir = 0, ig = 0, ib = 0;
    if (sscanf(s, "%d,%d,%d", &ir, &ig, &ib) != 3)
        return NO;
    *r = ir / 255.0f;
    *g = ig / 255.0f;
    *b = ib / 255.0f;
    return YES;
}

static NSColor *_colorFromString(const char *s) {
    float r, g, b;
    if (_parseRGB(s, &r, &g, &b))
        return [NSColor colorWithSRGBRed: r green: g blue: b alpha: 1.0f];
    return nil;
}

@implementation X11Theme

+ (BOOL) prefersDark {
    static int cached = -1;
    if (cached != -1)
        return cached;

    // KDE: luminance of the [Colors:View] background.
    const char *bg = _themeValue("Colors:View/BackgroundNormal");
    if (bg != NULL) {
        float r, g, b;
        if (_parseRGB(bg, &r, &g, &b)) {
            float lum = (r * 0.2126f + g * 0.7152f + b * 0.0722f);
            cached = (lum < 0.5f) ? 1 : 0;
            return cached;
        }
    }

    // GNOME GTK: gtk-application-prefer-dark-theme or theme name suffix.
    const char *pd = _themeValue("GTK/gtk-application-prefer-dark-theme");
    if (pd != NULL && strcasecmp(pd, "true") == 0) {
        cached = 1;
        return cached;
    }
    const char *theme = _themeValue("GTK/gtk-theme-name");
    if (theme != NULL && (strstr(theme, "dark") != NULL ||
                          strstr(theme, "Dark") != NULL ||
                          strstr(theme, "-Dark") != NULL ||
                          strstr(theme, "Night") != NULL)) {
        cached = 1;
        return cached;
    }

    cached = 0;
    return cached;
}

+ (NSColor *) accentColor {
    // KDE: [General] AccentColor.
    const char *accent = _themeValue("General/AccentColor");
    if (accent != NULL) {
        NSColor *c = _colorFromString(accent);
        if (c != nil)
            return c;
    }

    // GNOME GTK: derive from the theme's suggested accent when possible,
    // otherwise fall back to the GNOME default accent color.
    const char *theme = _themeValue("GTK/gtk-theme-name");
    if (theme != NULL) {
        // Common libadwaita blue.
        return [NSColor colorWithSRGBRed: 0.212f
                                   green: 0.518f
                                    blue: 0.894f
                                   alpha: 1.0f];
    }
    return nil;
}

+ (NSColor *) colorForRole: (NSString *) role
              background: (BOOL) background {
    const char *section = _sectionForRole(role);
    if (section == NULL)
        return nil;

    const char *key = background ? "BackgroundNormal" : "ForegroundNormal";
    char full[128];
    snprintf(full, sizeof(full), "%s/%s", section, key);
    const char *val = _themeValue(full);
    if (getenv("OSXIE_TRACE_THEME"))
        fprintf(stderr, "[TRACE] X11Theme colorForRole:%s bg=%d key=%s val=%s\n",
                [role UTF8String], background, full, val ? val : "(null)");
    return _colorFromString(val);
}

@end
