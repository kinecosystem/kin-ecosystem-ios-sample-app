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
    @IBOutlet weak var currentUserLabel: UILabel!
    @IBOutlet weak var newUserButton: UIButton!
    @IBOutlet weak var spendIndicator: UIActivityIndicatorView!
    @IBOutlet weak var buyStickerButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    
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
        titleLabel.text = "\(version)"
    }
    
    func alertConfigIssue() {
        let alert = UIAlertController(title: "Config Missing", message: "an app id and app key (or a jwt) is required in order to use the sample app. Please refer to the readme in the sample app repo for more information", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Oh ok", style: .cancel, handler: { [weak alert] action in
            alert?.dismiss(animated: true, completion: nil)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func newUserTapped(_ sender: Any) {
        
        let numberIndex = lastUser.index(after: lastUser.range(of: "_", options: [.backwards])!.lowerBound)
        let plusone = Int(lastUser.suffix(from: numberIndex))! + 1
        let newUser = String(lastUser.prefix(upTo: numberIndex) + "\(plusone)")
        
        guard let id = appId else {
            alertConfigIssue()
            return
        }
        
        if useJWT {
            jwtLoginWith(newUser, id: id)
        } else {
            guard let key = appKey else {
                alertConfigIssue()
                return
            }
            Kin.shared.start(apiKey: key, userId: newUser, appId: id)
            
        }
        UserDefaults.standard.set(newUser, forKey: "SALastUser")
        Kin.shared.launchMarketplace(from: self)
        currentUserLabel.text = lastUser
        
    }
    
    @IBAction func continueTapped(_ sender: Any) {
        guard let id = appId else {
            alertConfigIssue()
            return
        }
        
        if useJWT {
            jwtLoginWith(lastUser, id: id)
        } else {
            guard let key = appKey else {
                alertConfigIssue()
                return
            }
            Kin.shared.start(apiKey: key, userId: lastUser, appId: id)
            
        }
        
        Kin.shared.launchMarketplace(from: self)
    }
    
    func jwtLoginWith(_ user: String, id: String, completion: ((Error?) -> ())? = nil) {
        
        guard  let jwtPKey = privateKey else {
            alertConfigIssue()
            return
        }
        
        guard let encoded = JWTUtil.encode(header: ["alg": "RS512",
                                                    "typ": "jwt",
                                                    "kid" : "default-rs512"],
                                           body: ["user_id":user],
                                           subject: "register",
                                           id: id, privateKey: jwtPKey) else {
                                            alertConfigIssue()
                                            return
        }
        
        Kin.shared.start(apiKey: "", userId: user, appId: id, jwt: encoded, completion: completion)
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        guard (self.presentedViewController is UIAlertController) == false else {
            super.dismiss(animated: flag, completion: completion)
            return
        }
        super.dismiss(animated: flag, completion: {
            completion?()
            let alert = UIAlertController(title: "Please Restart", message: "Please restart the sample app", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Oh ok", style: .cancel, handler: { action in
                exit(0)
            }))
            self.present(alert, animated: true, completion: nil)
        })
    }
    
    @IBAction func buyStickerTapped(_ sender: Any) {
        
        guard   let id = appId,
            let jwtPKey = privateKey else {
                alertConfigIssue()
                return
        }
        
        jwtLoginWith(lastUser, id: id) { [weak self] error in
            guard let this = self else { return }
            guard let encoded = JWTUtil.encode(header: ["alg": "RS512",
                                                        "typ": "jwt",
                                                        "kid" : "default-rs512"],
                                               body: ["offer":["id":"WOWOMGCRAZY"+"\(arc4random_uniform(999999))", "amount":10],
                                                      "sender": ["title":"Native Spend",
                                                                 "description":"A native spend example",
                                                                 "user_id":this.lastUser]],
                                               subject: "spend",
                                               id: id, privateKey: jwtPKey) else {
                                                this.alertConfigIssue()
                                                return
            }
            this.buyStickerButton.isEnabled = false
            this.spendIndicator.startAnimating()
            _ = Kin.shared.purchase(offerJWT: encoded) { jwtConfirmation, error in
                DispatchQueue.main.async {
                    this.buyStickerButton.isEnabled = true
                    this.spendIndicator.stopAnimating()
                    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
                    if let confirm = jwtConfirmation {
                        alert.title = "Success"
                        alert.message = "Purchase complete. You can view the confirmation jwt or tap 'Continue' to enter the marketplace."
                        alert.addAction(UIAlertAction(title: "View on jwt.io", style: .default, handler: { [weak alert] action in
                            UIApplication.shared.openURL(URL(string:"https://jwt.io/#debugger-io?token=\(confirm)")!)
                            alert?.dismiss(animated: true, completion: nil)
                        }))
                        //
                    } else if let e = error {
                        alert.title = "Failure"
                        alert.message = "Purchase failed (\(e))"
                    }
                    
                    alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: { [weak alert] action in
                        alert?.dismiss(animated: true, completion: nil)
                    }))
                    
                    this.present(alert, animated: true, completion: nil)
                }
                
            }
        }
        
        
        
    }
}

