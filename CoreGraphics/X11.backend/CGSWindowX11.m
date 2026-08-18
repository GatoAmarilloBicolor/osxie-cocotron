/*
 This file is part of Osxie.

 Copyright (C) 2020 Lubos Dolezel

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
#import "CGSWindowX11.h"
#import "CGSConnectionX11.h"
#import "CGSSurfaceX11.h"
#import <CoreGraphics/CGSConnection.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSString.h>
#import <X11/Xutil.h>
#import <X11/Xatom.h>
#import <X11/extensions/Xcomposite.h>

static bool osxieCaptureTraceEnabled(void)
{
	static int enabled = -1;
	if (enabled < 0)
		enabled = (getenv("OSXIE_TRACE_CGSCAPTURE") != NULL);
	return enabled;
}

static void* osxieCapturePixels(Display* display, Drawable drawable,
								int x, int y, int w, int h,
								int* outWidth, int* outHeight)
{
	if (!display || !drawable || w <= 0 || h <= 0)
		return NULL;

	XImage* image = XGetImage(display, drawable, x, y, w, h, AllPlanes, ZPixmap);

	if (!image)
	{
		// A compositing WM (e.g. KWin) redirects the root and top-level
		// windows, making XGetImage fail with BadMatch. Fall back to the
		// compositor's name window pixmap.
		int eventBase = 0, errorBase = 0;
		if (osxieCaptureTraceEnabled())
			printf("OSXIE_TRACE_CGSCAPTURE: XGetImage failed (drawable=0x%lx); trying composite pixmap\n",
				(unsigned long) drawable);
		if (!XCompositeQueryExtension(display, &eventBase, &errorBase))
		{
			if (osxieCaptureTraceEnabled())
				printf("OSXIE_TRACE_CGSCAPTURE: no composite extension\n");
			return NULL;
		}

		Pixmap pixmap = XCompositeNameWindowPixmap(display, (Window) drawable);
		if (!pixmap)
		{
			if (osxieCaptureTraceEnabled())
				printf("OSXIE_TRACE_CGSCAPTURE: XCompositeNameWindowPixmap failed\n");
			return NULL;
		}

		image = XGetImage(display, pixmap, x, y, w, h, AllPlanes, ZPixmap);
		XFreePixmap(display, pixmap);

		if (!image)
		{
			if (osxieCaptureTraceEnabled())
				printf("OSXIE_TRACE_CGSCAPTURE: XGetImage on composite pixmap failed\n");
			return NULL;
		}
	}

	int bytesPerPixel = (image->bits_per_pixel + 7) / 8;
	int bpr = w * 4;
	unsigned char* buf = malloc((size_t) bpr * h);
	if (!buf)
	{
		XDestroyImage(image);
		return NULL;
	}

	if (image->bits_per_pixel == 32 && image->byte_order == LSBFirst)
	{
		// Server-native 32bpp pixels on little-endian are BGRX in memory.
		for (int row = 0; row < h; row++)
		{
			const unsigned char* src = (const unsigned char*) image->data + row * image->bytes_per_line;
			unsigned char* dst = buf + row * bpr;

			for (int col = 0; col < w; col++)
			{
				dst[0] = src[0];
				dst[1] = src[1];
				dst[2] = src[2];
				dst[3] = 0xFF;
				dst += 4;
				src += 4;
			}
		}
	}
	else
	{
		// General path: unpack with XGetPixel + visual masks.
		Visual* visual = XDefaultVisual(display, XDefaultScreen(display));
		unsigned long redMask = visual->red_mask;
		unsigned long greenMask = visual->green_mask;
		unsigned long blueMask = visual->blue_mask;
		int rShift = 0, gShift = 0, bShift = 0;
		while ((redMask & 1) == 0) { redMask >>= 1; rShift++; }
		while ((greenMask & 1) == 0) { greenMask >>= 1; gShift++; }
		while ((blueMask & 1) == 0) { blueMask >>= 1; bShift++; }

		for (int row = 0; row < h; row++)
		{
			unsigned char* dst = buf + row * bpr;
			for (int col = 0; col < w; col++)
			{
				unsigned long pixel = XGetPixel(image, col, row);
				*dst++ = (pixel >> bShift) & 0xFF;
				*dst++ = (pixel >> gShift) & 0xFF;
				*dst++ = (pixel >> rShift) & 0xFF;
				*dst++ = 0xFF;
			}
		}
	}

	XDestroyImage(image);

	*outWidth = w;
	*outHeight = h;
	return buf;
}

@implementation CGSWindowX11

- (instancetype) initWithRegion: (CGSRegionRef) region
                     connection: (CGSConnection *) connection
                       windowID: (CGSWindowID) windowID
{
	self = [super initWithRegion: region connection: connection windowID: windowID];
	if (self)
	{
		Display* display = [(CGSConnectionX11*) connection display];
		CGRect rect;
		CGSRegionToRect(region, &rect);

		if (rect.size.width < 1)
			rect.size.width = 1;
		if (rect.size.height < 1)
			rect.size.height = 1;

		XSetWindowAttributes attrs;
		memset(&attrs, 0, sizeof(attrs));
		attrs.background_pixel = WhitePixel(display, DefaultScreen(display));
		attrs.border_pixel = BlackPixel(display, DefaultScreen(display));
		attrs.event_mask = ExposureMask | StructureNotifyMask
			| ButtonPressMask | ButtonReleaseMask
			| PointerMotionMask | EnterWindowMask | LeaveWindowMask
			| KeyPressMask | KeyReleaseMask
			| FocusChangeMask | PropertyChangeMask;

		_x11Window = XCreateWindow(display, DefaultRootWindow(display),
			(int) rect.origin.x, (int) rect.origin.y,
			(unsigned) rect.size.width, (unsigned) rect.size.height,
			0, CopyFromParent, InputOutput, CopyFromParent,
			CWBackPixel | CWBorderPixel | CWEventMask, &attrs);

		_bounds = rect;
		_properties = [[NSMutableDictionary alloc] initWithCapacity: 1];

		XStoreName(display, _x11Window, "");
	}
	return self;
}

- (void) dealloc
{
	Display* display = [(CGSConnectionX11*) _connection display];

	if (_x11Window)
	{
		XDestroyWindow(display, _x11Window);
		_x11Window = 0;
	}

	[_properties release];

	[super dealloc];
}

-(Display*) display
{
	return [(CGSConnectionX11*) _connection display];
}

- (CGError) orderWindow: (CGSWindowOrderingMode) place
             relativeTo: (CGSWindow *) window
{
	Display* display = [(CGSConnectionX11*) _connection display];

	switch (place)
	{
		case kCGSOrderAbove:
			if (window)
			{
				XWindowChanges changes;
				memset(&changes, 0, sizeof(changes));
				changes.stack_mode = Above;
				changes.sibling = ((CGSWindowX11*) window)->_x11Window;
				XConfigureWindow(display, _x11Window, CWSibling | CWStackMode, &changes);
			}
			else
				XRaiseWindow(display, _x11Window);
			break;

		case kCGSOrderBelow:
			if (window)
			{
				XWindowChanges changes;
				memset(&changes, 0, sizeof(changes));
				changes.stack_mode = Below;
				changes.sibling = ((CGSWindowX11*) window)->_x11Window;
				XConfigureWindow(display, _x11Window, CWSibling | CWStackMode, &changes);
			}
			else
				XLowerWindow(display, _x11Window);
			break;

		case kCGSOrderIn:
			XMapRaised(display, _x11Window);
			break;

		case kCGSOrderOut:
			XUnmapWindow(display, _x11Window);
			break;
	}

	XFlush(display);
	return kCGSErrorSuccess;
}

- (CGError) moveTo: (const CGPoint *) point
{
	Display* display = [(CGSConnectionX11*) _connection display];

	XMoveWindow(display, _x11Window, (int) point->x, (int) point->y);
	XFlush(display);

	_bounds.origin = *point;
	return kCGSErrorSuccess;
}

- (CGError) setRegion: (CGSRegionRef) region
{
	CGRect rect;
	CGSRegionToRect(region, &rect);

	Display* display = [(CGSConnectionX11*) _connection display];

	XMoveResizeWindow(display, _x11Window,
		(int) rect.origin.x, (int) rect.origin.y,
		(unsigned) rect.size.width, (unsigned) rect.size.height);
	XFlush(display);

	_bounds = rect;
	return kCGSErrorSuccess;
}

- (CGError) getRect: (CGRect *) outRect
{
	Display* display = [(CGSConnectionX11*) _connection display];
	XWindowAttributes attrs;

	if (XGetWindowAttributes(display, _x11Window, &attrs))
	{
		Window root, child;
		int x, y;

		XTranslateCoordinates(display, _x11Window, DefaultRootWindow(display),
			0, 0, &x, &y, &child);

		*outRect = CGRectMake(x, y, attrs.width, attrs.height);
		_bounds = *outRect;
	}
	else
		*outRect = _bounds;

	return kCGSErrorSuccess;
}

- (BOOL) isOnscreen
{
	if (!_x11Window)
		return NO;

	Display* display = [(CGSConnectionX11*) _connection display];
	XWindowAttributes attrs;

	if (!XGetWindowAttributes(display, _x11Window, &attrs))
		return NO;

	return attrs.map_state == IsViewable;
}

- (CGError) setProperty: (CFStringRef) key value: (CFTypeRef) value
{
	NSString* k = (NSString*) key;
	Display* display = [(CGSConnectionX11*) _connection display];

	if ([k isEqualToString: (NSString*) kCGSWindowTitle])
	{
		NSString* title = (NSString*) value;
		const char* utf8 = [title UTF8String];

		XStoreName(display, _x11Window, utf8);
		XChangeProperty(display, _x11Window,
			XInternAtom(display, "_NET_WM_NAME", False),
			XInternAtom(display, "UTF8_STRING", False), 8, PropModeReplace,
			(const unsigned char*) utf8, (int) strlen(utf8));
		XFlush(display);
	}

	if (value)
		[_properties setObject: (id) value forKey: k];
	else
		[_properties removeObjectForKey: k];

	return kCGSErrorSuccess;
}

- (CGError) getProperty: (CFStringRef) key value: (CFTypeRef *) value
{
	id stored = [_properties objectForKey: (NSString*) key];

	*value = stored ? (CFTypeRef) [stored retain] : NULL;
	return kCGSErrorSuccess;
}

- (void) invalidate
{
	Display* display = [(CGSConnectionX11*) _connection display];

	if (_x11Window)
	{
		XDestroyWindow(display, _x11Window);
		_x11Window = 0;
		XFlush(display);
	}

	[super invalidate];
}

- (CGSSurface *) createSurface
{
	CGSSurfaceID sid = _nextSurfaceId++;
	CGSSurfaceX11* surface = [[CGSSurfaceX11 alloc] initWithWindow: self surfaceID: sid];

	if (!surface)
		return nil;

	@synchronized (_surfaces)
	{
		[_surfaces setObject: surface forKey: [NSNumber numberWithInt: sid]];
	}

	[surface release];
	return surface;
}

- (void *) nativeWindow
{
	return (void*) _x11Window;
}

- (void*) captureBitmapDataWithWidth: (int*) outWidth height: (int*) outHeight
{
	Display* display = [(CGSConnectionX11*) _connection display];
	if (!_x11Window || !display)
		return NULL;

	XWindowAttributes attrs;
	if (!XGetWindowAttributes(display, _x11Window, &attrs))
		return NULL;

	return osxieCapturePixels(display, _x11Window, 0, 0,
		attrs.width, attrs.height, outWidth, outHeight);
}

@end

@implementation CGSConnectionX11 (OsxieCapture)

- (void*) captureRootBitmapDataWithRect: (CGRect) rect
								  width: (int*) outWidth
								 height: (int*) outHeight
{
	Display* display = _display;
	if (osxieCaptureTraceEnabled())
		printf("OSXIE_TRACE_CGSCAPTURE: captureRoot display=%p self=%p class=%s\n",
			display, self, object_getClassName(self));
	if (!display)
		return NULL;

	int screen = XDefaultScreen(display);
	Window root = DefaultRootWindow(display);
	int screenWidth = DisplayWidth(display, screen);
	int screenHeight = DisplayHeight(display, screen);

	int x = 0, y = 0, w = screenWidth, h = screenHeight;

	if (!CGRectIsNull(rect) && rect.size.width > 0 && rect.size.height > 0)
	{
		x = (int) rect.origin.x;
		y = (int) rect.origin.y;
		w = (int) rect.size.width;
		h = (int) rect.size.height;

		if (x < 0) x = 0;
		if (y < 0) y = 0;
		if (x + w > screenWidth) w = screenWidth - x;
		if (y + h > screenHeight) h = screenHeight - y;
	}

	return osxieCapturePixels(display, root, x, y, w, h, outWidth, outHeight);
}

@end
