/*
   GSNibArchiveKeyedUnarchiver.m

   NIBArchive ("Xcode 8+" compiled nib) decoder for Cocotron.

   Ported to Cocotron from the GNUstep GUI library:

   Copyright (C) 2026 Free Software Foundation, Inc.

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   Adaptations for Cocotron:
   - Apple NIBArchive files wrap the real container object in an NSObject
     whose "IB.objectdata" key references it; the root decode unwraps that.
   - Delegate messages are only sent when the delegate implements them.
   - replaceObject:withObject: is implemented against the per-index decoded
     object table (Cocotron's NSKeyedUnarchiver version relies on CoreFoundation
     state that is never set up here).
*/

#import "GSNibArchiveKeyedUnarchiver.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <objc/runtime.h>
#import <string.h>

#define NIBARCHIVE_MAGIC "NIBArchive"
#define NIBARCHIVE_MAGIC_LENGTH 10

enum {
    GSNibArchiveTypeInt8 = 0,
    GSNibArchiveTypeInt16 = 1,
    GSNibArchiveTypeInt32 = 2,
    GSNibArchiveTypeInt64 = 3,
    GSNibArchiveTypeBoolFalse = 4,
    GSNibArchiveTypeBoolTrue = 5,
    GSNibArchiveTypeFloat = 6,
    GSNibArchiveTypeDouble = 7,
    GSNibArchiveTypeData = 8,
    GSNibArchiveTypeNil = 9,
    GSNibArchiveTypeObjectRef = 10
};

@interface GSNibArchiveObject : NSObject {
   @public
    NSInteger classNameIndex;
    NSInteger valuesIndex;
    NSInteger valueCount;
}
@end

@implementation GSNibArchiveObject
@end

@interface GSNibArchiveValue : NSObject {
   @public
    NSInteger keyIndex;
    uint8_t type;
    id object;
    uint32_t reference;
}
@end

@implementation GSNibArchiveValue
- (void) dealloc {
    [object release];
    [super dealloc];
}
@end

@interface GSNibArchiveClassName : NSObject {
   @public
    NSString *name;
    NSArray *fallbackClassIndexes;
}
@end

@implementation GSNibArchiveClassName
- (void) dealloc {
    [name release];
    [fallbackClassIndexes release];
    [super dealloc];
}
@end

@interface GSNibArchiveKeyedUnarchiver ()
- (BOOL) _parseData: (NSData *)data;
- (id) _decodeObjectAtIndex: (NSUInteger)index;
- (GSNibArchiveValue *) _valueForKey: (NSString *)key;
- (id) _objectForValue: (GSNibArchiveValue *)value;
- (NSNumber *) _numberForValue: (GSNibArchiveValue *)value;
@end

@implementation GSNibArchiveKeyedUnarchiver

static uint32_t
GSReadLE32(const uint8_t *bytes)
{
    return ((uint32_t)bytes[0])
        | (((uint32_t)bytes[1]) << 8)
        | (((uint32_t)bytes[2]) << 16)
        | (((uint32_t)bytes[3]) << 24);
}

static uint64_t
GSReadLE64(const uint8_t *bytes)
{
    return ((uint64_t)GSReadLE32(bytes))
        | (((uint64_t)GSReadLE32(bytes + 4)) << 32);
}

static BOOL
GSReadVarInt(const uint8_t *bytes, NSUInteger length, NSUInteger *offset,
    NSInteger *result)
{
    NSInteger value = 0;
    unsigned shift = 0;

    while (*offset < length && shift < (sizeof(NSInteger) * 8)) {
        uint8_t b = bytes[(*offset)++];

        value |= ((NSInteger)(b & 0x7f)) << shift;
        if ((b & 0x80) != 0) {
            *result = value;
            return YES;
        }
        shift += 7;
    }

    return NO;
}

+ (BOOL) canReadData: (NSData *)data {
    if ([data length] < NIBARCHIVE_MAGIC_LENGTH) {
        return NO;
    }

    return memcmp([data bytes], NIBARCHIVE_MAGIC, NIBARCHIVE_MAGIC_LENGTH) == 0;
}

- (instancetype) initForReadingWithData: (NSData *)data {
    if (data == nil || ![[self class] canReadData: data]) {
        [self release];
        return nil;
    }

    _objectZone = NSDefaultMallocZone();
    _archiveData = [data retain];
    _archiveBytes = [_archiveData bytes];
    _length = [_archiveData length];
    _archiveObjects = [[NSMutableArray alloc] init];
    _keys = [[NSMutableArray alloc] init];
    _values = [[NSMutableArray alloc] init];
    _classNames = [[NSMutableArray alloc] init];
    _decodedObjects = [[NSMutableDictionary alloc] init];
    _classNameMap = [[NSMutableDictionary alloc] init];
    _objectStack = [[NSMutableArray alloc] init];
    _cursorStack = [[NSMutableArray alloc] init];
    _savedClassNames = [[NSMutableArray alloc] init];

    if ([self _parseData: data] == NO) {
        [self release];
        return nil;
    }

    if (getenv("OSXIE_TRACE_NIB")) fprintf(stderr, "[TRACE] unarchiver parsed: archiveObjects=%p(%lu/%lu) classNames=%p(%lu/%lu) decoded=%p values=%p keys=%p\n",
        (void *) _archiveObjects, (unsigned long) [_archiveObjects count],
        (unsigned long) _parsedObjectCount,
        (void *) _classNames, (unsigned long) [_classNames count],
        (unsigned long) _parsedClassNameCount,
        (void *) _decodedObjects, (void *) _values, (void *) _keys);

    return self;
}

- (void) dealloc {
    [_archiveData release];
    [_archiveObjects release];
    [_keys release];
    [_values release];
    [_classNames release];
    [_decodedObjects release];
    [_classNameMap release];
    [_objectStack release];
    [_cursorStack release];
    [_savedClassNames release];
    [super dealloc];
}

- (BOOL) allowsKeyedCoding {
    return YES;
}

- (id) delegate {
    return _archiveDelegate;
}

- (void) setDelegate: (id)delegate {
    _archiveDelegate = delegate;
}

- (void) finishDecoding {
    if (_archiveDelegate != nil
      && [_archiveDelegate respondsToSelector: @selector(unarchiverWillFinish:)]) {
        [_archiveDelegate unarchiverWillFinish: self];
    }
    if (_archiveDelegate != nil
      && [_archiveDelegate respondsToSelector: @selector(unarchiverDidFinish:)]) {
        [_archiveDelegate unarchiverDidFinish: self];
    }
}

- (void) setObjectZone: (NSZone *)zone {
    _objectZone = zone;
}

- (NSZone *) objectZone {
    return _objectZone;
}

- (Class) classForClassName: (NSString *)className {
    return [_classNameMap objectForKey: className];
}

- (void) setClass: (Class)aClass forClassName: (NSString *)className {
    if (className == nil) {
        return;
    }
    if (aClass == nil) {
        [_classNameMap removeObjectForKey: className];
    } else {
        [_classNameMap setObject: aClass forKey: className];
    }
}

- (BOOL) _parseData: (NSData *)data {
    uint32_t objectCount;
    uint32_t offsetObjects;
    uint32_t keyCount;
    uint32_t offsetKeys;
    uint32_t valueCount;
    uint32_t offsetValues;
    uint32_t classNameCount;
    uint32_t offsetClassNames;
    NSUInteger offset;
    NSUInteger i;

    if (_length < 50) {
        return NO;
    }

    objectCount = GSReadLE32(_archiveBytes + 18);
    offsetObjects = GSReadLE32(_archiveBytes + 22);
    keyCount = GSReadLE32(_archiveBytes + 26);
    offsetKeys = GSReadLE32(_archiveBytes + 30);
    valueCount = GSReadLE32(_archiveBytes + 34);
    offsetValues = GSReadLE32(_archiveBytes + 38);
    classNameCount = GSReadLE32(_archiveBytes + 42);
    offsetClassNames = GSReadLE32(_archiveBytes + 46);

    _parsedObjectCount = objectCount;
    _parsedClassNameCount = classNameCount;

    if (offsetObjects > _length || offsetKeys > _length
      || offsetValues > _length || offsetClassNames > _length) {
        return NO;
    }

    offset = offsetObjects;
    for (i = 0; i < objectCount; i++) {
        NSInteger classNameIndex;
        NSInteger valuesIndex;
        NSInteger count;
        GSNibArchiveObject *object;

        if (!GSReadVarInt(_archiveBytes, _length, &offset, &classNameIndex)
          || !GSReadVarInt(_archiveBytes, _length, &offset, &valuesIndex)
          || !GSReadVarInt(_archiveBytes, _length, &offset, &count)
          || classNameIndex < 0 || valuesIndex < 0 || count < 0
          || (NSUInteger)classNameIndex >= classNameCount
          || (NSUInteger)valuesIndex + (NSUInteger)count > valueCount) {
            return NO;
        }

        object = [[GSNibArchiveObject alloc] init];
        object->classNameIndex = classNameIndex;
        object->valuesIndex = valuesIndex;
        object->valueCount = count;
        [_archiveObjects addObject: object];
        [object release];
    }
    if (offset != offsetKeys) {
        return NO;
    }

    for (i = 0; i < keyCount; i++) {
        NSInteger stringLength;
        NSString *key;

        if (!GSReadVarInt(_archiveBytes, _length, &offset, &stringLength)
          || stringLength < 0 || offset + (NSUInteger)stringLength > _length) {
            return NO;
        }
        key = [[NSString alloc] initWithBytes: _archiveBytes + offset
                                       length: stringLength
                                     encoding: NSUTF8StringEncoding];
        if (key == nil) {
            return NO;
        }
        [_keys addObject: key];
        [key release];
        offset += stringLength;
    }
    if (offset != offsetValues) {
        return NO;
    }

    for (i = 0; i < valueCount; i++) {
        NSInteger keyIndex;
        GSNibArchiveValue *value;

        if (!GSReadVarInt(_archiveBytes, _length, &offset, &keyIndex)
          || keyIndex < 0 || (NSUInteger)keyIndex >= keyCount
          || offset >= _length) {
            return NO;
        }

        value = [[GSNibArchiveValue alloc] init];
        value->keyIndex = keyIndex;
        value->type = _archiveBytes[offset++];

        switch (value->type) {
            case GSNibArchiveTypeInt8:
                if (offset + 1 > _length) return NO;
                value->object = [[NSNumber numberWithChar: (int8_t)_archiveBytes[offset]] retain];
                offset += 1;
                break;
            case GSNibArchiveTypeInt16:
                if (offset + 2 > _length) return NO;
                value->object = [[NSNumber numberWithShort:
                    (int16_t)(_archiveBytes[offset] | (_archiveBytes[offset + 1] << 8))] retain];
                offset += 2;
                break;
            case GSNibArchiveTypeInt32:
                if (offset + 4 > _length) return NO;
                value->object = [[NSNumber numberWithInt:
                    (int32_t)GSReadLE32(_archiveBytes + offset)] retain];
                offset += 4;
                break;
            case GSNibArchiveTypeInt64:
                if (offset + 8 > _length) return NO;
                value->object = [[NSNumber numberWithLongLong:
                    (int64_t)GSReadLE64(_archiveBytes + offset)] retain];
                offset += 8;
                break;
            case GSNibArchiveTypeBoolFalse:
                value->object = [[NSNumber numberWithBool: NO] retain];
                break;
            case GSNibArchiveTypeBoolTrue:
                value->object = [[NSNumber numberWithBool: YES] retain];
                break;
            case GSNibArchiveTypeFloat:
                {
                    uint32_t bits;
                    float f;
                    if (offset + 4 > _length) return NO;
                    bits = GSReadLE32(_archiveBytes + offset);
                    memcpy(&f, &bits, sizeof(f));
                    value->object = [[NSNumber numberWithFloat: f] retain];
                    offset += 4;
                }
                break;
            case GSNibArchiveTypeDouble:
                {
                    uint64_t bits;
                    double d;
                    if (offset + 8 > _length) return NO;
                    bits = GSReadLE64(_archiveBytes + offset);
                    memcpy(&d, &bits, sizeof(d));
                    value->object = [[NSNumber numberWithDouble: d] retain];
                    offset += 8;
                }
                break;
            case GSNibArchiveTypeData:
                {
                    NSInteger dataLength;
                    if (!GSReadVarInt(_archiveBytes, _length, &offset, &dataLength)
                      || dataLength < 0 || offset + (NSUInteger)dataLength > _length) {
                        return NO;
                    }
                    value->object = [[NSData alloc] initWithBytes: _archiveBytes + offset
                                                           length: dataLength];
                    offset += dataLength;
                }
                break;
            case GSNibArchiveTypeNil:
                break;
            case GSNibArchiveTypeObjectRef:
                if (offset + 4 > _length) return NO;
                value->reference = GSReadLE32(_archiveBytes + offset);
                if (value->reference >= objectCount) {
                    return NO;
                }
                offset += 4;
                break;
            default:
                return NO;
        }

        [_values addObject: value];
        [value release];
    }
    if (offset != offsetClassNames) {
        return NO;
    }

    for (i = 0; i < classNameCount; i++) {
        NSInteger stringLength;
        NSInteger fallbackCount;
        NSMutableArray *fallbacks;
        GSNibArchiveClassName *className;

        if (!GSReadVarInt(_archiveBytes, _length, &offset, &stringLength)
          || !GSReadVarInt(_archiveBytes, _length, &offset, &fallbackCount)
          || stringLength <= 0 || fallbackCount < 0) {
            return NO;
        }

        fallbacks = [NSMutableArray arrayWithCapacity: fallbackCount];
        while (fallbackCount-- > 0) {
            int32_t fallbackIndex;

            if (offset + 4 > _length) {
                return NO;
            }
            fallbackIndex = (int32_t)GSReadLE32(_archiveBytes + offset);
            if (fallbackIndex < 0 || (NSUInteger)fallbackIndex >= classNameCount) {
                return NO;
            }
            [fallbacks addObject: [NSNumber numberWithInt: fallbackIndex]];
            offset += 4;
        }

        if (offset + (NSUInteger)stringLength > _length
          || _archiveBytes[offset + (NSUInteger)stringLength - 1] != '\0') {
            return NO;
        }

        className = [[GSNibArchiveClassName alloc] init];
        className->name = [[NSString alloc] initWithBytes: _archiveBytes + offset
                                                   length: stringLength - 1
                                                 encoding: NSUTF8StringEncoding];
        if (className->name == nil) {
            [className release];
            return NO;
        }
        className->fallbackClassIndexes = [fallbacks retain];
        [_classNames addObject: className];
        [_savedClassNames addObject: [NSValue valueWithPointer: className]];
        [className release];
        offset += stringLength;
    }

    return YES;
}

- (NSString *) _keyForValue: (GSNibArchiveValue *)value {
    return [_keys objectAtIndex: value->keyIndex];
}

- (GSNibArchiveObject *) _currentObject {
    return [_objectStack lastObject];
}

- (GSNibArchiveValue *) _valueForKey: (NSString *)key {
    GSNibArchiveObject *object = [self _currentObject];
    NSUInteger start;
    NSUInteger end;
    NSUInteger i;

    if (object == nil) {
        return nil;
    }

    start = object->valuesIndex;
    end = start + object->valueCount;
    for (i = start; i < end; i++) {
        GSNibArchiveValue *value = [_values objectAtIndex: i];
        if ([[self _keyForValue: value] isEqual: key]) {
            return value;
        }
    }

    return nil;
}

- (GSNibArchiveValue *) _nextSequentialValue {
    GSNibArchiveObject *object = [self _currentObject];
    NSUInteger cursor;

    if (object == nil || [_cursorStack count] == 0) {
        return nil;
    }

    cursor = [[_cursorStack lastObject] unsignedIntegerValue];
    if (cursor >= (NSUInteger)object->valueCount) {
        return nil;
    }

    [_cursorStack removeLastObject];
    [_cursorStack addObject: [NSNumber numberWithUnsignedInteger: cursor + 1]];
    return [_values objectAtIndex: object->valuesIndex + cursor];
}

- (Class) _classForArchiveClassName: (GSNibArchiveClassName *)archiveClass {
    Class class = Nil;
    
    // Issue #2: Ensure main bundle and loaded bundles are loaded/initialized before class lookup
    [[NSBundle mainBundle] load];

    if (archiveClass != nil && archiveClass->name != nil) {
        class = [self classForClassName: archiveClass->name];

        if (class == Nil) {
            class = [[self class] classForClassName: archiveClass->name];
        }
        if (class == Nil) {
            class = NSClassFromString(archiveClass->name);
        }
        // Fallback: search all loaded classes in runtime if not found
        if (class == Nil) {
            int numClasses = objc_getClassList(NULL, 0);
            if (numClasses > 0) {
                Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
                numClasses = objc_getClassList(classes, numClasses);
                for (int i = 0; i < numClasses; i++) {
                    const char *className = class_getName(classes[i]);
                    if (className && [archiveClass->name isEqualToString: [NSString stringWithUTF8String: className]]) {
                        class = classes[i];
                        break;
                    }
                }
                free(classes);
            }
        }
    }

    if (class == Nil && archiveClass != nil) {
        NSEnumerator *enumerator = [archiveClass->fallbackClassIndexes objectEnumerator];
        NSNumber *fallbackIndex;

        while ((fallbackIndex = [enumerator nextObject]) != nil && class == Nil) {
            GSNibArchiveClassName *fallback =
                [_classNames objectAtIndex: [fallbackIndex unsignedIntegerValue]];
            class = [self _classForArchiveClassName: fallback];
        }
    }
    if (class == Nil && _archiveDelegate != nil
      && [_archiveDelegate respondsToSelector:
        @selector(unarchiver:cannotDecodeObjectOfClassName:originalClasses:)]) {
        class = [_archiveDelegate unarchiver: self
         cannotDecodeObjectOfClassName: (archiveClass != nil ? archiveClass->name : @"Unknown")
                        originalClasses: nil];
    }

    if (class == Nil) {
        NSLog(@"[GSNibArchive] Warning: Unable to resolve class '%@', falling back to NSObject placeholder", (archiveClass != nil ? archiveClass->name : @"Unknown"));
        class = [NSObject class];
    }

    return class;
}

- (void) _replaceObjectAtIndex: (NSUInteger)index
                    withObject: (id)replacement
{
    id object = [_decodedObjects objectForKey:
        [NSNumber numberWithUnsignedInteger: index]];
    if (object != nil && _archiveDelegate != nil
      && [_archiveDelegate respondsToSelector:
        @selector(unarchiver:willReplaceObject:withObject:)]) {
        [_archiveDelegate unarchiver: self
            willReplaceObject: object
                   withObject: replacement];
    }
    [_decodedObjects setObject: replacement forKey:
        [NSNumber numberWithUnsignedInteger: index]];
}

- (id) _decodeObjectAtIndex: (NSUInteger)index {
    if (getenv("OSXIE_TRACE_NIB")) fprintf(stderr, "[TRACE] _decodeObjectAtIndex enter idx=%lu parsedObjs=%lu archiveObjs=%lu classes=%lu\n",
            (unsigned long) index, (unsigned long) _parsedObjectCount,
            (unsigned long) [_archiveObjects count], (unsigned long) [_classNames count]);
    NSNumber *key = [NSNumber numberWithUnsignedInteger: index];
    if (getenv("OSXIE_TRACE_NIB")) fprintf(stderr, "[TRACE] _d step1 key=%p\n", (void *) key);
    id object = [_decodedObjects objectForKey: key];
    if (getenv("OSXIE_TRACE_NIB")) fprintf(stderr, "[TRACE] _d step2 cached=%p\n", (void *) object);
    GSNibArchiveObject *archiveObject;
    GSNibArchiveClassName *archiveClass;
    Class class;
    id result;

    if (object != nil) {
        return object;
    }

    archiveObject = [_archiveObjects objectAtIndex: index];
    if (getenv("OSXIE_TRACE_NIB")) fprintf(stderr, "[TRACE] _d step3 archiveObject=%p clsIdx=%d\n", (void *) archiveObject, (int) archiveObject->classNameIndex);
    if (getenv("OSXIE_TRACE_NIB")) fprintf(stderr, "[TRACE] _decodeObjectAtIndex got archiveObject=%p\n", (void *) archiveObject);
    NSInteger clsIdx = archiveObject->classNameIndex;
    if (clsIdx < 0 || (NSUInteger)clsIdx >= [_classNames count]) {
        if (getenv("OSXIE_TRACE_NIB")) fprintf(stderr, "[TRACE] ** FATAL: invalid classNameIndex %ld at object index %lu\n", (long)clsIdx, (unsigned long)index);
        return nil;
    }
    archiveClass = [_classNames objectAtIndex: clsIdx];
    if ([_archiveObjects count] != _parsedObjectCount
      || [_classNames count] != _parsedClassNameCount
      || archiveClass->name == nil
      || ![(id) archiveClass->name respondsToSelector: @selector(length)]
      || [(NSString *) archiveClass->name length] > 4096) {
        if (getenv("OSXIE_TRACE_NIB")) fprintf(stderr, "[TRACE] ** CORRUPT idx=%lu classIndex=%d name=%p objCount=%lu/%lu clsCount=%lu/%lu\n",
            (unsigned long) index, (int) archiveObject->classNameIndex,
            (void *) archiveClass->name,
            (unsigned long) [_archiveObjects count], (unsigned long) _parsedObjectCount,
            (unsigned long) [_classNames count], (unsigned long) _parsedClassNameCount);
    }
    {
        NSValue *saved = [_savedClassNames objectAtIndex: archiveObject->classNameIndex];
        void *savedPtr = (saved != nil) ? [saved pointerValue] : NULL;
        if (getenv("OSXIE_TRACE_NIB")) fprintf(stderr, "[TRACE] decodeIdx %lu classIndex=%d archiveClass=%p saved=%p name=%p fb=%p\n",
            (unsigned long) index, (int) archiveObject->classNameIndex,
            (void *) archiveClass, savedPtr, (void *) archiveClass->name,
            (void *) archiveClass->fallbackClassIndexes);
    }
    class = [self _classForArchiveClassName: archiveClass];
    if (class == Nil) {
        [NSException raise: NSInvalidUnarchiveOperationException
                    format: @"[%@ -%@]: no class for name '%@'",
          NSStringFromClass([self class]), NSStringFromSelector(_cmd),
          archiveClass->name];
    }

    object = [class allocWithZone: _objectZone];

    // Some classes (NSNumber, NSValue, NSString, NSData, NSTimer, ...)
    // override +allocWithZone: to return a single SHARED placeholder
    // instance.  The placeholder is owned by nobody: its retain count of 1
    // is the "creation" retain, and the alloc " +1" that callers normally
    // receive is virtual.  Sending it an extra -release below would free the
    // shared singleton, so the next +[NSNumber alloc] would hand out the
    // dead placeholder (garbage isa -> crash while dispatching initWithCoder:).
    // Detect the shared instance by asking the class for another alloc
    // result and comparing pointers; the probe is itself balanced by a
    // matching -release when it is NOT the shared singleton.
    BOOL sharedPlaceholder = NO;
    {
        id probe = [class allocWithZone: _objectZone];
        sharedPlaceholder = (probe == object);
        if (!sharedPlaceholder) {
            [probe release];
        }
    }

    [_decodedObjects setObject: object forKey: key];
    [_objectStack addObject: archiveObject];
    [_cursorStack addObject: [NSNumber numberWithUnsignedInteger: 0]];

    // Not every decoded class implements initWithCoder: (plain NSObject
    // wrappers, for example); Cocoa's NSObject does and returns self.
    @try {
        result = ([object respondsToSelector: @selector(initWithCoder:)])
            ? [object initWithCoder: self]
            : object;
    } @catch (NSException *e) {
        NSLog(@"GSNibArchive: exception decoding object index %lu class '%@' reason '%@'",
            (unsigned long)index, archiveClass->name, [e reason]);
        @throw e;
    }

    [_cursorStack removeLastObject];
    [_objectStack removeLastObject];

    if (result != object) {
        [self _replaceObjectAtIndex: index withObject: result];
        if (!sharedPlaceholder) {
            [object release];
        }
        object = [result retain];
    }

    if ([object respondsToSelector: @selector(awakeAfterUsingCoder:)]) {
        result = [object awakeAfterUsingCoder: self];
        if (result != object) {
            [self _replaceObjectAtIndex: index withObject: result];
            if (!sharedPlaceholder) {
                [object release];
            }
            object = [result retain];
        }
    }

    if (_archiveDelegate != nil
      && [_archiveDelegate respondsToSelector:
        @selector(unarchiver:didDecodeObject:)]) {
        result = [_archiveDelegate unarchiver: self didDecodeObject: object];
        if (result != object) {
            [self _replaceObjectAtIndex: index withObject: result];
            if (!sharedPlaceholder) {
                [object release];
            }
            object = [result retain];
        }
    }

    [object release];
    return [_decodedObjects objectForKey: key];
}

- (NSNumber *) _numberForValue: (GSNibArchiveValue *)value {
    id object = [self _objectForValue: value];

    if (object == nil || [object isKindOfClass: [NSNumber class]]) {
        return object;
    }

    [NSException raise: NSInvalidUnarchiveOperationException
                format: @"[%@ -%@]: value for key(%@) is '%@'",
      NSStringFromClass([self class]), NSStringFromSelector(_cmd),
      [self _keyForValue: value], object];
    return nil;
}

- (id) _objectForValue: (GSNibArchiveValue *)value {
    if (value == nil) {
        return nil;
    }

    if (value->type == GSNibArchiveTypeObjectRef) {
        if (getenv("OSXIE_TRACE_NIB")) fprintf(stderr, "[TRACE] objref -> %lu\n", (unsigned long) value->reference);
        return [self _decodeObjectAtIndex: value->reference];
    }
    if (value->type == GSNibArchiveTypeNil) {
        return nil;
    }
    if (value->type == GSNibArchiveTypeData) {
        return value->object;
    }

    return value->object;
}

- (BOOL) containsValueForKey: (NSString *)key {
    if ([self _currentObject] == nil
      && ([key isEqual: @"IB.objectdata"] || [key isEqual: @"root"])) {
        return [_archiveObjects count] > 0;
    }

    return [self _valueForKey: key] != nil;
}

- (id) decodeObjectForKey: (NSString *)key {
    if (![key isEqualToString: @"NS.string"]
      && ![key isEqualToString: @"NS.bytes"]
      && ![key isEqualToString: @"NS.objects"]
      && ![key isEqualToString: @"NS.keys"]
      && ![key isEqualToString: @"NS.classes"]) {
        if (getenv("OSXIE_TRACE_NIB")) NSLog(@"[TRACE] decodeObjectForKey: %@ stack=%lu", key, (unsigned long)[_objectStack count]);
    }
    if ([self _currentObject] == nil
      && ([key isEqual: @"IB.objectdata"] || [key isEqual: @"root"])) {
        id rootObject;

        if ([_archiveObjects count] == 0) {
            return nil;
        }
        rootObject = [self _decodeObjectAtIndex: 0];

        // Apple's NIBArchive files wrap the real container in an NSObject
        // whose "IB.objectdata" key references it.  GNUstep-style files put
        // the container (or an NSData wrapper) at index 0 directly.
        [_objectStack addObject: [_archiveObjects objectAtIndex: 0]];
        id realObject = [self _objectForValue: [self _valueForKey: key]];
        [_objectStack removeLastObject];

        return (realObject != nil) ? realObject : rootObject;
    }

    return [self _objectForValue: [self _valueForKey: key]];
}

- (id) decodeObject {
    return [self _objectForValue: [self _nextSequentialValue]];
}

- (BOOL) decodeBoolForKey: (NSString *)key {
    return [[self _numberForValue: [self _valueForKey: key]] boolValue];
}

- (double) decodeDoubleForKey: (NSString *)key {
    return [[self _numberForValue: [self _valueForKey: key]] doubleValue];
}

- (float) decodeFloatForKey: (NSString *)key {
    return [[self _numberForValue: [self _valueForKey: key]] floatValue];
}

- (int) decodeIntForKey: (NSString *)key {
    return [[self _numberForValue: [self _valueForKey: key]] intValue];
}

- (NSInteger) decodeIntegerForKey: (NSString *)key {
    return [[self _numberForValue: [self _valueForKey: key]] integerValue];
}

- (int32_t) decodeInt32ForKey: (NSString *)key {
    return [[self _numberForValue: [self _valueForKey: key]] intValue];
}

- (int64_t) decodeInt64ForKey: (NSString *)key {
    return [[self _numberForValue: [self _valueForKey: key]] longLongValue];
}

- (const uint8_t *) decodeBytesForKey: (NSString *)key
                       returnedLength: (NSUInteger *)length {
    GSNibArchiveValue *value = [self _valueForKey: key];

    if (value != nil && value->type == GSNibArchiveTypeData) {
        if (length != NULL) {
            *length = [value->object length];
        }
        return [value->object bytes];
    }

    if (length != NULL) {
        *length = 0;
    }
    return NULL;
}

- (id) decodeObjectOfClasses: (NSSet *)classes forKey: (NSString *)key {
    return [self decodeObjectForKey: key];
}

- (id) decodeObjectOfClass: (Class)cls forKey: (NSString *)key {
    return [self decodeObjectForKey: key];
}

- (void) decodeValueOfObjCType: (const char *)type at: (void *)address {
    GSNibArchiveValue *value;
    id object;

    if (type == NULL || address == NULL) {
        return;
    }

    value = [self _nextSequentialValue];
    object = [self _objectForValue: value];

    switch (*type) {
        case _C_ID:
        case _C_CLASS:
            *(id *)address = [object retain];
            return;
        case _C_SEL:
            *(SEL *)address = (object != nil) ? NSSelectorFromString(object) : NULL;
            return;
        case _C_CHR:
            *(char *)address = [object charValue];
            return;
        case _C_UCHR:
            *(unsigned char *)address = [object unsignedCharValue];
            return;
        case _C_SHT:
            *(short *)address = [object shortValue];
            return;
        case _C_USHT:
            *(unsigned short *)address = [object unsignedShortValue];
            return;
        case _C_INT:
            *(int *)address = [object intValue];
            return;
        case _C_UINT:
            *(unsigned int *)address = [object unsignedIntValue];
            return;
        case _C_LNG:
            *(long *)address = [object longValue];
            return;
        case _C_ULNG:
            *(unsigned long *)address = [object unsignedLongValue];
            return;
        case _C_LNG_LNG:
            *(long long *)address = [object longLongValue];
            return;
        case _C_ULNG_LNG:
            *(unsigned long long *)address = [object unsignedLongLongValue];
            return;
        case _C_FLT:
            *(float *)address = [object floatValue];
            return;
        case _C_DBL:
            *(double *)address = [object doubleValue];
            return;
#if defined(_C_BOOL) && (!defined(__GNUC__) || __GNUC__ > 2)
        case _C_BOOL:
            *(_Bool *)address = (_Bool)[object boolValue];
            return;
#endif
        default:
            [NSException raise: NSInvalidArgumentException
                        format: @"-[%@ %@]: unsupported type encoding ('%c')",
              NSStringFromClass([self class]), NSStringFromSelector(_cmd), *type];
    }
}

- (void) replaceObject: (id)object withObject: (id)replacement {
    if (object == nil || object == replacement) {
        return;
    }

    if (_archiveDelegate != nil
      && [_archiveDelegate respondsToSelector:
        @selector(unarchiver:willReplaceObject:withObject:)]) {
        [_archiveDelegate unarchiver: self
            willReplaceObject: object
                   withObject: replacement];
    }

    // Map every decoded object index that still resolves to `object` over to
    // the replacement so future object references decode to the replacement.
    NSArray *keys = [_decodedObjects allKeys];
    for (NSNumber *index in keys) {
        if ([_decodedObjects objectForKey: index] == object) {
            [_decodedObjects setObject: replacement forKey: index];
        }
    }
}

- (id) _decodeArrayOfObjectsForKey: (NSString *)key {
    GSNibArchiveObject *object = [self _currentObject];

    // NIBArchive stores the elements of array/set containers on the container
    // object itself, under a repeated "UINibEncoderEmptyKey" key.  Apple's
    // NSArray/NSMutableArray/NSSet initWithCoder: instead asks for
    // "NS.objects", which does not exist in this format, so synthesize the
    // array from those values directly.
    if (object != nil) {
        GSNibArchiveClassName *archiveClass =
            [_classNames objectAtIndex: object->classNameIndex];
        NSString *className = archiveClass->name;

        if ([className isEqualToString: @"NSArray"]
          || [className isEqualToString: @"NSMutableArray"]
          || [className isEqualToString: @"NSSet"]
          || [className isEqualToString: @"NSMutableSet"]) {
            NSMutableArray *elements = [NSMutableArray array];
            NSUInteger start = object->valuesIndex;
            NSUInteger end = start + object->valueCount;
            NSUInteger i;
            BOOL found = NO;

            for (i = start; i < end; i++) {
                GSNibArchiveValue *value = [_values objectAtIndex: i];
                if ([[self _keyForValue: value]
                        isEqualToString: @"UINibEncoderEmptyKey"]) {
                    id decoded = [self _objectForValue: value];
                    if (decoded != nil) {
                        [elements addObject: decoded];
                    }
                    found = YES;
                }
            }

            if (found) {
                return elements;
            }
        }
    }

    id array = [self decodeObjectForKey: key];

    if (array == nil || [array isKindOfClass: [NSArray class]]) {
        return array;
    }

    return nil;
}

- (id) _decodePropertyListForKey: (NSString *)key {
    GSNibArchiveValue *value = [self _valueForKey: key];

    // NIBArchive stores NSString contents as a Data blob under "NS.bytes"
    // (there is no "NS.string" property).  NSString's initWithCoder: first
    // asks for a property list for "NS.string"; fall back to the bytes so the
    // string decodes to its contents instead of nil.
    if (value == nil && [key isEqualToString: @"NS.string"]) {
        value = [self _valueForKey: @"NS.bytes"];
        if (value != nil && value->type == GSNibArchiveTypeData
          && [value->object isKindOfClass: [NSData class]]) {
            return [[[NSString alloc] initWithBytes: [value->object bytes]
                                             length: [value->object length]
                                           encoding: NSUTF8StringEncoding]
                autorelease];
        }
        return nil;
    }

    return [self decodeObjectForKey: key];
}

@end
