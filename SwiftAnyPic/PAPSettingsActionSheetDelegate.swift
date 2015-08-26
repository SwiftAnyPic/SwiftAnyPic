import Foundation

// ActionSheet button indexes
enum PAPSettingsActionSheetButtons: Int {
	case Profile = 0, FindFriends, Logout, NumberOfButtons
}

class PAPSettingsActionSheetDelegate: NSObject, UIActionSheetDelegate {
    var navController: UINavigationController?

    // MARK:- Initialization

    init(navigationController: UINavigationController?) {
        super.init()
        navController = navigationController
    }

    override convenience init() {
        self.init(navigationController: nil)
    }

    // MARK:- UIActionSheetDelegate

    // FIXME: It is deprecated!!!!!!!
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        if self.navController == nil {
            fatalError("navController cannot be nil")
// FIXME:           [NSException raise:NSInvalidArgumentException format:@"navController cannot be nil"];
            return
        }
        
        switch buttonIndex {
            case PAPSettingsActionSheetButtons.Profile.rawValue:
                let accountViewController = PAPAccountViewController(user: PFUser.currentUser()!)
                navController!.pushViewController(accountViewController, animated: true)
            
            case PAPSettingsActionSheetButtons.FindFriends.rawValue:
                // FIXME: Default with Plain style???
                let findFriendsVC = PAPFindFriendsViewController(style: UITableViewStyle.Plain)
                navController!.pushViewController(findFriendsVC, animated: true)
            
            case PAPSettingsActionSheetButtons.Logout.rawValue:
                // Log out user and present the login view controller
                (UIApplication.sharedApplication().delegate as! AppDelegate).logOut()
            
            default:
                break;
        }
    }
}
