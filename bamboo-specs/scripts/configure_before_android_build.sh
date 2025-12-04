#!/bin/bash

set -x -e

# Moving to a folder with scripts and move to the root directory
cd $(dirname $0)
cd ../..

android_root_dir="$1"
if [[ "${android_root_dir}" == "" ]]; then
  echo "The Android root directory path not specified"; exit 1
fi

# Configure project's dependencies
make .dart_tool/package_config.json

# Export Bamboo variables
export GPR_KEY="${bamboo_githubPublicRepoPassword}"
echo "gpr.key=${bamboo_githubPublicRepoPassword}" >> "${android_root_dir}/gradle.properties"

echo "${bamboo_keyStoreSecret}" | base64 --decode > "${android_root_dir}/trusttunnel.keystore"

echo "signingConfigKeyAlias=${bamboo_keyAliasSecret}" >> "${android_root_dir}/gradle.properties"
echo "signingConfigKeyPassword=${bamboo_keyPassword}" >> "${android_root_dir}/gradle.properties"
echo "signingConfigKeyStorePath=${android_root_dir}/trusttunnel.keystore" >> "${android_root_dir}/gradle.properties"
echo "signingConfigKeyStorePassword=${bamboo_storePassword}" >> "${android_root_dir}/gradle.properties"
