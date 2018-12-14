platform :ios, '11.0'
use_frameworks!

inhibit_all_warnings!

workspace 'HSBitcoinKit'

project 'HSBitcoinKitDemo/HSBitcoinKitDemo'
project 'HSBitcoinKit/HSBitcoinKit'


def internal_pods
  pod 'HSCryptoKit'
  pod 'HSHDWalletKit', '~> 1.0.1'
end

def kit_pods
  internal_pods

  pod 'Alamofire'
  pod 'ObjectMapper'

  pod 'RxSwift'

  pod 'BigInt'
  pod 'RealmSwift'
  pod 'RxRealm'
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
