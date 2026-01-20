Pod::Spec.new do |s|
  s.name             = 'webrtc_apm'
  s.version          = '0.0.1'
  s.summary          = 'WebRTC Audio Processing Module for Flutter'
  s.description      = <<-DESC
WebRTC APM provides software-based AEC, NS, and AGC for audio processing.
                       DESC
  s.homepage         = 'https://github.com/anthropics/ai-bookkeeping'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Anthropic' => 'support@anthropic.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
