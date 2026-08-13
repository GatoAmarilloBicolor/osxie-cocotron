#import <AppKit/NSView.h>

typedef NS_ENUM(NSInteger, NSVisualEffectMaterial) {
    NSVisualEffectMaterialAppearanceBased = 0,
    NSVisualEffectMaterialLight = 1,
    NSVisualEffectMaterialDark = 2,
    NSVisualEffectMaterialTitlebar = 3,
    NSVisualEffectMaterialSelection = 4,
    NSVisualEffectMaterialMenu = 5,
    NSVisualEffectMaterialPopover = 6,
    NSVisualEffectMaterialSidebar = 7,
    NSVisualEffectMaterialHeaderView = 8,
    NSVisualEffectMaterialSheet = 9,
    NSVisualEffectMaterialWindowBackground = 10,
    NSVisualEffectMaterialHUDWindow = 11,
    NSVisualEffectMaterialFullScreenUI = 15,
    NSVisualEffectMaterialToolTip = 17,
    NSVisualEffectMaterialContentBackground = 18,
    NSVisualEffectMaterialUnderWindowBackground = 21,
    NSVisualEffectMaterialUnderPageBackground = 22,
};

typedef NS_ENUM(NSInteger, NSVisualEffectBlendingMode) {
    NSVisualEffectBlendingModeBehindWindow = 0,
    NSVisualEffectBlendingModeWithinWindow = 1,
};

typedef NS_ENUM(NSInteger, NSVisualEffectState) {
    NSVisualEffectStateFollowsWindowActiveState = 0,
    NSVisualEffectStateActive = 1,
    NSVisualEffectStateInactive = 2,
};

@interface NSVisualEffectView : NSView {
    NSVisualEffectMaterial _material;
    NSVisualEffectBlendingMode _blendingMode;
    NSVisualEffectState _state;
}
- (NSVisualEffectMaterial) material;
- (void) setMaterial: (NSVisualEffectMaterial) material;
- (NSVisualEffectBlendingMode) blendingMode;
- (void) setBlendingMode: (NSVisualEffectBlendingMode) blendingMode;
- (NSVisualEffectState) state;
- (void) setState: (NSVisualEffectState) state;
@end
