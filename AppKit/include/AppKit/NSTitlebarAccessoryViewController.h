#import <AppKit/NSViewController.h>
#import <Foundation/Foundation.h>

@class NSWindow;

typedef NS_ENUM(NSInteger, NSLayoutAttribute) {
    NSLayoutAttributeNotAnAttribute = 0,
    NSLayoutAttributeLeft = 1,
    NSLayoutAttributeRight = 2,
    NSLayoutAttributeTop = 3,
    NSLayoutAttributeBottom = 4,
    NSLayoutAttributeLeading = 5,
    NSLayoutAttributeTrailing = 6,
    NSLayoutAttributeWidth = 7,
    NSLayoutAttributeHeight = 8,
    NSLayoutAttributeCenterX = 9,
    NSLayoutAttributeCenterY = 10,
    NSLayoutAttributeLastBaseline = 11,
    NSLayoutAttributeFirstBaseline = 12,
    NSLayoutAttributeLeftMargin = 13,
    NSLayoutAttributeRightMargin = 14,
    NSLayoutAttributeTopMargin = 15,
    NSLayoutAttributeBottomMargin = 16,
    NSLayoutAttributeLeadingMargin = 17,
    NSLayoutAttributeTrailingMargin = 18,
    NSLayoutAttributeCenterXWithinMargins = 19,
    NSLayoutAttributeCenterYWithinMargins = 20,
};

@interface NSTitlebarAccessoryViewController : NSViewController {
    NSLayoutAttribute _layoutAttribute;
    CGFloat _fullScreenMinHeight;
    NSWindow *_window; // weak
    BOOL _isHidden;
}

@property NSLayoutAttribute layoutAttribute;
@property CGFloat fullScreenMinHeight;
@property(readonly, weak) NSWindow *window;
@property(getter=isHidden) BOOL hidden;

@end
