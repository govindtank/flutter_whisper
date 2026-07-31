Pod::Spec.new do |s|
  s.name             = 'flutter_whisper'
  s.version          = '0.1.0'
  s.summary          = 'On-device speech-to-text using whisper.cpp'
  s.description      = <<-DESC
On-device speech-to-text transcription using whisper.cpp.
Automatic model download, streaming results, iOS/Android support.
                       DESC
  s.homepage         = 'https://github.com/govindtank/flutter_whisper'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Govind Tank' => 'govindtank600@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.static_framework = true
  # whisper.cpp would be included as a static framework
  # s.vendored_frameworks = 'Frameworks/whisper.framework'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end