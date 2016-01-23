# Uncomment this line to define a global platform for your project
# platform :ios, '6.0'

target 'SwiftAnyPic' do

use_frameworks!
pod 'Parse', '~> 1.7.5'
pod 'ParseFacebookUtils', '~> 1.7.5'
pod 'ParseCrashReporting', '~> 1.7.5'
# Workaround for the unknown crashes Bolts (https://github.com/BoltsFramework/Bolts-iOS/issues/102)
pod 'Bolts', :git => 'https://github.com/kwkhaw/Bolts-iOS.git'
pod 'ParseUI', '1.1.4'
pod 'MBProgressHUD', '~> 0.9.1'
pod 'FormatterKit', '~> 1.8.0'
pod 'UIImageEffects', '~> 0.0.1'
pod 'UIImageAFAdditions', :git => 'https://github.com/teklabs/UIImageAFAdditions.git'
pod 'Synchronized', '~> 2.0.0'

end

target 'SwiftAnyPicTests' do

end

target 'SwiftAnyPicUITests' do

end

# Disable bitcode for now.
post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['ENABLE_BITCODE'] = 'NO'
        end
    end
end
