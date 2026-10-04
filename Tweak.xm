#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <notify.h>
#import <dlfcn.h>
#import "NGConfig.h"
#import "NGOverlay.h"
#import "NGLogic.h"

// All private selectors are capability-checked. Missing lock-screen capabilities
// disable that path instead of guessing system state or bypassing Focus.
static id NGGet(id object, NSString *name) {
    SEL s=NSSelectorFromString(name);
    return [object respondsToSelector:s] ? ((id (*)(id,SEL))objc_msgSend)(object,s) : nil;
}
static BOOL NGFlag(id object, NSString *name, BOOL fallback) {
    SEL s=NSSelectorFromString(name);
    return [object respondsToSelector:s] ? ((BOOL (*)(id,SEL))objc_msgSend)(object,s) : fallback;
}
static id NGSingleton(NSString *name) { return NGGet(NSClassFromString(name),@"sharedInstance"); }
static NSDictionary *settings;
static NSMutableDictionary<NSString *,NSNumber *> *seen;
static CFTimeInterval lastAnimation;
static id focusService;
static BOOL NGFocusAllows(void) {
    if (!focusService) {
        Class cls=NSClassFromString(@"DNDStateService");
        SEL factory=NSSelectorFromString(@"serviceForClientIdentifier:");
        if ([cls respondsToSelector:factory]) focusService=((id (*)(id,SEL,id))objc_msgSend)(cls,factory,@"com.rshad.notifyglow");
    }
    SEL query=NSSelectorFromString(@"queryCurrentStateWithError:");
    if (![focusService respondsToSelector:query]) return NO;
    NSError *error=nil;
    id state=((id (*)(id,SEL,NSError **))objc_msgSend)(focusService,query,&error);
    return state && !error && !NGFlag(state,@"isActive",YES);
}
static void NGHandle(id request, BOOL banner) {
    dispatch_async(dispatch_get_main_queue(),^{
        @try {
            NSString *bundle=NGGet(request,@"sectionIdentifier");
            NSString *identifier=NGGet(request,@"notificationIdentifier");
            NSDate *date=NGGet(request,@"timestamp");
            if (![bundle isKindOfClass:NSString.class] || !bundle.length) return;
            if (![date isKindOfClass:NSDate.class] || !NGIsRecent(-date.timeIntervalSinceNow)) return;
            NSDictionary *o=NGOptions(settings,bundle);
            if (!NGBool(settings,@"Enabled",YES) || !NGBool(o,@"Enabled",YES)) return;
            id lock=NGSingleton(@"SBLockScreenManager");
            BOOL locked=NGFlag(lock,@"isUILocked",YES);
            // Unlocked notifications only animate when iOS posts a banner.
            if (!locked && !banner) return;
            if (locked) {
                if (!NGFocusAllows()) { NSLog(@"[NotifyGlow] lock skipped: Focus active or unavailable"); return; }
                id options=NGGet(request,@"options");
                if (!NGFlag(options,@"canTurnOnDisplay",NO)) return;
            }
            id backlight=NGSingleton(@"SBBacklightController");
            BOOL screenOn=NGFlag(backlight,@"screenIsOn",!locked);
            if (!(locked ? NGBool(o,@"OnLock",YES) : NGBool(o,@"OnOpen",YES))) return;
            if (NSProcessInfo.processInfo.lowPowerModeEnabled && NGBool(o,@"PauseLowPower",YES)) return;
            CFTimeInterval now=CACurrentMediaTime();
            NSString *key=[NSString stringWithFormat:@"%@:%@",bundle,[identifier isKindOfClass:NSString.class] ? identifier : date.description];
            if (seen[key] || now-lastAnimation<.75) return;
            if (!screenOn && locked && NGBool(o,@"WakeScreen",NO)) {
                SEL wake=NSSelectorFromString(@"turnOnScreenFullyWithBacklightSource:");
                if ([backlight respondsToSelector:wake]) ((void (*)(id,SEL,long long))objc_msgSend)(backlight,wake,0);
            }
            // Wait briefly for the normal notification wake, without retaining a UI overlay while asleep.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,250*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                NSDictionary *current=NGOptions(settings,bundle);
                BOOL currentLock=NGFlag(NGSingleton(@"SBLockScreenManager"),@"isUILocked",YES);
                BOOL on=NGFlag(backlight,@"screenIsOn",!currentLock);
                if (currentLock && !NGFocusAllows()) return;
                if (!NGShouldRender(NGBool(settings,@"Enabled",YES) && NGBool(current,@"Enabled",YES),currentLock,NGBool(current,@"OnLock",YES),NGBool(current,@"OnOpen",YES),on,NSProcessInfo.processInfo.lowPowerModeEnabled,NGBool(current,@"PauseLowPower",YES))) return;
                CFTimeInterval actual=CACurrentMediaTime();
                if (seen[key] || actual-lastAnimation<.75) return;
                for (NSString *old in [seen.allKeys copy]) if (actual-seen[old].doubleValue>60) [seen removeObjectForKey:old];
                if (seen.count>256) [seen removeAllObjects];
                seen[key]=@(actual); lastAnimation=actual;
                [[NGOverlay shared] showForBundle:bundle options:current];
            });
        } @catch (NSException *exception) {
            NSLog(@"[NotifyGlow] skipped incompatible notification: %@",exception.name);
        }
    });
}

%group Dispatcher
%hook NCNotificationDispatcher
- (void)postNotificationWithRequest:(id)request { %orig; NGHandle(request,NO); }
%end
%end
%group Banner
%hook SBNotificationBannerDestination
- (void)postNotificationRequest:(id)request forCoalescedNotification:(id)coalesced {
    %orig; NGHandle(request,YES);
}
%end
%end

%ctor {
    @autoreleasepool {
        dlopen("/System/Library/PrivateFrameworks/DoNotDisturb.framework/DoNotDisturb",RTLD_LAZY);
        settings=NGSettings(); seen=[NSMutableDictionary new];
        Class dispatcher=NSClassFromString(@"NCNotificationDispatcher");
        Class banner=NSClassFromString(@"SBNotificationBannerDestination");
        if ([dispatcher instancesRespondToSelector:@selector(postNotificationWithRequest:)]) { %init(Dispatcher); }
        else NSLog(@"[NotifyGlow] notification dispatcher unavailable");
        if ([banner instancesRespondToSelector:@selector(postNotificationRequest:forCoalescedNotification:)]) { %init(Banner); }
        else NSLog(@"[NotifyGlow] banner hook unavailable");
        int prefsToken,previewToken,displayToken;
        notify_register_dispatch("com.rshad.notifyglow/settings",&prefsToken,dispatch_get_main_queue(),^(int token){
            settings=NGSettings(); [[NGOverlay shared] dismiss];
        });
        notify_register_dispatch("com.rshad.notifyglow/preview",&previewToken,dispatch_get_main_queue(),^(int token){
            if (!NGFlag(NGSingleton(@"SBLockScreenManager"),@"isUILocked",YES))
                [[NGOverlay shared] showForBundle:@"com.apple.MobileSMS" options:settings];
        });
        notify_register_dispatch("com.apple.iokit.hid.displayStatus",&displayToken,dispatch_get_main_queue(),^(int token){
            uint64_t on=0; if (notify_get_state(token,&on)==NOTIFY_STATUS_OK && !on) [[NGOverlay shared] dismiss];
        });
        NSLog(@"[NotifyGlow] loaded 1.0.0; runtime validation required");
    }
}
