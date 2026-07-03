.PHONY: gen ln init release-android aux-setup-android-signing \
        ci-lint-dart ci-test-flutter \
        ci-build-android-apk ci-build-android-aab \
        ci-setup-ruby ci-setup-gpr \
        ci-fastlane-build-ipa ci-fastlane-build-simulator \
        ci-fastlane-build-ios ci-fastlane-build-ios-simulator \
        ci-setup-ruby-macos

gen:
	@echo "* Starting code generation... *"
	@dart run build_runner build --delete-conflicting-outputs
	@$(MAKE) -C plugins/vpn_plugin gen
	@echo "* Code generation successful *"

ln:
	@echo "* Generating localizations *"
	@dart run intl_utils:generate

init:
	@echo "* Running flutter clean *"
	@flutter clean
	@echo "* Getting latest dependencies *"
	@flutter pub get
	@echo "* Running build runner *"
	@dart run build_runner build --delete-conflicting-outputs
	@dart pub run intl_utils:generate
	@$(MAKE) -C plugins/vpn_plugin init

.dart_tool/package_config.json: pubspec.yaml pubspec.lock
	@echo "* Resolving dependencies... *"
	@flutter pub get 2>&1 | \
		grep -v 'untranslated message' | \
		grep -v 'To see a detailed report' | \
		grep -v 'untranslated-messages-file' | \
		grep -v 'This will generate' | cat
	@echo "* Dependencies resolved. *"

lib/common/localization/generated/l10n.dart: .dart_tool/package_config.json lib/common/localization/arb/*.arb
	@echo "* Generating localization... *"
	@dart run intl_utils:generate 2>&1 | \
		grep -v 'untranslated message' | \
		grep -v 'untranslated-messages-file' | \
		grep -v 'This will generate' | cat
	@flutter gen-l10n 2>&1 | \
		grep -v 'untranslated message' | \
		grep -v 'untranslated-messages-file' | \
		grep -v 'This will generate' | cat
	@echo "* Localization generated. *"

.dart_tool/build/entrypoint/build.dart: lib/common/localization/generated/l10n.dart
	@echo "* Starting code generation... *"
	@dart run build_runner build --delete-conflicting-outputs
	@$(MAKE) -C plugins/vpn_plugin gen
	@echo "* Code generation successful *"

aux-setup-android-signing:
	@echo "Enter password for Android keystore (will be used for keystore AND written to android/local.properties):"
	@read -s PASSWORD; echo ""; \
	echo "* Generating android/trusttunnel.keystore (alias: trusttunnel) *"; \
	mkdir -p android; \
	rm -f android/trusttunnel.keystore; \
	keytool -genkeypair -v \
		-keystore android/trusttunnel.keystore \
		-alias trusttunnel \
		-keyalg RSA \
		-keysize 2048 \
		-validity 10500 \
		-sigalg SHA256withRSA \
		-storepass $$PASSWORD \
		-keypass $$PASSWORD; \
	echo "* Updating android/local.properties (preserve other keys; replace signingConfigKey* only) *"; \
	touch android/local.properties; \
	grep -vE '^[[:space:]]*signingConfigKey(Alias|Password|StorePath|StorePassword)[[:space:]]*=' android/local.properties > android/local.properties.tmp || true; \
	mv android/local.properties.tmp android/local.properties; \
	printf "%s\n" \
		"signingConfigKeyAlias=trusttunnel" \
		"signingConfigKeyPassword=$$PASSWORD" \
		"signingConfigKeyStorePath=./trusttunnel.keystore" \
		"signingConfigKeyStorePassword=$$PASSWORD" \
		>> android/local.properties; \
	echo "* Android signing setup done. *"

release-android:
	@echo "* Building Android release (AAB) *"
	@flutter build appbundle --release
	@echo "* Android release build done *"

ci-lint-dart:
	@echo "* Running flutter analyze *"
	@flutter analyze
	@echo "* Lint OK *"

ci-test-flutter:
	@echo "* Running flutter test *"
	@flutter test
	@echo "* Tests OK *"

ci-setup-gpr:
	@if [ -z "$$GPR_KEY" ]; then \
		echo "ERROR: GPR_KEY env var is not set"; exit 1; \
	fi
	@echo "* GPR_KEY is set *"

ci-setup-ruby:
	@echo "* Setting up Ruby gems (ios/) *"
	@cd ios && bundle config set --local path '.bundle/vendor' && bundle install
	@echo "* Ruby setup done *"

ci-setup-ruby-macos:
	@echo "* Setting up Ruby gems (macos/) *"
	@cd macos && bundle config set --local path '.bundle/vendor' && bundle install
	@echo "* Ruby setup done *"

ci-build-android-apk: .dart_tool/build/entrypoint/build.dart
	@if [ -z "$$PROJECT_VERSION" ]; then \
		echo "ERROR: PROJECT_VERSION env var is not set"; exit 1; \
	fi
	@if [ -z "$$BUILD_NUMBER" ]; then \
		echo "ERROR: BUILD_NUMBER env var is not set"; exit 1; \
	fi
	@echo "* Building Android APK (release) *"
	@flutter build apk --release \
		--build-name=$$PROJECT_VERSION \
		--build-number=$$BUILD_NUMBER
	@echo "* Android APK build done *"

ci-build-android-aab: .dart_tool/build/entrypoint/build.dart
	@if [ -z "$$PROJECT_VERSION" ]; then \
		echo "ERROR: PROJECT_VERSION env var is not set"; exit 1; \
	fi
	@if [ -z "$$BUILD_NUMBER" ]; then \
		echo "ERROR: BUILD_NUMBER env var is not set"; exit 1; \
	fi
	@echo "* Building Android AAB (release) *"
	@flutter build appbundle --release \
		--build-name=$$PROJECT_VERSION \
		--build-number=$$BUILD_NUMBER
	@echo "* Android AAB build done *"

ci-fastlane-build-ipa: ci-setup-gpr ci-setup-ruby
	@echo "* Building iOS IPA via fastlane *"
	@cd ios && bundle exec fastlane build_ipa type:"$${BUILD_TYPE:-adhoc}"
	@echo "* iOS IPA build done *"

ci-fastlane-build-simulator: ci-setup-gpr ci-setup-ruby
	@echo "* Building iOS Simulator app via fastlane *"
	@cd ios && bundle exec fastlane build_simulator_app_and_zip
	@echo "* iOS Simulator build done *"

ci-fastlane-build-ios: ci-fastlane-build-ipa

ci-fastlane-build-ios-simulator: ci-fastlane-build-simulator

ci-fastlane-build-macos: ci-setup-gpr ci-setup-ruby-macos
	@echo "* Building macOS app via fastlane *"
	@cd macos && bundle exec fastlane build_and_package type:"$${BUILD_TYPE:-developer_id}"
	@echo "* macOS build done *"