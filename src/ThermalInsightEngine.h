#import <Foundation/Foundation.h>
#import "ThermalMonitor.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ThermalStateLevel) {
    ThermalStateLevelNormal = 0,    // < 60°C
    ThermalStateLevelWarm,          // 60°C - 74°C
    ThermalStateLevelElevated,      // 75°C - 84°C
    ThermalStateLevelHigh,          // 85°C - 94°C
    ThermalStateLevelCritical       // >= 95°C
};

@interface ThermalInsight : NSObject

@property (nonatomic, assign) double currentTemp;
@property (nonatomic, assign) double averageTemp;
@property (nonatomic, assign) ThermalStateLevel level;
@property (nonatomic, copy) NSString *stateDescription;
@property (nonatomic, assign) double rateOfChangePerMinute;
@property (nonatomic, assign) double thermalHeadroom;
@property (nonatomic, copy) NSString *trendDescription;
@property (nonatomic, copy) NSString *naturalLanguageSummary;
@property (nonatomic, copy) NSString *recommendedAction;
@property (nonatomic, strong) ThermalSnapshot *snapshot;

- (NSDictionary<NSString *, id> *)dictionaryRepresentation;
- (NSString *)jsonString;

@end

@interface ThermalInsightEngine : NSObject

+ (instancetype)sharedEngine;

- (void)recordSnapshot:(ThermalSnapshot *)snapshot;
- (ThermalInsight *)currentInsight;

@end

NS_ASSUME_NONNULL_END
