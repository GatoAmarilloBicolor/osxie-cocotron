#import <AppKit/NSPopover.h>
#import <AppKit/NSViewController.h>
#import <AppKit/NSWindow.h>
#import <Foundation/NSNotificationCenter.h>

NSNotificationName const NSPopoverDidCloseNotification = @"NSPopoverDidCloseNotification";
NSNotificationName const NSPopoverWillCloseNotification = @"NSPopoverWillCloseNotification";
NSNotificationName const NSPopoverWillShowNotification = @"NSPopoverWillShowNotification";
NSNotificationName const NSPopoverDidShowNotification = @"NSPopoverDidShowNotification";

@implementation NSPopover

- init {
    if ((self = [super init])) {
        _behavior = NSPopoverBehaviorApplicationDefined;
        _shown = NO;
    }
    return self;
}

- (void) dealloc {
    [_contentViewController release];
    [_popoverWindow release];
    [super dealloc];
}

- (NSViewController *) contentViewController {
    return _contentViewController;
}

- (void) setContentViewController: (NSViewController *) value {
    [_contentViewController autorelease];
    _contentViewController = [value retain];
}

- (id <NSPopoverDelegate>) delegate {
    return _delegate;
}

- (void) setDelegate: (id <NSPopoverDelegate>) value {
    _delegate = value;
}

- (NSPopoverBehavior) behavior {
    return _behavior;
}

- (void) setBehavior: (NSPopoverBehavior) value {
    _behavior = value;
}

- (BOOL) isShown {
    return _shown;
}

- (void) showRelativeToRect: (NSRect) positioningRect ofView: (NSView *) positioningView preferredEdge: (NSRectEdge) preferredEdge {
    if (_shown) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName: NSPopoverWillShowNotification object: self];
    
    if ([_delegate respondsToSelector: @selector(popoverWillShow:)]) {
        [_delegate popoverWillShow: [NSNotification notificationWithName: NSPopoverWillShowNotification object: self]];
    }
    
    _shown = YES;
    
    [[NSNotificationCenter defaultCenter] postNotificationName: NSPopoverDidShowNotification object: self];
    
    if ([_delegate respondsToSelector: @selector(popoverDidShow:)]) {
        [_delegate popoverDidShow: [NSNotification notificationWithName: NSPopoverDidShowNotification object: self]];
    }
}

- (void) close {
    if (!_shown) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName: NSPopoverWillCloseNotification object: self];
    
    if ([_delegate respondsToSelector: @selector(popoverWillClose:)]) {
        [_delegate popoverWillClose: [NSNotification notificationWithName: NSPopoverWillCloseNotification object: self]];
    }
    
    _shown = NO;
    
    [[NSNotificationCenter defaultCenter] postNotificationName: NSPopoverDidCloseNotification object: self];
    
    if ([_delegate respondsToSelector: @selector(popoverDidClose:)]) {
        [_delegate popoverDidClose: [NSNotification notificationWithName: NSPopoverDidCloseNotification object: self]];
    }
}

@end
