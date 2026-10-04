#import "AppDelegate.h"
#import "ThermalMonitor.h"
#import <ServiceManagement/ServiceManagement.h>
#import <sys/sysctl.h>

static NSString * const kPrefUpdateInterval = @"UpdateInterval";
static NSString * const kPrefUseFahrenheit = @"UseFahrenheit";

@interface AppDelegate ()
@property (nonatomic, copy) NSString *hardwareModel;
@property (nonatomic, strong) ThermalSnapshot *latestSnapshot;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Read hardware model
    self.hardwareModel = [self queryHardwareModel];

    // Load preferences
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.updateInterval = [defaults doubleForKey:kPrefUpdateInterval];
    if (self.updateInterval <= 0.0) {
        self.updateInterval = 2.0; // 2 seconds default
    }
    self.useFahrenheit = [defaults boolForKey:kPrefUseFahrenheit];

    // Setup Status Item
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSStatusBarButton *button = self.statusItem.button;
    if (button) {
        button.imagePosition = NSImageLeading;
        button.title = @" --°C";
    }

    // Setup Menu
    self.menu = [[NSMenu alloc] initWithTitle:@"cpu-temp"];
    self.menu.delegate = self;
    self.statusItem.menu = self.menu;

    // Register sleep/wake notifications to conserve battery
    NSNotificationCenter *workspaceCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
    [workspaceCenter addObserver:self
                        selector:@selector(screensDidSleep:)
                            name:NSWorkspaceScreensDidSleepNotification
                          object:nil];
    [workspaceCenter addObserver:self
                        selector:@selector(screensDidWake:)
                            name:NSWorkspaceScreensDidWakeNotification
                          object:nil];
    [workspaceCenter addObserver:self
                        selector:@selector(systemWillSleep:)
                            name:NSWorkspaceWillSleepNotification
                          object:nil];
    [workspaceCenter addObserver:self
                        selector:@selector(systemDidWake:)
                            name:NSWorkspaceDidWakeNotification
                          object:nil];

    // Perform initial read and start timer
    [self updateTemperature];
    [self startTimer];
}

- (NSString *)queryHardwareModel {
    char model[256] = {0};
    size_t size = sizeof(model) - 1;
    if (sysctlbyname("hw.model", model, &size, NULL, 0) == 0) {
        model[size] = '\0';
        return [NSString stringWithUTF8String:model];
    }
    return @"Apple Silicon Mac";
}

#pragma mark - Timer & Polling

- (void)startTimer {
    [self stopTimer];
    self.timer = [NSTimer timerWithTimeInterval:self.updateInterval
                                         target:self
                                       selector:@selector(timerFired:)
                                       userInfo:nil
                                        repeats:YES];
    // Use tolerance to allow macOS to coalesce wakeups and save energy
    self.timer.tolerance = 0.5;
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)stopTimer {
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)timerFired:(NSTimer *)timer {
    [self updateTemperature];
}

- (void)updateTemperature {
    self.latestSnapshot = [[ThermalMonitor sharedMonitor] currentSnapshot];
    double maxCelsius = self.latestSnapshot.maxCPUTemp;

    if (maxCelsius <= 0.0) {
        self.statusItem.button.title = @" --°C";
        return;
    }

    // Choose SF Symbol based on temperature
    NSString *symbolName = @"thermometer.low";
    if (maxCelsius >= 80.0) {
        symbolName = @"thermometer.high";
    } else if (maxCelsius >= 60.0) {
        symbolName = @"thermometer.medium";
    }

    NSImage *icon = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:@"CPU Temperature"];
    if (icon) {
        icon.template = YES;
        self.statusItem.button.image = icon;
    }

    // Format display string
    if (self.useFahrenheit) {
        double fahrenheit = (maxCelsius * 9.0 / 5.0) + 32.0;
        self.statusItem.button.title = [NSString stringWithFormat:@" %.0f°F", fahrenheit];
    } else {
        self.statusItem.button.title = [NSString stringWithFormat:@" %.0f°C", maxCelsius];
    }
}

#pragma mark - Sleep / Wake Handling

- (void)screensDidSleep:(NSNotification *)note {
    [self stopTimer];
}

- (void)screensDidWake:(NSNotification *)note {
    [self updateTemperature];
    [self startTimer];
}

- (void)systemWillSleep:(NSNotification *)note {
    [self stopTimer];
}

- (void)systemDidWake:(NSNotification *)note {
    [self updateTemperature];
    [self startTimer];
}

#pragma mark - NSMenuDelegate (Dynamic Menu Construction)

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];

    // 1. Header with Model Info
    NSString *headerText = [NSString stringWithFormat:@"cpu-temp  •  %@", self.hardwareModel];
    NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:headerText action:nil keyEquivalent:@""];
    headerItem.enabled = NO;
    [menu addItem:headerItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // 2. Summary Items
    double maxC = self.latestSnapshot.maxCPUTemp;
    double avgC = self.latestSnapshot.averageCPUTemp;
    NSString *unitStr = self.useFahrenheit ? @"°F" : @"°C";

    double displayMax = self.useFahrenheit ? (maxC * 9.0 / 5.0 + 32.0) : maxC;
    double displayAvg = self.useFahrenheit ? (avgC * 9.0 / 5.0 + 32.0) : avgC;

    NSMenuItem *maxItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Max CPU Temp:       %.1f%@", displayMax, unitStr]
                                                     action:nil
                                              keyEquivalent:@""];
    maxItem.enabled = NO;
    [menu addItem:maxItem];

    NSMenuItem *avgItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Average SoC Temp:  %.1f%@", displayAvg, unitStr]
                                                     action:nil
                                              keyEquivalent:@""];
    avgItem.enabled = NO;
    [menu addItem:avgItem];

    // Battery & Storage if present
    if (self.latestSnapshot.batterySensors.count > 0) {
        SensorInfo *bat = self.latestSnapshot.batterySensors.firstObject;
        double batVal = [bat temperatureInUnit:self.useFahrenheit];
        NSMenuItem *batItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Battery Temp:          %.1f%@", batVal, unitStr]
                                                         action:nil
                                                  keyEquivalent:@""];
        batItem.enabled = NO;
        [menu addItem:batItem];
    }

    if (self.latestSnapshot.storageSensors.count > 0) {
        SensorInfo *nand = self.latestSnapshot.storageSensors.firstObject;
        double nandVal = [nand temperatureInUnit:self.useFahrenheit];
        NSMenuItem *nandItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Storage (NAND):       %.1f%@", nandVal, unitStr]
                                                          action:nil
                                                   keyEquivalent:@""];
        nandItem.enabled = NO;
        [menu addItem:nandItem];
    }

    [menu addItem:[NSMenuItem separatorItem]];

    // 3. Submenu: All CPU / SoC Sensors
    NSMenuItem *cpuSensorsMenuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"SoC Sensors (%lu)", (unsigned long)self.latestSnapshot.cpuSensors.count]
                                                                action:nil
                                                         keyEquivalent:@""];
    NSMenu *cpuSubmenu = [[NSMenu alloc] initWithTitle:@"SoC Sensors"];
    for (SensorInfo *sensor in self.latestSnapshot.cpuSensors) {
        const char *cName = sensor.name ? [sensor.name UTF8String] : "Unknown";
        NSString *sTitle = [NSString stringWithFormat:@"%-24s  %@", cName, [sensor formattedTemperatureWithUnit:self.useFahrenheit]];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:sTitle action:nil keyEquivalent:@""];
        item.enabled = NO;
        [cpuSubmenu addItem:item];
    }
    cpuSensorsMenuItem.submenu = cpuSubmenu;
    [menu addItem:cpuSensorsMenuItem];

    // 4. Submenu: Other System Sensors
    if (self.latestSnapshot.otherSensors.count > 0) {
        NSMenuItem *otherMenuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Other Sensors (%lu)", (unsigned long)self.latestSnapshot.otherSensors.count]
                                                               action:nil
                                                        keyEquivalent:@""];
        NSMenu *otherSubmenu = [[NSMenu alloc] initWithTitle:@"Other Sensors"];
        for (SensorInfo *sensor in self.latestSnapshot.otherSensors) {
            const char *cName = sensor.name ? [sensor.name UTF8String] : "Unknown";
            NSString *sTitle = [NSString stringWithFormat:@"%-24s  %@", cName, [sensor formattedTemperatureWithUnit:self.useFahrenheit]];
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:sTitle action:nil keyEquivalent:@""];
            item.enabled = NO;
            [otherSubmenu addItem:item];
        }
        otherMenuItem.submenu = otherSubmenu;
        [menu addItem:otherMenuItem];
    }

    [menu addItem:[NSMenuItem separatorItem]];

    // 5. Settings: Update Interval
    NSMenuItem *intervalMenu = [[NSMenuItem alloc] initWithTitle:@"Update Interval" action:nil keyEquivalent:@""];
    NSMenu *intervalSubmenu = [[NSMenu alloc] initWithTitle:@"Update Interval"];

    NSArray *intervals = @[@(1.0), @(2.0), @(5.0)];
    NSArray *intervalLabels = @[@"1 second (Fast)", @"2 seconds (Default)", @"5 seconds (Power Saver)"];
    for (NSUInteger i = 0; i < intervals.count; i++) {
        double val = [intervals[i] doubleValue];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:intervalLabels[i]
                                                      action:@selector(selectInterval:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = intervals[i];
        item.state = (fabs(self.updateInterval - val) < 0.1) ? NSControlStateValueOn : NSControlStateValueOff;
        [intervalSubmenu addItem:item];
    }
    intervalMenu.submenu = intervalSubmenu;
    [menu addItem:intervalMenu];

    // 6. Settings: Temperature Unit
    NSMenuItem *unitMenu = [[NSMenuItem alloc] initWithTitle:@"Temperature Unit" action:nil keyEquivalent:@""];
    NSMenu *unitSubmenu = [[NSMenu alloc] initWithTitle:@"Temperature Unit"];

    NSMenuItem *cItem = [[NSMenuItem alloc] initWithTitle:@"Celsius (°C)" action:@selector(selectCelsius:) keyEquivalent:@""];
    cItem.target = self;
    cItem.state = !self.useFahrenheit ? NSControlStateValueOn : NSControlStateValueOff;
    [unitSubmenu addItem:cItem];

    NSMenuItem *fItem = [[NSMenuItem alloc] initWithTitle:@"Fahrenheit (°F)" action:@selector(selectFahrenheit:) keyEquivalent:@""];
    fItem.target = self;
    fItem.state = self.useFahrenheit ? NSControlStateValueOn : NSControlStateValueOff;
    [unitSubmenu addItem:fItem];

    unitMenu.submenu = unitSubmenu;
    [menu addItem:unitMenu];

    // 7. Launch at Login Toggle
    NSMenuItem *loginItem = [[NSMenuItem alloc] initWithTitle:@"Launch at Login" action:@selector(toggleLaunchAtLogin:) keyEquivalent:@""];
    loginItem.target = self;
    loginItem.state = [self isLaunchAtLoginEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:loginItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // 8. Refresh Now
    NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:@"Refresh Now" action:@selector(refreshNow:) keyEquivalent:@"r"];
    refreshItem.target = self;
    [menu addItem:refreshItem];

    // 9. Quit Action
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit cpu-temp" action:@selector(quitApp:) keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];
}

#pragma mark - Actions

- (void)selectInterval:(NSMenuItem *)sender {
    NSNumber *val = (NSNumber *)sender.representedObject;
    self.updateInterval = [val doubleValue];
    [[NSUserDefaults standardUserDefaults] setDouble:self.updateInterval forKey:kPrefUpdateInterval];
    [self startTimer];
}

- (void)selectCelsius:(NSMenuItem *)sender {
    self.useFahrenheit = NO;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kPrefUseFahrenheit];
    [self updateTemperature];
}

- (void)selectFahrenheit:(NSMenuItem *)sender {
    self.useFahrenheit = YES;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kPrefUseFahrenheit];
    [self updateTemperature];
}

- (void)refreshNow:(id)sender {
    [self updateTemperature];
}

- (void)quitApp:(id)sender {
    [self stopTimer];
    [NSApp terminate:nil];
}

- (void)dealloc {
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    [self stopTimer];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    [self stopTimer];
}

#pragma mark - Launch at Login

- (BOOL)isLaunchAtLoginEnabled {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = [SMAppService mainAppService];
        return (service.status == SMAppServiceStatusEnabled);
    }
    return NO;
}

- (void)toggleLaunchAtLogin:(NSMenuItem *)sender {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = [SMAppService mainAppService];
        NSError *error = nil;
        if (service.status == SMAppServiceStatusEnabled) {
            if (![service unregisterAndReturnError:&error]) {
                NSLog(@"[cpu-temp] Failed to unregister from login items: %@", error.localizedDescription);
            }
        } else {
            if (![service registerAndReturnError:&error]) {
                NSLog(@"[cpu-temp] Failed to register as login item: %@", error.localizedDescription);
            }
        }
    }
}

@end
