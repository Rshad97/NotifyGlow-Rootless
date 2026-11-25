#import <UIKit/UIKit.h>
@interface NGOverlay : NSObject
+ (instancetype)shared;
- (BOOL)showForBundle:(NSString *)bundle options:(NSDictionary *)options;
- (BOOL)showForBundle:(NSString *)bundle options:(NSDictionary *)options inScene:(UIWindowScene *)scene;
- (void)dismiss;
@end
