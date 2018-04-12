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

    @IBOutlet weak var appIdField: UITextField!
    @IBOutlet weak var appKeyField: UITextField!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var currentUserLabel: UILabel!
    @IBOutlet weak var newUserButton: UIButton!
    
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
        let appId = UserDefaults.standard.string(forKey: "SAAppId")
        let appKey = UserDefaults.standard.string(forKey: "SAAppKey")
        if let id = appId {
            appIdField.text = id
        }
        if let key = appKey {
            appKeyField.text = key
        }
        setContinueEnabled(appId != nil && appKey != nil)
        currentUserLabel.text = lastUser
    }
    
    @IBAction func newUserTapped(_ sender: Any) {
        guard let appId = appIdField.text, let appKey = appKeyField.text else {
            let alert = UIAlertController(title: "Missing Fields", message: "App id or key are missing", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Oh", style: .cancel, handler: { [weak alert] action in
                alert?.dismiss(animated: true, completion: nil)
            }))
            self.present(alert, animated: true, completion: nil)
            return
        }
        UserDefaults.standard.set(appKey, forKey: "SAAppKey")
        UserDefaults.standard.set(appId, forKey: "SAAppId")
        let numberIndex = lastUser.index(after: lastUser.range(of: "_", options: [.backwards])!.lowerBound)
        let plusone = Int(lastUser.suffix(from: numberIndex))! + 1
        let newUser = String(lastUser.prefix(upTo: numberIndex) + "\(plusone)")
        UserDefaults.standard.set(newUser, forKey: "SALastUser")
        currentUserLabel.text = lastUser
        DispatchQueue.once(token: "sharedInit") {
            Kin.shared.start(apiKey: appKeyField.text!, userId: newUser, appId: appIdField.text!)
        }
        Kin.shared.launchMarketplace(from: self)
    }
    
    @IBAction func continueTapped(_ sender: Any) {
        guard   let appId = UserDefaults.standard.string(forKey: "SAAppId"),
                let appKey = UserDefaults.standard.string(forKey: "SAAppKey") else {
            let alert = UIAlertController(title: "No", message: "Please start a new user", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Oh ok", style: .cancel, handler: { [weak alert] action in
                alert?.dismiss(animated: true, completion: nil)
            }))
            self.present(alert, animated: true, completion: nil)
            return
        }
        DispatchQueue.once(token: "sharedInit") {
            Kin.shared.start(apiKey: appKey, userId: lastUser, appId: appId)
        }
        Kin.shared.launchMarketplace(from: self)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let new = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        let appId = UserDefaults.standard.string(forKey: "SAAppId")
        let appKey = UserDefaults.standard.string(forKey: "SAAppKey")
        switch textField {
        case appKeyField:
            setContinueEnabled(appIdField.text == appId && new == appKey)
        default:
            setContinueEnabled(new == appId && appKeyField.text == appKey)
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
    
    func setContinueEnabled(_ enable: Bool) {
        continueButton.alpha = enable ? 1.0 : 0.4
        continueButton.isEnabled = enable
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
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

