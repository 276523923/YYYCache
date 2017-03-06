Pod::Spec.new do |s|

  s.name         = "YYYCache"
  s.version      = "1.0.0"
  s.summary      = "YYYCache"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.homepage     = "https://github.com/276523923/YYYTool.git"
  s.author             = { "yyy" => "276523923@qq.com" }

  s.description  = <<-DESC
YYYCache 网络缓存，根据YYCache修改，可以设定缓存时间。
                   DESC

  s.platform     = :ios, "8.0"
  s.ios.deployment_target = "8.0"

  s.source       = { :git => "https://github.com/276523923/YYYCache.git", :tag => s.version.to_s }
  s.requires_arc = true
  s.source_files  = "YYYCache/**/*.{m,h}"
  s.libraries = 'sqlite3'
  s.frameworks = 'UIKit', 'CoreFoundation', 'QuartzCore' 
end