#import "NGOverlay.h"
#import "NGConfig.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

@interface NGWindow : UIWindow
@end
@implementation NGWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { return nil; }
- (BOOL)_canBecomeKeyWindow { return NO; }
@end

@interface NGOverlay ()
@property(nonatomic,strong) NGWindow *window;
@property(nonatomic,strong) NSCache *colors;
@property(nonatomic) NSUInteger generation;
@end

@implementation NGOverlay
+ (instancetype)shared { static NGOverlay *o; static dispatch_once_t once; dispatch_once(&once, ^{ o = [self new]; o.colors = [NSCache new]; o.colors.countLimit = 100; }); return o; }
- (instancetype)init {
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismiss) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
    } return self;
}
- (UIImage *)icon:(NSString *)bundle {
    SEL sel = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    if (![UIImage respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL, id, int, CGFloat))objc_msgSend)(UIImage.class, sel, bundle, 2, UIScreen.mainScreen.scale);
}
- (UIColor *)color:(NSString *)bundle {
    UIColor *cached = [self.colors objectForKey:bundle]; if (cached) return cached;
    UIImage *image = [self icon:bundle];
    UIColor *fallback = [UIColor colorWithRed:.2 green:.65 blue:1 alpha:1];
    if (!image.CGImage) return fallback;
    unsigned char pixels[16*16*4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(pixels, 16, 16, 8, 16*4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space); if (!ctx) return fallback;
    CGContextDrawImage(ctx, CGRectMake(0,0,16,16), image.CGImage); CGContextRelease(ctx);
    double red=0, green=0, blue=0, total=0;
    for (int i=0;i<256;i++) {
        double r=pixels[i*4]/255., g=pixels[i*4+1]/255., b=pixels[i*4+2]/255.;
        double high=fmax(r,fmax(g,b)), low=fmin(r,fmin(g,b));
        if (pixels[i*4+3]<200 || high<.15 || high-low<.12) continue;
        double w=high-low; red+=r*w; green+=g*w; blue+=b*w; total+=w;
    }
    UIColor *c=total>0 ? [UIColor colorWithRed:red/total green:green/total blue:blue/total alpha:1] : fallback;
    [self.colors setObject:c forKey:bundle]; return c;
}
- (void)dismiss {
    self.generation++;
    [self.window.layer removeAllAnimations];
    self.window.hidden=YES; self.window=nil;
}
- (void)showForBundle:(NSString *)bundle options:(NSDictionary *)o {
    NSAssert(NSThread.isMainThread, @"UI must be on main thread");
    [self dismiss];
    UIColor *color=NGHexColor(o[@"Color"]) ?: [self color:bundle];
    double duration=NGNumber(o,@"Duration",2,.5,6), width=NGNumber(o,@"Width",4,1,12);
    double intensity=NGNumber(o,@"Intensity",.85,.1,1);
    NSString *style=[o[@"Style"] isKindOfClass:NSString.class] ? o[@"Style"] : @"edge";
    if ([style isEqual:@"random"]) style=@[@"edge",@"notch",@"wave"][arc4random_uniform(3)];
    if (![@[@"edge",@"notch",@"wave"] containsObject:style]) style=@"edge";
    self.window=[[NGWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.windowLevel=UIWindowLevelAlert+1000;
    self.window.backgroundColor=UIColor.clearColor;
    self.window.userInteractionEnabled=NO;
    self.window.accessibilityElementsHidden=YES;
    self.window.rootViewController=[UIViewController new];
    UIView *view=self.window.rootViewController.view;
    view.backgroundColor=UIColor.clearColor;
    self.window.hidden=NO; // Never makeKeyAndVisible: preserve underlying app input.
    CGRect bounds=view.bounds;
    BOOL reduced=UIAccessibilityIsReduceMotionEnabled();
    CAShapeLayer *shape=[CAShapeLayer layer];
    shape.frame=bounds; shape.fillColor=UIColor.clearColor.CGColor;
    shape.strokeColor=color.CGColor; shape.lineWidth=width; shape.lineCap=kCALineCapRound;
    shape.shadowColor=color.CGColor; shape.shadowRadius=12; shape.shadowOpacity=intensity; shape.shadowOffset=CGSizeZero;
    if ([style isEqual:@"notch"]) {
        CGFloat w=MIN(210,CGRectGetWidth(bounds)*.56);
        shape.path=[UIBezierPath bezierPathWithRoundedRect:CGRectMake((CGRectGetWidth(bounds)-w)/2,5,w,40) cornerRadius:21].CGPath;
    } else {
        shape.path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(bounds,width+3,width+3) cornerRadius:38].CGPath;
    }
    shape.opacity=0;
    [view.layer addSublayer:shape];
    CAKeyframeAnimation *fade=[CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    fade.values=@[@0,@(intensity),@(intensity),@0]; fade.keyTimes=@[@0,@.15,@.65,@1]; fade.duration=duration;
    [shape addAnimation:fade forKey:@"fade"];
    if (!reduced && [style isEqual:@"edge"]) {
        CABasicAnimation *draw=[CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        draw.fromValue=@0; draw.toValue=@1; draw.duration=duration*.65;
        [shape addAnimation:draw forKey:@"trace"];
    } else if (!reduced && [style isEqual:@"notch"]) {
        CAKeyframeAnimation *pulse=[CAKeyframeAnimation animationWithKeyPath:@"lineWidth"];
        pulse.values=@[@(width),@(width*2.5),@(width),@(width*2),@(width)]; pulse.duration=duration;
        [shape addAnimation:pulse forKey:@"pulse"];
    } else if (!reduced && [style isEqual:@"wave"]) {
        CABasicAnimation *wave=[CABasicAnimation animationWithKeyPath:@"path"];
        wave.fromValue=(__bridge id)shape.path;
        wave.toValue=(__bridge id)[UIBezierPath bezierPathWithRoundedRect:CGRectInset(bounds,35,70) cornerRadius:60].CGPath;
        wave.duration=duration;
        [shape addAnimation:wave forKey:@"wave"];
    }
    if (NGBool(o,@"ShowIcon",NO)) {
        UIImageView *icon=[[UIImageView alloc] initWithImage:[self icon:bundle]];
        icon.frame=CGRectMake((CGRectGetWidth(bounds)-40)/2,65,40,40);
        icon.layer.cornerRadius=9; icon.clipsToBounds=YES;
        [view addSubview:icon]; [icon.layer addAnimation:fade forKey:@"fade"];
    }
    NSUInteger ticket=self.generation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(duration*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if (ticket==self.generation) [self dismiss];
    });
    NSLog(@"[NotifyGlow] render style=%@ bundle=%@",style,bundle);
}
@end
