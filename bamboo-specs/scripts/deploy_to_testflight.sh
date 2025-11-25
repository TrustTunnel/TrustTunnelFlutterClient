#!/bin/bash

set -x

project_dir="$1"
if [[ "${project_dir}" == "" ]]; then
  echo "The project directory path not specified"; exit 1
fi

submit_beta_review="$2"
if [[ "${submit_beta_review}" == "" ]]; then
  submit_beta_review="false"
fi 

# Moving to a folder with scripts and move to the root directory
cd $(dirname $0)
cd ../..



if grep -q "<html>" "${PWD}/changelog.txt"; then
    echo "The changelog.txt file contains an <html> tag. Let's replace it to the 'Minor fixes' phrase."
    echo "Minor fixes" > "${PWD}/changelog.txt"
fi

changelog_text=$(cat "${PWD}/changelog.txt")
echo "Welcome to TrustTunnel ${bamboo_data_version_title}!" > changelog.txt
echo "" >> "${PWD}/changelog.txt"
echo "" >> "${PWD}/changelog.txt"
echo "## Release notes" >> "${PWD}/changelog.txt"
echo "" >> "${PWD}/changelog.txt"
echo "$changelog_text" >> "${PWD}/changelog.txt"



echo "${bamboo_fastlaneAppStoreApiInfoSecret}" | base64 --decode > "${project_dir}/fastlane/AppStoreApiInfo.json"
echo "${bamboo_fastlaneEnvSecret}" | base64 --decode > "${project_dir}/fastlane/.env"

# Configure bundler
bundle config set --local path '.bundle/vendor'
bundle install
if [ $? -eq 1 ]; then exit 1; fi



bundle exec fastlane deploy_to_testflight changelog_path:"${PWD}/changelog.txt" track:"$bamboo_build_channel" distribute_external:"$bamboo_distribute_external" submit_beta_review:"$submit_beta_review"

exit $?
