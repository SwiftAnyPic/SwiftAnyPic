import UIKit
import Synchronized
import ParseFacebookUtils

class PAPWelcomeViewController: UIViewController, PAPLogInViewControllerDelegate {
    
    private var _presentedLoginViewController: Bool = false
    private var _facebookResponseCount: Int = 0
    private var _expectedFacebookResponseCount: Int = 0
    private var _profilePicData: NSMutableData? = nil

    // MARK:- UIViewController
    override func loadView() {
        let backgroundImageView: UIImageView = UIImageView(frame: UIScreen.mainScreen().bounds)
        backgroundImageView.image = UIImage(named: "Default.png")
        self.view = backgroundImageView
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if PFUser.currentUser() == nil {
            presentLoginViewController(false)
            return
        }

        // Present Anypic UI
        (UIApplication.sharedApplication().delegate as! AppDelegate).presentTabBarController()
        
        // Refresh current user with server side data -- checks if user is still valid and so on
        _facebookResponseCount = 0
        PFUser.currentUser()?.fetchInBackgroundWithTarget(self, selector: Selector("refreshCurrentUserCallbackWithResult:error:"))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK:- PAPWelcomeViewController

    func presentLoginViewController(animated: Bool) {
        if _presentedLoginViewController {
            return
        }
        
        _presentedLoginViewController = true
        let loginViewController = PAPLogInViewController()
        loginViewController.delegate = self
        presentViewController(loginViewController, animated: animated, completion: nil)
    }

    // MARK:- PAPLoginViewControllerDelegate
    func logInViewControllerDidLogUserIn(logInViewController: PAPLogInViewController) {
        if _presentedLoginViewController {
            _presentedLoginViewController = false
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }

    // MARK:- ()

    func processedFacebookResponse() {
        // Once we handled all necessary facebook batch responses, save everything necessary and continue
        synchronized(self) {
            _facebookResponseCount++;
            if (_facebookResponseCount != _expectedFacebookResponseCount) {
                return
            }
        }
        _facebookResponseCount = 0;
        print("done processing all Facebook requests")
        
        PFUser.currentUser()!.saveInBackgroundWithBlock { (succeeded, error) in
            if !succeeded {
                print("Failed save in background of user, \(error)")
            } else {
                print("saved current parse user")
            }
        }
    }

    func refreshCurrentUserCallbackWithResult(refreshedObject: PFObject, error: NSError?) {
        // This fetches the most recent data from FB, and syncs up all data with the server including profile pic and friends list from FB.
        
        // A kPFErrorObjectNotFound error on currentUser refresh signals a deleted user
        if error != nil && error!.code == PFErrorCode.ErrorObjectNotFound.rawValue {
            print("User does not exist.")
            (UIApplication.sharedApplication().delegate as! AppDelegate).logOut()
            return
        }
        
        let session: FBSession = PFFacebookUtils.session()!
        if !session.isOpen {
            print("FB Session does not exist, logout")
            (UIApplication.sharedApplication().delegate as! AppDelegate).logOut()
            return
        }
        
        if session.accessTokenData.userID == nil {
            print("userID on FB Session does not exist, logout")
            (UIApplication.sharedApplication().delegate as! AppDelegate).logOut()
            return
        }
        
        guard let currentParseUser: PFUser = PFUser.currentUser() else {
            print("Current Parse user does not exist, logout")
            (UIApplication.sharedApplication().delegate as! AppDelegate).logOut()
            return
        }
        
        let facebookId = currentParseUser.objectForKey(kPAPUserFacebookIDKey) as? String
        if facebookId == nil || facebookId!.length == 0 {
            // set the parse user's FBID
            currentParseUser.setObject(session.accessTokenData.userID, forKey: kPAPUserFacebookIDKey)
        }
        
        if PAPUtility.userHasValidFacebookData(currentParseUser) == false {
            print("User does not have valid facebook ID. PFUser's FBID: \(currentParseUser.objectForKey(kPAPUserFacebookIDKey)), FBSessions FBID: \(session.accessTokenData.userID). logout")
            (UIApplication.sharedApplication().delegate as! AppDelegate).logOut()
            return
        }
        
        // Finished checking for invalid stuff
        // Refresh FB Session (When we link up the FB access token with the parse user, information other than the access token string is dropped
        // By going through a refresh, we populate useful parameters on FBAccessTokenData such as permissions.
        PFFacebookUtils.session()!.refreshPermissionsWithCompletionHandler { (session, error) in
            if (error != nil) {
                print("Failed refresh of FB Session, logging out: \(error)")
                (UIApplication.sharedApplication().delegate as! AppDelegate).logOut()
                return
            }
            // refreshed
            print("refreshed permissions: \(session)")
            
            
            self._expectedFacebookResponseCount = 0
            let permissions: NSArray = session.accessTokenData.permissions
            // FIXME: How to use "contains" in Swift Array? Replace the NSArray with Swift array
            if permissions.containsObject("public_profile") {
                // Logged in with FB
                // Create batch request for all the stuff
                let connection = FBRequestConnection()
                self._expectedFacebookResponseCount++
                connection.addRequest(FBRequest.requestForMe(), completionHandler: { (connection, result, error) in
                    if error != nil {
                        // Failed to fetch me data.. logout to be safe
                        print("couldn't fetch facebook /me data: \(error), logout")
                        (UIApplication.sharedApplication().delegate as! AppDelegate).logOut()
                        return
                    }
                    
                    if let facebookName = result["name"] as? String where facebookName.length > 0 {
                        currentParseUser.setObject(facebookName, forKey: kPAPUserDisplayNameKey)
                    }
                    
                    self.processedFacebookResponse()
                })
                
                // profile pic request
                self._expectedFacebookResponseCount++
                connection.addRequest(FBRequest(graphPath: "me", parameters: ["fields": "picture.width(500).height(500)"], HTTPMethod: "GET"), completionHandler: { (connection, result, error) in
                    if error == nil {
                        // result is a dictionary with the user's Facebook data
                        // FIXME: Really need to be this ugly???
//                        let userData = result as? [String : [String : [String : String]]]
//                        let profilePictureURL = NSURL(string: userData!["picture"]!["data"]!["url"]!)
//                        // Now add the data to the UI elements
//                        let profilePictureURLRequest: NSURLRequest = NSURLRequest(URL: profilePictureURL!, cachePolicy: NSURLRequestCachePolicy.UseProtocolCachePolicy, timeoutInterval: 10.0) // Facebook profile picture cache policy: Expires in 2 weeks
//                        NSURLConnection(request: profilePictureURLRequest, delegate: self)
                        if let userData = result as? [NSObject: AnyObject] {
                            if let picture = userData["picture"] as? [NSObject: AnyObject] {
                                if let data = picture["data"] as? [NSObject: AnyObject] {
                                    if let profilePictureURL = data["url"] as? String {
                                        // Now add the data to the UI elements
                                        let profilePictureURLRequest: NSURLRequest = NSURLRequest(URL: NSURL(string: profilePictureURL)!, cachePolicy: NSURLRequestCachePolicy.UseProtocolCachePolicy, timeoutInterval: 10.0) // Facebook profile picture cache policy: Expires in 2 weeks
                                        NSURLConnection(request: profilePictureURLRequest, delegate: self)
                                    }
                                }
                            }
                            
                        }
                    } else {
                        print("Error getting profile pic url, setting as default avatar: \(error)")
                        let profilePictureData: NSData = UIImagePNGRepresentation(UIImage(named: "AvatarPlaceholder.png")!)!
                        PAPUtility.processFacebookProfilePictureData(profilePictureData)
                    }
                    self.processedFacebookResponse()
                })
                if permissions.containsObject("user_friends") {
                    // Fetch FB Friends + me
                    self._expectedFacebookResponseCount++
                    connection.addRequest(FBRequest.requestForMyFriends(), completionHandler: { (connection, result, error) in
                        print("processing Facebook friends")
                        if error != nil {
                            // just clear the FB friend cache
                            PAPCache.sharedCache.clear()
                        } else {
                            let data = result.objectForKey("data") as? NSArray
                            let facebookIds: NSMutableArray = NSMutableArray(capacity: data!.count)
                            for friendData in data! {
                                if let facebookId = friendData["id"] {
                                    facebookIds.addObject(facebookId!)
                                }
                            }
                            // cache friend data
                            PAPCache.sharedCache.setFacebookFriends(facebookIds)
                            
                            if currentParseUser.objectForKey(kPAPUserFacebookFriendsKey) != nil {
                                currentParseUser.removeObjectForKey(kPAPUserFacebookFriendsKey)
                            }
                            if currentParseUser.objectForKey(kPAPUserAlreadyAutoFollowedFacebookFriendsKey) != nil {
                                (UIApplication.sharedApplication().delegate as! AppDelegate).autoFollowUsers()
                            }
                        }
                        self.processedFacebookResponse()
                    })
                }
                connection.start()
            } else {
                let profilePictureData: NSData = UIImagePNGRepresentation(UIImage(named: "AvatarPlaceholder.png")!)!
                PAPUtility.processFacebookProfilePictureData(profilePictureData)
                
                PAPCache.sharedCache.clear()
                currentParseUser.setObject("Someone", forKey: kPAPUserDisplayNameKey)
                self._expectedFacebookResponseCount++
                self.processedFacebookResponse()
            }
        }
    }

    // MARK:- NSURLConnectionDataDelegate

    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        _profilePicData = NSMutableData()
    }

    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        _profilePicData!.appendData(data)
    }

    func connectionDidFinishLoading(connection: NSURLConnection) {
        PAPUtility.processFacebookProfilePictureData(_profilePicData!)
    }

    // MARK:- NSURLConnectionDelegate
    
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        print("Connection error downloading profile pic data: \(error)")
    }
}
