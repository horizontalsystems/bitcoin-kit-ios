Pod::Spec.new do |spec|
  spec.name = 'Hodler.swift'
  spec.module_name = 'Hodler'
  spec.version = '0.1.0'
  spec.summary = 'Hodler library for Swift'
  spec.description = <<-DESC
                       Hodler plugin enables to send/receive/spend time-locked transactions.
                       ```
                    DESC
  spec.homepage = 'https://github.com/horizontalsystems/bitcoin-kit-ios'
  spec.license = { :type => 'Apache 2.0', :file => 'LICENSE' }
  spec.author = { 'Horizontal Systems' => 'hsdao@protonmail.ch' }
  spec.social_media_url = 'http://horizontalsystems.io/'

  spec.requires_arc = true
  spec.source = { git: 'https://github.com/horizontalsystems/bitcoin-kit-ios.git', tag: "#{spec.version}" }
  spec.source_files = 'Hodler/Hodler/**/*.{h,m,mm,swift}'
  spec.ios.deployment_target = '11.0'
  spec.swift_version = '5'

  spec.dependency 'BitcoinCore.swift', '~> 0.9.0'
  spec.dependency 'HSCryptoKit', '~> 1.4'
end
