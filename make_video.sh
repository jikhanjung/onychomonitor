#!/bin/bash

set -euo pipefail

PICTURES_DIR="/nfs/temp-share/onychomonitor/pictures"
VIDEOS_DIR="/nfs/temp-share/onychomonitor/videos"
FPS=30

usage() {
    echo "Usage: $0 [YYYYMMDD]"
    echo "  날짜를 생략하면 어제 날짜로 생성합니다."
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

DATE="${1:-$(TZ='Asia/Seoul' date -d yesterday +%Y%m%d)}"

if [[ ! "${DATE}" =~ ^[0-9]{8}$ ]]; then
    echo "Error: 날짜 형식이 올바르지 않습니다 (YYYYMMDD)" >&2
    exit 1
fi

SRC_DIR="${PICTURES_DIR}/${DATE}"
if [[ ! -d "${SRC_DIR}" ]]; then
    echo "Error: 디렉토리가 없습니다: ${SRC_DIR}" >&2
    exit 1
fi

FILE_COUNT=$(find "${SRC_DIR}" -maxdepth 1 -name '*.jpg' | wc -l)
if [[ "${FILE_COUNT}" -eq 0 ]]; then
    echo "Error: ${SRC_DIR}에 jpg 파일이 없습니다." >&2
    exit 1
fi

mkdir -p "${VIDEOS_DIR}"
OUTPUT="${VIDEOS_DIR}/${DATE}.mp4"
FILELIST=$(mktemp)
SUBFILE=$(mktemp --suffix=.ass)
trap 'rm -f "${FILELIST}" "${SUBFILE}"' EXIT

# ASS 자막 헤더 (우측 하단에 타임스탬프 표시)
cat > "${SUBFILE}" << 'ASSHEADER'
[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,40,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,1,0,0,0,100,100,0,0,3,1,2,3,20,20,30,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
ASSHEADER

# 파일명이 시간순이므로 정렬만 하면 됨
FRAME_IDX=0
while read -r f; do
    echo "file '${f}'" >> "${FILELIST}"

    # 파일명에서 타임스탬프 추출 (YYYYMMDD-HHMMSS.jpg)
    BASENAME=$(basename "${f}" .jpg)
    FILE_DATE="${BASENAME:0:4}-${BASENAME:4:2}-${BASENAME:6:2}"
    HOUR=$((10#${BASENAME:9:2}))
    MIN="${BASENAME:11:2}"

    if [[ ${HOUR} -eq 0 ]]; then
        DISPLAY_HOUR="12"; AMPM="am"
    elif [[ ${HOUR} -lt 12 ]]; then
        DISPLAY_HOUR="${HOUR}"; AMPM="am"
    elif [[ ${HOUR} -eq 12 ]]; then
        DISPLAY_HOUR="12"; AMPM="pm"
    else
        DISPLAY_HOUR="$((HOUR - 12))"; AMPM="pm"
    fi

    TIMESTAMP="${FILE_DATE} ${DISPLAY_HOUR}:${MIN}${AMPM}"

    # ASS 타임코드 계산 (H:MM:SS.CC)
    START_CS=$((FRAME_IDX * 100 / FPS))
    END_CS=$(((FRAME_IDX + 1) * 100 / FPS))

    printf "Dialogue: 0,%d:%02d:%02d.%02d,%d:%02d:%02d.%02d,Default,,0,0,0,,%s\n" \
        "$((START_CS / 360000))" "$(((START_CS % 360000) / 6000))" "$(((START_CS % 6000) / 100))" "$((START_CS % 100))" \
        "$((END_CS / 360000))" "$(((END_CS % 360000) / 6000))" "$(((END_CS % 6000) / 100))" "$((END_CS % 100))" \
        "${TIMESTAMP}" >> "${SUBFILE}"

    FRAME_IDX=$((FRAME_IDX + 1))
done < <(find "${SRC_DIR}" -maxdepth 1 -name '*.jpg' | sort)

ffmpeg -y -f concat -safe 0 -r "${FPS}" -i "${FILELIST}" \
    -vf "ass=${SUBFILE}" \
    -c:v libx264 -pix_fmt yuv420p -crf 18 \
    "${OUTPUT}"

echo "완료: ${OUTPUT} (${FILE_COUNT}장, ${FPS}fps)"
