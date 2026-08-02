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
#ifndef CGSSURFACE_H
#define CGSSURFACE_H
#include <CoreGraphics/CoreGraphicsPrivate.h>
#import <Foundation/NSObject.h>

@class CGSWindow;

@interface CGSSurface : NSObject {
    CGSWindow *_window;
    CGSSurfaceID _surfaceId;
}
- (instancetype) initWithWindow: (CGSWindow *) window
                      surfaceID: (CGSSurfaceID) surfaceID;
- (CGError) setBounds: (CGRect) rect;

// Used by CGL as EGLNativeWindowType for CGLSetSurface()
- (void *) nativeWindow;
- (void) invalidate;

@property(readonly) CGSSurfaceID surfaceId;

@end

#endif
