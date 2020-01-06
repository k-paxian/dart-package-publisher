#!/bin/bash

set -e

ACCESS_TOKEN="$1"
REFRESH_TOKEN="$2"
PACKAGE="$3"
RELATIVE_PATH="$4"

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
  if [ -z "$PACKAGE" ]; then
    echo "Missing package name"
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
  DEPS_OUT=`pub deps`
  PACKAGE_INFO=`echo "$DEPS_OUT" | cut -d\n -f3`
  IFS=' '
  read -a parts <<< "$PACKAGE_INFO"
  echo "$parts"
  for val in "${parts[@]}";
  do
  printf "$val\n"
  done  
  #PACKAGE_META=`echo "$PACKAGE_INFO" | awk '/^.*$/{print $1}'`
  #PACKAGE_META2=`echo "$PACKAGE_INFO" | awk '/^.*$/{print $2}'`
  #echo "$PACKAGE_META"
  #echo "$PACKAGE_META2"
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
#publish
