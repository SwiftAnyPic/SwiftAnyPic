import UIKit
import ParseUI
import MBProgressHUD

enum ActionSheetTags: Int {
    case MainAction = 0,
    ConfirmDeleteAction = 1
}

let kPAPCellInsetWidth: CGFloat = 0.0

class PAPPhotoDetailsViewController : PFQueryTableViewController, UITextFieldDelegate, UIActionSheetDelegate, PAPPhotoDetailsHeaderViewDelegate, PAPBaseTextCellDelegate {
    private(set) var photo: PFObject?
    private var likersQueryInProgress: Bool
    
    private var commentTextField: UITextField?
    private var headerView: PAPPhotoDetailsHeaderView?

    // MARK:- Initialization

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PAPUtilityUserLikedUnlikedPhotoCallbackFinishedNotification, object: self.photo!)
    }
    
    init(photo aPhoto: PFObject) {
        self.likersQueryInProgress = false
        
        // FIXME: Why can't I call this // super.init(style: UITableViewStyle.Plain)
        super.init(style: UITableViewStyle.Plain, className: nil)
        
        // The className to query on
        self.parseClassName = kPAPActivityClassKey

        // Whether the built-in pull-to-refresh is enabled
        self.pullToRefreshEnabled = true

        // Whether the built-in pagination is enabled
        self.paginationEnabled = true
        
        // The number of comments to show per page
        self.objectsPerPage = 30
        
        self.photo = aPhoto
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK:- UIViewController
    override func viewDidLoad() {
        self.tableView!.separatorStyle = UITableViewCellSeparatorStyle.None

        super.viewDidLoad()
        
        self.navigationItem.titleView = UIImageView(image: UIImage(named: "LogoNavigationBar.png"))
        
        // Set table view properties
        let texturedBackgroundView = UIView(frame: self.view.bounds)
        texturedBackgroundView.backgroundColor = UIColor.blackColor()
        self.tableView!.backgroundView = texturedBackgroundView
        
        // Set table header
        self.headerView = PAPPhotoDetailsHeaderView(frame: PAPPhotoDetailsHeaderView.rectForView(), photo:self.photo!)
        self.headerView!.delegate = self
        
        self.tableView.tableHeaderView = self.headerView;
        
        // Set table footer
        let footerView = PAPPhotoDetailsFooterView(frame: PAPPhotoDetailsFooterView.rectForView())
        commentTextField = footerView.commentField
        commentTextField!.delegate = self
        self.tableView.tableFooterView = footerView

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Action, target: self, action: Selector("activityButtonAction:"))
        
        // Register to be notified when the keyboard will be shown to scroll the view
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillShow:"), name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("userLikedOrUnlikedPhoto:"), name: PAPUtilityUserLikedUnlikedPhotoCallbackFinishedNotification, object: self.photo)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        self.headerView!.reloadLikeBar()
        
        // we will only hit the network if we have no cached data for this photo
        let hasCachedLikers: Bool = PAPCache.sharedCache.attributesForPhoto(self.photo!) != nil
        if !hasCachedLikers {
            self.loadLikers()
        }
    }


    // MARK:- UITableViewDelegate

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.row < self.objects!.count { // A comment row
            let object: PFObject? = self.objects![indexPath.row] as? PFObject
            
            if object != nil {
                let commentString: String = object!.objectForKey(kPAPActivityContentKey) as! String
                
                let commentAuthor: PFUser? = object!.objectForKey(kPAPActivityFromUserKey) as? PFUser
                
                var nameString = ""
                if commentAuthor != nil {
                    nameString = commentAuthor!.objectForKey(kPAPUserDisplayNameKey) as! String
                }
                
                return PAPActivityCell.heightForCellWithName(nameString, contentString: commentString, cellInsetWidth: kPAPCellInsetWidth)
            }
        }
        
        // The pagination row
        return 44.0
    }


    // MARK:- PFQueryTableViewController

    override func queryForTable() -> PFQuery {
        let query = PFQuery(className: self.parseClassName!)
        query.whereKey(kPAPActivityPhotoKey, equalTo: self.photo!)
        query.includeKey(kPAPActivityFromUserKey)
        query.whereKey(kPAPActivityTypeKey, equalTo: kPAPActivityTypeComment)
        query.orderByAscending("createdAt")

        query.cachePolicy = PFCachePolicy.NetworkOnly

        // If no objects are loaded in memory, we look to the cache first to fill the table
        // and then subsequently do a query against the network.
        //
        // If there is no network connection, we will hit the cache first.
        if self.objects!.count == 0 || UIApplication.sharedApplication().delegate!.performSelector(Selector("isParseReachable")) != nil {
            query.cachePolicy = PFCachePolicy.CacheThenNetwork
        }
        
        return query
    }

    override func objectsDidLoad(error: NSError?) {
        super.objectsDidLoad(error)

        self.headerView!.reloadLikeBar()
        self.loadLikers()
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath, object: PFObject?) -> PFTableViewCell? {
        let cellID = "CommentCell"

        // Try to dequeue a cell and create one if necessary
        var cell: PAPBaseTextCell? = tableView.dequeueReusableCellWithIdentifier(cellID) as? PAPBaseTextCell
        if cell == nil {
            cell = PAPBaseTextCell(style: UITableViewCellStyle.Default, reuseIdentifier: cellID)
            cell!.cellInsetWidth = kPAPCellInsetWidth
            cell!.delegate = self
        }
        
        cell!.user = object!.objectForKey(kPAPActivityFromUserKey) as? PFUser
        cell!.setContentText(object!.objectForKey(kPAPActivityContentKey) as! String)
        cell!.setDate(object!.createdAt!)

        return cell
    }

    override func tableView(tableView: UITableView, cellForNextPageAtIndexPath indexPath: NSIndexPath) -> PFTableViewCell? {
        let CellIdentifier = "NextPageDetails"
        
        var cell: PAPLoadMoreCell? = tableView.dequeueReusableCellWithIdentifier(CellIdentifier) as? PAPLoadMoreCell
        
        if cell == nil {
            cell = PAPLoadMoreCell(style: UITableViewCellStyle.Default, reuseIdentifier: CellIdentifier)
            cell!.cellInsetWidth = kPAPCellInsetWidth
            cell!.hideSeparatorTop = true
        }
        
        return cell
    }


    // MARK:- UITextFieldDelegate

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        let trimmedComment = textField.text!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if trimmedComment.length != 0 && self.photo!.objectForKey(kPAPPhotoUserKey) != nil {
            let comment = PFObject(className: kPAPActivityClassKey)
            comment.setObject(trimmedComment, forKey: kPAPActivityContentKey) // Set comment text
            comment.setObject(self.photo!.objectForKey(kPAPPhotoUserKey)!, forKey: kPAPActivityToUserKey) // Set toUser
            comment.setObject(PFUser.currentUser()!, forKey: kPAPActivityFromUserKey) // Set fromUser
            comment.setObject(kPAPActivityTypeComment, forKey:kPAPActivityTypeKey)
            comment.setObject(self.photo!, forKey: kPAPActivityPhotoKey)
            
            let ACL = PFACL(user: PFUser.currentUser()!)
            ACL.setPublicReadAccess(true)
            ACL.setWriteAccess(true, forUser: self.photo!.objectForKey(kPAPPhotoUserKey) as! PFUser)
            comment.ACL = ACL

            PAPCache.sharedCache.incrementCommentCountForPhoto(self.photo!)
            
            // Show HUD view
            MBProgressHUD.showHUDAddedTo(self.view.superview, animated: true)
            
            // If more than 5 seconds pass since we post a comment, stop waiting for the server to respond
            let timer: NSTimer = NSTimer.scheduledTimerWithTimeInterval(5.0, target: self, selector: Selector("handleCommentTimeout:"), userInfo: ["comment": comment], repeats: false)

            comment.saveEventually { (succeeded, error) in
                timer.invalidate()
                
                if error != nil && error!.code == PFErrorCode.ErrorObjectNotFound.rawValue {
                    PAPCache.sharedCache.decrementCommentCountForPhoto(self.photo!)
                    
                    let alertController = UIAlertController(title: NSLocalizedString("Could not post comment", comment: ""), message: NSLocalizedString("This photo is no longer available", comment: ""), preferredStyle: UIAlertControllerStyle.Alert)
                    let alertAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: UIAlertActionStyle.Cancel, handler: nil)
                    alertController.addAction(alertAction)
                    self.presentViewController(alertController, animated: true, completion: nil)
                    
                    self.navigationController!.popViewControllerAnimated(true)
                }
                
                NSNotificationCenter.defaultCenter().postNotificationName(PAPPhotoDetailsViewControllerUserCommentedOnPhotoNotification, object: self.photo!, userInfo: ["comments": self.objects!.count + 1])
                
                MBProgressHUD.hideHUDForView(self.view.superview, animated: true)
                self.loadObjects()
            }
        }
        
        textField.text = ""
        return textField.resignFirstResponder()
    }


    // MARK - UIActionSheetDelegate

    // FIXME!!!!!!!!!
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        if actionSheet.tag == ActionSheetTags.MainAction.rawValue {
            if actionSheet.destructiveButtonIndex == buttonIndex {
                // prompt to delete
                let actionSheet: UIActionSheet = UIActionSheet(title: NSLocalizedString("Are you sure you want to delete this photo?", comment: ""), delegate: self, cancelButtonTitle: NSLocalizedString("Cancel", comment: ""), destructiveButtonTitle: NSLocalizedString("Yes, delete photo", comment: ""), otherButtonTitles: "")
                actionSheet.tag = ActionSheetTags.ConfirmDeleteAction.rawValue
                actionSheet.showFromTabBar(self.tabBarController!.tabBar)
            } else {
                self.activityButtonAction(actionSheet)
            }
        } else if actionSheet.tag == ActionSheetTags.ConfirmDeleteAction.rawValue {
            if actionSheet.destructiveButtonIndex == buttonIndex {
                
                self.shouldDeletePhoto()
            }
        }
    }


    // MARK:- UIScrollViewDelegate

    override func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        commentTextField!.resignFirstResponder()
    }

    // MARK:- PAPBaseTextCellDelegate

    func cell(cellView: PAPBaseTextCell, didTapUserButton aUser: PFUser) {
        self.shouldPresentAccountViewForUser(aUser)
    }

    // MARK:- PAPPhotoDetailsHeaderViewDelegate

    func photoDetailsHeaderView(headerView: PAPPhotoDetailsHeaderView, didTapUserButton button: UIButton, user: PFUser) {
        self.shouldPresentAccountViewForUser(user)
    }


    // MARK:- ()

    // FIXME
    func actionButtonAction(sender: AnyObject) {
        let actionSheet = UIActionSheet()
        actionSheet.delegate = self
        actionSheet.tag = ActionSheetTags.MainAction.rawValue
        actionSheet.destructiveButtonIndex = actionSheet.addButtonWithTitle(NSLocalizedString("Delete Photo", comment: ""))
        if NSClassFromString("UIActivityViewController") != nil {
            actionSheet.addButtonWithTitle(NSLocalizedString("Share Photo", comment: ""))
        }
        actionSheet.cancelButtonIndex = actionSheet.addButtonWithTitle(NSLocalizedString("Cancel", comment: ""))
        actionSheet.showFromTabBar(self.tabBarController!.tabBar)
    }

    func activityButtonAction(sender: AnyObject) {
        if self.photo!.objectForKey(kPAPPhotoPictureKey)!.isDataAvailable() {
            self.showShareSheet()
        } else {
            MBProgressHUD.showHUDAddedTo(self.view, animated: true)
            self.photo!.objectForKey(kPAPPhotoPictureKey)!.getDataInBackgroundWithBlock { (data, error) in
                MBProgressHUD.hideHUDForView(self.view, animated: true)
                if error == nil {
                    self.showShareSheet()
                }
            }
        }
    }

    func showShareSheet() {
        self.photo!.objectForKey(kPAPPhotoPictureKey)!.getDataInBackgroundWithBlock { (data, error) in
            if error == nil {
                var activityItems = [AnyObject]()
                            
                // Prefill caption if this is the original poster of the photo, and then only if they added a caption initially.
                if (PFUser.currentUser()!.objectId == self.photo!.objectForKey(kPAPPhotoUserKey)!.objectId) && self.objects!.count > 0 {
                    let firstActivity: PFObject = self.objects![0] as! PFObject
                    if firstActivity.objectForKey(kPAPActivityFromUserKey)!.objectId == self.photo!.objectForKey(kPAPPhotoUserKey)!.objectId {
                        let commentString = firstActivity.objectForKey(kPAPActivityContentKey)
                        activityItems.append(commentString!)
                    }
                }
                
                activityItems.append(UIImage(data: data!)!)
                activityItems.append(NSURL(string:  "https://anypic.org/#pic/\(self.photo!.objectId!)")!)
                
                let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
                self.navigationController!.presentViewController(activityViewController, animated: true, completion: nil)
            }
        }
    }

    func handleCommentTimeout(aTimer: NSTimer) {
        MBProgressHUD.hideHUDForView(self.view.superview, animated: true)
        
        let alertController = UIAlertController(title: NSLocalizedString("New Comment", comment: ""), message: NSLocalizedString("Your comment will be posted next time there is an Internet connection.", comment: ""), preferredStyle: UIAlertControllerStyle.Alert)
        let alertAction = UIAlertAction(title: NSLocalizedString("Dismiss", comment: ""), style: UIAlertActionStyle.Cancel, handler: nil)
        alertController.addAction(alertAction)
        presentViewController(alertController, animated: true, completion: nil)
    }

    func shouldPresentAccountViewForUser(user: PFUser) {
        let accountViewController = PAPAccountViewController(user: user)
        print("Presenting account view controller with user: \(user)")
        self.navigationController!.pushViewController(accountViewController, animated: true)
    }

    func backButtonAction(sender: AnyObject) {
        self.navigationController!.popViewControllerAnimated(true)
    }

    func userLikedOrUnlikedPhoto(note: NSNotification) {
        self.headerView!.reloadLikeBar()
    }

    func keyboardWillShow(note: NSNotification) {
        // Scroll the view to the comment text box
        let info = note.userInfo
        let kbSize: CGSize = (info![UIKeyboardFrameBeginUserInfoKey] as! NSValue).CGRectValue().size
        self.tableView.setContentOffset(CGPointMake(0.0, self.tableView.contentSize.height-kbSize.height), animated: true)
    }

    func loadLikers() {
        if self.likersQueryInProgress {
            return
        }

        self.likersQueryInProgress = true
        let query: PFQuery = PAPUtility.queryForActivitiesOnPhoto(photo!, cachePolicy: PFCachePolicy.NetworkOnly)
        query.findObjectsInBackgroundWithBlock { (objects, error) in
            self.likersQueryInProgress = false
            if error != nil {
                self.headerView!.reloadLikeBar()
                return
            }
            
            var likers = [PFUser]()
            var commenters = [PFUser]()
            
            var isLikedByCurrentUser = false
            
            for activity in objects! {
                if (activity.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeLike && activity.objectForKey(kPAPActivityFromUserKey) != nil {
                    likers.append(activity.objectForKey(kPAPActivityFromUserKey) as! PFUser)
                } else if (activity.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeComment && activity.objectForKey(kPAPActivityFromUserKey) != nil {
                    commenters.append(activity.objectForKey(kPAPActivityFromUserKey) as! PFUser)
                }
                
                if ((activity.objectForKey(kPAPActivityFromUserKey) as! PFObject).objectId) == PFUser.currentUser()!.objectId {
                    if (activity.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeLike {
                        isLikedByCurrentUser = true
                    }
                }
            }
            
            PAPCache.sharedCache.setAttributesForPhoto(self.photo!, likers: likers, commenters: commenters, likedByCurrentUser: isLikedByCurrentUser)
            self.headerView!.reloadLikeBar()
        }
    }

    func currentUserOwnsPhoto() -> Bool {
        return (self.photo!.objectForKey(kPAPPhotoUserKey) as! PFObject).objectId == PFUser.currentUser()!.objectId
    }

    func shouldDeletePhoto() {
        // Delete all activites related to this photo
        let query = PFQuery(className: kPAPActivityClassKey)
        query.whereKey(kPAPActivityPhotoKey, equalTo: self.photo!)
        query.findObjectsInBackgroundWithBlock { (activities, error) in
            if error == nil {
                for activity in activities! {
                    activity.deleteEventually()
                }
            }
            
            // Delete photo
            self.photo!.deleteEventually()
        }
        NSNotificationCenter.defaultCenter().postNotificationName(PAPPhotoDetailsViewControllerUserDeletedPhotoNotification, object: self.photo!.objectId)
        self.navigationController!.popViewControllerAnimated(true)
    }
}
