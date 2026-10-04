#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SensorCategory) {
    SensorCategoryCPUSoC,
    SensorCategoryBattery,
    SensorCategoryStorage,
    SensorCategoryOther
};

@interface SensorInfo : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) double temperatureCelsius;
@property (nonatomic, assign) SensorCategory category;

- (instancetype)initWithName:(NSString *)name
          temperatureCelsius:(double)temp
                    category:(SensorCategory)category;

- (double)temperatureInUnit:(BOOL)useFahrenheit;
- (NSString *)formattedTemperatureWithUnit:(BOOL)useFahrenheit;

@end
