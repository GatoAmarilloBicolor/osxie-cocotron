#import <AppKit/AppKitExport.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>

typedef NS_ENUM(NSInteger, NSPopoverBehavior) {
    NSPopoverBehaviorApplicationDefined,
    NSPopoverBehaviorTransient,
    NSPopoverBehaviorSemitransient
};

@class NSViewController, NSView, NSWindow;

@protocol NSPopoverDelegate <NSObject>
@optional
- (void) popoverWillShow: (NSNotification *) notification;
- (void) popoverDidShow: (NSNotification *) notification;
- (void) popoverWillClose: (NSNotification *) notification;
- (void) popoverDidClose: (NSNotification *) notification;
@end

@interface NSPopover : NSObject {
  @public
    NSViewController *_contentViewController;
    id <NSPopoverDelegate> _delegate;
    NSPopoverBehavior _behavior;
    BOOL _shown;
    NSWindow *_popoverWindow;
}

- init;

- (NSViewController *) contentViewController;
- (void) setContentViewController: (NSViewController *) value;

- (id <NSPopoverDelegate>) delegate;
- (void) setDelegate: (id <NSPopoverDelegate>) value;

- (NSPopoverBehavior) behavior;
- (void) setBehavior: (NSPopoverBehavior) value;

- (BOOL) isShown;

- (void) showRelativeToRect: (NSRect) positioningRect ofView: (NSView *) positioningView preferredEdge: (NSRectEdge) preferredEdge;
- (void) close;

@end
