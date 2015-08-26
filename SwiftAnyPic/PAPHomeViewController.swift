import UIKit

class PAPHomeViewController: PAPPhotoTimelineViewController {
    var firstLaunch: Bool = false
    private var blankTimelineView: UIView?
    private var _presentingAccountNavController: UINavigationController?
    private var _presentingFriendNavController: UINavigationController?
    private var settingsActionSheetDelegate: PAPSettingsActionSheetDelegate?

    // MARK:- UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.titleView = UIImageView(image: UIImage(named: "LogoNavigationBar.png"))

        self.navigationItem.rightBarButtonItem = PAPSettingsButtonItem(target: self, action: Selector("settingsButtonAction:"))
        
        self.blankTimelineView = UIView(frame: self.tableView.bounds)
        
        let button = UIButton(type: UIButtonType.Custom)
        button.frame = CGRectMake(33.0, 96.0, 253.0, 173.0)
        button.setBackgroundImage(UIImage(named: "HomeTimelineBlank.png"), forState: UIControlState.Normal)
        button.addTarget(self, action: Selector("inviteFriendsButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)
        self.blankTimelineView!.addSubview(button)
    }

    // MARK:- PFQueryTableViewController

    override func objectsDidLoad(error: NSError?) {
        super.objectsDidLoad(error)

        if self.objects!.count == 0 && !self.queryForTable().hasCachedResult() && !self.firstLaunch {
            self.tableView.scrollEnabled = false
            
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
        }    
    }


    // MARK:- ()

    func settingsButtonAction(sender: AnyObject) {
        // TODO: Change to UIAlertController
//        let actionController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
//        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil)
        
        self.settingsActionSheetDelegate = PAPSettingsActionSheetDelegate(navigationController: self.navigationController)
        let actionSheet = UIActionSheet(title: nil, delegate: self.settingsActionSheetDelegate, cancelButtonTitle: nil, destructiveButtonTitle: nil, otherButtonTitles: "My Profile", "Find Friends", "Log Out")
        actionSheet.cancelButtonIndex = actionSheet.addButtonWithTitle("Cancel")
        actionSheet.showFromTabBar(self.tabBarController!.tabBar)
    }


    func inviteFriendsButtonAction(sender: AnyObject) {
        let detailViewController = PAPFindFriendsViewController(style: UITableViewStyle.Plain)
        self.navigationController!.pushViewController(detailViewController, animated: true)
    }
}
