#!/bin/bash

set -e

ACCESS_TOKEN="$1"
REFRESH_TOKEN="$2"
RELATIVE_PATH="$3"

check_inputs() {
  echo "Check inputs..."
  if [ -z "$ACCESS_TOKEN" ]; then
    echo "Missing accessToken"
    exit 1
  fi
  if [ -z "$REFRESH_TOKEN" ]; then
    echo "Missing refreshToken"
    exit 1
  fi
  echo "OK"
}

switch_working_directory() {
  echo "Switching to package directory '$RELATIVE_PATH'"
  cd "$RELATIVE_PATH"
}

get_local_package_version() {
  pub get
  OUT=`pub deps`
  PACKAGE_INFO=`echo "$OUT" | cut -d\n -f3`
  IFS=$'\n\r' read -d '' -r -a lines <<< "$PACKAGE_INFO"
  lastIndex=`expr ${#lines[@]}-1`
  PACKAGE_INFO="${lines[$lastIndex]}"
  PACKAGE=`echo "$PACKAGE_INFO" | cut -d' ' -f1`
  LOCAL_PACKAGE_VERSION=`echo "$PACKAGE_INFO" | cut -d' ' -f2`
  echo "Package: $PACKAGE"
  echo "Local version: $LOCAL_PACKAGE_VERSION"
}

get_remote_package_version() {
  REMOTE_PACKAGE_VERSION=""
  OUT=`pub global activate pana`
  V=`echo "$OUT" | perl -n -e'/^Activated .* (.*)\./ && print $1'`
  echo "version: $V"
  echo "Remote version: $REMOTE_PACKAGE_VERSION"
}

publish() {
  echo "Publish dart package to Pub"
  mkdir -p ~/.pub-cache
  cat <<-EOF > ~/.pub-cache/credentials.json
  {
    "accessToken":"$ACCESS_TOKEN",
    "refreshToken":"$REFRESH_TOKEN",
    "tokenEndpoint":"https://accounts.google.com/o/oauth2/token",
    "scopes": [ "openid", "https://www.googleapis.com/auth/userinfo.email" ],
    "expiration": 1577149838000
  }
EOF
  pub publish --dry-run
  pub lish -f  
}

check_inputs
switch_working_directory
get_local_package_version || true
get_remote_package_version || true
#publish
