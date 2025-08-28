# SPDX-License-Identifier: MIT
#
# Copyright (C) 2023-2025 fantastic-packages

include $(TOPDIR)/rules.mk

PKG_NAME:=fantastic-packages-feeds
PKG_VERSION:=20250513
PKG_RELEASE:=1

PKG_MAINTAINER:=Anya Lin <hukk1996@gmail.com>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=License

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=base
  CATEGORY:=Base system
  DEPENDS:=+fantastic-keyring +opkg
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
	REVISION=$$($$TOPDIR/scripts/getver.sh)
	REVISION=$$(echo "$$REVISION" | cut -f1 -d'-' | sed 's|[a-z]||gi')
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
	BRANCH="24.10"
	[ "$$REVISION" -lt 28158 ] && BRANCH="23.05"
	[ "$$REVISION" -lt 23069 ] && BRANCH="22.03"
	[ "$$REVISION" -lt 19302 ] && BRANCH="21.02"
	# https://archive.openwrt.org/releases/**/version.buildinfo
	# r28158-d276b4c91a    24.10.0-rc1
	# r23069-e2701e0f33    23.05.0-rc1
	# r19302-df622768da    22.03.0-rc1
	# r16122-c2139eef27    21.02.0-rc2
else
	BRANCH=$$(echo $$VERSION_NUMBER | awk -F '.' -v OFS='.' '{print $$1,$$2}')
fi
if ! grep -q fantastic_packages_ "$$IPKG_INSTROOT/etc/opkg/customfeeds.conf"; then
	BASE_URL="https://fantastic-packages.github.io/releases"
	BASE_URL="$$BASE_URL/$$BRANCH/packages/$$ARCH_PACKAGES"
	cat <<- EOF >> "$$IPKG_INSTROOT/etc/opkg/customfeeds.conf"
	src/gz fantastic_packages_packages $$BASE_URL/packages
	src/gz fantastic_packages_luci     $$BASE_URL/luci
	src/gz fantastic_packages_special  $$BASE_URL/special
	EOF
fi
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
sed -i "/fantastic_packages_/d" "$$IPKG_INSTROOT/etc/opkg/customfeeds.conf"
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
