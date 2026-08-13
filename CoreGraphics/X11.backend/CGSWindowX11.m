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

@end
