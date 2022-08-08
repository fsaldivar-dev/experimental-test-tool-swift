Pod::Spec.new do |s|
  s.name             = 'SpockSwift'
  s.version          = '0.0.1'
  s.summary          = 'Libreria para agulizar el desarrollo de pruebas'
  s.homepage         = 'https://github.com/fsaldivar-dev/experimental-test-tool-swift'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = 'Francisco Javier Saldivar Rubio'
  s.source           = { :git => 'https://github.com/fsaldivar-dev/experimental-test-tool-swift.git', :tag => s.version.to_s }
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'
  s.source_files = 'Sources/**/*'
  
  s.test_spec 'Tests' do |test_spec|
      test_spec.source_files = 'Tests/**/*'
  end
  
  s.subspec 'SpockDummy' do |sp|
      sp.source_files = 'Sources/SpockDummy/**'
      
      sp.test_spec do |test_subspec|
          test_subspec.source_files = 'Tests/SpockDummy/**/*'
      end
  end
end
