#
# Be sure to run `pod lib lint DtexCamera.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DtexCamera'
  s.version          = '0.0.5'
  s.summary          = 'Dtex Camera Library'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/DTexDDC/dtexg3-ios-camera-library'
  s.readme           = 'https://github.com/DTexDDC/dtexg3-ios-camera-library/blob/main/README.md'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'wenge8n' => 'wenge8n@outlook.com' }
  s.source           = { :git => 'https://github.com/DTexDDC/dtexg3-ios-camera-library.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'
  s.swift_version = '4.0'

  s.ios.deployment_target = '12.0'

  s.source_files = 'DtexCamera/Classes/**/*'
  
  # s.resource_bundles = {
  #   'DtexCamera' => ['DtexCamera/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  s.static_framework = true
  
  s.dependency "TensorFlowLiteSwift"
end
