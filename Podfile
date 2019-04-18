platform :ios, '11.0'
use_frameworks!

inhibit_all_warnings!

workspace 'BitcoinKit'

project 'Demo/Demo'
project 'BitcoinCore/BitcoinCore'
project 'BitcoinKit/BitcoinKit'
project 'BitcoinCashKit/BitcoinCashKit'
project 'DashKit/DashKit'

def internal_pods
  pod 'HSCryptoKit', '~> 1.0'
  pod 'HSHDWalletKit', '~> 1.0'
end

def kit_pods
  internal_pods

  pod 'Alamofire', '~> 4.0'
  pod 'ObjectMapper', '~> 3.0'

  pod 'RxSwift', '~> 4.0'

  pod 'BigInt', '~> 3.0'

  pod 'GRDB.swift', '~> 3.0'
end

target :BitcoinCore do
  project 'BitcoinCore/BitcoinCore'
  kit_pods
end

target :BitcoinKit do
    project 'BitcoinKit/BitcoinKit'
    kit_pods
end

target :BitcoinCashKit do
    project 'BitcoinCashKit/BitcoinCashKit'
    kit_pods
end

target :DashKit do
    project 'DashKit/DashKit'
    kit_pods

    pod 'HSCryptoX11', git: 'https://github.com/horizontalsystems/crypto-x11-ios'
end

target :Demo do
    project 'Demo/Demo'
    kit_pods

    pod 'HSCryptoX11', git: 'https://github.com/horizontalsystems/crypto-x11-ios'
end

def test_pods
  pod 'Quick'
  pod 'Nimble'
  pod 'Cuckoo'
  pod 'RxBlocking', '~> 4.0'
end

target :BitcoinCoreTests do
  project 'BitcoinCore/BitcoinCore'

  internal_pods
  test_pods
end

target :BitcoinKitTests do
    project 'BitcoinKit/BitcoinKit'
    
    internal_pods
    test_pods
end

target :BitcoinCashKitTests do
    project 'BitcoinCashKit/BitcoinCashKit'
    
    internal_pods
    test_pods
end

target :DashKitTests do
    project 'DashKit/DashKit'

    internal_pods
    test_pods

    pod 'HSCryptoX11', git: 'https://github.com/horizontalsystems/crypto-x11-ios'
end
