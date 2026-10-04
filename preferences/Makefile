include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = NotifyGlowPrefs
NotifyGlowPrefs_FILES = NGRootController.m ../NGConfig.m
NotifyGlowPrefs_FRAMEWORKS = UIKit Foundation
NotifyGlowPrefs_PRIVATE_FRAMEWORKS = Preferences
NotifyGlowPrefs_INSTALL_PATH = /Library/PreferenceBundles
NotifyGlowPrefs_CFLAGS = -fobjc-arc -fblocks
NotifyGlowPrefs_LDFLAGS += -Wl,-undefined,dynamic_lookup
include $(THEOS_MAKE_PATH)/bundle.mk
