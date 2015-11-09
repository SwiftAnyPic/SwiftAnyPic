import UIKit
import Parse
//import ParseCrashReporting
import ParseFacebookUtils
import MBProgressHUD

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, NSURLConnectionDataDelegate, UITabBarControllerDelegate {

    var window: UIWindow?
    var networkStatus: Reachability.NetworkStatus?
    var homeViewController: PAPHomeViewController?
    var activityViewController: PAPActivityFeedViewController?
    var welcomeViewController: PAPWelcomeViewController?
    
    var tabBarController: PAPTabBarController?
    var navController: UINavigationController?
    
    private var firstLaunch: Bool = true

    // MARK:- UIApplicationDelegate
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        self.window = UIWindow(frame: UIScreen.mainScreen().bounds)

        // ****************************************************************************
        // Parse initialization
// FIXME: CrashReporting currently query to cydia://        ParseCrashReporting.enable()
        //Parse.setApplicationId("PklSbwxITu46cOumt6tdWw8Jtg2urg0vj0CrbLr0", clientKey: "ML2sjwLC7k1RCujNCRP7fxG2HpUxtwzdIR1ElOe7")
        Parse.setApplicationId("oUuHAfy2K9KHPOj12TumNGe7tx2GSbyhCXjHCz8o", clientKey: "fJ2fqkZ1lsRqXfRiS2z6EM2A7egK7xQQirnSx77J")
        PFFacebookUtils.initializeFacebook()
// TODO: V4      PFFacebookUtils.initializeFacebookWithApplicationLaunchOptions(launchOptions)
        // ****************************************************************************
      
        // Track app open.
        PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
        
        if application.applicationIconBadgeNumber != 0 {
            application.applicationIconBadgeNumber = 0
            PFInstallation.currentInstallation().saveInBackground()
        }

        let defaultACL: PFACL = PFACL()
        // Enable public read access by default, with any newly created PFObjects belonging to the current user
        defaultACL.setPublicReadAccess(true)
        PFACL.setDefaultACL(defaultACL, withAccessForCurrentUser: true)

        // Set up our app's global UIAppearance
        self.setupAppearance()

        // Use Reachability to monitor connectivity
        self.monitorReachability()

        self.welcomeViewController = PAPWelcomeViewController()

        self.navController = UINavigationController(rootViewController: self.welcomeViewController!)
        self.navController!.navigationBarHidden = true

        self.window!.rootViewController = self.navController
        self.window!.makeKeyAndVisible()

        self.handlePush(launchOptions)
        
        return true
    }
    
    // TODO: V4
//    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
//        return FBSDKApplicationDelegate.sharedInstance().application(application, openURL: url, sourceApplication: sourceApplication, annotation: annotation)
//    }
    
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
        var wasHandled = false
        
        if PFFacebookUtils.session() != nil {
            wasHandled = wasHandled || FBAppCall.handleOpenURL(url, sourceApplication: sourceApplication, withSession: PFFacebookUtils.session())
        } else {
            wasHandled = wasHandled || FBAppCall.handleOpenURL(url, sourceApplication: sourceApplication)
        }
        
        wasHandled = wasHandled || handleActionURL(url)

        return wasHandled
    }

    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        if (application.applicationIconBadgeNumber != 0) {
            application.applicationIconBadgeNumber = 0
        }

        let currentInstallation = PFInstallation.currentInstallation()
        currentInstallation.setDeviceTokenFromData(deviceToken)
        currentInstallation.saveInBackground()
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
    	if error.code != 3010 { // 3010 is for the iPhone Simulator
            print("Application failed to register for push notifications: \(error)")
    	}
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        NSNotificationCenter.defaultCenter().postNotificationName(PAPAppDelegateApplicationDidReceiveRemoteNotification, object: nil, userInfo: userInfo)
        
        if UIApplication.sharedApplication().applicationState != UIApplicationState.Active {
            // Track app opens due to a push notification being acknowledged while the app wasn't active.
            PFAnalytics.trackAppOpenedWithRemoteNotificationPayload(userInfo)
        }

        if PFUser.currentUser() != nil {
            // FIXME: Looks so lengthy, any better way?
            if self.tabBarController!.viewControllers!.count > PAPTabBarControllerViewControllerIndex.ActivityTabBarItemIndex.rawValue {
                let tabBarItem: UITabBarItem = self.tabBarController!.viewControllers![PAPTabBarControllerViewControllerIndex.ActivityTabBarItemIndex.rawValue].tabBarItem
                
                if let currentBadgeValue: String = tabBarItem.badgeValue where currentBadgeValue.length > 0 {
                    tabBarItem.badgeValue = String(Int(currentBadgeValue)! + 1)
                } else {
                    tabBarItem.badgeValue = "1"
                }
            }
        }
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        // Clear badge and update installation, required for auto-incrementing badges.
        if application.applicationIconBadgeNumber != 0 {
            application.applicationIconBadgeNumber = 0
            PFInstallation.currentInstallation().saveInBackground()
        }

        // Clears out all notifications from Notification Center.
        UIApplication.sharedApplication().cancelAllLocalNotifications()
        application.applicationIconBadgeNumber = 1
        application.applicationIconBadgeNumber = 0

        FBAppCall.handleDidBecomeActiveWithSession(PFFacebookUtils.session())
// TODO: V4        FBSDKAppEvents.activateApp()
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    // MARK: - UITabBarControllerDelegate

    func tabBarController(aTabBarController: UITabBarController, shouldSelectViewController viewController: UIViewController) -> Bool {
        // The empty UITabBarItem behind our Camera button should not load a view controller
        return viewController != aTabBarController.viewControllers![PAPTabBarControllerViewControllerIndex.EmptyTabBarItemIndex.rawValue]
    }

    // MARK:- AppDelegate

    func isParseReachable() -> Bool {
        return self.networkStatus != .NotReachable
    }

    func presentLoginViewController(animated: Bool = true) {
        self.welcomeViewController!.presentLoginViewController(animated)
    }

    func presentTabBarController() {
        self.tabBarController = PAPTabBarController()
        self.homeViewController = PAPHomeViewController(style: UITableViewStyle.Plain)
        self.homeViewController!.firstLaunch = firstLaunch
        self.activityViewController = PAPActivityFeedViewController(style: UITableViewStyle.Plain)
        
        let homeNavigationController: UINavigationController = UINavigationController(rootViewController: self.homeViewController!)
        let emptyNavigationController: UINavigationController = UINavigationController()
        let activityFeedNavigationController: UINavigationController = UINavigationController(rootViewController: self.activityViewController!)
        
        let homeTabBarItem: UITabBarItem = UITabBarItem(title: NSLocalizedString("Home", comment: "Home"), image: UIImage(named: "IconHome.png")!.imageWithRenderingMode(UIImageRenderingMode.AlwaysOriginal), selectedImage: UIImage(named: "IconHomeSelected.png")!.imageWithRenderingMode(UIImageRenderingMode.AlwaysOriginal))
        homeTabBarItem.setTitleTextAttributes([NSForegroundColorAttributeName: UIColor.whiteColor(), NSFontAttributeName: UIFont.boldSystemFontOfSize(13)], forState: UIControlState.Selected)
        homeTabBarItem.setTitleTextAttributes([NSForegroundColorAttributeName: UIColor(red: 114.0/255.0, green: 114.0/255.0, blue: 114.0/255.0, alpha: 1.0), NSFontAttributeName: UIFont.boldSystemFontOfSize(13)], forState: UIControlState.Normal)
        
        let activityFeedTabBarItem: UITabBarItem = UITabBarItem(title: NSLocalizedString("Activity", comment: "Activity"), image: UIImage(named: "IconTimeline.png")!.imageWithRenderingMode(UIImageRenderingMode.AlwaysOriginal), selectedImage: UIImage(named: "IconTimelineSelected.png")!.imageWithRenderingMode(UIImageRenderingMode.AlwaysOriginal))
        activityFeedTabBarItem.setTitleTextAttributes([NSForegroundColorAttributeName: UIColor.whiteColor(), NSFontAttributeName: UIFont.boldSystemFontOfSize(13)], forState: UIControlState.Selected)
        activityFeedTabBarItem.setTitleTextAttributes([NSForegroundColorAttributeName: UIColor(red: 114.0/255.0, green: 114.0/255.0, blue: 114.0/255.0, alpha: 1.0), NSFontAttributeName: UIFont.boldSystemFontOfSize(13)], forState: UIControlState.Normal)
        
        homeNavigationController.tabBarItem = homeTabBarItem
        activityFeedNavigationController.tabBarItem = activityFeedTabBarItem
        
        tabBarController!.delegate = self
        tabBarController!.viewControllers = [homeNavigationController, emptyNavigationController, activityFeedNavigationController]
        
        navController!.setViewControllers([welcomeViewController!, tabBarController!], animated: false)

        // Register for Push Notitications
        let userNotificationTypes: UIUserNotificationType = [UIUserNotificationType.Alert, UIUserNotificationType.Badge, UIUserNotificationType.Sound]
        let settings: UIUserNotificationSettings = UIUserNotificationSettings(forTypes: userNotificationTypes, categories: nil)
        UIApplication.sharedApplication().registerUserNotificationSettings(settings)
        UIApplication.sharedApplication().registerForRemoteNotifications()
    }

    func logOut() {
        // clear cache
        PAPCache.sharedCache.clear()

        // clear NSUserDefaults
        NSUserDefaults.standardUserDefaults().removeObjectForKey(kPAPUserDefaultsCacheFacebookFriendsKey)
        NSUserDefaults.standardUserDefaults().removeObjectForKey(kPAPUserDefaultsActivityFeedViewControllerLastRefreshKey)
        NSUserDefaults.standardUserDefaults().synchronize()

        // Unsubscribe from push notifications by removing the user association from the current installation.
        PFInstallation.currentInstallation().removeObjectForKey(kPAPInstallationUserKey)
        PFInstallation.currentInstallation().saveInBackground()
        
        // Clear all caches
        PFQuery.clearAllCachedResults()
        
        // Log out
        PFUser.logOut()
        FBSession.setActiveSession(nil)
// V4???       FBSDKAccessToken.currentAccessToken().tokenString
        
        // clear out cached data, view controllers, etc
        navController!.popToRootViewControllerAnimated(false)
        
        presentLoginViewController()
        
        self.homeViewController = nil;
        self.activityViewController = nil;
    }

    // MARK: - ()

    // Set up appearance parameters to achieve Anypic's custom look and feel
    func setupAppearance() {
        UIApplication.sharedApplication().statusBarStyle = UIStatusBarStyle.LightContent

        UINavigationBar.appearance().tintColor = UIColor(red: 254.0/255.0, green: 149.0/255.0, blue: 50.0/255.0, alpha: 1.0)
        UINavigationBar.appearance().barTintColor = UIColor(red: 0.0/255.0, green: 0.0/255.0, blue: 0.0/255.0, alpha: 1.0)
        
        UINavigationBar.appearance().titleTextAttributes = [ NSForegroundColorAttributeName: UIColor.whiteColor() ]
        
        UIButton.appearanceWhenContainedInInstancesOfClasses([UINavigationBar.self]).setTitleColor(UIColor(red: 254.0/255.0, green: 149.0/255.0, blue: 50.0/255.0, alpha: 1.0), forState: UIControlState.Normal)
        
        UIBarButtonItem.appearance().setTitleTextAttributes([ NSForegroundColorAttributeName: UIColor(red: 254.0/255.0, green: 149.0/255.0, blue: 50.0/255.0, alpha: 1.0) ], forState: UIControlState.Normal)
        
        UISearchBar.appearance().tintColor = UIColor(red: 254.0/255.0, green: 149.0/255.0, blue: 50.0/255.0, alpha: 1.0)
    }

    func monitorReachability() {
        guard let reachability = Reachability(hostname: "api.parse.com") else {
            return
        }
        
        reachability.whenReachable = { (reach: Reachability) in
            self.networkStatus = reach.currentReachabilityStatus
            if self.isParseReachable() && PFUser.currentUser() != nil && self.homeViewController!.objects!.count == 0 {
                // Refresh home timeline on network restoration. Takes care of a freshly installed app that failed to load the main timeline under bad network conditions.
                // In this case, they'd see the empty timeline placeholder and have no way of refreshing the timeline unless they followed someone.
                self.homeViewController!.loadObjects()
            }
        }
        reachability.whenUnreachable = { (reach: Reachability) in
            self.networkStatus = reach.currentReachabilityStatus
        }
        
        reachability.startNotifier()
    }

    func handlePush(launchOptions: [NSObject: AnyObject]?) {
        // If the app was launched in response to a push notification, we'll handle the payload here
        guard let remoteNotificationPayload = launchOptions?[UIApplicationLaunchOptionsRemoteNotificationKey] as? [NSObject : AnyObject] else { return }
        
        NSNotificationCenter.defaultCenter().postNotificationName(PAPAppDelegateApplicationDidReceiveRemoteNotification, object: nil, userInfo: remoteNotificationPayload)
        
        if PFUser.currentUser() == nil {
            return
        }

        // If the push notification payload references a photo, we will attempt to push this view controller into view
        if let photoObjectId = remoteNotificationPayload[kPAPPushPayloadPhotoObjectIdKey] as? String where photoObjectId.characters.count > 0 {
            shouldNavigateToPhoto(PFObject(withoutDataWithClassName: kPAPPhotoClassKey, objectId: photoObjectId))
            return
        }
        
        // If the push notification payload references a user, we will attempt to push their profile into view
        guard let fromObjectId = remoteNotificationPayload[kPAPPushPayloadFromUserObjectIdKey] as? String where fromObjectId.characters.count > 0 else { return }
        
        let query: PFQuery? = PFUser.query()
        query!.cachePolicy = PFCachePolicy.CacheElseNetwork
        query!.getObjectInBackgroundWithId(fromObjectId, block: { (user, error) in
            if error == nil {
                let homeNavigationController = self.tabBarController!.viewControllers![PAPTabBarControllerViewControllerIndex.HomeTabBarItemIndex.rawValue] as? UINavigationController
                self.tabBarController!.selectedViewController = homeNavigationController
                
                let accountViewController = PAPAccountViewController(user: user as! PFUser)
                print("Presenting account view controller with user: \(user!)")
                homeNavigationController!.pushViewController(accountViewController, animated: true)
            }
        })
    }

    func autoFollowTimerFired(aTimer: NSTimer) {
        MBProgressHUD.hideHUDForView(navController!.presentedViewController!.view, animated: true)
        MBProgressHUD.hideHUDForView(homeViewController!.view, animated: true)
        self.homeViewController!.loadObjects()
    }

    func shouldProceedToMainInterface(user: PFUser)-> Bool{
        MBProgressHUD.hideHUDForView(navController!.presentedViewController!.view, animated: true)
        self.presentTabBarController()

        self.navController!.dismissViewControllerAnimated(true, completion: nil)
        return true
    }

    func handleActionURL(url: NSURL) -> Bool {
        if url.host == kPAPLaunchURLHostTakePicture {
            if PFUser.currentUser() != nil {
                return tabBarController!.shouldPresentPhotoCaptureController()
            }
        } else {
// FIXME: Is it working?           if ([[url fragment] rangeOfString:@"^pic/[A-Za-z0-9]{10}$" options:NSRegularExpressionSearch].location != NSNotFound) {
            if url.fragment!.rangeOfString("^pic/[A-Za-z0-9]{10}$" , options: [.RegularExpressionSearch]) != nil {
                let photoObjectId: String = url.fragment!.subString(4, length: 10)
                if photoObjectId.length > 0 {
                    print("WOOP: %@", photoObjectId)
                    shouldNavigateToPhoto(PFObject(withoutDataWithClassName: kPAPPhotoClassKey, objectId: photoObjectId))
                    return true
                }
            }
        }

        return false
    }

    func shouldNavigateToPhoto(var targetPhoto: PFObject) {
        for photo: PFObject in homeViewController!.objects as! [PFObject] {
            if photo.objectId == targetPhoto.objectId {
                targetPhoto = photo
                break
            }
        }
        
        // if we have a local copy of this photo, this won't result in a network fetch
        targetPhoto.fetchIfNeededInBackgroundWithBlock() { (object, error) in
            if (error == nil) {
                let homeNavigationController = self.tabBarController!.viewControllers![PAPTabBarControllerViewControllerIndex.HomeTabBarItemIndex.rawValue] as? UINavigationController
                self.tabBarController!.selectedViewController = homeNavigationController
                
                let detailViewController = PAPPhotoDetailsViewController(photo: object!)
                homeNavigationController!.pushViewController(detailViewController, animated: true)
            }
        }
    }

    func autoFollowUsers() {
        firstLaunch = true
        PFCloud.callFunctionInBackground("autoFollowUsers", withParameters: nil, block: { (_, error) in
            if error != nil {
                print("Error auto following users: \(error)")
            }
            MBProgressHUD.hideHUDForView(self.navController!.presentedViewController!.view, animated:false)
            self.homeViewController!.loadObjects()
        })
    }
}

