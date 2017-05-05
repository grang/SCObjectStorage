Pod::Spec.new do |s|
s.name = 'SCObjectStorage'
s.version = '0.0.1'
s.license = 'MIT'
s.summary = 'The iOS SDK of SpeedyCloud ObjectStorage'
s.homepage = 'https://github.com/grang/SCObjectStorage.git'
s.authors = { 'grang' => 'alex.huang.guo@gmail.com' }
s.source = { :git => 'https://github.com/grang/SCObjectStorage.git', :tag => s.version.to_s }
s.requires_arc = true
s.ios.deployment_target = '9.0'
s.source_files = 'SCObjectStorage/*.{h,m}'
s.resources = ''
end