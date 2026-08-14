#import <Cocoa/Cocoa.h>
int main(int argc, char **argv) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    (void)argc; (void)argv;
    NSBundle *b = [NSBundle mainBundle];
    printf("path=%s\n", [[b bundlePath] UTF8String]);
    printf("bundleID=%s\n", [[b bundleIdentifier] UTF8String]);
    NSDictionary *info = [b infoDictionary];
    printf("info keys=%ld\n", (long)[info count]);
    id theme = [info objectForKey:@"theme"];
    printf("theme class=%s count=%ld\n",
           theme ? class_getName([theme class]) : "nil",
           (long)[theme count]);
    if ([theme count] > 0) {
        id dark = [[theme objectAtIndex:0] objectForKey:@"dark"];
        printf("BAR_NORMALCOLOR=%s\n", [[dark objectForKey:@"BAR_NORMALCOLOR"] UTF8String]);
    }
    [pool drain];
    return 0;
}
