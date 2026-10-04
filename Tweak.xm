#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <notify.h>
#import <dlfcn.h>
#import "NGConfig.h"
#import "NGOverlay.h"
#import "NGLogic.h"
#import "NGDiagnostics.h"

@interface NCNotificationDispatcher : NSObject
- (void)postNotificationWithRequest:(id)request;
@end
@interface SBNotificationBannerDestination : NSObject
- (void)postNotificationRequest:(id)request forCoalescedNotification:(id)coalesced;
- (void)postNotificationRequest:(id)request;
@end

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
static unsigned hookMask;
static int displayToken=-1;
static BOOL NGScreenOn(BOOL locked) {
    id backlight=NGSingleton(@"SBBacklightController");
    if ([backlight respondsToSelector:NSSelectorFromString(@"screenIsOn")]) return NGFlag(backlight,@"screenIsOn",NO);
    uint64_t state=0;
    if (displayToken>=0 && notify_get_state(displayToken,&state)==NOTIFY_STATUS_OK) return state!=0;
    return !locked;
}
static void NGReply(unsigned result) {
    int token;
    if (notify_register_check(NG_REPLY,&token)==NOTIFY_STATUS_OK) {
        notify_set_state(token,NGDiagnosticState(result,hookMask));
        notify_post(NG_REPLY); notify_cancel(token);
    }
}
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
            if ([date isKindOfClass:NSDate.class] && !NGIsRecent(-date.timeIntervalSinceNow)) return;
            NSDictionary *o=NGOptions(settings,bundle);
            if (!NGBool(settings,@"Enabled",YES) || !NGBool(o,@"Enabled",YES)) return;
            id lock=NGSingleton(@"SBLockScreenManager");
            BOOL locked=NGFlag(lock,@"isUILocked",YES);
            // Unlocked notifications only animate when iOS posts a banner.
            if (!locked && !banner) return;
            if (locked && !banner) {
                if (!NGFocusAllows()) { NSLog(@"[NotifyGlow] lock skipped: Focus active or unavailable"); return; }
                id options=NGGet(request,@"options");
                if (!NGFlag(options,@"canTurnOnDisplay",NO)) return;
            }
            id backlight=NGSingleton(@"SBBacklightController");
            BOOL screenOn=NGScreenOn(locked);
            if (!(locked ? NGBool(o,@"OnLock",YES) : NGBool(o,@"OnOpen",YES))) return;
            if (NSProcessInfo.processInfo.lowPowerModeEnabled && NGBool(o,@"PauseLowPower",YES)) return;
            CFTimeInterval now=CACurrentMediaTime();
            NSString *key=[NSString stringWithFormat:@"%@:%@",bundle,[identifier isKindOfClass:NSString.class] ? identifier : [NSString stringWithFormat:@"%p",request]];
            if (seen[key] || now-lastAnimation<.75) return;
            if (!screenOn && locked && NGBool(o,@"WakeScreen",NO)) {
                SEL wake=NSSelectorFromString(@"turnOnScreenFullyWithBacklightSource:");
                if ([backlight respondsToSelector:wake]) ((void (*)(id,SEL,long long))objc_msgSend)(backlight,wake,0);
            }
            // Wait briefly for the normal notification wake, without retaining a UI overlay while asleep.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,250*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                @try {
                NSDictionary *current=NGOptions(settings,bundle);
                BOOL currentLock=NGFlag(NGSingleton(@"SBLockScreenManager"),@"isUILocked",YES);
                BOOL on=NGScreenOn(currentLock);
                if (currentLock && !banner && !NGFocusAllows()) return;
                if (!NGShouldRender(NGBool(settings,@"Enabled",YES) && NGBool(current,@"Enabled",YES),currentLock,NGBool(current,@"OnLock",YES),NGBool(current,@"OnOpen",YES),on,NSProcessInfo.processInfo.lowPowerModeEnabled,NGBool(current,@"PauseLowPower",YES))) return;
                CFTimeInterval actual=CACurrentMediaTime();
                if (seen[key] || actual-lastAnimation<.75) return;
                for (NSString *old in [seen.allKeys copy]) if (actual-seen[old].doubleValue>60) [seen removeObjectForKey:old];
                if (seen.count>256) [seen removeAllObjects];
                if ([[NGOverlay shared] showForBundle:bundle options:current]) {
                    seen[key]=@(actual); lastAnimation=actual;
                }
                } @catch (NSException *exception) { NSLog(@"[NotifyGlow] delayed render exception: %@",exception.name); }
            });
        } @catch (NSException *exception) {
            NSLog(@"[NotifyGlow] skipped incompatible notification: %@",exception.name);
        }
    });
}

%group Dispatcher
%hook NCNotificationDispatcher
- (void)postNotificationWithRequest:(id)request {
    %orig;
    NGHandle(request,NO);
}
%end
%end
%group Banner
%hook SBNotificationBannerDestination
- (void)postNotificationRequest:(id)request forCoalescedNotification:(id)coalesced {
    %orig;
    NGHandle(request,YES);
}
%end
%end
%group ModernBanner
%hook SBNotificationBannerDestination
- (void)postNotificationRequest:(id)request {
    %orig;
    // iOS has already routed this request to its alert destination.
    NGHandle(request,YES);
}
%end
%end

static void NGInstallHooks(unsigned attempt) {
    Class dispatcher=NSClassFromString(@"NCNotificationDispatcher");
    Class banner=NSClassFromString(@"SBNotificationBannerDestination");
    if (!(hookMask&1) && [dispatcher instancesRespondToSelector:@selector(postNotificationWithRequest:)]) {
        %init(Dispatcher);
        hookMask|=1;
    }
    if (!(hookMask&2) && [banner instancesRespondToSelector:@selector(postNotificationRequest:forCoalescedNotification:)]) {
        %init(Banner);
        hookMask|=2;
    }
    if (!(hookMask&4) && [banner instancesRespondToSelector:@selector(postNotificationRequest:)]) {
        %init(ModernBanner);
        hookMask|=4;
    }
    NSLog(@"[NotifyGlow] hooks mask=%u attempt=%u",hookMask,attempt);
    // Notification frameworks may not have loaded at dylib constructor time.
    if (attempt<30 && (!(hookMask&1) || !(hookMask&6))) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{ NGInstallHooks(attempt+1); });
    }
}

%ctor {
    @autoreleasepool {
        dlopen("/System/Library/PrivateFrameworks/DoNotDisturb.framework/DoNotDisturb",RTLD_LAZY);
        settings=NGSettings(); seen=[NSMutableDictionary new];
        dispatch_async(dispatch_get_main_queue(),^{ NGInstallHooks(0); });
        int prefsToken,previewToken,pingToken;
        notify_register_dispatch("com.rshad.notifyglow/settings",&prefsToken,dispatch_get_main_queue(),^(int token){
            settings=NGSettings(); [[NGOverlay shared] dismiss];
        });
        notify_register_dispatch(NG_PREVIEW,&previewToken,dispatch_get_main_queue(),^(int token){
            @try {
                settings=NGSettings();
                // Explicit Preview bypasses notification/lock/Focus/low-power gates.
                BOOL created=[[NGOverlay shared] showForBundle:@"com.apple.MobileSMS" options:settings];
                NGReply(created ? NGWindowCreated : NGNoScene);
            } @catch (NSException *exception) {
                NSLog(@"[NotifyGlow] preview exception: %@",exception.name); NGReply(NGException);
            }
        });
        notify_register_dispatch(NG_PING,&pingToken,dispatch_get_main_queue(),^(int token){
            NGInstallHooks(30); NGReply(NGReady);
        });
        notify_register_dispatch("com.apple.iokit.hid.displayStatus",&displayToken,dispatch_get_main_queue(),^(int token){
            uint64_t on=0; if (notify_get_state(token,&on)==NOTIFY_STATUS_OK && !on) [[NGOverlay shared] dismiss];
        });
        NSLog(@"[NotifyGlow] loaded 1.0.2; runtime validation required");
    }
}
