#import "ThermalMonitor.h"
#import <IOKit/IOKitLib.h>

typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEvent *IOHIDEventRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef key);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t param);
extern double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

#define kIOHIDEventTypeTemperature 15
#define IOHIDEventFieldBase(type) ((type) << 16)

@implementation ThermalSnapshot
@end

@interface ThermalMonitor ()
@property (nonatomic, assign) IOHIDEventSystemClientRef hidClient;
@end

@implementation ThermalMonitor

+ (instancetype)sharedMonitor {
    static ThermalMonitor *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupClient];
    }
    return self;
}

- (void)setupClient {
    if (_hidClient) {
        CFRelease(_hidClient);
        _hidClient = NULL;
    }

    _hidClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!_hidClient) {
        return;
    }

    int page = 0xff00;
    int usage = 5;
    CFNumberRef pageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &page);
    CFNumberRef usageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usage);
    const void *keys[] = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
    const void *vals[] = { pageNum, usageNum };
    CFDictionaryRef match = CFDictionaryCreate(kCFAllocatorDefault, keys, vals, 2,
                                               &kCFTypeDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);
    CFRelease(pageNum);
    CFRelease(usageNum);

    IOHIDEventSystemClientSetMatching(_hidClient, match);
    CFRelease(match);
}

- (void)dealloc {
    if (_hidClient) {
        CFRelease(_hidClient);
        _hidClient = NULL;
    }
}

- (SensorCategory)classifySensorName:(NSString *)name {
    NSString *lower = [name lowercaseString];
    if ([lower containsString:@"battery"] || [lower containsString:@"gas gauge"]) {
        return SensorCategoryBattery;
    }
    if ([lower containsString:@"nand"]) {
        return SensorCategoryStorage;
    }
    if ([lower containsString:@"tdie"] ||
        [lower containsString:@"soc"] ||
        [lower containsString:@"acc"] ||
        [lower containsString:@"cpu"] ||
        [lower containsString:@"gpu"] ||
        [lower containsString:@"core"]) {
        return SensorCategoryCPUSoC;
    }
    return SensorCategoryOther;
}

- (ThermalSnapshot *)currentSnapshot {
    @synchronized (self) {
        if (!_hidClient) {
            [self setupClient];
            if (!_hidClient) {
                return [[ThermalSnapshot alloc] init];
            }
        }

        CFArrayRef services = IOHIDEventSystemClientCopyServices(_hidClient);
        if (!services) {
            // Retry client setup once in case of service restart
            [self setupClient];
            services = IOHIDEventSystemClientCopyServices(_hidClient);
            if (!services) {
                return [[ThermalSnapshot alloc] init];
            }
        }

        CFIndex count = CFArrayGetCount(services);
        NSMutableArray<SensorInfo *> *allSensors = [NSMutableArray arrayWithCapacity:count];
        NSMutableArray<SensorInfo *> *cpuSensors = [NSMutableArray array];
        NSMutableArray<SensorInfo *> *batterySensors = [NSMutableArray array];
        NSMutableArray<SensorInfo *> *storageSensors = [NSMutableArray array];
        NSMutableArray<SensorInfo *> *otherSensors = [NSMutableArray array];

        double maxCPUTemp = 0.0;
        double sumCPUTemp = 0.0;
        NSInteger cpuCount = 0;

        for (CFIndex i = 0; i < count; i++) {
            IOHIDServiceClientRef s = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
            CFTypeRef rawProduct = IOHIDServiceClientCopyProperty(s, CFSTR("Product"));
            NSString *name = @"Unknown Sensor";
            if (rawProduct) {
                if (CFGetTypeID(rawProduct) == CFStringGetTypeID()) {
                    name = (__bridge_transfer NSString *)rawProduct;
                } else {
                    CFRelease(rawProduct);
                }
            }

            IOHIDEventRef event = IOHIDServiceClientCopyEvent(s, kIOHIDEventTypeTemperature, 0, 0);
            if (event) {
                double temp = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
                CFRelease(event);

                // Filter out NaN, infinity, or physically invalid readings (< 0 or > 125 C)
                if (isnan(temp) || isinf(temp) || temp <= 0.0 || temp > 125.0) {
                    continue;
                }

            SensorCategory category = [self classifySensorName:name];
            SensorInfo *info = [[SensorInfo alloc] initWithName:name
                                             temperatureCelsius:temp
                                                       category:category];
            [allSensors addObject:info];

            switch (category) {
                case SensorCategoryCPUSoC: {
                    // Exclude calibration constants like "tcal" from max temp
                    if (![[name lowercaseString] containsString:@"tcal"]) {
                        if (temp > maxCPUTemp) {
                            maxCPUTemp = temp;
                        }
                        sumCPUTemp += temp;
                        cpuCount++;
                    }
                    [cpuSensors addObject:info];
                    break;
                }
                case SensorCategoryBattery:
                    [batterySensors addObject:info];
                    break;
                case SensorCategoryStorage:
                    [storageSensors addObject:info];
                    break;
                case SensorCategoryOther:
                    [otherSensors addObject:info];
                    break;
            }
        }
    }

    CFRelease(services);

    // Sort CPU sensors descending by temperature
    NSSortDescriptor *sortDesc = [NSSortDescriptor sortDescriptorWithKey:@"temperatureCelsius" ascending:NO];
    [cpuSensors sortUsingDescriptors:@[sortDesc]];

    ThermalSnapshot *snapshot = [[ThermalSnapshot alloc] init];
    snapshot.maxCPUTemp = maxCPUTemp;
    snapshot.averageCPUTemp = (cpuCount > 0) ? (sumCPUTemp / cpuCount) : 0.0;
    snapshot.cpuSensors = cpuSensors;
    snapshot.batterySensors = batterySensors;
    snapshot.storageSensors = storageSensors;
    snapshot.otherSensors = otherSensors;
    snapshot.allSensors = allSensors;

        return snapshot;
    }
}

@end
