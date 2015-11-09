import UIKit
import ParseUI
import Synchronized

class PAPPhotoTimelineViewController: PFQueryTableViewController, PAPPhotoHeaderViewDelegate {
    var shouldReloadOnAppear: Bool = false
    var reusableSectionHeaderViews: Set<PAPPhotoHeaderView>!
    var outstandingSectionHeaderQueries: [NSObject:AnyObject]

    // MARK:- Initialization

    deinit {
        let defaultNotificationCenter = NSNotificationCenter.defaultCenter()
        defaultNotificationCenter.removeObserver(self, name: PAPTabBarControllerDidFinishEditingPhotoNotification, object: nil)
        defaultNotificationCenter.removeObserver(self, name: PAPUtilityUserFollowingChangedNotification, object: nil)
        defaultNotificationCenter.removeObserver(self, name: PAPPhotoDetailsViewControllerUserLikedUnlikedPhotoNotification, object: nil)
        defaultNotificationCenter.removeObserver(self, name: PAPUtilityUserLikedUnlikedPhotoCallbackFinishedNotification, object: nil)
        defaultNotificationCenter.removeObserver(self, name: PAPPhotoDetailsViewControllerUserCommentedOnPhotoNotification, object: nil)
        defaultNotificationCenter.removeObserver(self, name: PAPPhotoDetailsViewControllerUserDeletedPhotoNotification, object: nil)
    }

    // FIXME: Why can't find - (id)initWithStyle:(UITableViewStyle)style {
    override init(style: UITableViewStyle, className: String?) {
        self.outstandingSectionHeaderQueries = [NSObject:AnyObject]()
        
        super.init(style: style, className: kPAPPhotoClassKey)
        
        // The className to query on
        self.parseClassName = kPAPPhotoClassKey
        
        // Whether the built-in pull-to-refresh is enabled
        self.pullToRefreshEnabled = true

        // Whether the built-in pagination is enabled
        self.paginationEnabled = false
        
        // The number of objects to show per page
        // self.objectsPerPage = 10
        
        // Improve scrolling performance by reusing UITableView section headers
        self.reusableSectionHeaderViews = Set<PAPPhotoHeaderView>(minimumCapacity: 3)
        
        // The Loading text clashes with the dark Anypic design
        self.loadingViewEnabled = false

        self.shouldReloadOnAppear = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK:- UIViewController

    override func viewDidLoad() {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyle.None
        
        super.viewDidLoad()
        
        let texturedBackgroundView = UIView(frame: self.view.bounds)
        texturedBackgroundView.backgroundColor = UIColor(red: 0.0/255.0, green: 0.0/255.0, blue: 0.0/255.0, alpha: 1.0)
        self.tableView.backgroundView = texturedBackgroundView

        let defaultNotificationCenter = NSNotificationCenter.defaultCenter()
        defaultNotificationCenter.addObserver(self, selector: Selector("userDidPublishPhoto:"), name: PAPTabBarControllerDidFinishEditingPhotoNotification, object: nil)
        defaultNotificationCenter.addObserver(self, selector: Selector("userFollowingChanged:"), name: PAPUtilityUserFollowingChangedNotification, object: nil)
        defaultNotificationCenter.addObserver(self, selector: Selector("userDidDeletePhoto:"), name: PAPPhotoDetailsViewControllerUserDeletedPhotoNotification, object: nil)
        defaultNotificationCenter.addObserver(self, selector: Selector("userDidLikeOrUnlikePhoto:"), name: PAPPhotoDetailsViewControllerUserLikedUnlikedPhotoNotification, object: nil)
        defaultNotificationCenter.addObserver(self, selector: Selector("userDidLikeOrUnlikePhoto:"), name: PAPUtilityUserLikedUnlikedPhotoCallbackFinishedNotification, object: nil)
        defaultNotificationCenter.addObserver(self, selector: Selector("userDidCommentOnPhoto:"), name: PAPPhotoDetailsViewControllerUserCommentedOnPhotoNotification, object: nil)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.shouldReloadOnAppear {
            self.shouldReloadOnAppear = false
            self.loadObjects()
        }
    }

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    

    // MARK:- UITableViewDataSource

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.objects!.count * 2 + (self.paginationEnabled ? 1 : 0)
    }


    // MARK:- UITableViewDelegate

    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0
    }

    override func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0
    }
    override func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if self.paginationEnabled && (self.objects!.count * 2) == indexPath.row {
            // Load More Section
            return 44.0
        } else if indexPath.row % 2 == 0 {
            return 44.0
        }
        
        return 320.0
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        super.tableView(tableView, didSelectRowAtIndexPath: indexPath)

        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        if self.objectAtIndexPath(indexPath) == nil {
            // Load More Cell
            self.loadNextPage()
        }
    }


    // MARK:- PFQueryTableViewController

    override func queryForTable() -> PFQuery {
        if (PFUser.currentUser() == nil) {
            let query = PFQuery(className: self.parseClassName!)
            query.limit = 0
            return query
        }
        
        let followingActivitiesQuery = PFQuery(className: kPAPActivityClassKey)
        followingActivitiesQuery.whereKey(kPAPActivityTypeKey, equalTo: kPAPActivityTypeFollow)
        followingActivitiesQuery.whereKey(kPAPActivityFromUserKey, equalTo: PFUser.currentUser()!)
        followingActivitiesQuery.cachePolicy = PFCachePolicy.NetworkOnly
        followingActivitiesQuery.limit = 1000

        let autoFollowUsersQuery = PFUser.query()
        autoFollowUsersQuery!.whereKey(kPAPUserAutoFollowKey, equalTo: true)

        let photosFromFollowedUsersQuery = PFQuery(className: self.parseClassName!)
        photosFromFollowedUsersQuery.whereKey(kPAPPhotoUserKey, matchesKey: kPAPActivityToUserKey, inQuery: followingActivitiesQuery)
        photosFromFollowedUsersQuery.whereKeyExists(kPAPPhotoPictureKey)

        let photosFromCurrentUserQuery = PFQuery(className: self.parseClassName!)
        photosFromCurrentUserQuery.whereKey(kPAPPhotoUserKey, equalTo: PFUser.currentUser()!)
        photosFromCurrentUserQuery.whereKeyExists(kPAPPhotoPictureKey)

        let query = PFQuery.orQueryWithSubqueries([photosFromFollowedUsersQuery, photosFromCurrentUserQuery])
        query.limit = 30
        query.includeKey(kPAPPhotoUserKey)
        query.orderByDescending("createdAt")

        // A pull-to-refresh should always trigger a network request.
        query.cachePolicy = PFCachePolicy.NetworkOnly

        // If no objects are loaded in memory, we look to the cache first to fill the table
        // and then subsequently do a query against the network.
        //
        // If there is no network connection, we will hit the cache first.
        if self.objects!.count == 0 || (UIApplication.sharedApplication().delegate!.performSelector(Selector("isParseReachable")) == nil) {
            query.cachePolicy = PFCachePolicy.CacheThenNetwork
        }

        /*
         This query will result in an error if the schema hasn't been set beforehand. While Parse usually handles this automatically, this is not the case for a compound query such as this one. The error thrown is:
         
         Error: bad special key: __type
         
         To set up your schema, you may post a photo with a caption. This will automatically set up the Photo and Activity classes needed by this query.
         
         You may also use the Data Browser at Parse.com to set up your classes in the following manner.
         
         Create a User class: "User" (if it does not exist)
         
         Create a Custom class: "Activity"
         - Add a column of type pointer to "User", named "fromUser"
         - Add a column of type pointer to "User", named "toUser"
         - Add a string column "type"
         
         Create a Custom class: "Photo"
         - Add a column of type pointer to "User", named "user"
         
         You'll notice that these correspond to each of the fields used by the preceding query.
         */

        return query
    }

    override func objectAtIndexPath(indexPath: NSIndexPath?) -> PFObject? {
        let index = self.indexForObjectAtIndexPath(indexPath!)
        if (index < self.objects!.count) {
            return self.objects![index] as? PFObject
        }
        
        return nil
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath, object: PFObject?) -> PFTableViewCell? {
        let CellIdentifier = "Cell"

        let index = self.indexForObjectAtIndexPath(indexPath)

        if indexPath.row % 2 == 0 {
            // Header
            return self.detailPhotoCellForRowAtIndexPath(indexPath)
        } else {
            // Photo
            var cell: PAPPhotoCell? = tableView.dequeueReusableCellWithIdentifier(CellIdentifier) as? PAPPhotoCell

            if cell == nil {
                cell = PAPPhotoCell(style: UITableViewCellStyle.Default, reuseIdentifier: CellIdentifier)
                cell!.photoButton!.addTarget(self, action: Selector("didTapOnPhotoAction:"), forControlEvents: UIControlEvents.TouchUpInside)
            }

            cell!.photoButton!.tag = index
            cell!.imageView!.image = UIImage(named: "PlaceholderPhoto.png")
            
            if object != nil {
                cell!.imageView!.file = object!.objectForKey(kPAPPhotoPictureKey) as? PFFile
                
                // PFQTVC will take care of asynchronously downloading files, but will only load them when the tableview is not moving. If the data is there, let's load it right away.
                if cell!.imageView!.file!.isDataAvailable {
                    cell!.imageView!.loadInBackground()
                }
            }

            return cell
        }
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
        return cell
    }


    // MARK:- PAPPhotoTimelineViewController

    func dequeueReusableSectionHeaderView() -> PAPPhotoHeaderView? {
        for sectionHeaderView: PAPPhotoHeaderView in self.reusableSectionHeaderViews {
            if sectionHeaderView.superview == nil {
                // we found a section header that is no longer visible
                return sectionHeaderView
            }
        }
        
        return nil
    }


    // MARK:- PAPPhotoHeaderViewDelegate

    func photoHeaderView(photoHeaderView: PAPPhotoHeaderView, didTapUserButton button: UIButton, user: PFUser) {
        let accountViewController: PAPAccountViewController = PAPAccountViewController(user: user)
        print("Presenting account view controller with user: \(user)")
        self.navigationController!.pushViewController(accountViewController, animated: true)
    }

    func photoHeaderView(photoHeaderView: PAPPhotoHeaderView, didTapLikePhotoButton button: UIButton, photo: PFObject) {
        photoHeaderView.shouldEnableLikeButton(false)
        
        let liked: Bool = !button.selected
        photoHeaderView.setLikeStatus(liked)
        
        let originalButtonTitle = button.titleLabel!.text
        
        // FIXME: to be removed!
//        let numberFormatter = NSNumberFormatter()
//        numberFormatter.locale = NSLocale(localeIdentifier: "en_US")
//        let likeCount: Int = numberFormatter.numberFromString(button.titleLabel!.text!)
        
        var likeCount: Int = Int(button.titleLabel!.text!)!
        if (liked) {
            likeCount++
            PAPCache.sharedCache.incrementLikerCountForPhoto(photo)
        } else {
            if likeCount > 0 {
                likeCount--
            }
            PAPCache.sharedCache.decrementLikerCountForPhoto(photo)
        }
        
        PAPCache.sharedCache.setPhotoIsLikedByCurrentUser(photo, liked: liked)
        
        button.setTitle(String(likeCount), forState: UIControlState.Normal)
        
        if liked {
            PAPUtility.likePhotoInBackground(photo, block: { (succeeded, error) in
                // FIXME: nil??? same as the original AnyPic. Dead code?
                let actualHeaderView: PAPPhotoHeaderView? = self.tableView(self.tableView, viewForHeaderInSection: button.tag) as? PAPPhotoHeaderView
                actualHeaderView?.shouldEnableLikeButton(true)
                actualHeaderView?.setLikeStatus(succeeded)
                
                if !succeeded {
                    actualHeaderView?.likeButton!.setTitle(originalButtonTitle, forState: UIControlState.Normal)
                }
            })
        } else {
            PAPUtility.unlikePhotoInBackground(photo, block: { (succeeded, error) in
                // FIXME: nil??? same as the original AnyPic. Dead code?
                let actualHeaderView: PAPPhotoHeaderView? = self.tableView(self.tableView, viewForHeaderInSection: button.tag) as? PAPPhotoHeaderView
                actualHeaderView?.shouldEnableLikeButton(false)
                actualHeaderView?.setLikeStatus(!succeeded)
                
                if !succeeded {
                    actualHeaderView?.likeButton!.setTitle(originalButtonTitle, forState: UIControlState.Normal)
                }
            })
        }
    }

    func photoHeaderView(photoHeaderView: PAPPhotoHeaderView, didTapCommentOnPhotoButton buton: UIButton, photo: PFObject) {
        let photoDetailsVC: PAPPhotoDetailsViewController = PAPPhotoDetailsViewController(photo: photo)
        self.navigationController!.pushViewController(photoDetailsVC, animated: true)
    }

    // MARK:- ()

    func detailPhotoCellForRowAtIndexPath(indexPath: NSIndexPath) -> PFTableViewCell? {
        let CellIdentifier = "DetailPhotoCell"

        if self.paginationEnabled && indexPath.row == self.objects!.count * 2 {
            // Load More section
            return nil
        }
        
        let index: Int = self.indexForObjectAtIndexPath(indexPath)

        var headerView: PAPPhotoHeaderView? = self.tableView.dequeueReusableCellWithIdentifier(CellIdentifier) as? PAPPhotoHeaderView
        if headerView == nil {
            headerView = PAPPhotoHeaderView(frame: CGRectMake(0.0, 0.0, self.view.bounds.size.width, 44.0), buttons: PAPPhotoHeaderButtons.Default)
            headerView!.delegate = self
            headerView!.selectionStyle = UITableViewCellSelectionStyle.None
        }
        let object: PFObject? = objectAtIndexPath(indexPath)
        headerView!.photo = object
        headerView!.tag = index
        headerView!.likeButton!.tag = index

        let attributesForPhoto = PAPCache.sharedCache.attributesForPhoto(object!)
        
        if attributesForPhoto != nil {
            headerView!.setLikeStatus(PAPCache.sharedCache.isPhotoLikedByCurrentUser(object!))
            headerView!.likeButton!.setTitle(PAPCache.sharedCache.likeCountForPhoto(object!).description, forState: UIControlState.Normal)
            headerView!.commentButton!.setTitle(PAPCache.sharedCache.commentCountForPhoto(object!).description, forState: UIControlState.Normal)
            
            if headerView!.likeButton!.alpha < 1.0 || headerView!.commentButton!.alpha < 1.0 {
                UIView.animateWithDuration(0.200, animations: {
                    headerView!.likeButton!.alpha = 1.0
                    headerView!.commentButton!.alpha = 1.0
                })
            }
        } else {
            headerView!.likeButton!.alpha = 0.0
            headerView!.commentButton!.alpha = 0.0
            
            synchronized(self) {
                // check if we can update the cache
                let outstandingSectionHeaderQueryStatus: Int? = self.outstandingSectionHeaderQueries[index] as? Int
                if outstandingSectionHeaderQueryStatus == nil {
                    let query: PFQuery = PAPUtility.queryForActivitiesOnPhoto(object!, cachePolicy: PFCachePolicy.NetworkOnly)
                    query.findObjectsInBackgroundWithBlock { (objects, error) in
                        synchronized(self) {
                            self.outstandingSectionHeaderQueries.removeValueForKey(index)
                            
                            if error != nil {
                                return
                            }
                            
                            var likers = [PFUser]()
                            var commenters = [PFUser]()
                            
                            var isLikedByCurrentUser = false
                            
                            for activity in objects as! [PFObject] {
                                if (activity.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeLike && activity.objectForKey(kPAPActivityFromUserKey) != nil {
                                    likers.append(activity.objectForKey(kPAPActivityFromUserKey) as! PFUser)
                                } else if (activity.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeComment && activity.objectForKey(kPAPActivityFromUserKey) != nil {
                                    commenters.append(activity.objectForKey(kPAPActivityFromUserKey) as! PFUser)
                                }
                                
                                if (activity.objectForKey(kPAPActivityFromUserKey) as? PFUser)?.objectId == PFUser.currentUser()!.objectId {
                                    if (activity.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeLike {
                                        isLikedByCurrentUser = true
                                    }
                                }
                            }

                            PAPCache.sharedCache.setAttributesForPhoto(object!, likers: likers, commenters: commenters, likedByCurrentUser: isLikedByCurrentUser)
                            
                            if headerView!.tag != index {
                                return
                            }
                            
                            headerView!.setLikeStatus(PAPCache.sharedCache.isPhotoLikedByCurrentUser(object!))
                            headerView!.likeButton!.setTitle(PAPCache.sharedCache.likeCountForPhoto(object!).description, forState: UIControlState.Normal)
                            headerView!.commentButton!.setTitle(PAPCache.sharedCache.commentCountForPhoto(object!).description, forState: UIControlState.Normal)
                            
                            if headerView!.likeButton!.alpha < 1.0 || headerView!.commentButton!.alpha < 1.0 {
                                UIView.animateWithDuration(0.200, animations: {
                                    headerView!.likeButton!.alpha = 1.0
                                    headerView!.commentButton!.alpha = 1.0
                                })
                            }
                        }
                    }
                }
            }
        }
        
        return headerView
    }

    func indexPathForObject(targetObject: PFObject) -> NSIndexPath? {
        for var i = 0; i < self.objects!.count; i++ {
            let object: PFObject = self.objects![i] as! PFObject
            if object.objectId == targetObject.objectId {
                return NSIndexPath(forRow: i*2+1, inSection: 0)
            }
        }

        return nil
    }

    func userDidLikeOrUnlikePhoto(note: NSNotification) {
        self.tableView.beginUpdates()
        self.tableView.endUpdates()
    }

    func userDidCommentOnPhoto(note: NSNotification) {
        self.tableView.beginUpdates()
        self.tableView.endUpdates()
    }

    func userDidDeletePhoto(note: NSNotification) {
        // refresh timeline after a delay
        let time = dispatch_time(DISPATCH_TIME_NOW, Int64(1.0 * Double(NSEC_PER_SEC)))
        dispatch_after(time, dispatch_get_main_queue(), {
            self.loadObjects()
        })
    }

    func userDidPublishPhoto(note: NSNotification) {
        if self.objects!.count > 0 {
            self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0), atScrollPosition: UITableViewScrollPosition.Top, animated: true)
        }

        self.loadObjects()
    }

    func userFollowingChanged(note: NSNotification) {
        print("User following changed.")
        self.shouldReloadOnAppear = true
    }


    func didTapOnPhotoAction(sender: UIButton) {
        let photo: PFObject? = self.objects![sender.tag] as? PFObject
        if photo != nil {
            let photoDetailsVC = PAPPhotoDetailsViewController(photo: photo!)
            self.navigationController!.pushViewController(photoDetailsVC, animated: true)
        }
    }

    /*
     For each object in self.objects, we display two cells. If pagination is enabled, there will be an extra cell at the end.
     NSIndexPath     index self.objects
     0 0 HEADER      0
     0 1 PHOTO       0
     0 2 HEADER      1
     0 3 PHOTO       1
     0 4 LOAD MORE
     */

    func indexPathForObjectAtIndex(index: Int, header: Bool) -> NSIndexPath {
        return NSIndexPath(forItem: (index * 2 + (header ? 0 : 1)), inSection: 0)
    }

    func indexForObjectAtIndexPath(indexPath: NSIndexPath) -> Int {
        return indexPath.row / 2
    }
}
