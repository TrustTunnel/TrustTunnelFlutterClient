#!/bin/bash

set -x

# Moving to a folder with scripts and move to the root directory
cd $(dirname $0)
cd ../..

build_channel="$1"
if [ "$build_channel" == "" ]; then
    echo "The build channel not specified"; exit 1
fi

project_dir="$2"
if [[ "${project_dir}" == "" ]]; then
  echo "The project directory path not specified"; exit 1
fi



# Configure build_channel in pubspec.yaml
normalized_build_channel="Release"
if [ "$build_channel" == "prenightly" ]; then
    normalized_build_channel="PreNightly"
elif [ "$build_channel" == "nightly" ]; then
    normalized_build_channel="Nightly"
elif [ "$build_channel" == "beta" ]; then
    normalized_build_channel="Beta"
elif [ "$build_channel" == "rc" ]; then
    normalized_build_channel="Rc"
fi

if grep -q '^build_channel:' pubspec.yaml; then
    sed -i '' "s/^build_channel:.*/build_channel: ${normalized_build_channel}/" pubspec.yaml
else
    echo "build_channel: ${normalized_build_channel}" >> pubspec.yaml
fi

# Remove the GPR_KEY secret when native lib will be published
export GPR_KEY="${bamboo_githubPublicRepoPassword}"

if [[ -z "$GPR_KEY" ]]; then
    echo "ERROR: GPR_KEY Bamboo secret is empty or not defined!"
    exit 1
fi

echo "${bamboo_fastlaneAppStoreApiInfoSecret}" | base64 --decode > "${project_dir}/ios/fastlane/AppStoreApiInfo.json"
echo "${bamboo_fastlaneEnvSecret}" | base64 --decode > "${project_dir}/ios/fastlane/.env"

# Configure project's dependencies
make .dart_tool/package_config.json

# Configure bundler
cd ios
bundle config set --local path '.bundle/vendor'
bundle install
if [ $? -eq 1 ]; then exit 1; fi


bundle exec pod install --repo-update
if [ $? -eq 1 ]; then exit 1; fi
