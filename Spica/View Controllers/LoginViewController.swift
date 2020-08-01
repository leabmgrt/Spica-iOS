//
//  LoginViewController.swift
//  Spica
//
//  Created by Adrian Baumgart on 02.07.20.
//

import Combine
import JGProgressHUD
import UIKit

class LoginViewController: UIViewController, UITextFieldDelegate {
    var usernameLabel: UILabel!
    var passwordLabel: UILabel!
    var usernameField: UITextField!
    var passwordField: UITextField!
    var signInButton: UIButton!
    var toolbarDelegate = ToolbarDelegate()

    var createAccountButton: UIButton!

    var loadingHud: JGProgressHUD!

    private var subscriptions = Set<AnyCancellable>()

    func textFieldShouldReturn(_: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        hideKeyboardWhenTappedAround()

        /* NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
         NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil) */
        navigationItem.title = SLocale(.ALLES_LOGIN)
        navigationController?.navigationBar.prefersLargeTitles = true

        usernameField = UITextField(frame: .zero)
        usernameField.borderStyle = .roundedRect
        usernameField.placeholder = "jessica"
        usernameField.autocapitalizationType = .none
        usernameField.autocorrectionType = .no
        view.addSubview(usernameField)

        loadingHud = JGProgressHUD(style: .dark)
        loadingHud.textLabel.text = SLocale(.LOADING_ACTION)
        loadingHud.interactionType = .blockAllTouches

        usernameField.snp.makeConstraints { make in
            make.centerX.equalTo(view.snp.centerX)
            make.centerY.equalTo(view.snp.centerY).offset(-90)
            make.width.equalTo(view.snp.width).offset(-64)
            make.height.equalTo(40)
        }

        usernameLabel = UILabel(frame: .zero)
        usernameLabel.text = "\(SLocale(.USERNAME)):"
        view.addSubview(usernameLabel)

        usernameLabel.snp.makeConstraints { make in
            make.bottom.equalTo(usernameField.snp.top).offset(-8)
            make.leading.equalTo(32)
        }

        passwordLabel = UILabel(frame: .zero)
        passwordLabel.text = "\(SLocale(.PASSWORD)):"
        view.addSubview(passwordLabel)

        passwordLabel.snp.makeConstraints { make in
            make.top.equalTo(usernameField.snp.bottom).offset(16)
            make.leading.equalTo(32)
        }

        passwordField = UITextField(frame: .zero)
        passwordField.borderStyle = .roundedRect
        passwordField.placeholder = "••••••"
        passwordField.isSecureTextEntry = true
        passwordField.autocapitalizationType = .none
        passwordField.autocorrectionType = .no
        view.addSubview(passwordField)

        passwordField.snp.makeConstraints { make in
            make.centerX.equalTo(view.snp.centerX)
            make.top.equalTo(passwordLabel.snp.bottom).offset(8)
            make.width.equalTo(view.snp.width).offset(-64)
            make.height.equalTo(40)
        }

        usernameField.delegate = self
        passwordField.delegate = self

        signInButton = UIButton(type: .system)
        signInButton.backgroundColor = UIColor(named: "PostButtonColor")
        signInButton.setTitle(SLocale(.SIGN_IN), for: .normal)
        signInButton.setTitleColor(.white, for: .normal)
        signInButton.layer.cornerRadius = 12
        signInButton.addTarget(self, action: #selector(signIn), for: .touchUpInside)
        signInButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        view.addSubview(signInButton)

        signInButton.snp.makeConstraints { make in
            make.centerX.equalTo(view.snp.centerX)
            make.top.equalTo(passwordField.snp.bottom).offset(32)
            make.width.equalTo(150)
            make.height.equalTo(40)
        }

        createAccountButton = UIButton(type: .system)
        createAccountButton.setTitle(SLocale(.NO_ACCOUNT), for: .normal)
        createAccountButton.addTarget(self, action: #selector(openCreateAccount), for: .touchUpInside)
        view.addSubview(createAccountButton)

        createAccountButton.snp.makeConstraints { make in
            make.centerX.equalTo(view.snp.centerX)
            make.width.equalTo(200)
            make.height.equalTo(40)
            make.top.equalTo(signInButton.snp.bottom).offset(32)
        }

        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_: Bool) {
        #if targetEnvironment(macCatalyst)

            let toolbar = NSToolbar(identifier: "other")
            toolbar.delegate = toolbarDelegate
            toolbar.displayMode = .iconOnly

            if let titlebar = view.window!.windowScene!.titlebar {
                titlebar.toolbar = nil
                // titlebar.toolbarStyle = .automatic
            }

            navigationController?.setNavigationBarHidden(false, animated: false)
            navigationController?.setToolbarHidden(false, animated: false)
        #endif
        /* #if targetEnvironment(macCatalyst)
         let sceneDelegate = view.window!.windowScene!.delegate as! SceneDelegate
         if let titleBar = sceneDelegate.window?.windowScene?.titlebar {
         titleBar.toolbar = nil
         }
         #endif */
    }

    @objc func openCreateAccount() {
        UIApplication.shared.open(URL(string: "https://alles.cx/register")!)
    }

    @objc func signIn() {
        loadingHud.show(in: view)
        usernameField.layer.borderColor = UIColor.clear.cgColor
        usernameField.layer.borderWidth = 0.0

        passwordField.layer.borderColor = UIColor.clear.cgColor
        passwordField.layer.borderWidth = 0.0

        if !usernameField.text!.isEmpty && !passwordField.text!.isEmpty {
            AllesAPI.default.signInUser(username: usernameField.text!, password: passwordField.text!)
                .receive(on: RunLoop.main)
                .sink {
                    switch $0 {
                    case let .failure(err):
                        DispatchQueue.main.async {
                            self.loadingHud.dismiss()

                            AllesAPI.default.errorHandling(error: err, caller: self.view)
                        }
                    default: break
                    }
                } receiveValue: { _ in
                    DispatchQueue.main.async {
                        let sceneDelegate = self.view.window!.windowScene!.delegate as! SceneDelegate

                        let initialView = sceneDelegate.setupInitialView()
                        sceneDelegate.window?.rootViewController = initialView

                        self.loadingHud.dismiss()
                        sceneDelegate.window?.makeKeyAndVisible()
                    }
                }.store(in: &subscriptions)
        } else {
            loadingHud.dismiss()
            if usernameField.text!.isEmpty {
                usernameField.layer.borderColor = UIColor.systemRed.cgColor
                usernameField.layer.borderWidth = 1.0
            }
            if passwordField.text!.isEmpty {
                passwordField.layer.borderColor = UIColor.systemRed.cgColor
                passwordField.layer.borderWidth = 1.0
            }
        }
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if view.frame.origin.y == 0 {
                view.frame.origin.y -= keyboardSize.height
            }
        }
    }

    @objc func keyboardWillHide(notification _: NSNotification) {
        if view.frame.origin.y != 0 {
            view.frame.origin.y = 0
        }
    }

    override func viewWillAppear(_: Bool) {
        navigationController?.navigationBar.prefersLargeTitles = true
    }
}
