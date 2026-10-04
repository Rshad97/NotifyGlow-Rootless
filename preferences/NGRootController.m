#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <notify.h>
#import "../NGConfig.h"
@interface NGRootController : PSListController
@end
@implementation NGRootController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers=[self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    return NGSettings()[[specifier propertyForKey:@"key"]] ?: [specifier propertyForKey:@"default"];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    CFPreferencesSetAppValue((__bridge CFStringRef)[specifier propertyForKey:@"key"],(__bridge CFPropertyListRef)value,(__bridge CFStringRef)NGDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)NGDomain);
    notify_post("com.rshad.notifyglow/settings");
}
- (void)preview { notify_post("com.rshad.notifyglow/preview"); }
- (void)editApps {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Per-app settings" message:@"Enter the app bundle ID, e.g. com.toyopagroup.picaboo for Snapchat." preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder=@"Bundle ID"; t.autocapitalizationType=UITextAutocapitalizationTypeNone; t.autocorrectionType=UITextAutocorrectionTypeNo; }];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Configure" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSString *bundle=[a.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (bundle.length) [self configure:bundle];
    }]]; [self presentViewController:a animated:YES completion:nil];
}
- (void)saveRule:(NSDictionary *)rule bundle:(NSString *)bundle {
    id existing=NGSettings()[@"Apps"];
    NSMutableDictionary *apps=[existing isKindOfClass:NSDictionary.class] ? [existing mutableCopy] : [NSMutableDictionary new];
    if (rule) apps[bundle]=rule; else [apps removeObjectForKey:bundle];
    CFPreferencesSetAppValue(CFSTR("Apps"),(__bridge CFPropertyListRef)apps,(__bridge CFStringRef)NGDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)NGDomain); notify_post("com.rshad.notifyglow/settings");
}
- (void)configure:(NSString *)bundle {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:bundle message:@"Optional hex color, then choose an animation. Blank color uses the app icon." preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder=@"#33CC99 (optional)"; t.autocapitalizationType=UITextAutocapitalizationTypeAllCharacters; }];
    NSArray *styles=@[@"edge",@"notch",@"wave",@"random"];
    NSArray *labels=@[@"Edge lighting",@"Notch pulse",@"Soft wave",@"Random"];
    for (NSUInteger i=0;i<styles.count;i++) {
        NSString *style=styles[i];
        [a addAction:[UIAlertAction actionWithTitle:labels[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            NSString *hex=a.textFields.firstObject.text ?: @"";
            if (hex.length && !NGHexColor(hex)) { [self invalidColor:bundle]; return; }
            [self saveRule:@{@"Enabled":@YES,@"Style":style,@"Color":hex} bundle:bundle];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Disable this app" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){ [self saveRule:@{@"Enabled":@NO} bundle:bundle]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Use global settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){ [self saveRule:nil bundle:bundle]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)invalidColor:(NSString *)bundle {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Invalid color" message:@"Use exactly six hexadecimal digits, for example #33CC99." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Try again" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){ [self configure:bundle]; }]];
    [self presentViewController:a animated:YES completion:nil];
}
@end
