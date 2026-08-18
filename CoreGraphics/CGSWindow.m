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
#import <CoreGraphics/CGSConnection.h>
#import <CoreGraphics/CGSWindow.h>
#import <CoreGraphics/CoreGraphicsPrivate.h>
#import <CoreGraphics/CGImage.h>
#import <CoreGraphics/CGDataProvider.h>
#import <CoreGraphics/CGColorSpace.h>
#import <Foundation/NSRaise.h>

const CFStringRef kCGSWindowTitle = CFSTR("WindowTitle");

@implementation CGSWindow
@synthesize windowId = _windowId;

- (instancetype) initWithRegion: (CGSRegionRef) region
                     connection: (CGSConnection *) connection
                       windowID: (CGSWindowID) windowID
{
    _connection = connection;
    _nextSurfaceId = 1;
    _surfaces = [[NSMutableDictionary alloc] initWithCapacity: 1];
    _windowId = windowID;
    return self;
}

- (void) dealloc {
    [_surfaces release];
    [super dealloc];
}

- (CGSSurface *) surfaceForId: (CGSSurfaceID) surfaceId {
    CGSSurface *rv;
    @synchronized(_surfaces) {
        rv = [_surfaces objectForKey: [NSNumber numberWithInt: surfaceId]];
    }
    return rv;
}

- (void) _surfaceInvalidated: (CGSSurfaceID) surfaceId {
    @synchronized(_surfaces) {
        [_surfaces removeObjectForKey: [NSNumber numberWithInt: surfaceId]];
    }
}

- (void) invalidate {
    [_connection _windowInvalidated: _windowId];
}

- (CGError) orderWindow: (CGSWindowOrderingMode) place
             relativeTo: (CGSWindow *) window
{
    NSInvalidAbstractInvocation();
}

- (CGError) moveTo: (const CGPoint *) point {
    NSInvalidAbstractInvocation();
}

- (CGError) setRegion: (CGSRegionRef) region {
    NSInvalidAbstractInvocation();
}

- (CGError) getRect: (CGRect *) outRect {
    NSInvalidAbstractInvocation();
}

- (CGError) setProperty: (CFStringRef) key value: (CFTypeRef) value {
    NSInvalidAbstractInvocation();
}

- (CGError) getProperty: (CFStringRef) key value: (CFTypeRef *) value {
    NSInvalidAbstractInvocation();
}

- (BOOL) isOnscreen {
    return NO;
}

- (CGSSurface *) createSurface {
    NSInvalidAbstractInvocation();
}

- (void *) nativeWindow {
    NSInvalidAbstractInvocation();
}

- (void*) captureBitmapDataWithWidth: (int*) outWidth height: (int*) outHeight {
    return NULL;
}

@end

CGError CGSSetWindowTitle(CGSConnectionID cid, CGSWindowID wid,
                          CFStringRef title)
{
    return CGSSetWindowProperty(cid, wid, kCGSWindowTitle, title);
}

static void CGWindowListCreateImageReleasePixels(void* info, const void* data, size_t size)
{
	free((void*) data);
}

CGImageRef __nullable CGWindowListCreateImage(CGRect screenBounds,
                                              CGWindowListOption listOption,
                                              CGWindowID windowID,
                                              CGWindowImageOption imageOption)
{
	int w = 0, h = 0;
	void* pixels = NULL;

	if (windowID != kCGNullWindowID)
	{
		CGSConnection* conn = _CGSConnectionForWindowID(windowID);
		CGSWindow* window = conn ? [conn windowForId: windowID] : nil;

		if (window)
			pixels = [window captureBitmapDataWithWidth: &w height: &h];
	}
	else
	{
		CGSConnection* conn = _CGSConnectionForID(_CGSDefaultConnection());

		if (conn)
			pixels = [conn captureRootBitmapDataWithRect: screenBounds
												  width: &w
												 height: &h];
	}

	if (!pixels || w <= 0 || h <= 0)
	{
		free(pixels);
		return nil;
	}

	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels,
		(size_t) w * 4 * h, CGWindowListCreateImageReleasePixels);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();

	CGImageRef image = CGImageCreate(w, h, 8, 32, w * 4, space,
		kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little,
		provider, NULL, YES, kCGRenderingIntentDefault);

	CGColorSpaceRelease(space);
	CGDataProviderRelease(provider);
	return image;
}

