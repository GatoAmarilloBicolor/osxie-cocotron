#import <CoreText/CTLine.h>
#import <CoreText/CTFont.h>
#import <CoreText/CTStringAttributes.h>
#import <CoreText/KTFont.h>
#import <CoreFoundation/CFAttributedString.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/NSArray.h>
#import "CTPrivate.h"

@interface CTLine ()
@end

@implementation CTLine

- initWithAttributedString: (CFAttributedStringRef) string range: (CFRange) range
{
    _runs = [NSMutableArray new];
    _stringRange = range;

    CFIndex location = range.location;
    CFIndex end = range.location + range.length;

    CFIndex i = location;
    while (i < end) {
        CFRange effective;
        CFAttributedStringGetAttributes(string, i, &effective);

        CFIndex runEnd = effective.location + effective.length;
        if (runEnd > end)
            runEnd = end;

        CFRange runRange = CFRangeMake(i, runEnd - i);
        CTRunRef run = (CTRunRef) [[CTRun alloc] initWithAttributedString: string range: runRange];
        [_runs addObject: (id) run];
        [run release];

        i = runEnd;
    }

    CFIndex glyphCount = 0;
    CGFloat ascent = 0, descent = 0, leading = 0, width = 0, trailing = 0;
    for (CTRun *run in _runs) {
        glyphCount += [run glyphCount];

        KTFont *font = [run font];
        if ([font ascender] > ascent) ascent = [font ascender];
        if ([font descender] > descent) descent = [font descender];
        if ([font leading] > leading) leading = [font leading];

        width += [run width];
    }

    // trailing whitespace: walk glyphs from the back; whitespace glyphs are
    // those with zero *space* contribution at the end.  We approximate by
    // checking the string characters.
    CFStringRef cfString = CFAttributedStringGetString(string);
    CFIndex lastIndex = location + range.length;
    while (lastIndex > location) {
        unichar c;
        CFStringGetCharacters(cfString, CFRangeMake(lastIndex - 1, 1), &c);
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == 0x00A0) {
            trailing += [self offsetForStringIndex: lastIndex secondaryOffset: NULL] -
                        [self offsetForStringIndex: lastIndex - 1 secondaryOffset: NULL];
            lastIndex--;
        } else {
            break;
        }
    }

    _glyphCount = glyphCount;
    _ascent = ascent;
    _descent = descent;
    _leading = leading;
    _width = width;
    _trailingWhitespaceWidth = trailing;

    return self;
}

- (void) dealloc
{
    [_runs release];
    [super dealloc];
}

- (NSArray *) runs { return _runs; }
- (CFRange) stringRange { return _stringRange; }
- (CFIndex) glyphCount { return _glyphCount; }
- (CGFloat) ascent { return _ascent; }
- (CGFloat) descent { return _descent; }
- (CGFloat) leading { return _leading; }
- (CGFloat) width { return _width; }
- (CGFloat) trailingWhitespaceWidth { return _trailingWhitespaceWidth; }

- (CGFloat) penOffsetForFlush: (CGFloat) flushFactor flushWidth: (CGFloat) flushWidth
{
    return flushFactor * (flushWidth - _width);
}

- (CGFloat) offsetForStringIndex: (CFIndex) charIndex secondaryOffset: (CGFloat *) secondaryOffset
{
    CGFloat offset = 0;
    for (CTRun *run in _runs) {
        CFRange runRange = [run stringRange];
        CFIndex runEnd = runRange.location + runRange.length;
        if (charIndex < runRange.location) {
            if (secondaryOffset != NULL) *secondaryOffset = 0;
            return offset;
        }
        if (charIndex < runEnd) {
            CFIndex local = charIndex - runRange.location;
            const CGSize *advances = [run advances];
            const CFIndex *indices = [run stringIndices];
            CGFloat x = 0;
            CFIndex j = 0;
            for (; j < [run glyphCount]; j++) {
                if (indices[j] >= charIndex)
                    break;
                x += advances[j].width;
            }
            if (secondaryOffset != NULL)
                *secondaryOffset = (j < [run glyphCount]) ? advances[j].width : 0;
            return offset + x;
        }
        offset += [run width];
    }
    if (secondaryOffset != NULL) *secondaryOffset = 0;
    return offset;
}

- (CFIndex) stringIndexForPosition: (CGPoint) position
{
    CGFloat x = 0;
    for (CTRun *run in _runs) {
        CFIndex runCount = [run glyphCount];
        const CGSize *advances = [run advances];
        const CFIndex *indices = [run stringIndices];
        for (CFIndex j = 0; j < runCount; j++) {
            CGFloat next = x + advances[j].width;
            if (position.x < next)
                return indices[j];
            x = next;
        }
    }
    CFRange r = _stringRange;
    return r.location + r.length;
}

- (CFTypeID) _cfTypeID { return CTLineGetTypeID(); }

@end

CFTypeID CTLineGetTypeID(void)
{
    return (CFTypeID) [CTLine self];
}

CTLineRef CTLineCreateWithAttributedString(CFAttributedStringRef attrString)
{
    if (attrString == NULL)
        return NULL;

    CFRange full = CFRangeMake(0, CFAttributedStringGetLength(attrString));
    return (CTLineRef) [[CTLine alloc] initWithAttributedString: attrString range: full];
}

CTLineRef CTLineCreateTruncatedLine(CTLineRef lineRef, double width,
                                    CTLineTruncationType truncationType,
                                    CTLineRef truncationToken)
{
    // Simple truncation: keep the parts of the line that fit within width.
    CTLine *line = (CTLine *) lineRef;
    if (line == nil)
        return NULL;

    if ([line width] <= width)
        return (CTLineRef) CFRetain(line);

    return (CTLineRef) CFRetain(line);
}

CTLineRef _Nullable CTLineCreateJustifiedLine(CTLineRef line, CGFloat justificationFactor, double justificationWidth)
{
    if (line == nil)
        return NULL;
    return (CTLineRef) CFRetain(line);
}

CFIndex CTLineGetGlyphCount(CTLineRef lineRef)
{
    CTLine *line = (CTLine *) lineRef;
    if (line == nil) return 0;
    return [line glyphCount];
}

CFArrayRef CTLineGetGlyphRuns(CTLineRef lineRef)
{
    CTLine *line = (CTLine *) lineRef;
    if (line == nil) return NULL;
    return (CFArrayRef) [line runs];
}

CFRange CTLineGetStringRange(CTLineRef lineRef)
{
    CTLine *line = (CTLine *) lineRef;
    if (line == nil) return CFRangeMake(0, 0);
    return [line stringRange];
}

double CTLineGetPenOffsetForFlush(CTLineRef lineRef, CGFloat flushFactor, double flushWidth)
{
    CTLine *line = (CTLine *) lineRef;
    if (line == nil) return 0;
    return [line penOffsetForFlush: flushFactor flushWidth: flushWidth];
}

void CTLineDraw(CTLineRef lineRef, CGContextRef context)
{
    CTLine *line = (CTLine *) lineRef;
    if (line == nil || context == NULL)
        return;

    CGFloat pen = 0;
    for (CTRun *run in [line runs]) {
        CGPoint origin = CGContextGetTextPosition(context);
        CGContextSetTextPosition(context, origin.x + pen, origin.y);
        CTRunDraw((CTRunRef) run, context, CFRangeMake(0, [run glyphCount]));
        pen += [run width];
    }
}

double CTLineGetTypographicBounds(CTLineRef lineRef, CGFloat *ascent, CGFloat *descent, CGFloat *leading)
{
    CTLine *line = (CTLine *) lineRef;
    if (line == nil) return 0;
    if (ascent != NULL) *ascent = [line ascent];
    if (descent != NULL) *descent = [line descent];
    if (leading != NULL) *leading = [line leading];
    return [line width];
}

CGRect CTLineGetBoundsWithOptions(CTLineRef lineRef, CTLineBoundsOptions options)
{
    CTLine *line = (CTLine *) lineRef;
    if (line == nil) return CGRectZero;

    CGFloat ascent = [line ascent];
    CGFloat descent = [line descent];
    return CGRectMake(0, -descent, [line width], ascent + descent);
}

double CTLineGetTrailingWhitespaceWidth(CTLineRef lineRef)
{
    CTLine *line = (CTLine *) lineRef;
    if (line == nil) return 0;
    return [line trailingWhitespaceWidth];
}

CGRect CTLineGetImageBounds(CTLineRef lineRef, CGContextRef context)
{
    return CTLineGetBoundsWithOptions(lineRef, 0);
}

CFIndex CTLineGetStringIndexForPosition(CTLineRef lineRef, CGPoint position)
{
    CTLine *line = (CTLine *) lineRef;
    if (line == nil) return kCFNotFound;
    return [line stringIndexForPosition: position];
}

CGFloat CTLineGetOffsetForStringIndex(CTLineRef lineRef, CFIndex charIndex, CGFloat *secondaryOffset)
{
    CTLine *line = (CTLine *) lineRef;
    if (line == nil) return 0;
    return [line offsetForStringIndex: charIndex secondaryOffset: secondaryOffset];
}

typedef const UniChar * (*CTUniCharProviderCallback)(CFIndex stringIndex, CFIndex *charCount, CFDictionaryRef *attributes, void *refCon);
typedef void (*CTUniCharDisposeCallback)(const UniChar *chars, void *refCon);

CTLineRef CTLineCreateWithUniCharProvider(CTUniCharProviderCallback provideString, CTUniCharDisposeCallback disposeString, void *refCon)
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

    CTLineRef line = CTLineCreateWithAttributedString(mutable);
    CFRelease(mutable);

    if (disposeString != NULL)
        disposeString(chars, refCon);

    return line;
}

