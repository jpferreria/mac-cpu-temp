#import <Foundation/Foundation.h>
#import "SensorInfo.h"

@interface ThermalSnapshot : NSObject

@property (nonatomic, assign) double maxCPUTemp;
@property (nonatomic, assign) double averageCPUTemp;
@property (nonatomic, strong) NSArray<SensorInfo *> *cpuSensors;
@property (nonatomic, strong) NSArray<SensorInfo *> *batterySensors;
@property (nonatomic, strong) NSArray<SensorInfo *> *storageSensors;
@property (nonatomic, strong) NSArray<SensorInfo *> *otherSensors;
@property (nonatomic, strong) NSArray<SensorInfo *> *allSensors;

@end

@interface ThermalMonitor : NSObject

+ (instancetype)sharedMonitor;

- (ThermalSnapshot *)currentSnapshot;

@end
