Pod::Spec.new do |s|
  s.name             = 'BitcoinCore.swift'
  s.module_name      = 'BitcoinCore'
  s.version          = '0.18'
  s.summary          = 'Core library Bitcoin derived wallets for Swift.'

  s.description      = <<-DESC
BitcoinCore implements Bitcoin core protocol in Swift. It is an implementation of the Bitcoin SPV protocol written (almost) entirely in swift.
                       DESC

  s.homepage         = 'https://github.com/horizontalsystems/bitcoin-kit-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Horizontal Systems' => 'hsdao@protonmail.ch' }
  s.source           = { git: 'https://github.com/horizontalsystems/bitcoin-kit-ios.git', tag: "bitcoin-core-#{s.version}" }
  s.social_media_url = 'http://horizontalsystems.io/'

  s.ios.deployment_target = '13.0'
  s.swift_version = '5'

  s.source_files = 'BitcoinCore/Classes/**/*'

  s.requires_arc = true

  s.dependency 'OpenSslKit.swift', '~> 1.0'
  s.dependency 'Secp256k1Kit.swift', '~> 1.0'
  s.dependency 'HdWalletKit.swift', '~> 1.5'
  s.dependency 'HsToolKit.swift', '~> 1.3'
  s.dependency 'UIExtensions.swift', '~> 1.1.1'

  s.dependency 'ObjectMapper', '~> 4.0'
  s.dependency 'RxSwift', '~> 5.0'
  s.dependency 'BigInt', '~> 5.0'
  s.dependency 'GRDB.swift', '~> 5.0'
  s.dependency 'SwiftNIO', '~> 2'
end
