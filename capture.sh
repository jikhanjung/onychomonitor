#!/bin/bash

FILENAME="$(TZ='Asia/Seoul' date +%Y%m%d-%H%M%S).jpg"
TMP_PATH="/tmp/${FILENAME}"
DATE_DIR="$(TZ='Asia/Seoul' date +%Y%m%d)"
DEST_DIR="/nfs/share/onychomonitor/pictures/${DATE_DIR}"
TMP_PICTURES="/srv/onychomonitor/tmp_pictures"
LOG_FILE="/srv/onychomonitor/capture.log"

log() {
    echo "$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S') $1" >> "${LOG_FILE}"
}

mkdir -p "${TMP_PICTURES}"

# 촬영 -> /tmp (tmpfs)
if ! rpicam-still -o "${TMP_PATH}" --nopreview -t 1000 2>>"${LOG_FILE}"; then
    log "[ERROR] capture failed"
    exit 1
fi

if [ ! -f "${TMP_PATH}" ]; then
    log "[ERROR] captured file not found: ${TMP_PATH}"
    exit 1
fi

# NFS 마운트 확인 및 이동
if mountpoint -q /nfs/share; then
    mkdir -p "${DEST_DIR}"
    # 밀린 사진 일괄 전송
    for f in "${TMP_PICTURES}"/*.jpg; do
        [ -f "$f" ] || continue
        flush_date="${f##*/}"
        flush_date="${flush_date%%-*}"
        flush_dir="/nfs/share/onychomonitor/pictures/${flush_date}"
        mkdir -p "${flush_dir}"
        if mv "$f" "${flush_dir}/"; then
            log "[OK] flushed $(basename "$f")"
        else
            log "[ERROR] failed to flush $(basename "$f")"
        fi
    done

    # 현재 촬영분 전송
    if mv "${TMP_PATH}" "${DEST_DIR}/${FILENAME}"; then
        log "[OK] ${FILENAME}"
    else
        log "[ERROR] failed to move ${FILENAME} to ${DEST_DIR}, saving locally"
        mv "${TMP_PATH}" "${TMP_PICTURES}/${FILENAME}"
    fi
else
    log "[WARN] /nfs/share not mounted, saving to tmp_pictures"
    mv "${TMP_PATH}" "${TMP_PICTURES}/${FILENAME}"
fi
