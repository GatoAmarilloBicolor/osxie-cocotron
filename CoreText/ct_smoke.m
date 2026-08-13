#include <CoreText/CoreText.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    CFStringRef keys[1] = { kCTFontAttributeName };
    CFTypeRef vals[1];
    CTFontRef font = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, 12.0, NULL);
    if (!font) { printf("FAIL: no font\n"); return 1; }
    vals[0] = font;

    CFStringRef text = CFSTR("Hello, CoreText!");
    CFMutableAttributedStringRef attr = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    CFAttributedStringReplaceString(attr, CFRangeMake(0, 0), text);
    CFAttributedStringSetAttributes(attr, CFRangeMake(0, CFStringGetLength(text)), (CFDictionaryRef)CFDictionaryCreate(NULL, (const void**)keys, (const void**)vals, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks), true);

    CTTypesetterRef ts = CTTypesetterCreateWithAttributedString(attr);
    if (!ts) { printf("FAIL: no typesetter\n"); return 1; }
    printf("typeid TS=%lu FTS=%lu\n", CTTypesetterGetTypeID(), CTFramesetterGetTypeID());

    CFIndex breakIdx = CTTypesetterSuggestLineBreak(ts, 0, 80.0);
    printf("line break at %ld (len %ld)\n", (long)breakIdx, (long)CFAttributedStringGetLength(attr));

    CTLineRef line = CTTypesetterCreateLine(ts, CFRangeMake(0, breakIdx));
    CGFloat ascent=0, descent=0, leading=0;
    double w = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    printf("line width=%.2f ascent=%.2f descent=%.2f leading=%.2f runs=%ld typeid=%lu\n",
           w, ascent, descent, leading, (long)CTLineGetGlyphCount(line), CTLineGetTypeID());

    CTFramesetterRef fs = CTFramesetterCreateWithAttributedString(attr);
    CFRange fullRange = CFRangeMake(0, CFAttributedStringGetLength(attr));
    CGPathRef path = CGPathCreateWithRect(CGRectMake(0,0,80,60), NULL);
    CTFrameRef frame = CTFramesetterCreateFrame(fs, fullRange, path, NULL);
    CFArrayRef lines = CTFrameGetLines(frame);
    printf("frame lines=%ld typeid=%lu\n", (long)CFArrayGetCount(lines), CTFrameGetTypeID());
    CGPoint origins[8];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, CFArrayGetCount(lines)), origins);
    for (CFIndex i=0;i<CFArrayGetCount(lines);i++)
        printf("  line %ld origin (%.1f, %.1f)\n", (long)i, origins[i].x, origins[i].y);

    CGSize size = CTFramesetterSuggestFrameSizeWithConstraints(fs, fullRange, NULL, CGSizeMake(80,60), NULL);
    printf("suggested size = %.1f x %.1f\n", size.width, size.height);

    {
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGContextRef ctx = CGBitmapContextCreate(NULL, 80, 60, 8, 80*4, cs, kCGImageAlphaPremultipliedLast);
        if (ctx) {
            CGContextSetRGBFillColor(ctx, 1, 0, 0, 1);
            CTFrameDraw(frame, ctx);
            CGContextFlush(ctx);
            unsigned char *px = CGBitmapContextGetData(ctx);
            long ink = 0, total = 80*60;
            for (long i = 0; i < total; i++)
                if (px[i*4+3] != 0) ink++;
            printf("glyph draw: %ld/%ld non-transparent px; sample=[%d %d %d %d] row=%zu\n",
                   ink, total, px[0], px[1], px[2], px[3], CGBitmapContextGetBytesPerRow(ctx));
            CGContextRelease(ctx);
        }
        CGColorSpaceRelease(cs);
    }

    CFRelease(frame); CFRelease(fs); CFRelease(path); CFRelease(line); CFRelease(ts); CFRelease(attr); CFRelease(font);
    printf("OK\n");
    return 0;
}
