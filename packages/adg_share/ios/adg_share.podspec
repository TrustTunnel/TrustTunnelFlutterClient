Pod::Spec.new do |s|
  s.name             = 'adg_share'
  s.version          = '0.0.1'
  s.summary          = 'Native sharing plugin for Flutter on Android and iOS.'
  s.description      = <<-DESC
Native sharing plugin for Flutter on Android and iOS.
                       DESC
  s.homepage         = 'https://github.com/AdguardTeam/adguard-mail'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'AdGuard' => 'devnull@adguard.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
