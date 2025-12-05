#!/bin/bash
set -e

# Manipulate sample.properties file that the KCL application pulls properties from (ex: streamName, applicationName)
# Depending on the OS, different properties need to be changed
if [[ "$RUNNER_OS" == "macOS" ]]; then
  sed -i "" "s/STREAM_NAME_PLACEHOLDER/$STREAM_NAME/g" .github/resources/github_workflow.properties
  sed -i "" "s/APP_NAME_PLACEHOLDER/$APP_NAME/g" .github/resources/github_workflow.properties
elif [[ "$RUNNER_OS" == "Linux" || "$RUNNER_OS" == "Windows" ]]; then
  sed -i "s/STREAM_NAME_PLACEHOLDER/$STREAM_NAME/g" .github/resources/github_workflow.properties
  sed -i "s/APP_NAME_PLACEHOLDER/$APP_NAME/g" .github/resources/github_workflow.properties
  if [[ "$RUNNER_OS" == "Windows" ]]; then
    echo '@echo off' > samples/run_script.bat
    echo 'ruby %~dp0sample_kcl.rb %*' >> samples/run_script.bat
    sed -i 's/executableName = sample_kcl.rb/executableName = run_script.bat/' .github/resources/github_workflow.properties
  fi
else
  echo "Unknown OS: $RUNNER_OS"
  exit 1
fi

cat .github/resources/github_workflow.properties