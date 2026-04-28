# Relative path: partnersdk_demo_ios/app/libs/PartnerSDKBinary.podspec

Pod::Spec.new do |s|
  s.name             = "PartnerSDKBinary"
  s.version          = "1.0.0"
  s.summary          = "Binary wrapper for partnersdk_ios xcframework"
  s.description      = "Distributes partnersdk_ios.xcframework for demo integration."
  s.homepage         = "https://example.local/partnersdk"
  s.license          = { :type => "Commercial", :text => "Proprietary" }
  s.author           = { "Squady" => "dev@squady.app" }
  s.platform         = :ios, "13.0"
  s.swift_version    = "5.9"
  s.source           = { :path => "." }

  s.vendored_frameworks = "partnersdk_ios.xcframework"
  s.dependency "LiveKitClient"
end
