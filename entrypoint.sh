#!/bin/bash

set -e

export PATH="$PATH":"$HOME/.pub-cache/bin"

check_inputs() {
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
  echo "Switching to package directory '$INPUT_RELATIVEPATH'"
  cd "$INPUT_RELATIVEPATH"
  echo "Package dir: $PWD"
}

get_local_package_version() {
  if [ "$INPUT_FLUTTER" = "true" ]; then
    GET=`flutter pub get`
  else
    GET=`pub get`
  fi
  HAS_BUILD_RUNNER=`echo "$GET" | perl -n -e'/^\+ build_runner (.*)/ && print $1'`
  HAS_BUILD_TEST=`echo "$GET" | perl -n -e'/^\+ build_test (.*)/ && print $1'`
  HAS_TEST=`echo "$GET" | perl -n -e'/^\+ test (.*)/ && print $1'`

  if [ "$INPUT_FLUTTER" = "true" ]; then
    OUT=`flutter pub deps`
  else
    OUT=`pub deps`
  fi

  PACKAGE_INFO=`echo "$OUT" | cut -d'|' -f1 | cut -d"'" -f1 | sed '/^\s*$/d'`
  IFS=$'\n\r' read -d '' -r -a lines <<< "$PACKAGE_INFO"
  lastIndex=`expr ${#lines[@]}-1`
  PACKAGE_INFO="${lines[$lastIndex]}"  
  PACKAGE=`echo "$PACKAGE_INFO" | cut -d' ' -f1`  
  LOCAL_PACKAGE_VERSION=`echo "$PACKAGE_INFO" | cut -d' ' -f2`  
  echo "Package: $PACKAGE"
  echo "Local version: [$LOCAL_PACKAGE_VERSION]"
  if [ -z "$PACKAGE" ]; then
    echo "No package found. :("
    exit 0
  fi  
  echo "::set-output name=package::$PACKAGE"
  echo "::set-output name=localVersion::$LOCAL_PACKAGE_VERSION"
}

run_unit_tests() {
    if [ "$INPUT_SKIPTESTS" = "true" ]; then
      echo "Skip unit tests set to true, skip unit testing."
    else
      echo "br = $HAS_BUILD_RUNNER"
      echo "bt = $HAS_BUILD_TEST"
      echo "su = $INPUT_SUPPRESSBUILDRUNNER"
      if [ "$HAS_BUILD_RUNNER" != "" ] && [ "$HAS_BUILD_TEST" != "" ] && [ "$INPUT_SUPPRESSBUILDRUNNER" != "true" ]; then
        echo "build_runner: $HAS_BUILD_RUNNER"
        echo "build_test: $HAS_BUILD_TEST"
        if [ "$INPUT_FLUTTER" = "true" ]; then
          flutter pub run build_runner test
        else
          pub run build_runner test
        fi
      else
        if [ "$HAS_TEST" != "" ]; then
          if [ "$INPUT_FLUTTER" = "true" ]; then
            flutter pub run test
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
    OUT=`flutter pub global activate $PACKAGE`
  else
    OUT=`pub global activate $PACKAGE`
  fi
  REMOTE_PACKAGE_VERSION=`echo "$OUT" | perl -n -e'/^Activated .* (.*)\./ && print $1'`
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
      pub publish --dry-run
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

check_inputs
switch_working_directory
get_local_package_version || true
run_unit_tests
get_remote_package_version || true
publish || true
