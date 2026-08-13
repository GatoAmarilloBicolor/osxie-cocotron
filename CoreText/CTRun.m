#import <CoreText/CTRun.h>
#import <CoreText/CTFont.h>
#import <CoreText/CTStringAttributes.h>
#import <CoreText/KTFont.h>
#import <CoreFoundation/CFAttributedString.h>
#import <CoreGraphics/CoreGraphics.h>
#import <stdlib.h>
#import "CTPrivate.h"

@interface CTRun ()
@end

@implementation CTRun

- initWithAttributedString: (CFAttributedStringRef) string range: (CFRange) range
{
    CFStringRef cfString = CFAttributedStringGetString(string);
    CFIndex length = range.length;

    _count = length;
    _stringRange = range;
    _attributes = CFRetain(CFAttributedStringGetAttributes(string, range.location, NULL));

    _font = (KTFont *) CFDictionaryGetValue(_attributes, kCTFontAttributeName);
    if (_font == nil) {
        _font = (KTFont *) CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, 12.0, NULL);
    } else {
        [_font retain];
    }

    unichar *chars = malloc(sizeof(unichar) * length);
    CFStringGetCharacters(cfString, range, chars);

    _glyphs = malloc(sizeof(CGGlyph) * length);
    [_font getGlyphs: _glyphs forCharacters: chars length: length];

    _advances = malloc(sizeof(CGSize) * length);
    [_font getAdvancements: _advances forGlyphs: _glyphs count: length];

    _positions = malloc(sizeof(CGPoint) * length);
    _stringIndices = malloc(sizeof(CFIndex) * length);

    CGFloat x = 0, y = 0;
    for (CFIndex i = 0; i < length; i++) {
        _positions[i] = CGPointMake(x, y);
        x += _advances[i].width;
        y += _advances[i].height;
        _stringIndices[i] = range.location + i;
    }

    free(chars);
    return self;
}

- (void) dealloc
{
    if (_glyphs != NULL) free(_glyphs);
    if (_positions != NULL) free(_positions);
    if (_advances != NULL) free(_advances);
    if (_stringIndices != NULL) free(_stringIndices);
    if (_attributes != NULL) CFRelease(_attributes);
    if (_font != nil) [_font release];
    [super dealloc];
}

- (CFIndex) glyphCount { return _count; }
- (const CGGlyph *) glyphs { return _glyphs; }
- (const CGPoint *) positions { return _positions; }
- (const CGSize *) advances { return _advances; }
- (const CFIndex *) stringIndices { return _stringIndices; }
- (CFRange) stringRange { return _stringRange; }
- (CFDictionaryRef) attributes { return _attributes; }
- (KTFont *) font { return _font; }

- (CGFloat) width
{
    CGFloat sum = 0;
    for (CFIndex i = 0; i < _count; i++)
        sum += _advances[i].width;
    return sum;
}

- (CFTypeID) _cfTypeID { return CTRunGetTypeID(); }

@end

CFTypeID CTRunGetTypeID(void)
{
    return (CFTypeID) [CTRun self];
}

CFIndex CTRunGetGlyphCount(CTRunRef runRef)
{
    CTRun *run = (CTRun *) runRef;
    return [run glyphCount];
}

CFDictionaryRef CTRunGetAttributes(CTRunRef runRef)
{
    CTRun *run = (CTRun *) runRef;
    return [run attributes];
}

CTRunStatus CTRunGetStatus(CTRunRef runRef)
{
    return kCTRunStatusNoStatus;
}

const CGGlyph * CTRunGetGlyphsPtr(CTRunRef runRef)
{
    CTRun *run = (CTRun *) runRef;
    return [run glyphs];
}

static CFRange _CTRunClampedRange(CFRange range, CFIndex count)
{
    if (range.location == kCFNotFound)
        return CFRangeMake(0, count);
    if (range.location < 0)
        return CFRangeMake(0, count);
    if (range.location + range.length > count)
        range.length = count - range.location;
    if (range.length < 0)
        range.length = 0;
    return range;
}

void CTRunGetGlyphs(CTRunRef runRef, CFRange range, CGGlyph *buffer)
{
    CTRun *run = (CTRun *) runRef;
    CFIndex count = [run glyphCount];
    range = _CTRunClampedRange(range, count);
    const CGGlyph *glyphs = [run glyphs];
    for (CFIndex i = 0; i < range.length; i++)
        buffer[i] = glyphs[range.location + i];
}

const CGPoint * CTRunGetPositionsPtr(CTRunRef runRef)
{
    CTRun *run = (CTRun *) runRef;
    return [run positions];
}

void CTRunGetPositions(CTRunRef runRef, CFRange range, CGPoint *buffer)
{
    CTRun *run = (CTRun *) runRef;
    CFIndex count = [run glyphCount];
    range = _CTRunClampedRange(range, count);
    const CGPoint *positions = [run positions];
    for (CFIndex i = 0; i < range.length; i++)
        buffer[i] = positions[range.location + i];
}

const CGSize * CTRunGetAdvancesPtr(CTRunRef runRef)
{
    CTRun *run = (CTRun *) runRef;
    return [run advances];
}

void CTRunGetAdvances(CTRunRef runRef, CFRange range, CGSize *buffer)
{
    CTRun *run = (CTRun *) runRef;
    CFIndex count = [run glyphCount];
    range = _CTRunClampedRange(range, count);
    const CGSize *advances = [run advances];
    for (CFIndex i = 0; i < range.length; i++)
        buffer[i] = advances[range.location + i];
}

const CFIndex * CTRunGetStringIndicesPtr(CTRunRef runRef)
{
    CTRun *run = (CTRun *) runRef;
    return [run stringIndices];
}

void CTRunGetStringIndices(CTRunRef runRef, CFRange range, CFIndex *buffer)
{
    CTRun *run = (CTRun *) runRef;
    CFIndex count = [run glyphCount];
    range = _CTRunClampedRange(range, count);
    const CFIndex *indices = [run stringIndices];
    for (CFIndex i = 0; i < range.length; i++)
        buffer[i] = indices[range.location + i];
}

CFRange CTRunGetStringRange(CTRunRef runRef)
{
    CTRun *run = (CTRun *) runRef;
    return [run stringRange];
}

double CTRunGetTypographicBounds(CTRunRef runRef, CFRange range, CGFloat *ascent, CGFloat *descent, CGFloat *leading)
{
    CTRun *run = (CTRun *) runRef;
    KTFont *font = [run font];
    CFIndex count = [run glyphCount];
    range = _CTRunClampedRange(range, count);

    if (ascent != NULL) *ascent = [font ascender];
    if (descent != NULL) *descent = [font descender];
    if (leading != NULL) *leading = [font leading];

    const CGSize *advances = [run advances];
    double width = 0;
    for (CFIndex i = 0; i < range.length; i++)
        width += advances[range.location + i].width;
    return width;
}

CGRect CTRunGetImageBounds(CTRunRef runRef, CGContextRef context, CFRange range)
{
    CGFloat ascent, descent, leading;
    double width = CTRunGetTypographicBounds(runRef, range, &ascent, &descent, &leading);
    return CGRectMake(0, -descent, width, ascent + descent);
}

CGAffineTransform CTRunGetTextMatrix(CTRunRef runRef)
{
    return CGAffineTransformIdentity;
}

void CTRunGetBaseAdvancesAndOrigins(CTRunRef runRef, CFRange range, CGSize *advancesBuffer, CGPoint *originsBuffer)
{
    if (advancesBuffer != NULL)
        CTRunGetAdvances(runRef, range, advancesBuffer);
    if (originsBuffer != NULL)
        CTRunGetPositions(runRef, range, originsBuffer);
}

void CTRunDraw(CTRunRef runRef, CGContextRef context, CFRange range)
{
    CTRun *run = (CTRun *) runRef;
    if (run == nil || context == NULL)
        return;

    CFIndex count = [run glyphCount];
    range = _CTRunClampedRange(range, count);

    CGContextSetFont(context, (CGFontRef) [[run font] cgFont]);
    CGContextSetFontSize(context, [[run font] pointSize]);

    CGPoint origin = CGContextGetTextPosition(context);
    const CGGlyph *glyphs = [run glyphs];
    const CGPoint *positions = [run positions];

    for (CFIndex i = 0; i < range.length; i++) {
        CFIndex g = range.location + i;
        CGContextShowGlyphsAtPoint(context,
                                   origin.x + positions[g].x,
                                   origin.y + positions[g].y,
                                       &glyphs[g], 1);
    }
}

