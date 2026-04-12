target 'Scrabbdict' do
  platform :ios, '17.0'
  use_frameworks! :linkage => :static

  pod 'Firebase/Crashlytics'
  pod 'Firebase/Analytics'
  pod 'TinySwift'
  pod 'SwiftSpinner'

  target 'ScrabbdictTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.build_configurations.each do |config|
    config.build_settings.delete 'STRIP_INSTALLED_PRODUCT'
    config.build_settings.delete 'STRIP_STYLE'
    config.build_settings.delete 'STRIP_SWIFT_SYMBOLS'
    config.build_settings['DEAD_CODE_STRIPPING'] = 'YES'
    config.build_settings['LD_NO_PIE'] = 'NO'

    config.build_settings['GCC_C_LANGUAGE_STANDARD'] = 'gnu17'
    config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'gnu++20'
  end

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
      config.build_settings.delete 'MACOSX_DEPLOYMENT_TARGET'
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ''
      config.build_settings['CODE_SIGN_IDENTITY'] = ''
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    end
  end
end