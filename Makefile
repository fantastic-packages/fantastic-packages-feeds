# SPDX-License-Identifier: MIT
#
# Copyright (C) 2023-2025 fantastic-packages

include $(TOPDIR)/rules.mk

PKG_NAME:=fantastic-packages-feeds
PKG_VERSION:=20251222
PKG_RELEASE:=1

PKG_MAINTAINER:=Anya Lin <hukk1996@gmail.com>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=License

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=base
  CATEGORY:=Base system
  DEPENDS:=+fantastic-keyring +apk
  TITLE:=Installer for fantastic-packages feeds
  PKGARCH:=all
endef

Build/Compile=

define Package/$(PKG_NAME)/install
	:
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
export REVISION VERSION_NUMBER ARCH_PACKAGES
if [ -n "$$IPKG_INSTROOT" ]; then
	# building
	eval "$$(grep CONFIG_VERSION_NUMBER "$$TOPDIR/.config")"
	eval "$$(grep CONFIG_VERSION_REPO "$$TOPDIR/.config")"
	eval "$$(grep CONFIG_TARGET_ARCH_PACKAGES "$$TOPDIR/.config")"
	#REVISION=$$($$TOPDIR/scripts/getver.sh | cut -f1 -d'-' | sed 's|[a-z]||gi')
	eval "$$(grep BUILD_ID "$$IPKG_INSTROOT/usr/lib/os-release")"
	REVISION=$$(echo "$$BUILD_ID" | cut -f1 -d'-' | sed 's|[a-z]||gi')
	if [ -n "$$CONFIG_VERSION_REPO" ]; then
		VERSION_NUMBER=$${CONFIG_VERSION_REPO##*/}
	else
		VERSION_NUMBER=$${CONFIG_VERSION_NUMBER:-SNAPSHOT}
	fi
	ARCH_PACKAGES=$$CONFIG_TARGET_ARCH_PACKAGES
else
	# system
	eval "$$(grep OPENWRT_ARCH /etc/os-release)"
	ARCH_PACKAGES=$$OPENWRT_ARCH
	REVISION=$$(ubus call system board | jsonfilter -qe '@.release.revision' | cut -f1 -d'-' | sed 's|[a-z]||gi')
	VERSION_NUMBER=$$(ubus call system board | jsonfilter -qe '@.release.version')
fi
if [ "$$VERSION_NUMBER" = "SNAPSHOT" ]; then
	if   [ "$$REVISION" -ge 32353 -o "$$REVISION" -eq 0 ]; then BRANCH="25.12"
	else 2>&1 echo "Current version of OpenWrt is no longer supported, please upgrade!"; exit 1;
	fi
	# https://archive.openwrt.org/releases/**/version.buildinfo
	# r32353-9e9b05130c    25.12.0-rc1
	# r28158-d276b4c91a    24.10.0-rc1
else
	BRANCH=$$(echo $$VERSION_NUMBER | awk -F '.' -v OFS='.' '{print $$1,$$2}')
fi
BASE_URL="https://fantastic-packages.github.io/releases"
if ! grep -q "$$BASE_URL" "$$IPKG_INSTROOT/etc/apk/repositories.d/customfeeds.list"; then
	BASE_URL="$$BASE_URL/$$BRANCH/packages/$$ARCH_PACKAGES"
	cat <<- EOF >> "$$IPKG_INSTROOT/etc/apk/repositories.d/customfeeds.list"
	$$BASE_URL/packages/packages.adb
	$$BASE_URL/luci/packages.adb
	$$BASE_URL/special/packages.adb
	EOF
fi
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
BASE_URL="https://fantastic-packages.github.io/releases"
sed -i "/$$BASE_URL/d" "$$IPKG_INSTROOT/etc/apk/repositories.d/customfeeds.list"
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
