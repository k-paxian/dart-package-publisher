#!/bin/sh -l

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

publish() {
  echo "Publish dart package to Pub"
  pub publish --dry-run
  pub publish -f
}

check_inputs
switch_working_directory
