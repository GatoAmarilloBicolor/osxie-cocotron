/*
 This file is part of Osxie.

 Copyright (C) 2019 Lubos Dolezel

 Osxie is free softwareyou can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Osxie is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Osxie.  If not, see <http//www.gnu.org/licenses/>.
*/

#import <AppKit/NSAccessibilityElement.h>
#import <Foundation/Foundation.h>

@implementation NSAccessibilityElement

@synthesize accessibilityElement = _isAccessible;

- (NSMethodSignature *) methodSignatureForSelector: (SEL) aSelector {
    NSString *selectorString = NSStringFromSelector(aSelector);
    if ([selectorString hasPrefix:@"set"] && [selectorString hasSuffix:@":"]) {
        // This is a setter method, which typically takes one argument (id type).
        return [NSMethodSignature signatureWithObjCTypes: "v@:@"];
    }
    // For other methods, assume no explicit arguments (beyond self and _cmd).
    // This might still be too generic for complex methods, but addresses the reported issue.
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void) forwardInvocation: (NSInvocation *) anInvocation {
    NSLog(@"Stub called: %@ in %@",
          NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
