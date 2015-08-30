import UIKit

class PAPEditPhotoViewController: UIViewController, UITextFieldDelegate, UIScrollViewDelegate {
    var scrollView: UIScrollView!
    var image: UIImage!
    var commentTextField: UITextField!
    var photoFile: PFFile?
    var thumbnailFile: PFFile?
    var fileUploadBackgroundTaskId: UIBackgroundTaskIdentifier!
    var photoPostBackgroundTaskId: UIBackgroundTaskIdentifier!

    // MARK:- NSObject

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillHideNotification, object: nil)
    }

    init(image aImage: UIImage) {
        super.init(nibName: nil, bundle: nil)
        
        self.image = aImage
        self.fileUploadBackgroundTaskId = UIBackgroundTaskInvalid
        self.photoPostBackgroundTaskId = UIBackgroundTaskInvalid
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK:- UIViewController

    override func loadView() {
        self.scrollView = UIScrollView(frame: UIScreen.mainScreen().bounds)
        self.scrollView.delegate = self
        self.scrollView.backgroundColor = UIColor.blackColor()
        self.view = self.scrollView
        
        let photoImageView = UIImageView(frame: CGRectMake(0.0, 42.0, 320.0, 320.0))
        photoImageView.backgroundColor = UIColor.blackColor()
        photoImageView.image = self.image
        photoImageView.contentMode = UIViewContentMode.ScaleAspectFit
        
        self.scrollView.addSubview(photoImageView)
        
        var footerRect: CGRect = PAPPhotoDetailsFooterView.rectForView()
        footerRect.origin.y = photoImageView.frame.origin.y + photoImageView.frame.size.height

        let footerView = PAPPhotoDetailsFooterView(frame: footerRect)
        self.commentTextField = footerView.commentField
        self.commentTextField!.delegate = self
        self.scrollView!.addSubview(footerView)

        self.scrollView!.contentSize = CGSizeMake(self.scrollView.bounds.size.width, photoImageView.frame.origin.y + photoImageView.frame.size.height + footerView.frame.size.height)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.hidesBackButton = true

        self.navigationItem.titleView = UIImageView(image: UIImage(named: "LogoNavigationBar.png"))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.Plain, target: self, action: Selector("cancelButtonAction:"))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Publish", style: UIBarButtonItemStyle.Done, target: self, action: Selector("doneButtonAction:"))
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillShow:"), name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillHide:"), name: UIKeyboardWillHideNotification, object: nil)

        self.shouldUploadImage(self.image)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        print("Memory warning on Edit")
    }

    // MARK:- UITextFieldDelegate
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.doneButtonAction(textField)
        textField.resignFirstResponder()
        return true
    }

    // MARK:- UIScrollViewDelegate

    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        self.commentTextField.resignFirstResponder()
    }

    // MARK:- ()

    func shouldUploadImage(anImage: UIImage) -> Bool {
        let resizedImage: UIImage = anImage.resizedImageWithContentMode(UIViewContentMode.ScaleAspectFit, bounds: CGSizeMake(560.0, 560.0), interpolationQuality: CGInterpolationQuality.High)
        let thumbnailImage: UIImage = anImage.thumbnailImage(86, transparentBorder: 0, cornerRadius: 10, interpolationQuality: CGInterpolationQuality.Default)
        
        // JPEG to decrease file size and enable faster uploads & downloads
        guard let imageData: NSData = UIImageJPEGRepresentation(resizedImage, 0.8) else { return false }
        guard let thumbnailImageData: NSData = UIImagePNGRepresentation(thumbnailImage) else { return false }
        
        self.photoFile = PFFile(data: imageData)
        self.thumbnailFile = PFFile(data: thumbnailImageData)

        // Request a background execution task to allow us to finish uploading the photo even if the app is backgrounded
        self.fileUploadBackgroundTaskId = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler {
            UIApplication.sharedApplication().endBackgroundTask(self.fileUploadBackgroundTaskId)
        }
        
        print("Requested background expiration task with id \(self.fileUploadBackgroundTaskId) for Anypic photo upload")
        self.photoFile!.saveInBackgroundWithBlock { (succeeded, error) in
            if (succeeded) {
                print("Photo uploaded successfully")
                self.thumbnailFile!.saveInBackgroundWithBlock { (succeeded, error) in
                    if (succeeded) {
                        print("Thumbnail uploaded successfully")
                    }
                    UIApplication.sharedApplication().endBackgroundTask(self.fileUploadBackgroundTaskId)
                }
            } else {
                UIApplication.sharedApplication().endBackgroundTask(self.fileUploadBackgroundTaskId)
            }
        }
        
        return true
    }

    func keyboardWillShow(note: NSNotification) {
        let keyboardFrameEnd: CGRect = (note.userInfo![UIKeyboardFrameBeginUserInfoKey] as! NSValue).CGRectValue()
        var scrollViewContentSize: CGSize = self.scrollView.bounds.size
        scrollViewContentSize.height += keyboardFrameEnd.size.height
        self.scrollView.contentSize = scrollViewContentSize
        
        var scrollViewContentOffset: CGPoint = self.scrollView.contentOffset
        // Align the bottom edge of the photo with the keyboard
        scrollViewContentOffset.y = scrollViewContentOffset.y + keyboardFrameEnd.size.height*3.0 - UIScreen.mainScreen().bounds.size.height
        
        self.scrollView.setContentOffset(scrollViewContentOffset, animated: true)
    }

    func keyboardWillHide(note: NSNotification) {
        let keyboardFrameEnd: CGRect = (note.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        var scrollViewContentSize: CGSize = self.scrollView.bounds.size
        scrollViewContentSize.height -= keyboardFrameEnd.size.height
        UIView.animateWithDuration(0.200, animations: {
            self.scrollView.contentSize = scrollViewContentSize
        })
    }

    func doneButtonAction(sender: AnyObject) {
        var userInfo: [String: String]?
        let trimmedComment: String = self.commentTextField.text!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if (trimmedComment.length != 0) {
            userInfo = [kPAPEditPhotoViewControllerUserInfoCommentKey: trimmedComment]
        }
        
        if self.photoFile == nil || self.thumbnailFile == nil {
            let alertController = UIAlertController(title: NSLocalizedString("Couldn't post your photo", comment: ""), message: nil, preferredStyle: UIAlertControllerStyle.Alert)
            let alertAction = UIAlertAction(title: NSLocalizedString("Dismiss", comment: ""), style: UIAlertActionStyle.Cancel, handler: nil)
            alertController.addAction(alertAction)
            presentViewController(alertController, animated: true, completion: nil)
            return
        }
        
        // both files have finished uploading
        
        // create a photo object
        let photo = PFObject(className: kPAPPhotoClassKey)
        photo.setObject(PFUser.currentUser()!, forKey: kPAPPhotoUserKey)
        photo.setObject(self.photoFile!, forKey: kPAPPhotoPictureKey)
        photo.setObject(self.thumbnailFile!, forKey: kPAPPhotoThumbnailKey)
        
        // photos are public, but may only be modified by the user who uploaded them
        let photoACL = PFACL(user: PFUser.currentUser()!)
        photoACL.setPublicReadAccess(true)
        photo.ACL = photoACL
        
        // Request a background execution task to allow us to finish uploading the photo even if the app is backgrounded
        self.photoPostBackgroundTaskId = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler {
            UIApplication.sharedApplication().endBackgroundTask(self.photoPostBackgroundTaskId)
        }

        // save
        photo.saveInBackgroundWithBlock { (succeeded, error) in
            if succeeded {
                print("Photo uploaded")
                
                PAPCache.sharedCache.setAttributesForPhoto(photo, likers: [PFUser](), commenters: [PFUser](), likedByCurrentUser: false)
                
                // userInfo might contain any caption which might have been posted by the uploader
                if let userInfo = userInfo {
                    let commentText = userInfo[kPAPEditPhotoViewControllerUserInfoCommentKey]
                    
                    if commentText != nil && commentText!.length != 0 {
                        // create and save photo caption
                        let comment = PFObject(className: kPAPActivityClassKey)
                        comment.setObject(kPAPActivityTypeComment, forKey: kPAPActivityTypeKey)
                        comment.setObject(photo, forKey:kPAPActivityPhotoKey)
                        comment.setObject(PFUser.currentUser()!, forKey: kPAPActivityFromUserKey)
                        comment.setObject(PFUser.currentUser()!, forKey: kPAPActivityToUserKey)
                        comment.setObject(commentText!, forKey: kPAPActivityContentKey)
                        
                        let ACL = PFACL(user: PFUser.currentUser()!)
                        ACL.setPublicReadAccess(true)
                        comment.ACL = ACL
                        
                        comment.saveEventually()
                        PAPCache.sharedCache.incrementCommentCountForPhoto(photo)
                    }
                }
                
                NSNotificationCenter.defaultCenter().postNotificationName(PAPTabBarControllerDidFinishEditingPhotoNotification, object: photo)
            } else {
                print("Photo failed to save: \(error)")
                let alertController = UIAlertController(title: NSLocalizedString("Couldn't post your photo", comment: ""), message: nil, preferredStyle: UIAlertControllerStyle.Alert)
                let alertAction = UIAlertAction(title: NSLocalizedString("Dismiss", comment: ""), style: UIAlertActionStyle.Cancel, handler: nil)
                alertController.addAction(alertAction)
                self.presentViewController(alertController, animated: true, completion: nil)
            }
            UIApplication.sharedApplication().endBackgroundTask(self.photoPostBackgroundTaskId)
        }
        
        self.parentViewController!.dismissViewControllerAnimated(true, completion: nil)
    }

    func cancelButtonAction(sender: AnyObject) {
        self.parentViewController!.dismissViewControllerAnimated(true, completion: nil)
    }
}
