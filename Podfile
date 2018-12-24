platform :ios, '11.0'
use_frameworks!

inhibit_all_warnings!

workspace 'HSBitcoinKit'

project 'HSBitcoinKitDemo/HSBitcoinKitDemo'
project 'HSBitcoinKit/HSBitcoinKit'


def internal_pods
  pod 'HSCryptoKit', '~> 1.1.0'
  pod 'HSHDWalletKit', '~> 1.0.3'
end

def kit_pods
  internal_pods

  pod 'Alamofire', '~> 4.8.0'
  pod 'ObjectMapper', '~> 3.3.0'

  pod 'RxSwift', '~> 4.0'

  pod 'BigInt', '~> 3.1.0'
  pod 'RealmSwift', '~> 3.11.0'
  pod 'RxRealm', '~> 0.7.0'
end

target :HSBitcoinKitDemo do
  project 'HSBitcoinKitDemo/HSBitcoinKitDemo'
  kit_pods
end

target :HSBitcoinKit do
  project 'HSBitcoinKit/HSBitcoinKit'
  kit_pods
end

target :HSBitcoinKitTests do
  project 'HSBitcoinKit/HSBitcoinKit'

  internal_pods
  pod 'Cuckoo'
end
