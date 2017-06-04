//
//  DataService.swift
//  messagingAppPortfolio
//
//  Created by Sten Golds on 3/12/17.
//  Copyright © 2017 Sten Golds. All rights reserved.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase
import UIKit
import GoogleSignIn

class DataService {
    
    //singleton for calling the DataService
    static let ds = DataService()
    
    //private references for firebase database
    private var _REF_BASE = FIRDatabase.database().reference()
    private var _MESS_REF = FIRDatabase.database().reference().child("messages")
    
    //private reference for firebase storage
    private var _STORAGE_REF = FIRStorage.storage().reference(forURL: storageUrl)
    
    //getters for private variables to ensure no changing of variables
    var REF_BASE: FIRDatabaseReference {
        return _REF_BASE
    }
    
    var MESS_REF: FIRDatabaseReference {
        return _MESS_REF
    }
    
    var STORAGE_REF: FIRStorageReference {
        return _STORAGE_REF
    }
    
    /**
     * @name loginAnon
     * @desc logs in the user as an anonymous Firebase user
     * @return void
     */
    func loginAnon() {
        
        //login the user anonymously, print error if there is one, else make user and go to chat
        FIRAuth.auth()?.signInAnonymously(completion: { (anonUser, error) in
            
            //if there is an error, print it and leave the block
            if error != nil {
                print(error!.localizedDescription)
                return
            } else {
                //since there was no error, create user reference in Firebase, then set the value to our user dictionary
                //profileUrl is nil as the anonymous user does not have an external profile
                let newUser = FIRDatabase.database().reference().child("users").child(anonUser!.uid)
                newUser.setValue(["displayname" : "anonymous", "id" : "\(anonUser!.uid)",
                    "profileUrl": ""])
                
                //move to chat view
                self.switchToChat()
            }
        })
    }
    
    /**
     * @name loginGoogle
     * @desc logs in the user using a google account
     * @param GIDAuthentication auth - Google authentication item from sign in
     * @return void
     */
    func loginGoogle(auth: GIDAuthentication) {
        
        //get google authentication credential from google authentication
        let credential = FIRGoogleAuthProvider.credential(withIDToken: auth.idToken, accessToken: auth.accessToken)
        
        //login the user with google, print error if there is one, else make user and go to chat
        FIRAuth.auth()?.signIn(with: credential, completion: { (googUser, error) in
            
            //if there is an error, print it and leave the block
            if error != nil {
                print(error!.localizedDescription)
                return
            } else {
                //since there was no error, create user reference in Firebase, then set the value to our user dictionary
                let newUser = FIRDatabase.database().reference().child("users").child(googUser!.uid)
                
                //create a user dictionary user the google user data, then set the value of the user reference to our created user
                newUser.setValue(["displayname" : "\(googUser!.displayName!)", "id" : "\(googUser!.uid)",
                    "profileUrl": "\(googUser!.photoURL!)"])
                
                //move to chat view
                self.switchToChat()
            }
        })
    }
    
    /**
     * @name createMessage
     * @desc creates a message object in the database, with provided content and owned by passed in user
     * @param String senderId - the ID of the user who sent the message, stored as a String
     * @param String senderName - the name of the user who sent the message, stored as a String
     * @param String mediaType - the type of media of the message, such as text or image
     * @param String? text - optional parameter for the messages text content, optional as an image has no text
     * @param String? url - optional parameter for the media url for the message, optional as text message has no media url
     * @return void
     */
    func createMessage(senderId: String, senderName: String, mediaType: String, text: String?, url: String?) {
        
        //create a dictionary to store the message data
        var messageData = Dictionary<String, String>()
        
        //if the message is a text message, store the message with text data, mediaType (TEXT), and sender info
        //else store the message with a media display url, mediaType (PHOTO or VIDEO), and sender info
        if let textGot = text {
            messageData = ["senderId": senderId, "senderName": senderName, "mediaType": mediaType, "text": textGot]
        } else {
            messageData = ["senderId": senderId, "senderName": senderName, "mediaType": mediaType, "fileURL" : url!]
        }
        
        //add the message dictionary to the messages section of the Firebase database
        MESS_REF.childByAutoId().setValue(messageData)
    }
    
    /**
     * @name loginGoogle
     * @desc logs in the user using a google account
     * @param String senderId - the ID of the user who sent the message, stored as a String
     * @param String senderName - the name of the user who sent the message, stored as a String
     * @param UIImage? picture - optional parameter for the picture to be added to firebase storage
     * @param URL? video - optional parameter for the video URL that contains the data to add to firebase storage
     * @return void
     */
    func addToStorage(senderId: String, senderName: String, picture: UIImage?, video: URL?) {
        
        //following if statement runs if there was a picture passed into the function
        //the else if runs if a video was passed in to the function
        if let picture = picture {
            
            //create a new unique filepath for the picture
            let filePath = "\(FIRAuth.auth()!.currentUser)/\(Date.timeIntervalSinceReferenceDate)"
            
            //cast the picture as JPEG representation with 90% compression
            let data = UIImageJPEGRepresentation(picture, 0.1)
            
            //create metadata storing that the image is a jpg
            let metadata = FIRStorageMetadata()
            metadata.contentType = "image/jpg"
            
            //add the image to Firebase storage
            STORAGE_REF.child(filePath).put(data!, metadata: metadata) { (metadata, error)
                in
                
                //if there was an error adding the image, leave the function
                if error != nil {
                    print(error?.localizedDescription)
                    return
                }
                
                //get the uploaded image's download url
                let fileURL = metadata!.downloadURLs![0].absoluteString
                
                //create a new message with the image as the media
                self.createMessage(senderId: senderId, senderName: senderName, mediaType: "PHOTO", text: nil, url: fileURL)
                
            }
            
        } else if let video = video {
            
            //create a new unique filepath for the video
            let filePath = "\(FIRAuth.auth()!.currentUser)/\(Date.timeIntervalSinceReferenceDate)"
            
            //catch errors from trying to create data out of the contents of the video URL
            do {
                //cast the video contents as Data
                let data = try Data(contentsOf: video)
                
                //create metadata storing that the video is a mp4
                let metadata = FIRStorageMetadata()
                metadata.contentType = "video/mp4"
                
                //add the video to Firebase storage
                STORAGE_REF.child(filePath).put(data, metadata: metadata) { (metadata, error)
                    in
                    
                    //if there was an error adding the video, leave the function
                    if error != nil {
                        print(error?.localizedDescription)
                        return
                    }
                    
                    //get the uploaded video's download url
                    let fileURL = metadata!.downloadURLs![0].absoluteString
                    
                    //create a new message with the video as the media
                    self.createMessage(senderId: senderId, senderName: senderName, mediaType: "VIDEO", text: nil, url: fileURL)
                }

            } catch {
                print("Error uploading video to storage")
            }
        }
    }
    
    /**
     * @name switchToChat
     * @desc logs in the user using a google account
     * @return void
     */
    func switchToChat() {
        //get the app's display storyboard
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let navCont = storyboard.instantiateViewController(withIdentifier: "NavigationVC") as! UINavigationController
        let appDel = UIApplication.shared.delegate as! AppDelegate
        
        //set the root of the storyboard to the chat navigation controller
        appDel.window?.rootViewController = navCont
    }
    
}
