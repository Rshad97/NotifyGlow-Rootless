#import <UIKit/UIKit.h>
extern NSString *const NGDomain;
NSDictionary *NGSettings(void);
NSDictionary *NGOptions(NSDictionary *settings, NSString *bundle);
BOOL NGBool(NSDictionary *settings, NSString *key, BOOL fallback);
double NGNumber(NSDictionary *settings, NSString *key, double fallback, double lo, double hi);
UIColor *NGHexColor(NSString *hex);
