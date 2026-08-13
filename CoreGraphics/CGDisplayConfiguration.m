#import <CoreGraphics/CGDisplayConfiguration.h>

CGError CGDisplayRegisterReconfigurationCallback(CGDisplayReconfigurationCallBack callback, void *userInfo) {
    return kCGErrorSuccess;
}

CGError CGDisplayRemoveReconfigurationCallback(CGDisplayReconfigurationCallBack callback, void *userInfo) {
    return kCGErrorSuccess;
}
