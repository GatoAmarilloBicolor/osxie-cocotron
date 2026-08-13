#import <AppKit/NSRunningApplication.h>
#import <AppKit/NSApplication.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSURL.h>
#import <unistd.h>

// Implementation notes:
// _LSCopyApplicationInformationItem(-2, ...) is used to fetch properties, such
// as _kLSExecutablePathKey Applications (processes) are referred to by an
// opaque void* asn (application serial number). ASNs can be compared with
// _LSCompareASNs().
//
// lsd provides notifications when processes change. This is registered via:
// _LSScheduleNotificationFunction(-2, callback, eventMask, context,
// CFRunLoopRef, kCFRunLoopCommonModes) and _LSModifyNotification(). The
// properties are updated via KVO.
//
// Current application is also observed via LS - _LSGetCurrentApplicationASN().
// All apps: _LSCopyRunningApplicationArray() - returns an array of ASNs.
// Running apps: _LSCopyRunningApplicationArray() - ditto.

static NSRunningApplication *gCurrentApplication = nil;

@implementation NSRunningApplication

+ (NSRunningApplication *) currentApplication {
    if (!gCurrentApplication) {
        gCurrentApplication = [[self alloc] init];
    }
    return gCurrentApplication;
}

- (pid_t) processIdentifier {
    return getpid();
}

- (NSString *) bundleIdentifier {
    return [[NSBundle mainBundle] bundleIdentifier];
}

- (NSString *) localizedName {
    NSString *name = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleName"];
    if (!name) {
        name = [[NSProcessInfo processInfo] processName];
    }
    return name;
}

- (NSURL *) bundleURL {
    return [[NSBundle mainBundle] bundleURL];
}

- (NSURL *) executableURL {
    return [[NSBundle mainBundle] executableURL];
}

- (BOOL) isActive {
    return YES;
}

- (BOOL) isHidden {
    return NO;
}

- (BOOL) isTerminated {
    return NO;
}

- (BOOL) isFinishedLaunching {
    return YES;
}

- (NSApplicationActivationPolicy) activationPolicy {
    return NSApplicationActivationPolicyRegular;
}

- (BOOL) activateWithOptions: (NSApplicationActivationOptions) options {
    return YES;
}

- (BOOL) hide {
    return YES;
}

- (BOOL) unhide {
    return YES;
}

- (BOOL) terminate {
    return YES;
}

- (BOOL) forceTerminate {
    return YES;
}

- (BOOL) hideOtherApplications {
    return YES;
}

+ (NSArray<NSRunningApplication *> *) runningApplicationsWithBundleIdentifier: (NSString *) bundleIdentifier {
    if ([bundleIdentifier isEqualToString: [[NSBundle mainBundle] bundleIdentifier]]) {
        return @[[self currentApplication]];
    }
    return [NSArray array];
}

@end
