#!/bin/bash
set -e
set -o pipefail

chmod +x samples/sample_kcl.rb

if [[ "$RUNNER_OS" == "macOS" ]]; then
  brew install coreutils
  (cd samples && gtimeout $RUN_TIME_SECONDS rake run properties_file=../.github/resources/sample.properties 2>&1 | tee ../kcl_output.log) || [ $? -eq 124 ]
elif [[ "$RUNNER_OS" == "Linux" || "$RUNNER_OS" == "Windows" ]]; then
  (cd samples && timeout $RUN_TIME_SECONDS rake run properties_file=../.github/resources/sample.properties 2>&1 | tee ../kcl_output.log) || [ $? -eq 124 ]
else
  echo "Unknown OS: $RUNNER_OS"
  exit 1
fi

echo "==========ERROR LOGS HERE=========="
grep -i error kcl_output.log || echo "No errors found in logs"