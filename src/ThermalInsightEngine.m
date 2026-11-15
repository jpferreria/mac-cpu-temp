#import "ThermalInsightEngine.h"

@interface ThermalSample : NSObject
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, assign) double temperature;
@end

@implementation ThermalSample
@end

@implementation ThermalInsight

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"currentTempCelsius": @(self.currentTemp),
        @"averageTempCelsius": @(self.averageTemp),
        @"state": self.stateDescription ?: @"Unknown",
        @"rateOfChangePerMinute": @(self.rateOfChangePerMinute),
        @"thermalHeadroomCelsius": @(self.thermalHeadroom),
        @"trend": self.trendDescription ?: @"Stable",
        @"summary": self.naturalLanguageSummary ?: @"",
        @"recommendation": self.recommendedAction ?: @"",
        @"sensorCount": @(self.snapshot.allSensors.count)
    };
}

- (NSString *)jsonString {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self dictionaryRepresentation]
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];
    if (data && !error) {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return @"{}";
}

@end

@interface ThermalInsightEngine ()
@property (nonatomic, strong) NSMutableArray<ThermalSample *> *samples;
@property (nonatomic, strong) ThermalSnapshot *lastSnapshot;
@end

@implementation ThermalInsightEngine

+ (instancetype)sharedEngine {
    static ThermalInsightEngine *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _samples = [NSMutableArray arrayWithCapacity:60];
    }
    return self;
}

- (void)recordSnapshot:(ThermalSnapshot *)snapshot {
    @synchronized (self) {
        if (!snapshot || snapshot.maxCPUTemp <= 0.0) {
            return;
        }

        self.lastSnapshot = snapshot;
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

        ThermalSample *sample = [[ThermalSample alloc] init];
        sample.timestamp = now;
        sample.temperature = snapshot.maxCPUTemp;
        [self.samples addObject:sample];

        // Retain only the last 60 seconds of samples
        while (self.samples.count > 0 && (now - self.samples.firstObject.timestamp > 60.0)) {
            [self.samples removeObjectAtIndex:0];
        }
    }
}

- (ThermalInsight *)currentInsight {
    @synchronized (self) {
        ThermalSnapshot *snap = self.lastSnapshot;
        if (!snap) {
            snap = [[ThermalMonitor sharedMonitor] currentSnapshot];
            [self recordSnapshot:snap];
        }

        double current = snap.maxCPUTemp;
        double avg = snap.averageCPUTemp;
        double headroom = MAX(0.0, 100.0 - current);

        // Determine rate of change (°C / min)
        double rate = 0.0;
        if (self.samples.count >= 2) {
            ThermalSample *oldest = self.samples.firstObject;
            ThermalSample *newest = self.samples.lastObject;
            NSTimeInterval dt = newest.timestamp - oldest.timestamp;
            if (dt >= 2.0) {
                rate = ((newest.temperature - oldest.temperature) / dt) * 60.0;
            }
        }

        // Determine thermal level and descriptions
        ThermalStateLevel level;
        NSString *stateStr;
        NSString *recommendation;

        if (current < 60.0) {
            level = ThermalStateLevelNormal;
            stateStr = @"Normal";
            recommendation = @"Safe thermal envelope for fanless operation.";
        } else if (current < 75.0) {
            level = ThermalStateLevelWarm;
            stateStr = @"Warm";
            recommendation = @"Nominal operating temperature under active multitasking.";
        } else if (current < 85.0) {
            level = ThermalStateLevelElevated;
            stateStr = @"Elevated";
            recommendation = @"Heavy workload active (e.g., compilation or AI model inference).";
        } else if (current < 95.0) {
            level = ThermalStateLevelHigh;
            stateStr = @"High";
            recommendation = @"Approaching thermal limit. The system may engage passive throttling soon.";
        } else {
            level = ThermalStateLevelCritical;
            stateStr = @"Critical";
            recommendation = @"Extreme thermal limit. Reduce intensive workloads to allow chassis cooling.";
        }

        // Trend description
        NSString *trendStr;
        if (rate > 1.0) {
            trendStr = [NSString stringWithFormat:@"Heating (+%.1f°C/min)", rate];
        } else if (rate < -1.0) {
            trendStr = [NSString stringWithFormat:@"Cooling (%.1f°C/min)", rate];
        } else {
            trendStr = @"Stable";
        }

        // Natural language summary for Siri / Apple Intelligence dialog
        NSString *rateText = @"temperature is stable";
        if (rate > 1.0) {
            rateText = [NSString stringWithFormat:@"rising at %.1f degrees per minute", rate];
        } else if (rate < -1.0) {
            rateText = [NSString stringWithFormat:@"cooling at %.1f degrees per minute", fabs(rate)];
        }

        NSString *summary = [NSString stringWithFormat:@"Your CPU is at %.0f°C (%@) and %@. Thermal headroom is %.0f°C before throttling.",
                             current, stateStr, rateText, headroom];

        ThermalInsight *insight = [[ThermalInsight alloc] init];
        insight.currentTemp = current;
        insight.averageTemp = avg;
        insight.level = level;
        insight.stateDescription = stateStr;
        insight.rateOfChangePerMinute = rate;
        insight.thermalHeadroom = headroom;
        insight.trendDescription = trendStr;
        insight.naturalLanguageSummary = summary;
        insight.recommendedAction = recommendation;
        insight.snapshot = snap;

        return insight;
    }
}

@end
