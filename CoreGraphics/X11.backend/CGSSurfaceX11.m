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
#import "CGSSurfaceX11.h"
#import "CGSWindowX11.h"
#import <CoreGraphics/CGSWindow.h>
#import <X11/Xutil.h>

@implementation CGSSurfaceX11

- (instancetype) initWithWindow: (CGSWindow *) window
                      surfaceID: (CGSSurfaceID) surfaceID
{
	self = [super initWithWindow: window surfaceID: surfaceID];
	if (self)
	{
		CGSWindowX11* windowX11 = (CGSWindowX11*) window;
		Display* display = [windowX11 display];
		Window parent = (Window) [windowX11 nativeWindow];

		XSetWindowAttributes attrs;
		memset(&attrs, 0, sizeof(attrs));
		attrs.background_pixel = WhitePixel(display, DefaultScreen(display));
		attrs.event_mask = ExposureMask | StructureNotifyMask;

		_x11Window = XCreateWindow(display, parent, 0, 0, 1, 1, 0,
			CopyFromParent, InputOutput, CopyFromParent,
			CWBackPixel | CWEventMask, &attrs);

		XMapWindow(display, _x11Window);
		XFlush(display);
	}
	return self;
}

- (void) dealloc
{
	CGSWindowX11* windowX11 = (CGSWindowX11*) _window;

	if (_x11Window)
	{
		XDestroyWindow([windowX11 display], _x11Window);
		_x11Window = 0;
	}

	[super dealloc];
}

- (CGError) setBounds: (CGRect) rect
{
	CGSWindowX11* windowX11 = (CGSWindowX11*) _window;

	XMoveResizeWindow([windowX11 display], _x11Window,
		(int) rect.origin.x, (int) rect.origin.y,
		(unsigned) rect.size.width, (unsigned) rect.size.height);
	XFlush([windowX11 display]);

	return kCGSErrorSuccess;
}

- (void) invalidate
{
	CGSWindowX11* windowX11 = (CGSWindowX11*) _window;

	if (_x11Window)
	{
		XDestroyWindow([windowX11 display], _x11Window);
		_x11Window = 0;
		XFlush([windowX11 display]);
	}

	[super invalidate];
}

- (void *) nativeWindow
{
	return (void*) _x11Window;
}

@end
