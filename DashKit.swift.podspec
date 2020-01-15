Pod::Spec.new do |s|
  s.name             = 'DashKit.swift'
  s.module_name      = 'DashKit'
  s.version          = '0.13.3'
  s.summary          = 'Dash library for Swift.'

  s.description      = <<-DESC
DashKit implements Dash protocol in Swift.
                       DESC

  s.homepage         = 'https://github.com/horizontalsystems/bitcoin-kit-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Horizontal Systems' => 'hsdao@protonmail.ch' }
  s.source           = { git: 'https://github.com/horizontalsystems/bitcoin-kit-ios.git', tag: "dash-#{s.version}" }
  s.social_media_url = 'http://horizontalsystems.io/'

  s.ios.deployment_target = '11.0'
  s.swift_version = '5'

  s.source_files = 'DashKit/Classes/**/*'
  s.resource_bundle = { 'DashKit' => 'DashKit/Assets/Checkpoints/*' }

  s.requires_arc = true

  s.dependency 'BitcoinCore.swift', '~> 0.13.2'
  s.dependency 'OpenSslKit.swift', '~> 1.0'
  s.dependency 'Secp256k1Kit.swift', '~> 1.0'
  s.dependency 'BlsKit.swift', '~> 1.0'
  s.dependency 'X11Kit.swift', '~> 1.0'
  s.dependency 'HdWalletKit.swift', '~> 1.4'

  s.dependency 'Alamofire', '~> 4.0'
  s.dependency 'ObjectMapper', '~> 3.0'
  s.dependency 'RxSwift', '~> 5.0'
  s.dependency 'BigInt', '~> 5.0'
  s.dependency 'GRDB.swift', '~> 4.0'
end
