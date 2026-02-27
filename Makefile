include $(TOPDIR)/rules.mk

PKG_NAME:=ntrip-failover
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/ntrip-failover
  SECTION:=net
  CATEGORY:=Network
  TITLE:=NTRIP client with automatic failover
  DEPENDS:=+ntripclient +uci
endef

define Package/ntrip-failover/description
  A watchdog script for ntripclient that supports multiple mountpoints
  and automatic failover when a station goes offline.
endef

define Build/Compile
endef

define Package/ntrip-failover/install
  $(INSTALL_DIR) $(1)/usr/bin
  $(INSTALL_BIN) ./files/usr/bin/ntrip-stream.sh $(1)/usr/bin/
  $(INSTALL_DIR) $(1)/etc/init.d
  $(INSTALL_BIN) ./files/etc/init.d/ntrip-stream $(1)/etc/init.d/
  $(INSTALL_DIR) $(1)/etc/config
  $(INSTALL_CONF) ./files/etc/config/ntrip $(1)/etc/config/ntrip

endef

$(eval $(call BuildPackage,ntrip-failover))