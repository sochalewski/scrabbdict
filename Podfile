target 'Scrabbdict' do
  platform :ios, '13.0'
  
  use_frameworks!

  pod 'Firebase/Crashlytics'
  pod 'Firebase/Analytics'
  pod 'TinySwift'
  pod 'SwiftSpinner'
  pod 'RealmSwift'

  target 'ScrabbdictTests' do
    inherit! :search_paths
  end
end

target 'RealmDatabaseWizard' do
  platform :macos, '13.0'
  
  use_frameworks!

  pod 'RealmSwift'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['DEAD_CODE_STRIPPING'] = 'YES'
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
      config.build_settings.delete 'MACOSX_DEPLOYMENT_TARGET'
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ''
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    end
  end
end
