//
//  LoginVC.swift
//  messagingAppPortfolio
//
//  Created by Sten Golds on 3/11/17.
//  Copyright © 2017 Sten Golds. All rights reserved.
//

import UIKit
import FirebaseAuth
import GoogleSignIn

class LoginVC: UIViewController, GIDSignInUIDelegate, GIDSignInDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        //set up google login by making this view the delegate and setting the client id
        GIDSignIn.sharedInstance().clientID = clientID
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().delegate = self
        
    }
    
    /**
     * @name loginAnonPressed
     * @desc logs in the user with an anonymous account
     * @param Any sender - the sender of the action
     * @return void
     */
    @IBAction func loginAnonPressed(_ sender: Any) {
        
        DataService.ds.loginAnon()
        
    }

    /**
     * @name googleLoginPressed
     * @desc logs in the user using a google account
     * @param Any sender - the sender of the action
     * @return void
     */
    @IBAction func googleLoginPressed(_ sender: Any) {
        
        GIDSignIn.sharedInstance().signIn()

    }
    
    /**
     * @name sign
     * @desc delegate method for google sign in, used to see if the Google sign in was successful
     * @param GIDSignIn signIn - sign in object from the complete Google sign in
     * @param GIDGoogleUser user - the Google user got from signing into Google
     * @param Error error - sign in error, nil if no error
     * @return void
     */
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        
        if error != nil {
            print(error!.localizedDescription)
            return
        }
        
        DataService.ds.loginGoogle(auth: user.authentication)
    }
    
}
