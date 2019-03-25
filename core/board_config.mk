#
# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# ###############################################################
# This file includes BoardConfig.mk for the device being built,
# and sanity-checks the variable defined therein.
# ###############################################################

# Boards may be defined under $(SRC_TARGET_DIR)/board/$(TARGET_DEVICE)
# or under vendor/*/$(TARGET_DEVICE).  Search in both places, but
# make sure only one exists.
# Real boards should always be associated with an OEM vendor.
ifdef TARGET_DEVICE_DIR
  ifneq ($(origin TARGET_DEVICE_DIR),command line)
    $(error TARGET_DEVICE_DIR may not be set manually)
  endif
  board_config_mk := $(TARGET_DEVICE_DIR)/BoardConfig.mk
else
  board_config_mk := \
    $(strip $(sort $(wildcard \
      $(SRC_TARGET_DIR)/board/$(TARGET_DEVICE)/BoardConfig.mk \
      $(shell test -d device && find -L device -maxdepth 4 -path '*/$(TARGET_DEVICE)/BoardConfig.mk') \
      $(shell test -d vendor && find -L vendor -maxdepth 4 -path '*/$(TARGET_DEVICE)/BoardConfig.mk') \
    )))
  ifeq ($(board_config_mk),)
    $(error No config file found for TARGET_DEVICE $(TARGET_DEVICE))
  endif
  ifneq ($(words $(board_config_mk)),1)
    $(error Multiple board config files for TARGET_DEVICE $(TARGET_DEVICE): $(board_config_mk))
  endif
  TARGET_DEVICE_DIR := $(patsubst %/,%,$(dir $(board_config_mk)))
  .KATI_READONLY := TARGET_DEVICE_DIR
endif
include $(board_config_mk)
ifeq ($(TARGET_ARCH),)
  $(error TARGET_ARCH not defined by board config: $(board_config_mk))
endif
ifneq ($(MALLOC_IMPL),)
  $(warning *** Unsupported option MALLOC_IMPL defined by board config: $(board_config_mk).)
  $(error Use `MALLOC_SVELTE := true` to configure jemalloc for low-memory)
endif
board_config_mk :=

###########################################
# Handle BUILD_BROKEN_* settings
vars := \
  BUILD_BROKEN_ANDROIDMK_EXPORTS \
  BUILD_BROKEN_DUP_COPY_HEADERS \
  BUILD_BROKEN_DUP_RULES \
  BUILD_BROKEN_PHONY_TARGETS \
  BUILD_BROKEN_ENG_DEBUG_TAGS

$(foreach var,$(vars),$(eval $(var) := $$(strip $$($(var)))))

$(foreach var,$(vars), \
  $(if $(filter-out true false,$($(var))), \
    $(error Valid values of $(var) are "true", "false", and "". Not "$($(var))")))

.KATI_READONLY := $(vars)

ifneq ($(BUILD_BROKEN_ANDROIDMK_EXPORTS),true)
$(KATI_obsolete_export It is a global setting. See $(CHANGES_URL)#export_keyword)
endif

###########################################
# Now we can substitute with the real value of TARGET_COPY_OUT_RAMDISK
ifeq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
TARGET_COPY_OUT_RAMDISK := $(TARGET_COPY_OUT_ROOT)
endif

###########################################
# Configure whether we're building the system image
BUILDING_SYSTEM_IMAGE := true
ifeq ($(PRODUCT_BUILD_SYSTEM_IMAGE),)
  ifndef PRODUCT_USE_DYNAMIC_PARTITION_SIZE
    ifndef BOARD_SYSTEMIMAGE_PARTITION_SIZE
      BUILDING_SYSTEM_IMAGE :=
    endif
  endif
else ifeq ($(PRODUCT_BUILD_SYSTEM_IMAGE),false)
  BUILDING_SYSTEM_IMAGE :=
endif
.KATI_READONLY := BUILDING_SYSTEM_IMAGE

# Are we building a system_other image
BUILDING_SYSTEM_OTHER_IMAGE :=
ifeq ($(PRODUCT_BUILD_SYSTEM_OTHER_IMAGE),)
  ifdef BUILDING_SYSTEM_IMAGE
    ifeq ($(BOARD_USES_SYSTEM_OTHER_ODEX),true)
      BUILDING_SYSTEM_OTHER_IMAGE := true
    endif
  endif
else ifeq ($(PRODUCT_BUILD_SYSTEM_OTHER_IMAGE),true)
  BUILDING_SYSTEM_OTHER_IMAGE := true
  ifndef BUILDING_SYSTEM_IMAGE
    $(error PRODUCT_BUILD_SYSTEM_OTHER_IMAGE = true requires building the system image)
  endif
endif
.KATI_READONLY := BUILDING_SYSTEM_OTHER_IMAGE

# Are we building a cache image
BUILDING_CACHE_IMAGE :=
ifeq ($(PRODUCT_BUILD_CACHE_IMAGE),)
  ifdef BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE
    BUILDING_CACHE_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_CACHE_IMAGE),true)
  BUILDING_CACHE_IMAGE := true
  ifndef BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE
    $(error PRODUCT_BUILD_CACHE_IMAGE set to true, but BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE not defined)
  endif
endif
.KATI_READONLY := BUILDING_CACHE_IMAGE

# TODO: Add BUILDING_BOOT_IMAGE / BUILDING_RECOVERY_IMAGE
# This gets complicated with BOARD_USES_RECOVERY_AS_BOOT, so skipping for now.

# Are we building a ramdisk image
BUILDING_RAMDISK_IMAGE := true
ifeq ($(PRODUCT_BUILD_RAMDISK_IMAGE),)
  # TODO: Be smarter about this. This probably only needs to happen when one of the follow is true:
  #  BUILDING_BOOT_IMAGE
  #  BUILDING_RECOVERY_IMAGE
else ifeq ($(PRODUCT_BUILD_RAMDISK_IMAGE),false)
  BUILDING_RAMDISK_IMAGE :=
endif
.KATI_READONLY := BUILDING_RAMDISK_IMAGE

# Are we building a userdata image
BUILDING_USERDATA_IMAGE :=
ifeq ($(PRODUCT_BUILD_USERDATA_IMAGE),)
  ifdef BOARD_USERDATAIMAGE_PARTITION_SIZE
    BUILDING_USERDATA_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_USERDATA_IMAGE),true)
  BUILDING_USERDATA_IMAGE := true
endif
.KATI_READONLY := BUILDING_USERDATA_IMAGE

###########################################
# Now we can substitute with the real value of TARGET_COPY_OUT_VENDOR
ifeq ($(TARGET_COPY_OUT_VENDOR),$(_vendor_path_placeholder))
  TARGET_COPY_OUT_VENDOR := system/vendor
else ifeq ($(filter vendor system/vendor,$(TARGET_COPY_OUT_VENDOR)),)
  $(error TARGET_COPY_OUT_VENDOR must be either 'vendor' or 'system/vendor', seeing '$(TARGET_COPY_OUT_VENDOR)'.)
endif
PRODUCT_COPY_FILES := $(subst $(_vendor_path_placeholder),$(TARGET_COPY_OUT_VENDOR),$(PRODUCT_COPY_FILES))

BOARD_USES_VENDORIMAGE :=
ifdef BOARD_PREBUILT_VENDORIMAGE
  BOARD_USES_VENDORIMAGE := true
endif
ifdef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
  BOARD_USES_VENDORIMAGE := true
endif
ifeq ($(TARGET_COPY_OUT_VENDOR),vendor)
  BOARD_USES_VENDORIMAGE := true
else ifdef BOARD_USES_VENDORIMAGE
  $(error TARGET_COPY_OUT_VENDOR must be set to 'vendor' to use a vendor image)
endif
.KATI_READONLY := BOARD_USES_VENDORIMAGE

BUILDING_VENDOR_IMAGE :=
ifeq ($(PRODUCT_BUILD_VENDOR_IMAGE),)
  ifdef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
    BUILDING_VENDOR_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_VENDOR_IMAGE),true)
  BUILDING_VENDOR_IMAGE := true
  ifndef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
    $(error PRODUCT_BUILD_VENDOR_IMAGE set to true, but BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE not defined)
  endif
endif
ifdef BOARD_PREBUILT_VENDORIMAGE
  BUILDING_VENDOR_IMAGE :=
endif
.KATI_READONLY := BUILDING_VENDOR_IMAGE

###########################################
# Now we can substitute with the real value of TARGET_COPY_OUT_PRODUCT
ifeq ($(TARGET_COPY_OUT_PRODUCT),$(_product_path_placeholder))
TARGET_COPY_OUT_PRODUCT := system/product
else ifeq ($(filter product system/product,$(TARGET_COPY_OUT_PRODUCT)),)
$(error TARGET_COPY_OUT_PRODUCT must be either 'product' or 'system/product', seeing '$(TARGET_COPY_OUT_PRODUCT)'.)
endif
PRODUCT_COPY_FILES := $(subst $(_product_path_placeholder),$(TARGET_COPY_OUT_PRODUCT),$(PRODUCT_COPY_FILES))

BOARD_USES_PRODUCTIMAGE :=
ifdef BOARD_PREBUILT_PRODUCTIMAGE
  BOARD_USES_PRODUCTIMAGE := true
endif
ifdef BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE
  BOARD_USES_PRODUCTIMAGE := true
endif
ifeq ($(TARGET_COPY_OUT_PRODUCT),product)
  BOARD_USES_PRODUCTIMAGE := true
else ifdef BOARD_USES_PRODUCTIMAGE
  $(error TARGET_COPY_OUT_PRODUCT must be set to 'product' to use a product image)
endif
.KATI_READONLY := BOARD_USES_PRODUCTIMAGE

BUILDING_PRODUCT_IMAGE :=
ifeq ($(PRODUCT_BUILD_PRODUCT_IMAGE),)
  ifdef BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE
    BUILDING_PRODUCT_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_PRODUCT_IMAGE),true)
  BUILDING_PRODUCT_IMAGE := true
  ifndef BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE
    $(error PRODUCT_BUILD_PRODUCT_IMAGE set to true, but BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE not defined)
  endif
endif
ifdef BOARD_PREBUILT_PRODUCTIMAGE
  BUILDING_PRODUCT_IMAGE :=
endif
.KATI_READONLY := BUILDING_PRODUCT_IMAGE

###########################################
# Now we can substitute with the real value of TARGET_COPY_OUT_PRODUCT_SERVICES
MERGE_PRODUCT_SERVICES_INTO_PRODUCT :=
ifeq ($(TARGET_COPY_OUT_PRODUCT_SERVICES),$(_product_services_path_placeholder))
  TARGET_COPY_OUT_PRODUCT_SERVICES := $(TARGET_COPY_OUT_PRODUCT)
  MERGE_PRODUCT_SERVICES_INTO_PRODUCT := true
else ifeq ($(TARGET_COPY_OUT_PRODUCT),$(TARGET_COPY_OUT_PRODUCT_SERVICES))
  MERGE_PRODUCT_SERVICES_INTO_PRODUCT := true
else ifeq ($(filter product_services system/product_services,$(TARGET_COPY_OUT_PRODUCT_SERVICES)),)
  $(error TARGET_COPY_OUT_PRODUCT_SERVICES must be either 'product_services',\
    '$(TARGET_COPY_OUT_PRODUCT)' or 'system/product_services', seeing '$(TARGET_COPY_OUT_PRODUCT_SERVICES)'.)
endif
.KATI_READONLY := MERGE_PRODUCT_SERVICES_INTO_PRODUCT
PRODUCT_COPY_FILES := $(subst $(_product_services_path_placeholder),$(TARGET_COPY_OUT_PRODUCT_SERVICES),$(PRODUCT_COPY_FILES))

BOARD_USES_PRODUCT_SERVICESIMAGE :=
ifdef BOARD_PREBUILT_PRODUCT_SERVICESIMAGE
  BOARD_USES_PRODUCT_SERVICESIMAGE := true
endif
ifdef BOARD_PRODUCT_SERVICESIMAGE_FILE_SYSTEM_TYPE
  BOARD_USES_PRODUCT_SERVICESIMAGE := true
endif
ifeq ($(TARGET_COPY_OUT_PRODUCT_SERVICES),product_services)
  BOARD_USES_PRODUCT_SERVICESIMAGE := true
else ifdef BOARD_USES_PRODUCT_SERVICESIMAGE
  $(error TARGET_COPY_OUT_PRODUCT_SERVICES must be set to 'product_services' to use a product_services image)
endif

BUILDING_PRODUCT_SERVICES_IMAGE :=
ifeq ($(PRODUCT_BUILD_PRODUCT_SERVICES_IMAGE),)
  ifdef BOARD_PRODUCT_SERVICESIMAGE_FILE_SYSTEM_TYPE
    BUILDING_PRODUCT_SERVICES_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_PRODUCT_SERVICES_IMAGE),true)
  BUILDING_PRODUCT_SERVICES_IMAGE := true
  ifndef BOARD_PRODUCT_SERVICESIMAGE_FILE_SYSTEM_TYPE
    $(error PRODUCT_BUILD_PRODUCT_SERVICES_IMAGE set to true, but BOARD_PRODUCT_SERVICESIMAGE_FILE_SYSTEM_TYPE not defined)
  endif
endif
ifdef BOARD_PREBUILT_PRODUCT_SERVICESIMAGE
  BUILDING_PRODUCT_SERVICES_IMAGE :=
endif
.KATI_READONLY := BUILDING_PRODUCT_SERVICES_IMAGE

###########################################
# Now we can substitute with the real value of TARGET_COPY_OUT_ODM
ifeq ($(TARGET_COPY_OUT_ODM),$(_odm_path_placeholder))
  TARGET_COPY_OUT_ODM := vendor/odm
else ifeq ($(filter odm vendor/odm,$(TARGET_COPY_OUT_ODM)),)
  $(error TARGET_COPY_OUT_ODM must be either 'odm' or 'vendor/odm', seeing '$(TARGET_COPY_OUT_ODM)'.)
endif
PRODUCT_COPY_FILES := $(subst $(_odm_path_placeholder),$(TARGET_COPY_OUT_ODM),$(PRODUCT_COPY_FILES))

BOARD_USES_ODMIMAGE :=
ifdef BOARD_PREBUILT_ODMIMAGE
  BOARD_USES_ODMIMAGE := true
endif
ifdef BOARD_ODMIMAGE_FILE_SYSTEM_TYPE
  BOARD_USES_ODMIMAGE := true
endif
ifeq ($(TARGET_COPY_OUT_ODM),odm)
  BOARD_USES_ODMIMAGE := true
else ifdef BOARD_USES_ODMIMAGE
  $(error TARGET_COPY_OUT_ODM must be set to 'odm' to use an odm image)
endif

BUILDING_ODM_IMAGE :=
ifeq ($(ODM_BUILD_ODM_IMAGE),)
  ifdef BOARD_ODMIMAGE_FILE_SYSTEM_TYPE
    BUILDING_ODM_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_ODM_IMAGE),true)
  BUILDING_ODM_IMAGE := true
  ifndef BOARD_ODMIMAGE_FILE_SYSTEM_TYPE
    $(error PRODUCT_BUILD_ODM_IMAGE set to true, but BOARD_ODMIMAGE_FILE_SYSTEM_TYPE not defined)
  endif
endif
ifdef BOARD_PREBUILT_ODMIMAGE
  BUILDING_ODM_IMAGE :=
endif
.KATI_READONLY := BUILDING_ODM_IMAGE

###########################################
# Ensure that only TARGET_RECOVERY_UPDATER_LIBS *or* AB_OTA_UPDATER is set.
TARGET_RECOVERY_UPDATER_LIBS ?=
AB_OTA_UPDATER ?=
.KATI_READONLY := TARGET_RECOVERY_UPDATER_LIBS AB_OTA_UPDATER
ifeq ($(AB_OTA_UPDATER),true)
  ifneq ($(strip $(TARGET_RECOVERY_UPDATER_LIBS)),)
    $(error Do not use TARGET_RECOVERY_UPDATER_LIBS when using AB_OTA_UPDATER)
  endif
endif

# Check BOARD_VNDK_VERSION
define check_vndk_version
  $(eval vndk_path := prebuilts/vndk/v$(1)) \
  $(if $(wildcard $(vndk_path)/*/Android.bp),,$(error VNDK version $(1) not found))
endef

ifdef BOARD_VNDK_VERSION
  ifneq ($(BOARD_VNDK_VERSION),current)
    $(error BOARD_VNDK_VERSION: Only "current" is implemented)
  endif

  TARGET_VENDOR_TEST_SUFFIX := /vendor
else
  TARGET_VENDOR_TEST_SUFFIX :=
endif

ifeq (,$(TARGET_BUILD_APPS))
ifdef PRODUCT_EXTRA_VNDK_VERSIONS
  $(foreach v,$(PRODUCT_EXTRA_VNDK_VERSIONS),$(call check_vndk_version,$(v)))
endif
endif

# Ensure that BOARD_SYSTEMSDK_VERSIONS are all within PLATFORM_SYSTEMSDK_VERSIONS
_unsupported_systemsdk_versions := $(filter-out $(PLATFORM_SYSTEMSDK_VERSIONS),$(BOARD_SYSTEMSDK_VERSIONS))
ifneq (,$(_unsupported_systemsdk_versions))
  $(error System SDK versions '$(_unsupported_systemsdk_versions)' in BOARD_SYSTEMSDK_VERSIONS are not supported.\
          Supported versions are $(PLATFORM_SYSTEMSDK_VERSIONS))
endif
