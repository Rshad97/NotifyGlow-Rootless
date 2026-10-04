#import <UIKit/UIKit.h>
@interface NGOverlay : NSObject
+ (instancetype)shared;
- (void)showForBundle:(NSString *)bundle options:(NSDictionary *)options;
- (void)dismiss;
@end
