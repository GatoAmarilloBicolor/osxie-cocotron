#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CTRun.h>
#import <CoreText/CTLine.h>
#import <CoreText/CTFrame.h>
#import <CoreText/CTFrameSetter.h>
#import <CoreText/KTFont.h>

@interface CTRun : NSObject {
    CFIndex _count;
    CGGlyph *_glyphs;
    CGPoint *_positions;
    CGSize *_advances;
    CFIndex *_stringIndices;
    CFRange _stringRange;
    CFDictionaryRef _attributes;
    KTFont *_font;
}
- initWithAttributedString: (CFAttributedStringRef) string range: (CFRange) range;
- (CFIndex) glyphCount;
- (const CGGlyph *) glyphs;
- (const CGPoint *) positions;
- (const CGSize *) advances;
- (const CFIndex *) stringIndices;
- (CFRange) stringRange;
- (CFDictionaryRef) attributes;
- (KTFont *) font;
- (CGFloat) width;
@end

@interface CTLine : NSObject {
    NSArray *_runs;
    CFRange _stringRange;
    CFIndex _glyphCount;
    CGFloat _ascent;
    CGFloat _descent;
    CGFloat _leading;
    CGFloat _width;
    CGFloat _trailingWhitespaceWidth;
}
- initWithAttributedString: (CFAttributedStringRef) string range: (CFRange) range;
- (NSArray *) runs;
- (CFRange) stringRange;
- (CFIndex) glyphCount;
- (CGFloat) ascent;
- (CGFloat) descent;
- (CGFloat) leading;
- (CGFloat) width;
- (CGFloat) trailingWhitespaceWidth;
- (CGFloat) penOffsetForFlush: (CGFloat) flushFactor flushWidth: (CGFloat) flushWidth;
- (CGFloat) offsetForStringIndex: (CFIndex) charIndex secondaryOffset: (CGFloat *) secondaryOffset;
- (CFIndex) stringIndexForPosition: (CGPoint) position;
@end

@interface CTFrame : NSObject {
    NSArray *_lines;
    NSArray *_origins;
    CGPathRef _path;
    CFRange _stringRange;
    CFDictionaryRef _frameAttributes;
}
- initWithLines: (NSArray *) lines
        origins: (NSArray *) origins
           path: (CGPathRef) path
    stringRange: (CFRange) stringRange
frameAttributes: (CFDictionaryRef) frameAttributes;
- (NSArray *) lines;
- (NSArray *) origins;
- (CGPathRef) path;
- (CFRange) stringRange;
- (CFDictionaryRef) frameAttributes;
@end

@interface CTTypesetter : NSObject {
    CFAttributedStringRef _string;
}
- initWithAttributedString: (CFAttributedStringRef) string;
- (CFAttributedStringRef) attributedString;
- (CTLineRef) createLineInRange: (CFRange) range;
- (CFIndex) suggestLineBreak: (CFIndex) start width: (CGFloat) width;
@end

@interface CTFramesetter : NSObject {
    CTTypesetter *_typesetter;
}
- initWithTypesetter: (CTTypesetterRef) typesetter;
- (CTTypesetterRef) typesetter;
- (CTFrameRef) createFrameWithRange: (CFRange) range path: (CGPathRef) path frameAttributes: (CFDictionaryRef) frameAttributes;
- (CGSize) suggestFrameSizeWithConstraints: (CGSize) constraints range: (CFRange) range fitRange: (CFRange *) fitRange;
@end
