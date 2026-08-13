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

#import <Foundation/NSObject.h>

@class NSColor, NSString;

// Bridge between AppKit system colors and the host desktop environment
// (KDE/GNOME). Reads the DE's global configuration and maps it onto the
// macOS semantic color names resolved by X11Display -colorWithName:.
@interface X11Theme : NSObject

// YES when the host desktop prefers a dark color scheme (KDE kdeglobals
// [Colors:View] BackgroundNormal luminance, or GTK prefer-dark).
+ (BOOL) prefersDark;

// The DE's accent color (KDE [General] AccentColor; on GNOME falls back to
// the GTK default accent). Returns nil when the DE exposes none.
+ (NSColor *) accentColor;

// Maps a KDE color role (e.g. "Selection", "Window", "Button", "View") onto
// an sRGB NSColor. Returns nil when the DE does not define the role.
+ (NSColor *) colorForRole: (NSString *) role
              background: (BOOL) background;

@end
