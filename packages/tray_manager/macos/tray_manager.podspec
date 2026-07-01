#
# Run `pod lib lint tray_manager.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'tray_manager'
  s.version          = '0.1.0'
  s.summary          = 'TrustTunnel macOS status bar tray plugin.'
  s.description      = <<-DESC
Provides the native macOS status bar tray implementation for TrustTunnel.
                       DESC
  # These are required by CocoaPods but intentionally carry no contact details.
  s.homepage         = 'https://localhost'
  s.license          = { :type => 'UNLICENSED' }
  s.authors          = { '' => '' }

  s.source = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.resource_bundles = { 'tray_manager_privacy' => ['Resources/PrivacyInfo.xcprivacy'] }

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '15.5'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
