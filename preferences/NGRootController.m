#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <notify.h>
#import "../NGConfig.h"
#import "../NGDiagnostics.h"
@interface NGRootController : PSListController
@property(nonatomic) BOOL checkingRuntime;
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
- (void)runtimeMessage:(NSString *)message {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"NotifyGlow runtime" message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)checkRuntime:(BOOL)preview {
    if (self.checkingRuntime) return;
    self.checkingRuntime=YES;
    __block int replyToken=-1;
    __block BOOL answered=NO;
    uint32_t status=notify_register_dispatch(NG_REPLY,&replyToken,dispatch_get_main_queue(),^(int token){
        if (answered) return;
        uint64_t state=0;
        if (notify_get_state(token,&state)!=NOTIFY_STATUS_OK) return;
        answered=YES; notify_cancel(token); self.checkingRuntime=NO;
        unsigned result=state&255, hooks=(state>>8)&255, version=(unsigned)(state>>16);
        if (preview && result==NGWindowCreated) return;
        NSString *detail=result==NGNoScene ? @"SpringBoard received Preview but could not create the display window." :
            result==NGException ? @"SpringBoard received Preview but the renderer raised an exception. Check the [NotifyGlow] log." :
            @"SpringBoard injection is responding. This confirms loading, not that the animation is visibly displayed.";
        [self runtimeMessage:[NSString stringWithFormat:@"Runtime: %u.%u.%u\nDispatcher: %@\nBanner: %@\n\n%@",version/100,(version/10)%10,version%10,(hooks&1)?@"hooked":@"unavailable",(hooks&6)?@"hooked":@"unavailable",detail]];
    });
    if (status!=NOTIFY_STATUS_OK) {
        self.checkingRuntime=NO; [self runtimeMessage:@"Could not register the runtime response listener."]; return;
    }
    notify_post(preview ? NG_PREVIEW : NG_PING);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if (answered) return;
        answered=YES; notify_cancel(replyToken); self.checkingRuntime=NO;
        [self runtimeMessage:@"No response from SpringBoard. Restart SpringBoard after updating. If this persists, check that tweak injection is enabled for SpringBoard in your jailbreak; Sileo alone does not load tweaks."];
    });
}
- (void)preview { [self checkRuntime:YES]; }
- (void)diagnostics { [self checkRuntime:NO]; }
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
