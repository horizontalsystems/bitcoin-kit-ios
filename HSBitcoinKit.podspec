Pod::Spec.new do |spec|
  spec.name = 'HSBitcoinKit'
  spec.version = '0.1.0'
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

  spec.dependency 'HSCryptoKit'
  spec.dependency 'HSHDWalletKit'
  spec.dependency 'Alamofire'
  spec.dependency 'ObjectMapper'
  spec.dependency 'RxSwift'
  spec.dependency 'BigInt'
  spec.dependency 'RealmSwift'
  spec.dependency 'RxRealm'
end
