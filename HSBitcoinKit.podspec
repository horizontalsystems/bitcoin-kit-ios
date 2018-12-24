Pod::Spec.new do |spec|
  spec.name = 'HSBitcoinKit'
  spec.version = '0.1.5'
  spec.summary = 'Bitcoin wallet library for Swift'
  spec.description = <<-DESC
                       HSBitcoinKit implements Bitcoin protocol in Swift. It is an implementation of the Bitcoin SPV protocol written (almost) entirely in swift.
                       ```
                    DESC
  spec.homepage = 'https://github.com/horizontalsystems/bitcoin-kit-ios'
  spec.license = { :type => 'Apache 2.0', :file => 'LICENSE' }
  spec.author = { 'Horizontal Systems' => 'hsdao@protonmail.ch' }
  spec.social_media_url = 'http://horizontalsystems.io/'

  spec.requires_arc = true
  spec.source = { git: 'https://github.com/horizontalsystems/bitcoin-kit-ios.git', tag: "#{spec.version}" }
  spec.source_files = 'HSBitcoinKit/HSBitcoinKit/**/*.{h,m,swift}'
  spec.ios.deployment_target = '11.0'
  spec.swift_version = '4.1'

  spec.dependency 'HSCryptoKit', '~> 1.1.0'
  spec.dependency 'HSHDWalletKit', '~> 1.0.3'
  spec.dependency 'Alamofire', '~> 4.8.0'
  spec.dependency 'ObjectMapper', '~> 3.3.0'
  spec.dependency 'RxSwift', '~> 4.0'
  spec.dependency 'BigInt', '~> 3.1.0'
  spec.dependency 'RealmSwift', '~> 3.11.0'
  spec.dependency 'RxRealm', '~> 0.7.0'
end
