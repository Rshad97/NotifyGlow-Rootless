#import <UIKit/UIKit.h>
@interface NGOverlay : NSObject
+ (instancetype)shared;
- (BOOL)showForBundle:(NSString *)bundle options:(NSDictionary *)options;
- (void)dismiss;
@end
