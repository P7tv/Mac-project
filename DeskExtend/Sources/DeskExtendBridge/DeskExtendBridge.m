#import "include/DeskExtendBridge.h"

@interface CGVirtualDisplayDescriptor : NSObject
@property (retain) dispatch_queue_t queue;
@property (retain) NSString *name;
@property unsigned int maxPixelsWide;
@property unsigned int maxPixelsHigh;
@property CGSize sizeInMillimeters;
@property unsigned int productID;
@property unsigned int vendorID;
@property unsigned int serialNum;
@property CGPoint whitePoint;
@property CGPoint redPrimary;
@property CGPoint greenPrimary;
@property CGPoint bluePrimary;
@property (copy) void (^terminationHandler)(id, id);
@end

@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(unsigned int)width height:(unsigned int)height refreshRate:(double)refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
@property (retain) NSArray *modes;
@property unsigned int hiDPI;
@end

@interface CGVirtualDisplay : NSObject
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@property (readonly) CGDirectDisplayID displayID;
@end

@implementation DeskExtendVirtualDisplay {
    CGVirtualDisplay *_virtualDisplay;
    dispatch_queue_t _displayQueue;
}

- (nullable instancetype)initWithWidth:(uint32_t)width
                                height:(uint32_t)height
                           refreshRate:(double)refreshRate
                                 hiDPI:(BOOL)hiDPI
                                  name:(NSString *)name {
    self = [super init];
    if (!self) return nil;

    Class descClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
    Class modeClass = NSClassFromString(@"CGVirtualDisplayMode");
    Class settingsClass = NSClassFromString(@"CGVirtualDisplaySettings");
    Class dispClass = NSClassFromString(@"CGVirtualDisplay");

    if (!descClass || !modeClass || !settingsClass || !dispClass) {
        NSLog(@"[DeskExtendBridge] CGVirtualDisplay classes not found in CoreGraphics");
        return nil;
    }

    _displayQueue = dispatch_queue_create("com.deskextend.virtualdisplay", DISPATCH_QUEUE_SERIAL);

    CGVirtualDisplayDescriptor *desc = [[descClass alloc] init];
    desc.queue = _displayQueue;
    desc.name = name ?: @"DeskExtend Virtual Display";
    desc.maxPixelsWide = width;
    desc.maxPixelsHigh = height;
    desc.sizeInMillimeters = CGSizeMake(530, 300);
    desc.productID = 0xDE01;
    desc.vendorID = 0xDE02;
    // Standard sRGB chromaticity coordinates
    desc.whitePoint = CGPointMake(0.3127, 0.3290);
    desc.redPrimary = CGPointMake(0.6400, 0.3300);
    desc.greenPrimary = CGPointMake(0.3000, 0.6000);
    desc.bluePrimary = CGPointMake(0.1500, 0.0600);
    desc.terminationHandler = ^(id a, id b) {
        NSLog(@"[DeskExtendBridge] Virtual display terminated.");
    };

    _virtualDisplay = [[dispClass alloc] initWithDescriptor:desc];
    if (!_virtualDisplay) {
        NSLog(@"[DeskExtendBridge] Failed to instantiate CGVirtualDisplay");
        return nil;
    }

    CGVirtualDisplayMode *mode = [[modeClass alloc] initWithWidth:width height:height refreshRate:refreshRate];
    CGVirtualDisplaySettings *settings = [[settingsClass alloc] init];
    settings.modes = @[mode];
    settings.hiDPI = hiDPI ? 1 : 0;

    _isApplied = [_virtualDisplay applySettings:settings];
    _displayID = _virtualDisplay.displayID;

    NSLog(@"[DeskExtendBridge] Virtual Display initialized. Applied: %d, DisplayID: %u", _isApplied, _displayID);
    return self;
}

- (void)terminate {
    _virtualDisplay = nil;
    _displayID = 0;
    _isApplied = NO;
}

- (void)dealloc {
    [self terminate];
}

@end
