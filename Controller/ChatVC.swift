//
//  ChatVC.swift
//  messagingAppPortfolio
//
//  Created by Sten Golds on 3/11/17.
//  Copyright © 2017 Sten Golds. All rights reserved.
//

import UIKit
import Firebase
import FirebaseAuth
import JSQMessagesViewController
import MobileCoreServices
import AVKit
import SDWebImage

class ChatVC: JSQMessagesViewController  {

    //array to store the messages in the chatroom
    var messages = [JSQMessage]()
    
    //dictionary to store the user avatars for user's in the chatroom
    var avatarImgDict = [String: JSQMessagesAvatarImage]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //if there is a user, get it

        if let currentUser = FIRAuth.auth()?.currentUser {
            //assign the senderId to be equal to the signed in user's id
            self.senderId = currentUser.uid
            
            //if the current user is anonymous, make display name anonymous, else use user's display name
            if currentUser.isAnonymous == true {
                self.senderDisplayName = "anonymous"
            } else {
                self.senderDisplayName = "\(currentUser.displayName!)"
            }
        }
        
        //start observing the messages for the chatroom
        observeMessages()
    }
    
    /**
     * @name observeUsers
     * @desc get the user with id, and load the user's avatar to the user's messages
     * @param String id - the id of the user to load the avatar for
     * @return void
     */
    func observeUsers(id: String) {
        //get user with id
        DataService.ds.REF_BASE.child("users").child(id).observe(.value, with: {
            snapshot in
            
            //cast the snapshot.value, which we know will be a dictionary as it is a user, as a dictionary
            if let dict = snapshot.value as? [String: AnyObject]
            {
                //get the user's profileUrl, which stores the user's avatar
                let avUrl = dict["profileUrl"] as! String
                
                //set up the avatar with the user's profileURL and user's id
                self.setupAvatar(url: avUrl, messageId: id)
            }
        })
        
    }
    
    /**
     * @name observeMessages
     * @desc moniters the messages in the chatroom and displays them
     * @return void
     */
    func observeMessages() {
        
        //retrieve the messages for the chatroom, which are stored at the MESS_REF value in Firebase
        DataService.ds.MESS_REF.observe(.childAdded, with: { (snapshot) in
            
            //cast the retrieved value as a dictionary representing the message
            if let messDict = snapshot.value as? [String: AnyObject] {
                
                //get the type of media type, sender id, and sender's display name from the message dictionary
                let mediaType = messDict["mediaType"] as! String
                let senderId = messDict["senderId"] as! String
                let displayName = messDict["senderName"] as! String
                
                //add user avatar to the message
                self.observeUsers(id: senderId)
                
                //switch statement to load message with correct media (text, image, video)
                switch mediaType {
                
                //runs if the message mediaType is text
                case "TEXT":
                    //gets the messages text
                    let text = messDict["text"] as! String
                    
                    //adds a message with the retrieved senderId, displayName, and text
                    self.messages.append(JSQMessage(senderId: senderId, displayName: displayName, text: text))
                 
                //runs if the message mediaType is PHOTO
                case "PHOTO":
                    //creates new message photo item
                    let photo = JSQPhotoMediaItem(image: nil)
                    
                    //get url from the message to download the photo from
                    if let fileUrl = messDict["fileURL"] as? String {
                        
                        //download the image in the background, and set message photo item to the downloaded image
                        //after downloading and setting, refresh the message screen
                        let downloader = SDWebImageDownloader.shared()
                        downloader.downloadImage(with: URL(string: fileUrl)!, options: [], progress: nil, completed: { (image, data, error, finished) in
                            DispatchQueue.main.async (execute: {
                                photo?.image = image
                                self.collectionView.reloadData()
                            })
                        })
                    }
                    
                    //add a message with the retrieved senderId, displayName, and photo
                    self.messages.append(JSQMessage(senderId: senderId, displayName: displayName, media: photo))
                    
                    //masks image based on if the current user sent the image, or another user
                    if self.senderId == senderId {
                        photo?.appliesMediaViewMaskAsOutgoing = true
                    } else {
                        photo?.appliesMediaViewMaskAsOutgoing = false
                    }
                
                //runs if the message mediaType is VIDEO
                case "VIDEO":
                    
                    //get url from the message to download the video from
                    if let fileURL = messDict["fileURL"] as? String {
                        //create a URL object with the video URL
                        let video = URL(string: fileURL)
                        
                        //cast the video URL as a playable message video item
                        if let videoItem = JSQVideoMediaItem(fileURL: video, isReadyToPlay: true) {
                            
                            //add a message with the retrieved senderId, displayName, and video
                            self.messages.append(JSQMessage(senderId: senderId, displayName: displayName, media: videoItem))
                            
                            //masks image based on if the current user sent the video, or another user
                            if self.senderId == senderId {
                                videoItem.appliesMediaViewMaskAsOutgoing = true
                            } else {
                                videoItem.appliesMediaViewMaskAsOutgoing = false
                            }
                        }
                    }
                
                //runs if no known mediaType was selected, prints a statement signaling this has occurred
                default:
                    print("Unknown Data Type")
                    
                }
                
                //refresh the messages screen
                self.collectionView.reloadData()
            }
            
        })
    }
    
    /**
     * @name setupAvatar
     * @desc adds the user's avatar to their message, useful for identifying who sent what message
     * @param String url - the url where the user's avatar picture is stored
     * @param String messageId - the id of the message's sending user to load the avatar for
     * @return void
     */
    func setupAvatar(url: String, messageId: String) {
        
        //if there is a url for the user's avatar, load it, and add it to the message
        //else, load a default profile image for the message
        if url != "" {
            
            //catch any errors that may arise from loading the user's avatar
            do {
                //get the data from the url
                let fileUrl = URL(string: url)
                let data = try Data(contentsOf: fileUrl!)
                
                //cast the data into an image, then make the image into a message avatar
                let image = UIImage(data: data)
                let userImg = JSQMessagesAvatarImageFactory.avatarImage(with: image, diameter: 30)
                
                //store the user's avatar in a dictionary, so you do not need to load it everytime
                self.avatarImgDict[messageId] = userImg
                
                //reload the message view
                self.collectionView.reloadData()
            } catch {
                print("Error retrieving avatar image")
            }
            
        } else {
            
            //create an avatar with the default profile picture
            avatarImgDict[messageId] = JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "profileImage.png"), diameter: 30)
            
            //reload the message view
            self.collectionView.reloadData()
        }
        
    }
    
    /**
     * @name didPressSend
     * @desc sends a text message by creating a message and storing it in Firebase
     * @param UIButton button - button action used to check if send was pressed
     * @param String text - the text of the message
     * @param String senderId - the id of the message's sending user
     * @param String senderDisplayName - the display name of the message's sending user
     * @param Date date - the time of message creastion
     * @return void
     */
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        
        //creates new text message in Firebase with the text data, and from the senderId
        DataService.ds.createMessage(senderId: senderId, senderName: senderDisplayName, mediaType: "TEXT", text: text, url: nil)
        
        //finish sending message by calling JSQMessage function to finish, animates message sending
        self.finishSendingMessage()
    }
    
    /**
     * @name didPressAccessoryButton
     * @desc creates a sheet to allow user to select a photo or video to send
     * @param UIButton sender - sender of the action
     * @return void
     */
    override func didPressAccessoryButton(_ sender: UIButton!) {
        
        //create display sheet informing user to choose a media type
        let sheet = UIAlertController(title: "Media Type", message: "Please Select Media", preferredStyle: .actionSheet)
        
        //sheet button to cancel the action sheet
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
        }
        
        //sheet button to open the user's photo library, and allow the user to chose a photo to send
        let photoLib = UIAlertAction(title: "Photo Library", style: .default) { (action) in
            self.getMedia(type: kUTTypeImage)
        }
        
        //sheet button to open the user's video library, and allow the user to chose a video to send
        let videoLib = UIAlertAction(title: "Video Library", style: .default) { (action) in
            self.getMedia(type: kUTTypeVideo)
        }
        
        //add buttons for cancelling, photo library, and video library to the action sheet
        sheet.addAction(cancel)
        sheet.addAction(photoLib)
        sheet.addAction(videoLib)
        
        //display the action sheet
        self.present(sheet, animated: true, completion: nil)
    
    }
    
    /**
     * @name getMedia
     * @desc creates and presents a media picker for the given type to allow user to select media to send
     * @param CFString type - type of media picker to present
     * @return void
     */
    func getMedia(type: CFString) {
        
        //create media picker with given type, either image or video
        let mediaPicker = UIImagePickerController()
        mediaPicker.delegate = self
        mediaPicker.mediaTypes = [type as String]
        
        //present the media picker
        self.present(mediaPicker, animated: true, completion: nil)
        
    }
    
    /**
     * @name collectionView - messageDataForItemAt
     * @desc JSQMessage function override to get message from our message array at index path
     * @param JSQMessagesCollectionView collectionView - collection view that displays the messages
     * @param IndexPath indexPath - stores information on where in the collection view a certain item will go/be
     * @return JSQMessageData - JSQMessage at the index path in our messages array
     */
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        
        //return message at indexPath
        return messages[indexPath.item]
    }
    
    /**
     * @name collectionView - messageBubbleImageDataForItemAt
     * @desc JSQMessage function override to create a chat bubble around our messages
     * @param JSQMessagesCollectionView collectionView - collection view that displays the messages
     * @param IndexPath indexPath - stores information on where in the collection view a certain item will go/be
     * @return JSQMessageBubbleImageDataSource - DataSource that tells us whether a bubble should be blue or gray
     */
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        
        //get message at indexPath
        let message = messages[indexPath.item]
        
        //create bubble factory, and set outgoing chat bubbles to blue, and incoming chat bubbles to gray
        let bubbleFactory = JSQMessagesBubbleImageFactory()
        if message.senderId == self.senderId {
            return bubbleFactory!.outgoingMessagesBubbleImage(with: .blue)
        } else {
            return bubbleFactory!.incomingMessagesBubbleImage(with: .gray)
        }
    }
    
    /**
     * @name collectionView - avatarImageDataForItemAt
     * @desc JSQMessage function override to display user avatar next to their messages
     * @param JSQMessagesCollectionView collectionView - collection view that displays the messages
     * @param IndexPath indexPath - stores information on where in the collection view a certain item will go/be
     * @return JSQMessageAvatarImageDataSource - DataSource that tells us what avatar to display for the message
     */
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        
        //get message at indexPath
        let message = messages[indexPath.item]
        
        //return the user avatar for the sender of the message at indexPath
        return avatarImgDict[message.senderId]
    }
    
    /**
     * @name collectionView - numberOfItemsInSection
     * @desc tells the collection view how many messages will be displayed
     * @param JSQMessagesCollectionView collectionView - collection view that displays the messages
     * @param Int section - the current section of the collection view, as this app only uses one section, section is never used
     * @return Int - number of messages to display
     */
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        //return number of messages
        return messages.count
    }
    
    /**
     * @name collectionView - cellForItemAt
     * @desc create a message cell for each index path
     * @param JSQMessagesCollectionView collectionView - collection view that displays the messages
     * @param IndexPath indexPath - stores information on where in the collection view a certain item will go/be
     * @return UICollectionViewCell - message cell for current index path
     */
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        //create message cell for the index path in the collection view
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        
        //return the created cell
        return cell
    }
    
    /**
     * @name collectionView - didTapMessageBubbleAt
     * @desc if the message is a image or a video, this function will display the media if the message bubble is tapped
     * @param JSQMessagesCollectionView collectionView - collection view that displays the messages
     * @param IndexPath indexPath - stores information on where in the collection view a certain item will go/be
     * @return void
     */
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAt indexPath: IndexPath!) {
        
        //get message at index path
        let message = messages[indexPath.item]
    
        //runs if the message has media to displatt
        if message.isMediaMessage {
            
            //if the media is a video, create a video player and display the video
            //else if the media is an image, create an image frame where tapping dismisses the frame, and display the image
            if let mediaItem = message.media as? JSQVideoMediaItem {
                let player = AVPlayer(url: mediaItem.fileURL)
                let playerVC = AVPlayerViewController()
                playerVC.player = player
                
                self.present(playerVC, animated: true, completion: nil)
            } else if let mediaItem = message.media as? JSQPhotoMediaItem {
                let newImageView = UIImageView(image: mediaItem.image)
                newImageView.frame = self.view.frame
                newImageView.backgroundColor = .black
                newImageView.contentMode = .scaleAspectFit
                newImageView.isUserInteractionEnabled = true
                
                let tap = UITapGestureRecognizer(target: self, action: #selector(dismissFullscreenImage))
                newImageView.addGestureRecognizer(tap)
                self.view.addSubview(newImageView)
            }
        }
    }
    
    /**
     * @name dismissFullscreenImage
     * @desc helper method to dismiss the full screen displayed image media message
     * @param UITapGestureRecognizer sender - gesture that calls the function
     * @return void
     */
    func dismissFullscreenImage(_ sender: UITapGestureRecognizer) {
        sender.view?.removeFromSuperview()
    }

    /**
     * @name logOutPressed
     * @desc logs the user out, therefore exiting the chatroom and bringing the user back to the sign in screen
     * @param Any sender - caller of function, e.g. button
     * @return void
     */
    @IBAction func logOutPressed(_ sender: Any) {
        //log out of Firebase
        do {
            try FIRAuth.auth()?.signOut()
        } catch let error {
            print(error)
        }
        
        //create storyboard instance
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        //instantiate navigation controller
        let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginVC") as! LoginVC
        
        //get app del
        let appDel = UIApplication.shared.delegate as! AppDelegate
        
        //set loginVC as root view
        appDel.window?.rootViewController = loginVC
    }
    
}

/**
 * @name logOutPressed
 * @desc extenstion to help with selecting media and adding selected media for a message to Firebase storage
 */
extension ChatVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    /**
     * @name logOutPressed
     * @desc logs the user out, therefore exiting the chatroom and bringing the user back to the sign in screen
     * @param UIImagePickerController picker - the picker controller that allows for selecting media
     * @param [String : Any] info - dictionary of related information about the selected media
     * @return void
     */
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        //get image or video
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            //add image to Firebase storage
            DataService.ds.addToStorage(senderId: senderId, senderName: senderDisplayName, picture: image, video: nil)
        }
        else if let videoURL = info[UIImagePickerControllerMediaURL] as? URL {
            //add video to Firebase storage
            DataService.ds.addToStorage(senderId: senderId, senderName: senderDisplayName, picture: nil, video: videoURL)
        }
        
        //dismiss media selector view
        self.dismiss(animated: true, completion: nil)
        
        //reload the chat view
        collectionView.reloadData()
    }
}
