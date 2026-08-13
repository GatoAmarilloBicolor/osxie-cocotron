#import <CoreText/CTFrameSetter.h>
#import <CoreFoundation/CFAttributedString.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/NSArray.h>
#import "CTPrivate.h"

@interface CTTypesetter ()
@end

CFTypeID CTTypesetterGetTypeID(void);

@implementation CTTypesetter

- initWithAttributedString: (CFAttributedStringRef) string
{
    _string = CFRetain(string);
    return self;
}

- (void) dealloc
{
    CFRelease(_string);
    [super dealloc];
}

- (CFAttributedStringRef) attributedString { return _string; }

- (CTLineRef) createLineInRange: (CFRange) range
{
    CTLineRef line = (CTLineRef) [[CTLine alloc] initWithAttributedString: _string range: range];
    return line;
}

- (CFIndex) suggestLineBreak: (CFIndex) start width: (CGFloat) width
{
    CFIndex length = CFAttributedStringGetLength(_string);

    // measure the widest single-character and the full remaining line first
    CTLineRef fullLine = [self createLineInRange: CFRangeMake(start, length - start)];
    double fullWidth = CTLineGetTypographicBounds(fullLine, NULL, NULL, NULL);
    [fullLine release];

    if (fullWidth <= width)
        return length;

    CFIndex lo = start;      // last known index that fits
    CFIndex hi = length;     // first index known to not fit

    while (lo + 1 < hi) {
        CFIndex mid = (lo + hi) / 2;
        CTLineRef line = [self createLineInRange: CFRangeMake(start, mid - start)];
        double w = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
        [line release];
        if (w <= width)
            lo = mid;
        else
            hi = mid;
    }

    // back off to the last whitespace before lo
    CFStringRef string = CFAttributedStringGetString(_string);
    CFIndex i = lo;
    while (i > start) {
        unichar c;
        CFStringGetCharacters(string, CFRangeMake(i - 1, 1), &c);
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
            return i;
        }
        i--;
    }

    return lo;
}

- (CFTypeID) _cfTypeID { return CTTypesetterGetTypeID(); }

@end

CFTypeID CTTypesetterGetTypeID(void)
{
    return (CFTypeID) [CTTypesetter self];
}

CTTypesetterRef CTTypesetterCreateWithAttributedString(CFAttributedStringRef attrString)
{
    if (attrString == NULL)
        return NULL;
    return (CTTypesetterRef) [[CTTypesetter alloc] initWithAttributedString: attrString];
}

CTLineRef CTTypesetterCreateLine(CTTypesetterRef typesetterRef, CFRange range)
{
    CTTypesetter *typesetter = (CTTypesetter *) typesetterRef;
    if (typesetter == nil)
        return NULL;

    if (range.location == kCFNotFound)
        range = CFRangeMake(0, CFAttributedStringGetLength([typesetter attributedString]));

    return [typesetter createLineInRange: range];
}

CFIndex CTTypesetterSuggestLineBreak(CTTypesetterRef typesetterRef, CFIndex startIndex, double width)
{
    CTTypesetter *typesetter = (CTTypesetter *) typesetterRef;
    if (typesetter == nil)
        return startIndex;
    return [typesetter suggestLineBreak: startIndex width: width];
}

typedef const UniChar * (*CTUniCharProviderCallback)(CFIndex stringIndex, CFIndex *charCount, CFDictionaryRef *attributes, void *refCon);
typedef void (*CTUniCharDisposeCallback)(const UniChar *chars, void *refCon);

CTTypesetterRef CTTypesetterCreateWithUniCharProviderAndOptions(CTUniCharProviderCallback provideString, CTUniCharDisposeCallback disposeString, void *refCon, CFDictionaryRef options)
{
    if (provideString == NULL)
        return NULL;

    CFIndex charCount = 0;
    CFDictionaryRef attributes = NULL;
    const UniChar *chars = provideString(0, &charCount, &attributes, refCon);
    if (chars == NULL || charCount <= 0)
        return NULL;

    CFMutableAttributedStringRef mutable = CFAttributedStringCreateMutable(kCFAllocatorDefault, charCount);
    CFStringRef string = CFStringCreateWithCharacters(kCFAllocatorDefault, chars, charCount);
    CFAttributedStringReplaceString(mutable, CFRangeMake(0, 0), string);
    CFRelease(string);
    if (attributes != NULL)
        CFAttributedStringSetAttributes(mutable, CFRangeMake(0, charCount), attributes, YES);

    CTTypesetterRef result = CTTypesetterCreateWithAttributedString(mutable);
    CFRelease(mutable);

    if (disposeString != NULL)
        disposeString(chars, refCon);

    return result;
}

@interface CTFramesetter ()
@end

@implementation CTFramesetter

- initWithTypesetter: (CTTypesetterRef) typesetter
{
    _typesetter = [(CTTypesetter *) typesetter retain];
    return self;
}

- (void) dealloc
{
    [_typesetter release];
    [super dealloc];
}

- (CTTypesetterRef) typesetter { return (CTTypesetterRef) _typesetter; }

- (CTFrameRef) createFrameWithRange: (CFRange) range path: (CGPathRef) path frameAttributes: (CFDictionaryRef) frameAttributes
{
    CFAttributedStringRef string = [_typesetter attributedString];
    CFIndex stringLength = CFAttributedStringGetLength(string);

    if (range.location == kCFNotFound)
        range = CFRangeMake(0, stringLength);
    if (range.location + range.length > stringLength)
        range.length = stringLength - range.location;

    CGRect bounds = CGPathGetBoundingBox(path);
    CGFloat availableWidth = bounds.size.width;
    if (availableWidth <= 0)
        availableWidth = CGFLOAT_MAX;

    CFIndex location = range.location;
    CFIndex end = range.location + range.length;

    NSMutableArray *lines = [NSMutableArray array];
    NSMutableArray *origins = [NSMutableArray array];

    CGFloat top = bounds.origin.y + bounds.size.height;
    CFIndex current = location;
    CGFloat lastLineHeight = 0;

    while (current < end) {
        CFIndex breakIndex = [_typesetter suggestLineBreak: current width: availableWidth];
        if (breakIndex <= current)
            breakIndex = current + 1;
        if (breakIndex > end)
            breakIndex = end;

        CTLineRef line = [_typesetter createLineInRange: CFRangeMake(current, breakIndex - current)];

        CGFloat ascent, descent, leading;
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
        CGFloat lineHeight = ascent + descent + leading;

        CGFloat baselineY = top - ascent;
        CGPoint origin = CGPointMake(bounds.origin.x, baselineY);

        [lines addObject: (id) line];
        [origins addObject: [NSValue valueWithPoint: origin]];
        [line release];

        top -= lineHeight;
        lastLineHeight = lineHeight;
        current = breakIndex;
    }

    CTFrameRef frame = (CTFrameRef) [[CTFrame alloc]
            initWithLines: lines
                  origins: origins
                     path: path
              stringRange: CFRangeMake(location, current - location)
          frameAttributes: frameAttributes];
    return frame;
}

- (CGSize) suggestFrameSizeWithConstraints: (CGSize) constraints range: (CFRange) range fitRange: (CFRange *) fitRange
{
    CFAttributedStringRef string = [_typesetter attributedString];
    CFIndex stringLength = CFAttributedStringGetLength(string);

    if (range.location == kCFNotFound)
        range = CFRangeMake(0, stringLength);
    if (range.location + range.length > stringLength)
        range.length = stringLength - range.location;

    CFIndex location = range.location;
    CFIndex end = range.location + range.length;

    CGFloat maxWidth = 0;
    CGFloat totalHeight = 0;
    CFIndex current = location;

    while (current < end) {
        CGFloat availableWidth = (constraints.width > 0) ? constraints.width : CGFLOAT_MAX;
        CFIndex breakIndex = [_typesetter suggestLineBreak: current width: availableWidth];
        if (breakIndex <= current)
            breakIndex = current + 1;
        if (breakIndex > end)
            breakIndex = end;

        CTLineRef line = [_typesetter createLineInRange: CFRangeMake(current, breakIndex - current)];

        CGFloat ascent, descent, leading;
        double w = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
        CGFloat lineHeight = ascent + descent + leading;

        if (constraints.height > 0 && totalHeight + lineHeight > constraints.height)
            break;

        if (w > maxWidth)
            maxWidth = w;
        totalHeight += lineHeight;
        current = breakIndex;

        [line release];
    }

    if (fitRange != NULL)
        *fitRange = CFRangeMake(location, current - location);

    CGSize result = CGSizeMake(maxWidth, totalHeight);
    if (constraints.width > 0 && result.width < constraints.width)
        result.width = constraints.width;
    return result;
}

- (CFTypeID) _cfTypeID { return CTFramesetterGetTypeID(); }

@end

CFTypeID CTFramesetterGetTypeID(void)
{
    return (CFTypeID) [CTFramesetter self];
}

CTFramesetterRef CTFramesetterCreateWithTypesetter(CTTypesetterRef typesetter)
{
    if (typesetter == NULL)
        return NULL;
    return (CTFramesetterRef) [[CTFramesetter alloc] initWithTypesetter: typesetter];
}

CTFramesetterRef CTFramesetterCreateWithAttributedString(CFAttributedStringRef attrString)
{
    if (attrString == NULL)
        return NULL;
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(attrString);
    CTFramesetterRef result = CTFramesetterCreateWithTypesetter(typesetter);
    CFRelease(typesetter);
    return result;
}

CTFrameRef CTFramesetterCreateFrame(CTFramesetterRef framesetterRef,
                                    CFRange stringRange,
                                    CGPathRef path,
                                    CFDictionaryRef frameAttributes)
{
    CTFramesetter *framesetter = (CTFramesetter *) framesetterRef;
    if (framesetter == nil || path == NULL)
        return NULL;
    return [framesetter createFrameWithRange: stringRange path: path frameAttributes: frameAttributes];
}

CTTypesetterRef CTFramesetterGetTypesetter(CTFramesetterRef framesetterRef)
{
    CTFramesetter *framesetter = (CTFramesetter *) framesetterRef;
    if (framesetter == nil)
        return NULL;
    return [framesetter typesetter];
}

CGSize CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterRef framesetterRef,
                                                    CFRange stringRange,
                                                    CFDictionaryRef frameAttributes,
                                                    CGSize constraints,
                                                    CFRange *fitRange)
{
    CTFramesetter *framesetter = (CTFramesetter *) framesetterRef;
    if (framesetter == nil)
        return CGSizeZero;
    return [framesetter suggestFrameSizeWithConstraints: constraints range: stringRange fitRange: fitRange];
}

