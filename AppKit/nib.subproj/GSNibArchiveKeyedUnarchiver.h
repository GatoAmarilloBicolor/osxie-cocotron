/*
   GSNibArchiveKeyedUnarchiver.h

   NIBArchive ("Xcode 8+" compiled nib) decoder for Cocotron.

   Ported to Cocotron from the GNUstep GUI library:

   Copyright (C) 2026 Free Software Foundation, Inc.

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
*/

#import <Foundation/NSKeyedArchiver.h>

@class NSData;

@interface GSNibArchiveKeyedUnarchiver : NSKeyedUnarchiver {
   @private
    NSData *_archiveData;
    const uint8_t *_archiveBytes;
    NSUInteger _length;
    NSMutableArray *_archiveObjects;
    NSMutableArray *_keys;
    NSMutableArray *_values;
    NSMutableArray *_classNames;
    NSMutableDictionary *_decodedObjects;
    NSMutableDictionary *_classNameMap;
    NSMutableArray *_objectStack;
    NSMutableArray *_cursorStack;
    id _archiveDelegate;
    NSZone *_objectZone;
}

+ (BOOL) canReadData: (NSData *)data;
- (instancetype) initForReadingWithData: (NSData *)data;

@end
