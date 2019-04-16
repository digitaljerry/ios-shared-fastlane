#!/bin/bash

TARGET_NAMES=( RallyReaderApp RallyReaderAppDEV )
PREV_TOTAL=0
SRCROOT=./

for TARGET_NAME in "${TARGET_NAMES[@]}"; do
    TOTAL=`${SRCROOT}/XcodeProjectTargetCheck -xcproj ${SRCROOT}/RallyReaderApp.xcodeproj -targets ${TARGET_NAME} | wc -l`
    echo 'Target: '${TARGET_NAME} '- Number of files: '${TOTAL}

    if [ "$PREV_TOTAL" -gt 0 ]; then
        if [ "$TOTAL" != "$PREV_TOTAL" ]; then
            echo "error: Target with name \"${TARGET_NAME}\" has a different number of files!"
            exit 1
        fi
    fi

    PREV_TOTAL=$TOTAL
done
