#import <AppKit/NSTitlebarAccessoryViewController.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSView.h>

@interface NSWindow (private)
- (void) _layoutTitlebarAccessories;
@end

@implementation NSTitlebarAccessoryViewController

- (instancetype) init {
    if (self = [super init]) {
        _layoutAttribute = NSLayoutAttributeBottom;
    }
    return self;
}

- (NSLayoutAttribute) layoutAttribute {
    return _layoutAttribute;
}

- (void) setLayoutAttribute: (NSLayoutAttribute) attribute {
    _layoutAttribute = attribute;
    [[self window] _layoutTitlebarAccessories];
}

- (CGFloat) fullScreenMinHeight {
    return _fullScreenMinHeight;
}

- (void) setFullScreenMinHeight: (CGFloat) value {
    _fullScreenMinHeight = value;
}

- (NSWindow *) window {
    return _window;
}

- (BOOL) isHidden {
    return _isHidden;
}

- (void) setHidden: (BOOL) value {
    if (_isHidden == value) {
        return;
    }
    _isHidden = value;
    [[self window] _layoutTitlebarAccessories];
}

- (void) setView: (NSView *) view {
    [super setView: view];
    [[self window] _layoutTitlebarAccessories];
}

- (void) _setWindow: (NSWindow *) window {
    _window = window;
    [[self window] _layoutTitlebarAccessories];
}

@end
