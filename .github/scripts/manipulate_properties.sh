#!/bin/bash
set -e

# Manipulate sample.properties file that the KCL application pulls properties from (ex: streamName, applicationName)
# Depending on the OS, different properties need to be changed
if [[ "$RUNNER_OS" == "macOS" ]]; then
  sed -i "" "s/kclrbsample/$STREAM_NAME/g" samples/sample.properties
  sed -i "" "s/RubyKCLSample/$APP_NAME/g" samples/sample.properties
  sed -i "" 's/us-east-5/us-east-1/g' samples/sample.properties
  grep -v "idleTimeBetweenReadsInMillis" samples/sample.properties > samples/temp.properties
  echo "idleTimeBetweenReadsInMillis = 250" >> samples/temp.properties
  mv samples/temp.properties samples/sample.properties
elif [[ "$RUNNER_OS" == "Linux" || "$RUNNER_OS" == "Windows" ]]; then
  sed -i "s/kclrbsample/$STREAM_NAME/g" samples/sample.properties
  sed -i "s/RubyKCLSample/$APP_NAME/g" samples/sample.properties
  sed -i 's/us-east-5/us-east-1/g' samples/sample.properties
  sed -i "/idleTimeBetweenReadsInMillis/c\idleTimeBetweenReadsInMillis = 250" samples/sample.properties
  if [[ "$RUNNER_OS" == "Windows" ]]; then
    echo '@echo off' > samples/run_script.bat
    echo 'ruby %~dp0\sample_kcl.rb %*' >> samples/run_script.bat
    sed -i 's/executableName = sample_kcl.rb/executableName = run_script.bat/' samples/sample.properties
  fi
else
  echo "Unknown OS: $RUNNER_OS"
  exit 1
fi

cat samples/sample.properties