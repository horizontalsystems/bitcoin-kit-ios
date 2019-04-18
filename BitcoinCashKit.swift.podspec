Pod::Spec.new do |spec|
  spec.name = 'BitcoinCashKit'
  spec.version = '0.4.1'
  spec.summary = 'BitcoinCash wallet library for Swift'
  spec.description = <<-DESC
                       BitcoinCashKit implements BitcoinCash protocol in Swift. It is an implementation of the BitcoinCash SPV protocol written (almost) entirely in swift.
                       ```
                    DESC
  spec.homepage = 'https://github.com/horizontalsystems/bitcoin-kit-ios'
  spec.license = { :type => 'Apache 2.0', :file => 'LICENSE' }
  spec.author = { 'Horizontal Systems' => 'hsdao@protonmail.ch' }
  spec.social_media_url = 'http://horizontalsystems.io/'

  spec.requires_arc = true
  spec.source = { git: 'https://github.com/horizontalsystems/bitcoin-kit-ios.git', tag: "#{spec.version}" }
  spec.source_files = 'BitcoinCashKit/BitcoinCashKit/**/*.{h,m,swift}'
  spec.ios.deployment_target = '11.0'
  spec.swift_version = '4.2'

  spec.dependency 'BitcoinCore', '~> 0.4.1'
  spec.dependency 'HSCryptoKit', '~> 1.3.0'
  spec.dependency 'HSHDWalletKit', '~> 1.0.4'
  spec.dependency 'Alamofire', '~> 4.8.0'
  spec.dependency 'ObjectMapper', '~> 3.4.0'
  spec.dependency 'RxSwift', '~> 4.0'
  spec.dependency 'BigInt', '~> 3.1.0'
  spec.dependency 'GRDB.swift', '~> 3.6.2'
  spec.dependency 'RealmSwift', '~> 3.11.0'
  spec.dependency 'RxRealm', '~> 0.7.0'
end
