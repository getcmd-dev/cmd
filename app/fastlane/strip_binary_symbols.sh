#!/bin/bash

# From https://docs.emergetools.com/docs/strip-binary-symbols

set -e

echo "Starting the symbol stripping process..."

if [ "Release" = "${CONFIGURATION}" ]; then
  echo "Configuration is Release."
  
  # Path to the app directory
  APP_DIR_PATH="${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"
  echo "App directory path: ${APP_DIR_PATH}"

  # Strip main binary
  echo "Stripping main binary: ${APP_DIR_PATH}/${EXECUTABLE_NAME}"
#   strip -rSTx "${APP_DIR_PATH}/${EXECUTABLE_NAME}"
  strip -rSTx "/Users/guigui/dev/cmd/app/build/release/command.app/Contents/MacOS"
  if [ $? -eq 0 ]; then
    echo "Successfully stripped main binary."
  else
    echo "Failed to strip main binary." >&2
  fi

  # Path to the Frameworks directory
  APP_FRAMEWORKS_DIR="${APP_DIR_PATH}/Frameworks"
  echo "Frameworks directory path: ${APP_FRAMEWORKS_DIR}"

  # Strip symbols from frameworks, if Frameworks/ exists at all
  # ... as long as the framework is NOT signed by Apple
  if [ -d "${APP_FRAMEWORKS_DIR}" ]; then
    echo "Frameworks directory exists. Proceeding to strip symbols from frameworks."
    find "${APP_FRAMEWORKS_DIR}" -type f -perm +111 -maxdepth 2 -mindepth 2 -exec bash -c '
    codesign -v -R="anchor apple" "{}" &> /dev/null ||
    (
        echo "Stripping {}" &&
        if [ -w "{}" ]; then
            strip -rSTx "{}"
            if [ $? -eq 0 ]; then
                echo "Successfully stripped {}"
            else
                echo "Failed to strip {}" >&2
            fi
        else
            echo "Warning: No write permission for {}"
        fi
    )
    ' \;
    if [ $? -eq 0 ]; then
        echo "Successfully stripped symbols from frameworks."
    else
        echo "Failed to strip symbols from some frameworks." >&2
    fi
  else
    echo "Frameworks directory does not exist. Skipping framework stripping."
  fi
else
  echo "Configuration is not Release. Skipping symbol stripping."
fi

echo "Symbol stripping process completed."