ARCHS = armv7 arm64
TARGET = iphone:latest:8.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TKDemo
TKDemo_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 WeChat"
