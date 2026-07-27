#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSRect frame = NSMakeRect(100, 100, 400, 300);
    NSWindowStyleMask style = NSWindowStyleMaskTitled |
                              NSWindowStyleMaskClosable |
                              NSWindowStyleMaskResizable |
                              NSWindowStyleMaskMiniaturizable;

    _window = [[NSWindow alloc] initWithContentRect:frame
                                          styleMask:style
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    [_window setTitle:@"Osxie Test"];
    [_window makeKeyAndOrderFront:nil];

    NSView *contentView = [_window contentView];
    NSRect bounds = [contentView bounds];

    NSTextField *label = [NSTextField labelWithString:@"Hello from Osxie!"];
    [label setFrame:NSMakeRect(120, bounds.size.height / 2 - 15, 160, 30)];
    [label setFont:[NSFont systemFontOfSize:18]];
    [label setTextColor:[NSColor blueColor]];
    [contentView addSubview:label];

    NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(150, 40, 100, 32)];
    [button setTitle:@"Click Me"];
    [button setBezelStyle:NSRoundedBezelStyle];
    [button setTarget:self];
    [button setAction:@selector(buttonClicked:)];
    [contentView addSubview:button];

    NSLog(@"[OSXIE] TestWindow launched successfully");
}

- (void)buttonClicked:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Hello!"];
    [alert setInformativeText:@"Osxie GUI is working."];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
    NSLog(@"[OSXIE] Button clicked - GUI interaction works");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
