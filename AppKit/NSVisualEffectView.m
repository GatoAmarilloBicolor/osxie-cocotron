#import <AppKit/NSVisualEffectView.h>

@implementation NSVisualEffectView

- (NSVisualEffectMaterial) material {
    return _material;
}

- (void) setMaterial: (NSVisualEffectMaterial) material {
    _material = material;
}

- (NSVisualEffectBlendingMode) blendingMode {
    return _blendingMode;
}

- (void) setBlendingMode: (NSVisualEffectBlendingMode) blendingMode {
    _blendingMode = blendingMode;
}

- (NSVisualEffectState) state {
    return _state;
}

- (void) setState: (NSVisualEffectState) state {
    _state = state;
}

@end
