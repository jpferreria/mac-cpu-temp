#import "SensorInfo.h"

@implementation SensorInfo

- (instancetype)initWithName:(NSString *)name
          temperatureCelsius:(double)temp
                    category:(SensorCategory)category {
    self = [super init];
    if (self) {
        _name = [name copy];
        _temperatureCelsius = temp;
        _category = category;
    }
    return self;
}

- (double)temperatureInUnit:(BOOL)useFahrenheit {
    if (useFahrenheit) {
        return (self.temperatureCelsius * 9.0 / 5.0) + 32.0;
    }
    return self.temperatureCelsius;
}

- (NSString *)formattedTemperatureWithUnit:(BOOL)useFahrenheit {
    double temp = [self temperatureInUnit:useFahrenheit];
    NSString *unit = useFahrenheit ? @"°F" : @"°C";
    return [NSString stringWithFormat:@"%.1f%@", temp, unit];
}

@end
