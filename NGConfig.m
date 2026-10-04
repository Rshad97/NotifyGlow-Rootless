#import "NGConfig.h"
#import "NGLogic.h"
NSString *const NGDomain = @"com.rshad.notifyglow";
NSDictionary *NGSettings(void) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)NGDomain);
    NSArray *keys = CFBridgingRelease(CFPreferencesCopyKeyList((__bridge CFStringRef)NGDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
    NSDictionary *d = keys ? CFBridgingRelease(CFPreferencesCopyMultiple((__bridge CFArrayRef)keys, (__bridge CFStringRef)NGDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)) : nil;
    return [d isKindOfClass:NSDictionary.class] ? d : @{};
}
NSDictionary *NGOptions(NSDictionary *s, NSString *bundle) {
    NSMutableDictionary *result = [s mutableCopy];
    NSDictionary *rules = s[@"Apps"];
    id rule = [rules isKindOfClass:NSDictionary.class] ? rules[bundle] : nil;
    if ([rule isKindOfClass:NSDictionary.class]) [result addEntriesFromDictionary:rule];
    return result;
}
BOOL NGBool(NSDictionary *s, NSString *key, BOOL fallback) {
    id v = s[key]; return [v respondsToSelector:@selector(boolValue)] ? [v boolValue] : fallback;
}
double NGNumber(NSDictionary *s, NSString *key, double fallback, double lo, double hi) {
    id v = s[key]; return NGClamp([v respondsToSelector:@selector(doubleValue)] ? [v doubleValue] : fallback, fallback, lo, hi);
}
UIColor *NGHexColor(NSString *hex) {
    if (![hex isKindOfClass:NSString.class]) return nil;
    NSString *s = [hex stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([s hasPrefix:@"#"]) s = [s substringFromIndex:1];
    if (s.length != 6 || [s rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet]].location != NSNotFound) return nil;
    unsigned value = 0; [[NSScanner scannerWithString:s] scanHexInt:&value];
    return [UIColor colorWithRed:((value >> 16) & 255)/255.0 green:((value >> 8) & 255)/255.0 blue:(value & 255)/255.0 alpha:1];
}
