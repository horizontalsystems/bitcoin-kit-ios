Pod::Spec.new do |s|
  s.name             = 'BitcoinCashKit.swift'
  s.module_name      = 'BitcoinCashKit'
  s.version          = '0.12.2'
  s.summary          = 'BitcoinCash library for Swift.'

  s.description      = <<-DESC
BitcoinCashKit implements BitcoinCash protocol in Swift. It is an implementation of the BitcoinCash SPV protocol written (almost) entirely in swift.
                       DESC

  s.homepage         = 'https://github.com/horizontalsystems/bitcoin-kit-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Horizontal Systems' => 'hsdao@protonmail.ch' }
  s.source           = { git: 'https://github.com/horizontalsystems/bitcoin-kit-ios.git', tag: "bitcoin-cash-#{s.version}" }
  s.social_media_url = 'http://horizontalsystems.io/'

  s.ios.deployment_target = '11.0'
  s.swift_version = '5'

  s.source_files = 'BitcoinCashKit/Classes/**/*'
  s.resource_bundle = { 'Checkpoints' => 'BitcoinCashKit/Assets/Checkpoints/*' }

  s.requires_arc = true

  s.dependency 'BitcoinCore.swift', '~> 0.12.2'
  s.dependency 'OpenSslKit.swift', '~> 1.0'
  s.dependency 'Secp256k1Kit.swift', '~> 1.0'
  s.dependency 'HdWalletKit.swift', '~> 1.4'

  s.dependency 'Alamofire', '~> 4.0'
  s.dependency 'ObjectMapper', '~> 3.0'
  s.dependency 'RxSwift', '~> 5.0'
  s.dependency 'BigInt', '~> 5.0'
  s.dependency 'GRDB.swift', '~> 4.0'
end
