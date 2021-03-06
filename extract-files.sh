#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017 The LineageOS Project
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

set -e

DEVICE=kuntao
VENDOR=lenovo
INITIAL_COPYRIGHT_YEAR=2017

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

LINEAGE_ROOT="$MY_DIR"/../../..

HELPER="$LINEAGE_ROOT"/vendor/lineage/build/tools/extract_utils.sh
if [ ! -f "$HELPER" ]; then
    echo "Unable to find helper script at $HELPER"
    exit 1
fi
. "$HELPER"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

while [ "$1" != "" ]; do
    case $1 in
        -n | --no-cleanup )     CLEAN_VENDOR=false
                                ;;
        -s | --section )        shift
                                SECTION=$1
                                CLEAN_VENDOR=false
                                ;;
        * )                     SRC=$1
                                ;;
    esac
    shift
done

if [ -z "$SRC" ]; then
    SRC=adb
fi

# Initialize the helper
setup_vendor "$DEVICE" "$VENDOR" "$LINEAGE_ROOT" false "$CLEAN_VENDOR"

#
# Hax libaudcal.so to store acdbdata in new path
#
sed -i "s|\/data\/vendor\/misc\/audio\/acdbdata\/delta\/|\/data\/vendor\/audio\/acdbdata\/delta\/\x00\x00\x00\x00\x00|g" \
    "$BLOB_ROOT"/vendor/lib/libaudcal.so
sed -i "s|\/data\/vendor\/misc\/audio\/acdbdata\/delta\/|\/data\/vendor\/audio\/acdbdata\/delta\/\x00\x00\x00\x00\x00|g" \
    "$BLOB_ROOT"/vendor/lib64/libaudcal.so

for HIDL_BASE_LIB in $(grep -lr "android\.hidl\.base@1\.0\.so" $BLOB_ROOT); do
    patchelf --remove-needed android.hidl.base@1.0.so "$HIDL_BASE_LIB" || true
done

for HIDL_MANAGER_LIB in $(grep -lr "android\.hidl\.@1\.0\.so" $BLOB_ROOT); do
    patchelf --remove-needed android.hidl.manager@1.0.so "$HIDL_MANAGER_LIB" || true
done

#
# Add liblog dependency to smart_charger
#
SMART_CHARGER="$BLOB_ROOT"/vendor/bin/smart_charger
patchelf --add-needed liblog.so "$SMART_CHARGER"

extract "$MY_DIR"/proprietary-files.txt "$SRC" "$SECTION"
extract "$MY_DIR"/proprietary-files-qc.txt "$SRC" "$SECTION"

COMMON_BLOB_ROOT="$LINEAGE_ROOT"/vendor/"$VENDOR"/"$DEVICE"/proprietary

"$MY_DIR"/setup-makefiles.sh
