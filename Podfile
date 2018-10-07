platform :ios, '11.0'
use_frameworks!

inhibit_all_warnings!

workspace 'Example'

project 'Example/Example'
project 'WalletKit/WalletKit'


def crypto_pods
  pod "CryptoKit", git: "https://github.com/horizontalsystems/crypto-kit-ios"
end

def kit_pods
  crypto_pods

  pod 'Alamofire'
  pod 'ObjectMapper'

  pod 'RxSwift'

  pod 'BigInt'
  pod 'RealmSwift'
  pod "RxRealm"
end

target :Example do
  project 'Example/Example'
  kit_pods
end

target :WalletKit do
  project 'WalletKit/WalletKit'
  kit_pods
end

target :WalletKitTests do
  project 'WalletKit/WalletKit'

  crypto_pods
  pod "Cuckoo"
end
