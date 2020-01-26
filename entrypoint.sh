#!/bin/bash

set -e

export PATH="$PATH":"$HOME/.pub-cache/bin"

check_required_inputs() {
  echo "Check inputs..."
  if [ -z "$INPUT_ACCESSTOKEN" ]; then
    echo "Missing accessToken"
    exit 1
  fi
  if [ -z "$INPUT_REFRESHTOKEN" ]; then
    echo "Missing refreshToken"
    exit 1
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

get_local_package_version() {
  if [ "$INPUT_FLUTTER" = "true" ]; then
    GET_OUTPUT=`flutter pub get`
    DEPS_OUTPUT=`flutter pub deps`
  else
    GET_OUTPUT=`pub get`
    DEPS_OUTPUT=`pub deps`
  fi
  PACKAGE_INFO=`echo "$DEPS_OUTPUT" | cut -d'|' -f1 | cut -d"'" -f1 | sed '/^\s*$/d'`
  IFS=$'\n\r' read -d '' -r -a lines <<< "$PACKAGE_INFO"
  lastIndex=`expr ${#lines[@]}-1`
  echo "$PACKAGE_INFO"  
  DART_VERSION=`echo "$PACKAGE_INFO" | perl -n -e'/^Dart SDK (.*)$/ && print $1'`
  FLUTTER_VERSION=`echo "$PACKAGE_INFO" | perl -n -e'/^Flutter SDK (.*)$/ && print $1'`
  PACKAGE_INFO="${lines[$lastIndex]}"  
  PACKAGE=`echo "$PACKAGE_INFO" | cut -d' ' -f1`  
  LOCAL_PACKAGE_VERSION=`echo "$PACKAGE_INFO" | cut -d' ' -f2`  
  if [ -z "$PACKAGE" ]; then
    echo "No package found. :("
    exit 0
  fi  
  echo "::set-output name=dartVersion::$DART_VERSION"
  if [ "$FLUTTER_VERSION" != "" ]; then
    echo "::set-output name=flutterVersion::$FLUTTER_VERSION"
  fi
  echo "::set-output name=package::$PACKAGE"
  echo "::set-output name=localVersion::$LOCAL_PACKAGE_VERSION"
}

run_unit_tests() {
    if [ "$INPUT_SKIPTESTS" = "true" ]; then
      echo "Skip unit tests set to true, skip unit testing."
    else
      HAS_BUILD_RUNNER=`echo "$DEPS_OUTPUT" | perl -n -e'/^.* build_runner (.*)/ && print $1'`
      HAS_BUILD_TEST=`echo "$DEPS_OUTPUT" | perl -n -e'/^.* build_test (.*)/ && print $1'`
      HAS_TEST=`echo "$DEPS_OUTPUT" | perl -n -e'/^.* (test|flutter_test) (.*)/ && print $2'`
      if [ "$HAS_BUILD_RUNNER" != "" ] && [ "$HAS_BUILD_TEST" != "" ] && [ "$INPUT_SUPPRESSBUILDRUNNER" != "true" ]; then
        if [ "$INPUT_FLUTTER" = "true" ]; then
          flutter pub run build_runner test
        else
          pub run build_runner test
        fi
      else
        if [ "$HAS_TEST" != "" ]; then
          if [ "$INPUT_FLUTTER" = "true" ]; then
            flutter test
          else
            pub run test
          fi
        else
          echo "No unit test related dependencies detected, skip unit testing."
        fi      
      fi      
    fi
}

get_remote_package_version() {
  if [ "$INPUT_FLUTTER" = "true" ]; then
    ACTIVATE_OUTPUT=`flutter pub global activate $PACKAGE`
  else
    ACTIVATE_OUTPUT=`pub global activate $PACKAGE`
  fi
  REMOTE_PACKAGE_VERSION=`echo "$ACTIVATE_OUTPUT" | perl -n -e'/^Activated .* (.*)\./ && print $1'`
  if [ -z "$REMOTE_PACKAGE_VERSION" ]; then
    REMOTE_PACKAGE_VERSION="✗"
  fi
  echo "Local version: [$LOCAL_PACKAGE_VERSION]"  
  echo "Remote version: [$REMOTE_PACKAGE_VERSION]"
  echo "::set-output name=remoteVersion::$REMOTE_PACKAGE_VERSION"
}

publish() {
  if [ "$LOCAL_PACKAGE_VERSION" = "$REMOTE_PACKAGE_VERSION" ]; then
    echo "Remote & Local versions are equal, skip publishing."
  else
    mkdir -p ~/.pub-cache
    cat <<-EOF > ~/.pub-cache/credentials.json
    {
      "accessToken":"$INPUT_ACCESSTOKEN",
      "refreshToken":"$INPUT_REFRESHTOKEN",
      "tokenEndpoint":"https://accounts.google.com/o/oauth2/token",
      "scopes": [ "openid", "https://www.googleapis.com/auth/userinfo.email" ],
      "expiration": 1577149838000
    }
EOF
    if [ "$INPUT_FLUTTER" = "true" ]; then
      flutter pub publish --dry-run
    else
      pub lish --dry-run
    fi
    if [ $? -eq 0 ]; then
      echo "Dry Run Successfull."
    else
      echo "Dry Run Failed, skip real publishing."
      exit 0
    fi    
    if [ "$INPUT_DRYRUNONLY" = "true" ]; then
      echo "Dry run only, skip publishing."
    else
      if [ "$INPUT_FLUTTER" = "true" ]; then
        flutter pub publish -f
      else
        pub lish -f
      fi
    fi
  fi  
}

check_required_inputs
switch_working_directory
get_local_package_version || true
run_unit_tests
get_remote_package_version || true
publish || true
