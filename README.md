# kin-ecosystem-ios-sample-app

This app showcases the use of the [Kin Ecosystem iOS SDK](https://github.com/kinfoundation/kin-ecosystem-ios-sdk).

## Installation
1. Clone the repo
2. Clone the repo [Kin Ecosystem iOS SDK](https://github.com/kinecosystem/kin-ecosystem-ios-sdk)
3. Run `pod install`

## Usage
The sample app can authenticate with the kin ecosystem using one of two ways:
1. [JWT](http://jwt.io)
2. An app id and developer key</br>

For this sample app, a default credentials plist is provided (`defaultConfig.plist`) which uses test credentials environment with both options available.

> Note: the private key used in the credentials plist is for test purposes only.</br>
You should definitely keep your production private key in a safer and more secure place.

### Disclaimer
> This is a very minimal app designed just to launch the Kin Marketplace and allow interacting with all of Kin SDK's appearance on hosting apps. It is maintained from time to time, but at a low priority.
</br>For more info on using the actual SDK in your own app, go to [Kin Ecosystem iOS SDK](https://github.com/kinfoundation/kin-ecosystem-ios-sdk).
