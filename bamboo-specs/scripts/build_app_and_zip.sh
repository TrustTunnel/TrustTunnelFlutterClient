#!/bin/bash

set -x -e

# Moving to a folder with scripts and move to the root directory
cd $(dirname $0)
cd ../..

build_channel="$1"
if [[ "$build_channel" == "beta" ]] || [[ "$build_channel" == "rc" ]] || [[ "$build_channel" == "release" ]]; then
    echo "The build channel is correct, the posting to slack is allowed"
else
    echo "Unknown build channel: ${build_channel}. The building for simulator is not allowed"
    mkdir -p "build" && touch "build/TrustTunnel.app.zip" # Let's create an empty file for Bamboo artifact's publishing
    exit 0
fi

# Remove the GPR_KEY secret when native lib will be published
export GPR_KEY="${bamboo_githubPublicRepoPassword}"

make .dart_tool/build/entrypoint/build.dart

cd ios
bundle exec fastlane build_simulator_app_and_zip
