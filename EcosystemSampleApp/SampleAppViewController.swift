//
//  ViewController.swift
//  EcosystemSampleApp
//
//  Created by Elazar Yifrach on 14/02/2018.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import UIKit
import KinEcosystem
import JWT

class SampleAppViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var currentUserLabel: UILabel!
    @IBOutlet weak var loginOutButton: UIButton!
    @IBOutlet weak var externalIndicator: UIActivityIndicatorView!
    @IBOutlet weak var buyStickerButton: UIButton!
    @IBOutlet weak var getKinButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var payButton: UIButton!
    
    let environment: Environment = .beta
    let kid = "rs512_0"
    
    var appKey: String? {
        return configValue(for: "appKey", of: String.self)
    }
    
    var appId: String? {
        return configValue(for: "appId", of: String.self)
    }
    
    var privateKey: String? {
        return configValue(for: "RS512_PRIVATE_KEY", of: String.self)
    }
    
    var lastUser: String? {
        get {
            if let user = UserDefaults.standard.string(forKey: "SALastUser") {
                return user
            }
            return nil
        }
    }
    
    lazy var deviceId: String = {
        var identifier: String
        if let vendorIdentifier = UIDevice.current.identifierForVendor?.uuidString {
            identifier = vendorIdentifier
        } else if let uuid = UserDefaults.standard.string(forKey: "sampleAppDeviceIdentifier") {
            identifier = uuid
        } else {
            let uuid = UUID().uuidString
            UserDefaults.standard.set(uuid, forKey: "sampleAppDeviceIdentifier")
            identifier = uuid
        }
        return identifier
    }()
    
    func configValue<T>(for key: String, of type: T.Type) -> T? {
        if  let path = Bundle.main.path(forResource: "defaultConfig", ofType: "plist"),
            let value = NSDictionary(contentsOfFile: path)?[key] as? T {
            return value
        }
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        titleLabel.text = "\(version) (\(build))"
        _ = Kin.shared.addBalanceObserver { balance in
            DispatchQueue.main.async {
                self.balanceLabel.text = "\(balance.amount) K"
            }
        }
        startKin()
        Kin.shared.orderConfirmation(for: "NSOffer_01") { status, error in
            if let s = status, case let .completed(jwt) = s {
                print("order complete. jwt confirmation is: \(jwt)")
            } else {
                // handle errors
            }
        }
    }
    
    func alertConfigIssue() {
        presentAlert("Config Missing", body: "an app id and app key (or a jwt) is required in order to use the sample app. Please refer to the readme in the sample app repo for more information")
    }
    
    @IBAction func loginOutButtonTapped(_ sender: Any) {
        Kin.shared.logout()
        currentUserLabel.text = nil
        loginOutButton.setTitle("Login", for: .normal)
        UserDefaults.standard.removeObject(forKey: "SALastUser")
        presentLogin(animated: true)
    }
    
    @IBAction func continueTapped(_ sender: Any) {
        try? Kin.shared.launchEcosystem(from: self)
    }
    
    func startKin() {
        
        do {
            try jwtLogin()
        } catch {
            alertStartError(error)
        }
        let sOffer = NativeOffer(id: "NSOffer_01",
                                title: "Buy this!",
                                description: "It's amazing",
                                amount: 1000,
                                image: "https://s3.amazonaws.com/assets.kinecosystembeta.com/images/spend_test.png",
                                offerType: .spend,
                                isModal: true)
        let eOffer = NativeOffer(id: "NEOffer_01",
                                 title: "Get Kin!",
                                 description: "It's Free!",
                                 amount: 10,
                                 image: "https://s3.amazonaws.com/assets.kinecosystembeta.com/images/native_earn_padding.png",
                                 offerType: .earn,
                                 isModal: true)
        do {
            try Kin.shared.add(nativeOffer: sOffer)
            try Kin.shared.add(nativeOffer: eOffer)
        } catch {
            print("failed to add native offer, error: \(error)")
        }
        Kin.shared.nativeOfferHandler = { offer in
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Native Offer", message: "You tapped a native offer and the handler was invoked.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: { [weak alert] action in
                    alert?.dismiss(animated: true, completion: nil)
                }))
                
                let presentor = self.presentedViewController ?? self
                presentor.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func presentLogin(animated: Bool) {
        let pt = self.storyboard!.instantiateViewController(withIdentifier: "TargetUserViewController") as! TargetUserViewController
        pt.title = "Login"
        pt.selectBlock = { [weak self] userId in
            guard let this = self else { return }
            //self?.currentUserLabel.text = lastUser
            defer {
                this.setActionRunning(true)
                UserDefaults.standard.set(userId, forKey: "SALastUser")
                try? this.jwtLogin() { error in
                    this.setActionRunning(false)
                    if let e = error {
                        this.presentAlert("Login failed", body: "error: \(e.localizedDescription)")
                    }
                }
            }
            this.dismiss(animated: true)
        }
        let nc = UINavigationController(rootViewController: pt)
        self.present(nc, animated: animated)
    }
    
    func jwtLogin(callback: KinLoginCallback? = nil) throws {
        
        guard let user = lastUser else {
            loginOutButton.setTitle("Login", for: .normal)
            presentLogin(animated: true)
            return
        }
        
        
        guard   let jwtPKey = privateKey,
                let id = appId else {
            alertConfigIssue()
            return
        }
        
        guard let encoded = JWTUtil.encode(header: ["alg": "RS512",
                                                    "typ": "jwt",
                                                    "kid" : kid],
                                           body: ["user_id": user,
                                                  "device_id": deviceId],
                                           subject: "register",
                                           id: id, privateKey: jwtPKey) else {
                                            alertConfigIssue()
                                            return
        }
        
        try Kin.shared.start(environment: environment)
        try Kin.shared.login(jwt: encoded) { [weak self] e in
            DispatchQueue.main.async {
                self?.currentUserLabel.text = self?.lastUser
                self?.loginOutButton.setTitle("Logout", for: .normal)
                callback?(e)
            }
        }
    }
    
    fileprivate func alertStartError(_ error: Error) {
        let alert = UIAlertController(title: "Start failed", message: "Error: \(error)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Oh ok", style: .cancel, handler: { [weak alert] action in
            alert?.dismiss(animated: true, completion: nil)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func buyStickerTapped(_ sender: Any) {
        externalOfferTapped(false)
    }
    
    @IBAction func requestPaymentTapped(_ sender: Any) {
        externalOfferTapped(true)
    }
    
    @IBAction func payToUserTapped(_ sender: Any) {
        let pt = self.storyboard!.instantiateViewController(withIdentifier: "TargetUserViewController") as! TargetUserViewController
        pt.title = "Pay to User"
        pt.selectBlock = { [weak self] userId in
            self?.payToUserId(userId)
        }
        let nc = UINavigationController(rootViewController: pt)
        self.present(nc, animated: true)
    }
    
    @IBAction func userStats(_ sender: Any) {
        Kin.shared.userStats { [weak self] stats, error in
            if let result = stats {
                self?.presentAlert("User Stats", body: result.description)
            } else if let err = error {
                self?.presentAlert("Error", body: err.localizedDescription)
            } else {
                self?.presentAlert("Error", body: "Unknown Error")
            }
        }
    }
    
    fileprivate func externalOfferTapped(_ earn: Bool) {
        guard   let id = appId,
                let jwtPKey = privateKey else {
                alertConfigIssue()
                return
        }
        do {
            try jwtLogin()
        } catch {
            alertStartError(error)
            return
        }
        let offerID = "WOWOMGCRAZY"+"\(arc4random_uniform(999999))"
        var encoded: String? = nil
        if earn {
            encoded = JWTUtil.encode(header: ["alg": "RS512",
                                              "typ": "jwt",
                                              "kid" : kid],
                                     body: ["offer":["id":offerID, "amount":99],
                                            "recipient": ["title":"Give me Kin",
                                                          "description":"A native earn example",
                                                          "user_id":lastUser,
                                                          "device_id": deviceId]],
                                     subject: "earn",
                                     id: id, privateKey: jwtPKey)
        } else {
            encoded = JWTUtil.encode(header: ["alg": "RS512",
                                                    "typ": "jwt",
                                                    "kid" : kid],
                                           body: ["offer":["id":offerID, "amount":10],
                                                  "sender": ["title":"Native Spend",
                                                             "description":"A native spend example",
                                                             "user_id":lastUser,
                                                             "device_id": deviceId]],
                                           subject: "spend",
                                           id: id, privateKey: jwtPKey)
        }
        guard let encodedJWT = encoded else {
            alertConfigIssue()
            return
        }
        setActionRunning(true)
        let handler: KinCallback = { jwtConfirmation, error in
            DispatchQueue.main.async { [weak self] in
                self?.setActionRunning(false)
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
                if let confirm = jwtConfirmation {
                    alert.title = "Success"
                    alert.message = "\(earn ? "Earn" : "Purchase") complete. You can view the confirmation on jwt.io"
                    alert.addAction(UIAlertAction(title: "View on jwt.io", style: .default, handler: { [weak alert] action in
                        UIApplication.shared.openURL(URL(string:"https://jwt.io/#debugger-io?token=\(confirm)")!)
                        alert?.dismiss(animated: true, completion: nil)
                    }))
                } else if let e = error {
                    alert.title = "Failure"
                    alert.message = "\(earn ? "Earn" : "Purchase") failed (\(e.localizedDescription))"
                }
                
                alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: { [weak alert] action in
                    alert?.dismiss(animated: true, completion: nil)
                }))
                
                self?.present(alert, animated: true, completion: nil)
            }
        }
        if earn {
            _ = Kin.shared.requestPayment(offerJWT: encodedJWT, completion: handler)
        } else {
            _ = Kin.shared.purchase(offerJWT: encodedJWT, completion: handler)
        }
    }
    
    func payToUserId(_ uid: String) {
        guard   let id = appId,
            let jwtPKey = privateKey else {
                alertConfigIssue()
                return
        }
        do {
            try jwtLogin()
        } catch {
            alertStartError(error)
            return
        }
        
        Kin.shared.hasAccount(peer: uid) { [weak self] response, error in
            if let response = response {
                guard response else {
                    self?.presentAlert("User Not Found", body: "User \(uid) could not be found. Make sure the receiving user has activated kin, and in on the same environment as this user")
                    return
                }
                self?.transferKin(to: uid, appId: id, pKey: jwtPKey)
            } else if let error = error {
                self?.presentAlert("An Error Occurred", body: "\(error.localizedDescription)")
            } else {
                self?.presentAlert("An Error Occurred", body: "unknown error")
            }
        }
        
    }
    
    fileprivate func presentAlert(_ title: String, body: String?) {
        let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Oh ok", style: .cancel, handler: { [weak alert] action in
            alert?.dismiss(animated: true, completion: nil)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    fileprivate func transferKin(to: String, appId: String, pKey: String) {
        guard let user = lastUser else {
            presentAlert("Not logged in", body: "try logging in.")
            return
        }
        let offerID = "WOWOMGP2P"+"\(arc4random_uniform(999999))"
        guard let encoded =  JWTUtil.encode(header: ["alg": "RS512",
                                                     "typ": "jwt",
                                                     "kid" : kid],
                                            body: ["offer":["id":offerID, "amount":10],
                                                   "sender": ["title":"Pay to \(to)",
                                                    "description":"Kin transfer to \(to)",
                                                    "user_id":lastUser,
                                                    "device_id": deviceId],
                                                   "recipient": ["title":"\(user) paid you",
                                                    "description":"Kin transfer from \(user)",
                                                    "user_id":to]],
                                            subject: "pay_to_user",
                                            id: appId,
                                            privateKey: pKey) else {
                                                alertConfigIssue()
                                                return
        }
        setActionRunning(true)
        let handler: KinCallback = { jwtConfirmation, error in
            DispatchQueue.main.async { [weak self] in
                self?.setActionRunning(false)
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
                if let confirm = jwtConfirmation {
                    alert.title = "Success"
                    alert.message = "Payment complete. You can view the confirmation on jwt.io"
                    alert.addAction(UIAlertAction(title: "View on jwt.io", style: .default, handler: { [weak alert] action in
                        UIApplication.shared.openURL(URL(string:"https://jwt.io/#debugger-io?token=\(confirm)")!)
                        alert?.dismiss(animated: true, completion: nil)
                    }))
                } else if let e = error {
                    alert.title = "Failure"
                    alert.message = "Payment failed (\(e.localizedDescription))"
                }
                
                alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: { [weak alert] action in
                    alert?.dismiss(animated: true, completion: nil)
                }))
                
                self?.present(alert, animated: true, completion: nil)
            }
        }
        
        _ = Kin.shared.payToUser(offerJWT: encoded, completion: handler)
        
    }
    
    func setActionRunning(_ value: Bool) {
        loginOutButton.isEnabled = !value
        buyStickerButton.isEnabled = !value
        getKinButton.isEnabled = !value
        payButton.isEnabled = !value
        loginOutButton.alpha = value ? 0.3 : 1.0
        buyStickerButton.alpha = value ? 0.3 : 1.0
        getKinButton.alpha = value ? 0.3 : 1.0
        payButton.alpha = value ? 0.3 : 1.0
        value ? externalIndicator.startAnimating() : externalIndicator.stopAnimating()
    }
    
    
}

