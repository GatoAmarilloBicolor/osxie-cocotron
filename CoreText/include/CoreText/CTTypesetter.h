#import <CoreText/CTLine.h>

CF_IMPLICIT_BRIDGING_ENABLED

typedef struct __CTTypesetter* CTTypesetterRef;

CORETEXT_EXPORT CFTypeID CTTypesetterGetTypeID(void);
CORETEXT_EXPORT CTTypesetterRef CTTypesetterCreateWithAttributedString(CFAttributedStringRef attrString);

CORETEXT_EXPORT CTTypesetterRef CTTypesetterCreateWithUniCharProvider(const UniChar * (*provideString)(CFIndex stringIndex, CFIndex *charCount, CFDictionaryRef *attributes, void *refCon), void (*disposeString)(const UniChar *chars, void *refCon), void *refCon, CFDictionaryRef options);

CORETEXT_EXPORT CTLineRef CTTypesetterCreateLine(CTTypesetterRef typesetter, CFRange stringRange);

CORETEXT_EXPORT CFIndex CTTypesetterSuggestLineBreak(CTTypesetterRef typesetter, CFIndex startIndex, double width);

CF_IMPLICIT_BRIDGING_DISABLED
