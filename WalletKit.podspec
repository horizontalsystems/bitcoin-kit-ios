Pod::Spec.new do |spec|
  spec.name = 'WalletKit'
  spec.version = '0.1.0'
  spec.summary = 'Bitcoin wallet library for Swift'
  spec.description = <<-DESC
                       WalletKit implements Bitcoin protocol in Swift. It is an implementation of the Bitcoin SPV protocol written (almost) entirely in swift.
                       ```
                    DESC
  spec.homepage = 'https://github.com/horizontalsystems/WalletKit-iOS'
  spec.license = { :type => 'Apache 2.0', :file => 'LICENSE' }
  spec.author = { 'Horizontal Systems' => 'grouvilimited@gmail.com' }
  spec.social_media_url = 'http://horizontalsystems.io/'

  spec.requires_arc = true
  spec.source = { git: 'https://github.com/horizontalsystems/WalletKit-iOS.git', tag: "v#{spec.version}" }
  spec.source_files = 'WalletKit/WalletKit/**/*.{h,m,swift}'
  spec.private_header_files = 'WalletKit/WalletKit/**/WalletKitInternal.h'
  spec.module_map = 'WalletKit/WalletKit/WalletKit.modulemap'
  spec.ios.deployment_target = '11.0'
  spec.swift_version = '4.1'

  spec.pod_target_xcconfig = { 'SWIFT_WHOLE_MODULE_OPTIMIZATION' => 'YES',
                               'APPLICATION_EXTENSION_API_ONLY' => 'YES',
                               'SWIFT_INCLUDE_PATHS' => '${PODS_ROOT}/WalletKit/WalletKit/Libraries',
                               'HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/WalletKit/WalletKit/Libraries/openssl/include" "${PODS_ROOT}/WalletKit/WalletKit/Libraries/secp256k1/include"',
                               'LIBRARY_SEARCH_PATHS' => '"${PODS_ROOT}/WalletKit/WalletKit/Libraries/openssl/lib" "${PODS_ROOT}/WalletKit/WalletKit/Libraries/secp256k1/lib"' }
  spec.preserve_paths = ['WalletKit/setup', 'WalletKit/Libraries']
  # spec.prepare_command = 'sh WalletKit/setup/build_libraries.sh'

  spec.dependency 'Alamofire'
  spec.dependency 'ObjectMapper'
  spec.dependency 'RxSwift'
  spec.dependency 'BigInt'
  spec.dependency 'RealmSwift'
  spec.dependency 'RxRealm'
end
