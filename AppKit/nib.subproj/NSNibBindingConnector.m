/* Copyright (c) 2007 Johannes Fortmann

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
#import "NSNibBindingConnector.h"
#import <AppKit/NSObject+BindingSupport.h>
#import <stdio.h>
#import <objc/runtime.h>

@implementation NSNibBindingConnector
- (void) dealloc {
    [_binding release];
    [_keyPath release];
    [_options release];
    [super dealloc];
}

- (id) initWithCoder: (NSCoder *) coder {
    if ((self = [super initWithCoder: coder])) {
        int version = [coder decodeIntForKey: @"NSNibBindingConnectorVersion"];
        if (version != 2)
            [NSException raise: NSInvalidArgumentException
                        format: @"-[%@ %s] unknown connector version %i",
                                [self class], sel_getName(_cmd), version];

        _binding = [[coder decodeObjectForKey: @"NSBinding"] retain];
        _keyPath = [[coder decodeObjectForKey: @"NSKeyPath"] retain];
        _options = [[coder decodeObjectForKey: @"NSOptions"] retain];
    } else {
        [NSException raise: NSInvalidArgumentException
                    format: @"-[%@ %s] is not implemented for coder %@",
                            [self class], sel_getName(_cmd), coder];
    }
    return self;
}

- (void) establishConnection {
    if (getenv("OSXIE_TRACE_NIB")) fprintf(stderr, "[TRACE] NSNibBindingConnector: enter binding=%@ src=%p(%s) dst=%p(%s) keyPath=%@\n",
            _binding, (void *)_source, _source?object_getClassName(_source):"nil",
            (void *)_destination, _destination?object_getClassName(_destination):"nil", _keyPath);
    fflush(stderr);

    if (_source == nil || _destination == nil || _binding == nil || _keyPath == nil) {
        NSLog(@"[NSNibBindingConnector] Warning: skipping binding with nil source/destination/binding/keyPath");
        return;
    }

    // A SEGV here is not catchable; we must never touch a non-object or a
    // placeholder whose class didn't resolve. Validate both endpoints are
    // real NSObjects before doing anything.
    if (![_source isKindOfClass: [NSObject class]] ||
        ![_destination isKindOfClass: [NSObject class]]) {
        NSLog(@"[NSNibBindingConnector] Warning: source/destination is not a valid NSObject; skipping binding %@ between %@ and %@",
              _binding, object_getClassName(_source), object_getClassName(_destination));
        return;
    }
    if (![_source respondsToSelector: @selector(bind:toObject:withKeyPath:options:)]) {
        NSLog(@"[NSNibBindingConnector] Warning: source %@ does not implement bind:toObject:withKeyPath:options:; skipping binding %@",
              object_getClassName(_source), _binding);
        return;
    }
    if (![_destination respondsToSelector: @selector(valueForKey:)]) {
        NSLog(@"[NSNibBindingConnector] Warning: destination %@ does not implement valueForKey:; skipping binding %@",
              object_getClassName(_destination), _binding);
        return;
    }

    if (getenv("OSXIE_TRACE_NIB")) fprintf(stderr, "[TRACE] NSNibBindingConnector: calling bind:\n");
    fflush(stderr);
    @try {
        [_source bind: _binding
                   toObject: _destination
                withKeyPath: _keyPath
                    options: _options];
        if (getenv("OSXIE_TRACE_NIB")) fprintf(stderr, "[TRACE] NSNibBindingConnector: bind: returned\n");
        fflush(stderr);
    } @catch (NSException *e) {
        NSLog(@"[NSNibBindingConnector] Exception establishing binding '%@': %@", _binding, [e reason]);
    }
}
@end
