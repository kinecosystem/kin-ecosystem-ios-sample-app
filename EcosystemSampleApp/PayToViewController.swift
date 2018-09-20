//
//  PayToViewController.swift
//  EcosystemSampleApp
//
//  Created by Elazar Yifrach on 16/09/2018.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation
import UIKit

protocol PayToViewControllerDelegate: class {
    func payToUserId(_ uid: String)
}
class PayToViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var nextButton: UIButton!
    weak var delegate: PayToViewControllerDelegate?
    @IBOutlet weak var textfield: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pay To User"
        nextButton.isEnabled = false
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelPayment))
    }
    
    
    @IBAction func uidChanged(_ sender: Any) {
        nextButton.isEnabled = (sender as! UITextField).hasText
    }
    @IBAction func nextTapped(_ sender: Any) {
        guard let delegate = delegate else { return }
        defer {
            self.dismiss(animated: true)
        }
        delegate.payToUserId(textfield.text!)
    }
    
    @objc func cancelPayment() {
        self.dismiss(animated: true)
    }
}

