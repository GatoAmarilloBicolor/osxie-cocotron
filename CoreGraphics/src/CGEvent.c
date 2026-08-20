#include <CoreGraphics/CGEvent.h>
#include <X11/Xlib.h>
#include <X11/extensions/XTest.h>
#include <stdio.h>
#include <stdarg.h>

CGError CGPostMouseEvent(CGPoint mouseCursorPosition,
    boolean_t updateMouseCursorPosition, CGButtonCount buttonCount,
    boolean_t mouseButtonDown, ...)
{
    Display* dpy = XOpenDisplay(NULL);
    if (!dpy)
        return kCGErrorFailure;

    if (updateMouseCursorPosition)
        XTestFakeMotionEvent(dpy, -1, (int)mouseCursorPosition.x,
            (int)mouseCursorPosition.y, CurrentTime);

    if (buttonCount > 0) {
        va_list args;
        va_start(args, mouseButtonDown);
        for (CGButtonCount i = 0; i < buttonCount; i++) {
            boolean_t down = va_arg(args, int);
            unsigned int btn = (i == 0) ? Button1 : (i == 1) ? Button3 : (i == 2) ? Button2 : (Button1 + i);
            XTestFakeButtonEvent(dpy, btn, down ? True : False, CurrentTime);
        }
        va_end(args);
    }

    XFlush(dpy);
    XCloseDisplay(dpy);
    return kCGErrorSuccess;
}
