Pod::Spec.new do |s|
  s.name             = 'remove_video_metadata'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin that strips selected metadata from video files without re-encoding.'
  s.description      = <<-DESC
Removes location and creation timestamp metadata from video assets on iOS using AVFoundation.
  DESC
  s.homepage         = 'https://github.com/example/remove_video_metadata'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'remove_video_metadata developers' => 'hello@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'
  s.static_framework = true
end
