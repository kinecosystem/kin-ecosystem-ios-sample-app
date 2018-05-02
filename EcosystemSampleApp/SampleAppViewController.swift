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

public extension DispatchQueue {
    
    private static var _onceTracker = [String]()
    
    public class func once(token: String, block:() -> ()) {
        objc_sync_enter(self); defer { objc_sync_exit(self) }
        
        if _onceTracker.contains(token) {
            return
        }
        
        _onceTracker.append(token)
        block()
    }
}

class SampleAppViewController: UIViewController, UITextFieldDelegate {


    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var currentUserLabel: UILabel!
    @IBOutlet weak var newUserButton: UIButton!
    
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
            DispatchQueue.once(token: "sharedInit") {
                Kin.shared.start(apiKey: key, userId: newUser, appId: id)
            }
            
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
            DispatchQueue.once(token: "sharedInit") {
                Kin.shared.start(apiKey: key, userId: lastUser, appId: id)
            }
        }
        
        Kin.shared.launchMarketplace(from: self)
    }
    
    func jwtLoginWith(_ user: String, id: String) {
        
        guard   let jwtPKey = privateKey,
            let key = try? JWTCryptoKeyPrivate(pemEncoded: jwtPKey, parameters: nil),
            let holder = (JWTAlgorithmRSFamilyDataHolder().signKey(key)?.secretData(jwtPKey.data(using: .utf8))?.algorithmName(JWTAlgorithmNameRS512) as? JWTAlgorithmRSFamilyDataHolder) else {
                alertConfigIssue()
                return
        }

        let claims = JWTClaimsSet()
        let issuedAt = Date()
        claims.issuer = id
        claims.issuedAt = issuedAt
        claims.expirationDate = issuedAt.addingTimeInterval(86400.0)
        claims.subject = "register"

        guard var claimsDict = JWTClaimsSetSerializer.dictionary(with: claims) else {
            alertConfigIssue()
            return
        }

        claimsDict["user_id"] = user

        let result = JWTEncodingBuilder.encodePayload(claimsDict)
            .headers(["alg": "RS512",
                      "typ": "jwt",
                      "kid" : "default-rs512"])?
            .addHolder(holder)?
            .result

        guard let encoded = result?.successResult?.encoded else {
            alertConfigIssue()
            return
        }
        
        DispatchQueue.once(token: "sharedInit") {
            Kin.shared.start(apiKey: "", userId: user, appId: id, jwt: encoded)
        }
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
}

