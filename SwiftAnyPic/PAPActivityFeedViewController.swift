import UIKit
import ParseUI
import MBProgressHUD

class PAPActivityFeedViewController: PFQueryTableViewController, PAPActivityCellDelegate {
    var settingsActionSheetDelegate: PAPSettingsActionSheetDelegate?
    var lastRefresh: NSDate?
    var blankTimelineView: UIView?
    
    // MARK:- Initialization
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: PAPAppDelegateApplicationDidReceiveRemoteNotification, object: nil)
    }
    
    override init(style: UITableViewStyle, className: String?) {
        super.init(style: style, className: className)
        // The className to query on
        self.parseClassName = kPAPActivityClassKey
        
        // Whether the built-in pagination is enabled
        self.paginationEnabled = true
        
        // Whether the built-in pull-to-refresh is enabled
        self.pullToRefreshEnabled = true
        
        // The number of objects to show per page
        self.objectsPerPage = 15
        
        // The Loading text clashes with the dark Anypic design
        self.loadingViewEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK - UIViewController
    
    override func viewDidLoad() {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyle.SingleLine
    
        super.viewDidLoad()
        
        let texturedBackgroundView = UIView(frame: self.view.bounds)
        texturedBackgroundView.backgroundColor = UIColor.blackColor()
        self.tableView.backgroundView = texturedBackgroundView
        
        self.navigationItem.titleView = UIImageView(image: UIImage(named: "LogoNavigationBar.png"))
        
        // Add Settings button
        self.navigationItem.rightBarButtonItem = PAPSettingsButtonItem(target: self, action: Selector("settingsButtonAction:"))
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("applicationDidReceiveRemoteNotification:"), name: PAPAppDelegateApplicationDidReceiveRemoteNotification, object: nil)
        
        self.blankTimelineView = UIView(frame: self.tableView.bounds)
        
        let button = UIButton(type: UIButtonType.Custom)
        button.setBackgroundImage(UIImage(named: "ActivityFeedBlank.png"), forState: UIControlState.Normal)
        button.frame = CGRectMake(24.0, 113.0, 271.0, 140.0)
        button.addTarget(self, action: Selector("inviteFriendsButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)
        self.blankTimelineView!.addSubview(button)
        
        lastRefresh = NSUserDefaults.standardUserDefaults().objectForKey(kPAPUserDefaultsActivityFeedViewControllerLastRefreshKey) as? NSDate
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.separatorColor = UIColor(red: 30.0/255.0, green: 30.0/255.0, blue: 30.0/255.0, alpha: 1.0)
    }
    
    // MARK:- UITableViewDelegate
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.row < self.objects!.count {
            let object: PFObject = self.objects![indexPath.row] as! PFObject
            let activityString: String? = PAPActivityFeedViewController.stringForActivityType(object.objectForKey(kPAPActivityTypeKey) as! String)
            
            let user: PFUser? = object.objectForKey(kPAPActivityFromUserKey) as? PFUser
            var nameString = NSLocalizedString("Someone", comment: "Someone")
            if (user?.objectForKey(kPAPUserDisplayNameKey) as? String)?.length > 0 {
                nameString = user!.objectForKey(kPAPUserDisplayNameKey) as! String
            }
            
            return PAPActivityCell.heightForCellWithName(nameString, contentString:activityString!)
        } else {
            return 44.0
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        if indexPath.row < self.objects!.count {
            let activity: PFObject = self.objects![indexPath.row] as! PFObject
            if activity.objectForKey(kPAPActivityPhotoKey) != nil {
                let detailViewController = PAPPhotoDetailsViewController(photo: activity.objectForKey(kPAPActivityPhotoKey) as! PFObject)
                self.navigationController!.pushViewController(detailViewController, animated: true)
            } else if activity.objectForKey(kPAPActivityFromUserKey) != nil {
                let detailViewController = PAPAccountViewController(user: activity.objectForKey(kPAPActivityFromUserKey) as! PFUser)
                print("Presenting account view controller with user: \(activity.objectForKey(kPAPActivityFromUserKey) as! PFUser)")
                self.navigationController!.pushViewController(detailViewController, animated: true)
            }
        } else if self.paginationEnabled {
            // load more
            self.loadNextPage()
        }
    }
    
    // MARK:- PFQueryTableViewController
    
    override func queryForTable() -> PFQuery {
        if PFUser.currentUser() == nil {
            let query = PFQuery(className: self.parseClassName!)
            query.limit = 0
            return query
        }
        
        let query = PFQuery(className: self.parseClassName!)
        query.whereKey(kPAPActivityToUserKey, equalTo: PFUser.currentUser()!)
        query.whereKey(kPAPActivityFromUserKey, notEqualTo: PFUser.currentUser()!)
        query.whereKeyExists(kPAPActivityFromUserKey)
        query.includeKey(kPAPActivityFromUserKey)
        query.includeKey(kPAPActivityPhotoKey)
        query.orderByDescending("createdAt")
        
        query.cachePolicy = PFCachePolicy.NetworkOnly
        
        // If no objects are loaded in memory, we look to the cache first to fill the table
        // and then subsequently do a query against the network.
        //
        // If there is no network connection, we will hit the cache first.
        if self.objects!.count == 0 || UIApplication.sharedApplication().delegate!.performSelector(Selector("isParseReachable")) == nil {
            query.cachePolicy = PFCachePolicy.CacheThenNetwork
        }
        
        return query
    }
    
    override func objectsDidLoad(error: NSError?) {
        super.objectsDidLoad(error)
        
        lastRefresh = NSDate()
        NSUserDefaults.standardUserDefaults().setObject(lastRefresh, forKey: kPAPUserDefaultsActivityFeedViewControllerLastRefreshKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        
        MBProgressHUD.hideHUDForView(self.view, animated: true)
        
        if self.objects!.count == 0 && !self.queryForTable().hasCachedResult() {
            self.tableView.scrollEnabled = false
            self.navigationController!.tabBarItem.badgeValue = nil
            
            if self.blankTimelineView!.superview == nil {
                self.blankTimelineView!.alpha = 0.0
                self.tableView.tableHeaderView = self.blankTimelineView
                
                UIView.animateWithDuration(0.200, animations: {
                    self.blankTimelineView!.alpha = 1.0
                })
            }
        } else {
            self.tableView.tableHeaderView = nil
            self.tableView.scrollEnabled = true
            
            var unreadCount: Int = 0
            for activity in self.objects as! [PFObject] {
                if lastRefresh!.compare(activity.createdAt!) == NSComparisonResult.OrderedAscending && (activity.objectForKey(kPAPActivityTypeKey) as! String) != kPAPActivityTypeJoined {
                    unreadCount++
                }
            }
            
            if unreadCount > 0 {
                self.navigationController!.tabBarItem.badgeValue = "\(unreadCount)"
            } else {
                self.navigationController!.tabBarItem.badgeValue = nil
            }
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath, object: PFObject?) -> PFTableViewCell? {
        let CellIdentifier = "ActivityCell"
        
        var cell: PAPActivityCell? = tableView.dequeueReusableCellWithIdentifier(CellIdentifier) as? PAPActivityCell
        if cell == nil {
            cell = PAPActivityCell(style: UITableViewCellStyle.Default, reuseIdentifier: CellIdentifier)
            cell!.delegate = self
            cell!.selectionStyle = UITableViewCellSelectionStyle.None
        }
        
        cell!.activity = object
        
        if lastRefresh!.compare(object!.createdAt!) == NSComparisonResult.OrderedAscending {
            cell!.setIsNew(true)
        } else {
            cell!.setIsNew(false)
        }
        
        cell!.hideSeparator = (indexPath.row == self.objects!.count - 1)
        
        return cell!
    }
    
    override func tableView(tableView: UITableView, cellForNextPageAtIndexPath indexPath: NSIndexPath) -> PFTableViewCell? {
        let LoadMoreCellIdentifier = "LoadMoreCell"
        
        var cell: PAPLoadMoreCell? = tableView.dequeueReusableCellWithIdentifier(LoadMoreCellIdentifier) as? PAPLoadMoreCell
        if cell == nil {
            cell = PAPLoadMoreCell(style: UITableViewCellStyle.Default, reuseIdentifier: LoadMoreCellIdentifier)
            cell!.selectionStyle = UITableViewCellSelectionStyle.None
            cell!.hideSeparatorBottom = true
            cell!.mainView!.backgroundColor = UIColor.clearColor()
        }
        return cell!
    }
    
    // MARK:- PAPActivityCellDelegate Methods
    
    func cell(cellView: PAPActivityCell, didTapActivityButton activity: PFObject) {
        // Get image associated with the activity
        let photo: PFObject = activity.objectForKey(kPAPActivityPhotoKey) as! PFObject
        
        // Push single photo view controller
        let photoViewController = PAPPhotoDetailsViewController(photo: photo)
        self.navigationController!.pushViewController(photoViewController, animated: true)
    }
    
    func cell(cellView: PAPBaseTextCell, didTapUserButton aUser: PFUser) {
        // Push account view controller
        let accountViewController = PAPAccountViewController(user: aUser)
        print("Presenting account view controller with user: \(aUser)")
        self.navigationController!.pushViewController(accountViewController, animated: true)
    }
    
    
    // MARK:- PAPActivityFeedViewController
    
    class func stringForActivityType(activityType: String) -> String? {
        if activityType == kPAPActivityTypeLike {
            return NSLocalizedString("liked your photo", comment: "")
        } else if activityType == kPAPActivityTypeFollow {
            return NSLocalizedString("started following you", comment: "")
        } else if activityType == kPAPActivityTypeComment {
            return NSLocalizedString("commented on your photo", comment: "")
        } else if activityType == kPAPActivityTypeJoined {
            return NSLocalizedString("joined Anypic", comment: "")
        } else {
            return nil
        }
    }
    
    // MARK:- ()
    
    func settingsButtonAction(sender: AnyObject) {
        self.settingsActionSheetDelegate = PAPSettingsActionSheetDelegate(navigationController: self.navigationController)
        let actionSheet = UIActionSheet(title: nil, delegate: self.settingsActionSheetDelegate, cancelButtonTitle: nil, destructiveButtonTitle: nil, otherButtonTitles: NSLocalizedString("My Profile", comment: ""), NSLocalizedString("Find Friends", comment: ""), NSLocalizedString("Log Out", comment: ""))
        actionSheet.cancelButtonIndex = actionSheet.addButtonWithTitle("Cancel")
        actionSheet.showFromTabBar(self.tabBarController!.tabBar)
    }
    
    func inviteFriendsButtonAction(sender: AnyObject) {
        let detailViewController = PAPFindFriendsViewController(style: UITableViewStyle.Plain)
        self.navigationController!.pushViewController(detailViewController, animated: true)
    }
    
    func applicationDidReceiveRemoteNotification(note: NSNotification) {
        self.loadObjects()
    }
}
