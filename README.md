# BitcoinKit-iOS

Bitcoin and Bitcoin Cash protocols SPV wallet toolkit for Swift

## Usage

### Initialization

`BitcoinKit` requires you to provide mnemonic phrase when it is initialized:

```swift
let words = ["word1", ... , "word12"]
```

#### Bitcoin

```swift
let bitcoinKit = BitcoinKit(withWords: words, coin: .bitcoin(network: .testNet), minLogLevel: .verbose)
```

#### Bitcoin Cash

```swift
let bitcoinCashKit = BitcoinKit(withWords: words, coin: .bitcoinCash(network: .testNet), minLogLevel: .verbose)
```

Both networks can be configured to work in `mainNet` or `testNet`.

Also `minLogLevel` can be configured for debug purposes if required.

### Starting and Stopping

`BitcoinKit` requires to be started with `start` command, but does not need to be stopped. It will be in synced state as long as it is possible:

```swift
try bitcoinKit.start()
```

#### Clearing data from device

`BitcoinKit` uses internal databse for storing data fetched from blockchain. In order to clean all stored data, `clear` command should be called:

```swift
try bitcoinKit.clear()
```


### Getting Data

`BitcoinKit` can return any required synced data for its blockchain

#### Current Balance

Balance is provided in `Satoshi`:

```swift
bitcoinKit.balance
```

#### Last Block Info

Last block info contains `headerHash`, `height` and `timestamp` that can be used for displaying sync info to user:

```swift
bitcoinKit.lastBlockInfo
```

## Requirements

* Xcode 10.0
* Swift 4.1
* iOS 11

## Installation

### [CocoaPods](https://guides.cocoapods.org/using/using-cocoapods.html)

```ruby
pod 'HSBitcoinKit'
```

### Example Project

All features of the library are used in example project. It can be referred as a starting point for usage of the library.

* [Example Project](https://github.com/horizontalsystems/bitcoin-kit-ios/tree/master/HSBitcoinKitDemo)

## Dependencies

* [HSHDWalletKit](https://github.com/horizontalsystems/hd-wallet-kit-ios) - HD Wallet related features, mnemonic phrase geneartion.
* [HSCryptoKit](https://github.com/horizontalsystems/crypto-kit-ios) - Crypto functions required for working with blockchain.
