import UIKit
import MessageUI
import ParseUI
import AddressBookUI
import MBProgressHUD
import Synchronized

enum PAPFindFriendsFollowStatus: Int {
    case FollowingNone = 0, // User isn't following anybody in Friends list
         FollowingAll,      // User is following all Friends
         FollowingSome      // User is following some of their Friends
}

class PAPFindFriendsViewController: PFQueryTableViewController, PAPFindFriendsCellDelegate, ABPeoplePickerNavigationControllerDelegate, MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate, UIActionSheetDelegate {
    private var headerView: UIView?
    private var followStatus: PAPFindFriendsFollowStatus
    private var selectedEmailAddress: String
    private var outstandingFollowQueries: [NSObject: AnyObject]
    private var outstandingCountQueries: [NSIndexPath: AnyObject]

    // MARK:- Initialization

    init(style: UITableViewStyle) {
        self.selectedEmailAddress = ""
        
        // Used to determine Follow/Unfollow All button status
        self.followStatus = PAPFindFriendsFollowStatus.FollowingSome
        self.outstandingFollowQueries = [NSObject: AnyObject]()
        self.outstandingCountQueries = [NSIndexPath: AnyObject]()
        
        super.init(style: style, className: nil)

        // Whether the built-in pull-to-refresh is enabled
        self.pullToRefreshEnabled = true

        // The number of objects to show per page
        self.objectsPerPage = 15
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    // MARK:- UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.separatorStyle = UITableViewCellSeparatorStyle.None
        self.tableView.backgroundColor = UIColor.blackColor()

        self.navigationItem.titleView = UIImageView(image: UIImage(named: "TitleFindFriends.png"))
    
        if self.navigationController!.viewControllers[0] == self {
            let dismissLeftBarButtonItem = UIBarButtonItem(title: "Back", style: UIBarButtonItemStyle.Plain, target: self, action: Selector("dismissPresentingViewController"))
            self.navigationItem.leftBarButtonItem = dismissLeftBarButtonItem
        } else {
            self.navigationItem.leftBarButtonItem = nil
        }

        if MFMailComposeViewController.canSendMail() || MFMessageComposeViewController.canSendText() {
            self.headerView = UIView(frame: CGRectMake(0, 0, 320, 67))
            self.headerView!.backgroundColor = UIColor.blackColor()
            let clearButton = UIButton(type: UIButtonType.Custom)
            clearButton.backgroundColor = UIColor.clearColor()
            clearButton.addTarget(self, action: Selector("inviteFriendsButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)
            clearButton.frame = self.headerView!.frame
            self.headerView!.addSubview(clearButton)
            let inviteString = NSLocalizedString("Invite friends", comment: "Invite friends")
            let boundingRect: CGRect = inviteString.boundingRectWithSize(CGSizeMake(310.0, CGFloat.max),
                                                             options: [NSStringDrawingOptions.TruncatesLastVisibleLine, NSStringDrawingOptions.UsesLineFragmentOrigin],
                                                          attributes: [NSFontAttributeName: UIFont.boldSystemFontOfSize(18.0)],
                                                             context: nil)
            let inviteStringSize: CGSize = boundingRect.size

            let inviteLabel = UILabel(frame: CGRectMake(10, (self.headerView!.frame.size.height-inviteStringSize.height)/2, inviteStringSize.width, inviteStringSize.height))
            inviteLabel.text = inviteString
            inviteLabel.font = UIFont.boldSystemFontOfSize(18)
            inviteLabel.textColor = UIColor.whiteColor()
            inviteLabel.backgroundColor = UIColor.clearColor()
            self.headerView!.addSubview(inviteLabel)
            self.tableView!.tableHeaderView = self.headerView
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.separatorColor = UIColor(red: 30.0/255.0, green: 30.0/255.0, blue: 30.0/255.0, alpha: 1.0)
    }

    func dismissPresentingViewController() {
        self.navigationController!.dismissViewControllerAnimated(true, completion: nil)
    }

    // MARK:- UITableViewDelegate

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.row < self.objects!.count {
            return PAPFindFriendsCell.heightForCell()
        } else {
            return 44.0
        }
    }

    // MARK:- PFQueryTableViewController

    override func queryForTable() -> PFQuery {
        // Use cached facebook friend ids
        let facebookFriends: [PFUser]? = PAPCache.sharedCache.facebookFriends()

        // Query for all friends you have on facebook and who are using the app
        let friendsQuery: PFQuery = PFUser.query()!
        friendsQuery.whereKey(kPAPUserFacebookIDKey, containedIn: facebookFriends!)

        // Query for all Parse employees
        var parseEmployees: [String] = kPAPParseEmployeeAccounts
        let currentUserFacebookId = PFUser.currentUser()!.objectForKey(kPAPUserFacebookIDKey) as! String
        parseEmployees = parseEmployees.filter { (facebookId) in facebookId != currentUserFacebookId }
        let parseEmployeeQuery: PFQuery = PFUser.query()!
        parseEmployeeQuery.whereKey(kPAPUserFacebookIDKey, containedIn: parseEmployees)

        let query: PFQuery = PFQuery.orQueryWithSubqueries([friendsQuery, parseEmployeeQuery])
        query.cachePolicy = PFCachePolicy.NetworkOnly

        if self.objects!.count == 0 {
            query.cachePolicy = PFCachePolicy.CacheThenNetwork
        }

        query.orderByAscending(kPAPUserDisplayNameKey)

        return query
    }

    override func objectsDidLoad(error: NSError?) {
        super.objectsDidLoad(error)

        let isFollowingQuery = PFQuery(className: kPAPActivityClassKey)
        isFollowingQuery.whereKey(kPAPActivityFromUserKey, equalTo: PFUser.currentUser()!)
        isFollowingQuery.whereKey(kPAPActivityTypeKey, equalTo: kPAPActivityTypeFollow)
        isFollowingQuery.whereKey(kPAPActivityToUserKey, containedIn: self.objects!)
        isFollowingQuery.cachePolicy = PFCachePolicy.NetworkOnly

        isFollowingQuery.countObjectsInBackgroundWithBlock { (number, error) in
            if error == nil {
                if Int(number) == self.objects!.count {
                    self.followStatus = PAPFindFriendsFollowStatus.FollowingAll
                    self.configureUnfollowAllButton()
                    for user in self.objects as! [PFUser] {
                        PAPCache.sharedCache.setFollowStatus(true, user: user)
                    }
                } else if number == 0 {
                    self.followStatus = PAPFindFriendsFollowStatus.FollowingNone
                    self.configureFollowAllButton()
                    for user in self.objects as! [PFUser] {
                        PAPCache.sharedCache.setFollowStatus(false, user: user)
                    }
                } else {
                    self.followStatus = PAPFindFriendsFollowStatus.FollowingSome
                    self.configureFollowAllButton()
                }
            }

            if self.objects!.count == 0 {
                self.navigationItem.rightBarButtonItem = nil
            }
        }

        if self.objects!.count == 0 {
            self.navigationItem.rightBarButtonItem = nil
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath, object: PFObject?) -> PFTableViewCell? {
        let FriendCellIdentifier = "FriendCell"

        var cell: PAPFindFriendsCell? = tableView.dequeueReusableCellWithIdentifier(FriendCellIdentifier) as? PAPFindFriendsCell
        if cell == nil {
            cell = PAPFindFriendsCell(style: UITableViewCellStyle.Default, reuseIdentifier: FriendCellIdentifier)
            cell!.delegate = self
        }

        cell!.user = object as? PFUser

        cell!.photoLabel!.text = "0 photos"

        let attributes: [NSObject: AnyObject]? = PAPCache.sharedCache.attributesForUser(object as! PFUser)

        if attributes != nil {
            // set them now
            let number = PAPCache.sharedCache.photoCountForUser(object as! PFUser)
            let appendS = number == 1 ? "": "s"
            cell!.photoLabel.text = "\(number) photo\(appendS)"
        } else {
            synchronized(self) {
                let outstandingCountQueryStatus: Int? = self.outstandingCountQueries[indexPath] as? Int
                if outstandingCountQueryStatus == nil {
                    self.outstandingCountQueries[indexPath] = true
                    let photoNumQuery = PFQuery(className: kPAPPhotoClassKey)
                    photoNumQuery.whereKey(kPAPPhotoUserKey, equalTo: object!)
                    photoNumQuery.cachePolicy = PFCachePolicy.CacheThenNetwork
                    photoNumQuery.countObjectsInBackgroundWithBlock { (number, error) in
                        synchronized(self) {
                            PAPCache.sharedCache.setPhotoCount(Int(number), user: object as! PFUser)
                            self.outstandingCountQueries.removeValueForKey(indexPath)
                        }
                        let actualCell: PAPFindFriendsCell? = tableView.cellForRowAtIndexPath(indexPath) as? PAPFindFriendsCell
                        let appendS = number == 1 ? "" : "s"
                        actualCell?.photoLabel?.text = "\(number) photo\(appendS)"
                    }
                }
            }
        }

        cell!.followButton.selected = false
        cell!.tag = indexPath.row

        if self.followStatus == PAPFindFriendsFollowStatus.FollowingSome {
            if attributes != nil {
                cell!.followButton.selected = PAPCache.sharedCache.followStatusForUser(object as! PFUser)
            } else {
                synchronized(self) {
                    let outstandingQuery: Int? = self.outstandingFollowQueries[indexPath] as? Int
                    if outstandingQuery == nil {
                        self.outstandingFollowQueries[indexPath] = true
                        let isFollowingQuery = PFQuery(className: kPAPActivityClassKey)
                        isFollowingQuery.whereKey(kPAPActivityFromUserKey, equalTo: PFUser.currentUser()!)
                        isFollowingQuery.whereKey(kPAPActivityTypeKey, equalTo: kPAPActivityTypeFollow)
                        isFollowingQuery.whereKey(kPAPActivityToUserKey, equalTo: object!)
                        isFollowingQuery.cachePolicy = PFCachePolicy.CacheThenNetwork

                        isFollowingQuery.countObjectsInBackgroundWithBlock { (number, error) in
                            synchronized(self) {
                                self.outstandingFollowQueries.removeValueForKey(indexPath)
                                PAPCache.sharedCache.setFollowStatus((error == nil && number > 0), user: object as! PFUser)
                            }
                            if cell!.tag == indexPath.row {
                                cell!.followButton.selected = (error == nil && number > 0)
                            }
                        }
                    }
                }
            }
        } else {
            cell!.followButton.selected = (self.followStatus == PAPFindFriendsFollowStatus.FollowingAll)
        }

        return cell!
    }

    override func tableView(tableView: UITableView, cellForNextPageAtIndexPath indexPath: NSIndexPath) -> PFTableViewCell? {
        let NextPageCellIdentifier = "NextPageCell"

        var cell: PAPLoadMoreCell? = tableView.dequeueReusableCellWithIdentifier(NextPageCellIdentifier) as? PAPLoadMoreCell

        if cell == nil {
            cell = PAPLoadMoreCell(style: UITableViewCellStyle.Default, reuseIdentifier: NextPageCellIdentifier)
            cell!.mainView!.backgroundColor = UIColor.blackColor()
            cell!.hideSeparatorBottom = true
            cell!.hideSeparatorTop = true
        }

        cell!.selectionStyle = UITableViewCellSelectionStyle.None

        return cell!
    }


    // MARK:- PAPFindFriendsCellDelegate

    func cell(cellView: PAPFindFriendsCell, didTapUserButton aUser: PFUser) {
        // Push account view controller
        let accountViewController = PAPAccountViewController(user: aUser)
        print("Presenting account view controller with user: \(aUser)")
        self.navigationController!.pushViewController(accountViewController, animated: true)
    }

    func cell(cellView: PAPFindFriendsCell, didTapFollowButton aUser: PFUser) {
        self.shouldToggleFollowFriendForCell(cellView)
    }


    // MARK:- ABPeoplePickerDelegate

    /* Called when the user cancels the address book view controller. We simply dismiss it. */
    // FIXME!!!!!!!!!
    func peoplePickerNavigationControllerDidCancel(peoplePicker: ABPeoplePickerNavigationController) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    /* Called when a member of the address book is selected, we return YES to display the member's details. */
    func peoplePickerNavigationController(peoplePicker: ABPeoplePickerNavigationController, shouldContinueAfterSelectingPerson person: ABRecord) -> Bool {
        return true
    }

    /* Called when the user selects a property of a person in their address book (ex. phone, email, location,...)
       This method will allow them to send a text or email inviting them to Anypic.  */
    func peoplePickerNavigationController(peoplePicker: ABPeoplePickerNavigationController, shouldContinueAfterSelectingPerson person: ABRecord, property: ABPropertyID, identifier: ABMultiValueIdentifier) -> Bool {
//        if property == kABPersonEmailProperty {
//            let emailProperty: ABMultiValueRef = ABRecordCopyValue(person,property)
//            let email = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(emailProperty,identifier);
//            self.selectedEmailAddress = email;
//
//            if ([MFMailComposeViewController canSendMail] && [MFMessageComposeViewController canSendText]) {
//                // ask user
//                UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"Invite %@",@""] delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Email", @"iMessage", nil];
//                [actionSheet showFromTabBar:self.tabBarController.tabBar];
//            } else if ([MFMailComposeViewController canSendMail]) {
//                // go directly to mail
//                [self presentMailComposeViewController:email];
//            } else if ([MFMessageComposeViewController canSendText]) {
//                // go directly to iMessage
//                [self presentMessageComposeViewController:email];
//            }
//
//        } else if (property == kABPersonPhoneProperty) {
//            ABMultiValueRef phoneProperty = ABRecordCopyValue(person,property);
//            NSString *phone = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(phoneProperty,identifier);
//
//            if ([MFMessageComposeViewController canSendText]) {
//                [self presentMessageComposeViewController:phone];
//            }
//        }

        return false
    }

    // MARK:- MFMailComposeDelegate
    
    /* Simply dismiss the MFMailComposeViewController when the user sends an email or cancels */
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }


    // MARK:- MFMessageComposeDelegate

    /* Simply dismiss the MFMessageComposeViewController when the user sends a text or cancels */
    func messageComposeViewController(controller: MFMessageComposeViewController, didFinishWithResult result: MessageComposeResult) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }


    // MARK:- UIActionSheetDelegate

    // FIXME!!!!!!!!
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        if buttonIndex == actionSheet.cancelButtonIndex {
            return
        }

        if buttonIndex == 0 {
            self.presentMailComposeViewController(self.selectedEmailAddress)
        } else if buttonIndex == 1 {
            self.presentMessageComposeViewController(self.selectedEmailAddress)
        }
    }

    // MARK:- ()

    func backButtonAction(sender: AnyObject) {
        self.navigationController!.popViewControllerAnimated(true)
    }

    func inviteFriendsButtonAction(sender: AnyObject) {
        let addressBook = ABPeoplePickerNavigationController()
        addressBook.peoplePickerDelegate = self

        if MFMailComposeViewController.canSendMail() && MFMessageComposeViewController.canSendText() {
            addressBook.displayedProperties = [Int(kABPersonEmailProperty), Int(kABPersonPhoneProperty)]
        } else if MFMailComposeViewController.canSendMail() {
            addressBook.displayedProperties = [Int(kABPersonEmailProperty)]
        } else if MFMessageComposeViewController.canSendText() {
            addressBook.displayedProperties = [Int(kABPersonPhoneProperty)]
        }

        self.presentViewController(addressBook, animated: true, completion: nil)
    }

    func followAllFriendsButtonAction(sender: AnyObject) {
        MBProgressHUD.showHUDAddedTo(UIApplication.sharedApplication().keyWindow, animated: true)

        self.followStatus = PAPFindFriendsFollowStatus.FollowingAll
        self.configureUnfollowAllButton()

        let popTime: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(0.01 * Double(NSEC_PER_SEC)))
        dispatch_after(popTime, dispatch_get_main_queue(), {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Unfollow All", style: UIBarButtonItemStyle.Plain, target: self, action: Selector("unfollowAllFriendsButtonAction:"))

            var indexPaths = Array<NSIndexPath>(count: self.objects!.count, repeatedValue: NSIndexPath())
            for var r = 0; r < self.objects!.count; r++ {
                let user: PFObject = self.objects![r] as! PFObject
                let indexPath: NSIndexPath = NSIndexPath(forRow: r, inSection: 0)
                let cell: PAPFindFriendsCell? = self.tableView(self.tableView, cellForRowAtIndexPath: indexPath, object: user) as? PAPFindFriendsCell
                cell!.followButton.selected = true
                indexPaths.append(indexPath)
            }

            self.tableView.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: UITableViewRowAnimation.None)
            MBProgressHUD.hideAllHUDsForView(UIApplication.sharedApplication().keyWindow, animated: true)

            let timer: NSTimer = NSTimer.scheduledTimerWithTimeInterval(2.0, target: self, selector: Selector("followUsersTimerFired:"), userInfo: nil, repeats: false)
            PAPUtility.followUsersEventually(self.objects as! [PFUser], block: { (succeeded, error) in
                // note -- this block is called once for every user that is followed successfully. We use a timer to only execute the completion block once no more saveEventually blocks have been called in 2 seconds
                timer.fireDate = NSDate(timeIntervalSinceNow: 2.0)
            })
        })
    }

    func unfollowAllFriendsButtonAction(sender: AnyObject) {
        MBProgressHUD.showHUDAddedTo(UIApplication.sharedApplication().keyWindow, animated: true)

        self.followStatus = PAPFindFriendsFollowStatus.FollowingNone
        self.configureFollowAllButton()

        let popTime: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(0.01 * Double(NSEC_PER_SEC)))
        dispatch_after(popTime, dispatch_get_main_queue(), {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Follow All", style: UIBarButtonItemStyle.Plain, target: self, action: Selector("followAllFriendsButtonAction:"))

            var indexPaths: [NSIndexPath] = Array<NSIndexPath>(count: self.objects!.count, repeatedValue: NSIndexPath())
            for var r = 0; r < self.objects!.count; r++ {
                let user: PFObject = self.objects![r] as! PFObject
                let indexPath: NSIndexPath = NSIndexPath(forRow: r, inSection: 0)
                let cell: PAPFindFriendsCell = self.tableView(self.tableView, cellForRowAtIndexPath: indexPath, object: user) as! PAPFindFriendsCell
                cell.followButton.selected = false
                indexPaths.append(indexPath)
            }

            self.tableView.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: UITableViewRowAnimation.None)
            MBProgressHUD.hideAllHUDsForView(UIApplication.sharedApplication().keyWindow, animated: true)

            PAPUtility.unfollowUsersEventually(self.objects as! [PFUser])

            NSNotificationCenter.defaultCenter().postNotificationName(PAPUtilityUserFollowingChangedNotification, object: nil)
        })
    }

    func shouldToggleFollowFriendForCell(cell: PAPFindFriendsCell) {
        let cellUser: PFUser = cell.user!
        if cell.followButton.selected {
            // Unfollow
            cell.followButton.selected = false
            PAPUtility.unfollowUserEventually(cellUser)
            NSNotificationCenter.defaultCenter().postNotificationName(PAPUtilityUserFollowingChangedNotification, object: nil)
        } else {
            // Follow
            cell.followButton.selected = true
            PAPUtility.followUserEventually(cellUser, block: { (succeeded, error) in
                if error == nil {
                    NSNotificationCenter.defaultCenter().postNotificationName(PAPUtilityUserFollowingChangedNotification, object: nil)
                } else {
                    cell.followButton.selected = false
                }
            })
        }
    }

    func configureUnfollowAllButton() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Unfollow All", style: UIBarButtonItemStyle.Plain, target: self, action: Selector("unfollowAllFriendsButtonAction:"))
    }

    func configureFollowAllButton() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Follow All", style: UIBarButtonItemStyle.Plain, target: self, action: Selector("followAllFriendsButtonAction:"))
    }

    func presentMailComposeViewController(recipient: String) {
        // Create the compose email view controller
        let composeEmailViewController = MFMailComposeViewController()

        // Set the recipient to the selected email and a default text
        composeEmailViewController.mailComposeDelegate = self
        composeEmailViewController.setSubject("Join me on Anypic")
        composeEmailViewController.setToRecipients([recipient])
        composeEmailViewController.setMessageBody("<h2>Share your pictures, share your story.</h2><p><a href=\"http://anypic.org\">Anypic</a> is the easiest way to share photos with your friends. Get the app and share your fun photos with the world.</p><p><a href=\"http://anypic.org\">Anypic</a> is fully powered by <a href=\"http://parse.com\">Parse</a>.</p>", isHTML: true)

        // Dismiss the current modal view controller and display the compose email one.
        // Note that we do not animate them. Doing so would require us to present the compose
        // mail one only *after* the address book is dismissed.
        self.dismissViewControllerAnimated(false, completion: nil)
        self.presentViewController(composeEmailViewController, animated: false, completion: nil)
    }

    func presentMessageComposeViewController(recipient: String) {
        // Create the compose text message view controller
        let composeTextViewController = MFMessageComposeViewController()

        // Send the destination phone number and a default text
        composeTextViewController.messageComposeDelegate = self
        composeTextViewController.recipients = [recipient]
        composeTextViewController.body = "Check out Anypic! http://anypic.org"

        // Dismiss the current modal view controller and display the compose text one.
        // See previous use for reason why these are not animated.
        self.dismissViewControllerAnimated(false, completion: nil)
        self.presentViewController(composeTextViewController, animated: false, completion: nil)
    }

    func followUsersTimerFired(timer: NSTimer) {
        self.tableView.reloadData()
        NSNotificationCenter.defaultCenter().postNotificationName(PAPUtilityUserFollowingChangedNotification, object: nil)
    }
}
