#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>

@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSMenu *menu;

@property (assign, nonatomic) NSTimeInterval updateInterval;
@property (assign, nonatomic) BOOL useFahrenheit;

@end
