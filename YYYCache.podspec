#
# Be sure to run `pod lib lint YYYCache.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'YYYCache'
  s.version          = '0.1.0'
  s.summary          = 'A short description of YYYCache.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
YYYCache 缓存，根据YYCache修改，可以设定缓存时间。
                       DESC

  s.homepage         = 'https://gitee.com/yyyue/YYYCache.git'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '276523923@qq.com' => 'yyyue@vip.qq.com' }
  s.source           = { :git => 'https://gitee.com/yyyue/YYYCache.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'YYYCache/Classes/**/*'
  s.libraries = 'sqlite3'
  s.frameworks = 'UIKit', 'CoreFoundation', 'QuartzCore'

  # s.resource_bundles = {
  #   'YYYCache' => ['YYYCache/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
