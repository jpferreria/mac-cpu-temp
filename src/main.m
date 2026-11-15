#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"
#import "ThermalMonitor.h"
#import "ThermalInsightEngine.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc > 1) {
            NSString *arg = [NSString stringWithUTF8String:argv[1]];
            if ([arg isEqualToString:@"--temp"] || [arg isEqualToString:@"-t"]) {
                ThermalSnapshot *snap = [[ThermalMonitor sharedMonitor] currentSnapshot];
                printf("%.1f\n", snap.maxCPUTemp);
                return 0;
            } else if ([arg isEqualToString:@"--status"] || [arg isEqualToString:@"--siri"] || [arg isEqualToString:@"-s"]) {
                ThermalSnapshot *snap = [[ThermalMonitor sharedMonitor] currentSnapshot];
                [[ThermalInsightEngine sharedEngine] recordSnapshot:snap];
                ThermalInsight *insight = [[ThermalInsightEngine sharedEngine] currentInsight];
                printf("%s\n", [insight.naturalLanguageSummary UTF8String]);
                return 0;
            } else if ([arg isEqualToString:@"--json"] || [arg isEqualToString:@"-j"]) {
                ThermalSnapshot *snap = [[ThermalMonitor sharedMonitor] currentSnapshot];
                [[ThermalInsightEngine sharedEngine] recordSnapshot:snap];
                ThermalInsight *insight = [[ThermalInsightEngine sharedEngine] currentInsight];
                printf("%s\n", [[insight jsonString] UTF8String]);
                return 0;
            } else if ([arg isEqualToString:@"--help"] || [arg isEqualToString:@"-h"]) {
                printf("cpu-temp: Apple Silicon CPU & SoC Thermal Monitor\n\n"
                       "Usage: cpu-temp [OPTION]\n\n"
                       "Options:\n"
                       "  (no args)      Launch the macOS menu bar utility\n"
                       "  -t, --temp     Print current max CPU temperature in Celsius\n"
                       "  -s, --status   Print Apple Intelligence natural language thermal summary\n"
                       "  -j, --json     Print full thermal telemetry JSON (for Shortcuts/AI)\n"
                       "  -h, --help     Show this help message\n");
                return 0;
            }
        }

        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory]; // Pure menu bar accessory (no Dock)
        
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        
        [app run];
    }
    return 0;
}
