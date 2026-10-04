#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc __unused, const char * argv[] __unused) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory]; // Pure menu bar accessory (no Dock)
        
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        
        [app run];
    }
    return 0;
}
