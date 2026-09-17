#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface DeskExtendVirtualDisplay : NSObject

@property (nonatomic, readonly) CGDirectDisplayID displayID;
@property (nonatomic, readonly) BOOL isApplied;

- (nullable instancetype)initWithWidth:(uint32_t)width
                                height:(uint32_t)height
                           refreshRate:(double)refreshRate
                                 hiDPI:(BOOL)hiDPI
                                  name:(NSString *)name;

- (void)terminate;

@end

NS_ASSUME_NONNULL_END
