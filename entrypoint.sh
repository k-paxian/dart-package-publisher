#!/bin/bash

set -e

export PATH="$PATH":"$HOME/.pub-cache/bin"

trace() {
  local message=$1
	local summary=$2

  if [ -z "$message" ]; then
    :
  else
    echo "$message"
  fi

  if [ -z "$summary" ]; then
    :
  else
    echo "$summary" >> $GITHUB_STEP_SUMMARY
  fi
}

check_required_inputs() {
  trace "🔑 Check credentials..."
  if [ -z "$INPUT_CREDENTIALJSON" ]; then
    trace "Missing credentialJson, trying tokens"
    if [ -z "$INPUT_ACCESSTOKEN" ]; then
      trace "Missing accessToken"
      exit 1
    fi
    if [ -z "$INPUT_REFRESHTOKEN" ]; then
      trace "Missing refreshToken"
      exit 1
    fi
  fi
  echo "OK"
}

switch_working_directory() {
  if [ -z "$INPUT_RELATIVEPATH" ]; then
    :
  else
    echo "Switching to package directory '$INPUT_RELATIVEPATH'"
    cd "$INPUT_RELATIVEPATH"
  fi
  echo "Package dir: $PWD"
}

detect_flutter_package() {
  GET_OUTPUT=`dart pub get`
  if [ "$?" = 69 ] || [ "$GET_OUTPUT" = "Resolving dependencies..." ] || [ "$INPUT_FLUTTER" = "true" ]; then
    INPUT_FLUTTER="true"
    export PATH="$PATH":"/flutter/bin"
    echo "Flutter package detected. Installing Flutter from $INPUT_FLUTTERBRANCH branch..."
    git clone -b $INPUT_FLUTTERBRANCH --depth 1 https://github.com/flutter/flutter.git /flutter
    flutter doctor
  fi
}

get_local_package_version() {
  if [ "$INPUT_FLUTTER" = "true" ]; then
    GET_OUTPUT=`flutter pub get`
    DEPS_OUTPUT=`flutter pub deps`
  else
    GET_OUTPUT=`dart pub get`
    DEPS_OUTPUT=`dart pub deps`
  fi
  PACKAGE_INFO=`echo "$DEPS_OUTPUT" | cut -d'|' -f1 | cut -d"'" -f1 | head -n 3`
  echo "$PACKAGE_INFO"
  DART_VERSION=`echo "$PACKAGE_INFO" | perl -n -e'/^Dart SDK (.*)$/ && print $1'`
  FLUTTER_VERSION=`echo "$PACKAGE_INFO" | perl -n -e'/^Flutter SDK (.*)$/ && print $1'`
  PACKAGE_INFO=`echo "$PACKAGE_INFO" | tail -1`
  PACKAGE=`echo "$PACKAGE_INFO" | cut -d' ' -f1`
  LOCAL_PACKAGE_VERSION=`echo "$PACKAGE_INFO" | cut -d' ' -f2`
  if [ -z "$PACKAGE" ]; then
    echo "::error::No package found. :("
    echo "No package found. :(" >> $GITHUB_STEP_SUMMARY
    exit 1
  fi
  echo "dartVersion=$DART_VERSION" >> $GITHUB_OUTPUT
  if [ "$FLUTTER_VERSION" != "" ]; then
    echo "flutterVersion=$FLUTTER_VERSION" >> $GITHUB_OUTPUT
  fi
  echo "package=$PACKAGE" >> $GITHUB_OUTPUT
  echo "localVersion=$LOCAL_PACKAGE_VERSION" >> $GITHUB_OUTPUT
}

run_unit_tests() {
    if [ "$INPUT_SKIPTESTS" = "true" ]; then
      echo "::notice::Skip unit tests set to true, skip unit testing."
    else
      HAS_BUILD_RUNNER=`echo "$DEPS_OUTPUT" | perl -n -e'/^.* build_runner (.*)/ && print $1'`
      HAS_BUILD_TEST=`echo "$DEPS_OUTPUT" | perl -n -e'/^.* build_test (.*)/ && print $1'`
      HAS_TEST=`echo "$DEPS_OUTPUT" | perl -n -e'/^.* (test|flutter_test) (.*)/ && print $2'`
      if [ "$HAS_BUILD_RUNNER" != "" ] && [ "$HAS_BUILD_TEST" != "" ] && [ "$INPUT_SUPPRESSBUILDRUNNER" != "true" ]; then
        if [ "$INPUT_FLUTTER" = "true" ]; then
          echo "::notice::flutter tests with build_runner"
          flutter pub run build_runner build --delete-conflicting-outputs
          flutter test
        else
          dart pub run build_runner test --delete-conflicting-outputs
        fi
      else
        if [ "$HAS_TEST" != "" ]; then
          if [ "$INPUT_FLUTTER" = "true" ]; then
            flutter test
          else
            dart pub run test
          fi
        else
          echo "::notice::No unit test related dependencies detected, skip unit testing."
          echo "No unit test related dependencies detected, skip unit testing." >> $GITHUB_STEP_SUMMARY
        fi
      fi
    fi
}

get_remote_package_version() {
  if [ "$INPUT_FLUTTER" = "true" ]; then
    ACTIVATE_OUTPUT=`flutter pub global activate $PACKAGE`
  else
    ACTIVATE_OUTPUT=`dart pub global activate $PACKAGE`
  fi
  REMOTE_PACKAGE_VERSION=`echo "$ACTIVATE_OUTPUT" | perl -n -e'/^Activated .* (.*)\./ && print $1'`
  if [ -z "$REMOTE_PACKAGE_VERSION" ]; then
    REMOTE_PACKAGE_VERSION="✗"
  fi
  echo "::notice::Local version: [$LOCAL_PACKAGE_VERSION]"
  echo "Local version: [$LOCAL_PACKAGE_VERSION]" >> $GITHUB_STEP_SUMMARY
  echo "::notice::Remote version: [$REMOTE_PACKAGE_VERSION]"
  echo "Remote version: [$REMOTE_PACKAGE_VERSION]" >> $GITHUB_STEP_SUMMARY
  echo "remoteVersion=$REMOTE_PACKAGE_VERSION" >> $GITHUB_OUTPUT
}

format() {
  if [ "$INPUT_FORMAT" = "true" ]; then
    if [ "$INPUT_FLUTTER" = "true" ]; then
      flutter format .
    else
      dart format .
    fi
  fi
}

publish() {
  if [ "$LOCAL_PACKAGE_VERSION" = "$REMOTE_PACKAGE_VERSION" ]; then
    echo "::notice::Remote & Local versions are equal, skip publishing."
    echo "📝Remote & Local versions are equal, skip publishing." >> $GITHUB_STEP_SUMMARY
  else
    mkdir -p ~/.config/dart
    if [ -z "$INPUT_CREDENTIALJSON" ]; then
      cat <<-EOF > ~/.config/dart/pub-credentials.json
      {
        "accessToken":"$INPUT_ACCESSTOKEN",
        "refreshToken":"$INPUT_REFRESHTOKEN",
        "tokenEndpoint":"https://accounts.google.com/o/oauth2/token",
        "scopes": [ "openid", "https://www.googleapis.com/auth/userinfo.email" ],
        "expiration": 1577149838000
      }
EOF
    else
      echo "$INPUT_CREDENTIALJSON" > ~/.config/dart/pub-credentials.json
    fi
    if [ "$INPUT_FLUTTER" = "true" ]; then
      flutter pub publish --dry-run
    else
      dart pub lish --dry-run
    fi
    if [ $? -eq 0 ]; then
      echo "::notice::Dry Run Successfull."
    else
      if [ "$INPUT_FORCE" != "true" ] && [ "$INPUT_TESTRUNONLY" != "true" ]; then
        echo "::error::Dry Run Failed, skip real publishing."
        echo "Dry Run Failed, skip real publishing." >> $GITHUB_STEP_SUMMARY
        exit 1
      fi
    fi
    if [ "$INPUT_DRYRUNONLY" = "true" ]; then
      echo "::notice::Dry 🏃‍♂️ only, skip publishing."
      echo "Dry 🏃‍♂️ only, skip publishing." >> $GITHUB_STEP_SUMMARY
    else
      if [ "$INPUT_FLUTTER" = "true" ]; then
        flutter pub publish -f
      else
        dart pub lish -f
      fi
      if [ $? -eq 0 ]; then
        echo "success=true" >> $GITHUB_OUTPUT
        echo ":rocket:" >> $GITHUB_STEP_SUMMARY
      else
        echo "success=false" >> $GITHUB_OUTPUT
        echo ":red_circle:" >> $GITHUB_STEP_SUMMARY
      fi
    fi
  fi
}

check_required_inputs
switch_working_directory
detect_flutter_package || true
get_local_package_version
run_unit_tests
get_remote_package_version || true
format || true
publish || true
