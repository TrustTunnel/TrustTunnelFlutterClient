#!/bin/bash

set -x -e

# Moving to a folder with scripts and move to the root directory
cd $(dirname $0)
cd ../..

build_type="$1"
if [ "$build_type" == "" ]; then
    echo "The build type not specified"; exit 1
fi

upload_symbols="$2"
if [ "$upload_symbols" == "" ]; then
    echo "The 'upload symbols' state not specified"; exit 1
fi


cd ios
bundle exec fastlane sync_certs_and_profiles type:"$build_type"
if [ "$build_type" != "appstore" ]; then
    echo "Build type is not 'appstore', so we need to download 'appstore' profiles to build an app, also."
    echo "That's an 'xcodebuild' command feature which is used by fastlane to build an app."
    bundle exec fastlane sync_certs_and_profiles type:appstore readonly:true
fi
cd ..

# Remove the GPR_KEY secret when native lib will be published
export GPR_KEY="${bamboo_githubPublicRepoPassword}"

make .dart_tool/build/entrypoint/build.dart

cd ios
bundle exec pod install # Let's install again to synchronize built files
bundle exec fastlane build_ipa type:"$build_type" upload_symbols:"$upload_symbols"
