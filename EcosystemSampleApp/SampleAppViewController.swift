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

class SampleAppViewController: UIViewController, UITextFieldDelegate, PayToViewControllerDelegate {
    
    
    
    
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var currentUserLabel: UILabel!
    @IBOutlet weak var newUserButton: UIButton!
    @IBOutlet weak var externalIndicator: UIActivityIndicatorView!
    @IBOutlet weak var buyStickerButton: UIButton!
    @IBOutlet weak var getKinButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var payButton: UIButton!
    
    let environment: Environment = .playground
    
    var appKey: String? {
        return configValue(for: "appKey", of: String.self)
    }
    
    var appId: String? {
        return configValue(for: "appId", of: String.self)
    }
    
    var useJWT: Bool {
        return configValue(for: "IS_JWT_REGISTRATION", of: Bool.self) ?? false
    }
    
    var privateKey: String? {
        return configValue(for: "RS512_PRIVATE_KEY", of: String.self)
    }
    
    var lastUser: String {
        get {
            if let user = UserDefaults.standard.string(forKey: "SALastUser") {
                return user
            }
            let first = "user_\(arc4random_uniform(99999))_0"
            UserDefaults.standard.set(first, forKey: "SALastUser")
            return first
        }
    }
    
    func configValue<T>(for key: String, of type: T.Type) -> T? {
        if  let path = Bundle.main.path(forResource: "defaultConfig", ofType: "plist"),
            let value = NSDictionary(contentsOfFile: path)?[key] as? T {
            return value
        }
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        currentUserLabel.text = lastUser
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        titleLabel.text = "\(version) (\(build))"
    }
    
    func alertConfigIssue() {
        presentAlert("Config Missing", body: "an app id and app key (or a jwt) is required in order to use the sample app. Please refer to the readme in the sample app repo for more information")
    }
    
    @IBAction func newUserTapped(_ sender: Any) {
        
        let numberIndex = lastUser.index(after: lastUser.range(of: "_", options: [.backwards])!.lowerBound)
        let plusone = Int(lastUser.suffix(from: numberIndex))! + 1
        let newUser = String(lastUser.prefix(upTo: numberIndex) + "\(plusone)")
        UserDefaults.standard.set(newUser, forKey: "SALastUser")
        currentUserLabel.text = lastUser
        let alert = UIAlertController(title: "Please Restart", message: "A new user was created.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Oh ok", style: .cancel, handler: { action in
            exit(0)
        }))
        self.present(alert, animated: true, completion: nil)
        
    }
    
    @IBAction func continueTapped(_ sender: Any) {
        guard let id = appId else {
            alertConfigIssue()
            return
        }
        
        if useJWT {
            do {
                try jwtLoginWith(lastUser, id: id)
            } catch {
                alertStartError(error)
            }
        } else {
            guard let key = appKey else {
                alertConfigIssue()
                return
            }
            do {
                try Kin.shared.start(userId: lastUser, apiKey: key, appId: id, environment: environment)
            } catch {
                alertStartError(error)
            }
            
        }
        
        let offer = NativeOffer(id: "wowowo12345",
                                title: "Renovate!",
                                description: "Your new home",
                                amount: 1000,
                                image: "https://www.makorrishon.co.il/nrg/images/archive/300x225/270/557.jpg",
                                isModal: true)
        do {
            try Kin.shared.add(nativeOffer: offer)
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
        try? Kin.shared.launchMarketplace(from: self)
    }
    
    func jwtLoginWith(_ user: String, id: String) throws {
        
        guard  let jwtPKey = privateKey else {
            alertConfigIssue()
            return
        }
        
        guard let encoded = JWTUtil.encode(header: ["alg": "RS512",
                                                    "typ": "jwt",
                                                    "kid" : "rs512_0"],
                                           body: ["user_id":user],
                                           subject: "register",
                                           id: id, privateKey: jwtPKey) else {
                                            alertConfigIssue()
                                            return
        }
        
        try Kin.shared.start(userId: user, jwt: encoded, environment: environment)
        
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
        let pt = self.storyboard!.instantiateViewController(withIdentifier: "PayToViewController") as! PayToViewController
        pt.delegate = self
        let nc = UINavigationController(rootViewController: pt)
        self.present(nc, animated: true)
    }
    
    fileprivate func externalOfferTapped(_ earn: Bool) {
        guard   let id = appId,
            let jwtPKey = privateKey else {
                alertConfigIssue()
                return
        }
        do {
            try jwtLoginWith(lastUser, id: id)
        } catch {
            alertStartError(error)
            return
        }
        let offerID = "WOWOMGCRAZY"+"\(arc4random_uniform(999999))"
        var encoded: String? = nil
        if earn {
            encoded = JWTUtil.encode(header: ["alg": "RS512",
                                              "typ": "jwt",
                                              "kid" : "rs512_0"],
                                     body: ["offer":["id":offerID, "amount":99],
                                            "recipient": ["title":"Give me Kin",
                                                          "description":"A native earn example",
                                                          "user_id":lastUser]],
                                     subject: "earn",
                                     id: id, privateKey: jwtPKey)
        } else {
            encoded = JWTUtil.encode(header: ["alg": "RS512",
                                                    "typ": "jwt",
                                                    "kid" : "rs512_0"],
                                           body: ["offer":["id":offerID, "amount":10],
                                                  "sender": ["title":"Native Spend",
                                                             "description":"A native spend example",
                                                             "user_id":lastUser]],
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
            try jwtLoginWith(lastUser, id: id)
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
        let offerID = "WOWOMGP2P"+"\(arc4random_uniform(999999))"
        guard let encoded =  JWTUtil.encode(header: ["alg": "RS512",
                                                     "typ": "jwt",
                                                     "kid" : "rs512_0"],
                                            body: ["offer":["id":offerID, "amount":10],
                                                   "sender": ["title":"Pay to \(to)",
                                                    "description":"Kin transfer to \(to)",
                                                    "user_id":lastUser],
                                                   "recipient": ["title":"\(lastUser) paid you",
                                                    "description":"Kin transfer from \(lastUser)",
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
        newUserButton.isEnabled = !value
        buyStickerButton.isEnabled = !value
        getKinButton.isEnabled = !value
        payButton.isEnabled = !value
        newUserButton.alpha = value ? 0.3 : 1.0
        buyStickerButton.alpha = value ? 0.3 : 1.0
        getKinButton.alpha = value ? 0.3 : 1.0
        payButton.alpha = value ? 0.3 : 1.0
        value ? externalIndicator.startAnimating() : externalIndicator.stopAnimating()
    }
}

