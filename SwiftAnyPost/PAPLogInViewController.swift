import UIKit
import MBProgressHUD
import ParseFacebookUtils

class PAPLogInViewController: UIViewController, FBLoginViewDelegate {
    var delegate: PAPLogInViewControllerDelegate?
    var _facebookLoginView: FBLoginView?
    var hud: MBProgressHUD?

    // MARK:- UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // There is no documentation on how to handle assets with the taller iPhone 5 screen as of 9/13/2012
        if UIScreen.mainScreen().bounds.size.height > 480.0 {
            // for the iPhone 5
            // FIXME: We need 3x picture for iPhone 6
            let color = UIColor(patternImage: UIImage(named: "BackgroundLogin.png")!)
            self.view.backgroundColor = color
        } else {
            self.view.backgroundColor = UIColor(patternImage: UIImage(named: "BackgroundLogin.png")!)
        }
        
        //Position of the Facebook button
        var yPosition: CGFloat = 360.0
        if UIScreen.mainScreen().bounds.size.height > 480.0 {
            yPosition = 450.0
        }
        
        _facebookLoginView = FBLoginView(readPermissions: ["public_profile", "user_friends"/*, "email", "user_photos"*/])
        _facebookLoginView!.frame = CGRectMake(36.0, yPosition, 244.0, 44.0)
        _facebookLoginView!.delegate = self
        _facebookLoginView!.tooltipBehavior = FBLoginViewTooltipBehavior.Disable
        self.view.addSubview(_facebookLoginView!)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func shouldAutorotate() -> Bool {
        let orientation: UIInterfaceOrientation = UIApplication.sharedApplication().statusBarOrientation
        
        return orientation == UIInterfaceOrientation.Portrait
    }
    
    // FIXME: Just replaced with shouldAutorotate above? The one below is deprecated since ios6
//    override func shouldAutorotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation) -> Bool {
//        return toInterfaceOrientation == UIInterfaceOrientation.Portrait
//    }

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }


    // MARK:- FBLoginViewDelegate

    func loginViewShowingLoggedInUser(loginView: FBLoginView) {
        self.handleFacebookSession()
    }

    func loginView(loginView: FBLoginView, handleError error: NSError?) {
        self.handleLogInError(error)
    }

    func handleFacebookSession() {
        if PFUser.currentUser() != nil {
            if self.delegate != nil && self.delegate!.respondsToSelector(Selector("logInViewControllerDidLogUserIn:")) {
                self.delegate!.performSelector(Selector("logInViewControllerDidLogUserIn:"), withObject: PFUser.currentUser()!)
            }
            return
        }
        
        let permissionsArray = ["public_profile", "user_friends", "email"]
        self.hud = MBProgressHUD.showHUDAddedTo(self.view, animated: true)
        
        // Login PFUser using Facebook
        PFFacebookUtils.logInWithPermissions(permissionsArray, block: { (user, error) in
            if user == nil {
                var errorMessage: String = ""
                if error == nil {
                    print("Uh oh. The user cancelled the Facebook login.")
                    errorMessage = NSLocalizedString("Uh oh. The user cancelled the Facebook login.", comment: "")
                } else {
                    print("Uh oh. An error occurred: %@", error)
                    errorMessage = error!.localizedDescription
                }
                let alertController = UIAlertController(title: NSLocalizedString("Log In Error", comment: ""), message: errorMessage, preferredStyle: UIAlertControllerStyle.Alert)
                let alertAction = UIAlertAction(title: NSLocalizedString("Dismiss", comment: ""), style: UIAlertActionStyle.Cancel, handler: nil)
                alertController.addAction(alertAction)
                self.presentViewController(alertController, animated: true, completion: nil)
            } else {
                if user!.isNew {
                    print("User with facebook signed up and logged in!")
                } else {
                    print("User with facebook logged in!")
                }
                
                if error == nil {
                    self.hud!.removeFromSuperview()
                    if self.delegate != nil {
                        if self.delegate!.respondsToSelector(Selector("logInViewControllerDidLogUserIn:")) {
                        self.delegate!.performSelector(Selector("logInViewControllerDidLogUserIn:"), withObject: user)
                        }
                    }
                } else {
                    self.cancelLogIn(error)
                }
            }
        })
    }

    // MARK:- ()

    func cancelLogIn(error: NSError?) {
        if error != nil {
            self.handleLogInError(error)
        }
        
        self.hud!.removeFromSuperview()
        FBSession.activeSession().closeAndClearTokenInformation()
        PFUser.logOut()
        (UIApplication.sharedApplication().delegate as! AppDelegate).presentLoginViewController(false)
    }

    func handleLogInError(error: NSError?) {
        if error != nil {
            let reason = error!.userInfo["com.facebook.sdk:ErrorLoginFailedReason"] as? String
            print("Error: \(reason)")
            let title: String = NSLocalizedString("Login Error", comment: "Login error title in PAPLogInViewController")
            let message: String = NSLocalizedString("Something went wrong. Please try again.", comment: "Login error message in PAPLogInViewController")
            
            if reason == "com.facebook.sdk:UserLoginCancelled" {
                return
            }
            
            
            if error!.code == PFErrorCode.ErrorFacebookInvalidSession.rawValue {
                print("Invalid session, logging out.")
                FBSession.activeSession().closeAndClearTokenInformation()
                return
            }
            
            if error!.code == PFErrorCode.ErrorConnectionFailed.rawValue {
                let ok = NSLocalizedString("OK", comment: "OK")
                let title = NSLocalizedString("Offline Error", comment: "Offline Error")
                let message = NSLocalizedString("Something went wrong. Please try again.", comment: "Offline message")
                let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
                let okAction = UIAlertAction(title: ok, style: .Default, handler: nil)
                
                // Add Actions
                alertController.addAction(okAction)
                self.presentViewController(alertController, animated: true, completion: nil)
                return
            }
            let ok = NSLocalizedString("OK", comment: "OK")
            let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
            let okAction = UIAlertAction(title: ok, style: .Default, handler: nil)
            
            // Add Actions
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }

}

@objc protocol PAPLogInViewControllerDelegate: NSObjectProtocol {
    func logInViewControllerDidLogUserIn(logInViewController: PAPLogInViewController)
}
