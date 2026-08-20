#include <CoreGraphics/CGEvent.h>
#import "CGEventObjC.h"
#include <CoreGraphics/CGEventTapInternal.h>

#define MAX_TAPS 32

static CGEventTap* g_taps[MAX_TAPS] = {0};
static int g_tapCount = 0;

static void registerTap(CGEventTap* tap) {
    if (g_tapCount < MAX_TAPS)
        g_taps[g_tapCount++] = tap;
}

static void deregisterTap(mach_port_t mp) {
    for (int i = 0; i < g_tapCount; i++) {
        if (g_taps[i] && g_taps[i].machPort == mp) {
            g_taps[i] = g_taps[--g_tapCount];
            g_taps[g_tapCount] = nil;
            return;
        }
    }
}

static CGEventTap* findTapByPort(mach_port_t mp) {
    for (int i = 0; i < g_tapCount; i++)
        if (g_taps[i] && g_taps[i].machPort == mp)
            return g_taps[i];
    return nil;
}

void CGEventPost(CGEventTapLocation tap, CGEventRef _Nullable event)
{
    if (!event) return;

    for (int i = 0; i < g_tapCount; i++) {
        CGEventTap* t = g_taps[i];
        if (!t || !t.enabled) continue;

        CGEventType type = CGEventGetType(event);
        if ((CGEventMaskBit(type) & t.mask) == 0) continue;

        if (t.callback) {
            struct TapMachMessage msg = {0};
            msg.event = (CGEventRef)[event copy];
            msg.proxy = NULL;

            CGEventRef returned = t.callback(NULL, type, msg.event, t.userInfo);
            if (returned != msg.event)
                CFRelease(msg.event);

            if (!(t.options & kCGEventTapOptionListenOnly) && returned)
                event = returned;
        }
    }
}

CFMachPortRef CGEventTapCreate(CGEventTapLocation tap, CGEventTapPlacement place,
    CGEventTapOptions options, CGEventMask eventsOfInterest, CGEventTapCallBack callback, void *userInfo)
{
    CGEventTap* newTap = [[CGEventTap alloc] initWithLocation: tap
                                                options: options
                                                mask: eventsOfInterest
                                                callback: callback
                                                userInfo: userInfo];

    if (!newTap)
        return NULL;

    registerTap(newTap);
    CFMachPortRef mp = [newTap createCFMachPort];
    [newTap release];
    return mp;
}

void _CGEventTapDestroyed(CGEventTapLocation location, mach_port_t mp)
{
    deregisterTap(mp);
}

void CGEventTapEnable(CFMachPortRef tap, bool enable)
{
    mach_port_t mp = CFMachPortGetPort(tap);
    CGEventTap* tapObj = findTapByPort(mp);
    tapObj.enabled = enable;
}

void CGEventTapPostEvent(CGEventTapProxy proxy, CGEventRef event)
{
}

CGError CGGetEventTapList(uint32_t maxNumberOfTaps, CGEventTapInformation *tapList, uint32_t *eventTapCount)
{
    if (eventTapCount)
        *eventTapCount = (uint32_t)g_tapCount;
    return kCGErrorSuccess;
}
