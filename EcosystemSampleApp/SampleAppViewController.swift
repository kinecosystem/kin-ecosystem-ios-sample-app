//
//  ViewController.swift
//  EcosystemSampleApp
//
//  Created by Elazar Yifrach on 14/02/2018.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import UIKit
import KinEcosystem

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
        get {
            if  let path = Bundle.main.path(forResource: "ESSAConfig", ofType: "plist"),
                let key = NSDictionary(contentsOfFile: path)?["appKey"] as? String,
                key.isEmpty == false {
                return key
            }
            return nil
        }
    }
    
    var appId: String? {
        get {
            if  let path = Bundle.main.path(forResource: "ESSAConfig", ofType: "plist"),
                let id = NSDictionary(contentsOfFile: path)?["appId"] as? String,
                id.isEmpty == false {
                return id
            }
            return nil
        }
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
        guard let id = appId, let key = appKey else {
            alertConfigIssue()
            return
        }
        let numberIndex = lastUser.index(after: lastUser.range(of: "_", options: [.backwards])!.lowerBound)
        let plusone = Int(lastUser.suffix(from: numberIndex))! + 1
        let newUser = String(lastUser.prefix(upTo: numberIndex) + "\(plusone)")
        UserDefaults.standard.set(newUser, forKey: "SALastUser")
        currentUserLabel.text = lastUser
        DispatchQueue.once(token: "sharedInit") {
            Kin.shared.start(apiKey: key, userId: newUser, appId: id)
        }
        Kin.shared.launchMarketplace(from: self)
    }
    
    @IBAction func continueTapped(_ sender: Any) {
        guard let id = appId, let key = appKey else {
            alertConfigIssue()
            return
        }
        DispatchQueue.once(token: "sharedInit") {
            Kin.shared.start(apiKey: key, userId: lastUser, appId: id)
        }
        Kin.shared.launchMarketplace(from: self)
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

