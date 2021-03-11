#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

function blob_fixup() {
    case "${1}" in
        lib64/libwfdnative.so)
            "${PATCHELF}" --remove-needed android.hidl.base@1.0.so "${2}"
            ;;

        # memset shim
        vendor/bin/charge_only_mode)
            for LIBMEMSET_SHIM in $(grep -L "libmemset_shim.so" "${2}"); do
                "${PATCHELF}" --add-needed "libmemset_shim.so" "${LIBMEMSET_SHIM}"
            done
            ;;

        vendor/lib/hw/activity_recognition.msm8937.so | vendor/lib64/hw/activity_recognition.msm8937.so)
            "${PATCHELF}" --set-soname activity_recognition.msm8937.so "${2}"
            ;;

        vendor/lib/hw/camera.msm8937.so)
            "${PATCHELF}" --set-soname camera.msm8937.so "${2}"
            ;;

        vendor/lib64/hw/gatekeeper.msm8937.so)
            "${PATCHELF}" --set-soname gatekeeper.msm8937.so "${2}"
            ;;

        vendor/lib64/hw/keystore.msm8937.so)
            "${PATCHELF}" --set-soname keystore.msm8937.so "${2}"
            ;;

        vendor/lib/libactuator_dw9767_truly.so)
            "${PATCHELF}" --set-soname libactuator_dw9767_truly.so "${2}"
            ;;

        # Fix camera recording
        vendor/lib/libmmcamera2_pproc_modules.so)
            sed -i "s/ro.product.manufacturer/ro.product.nopefacturer/" "${2}"
            ;;

        vendor/lib/libmmcamera2_sensor_modules.so)
            sed -i 's|msm8953_mot_deen_camera.xml|msm8937_mot_camera_conf.xml|g' "${2}"
            ;;

        vendor/lib/libmot_gpu_mapper.so | vendor/lib/libmmcamera_vstab_module.so)
            sed -i "s/libgui/libwui/" "${2}"
            ;;

        vendor/lib64/libmdmcutback.so)
            sed -i "s|libqsap_sdk.so|libqsapshim.so|g" "${2}"
            ;;

        vendor/lib64/libril-qc-qmi-1.so)
            for LIBCUTILS_SHIM in $(grep -L "libcutils_shim.so" "${2}"); do
                "${PATCHELF}" --add-needed "libcutils_shim.so" "${LIBCUTILS_SHIM}"
            done
            ;;
    esac
}

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_BOARD_COMMON=
ONLY_DEVICE_COMMON=
ONLY_TARGET=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-board-common )
                ONLY_BOARD_COMMON=true
                ;;
        --only-device-common )
                ONLY_DEVICE_COMMON=true
                ;;
        --only-target )
                ONLY_TARGET=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

if [ -z "${ONLY_TARGET}" ] && [ -z "${ONLY_DEVICE_COMMON}" ]; then
    # Initialize the helper
    setup_vendor "${BOARD_COMMON}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" ${KANG} --section "${SECTION}"
fi

if [ -z "${ONLY_BOARD_COMMON}" ] && [ -z "${ONLY_TARGET}" ] && [ -s "${MY_DIR}/../${DEVICE_COMMON}/proprietary-files.txt" ];then
    # Reinitialize the helper for device common
    source "${MY_DIR}/../${DEVICE_COMMON}/extract-files.sh"
    setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../${DEVICE_COMMON}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${ONLY_BOARD_COMMON}" ] && [ -z "${ONLY_DEVICE_COMMON}" ] && [ -s "${MY_DIR}/../${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../${DEVICE}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"
