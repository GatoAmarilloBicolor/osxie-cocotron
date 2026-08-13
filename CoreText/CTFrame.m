#import <CoreText/CTFrame.h>
#import <CoreFoundation/CFArray.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSGeometry.h>
#import "CTPrivate.h"

@interface CTFrame ()
@end

@implementation CTFrame

- initWithLines: (NSArray *) lines
        origins: (NSArray *) origins
           path: (CGPathRef) path
    stringRange: (CFRange) stringRange
frameAttributes: (CFDictionaryRef) frameAttributes
{
    _lines = [lines retain];
    _origins = [origins retain];
    _path = CGPathRetain(path);
    _stringRange = stringRange;
    _frameAttributes = (frameAttributes != NULL) ? CFRetain(frameAttributes) : NULL;
    return self;
}

- (void) dealloc
{
    [_lines release];
    [_origins release];
    CGPathRelease(_path);
    if (_frameAttributes != NULL) CFRelease(_frameAttributes);
    [super dealloc];
}

- (NSArray *) lines { return _lines; }
- (NSArray *) origins { return _origins; }
- (CGPathRef) path { return _path; }
- (CFRange) stringRange { return _stringRange; }
- (CFDictionaryRef) frameAttributes { return _frameAttributes; }

- (CFTypeID) _cfTypeID { return CTFrameGetTypeID(); }

@end

CFTypeID CTFrameGetTypeID(void)
{
    return (CFTypeID) [CTFrame self];
}

CFRange CTFrameGetStringRange(CTFrameRef frameRef)
{
    CTFrame *frame = (CTFrame *) frameRef;
    if (frame == nil) return CFRangeMake(0, 0);
    return [frame stringRange];
}

CFRange CTFrameGetVisibleStringRange(CTFrameRef frameRef)
{
    CTFrame *frame = (CTFrame *) frameRef;
    if (frame == nil) return CFRangeMake(0, 0);
    return [frame stringRange];
}

CGPathRef CTFrameGetPath(CTFrameRef frameRef)
{
    CTFrame *frame = (CTFrame *) frameRef;
    if (frame == nil) return NULL;
    return [frame path];
}

CFDictionaryRef _Nullable CTFrameGetFrameAttributes(CTFrameRef frameRef)
{
    CTFrame *frame = (CTFrame *) frameRef;
    if (frame == nil) return NULL;
    return [frame frameAttributes];
}

CFArrayRef CTFrameGetLines(CTFrameRef frameRef)
{
    CTFrame *frame = (CTFrame *) frameRef;
    if (frame == nil) return NULL;
    return (CFArrayRef) [frame lines];
}

void CTFrameGetLineOrigins(CTFrameRef frameRef, CFRange range, CGPoint origins[_Nonnull])
{
    CTFrame *frame = (CTFrame *) frameRef;
    if (frame == nil) return;

    NSArray *allOrigins = [frame origins];
    CFIndex count = (CFIndex) [allOrigins count];

    if (range.location == kCFNotFound)
        range = CFRangeMake(0, count);
    if (range.location < 0)
        range.location = 0;
    if (range.location + range.length > count)
        range.length = count - range.location;

    for (CFIndex i = 0; i < range.length; i++)
        origins[i] = [[allOrigins objectAtIndex: range.location + i] pointValue];
}

void CTFrameDraw(CTFrameRef frameRef, CGContextRef context)
{
    CTFrame *frame = (CTFrame *) frameRef;
    if (frame == nil || context == NULL)
        return;

    NSArray *lines = [frame lines];
    NSArray *origins = [frame origins];

    CFIndex count = (CFIndex) [lines count];
    for (CFIndex i = 0; i < count; i++) {
        CGPoint origin = [[origins objectAtIndex: i] pointValue];
        CTLineRef line = (CTLineRef) [lines objectAtIndex: i];

        CGContextSaveGState(context);
        CGContextTranslateCTM(context, origin.x, origin.y);
        CTLineDraw(line, context);
        CGContextRestoreGState(context);
    }
}

