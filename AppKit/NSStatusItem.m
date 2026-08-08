/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSMenu.h>
#import <AppKit/NSPopUpWindow.h>
#import <AppKit/NSRaise.h>
#import <AppKit/NSStatusBar.h>
#import <AppKit/NSStatusItem+Private.h>
#import <AppKit/NSStatusItem.h>
#import <AppKit/NSWindow.h>
#import <stdio.h>
#ifndef WIN32
#import "X11Window.h"
#endif
#ifdef WIN32
#import <AppKit/NSStatusBar_(Private).h>
#import <AppKit/Win32Window.h>
#import <Foundation/NSPlatform_win32.h>
#endif

@implementation NSStatusItem

#pragma mark Private Methods

#ifdef WIN32

- (void) _createTrayIcon {
    ZeroMemory(&niData, sizeof(NOTIFYICONDATA_V2_SIZE));
    niData.cbSize = NOTIFYICONDATA_V2_SIZE;
    srand(time(NULL));
    _trayIconID = rand();
    niData.uID = _trayIconID;
    niData.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    if (_trayIcon == NULL) {
        [self _setHICONFromImage: [self image]];
    }
    niData.hIcon = _trayIcon;
    Win32Window *window = [[NSStatusBar systemStatusBar] fakeWindow];
    niData.hWnd = [window windowHandle];
    niData.uCallbackMessage = 9001;
    Shell_NotifyIcon(NIM_ADD, &niData);
}

- (void) _removeTrayIcon {
    // If tray icon has been created, destroy it
    if (_trayIconID > -1) {
        Shell_NotifyIcon(NIM_DELETE, &niData);
    }
}

- (int) trayIconID {
    return _trayIconID;
}

- (void) _processWin32Event: (int) event {
    switch (event) {
    case WM_RBUTTONUP:
        [[NSNotificationCenter defaultCenter]
                addObserver: self
                   selector: @selector(processCommandEvent:)
                       name: @"WIN32_WM_COMMAND"
                     object: nil];
        [self _showContextMenu];
        break;
    case WM_LBUTTONUP:
        break;
    default:
        break;
    }
}

- (void) processCommandEvent: (NSNotification *) notification {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) _w32loadMenuItem: (NSMenuItem *) item
           withIdentifier: (int) i
                 intoMenu: (HMENU) menu
{
    if ([item hasSubmenu]) {
        // Configure Submenu based item
        NSString *title = [item title];
        HMENU submenu = CreatePopupMenu();
        if (submenu) {
            NSMenu *sub = [item submenu];
            if (sub) {
                for (int pos = 0; pos < [sub itemArray].count; pos++) {
                    [self _w32loadMenuItem: [[sub itemArray] objectAtIndex: pos]
                            withIdentifier: (i * 10) + pos
                                  intoMenu: submenu];
                }
            };
            NSString *title = [item title];
            MENUITEMINFO item = {0};
            item.cbSize = sizeof(MENUITEMINFO);
            item.fMask = MIIM_TYPE | MIIM_ID | MIIM_DATA | MIIM_SUBMENU;
            item.fType = MFT_STRING;
            char *string = [title cStringUsingEncoding: NSUTF8StringEncoding];
            item.dwTypeData = string;
            item.cch = lstrlen(string);
            item.hSubMenu = submenu;
            InsertMenuItem(menu, i, FALSE, &item);
        }
    } else {
        NSString *title = [item title];
        MENUITEMINFO item = {0};
        item.cbSize = sizeof(MENUITEMINFO);
        item.fMask = MIIM_TYPE | MIIM_ID | MIIM_DATA;
        item.fType = MFT_STRING;
        char *string = [title cStringUsingEncoding: NSUTF8StringEncoding];
        item.dwTypeData = string;
        item.cch = lstrlen(string);
        InsertMenuItem(menu, i, FALSE, &item);
    }
}

- (void) _setHICONFromImage: (NSImage *) image {
    // Taken from NSCursor.m

    /// move to the platform files
    size_t width = [self length];
    size_t height = width;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(
            NULL, width, height, 8, 0, colorSpace,
            kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);

    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSGraphicsContext *graphicsContext =
            [NSGraphicsContext graphicsContextWithGraphicsPort: context
                                                       flipped: NO];

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext: graphicsContext];

    [image drawInRect: NSMakeRect(0, 0, width, height)
             fromRect: NSZeroRect
            operation: NSCompositeCopy
             fraction: 1.0];

    [NSGraphicsContext restoreGraphicsState];

    [pool release];

    uint8_t *rowBytes = CGBitmapContextGetData(context);
    size_t bytesPerRow = CGBitmapContextGetBytesPerRow(context);

    HDC displayDC = GetDC(NULL);
    HBITMAP colorBitmap;
    HBITMAP maskBitmap;

    if (NSPlatformGreaterThanOrEqualToWindows2000()) {
        // Cursor with alpha channel, no mask. Win2k and above
        BITMAPV5HEADER bi;
        void *lpBits;
        uint8_t *dibRowBytes;

        ZeroMemory(&bi, sizeof(BITMAPV5HEADER));
        bi.bV5Size = sizeof(BITMAPV5HEADER);
        bi.bV5Width = width;
        bi.bV5Height = -height;
        bi.bV5Planes = 1;
        bi.bV5BitCount = 32;
        bi.bV5Compression = BI_BITFIELDS;
        bi.bV5RedMask = 0x00FF0000;
        bi.bV5GreenMask = 0x0000FF00;
        bi.bV5BlueMask = 0x000000FF;
        bi.bV5AlphaMask = 0xFF000000;

        colorBitmap = CreateDIBSection(displayDC, (BITMAPINFO *) &bi,
                                       DIB_RGB_COLORS, &lpBits, NULL, 0);
        dibRowBytes = lpBits;

        maskBitmap = CreateBitmap(width, height, 1, 1, NULL);
        int row, column;

        for (row = 0; row < height;
             row++, rowBytes += bytesPerRow, dibRowBytes += width * 4) {
            for (column = 0; column < width; column++) {
                dibRowBytes[column * 4] = rowBytes[column * 4];
                dibRowBytes[column * 4 + 1] = rowBytes[column * 4 + 1];
                dibRowBytes[column * 4 + 2] = rowBytes[column * 4 + 2];
                dibRowBytes[column * 4 + 3] = rowBytes[column * 4 + 3];
            }
        }

    } else {
        // This works for versions lower than 2k, not really needed, but here.
        HDC colorDC = CreateCompatibleDC(displayDC);
        HDC maskDC = CreateCompatibleDC(displayDC);

        colorBitmap = CreateCompatibleBitmap(displayDC, width, height);
        maskBitmap = CreateCompatibleBitmap(displayDC, width, height);

        HBITMAP oldColorBitmap = SelectObject(colorDC, colorBitmap);
        HBITMAP oldMaskBitmap = SelectObject(maskDC, maskBitmap);

        int row, column;

        for (row = 0; row < height; row++, rowBytes += bytesPerRow) {
            for (column = 0; column < width; column++) {
                uint8_t b = rowBytes[column * 4];
                uint8_t g = rowBytes[column * 4 + 1];
                uint8_t r = rowBytes[column * 4 + 2];
                uint8_t a = rowBytes[column * 4 + 3];

                if (a < 255) {
                    SetPixel(colorDC, column, row, RGB(r, g, b));
                    SetPixel(maskDC, column, row, RGB(255, 255, 255));
                } else {
                    SetPixel(colorDC, column, row, RGB(r, g, b));
                    SetPixel(maskDC, column, row, RGB(0, 0, 0));
                }
            }
        }
        SelectObject(colorDC, oldColorBitmap);
        SelectObject(maskDC, oldMaskBitmap);
        DeleteDC(colorDC);
        DeleteDC(maskDC);
    }

    ReleaseDC(NULL, displayDC);

    CGContextRelease(context);

    ICONINFO iconInfo;

    iconInfo.fIcon = FALSE;
    iconInfo.hbmMask = maskBitmap;
    iconInfo.hbmColor = colorBitmap;

    _trayIcon = CreateIconIndirect(&iconInfo);

    DeleteObject(colorBitmap);
    DeleteObject(maskBitmap);
}

#endif

#pragma mark Public Methods

- (id) init {
    self = [super init];
    if (self) {
#ifdef WIN32
        _trayIcon = NULL;
        _trayIconID = -1;
        _win32Menu = NULL;
#endif
    }
    return self;
}

- (NSStatusBar *) statusBar {
    return [NSStatusBar systemStatusBar];
}

- (SEL) action {
    return _action;
}
- (void) setAction: (SEL) action {
    _action = action;
}
- (SEL) doubleAction {
    return _doubleAction;
}
- (void) setDoubleAction: (SEL) action {
    _doubleAction = action;
}
- (id) target {
    return _target;
}
- (void) setTarget: (id) target {
    _target = target;
}

- (NSImage *) image {
    return _image;
}

- (void) setImage: (NSImage *) image {
    [_image release];
    _image = nil;
    _image = [image copy];
#ifdef WIN32
    if (_trayIconID <= -1) {
        [self _createTrayIcon];
    }
#else
    [self _ensureTrayWindow];
#endif
}
- (NSImage *) alternateImage {
    return _alternateImage;
}
- (void) setAlternateImage: (NSImage *) image {
#ifndef WIN32
    [_alternateImage release];
    _alternateImage = nil;
    _alternateImage = [image copy];
#endif
}

- (NSString *) title {
    return _title;
}
- (void) setTitle: (NSString *) title {
#ifndef WIN32
    [_title release];
    _title = nil;
    _title = [title copy];
    [self _ensureTrayWindow];
#endif
}
- (void) setToolTip: (NSString *) toolTip {
}
- (NSAttributedString *) attributedTitle {
    return _atrTitle;
}
- (void) setAttributedTitle: (NSAttributedString *) title {
#ifndef WIN32
    [_atrTitle release];
    _atrTitle = nil;
    _atrTitle = [title copy];
#endif
}

- (NSView *) view {
    return _view;
}
- (void) setView: (NSView *) view {
    [_view release];
    _view = nil;
    _view = [view copy];
    // Start capture timer
#ifndef WIN32
    [self _ensureTrayWindow];
#endif
}

- (NSButton *) button {
    if (_button == nil) {
        _button = [[NSButton alloc] initWithFrame: NSMakeRect(0, 0, 0, 0)];
        [_button setButtonType: NSMomentaryLightButton];
        [_button setTarget: _target];
        [_button setAction: _action];
        [self _ensureTrayWindow];
    }

    return _button;
}

#ifndef WIN32
- (void) _trayWindowWillClose: (NSNotification *) note {
    // The system tray removed/destroyed our embedded window (e.g. WM_DELETE
    // on a stale embed). Drop it and re-dock on the next access so the icon
    // does not disappear and the app does not touch a closed window.
    if (_trayWindow != nil) {
        [[NSNotificationCenter defaultCenter]
                removeObserver: self
                          name: NSWindowWillCloseNotification
                        object: _trayWindow];
        // Do NOT release here: the window's _releaseWhenClosed (default YES)
        // already autoreleases it in -close:, and the closing path (e.g. the
        // deferred platformWindowWillClose: perform) may hold another retain.
        // Releasing here double-releases and crashes (SIGEXC in objc_msgSend).
        _trayWindow = nil;
    }
    [self _ensureTrayWindow];
}

- (void) _ensureTrayWindow {
    BOOL newlyCreated = NO;
    if (_trayWindow == nil) {
        // On X11 the status item is a small borderless window that we dock into
        // the system tray (_NET_SYSTEM_TRAY_S0 / XEmbed). The button is its
        // content view, so the normal AppKit drawing machinery renders it.
        CGFloat thickness = [[NSStatusBar systemStatusBar] thickness];
        CGFloat width = _length > 0 ? _length : thickness;
        NSRect frame = NSMakeRect(0, 0, width, thickness);

        _trayWindow = [[NSWindow alloc]
                initWithContentRect: frame
                          styleMask: NSBorderlessWindowMask
                            backing: NSBackingStoreBuffered
                              defer: NO];
        [_trayWindow setLevel: NSStatusWindowLevel];
        [_trayWindow setHasShadow: NO];
        [[NSNotificationCenter defaultCenter]
                addObserver: self
                   selector: @selector(_trayWindowWillClose:)
                       name: NSWindowWillCloseNotification
                     object: _trayWindow];
        newlyCreated = YES;
    }

    // Refresh the content view. The button may be created after the window
    // (e.g. when a setter docks the item before the button is first requested).
    BOOL contentViewChanged = NO;
    if (_view != nil && [_trayWindow contentView] != _view) {
        [_view setFrame: [_trayWindow frame]];
        [_trayWindow setContentView: _view];
        contentViewChanged = YES;
    } else if (_button != nil && [_trayWindow contentView] != _button) {
        [_button setFrame: [_trayWindow frame]];
        [_trayWindow setContentView: _button];
        contentViewChanged = YES;
    }

    if (newlyCreated) {
        X11Window *platformWindow =
                (X11Window *) [_trayWindow platformWindow];
        [platformWindow dockInSystemTray];

        [_trayWindow orderFront: nil];
    } else if (contentViewChanged) {
        [_trayWindow setViewsNeedDisplay: YES];
        [_trayWindow displayIfNeeded];
    }
}
#endif

- (BOOL) highlightMode {
    return _highlightMode;
}
- (void) setHighlightMode: (BOOL) flag {
    _highlightMode = flag;
}

- (BOOL) isEnabled {
    return _enabled;
}
- (void) setEnabled: (BOOL) flag {
    _enabled = flag;
}

- (CGFloat) length {
#ifdef WIN32
    int traySizeX = GetSystemMetrics(SM_CXSMICON);
    int traySizeY = GetSystemMetrics(SM_CYSMICON);
    // Make sure we return a value that will ensure icon will not be clipped
    // with non-standard tray icon sizes
    if (traySizeX > traySizeY) {
        return traySizeY;
    } else {
        return traySizeX;
    }
#endif
    return _length;
}
- (void) setLength: (CGFloat) len {
#ifndef WIN32
    _length = len;
    [self _ensureTrayWindow];
#endif
}

- (NSMenu *) menu {
    return _menu;
}
- (void) setMenu: (NSMenu *) menu {
    [_menu release];
    _menu = nil;
    _menu = [menu copy];
#ifndef WIN32
    [self _ensureTrayWindow];
#endif
#ifdef WIN32
    // Preprocess Menu into HMENU ready for Win32 Events
    if (_win32Menu == NULL) {
        _win32Menu = CreatePopupMenu();
    }
    if (_win32Menu) {
        for (int i = 0; i < [_menu itemArray].count; i++) {
            [self _w32loadMenuItem: [[_menu itemArray] objectAtIndex: i]
                    withIdentifier: i
                          intoMenu: _win32Menu];
        }
    }
#endif
}

- (void) popUpStatusItemMenu: (NSMenu *) menu {
}

- (void) _showContextMenu {
#ifdef WIN32
    if (_win32Menu) {
        POINT pt;
        GetCursorPos(&pt);
        Win32Window *window = [[NSStatusBar systemStatusBar] fakeWindow];
        SetForegroundWindow([window windowHandle]);
        TrackPopupMenu(_win32Menu, TPM_RIGHTBUTTON, pt.x, pt.y, 0,
                       [window windowHandle], NULL);
    } else {
        NSLog(@"win32Menu is null!");
    }
#endif
}

- (NSInteger) sendActionOn: (NSInteger) mask {
    int previousMask = _actionMask;
    _actionMask = mask;
    return previousMask;
}

- (void) drawStatusBarBackgroundInRect: (NSRect) rect
                         withHighlight: (BOOL) highlight
{
    NSUnimplementedMethod();
}

@end
