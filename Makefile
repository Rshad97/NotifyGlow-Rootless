ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:15.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = NotifyGlow
NotifyGlow_FILES = Tweak.xm NGOverlay.m NGConfig.m
NotifyGlow_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics
NotifyGlow_CFLAGS = -fobjc-arc -fblocks -Wall
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
