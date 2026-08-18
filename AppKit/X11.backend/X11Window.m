/* Copyright (c) 2008 Johannes Fortmann

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

#import <AppKit/NSMenuWindow.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSPopUpWindow.h>
#import <AppKit/NSRaise.h>
#import <AppKit/NSWindow.h>
#import <execinfo.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSException.h>
#import <Foundation/NSMutableData.h>
#import <Foundation/NSProcessInfo.h>
#import <Onyx2D/O2BitmapContext.h>
#import <Onyx2D/O2Context_builtin_FT.h>
#import <Onyx2D/O2ImageSource.h>
#import <Onyx2D/O2Surface.h>
#import <QuartzCore/CAWindowOpenGLContext.h>

#import "X11Display.h"
#import "X11SubWindow.h"
#import "X11Window.h"
#import <X11/Xatom.h>
#import <X11/Xutil.h>
#import <unistd.h>
#import <string.h>

@implementation X11Window

+ (Visual *) visual {
    static Visual *ret = NULL;

    if (!ret) {
        int visuals_matched, i;
        XVisualInfo match = {0};
        Display *dpy = [(X11Display *) [NSDisplay currentDisplay] display];

        XVisualInfo *info = XGetVisualInfo(dpy, 0, &match, &visuals_matched);

        for (i = 0; i < visuals_matched; i++) {
            if (info[i].depth == 32 && (info[i].red_mask == 0xff0000 &&
                                        info[i].green_mask == 0x00ff00 &&
                                        info[i].blue_mask == 0x0000ff)) {
                ret = info[i].visual;
            }
        }
        XFree(info);
        if (!ret)
            ret = DefaultVisual(dpy, DefaultScreen(dpy));
    }

    return ret;
}

static NSData *makeWindowIcon() {
    static NSMutableData *res;

    if (res != nil)
        return res;

    // Figure out the path.
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *name = [bundle objectForInfoDictionaryKey: @"CFBundleIconFile"];
    if (name == nil || [name length] == 0)
        return nil;
    NSString *path = [bundle pathForImageResource: name];
    if (path == nil) {
        NSLog(@"Cannot find an icon file named %@", name);
        return nil;
    }
    NSURL *url = [NSURL fileURLWithPath: path];

    O2ImageSource *imageSource = [O2ImageSource newImageSourceWithURL: url
                                                              options: nil];
    if (imageSource == nil) {
        NSLog(@"Cannot parse the icon");
        return nil;
    }

    res = [[NSMutableData alloc] initWithCapacity: 32 * 32 * 4 + 2];
    O2ColorSpace *colorSpace = O2ColorSpaceCreateDeviceRGB();

    // Go over the images, turning them into the required format
    // and appending them to res.
    for (NSUInteger i = 0; i < [imageSource count]; i++) {

        O2Image *image = [imageSource createImageAtIndex: i options: nil];
        NSUInteger width = O2ImageGetWidth(image);
        NSUInteger height = O2ImageGetHeight(image);

        // Render the image in ARGB.
        O2BitmapContext *context = (O2BitmapContext *) O2BitmapContextCreate(
                NULL, width, height, 8, width * 4, colorSpace,
                kO2ImageAlphaPremultipliedFirst | kO2BitmapByteOrder32Host);

        [context drawImage: image inRect: O2RectMake(0, 0, width, height)];
        int *imageData = O2BitmapContextGetData(context);

        // Convert to the format accepted by Xlib.
        NSMutableData *data =
                [NSMutableData dataWithLength: width * height * sizeof(long)];
        long *dataPtr = (long *) [data mutableBytes];
        int count = width * height;
        for (int i = 0; i < count; i++) {
            dataPtr[i] = imageData[i];
        }

        struct {
            long w, h;
        } size = {width, height};
        [res appendBytes: &size length: sizeof(size)];
        [res appendData: data];

        [context release];
        [image release];
    }

    [colorSpace release];
    [imageSource release];

    return res;
}

- (void) setWindowIcon {

    NSData *data = makeWindowIcon();

    if (data == nil)
        return;

    XChangeProperty(
            _display, _window, XInternAtom(_display, "_NET_WM_ICON", False),
            XInternAtom(_display, "CARDINAL", False), 32, PropModeReplace,
            [data bytes], [data length] / sizeof(long));
}

- (instancetype) initWithDelegate: (NSWindow *) delegate {
    _delegate = delegate;
    _level = [delegate level];
    _styleMask = [delegate styleMask];
    _backingType = (CGSBackingStoreType)[delegate backingType];
    _deviceDictionary = [NSMutableDictionary new];

    X11Display* x11disp = (X11Display *) [NSDisplay currentDisplay];
    _display = [x11disp display];

    _frame = [self transformFrame: [delegate frame]];
    BOOL isPanel = [delegate isKindOfClass: [NSPanel class]];
    // Doc-modals (alert sheets/dialogs) must stay WM-managed so they receive
    // events. The borderless conversion only drops the style bits; it must
    // NOT imply override_redirect, or KWin never manages the window and the
    // modal run loop waits forever for a click that never arrives.
    BOOL isDocModalPanel = isPanel && (_styleMask & NSDocModalWindowMask);
    if (isDocModalPanel)
        _styleMask = NSBorderlessWindowMask;
    // TODO: get rid of these glX calls
    GLint att[] = {GLX_RGBA,
                   GLX_DOUBLEBUFFER,
                   GLX_RED_SIZE,
                   4,
                   GLX_GREEN_SIZE,
                   4,
                   GLX_BLUE_SIZE,
                   4,
                   GLX_DEPTH_SIZE,
                   4,
                   None};

    int screen = DefaultScreen(_display);

    if ((_visualInfo = glXChooseVisual(_display, screen, att)) == NULL) {
        NSLog(@"glXChooseVisual failed at %s %d", __FILE__, __LINE__);
    }

    Colormap cmap =
            XCreateColormap(_display, RootWindow(_display, _visualInfo->screen),
                            _visualInfo->visual, AllocNone);

    if (cmap < 0) {
        NSLog(@"XCreateColormap failed");
        [self release];
        return nil;
    }

    XSetWindowAttributes xattr;
    unsigned long xattr_mask;
    xattr.override_redirect = (_styleMask == NSBorderlessWindowMask &&
                               !isDocModalPanel) ? True : False;
    xattr_mask = CWOverrideRedirect | CWColormap;
    xattr.colormap = cmap;

    _window = XCreateWindow(
            _display, DefaultRootWindow(_display), _frame.origin.x,
            _frame.origin.y, _frame.size.width, _frame.size.height, 0,
            (_visualInfo == NULL) ? CopyFromParent : _visualInfo->depth,
            InputOutput,
            (_visualInfo == NULL) ? CopyFromParent : _visualInfo->visual,
            xattr_mask, &xattr);

    [self syncDelegateProperties];

    Atom atm = XInternAtom(_display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(_display, _window, &atm, 1);

    const char *name = [[[NSProcessInfo processInfo] processName] UTF8String];

    XClassHint classHint = {.res_name = (char *) name,
                            .res_class = (char *) name};
    XSetClassHint(_display, _window, &classHint);

    XSetWindowBackgroundPixmap(_display, _window, None);

    _isModal = [delegate isSheet] || [NSApp modalWindow] == delegate;
    // FIXME: There should be no need for this.
    _isModal |= [delegate isKindOfClass: NSClassFromString(@"NSSavePanel")];

    const char *type = [self _windowTypeString];
    BOOL isTransient = strcmp(type, "_NET_WM_WINDOW_TYPE_NORMAL") != 0;
    [self syncWindowTypeAndState];

    if (isTransient && [NSApp mainWindow]) {
        X11Window *mainWindow =
                (X11Window *) [[NSApp mainWindow] platformWindow];
        XSetTransientForHint(_display, _window, [mainWindow windowHandle]);
    }

    _xic = XCreateIC(x11disp->_xim,
        XNInputStyle, XIMPreeditNothing | XIMStatusNothing,
        XNClientWindow, _window,
        XNFocusWindow, _window,
        NULL);

    _cglWindow = CGLGetWindow((void *) _window);

    [(X11Display *) [NSDisplay currentDisplay] setWindow: self forID: _window];

    // FIXME: Move this call into setStyleMaskInternal below!
    if (_styleMask == NSBorderlessWindowMask) {
        [[self class] removeDecorationForWindow: _window onDisplay: _display];
    }
    [self setStyleMaskInternal: _styleMask force: YES];

    [self setWindowIcon];

    if (getenv("OSXIE_TRACE_WINDOW_LIFE"))
        fprintf(stderr, "[LIFE] X11Window init: self=%p xid=%lu delegate=%p\n",
                self, (unsigned long) _window, _delegate);

    return self;
}

- (void) dealloc {
    if (getenv("OSXIE_TRACE_WINDOW_LIFE"))
        fprintf(stderr,
                "[LIFE] X11Window dealloc: self=%p xid=%lu delegate=%p\n",
                self, (unsigned long) _window, _delegate);
    [self invalidate];
    [_deviceDictionary release];
    [super dealloc];
}

- (NSUInteger) styleMask {
    return _styleMask;
}

- (void) setStyleMaskInternal: (NSUInteger) mask force: (BOOL) force {
    if (_window == 0) {
        _styleMask = mask;
        return;
    }
    _styleMask = mask;
    if (force || (mask & NSWindowStyleMaskResizable) !=
                         (_styleMask & NSWindowStyleMaskResizable)) {
        XSizeHints *sh = XAllocSizeHints();
        if (mask & NSWindowStyleMaskResizable) {
            // Make resizable
            sh->flags = 0;
        } else {
            // Make non-resizable
            sh->flags = PMinSize | PMaxSize;
            sh->min_width = sh->max_width = _frame.size.width;
            sh->min_height = sh->max_height = _frame.size.height;
        }

        XSetWMSizeHints(_display, _window, sh, XA_WM_NORMAL_HINTS);
        XFree(sh);
    }

    if (!_mapped) {
        [self syncWindowTypeAndState];
    } else if (force || ((mask & NSWindowStyleMaskFullScreen) !=
                         (_styleMask & NSWindowStyleMaskFullScreen))) {
        XClientMessageEvent event = {0};
        event.type = ClientMessage;
        event.window = _window;
        event.message_type = XInternAtom(_display, "_NET_WM_STATE", False);
        event.format = 32;
        event.data.l[0] = (mask & NSWindowStyleMaskFullScreen) ? 1 : 2;
        event.data.l[1] =
                (long) XInternAtom(_display, "_NET_WM_STATE_FULLSCREEN", False);
        event.data.l[3] = 1;
        XSendEvent(_display, DefaultRootWindow(_display), False,
                   SubstructureNotifyMask | SubstructureRedirectMask,
                   (XEvent *) &event);
    }
}

- (void) setStyleMask: (NSUInteger) mask {
    [self setStyleMaskInternal: mask force: NO];
}

- (const char *) _windowTypeString {
    if (_isModal) {
        return "_NET_WM_WINDOW_TYPE_DIALOG";
    }
    if ([_delegate isKindOfClass: [NSMenuWindow class]] ||
        [_delegate isKindOfClass: [NSPopUpWindow class]]) {
        return "_NET_WM_WINDOW_TYPE_MENU";
    }
    // Bars (menu bar / dock), status items and tray applets live at or above
    // kCGMainMenuWindowLevel; advertise them as DOCK so the WM never treats
    // them as ordinary documents (no taskbar entry, no pager, stays on top).
    if (_level >= kCGMainMenuWindowLevel) {
        return "_NET_WM_WINDOW_TYPE_DOCK";
    }
    if (_level >= kCGFloatingWindowLevel ||
        [_delegate isKindOfClass: [NSPanel class]]) {
        return "_NET_WM_WINDOW_TYPE_UTILITY";
    }
    return "_NET_WM_WINDOW_TYPE_NORMAL";
}

// Central place for the _NET_WM_WINDOW_TYPE and _NET_WM_STATE properties. The
// window type is re-derived from _level/_styleMask every time, so calling this
// from setLevel:/setStyleMask: keeps bars, applets and tray items classified
// correctly even when they are re-styled after creation.
- (void) syncWindowTypeAndState {
    if (_window == 0) {
        return;
    }

    long windowTypeAtom =
            (long) XInternAtom(_display, [self _windowTypeString], False);
    XChangeProperty(_display, _window,
                    XInternAtom(_display, "_NET_WM_WINDOW_TYPE", False),
                    XA_ATOM, 32, PropModeReplace,
                    (const unsigned char *) &windowTypeAtom, 1);

    long states[8];
    int states_cnt = 0;
    if (_isModal) {
        states[states_cnt++] =
                (long) XInternAtom(_display, "_NET_WM_STATE_MODAL", False);
    }
    if (_level >= kCGMainMenuWindowLevel) {
        states[states_cnt++] =
                (long) XInternAtom(_display, "_NET_WM_STATE_SKIP_TASKBAR", False);
        states[states_cnt++] =
                (long) XInternAtom(_display, "_NET_WM_STATE_SKIP_PAGER", False);
        states[states_cnt++] =
                (long) XInternAtom(_display, "_NET_WM_STATE_STICKY", False);
        states[states_cnt++] =
                (long) XInternAtom(_display, "_NET_WM_STATE_ABOVE", False);
    }
    if (_styleMask & NSWindowStyleMaskFullScreen) {
        states[states_cnt++] = (long) XInternAtom(
                _display, "_NET_WM_STATE_FULLSCREEN", False);
    }
    XChangeProperty(_display, _window,
                    XInternAtom(_display, "_NET_WM_STATE", False), XA_ATOM,
                    32, PropModeReplace, (const unsigned char *) states,
                    states_cnt);
}

+ (void) removeDecorationForWindow: (Window) w onDisplay: (Display *) dpy {
    return;
    struct {
        unsigned long flags;
        unsigned long functions;
        unsigned long decorations;
        long input_mode;
        unsigned long status;
    } hints = {
            2, 0, 0, 0, 0,
    };
    XChangeProperty(dpy, w, XInternAtom(dpy, "_MOTIF_WM_HINTS", False),
                    XInternAtom(dpy, "_MOTIF_WM_HINTS", False), 32,
                    PropModeReplace, (const unsigned char *) &hints,
                    sizeof(hints) / sizeof(long));
}

- (void) ensureMapped {
    if (!_mapped && !_embedded) {
        XMapWindow(_display, _window);
        _mapped = YES;
    }
}

- (void) dockInSystemTray {
    Atom selectionAtom = XInternAtom(_display, "_NET_SYSTEM_TRAY_S0", False);
    Window trayWindow = XGetSelectionOwner(_display, selectionAtom);
    if (trayWindow == None) {
        if (getenv("OSXIE_TRACE_WINDOW_LIFE"))
            fprintf(stderr, "[TRACE] dockInSystemTray: no tray selection owner\n");
        return;
    }

    // XEmbed handshake: declare we're an XEmbed client (version 0, flags 0).
    // The window must stay UNMAPPED until the tray reparents it — mapping a
    // top-level window before embedding makes KWin/xembedsniproxy destroy it.
    long xembedInfo[2] = {0, 0};
    XChangeProperty(_display, _window,
                    XInternAtom(_display, "_XEMBED_INFO", False),
                    XInternAtom(_display, "_XEMBED_INFO", False), 32,
                    PropModeReplace, (unsigned char *) xembedInfo, 2);

    // Ask the tray to dock us: _NET_SYSTEM_TRAY_OPCODE, SYSTEM_TRAY_REQUEST_DOCK=0
    XClientMessageEvent request = {0};
    request.type = ClientMessage;
    request.window = trayWindow;
    request.message_type =
            XInternAtom(_display, "_NET_SYSTEM_TRAY_OPCODE", False);
    request.format = 32;
    request.data.l[0] = CurrentTime;
    request.data.l[1] = 0; // SYSTEM_TRAY_REQUEST_DOCK
    request.data.l[2] = (long) _window;
    request.data.l[3] = 0;
    request.data.l[4] = 0;

    if (getenv("OSXIE_TRACE_WINDOW_LIFE"))
        fprintf(stderr, "[TRACE] dockInSystemTray: dock request to %lu for window %lu\n",
                trayWindow, (unsigned long) _window);
    XSendEvent(_display, trayWindow, False, NoEventMask,
               (XEvent *) &request);
    XSync(_display, False);

    // Wait for the tray to reparent us (poll for up to ~3s). Only then is it
    // safe to map, otherwise the window flashes at (0,0) or gets destroyed.
    BOOL reparented = NO;
    for (int i = 0; i < 60; i++) {
        Window root, parent, *children;
        unsigned int nchild;
        if (XQueryTree(_display, _window, &root, &parent, &children, &nchild)) {
            if (children)
                XFree(children);
            if (parent != root && parent != None) {
                reparented = YES;
                break;
            }
        }
        usleep(50000);
    }
    if (reparented) {
        // We are embedded: the tray owns our placement. Never map/raise/
        // restack us against the root afterwards, or KWin un-embeds and
        // destroys the window.
        _embedded = YES;
        _mapped = YES;
    }
    if (getenv("OSXIE_TRACE_WINDOW_LIFE"))
        fprintf(stderr, "[TRACE] dockInSystemTray: reparented=%d\n", reparented);

    [self ensureMapped];
}

- (void) showWindowWithoutActivation {
    [self ensureMapped];
}

- (void) setDelegate: delegate {
    _delegate = delegate;
    [self syncDelegateProperties];
}

- delegate {
    return _delegate;
}

- (void) syncDelegateProperties {
    if (_window == 0) {
        return;
    }
    long mask = KeyPressMask | KeyReleaseMask | ExposureMask |
                StructureNotifyMask | EnterWindowMask | LeaveWindowMask |
                ButtonPressMask | ButtonReleaseMask | ButtonMotionMask |
                VisibilityChangeMask | FocusChangeMask |
                SubstructureRedirectMask;

    if ([_delegate acceptsMouseMovedEvents]) {
        mask |= PointerMotionMask;
    }
    XSelectInput(_display, _window, mask);

    // TODO: background color
}

- (void) invalidate {
    if (getenv("OSXIE_TRACE_WINDOW_LIFE")) {
        fprintf(stderr,
                "[LIFE] X11Window invalidate: self=%p xid=%lu delegate=%p "
                "context=%p caContext=%p\n",
                self, (unsigned long) _window, _delegate, _context,
                _caContext);
        void *bt[32];
        int n = backtrace(bt, 32);
        char **syms = backtrace_symbols(bt, n);
        for (int i = 0; i < n && i < 14; i++)
            fprintf(stderr, "  %s\n", syms[i]);
        free(syms);
    }
    // This is essentially dealloc; we release our contexts
    // and windows, but unlike dealloc, this method can be called
    // several times, so set everything to nil/NULL/0.
    [_context release];
    _context = nil;

    [_delegate platformWindowDidInvalidateCGContext: self];
    _delegate = nil;

    [_caContext release];
    _caContext = nil;

    if (_cglContext != NULL) {
        CGLReleaseContext(_cglContext);
        _cglContext = NULL;
    }
    if (_cglWindow != NULL) {
        CGLDestroyWindow(_cglWindow);
        _cglWindow = NULL;
    }

    if (_window) {
        XDestroyIC(_xic);

        [(X11Display *) [NSDisplay currentDisplay] setWindow: nil
                                                       forID: _window];
        XDestroyWindow(_display, _window);
        _window = 0;
    }
}

- (Window) windowHandle {
    return _window;
}

- (O2Context *) createCGContextIfNeeded {
    if (_context == nil) {
        if (getenv("OSXIE_TRACE_FLUSH"))
            fprintf(stderr, "[TRACE] createCGContextIfNeeded window=%lu size=%zux%zu\n",
                    (unsigned long) _window, (size_t) _frame.size.width,
                    (size_t) _frame.size.height);
        O2ColorSpaceRef colorSpace = O2ColorSpaceCreateDeviceRGB();
        O2Surface *surface = [[O2Surface alloc]
                   initWithBytes: NULL
                           width: _frame.size.width
                          height: _frame.size.height
                bitsPerComponent: 8
                     bytesPerRow: 0
                      colorSpace: colorSpace
                      bitmapInfo: kO2ImageAlphaPremultipliedFirst |
                                  kO2BitmapByteOrder32Little];
        O2ColorSpaceRelease(colorSpace);
        _context = [[O2Context_builtin_FT alloc] initWithSurface: surface
                                                         flipped: NO];
    }
    return _context;
}

- (O2Context *) cgContext {
    return [self createCGContextIfNeeded];
}

- (void) invalidateContextWithNewSize: (NSSize) size
                         forceRebuild: (BOOL) forceRebuild
{
    if (!NSEqualSizes(_frame.size, size) || forceRebuild) {
        _frame.size = size;
        if (![_context resizeWithNewSize: size]) {
            [_context release];
            _context = nil;
            [_delegate platformWindowDidInvalidateCGContext: self];
        }
    }
}

- (void) invalidateContextWithNewSize: (NSSize) size {
    [self invalidateContextWithNewSize: size forceRebuild: NO];
}

- (void) setTitle: (NSString *) title {
    if (_window == 0) {
        return;
    }
    XTextProperty prop;
    const char *text = [title cString];
    XStringListToTextProperty((char **) &text, 1, &prop);
    XSetWMName(_display, _window, &prop);
}

- (void) setFrame: (O2Rect) frame {
    if (_window == 0) {
        return;
    }
    frame = [self transformFrame: frame];
    XMoveResizeWindow(_display, _window, frame.origin.x, frame.origin.y,
                      frame.size.width, frame.size.height);
    [self invalidateContextWithNewSize: frame.size];
    _frame = frame;
}

- (void) setHasShadow: (BOOL) value {
    _hasShadow = value;
}

- (void) setLevel: (int) value {
    _level = value;
    [self syncWindowTypeAndState];
}

- (void) setOpaque: (BOOL) value {
    _isOpaque = value;
}

- (void) sheetOrderFrontFromFrame: (NSRect) frame
                      aboveWindow: (CGWindow *) aboveWindow
{
    [self setFrame: frame];
    [self placeAboveWindow: [aboveWindow windowNumber]];
}

- (void) sheetOrderOutToFrame: (NSRect) frame {
    [self hideWindow];
}

- (void) showWindowForAppActivation: (O2Rect) frame {
    [self showWindowWithoutActivation];
}

- (void) hideWindowForAppDeactivation: (O2Rect) frame {
    /* Ignored */
}

- (void) hideWindow {
    if (_embedded || _window == 0) {
        return;
    }
    XUnmapWindow(_display, _window);
    _mapped = NO;
}

- (void) placeAboveWindow: (NSInteger) otherNumber {
    if (_embedded || _window == 0) {
        return;
    }
    X11Window *other = [X11Window windowWithWindowNumber: otherNumber];
    [self ensureMapped];

    if (!other) {
        XRaiseWindow(_display, _window);
    } else {
        Window w[2] = {_window, other->_window};
        XRestackWindows(_display, w, 1);
    }
}

- (void) placeBelowWindow: (NSInteger) otherNumber {
    if (_embedded || _window == 0) {
        return;
    }
    X11Window *other = [X11Window windowWithWindowNumber: otherNumber];
    [self ensureMapped];

    if (!other) {
        XLowerWindow(_display, _window);
    } else {
        Window w[2] = {other->_window, _window};
        XRestackWindows(_display, w, 1);
    }
}

- (void) makeKey {
    if (_embedded || _window == 0) {
        return;
    }
    [self ensureMapped];
    XRaiseWindow(_display, _window);

    // Ask the window manager to give us keyboard focus. XRaiseWindow alone
    // only restacks; KWin will not deliver key events unless the window is
    // the active one (_NET_ACTIVE_WINDOW). Send the EWMH client message and
    // fall back to XSetInputFocus for windows the WM refuses to manage
    // (e.g. override-redirect panels).
    XClientMessageEvent event = {0};
    event.type = ClientMessage;
    event.window = DefaultRootWindow(_display);
    event.message_type = XInternAtom(_display, "_NET_ACTIVE_WINDOW", False);
    event.format = 32;
    event.data.l[0] = 1; // source indication: 1 = application
    event.data.l[1] = CurrentTime;
    event.data.l[2] = (long) _window;
    event.data.l[3] = 0;
    event.data.l[4] = 0;
    XSendEvent(_display, event.window, False,
               SubstructureRedirectMask | SubstructureNotifyMask,
               (XEvent *) &event);

    XSetInputFocus(_display, _window, RevertToParent, CurrentTime);
}

- (void) makeMain {
}

- (void) captureEvents {
}

- (void) miniaturize {
    if (_embedded || _window == 0) {
        return;
    }
    XIconifyWindow(_display, _window, DefaultScreen(_display));
}

- (void) deminiaturize {
    if (_embedded || _window == 0) {
        return;
    }
    XRaiseWindow(_display, _window);
}

- (BOOL) isMiniaturized {
    if (_window == 0 || _embedded) {
        return NO;
    }
    Atom wmState = XInternAtom(_display, "_NET_WM_STATE", FALSE);
    Atom hiddenState = XInternAtom(_display, "_NET_WM_STATE_HIDDEN", FALSE);

    Atom type;
    int format;
    unsigned long nItem, bytesAfter;
    unsigned char *properties = NULL;
    BOOL rv = NO;

    if (XGetWindowProperty(_display, _window, wmState, 0, (~0L), FALSE, XA_ATOM,
                           &type, &format, &nItem, &bytesAfter,
                           &properties) == Success) {
        Atom *atoms = (Atom *) properties;
        for (int i = 0; i < nItem; i++) {
            if (atoms[i] == hiddenState) {
                rv = YES;
                break;
            }
        }
        XFree(properties);
    }

    return rv;
}

- (CGLContextObj) cglContext {
    return _cglContext;
}

- (void) createCGLContextObjIfNeeded {
    if (_cglContext == NULL) {
        CGLError error;

        if ((error = CGLCreateContext(NULL, NULL, &_cglContext)) !=
            kCGLNoError) {
            NSLog(@"CGLCreateContext failed at %s %d with error %d", __FILE__,
                  __LINE__, error);

            [NSException raise: NSGenericException
                        format: @"Failed to create GL context, CGL error %d",
                                error];
        }
        if ((error = CGLContextMakeCurrentAndAttachToWindow(
                     _cglContext, _cglWindow)) != kCGLNoError)
            NSLog(@"CGLContextMakeCurrentAndAttachToWindow failed with error "
                  @"%d",
                  error);
    }
    if (_cglContext != nil && _caContext == nil) {
        _caContext =
                [[CAWindowOpenGLContext alloc] initWithCGLContext: _cglContext];
    }
}

- (void) openGLFlushBuffer {
    CGLError error;

    CGLContextObj prevContext = CGLGetCurrentContext();

    [self createCGLContextObjIfNeeded];
    if (_caContext == nil)
        return;

    O2Surface *surface = [_context surface];
    size_t width = O2ImageGetWidth(surface);
    size_t height = O2ImageGetHeight(surface);

    [_caContext prepareViewportWidth: width height: height];
    [_caContext renderSurface: surface];

    glFlush();
    CGLFlushDrawable(_cglContext);

    CGLSetCurrentContext(prevContext);
}

- (void) flushBuffer {
    if (getenv("OSXIE_TRACE_FLUSH"))
        fprintf(stderr, "[TRACE] flushBuffer window=%lu context=%p\n",
                (unsigned long) _window, _context);
    if (_context == nil)
        return;
    O2ContextFlush(_context);
    [self softwareFlushToX];
}

- (void) softwareFlushToX {
    if (_context == nil || _window == 0)
        return;
    O2Surface *surface = [_context surface];
    if (surface == nil)
        return;
    size_t w = O2SurfaceGetWidth(surface);
    size_t h = O2SurfaceGetHeight(surface);
    if (w == 0 || h == 0)
        return;
    void *bytes = O2SurfaceGetPixelBytes(surface);
    size_t stride = O2SurfaceGetBytesPerRow(surface);
    if (bytes == NULL)
        return;

    if (getenv("OSXIE_TRACE_FLUSH")) {
        size_t nonblack = 0;
        for (size_t yy = 0; yy < h; yy++) {
            const unsigned char *row = (const unsigned char *)bytes + yy * stride;
            for (size_t xx = 0; xx < w; xx++) {
                if (row[xx*4] != 0 || row[xx*4+1] != 0 || row[xx*4+2] != 0) {
                    nonblack++;
                    break;
                }
            }
        }
        fprintf(stderr, "[TRACE] flushBuffer window=%lu size=%zux%zu nonblack_rows=%zu\n",
                (unsigned long) _window, w, h, nonblack);
    }

    XWindowAttributes attrs;
    if (!XGetWindowAttributes(_display, _window, &attrs))
        return;
    int depth = attrs.depth;
    Visual *vis = attrs.visual;

    size_t bufferStride = w * 4;
    unsigned char *buf = malloc(bufferStride * h);
    if (buf == NULL)
        return;

    // Surface is premultiplied ARGB, host byte order -> memory bytes are
    // b,g,r,a. Pack as straight-alpha XRGB (a in top byte, 0xFF = opaque).
    for (size_t y = 0; y < h; y++) {
        const unsigned char *src = (const unsigned char *)bytes + y * stride;
        unsigned char *dst = buf + y * bufferStride;
        for (size_t x = 0; x < w; x++) {
            dst[0] = src[0]; // b
            dst[1] = src[1]; // g
            dst[2] = src[2]; // r
            dst[3] = 0xFF;   // a
            dst += 4;
            src += 4;
        }
    }

    // Build the XImage by hand so we fully control buffer ownership:
    // XFree(img) frees only the struct, free(buf) frees the pixels exactly
    // once (XCreateImage/XDestroyImage manage the pixel buffer themselves and
    // crashed with a heap double-free in this environment).
    XImage img;
    memset(&img, 0, sizeof(img));
    img.width = w;
    img.height = h;
    img.xoffset = 0;
    img.format = ZPixmap;
    img.data = (char *) buf;
    img.byte_order = LSBFirst;
    img.bitmap_unit = 32;
    img.bitmap_bit_order = LSBFirst;
    img.bitmap_pad = 32;
    img.depth = depth;
    img.bytes_per_line = bufferStride;
    img.bits_per_pixel = 32;
    img.red_mask = vis->red_mask;
    img.green_mask = vis->green_mask;
    img.blue_mask = vis->blue_mask;
    img.obdata = NULL;

    GC gc = XCreateGC(_display, _window, 0, NULL);
    XPutImage(_display, _window, gc, &img, 0, 0, 0, 0, w, h);
    XFreeGC(_display, gc);
    XFlush(_display);
    free(buf);
}

- (void) setLastKnownCursorPosition: (CGPoint) point {
    _lastMotionPos = [self transformPoint: point];
}

- (NSPoint) mouseLocationOutsideOfEventStream {
    return [self transformPoint: _lastMotionPos];
}

- (O2Rect) frame {
    return [self transformFrame: _frame];
}

static int ignoreBadWindow(Display *display, XErrorEvent *errorEvent) {
    if (errorEvent->error_code == BadWindow)
        return 0;
    char buf[512];
    XGetErrorText(display, errorEvent->error_code, buf, 512);
    [NSException raise: NSInternalInconsistencyException
                format: @"X11 error: %s", buf];
    return 0;
}

- (void) frameChanged {
    XErrorHandler previousHandler = XSetErrorHandler(ignoreBadWindow);
    @try {
        Window root, parent;
        Window window = _window;
        int x, y;
        unsigned int w, h, d, b, nchild;
        Window *children;
        O2Rect rect = NSZeroRect;
        // recursively get geometry to get absolute position
        BOOL success = YES;
        while (window && success) {
            XGetGeometry(_display, window, &root, &x, &y, &w, &h, &b, &d);
            success = XQueryTree(_display, window, &root, &parent, &children,
                                 &nchild);
            if (children)
                XFree(children);

            // first iteration: save our own w, h
            if (window == _window)
                rect = NSMakeRect(0, 0, w, h);
            rect.origin.x += x;
            rect.origin.y += y;
            window = parent;
        };

        [self invalidateContextWithNewSize: rect.size];
        _frame = rect;
    } @finally {
        XSetErrorHandler(previousHandler);
    }
}

- (Visual *) visual {
    return DefaultVisual(_display, DefaultScreen(_display));
}

- (Drawable) drawable {
    return _window;
}

- (void) addEntriesToDeviceDictionary: (NSDictionary *) entries {
    [_deviceDictionary addEntriesFromDictionary: entries];
}

- (O2Rect) transformFrame: (O2Rect) frame {
    return NSMakeRect(frame.origin.x,
                      DisplayHeight(_display, DefaultScreen(_display)) -
                              frame.origin.y - frame.size.height,
                      fmax(frame.size.width, 1.0),
                      fmax(frame.size.height, 1.0));
}

- (NSPoint) transformPoint: (NSPoint) pos; {
    return NSMakePoint(pos.x, _frame.size.height - pos.y);
}

- (X11SubWindow *) createSubWindowWithFrame: (CGRect) frame {
    return [[[X11SubWindow alloc] initWithParentWindow: self
                                                 frame: frame] autorelease];
}

@end
