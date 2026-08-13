#import "NSNibAXRelationshipConnector.h"

@implementation NSNibAXRelationshipConnector

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end

@implementation NSNibAXAttributeConnector

- (void) encodeWithCoder: (NSCoder *) aCoder {
    [super encodeWithCoder: aCoder];
}

- (id) initWithCoder: (NSCoder *) coder {
    if (self = [super initWithCoder: coder]) {
        if ([coder allowsKeyedCoding]) {
            NSKeyedUnarchiver *keyed = (NSKeyedUnarchiver *) coder;
            NSString *label = [keyed decodeObjectForKey: @"NSLabel"];
            if (label != nil)
                [self setLabel: label];
        }
    }
    return self;
}

- (void) establishConnection {
    // Accessibility bindings are not supported; nothing to connect.
}

@end
