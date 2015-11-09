import UIKit
import FormatterKit
import ParseUI

struct PAPPhotoHeaderButtons : OptionSetType {
    let rawValue : Int
    init(rawValue: Int) { self.rawValue = rawValue }

    static let None = PAPPhotoHeaderButtons(rawValue: 1 << 0)
    static let Like = PAPPhotoHeaderButtons(rawValue: 1 << 1)
    static let Comment = PAPPhotoHeaderButtons(rawValue: 1 << 2)
    static let User = PAPPhotoHeaderButtons(rawValue: 1 << 3)
    
    static let Default: PAPPhotoHeaderButtons = [Like, Comment, User]
}

class PAPPhotoHeaderView: PFTableViewCell {

    /// The bitmask which specifies the enabled interaction elements in the view
    var buttons: PAPPhotoHeaderButtons = .None

    /*! @name Accessing Interaction Elements */

    /// The Like Photo button
    var likeButton: UIButton?
    
    /// The Comment On Photo button
    var commentButton: UIButton?
    
    var delegate: PAPPhotoHeaderViewDelegate?
    
    var containerView: UIView?
    var avatarImageView: PAPProfileImageView?
    var userButton: UIButton?
    var timestampLabel: UILabel?
    var timeIntervalFormatter: TTTTimeIntervalFormatter?
    
    // MARK:- Initialization

    init(frame: CGRect, buttons otherButtons: PAPPhotoHeaderButtons) {
        super.init(style: UITableViewCellStyle.Default, reuseIdentifier: nil)
        self.frame = frame
        
        PAPPhotoHeaderView.validateButtons(otherButtons)
        buttons = otherButtons

        self.clipsToBounds = false
// FIXME: It crashed!        self.superview!.clipsToBounds = false
        self.backgroundColor = UIColor.clearColor()
        
        // translucent portion
        self.containerView = UIView(frame: CGRectMake(0.0, 0.0, self.bounds.size.width, self.bounds.size.height))
        self.containerView!.clipsToBounds = false
        self.addSubview(self.containerView!)
        self.containerView!.backgroundColor = UIColor.whiteColor()
        
        self.avatarImageView = PAPProfileImageView()
        self.avatarImageView!.frame = CGRectMake(4.0, 4.0, 35.0, 35.0)
        self.avatarImageView!.profileButton!.addTarget(self, action: Selector("didTapUserButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)
        self.containerView!.addSubview(self.avatarImageView!)
        
        if self.buttons.contains(PAPPhotoHeaderButtons.Comment) {
            // comments button
            commentButton = UIButton(type: UIButtonType.Custom)
            containerView!.addSubview(self.commentButton!)
            self.commentButton!.frame = CGRectMake(282.0, 10.0, 29.0, 29.0)
            self.commentButton!.backgroundColor = UIColor.clearColor()
            self.commentButton!.setTitle("", forState: UIControlState.Normal)
            self.commentButton!.setTitleColor(UIColor(red: 254.0/255.0, green: 149.0/255.0, blue: 50.0/255.0, alpha: 1.0), forState: UIControlState.Normal)
            self.commentButton!.titleEdgeInsets = UIEdgeInsetsMake(-6.0, 0.0, 0.0, 0.0)
            self.commentButton!.titleLabel!.font = UIFont.systemFontOfSize(12.0)
            self.commentButton!.titleLabel!.minimumScaleFactor = 0.8
            self.commentButton!.titleLabel!.adjustsFontSizeToFitWidth = true
            self.commentButton!.setBackgroundImage(UIImage(named: "IconComment.png"), forState: UIControlState.Normal)
            self.commentButton!.selected = false
        }
        
        if self.buttons.contains(PAPPhotoHeaderButtons.Like) {
            // like button
            likeButton = UIButton(type: UIButtonType.Custom)
            containerView!.addSubview(self.likeButton!)
            self.likeButton!.frame = CGRectMake(246.0, 9.0, 29.0, 29.0)
            self.likeButton!.backgroundColor = UIColor.clearColor()
            self.likeButton!.setTitle("", forState: UIControlState.Normal)
            self.likeButton!.setTitleColor(UIColor(red: 254.0/255.0, green: 149.0/255.0, blue: 50.0/255.0, alpha: 1.0), forState: UIControlState.Normal)
            self.likeButton!.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Selected)
            self.likeButton!.titleEdgeInsets = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0)
            self.likeButton!.titleLabel!.font = UIFont.systemFontOfSize(12.0)
            self.likeButton!.titleLabel!.minimumScaleFactor = 0.8
            self.likeButton!.titleLabel!.adjustsFontSizeToFitWidth = true
            self.likeButton!.adjustsImageWhenHighlighted = false
            self.likeButton!.adjustsImageWhenDisabled = false
            self.likeButton!.setBackgroundImage(UIImage(named: "ButtonLike.png"), forState: UIControlState.Normal)
            self.likeButton!.setBackgroundImage(UIImage(named: "ButtonLikeSelected.png"), forState: UIControlState.Selected)
            self.likeButton!.selected = false
        }
        
        if self.buttons.contains(PAPPhotoHeaderButtons.User) {
            // This is the user's display name, on a button so that we can tap on it
            self.userButton = UIButton(type: UIButtonType.Custom)
            containerView!.addSubview(self.userButton!)
            self.userButton!.backgroundColor = UIColor.clearColor()
            self.userButton!.titleLabel!.font = UIFont.boldSystemFontOfSize(15)
            self.userButton!.setTitleColor(UIColor(red: 34.0/255.0, green: 34.0/255.0, blue: 34.0/255.0, alpha: 1.0), forState: UIControlState.Normal)
            self.userButton!.setTitleColor(UIColor.blackColor(), forState: UIControlState.Highlighted)
            self.userButton!.titleLabel!.lineBreakMode = NSLineBreakMode.ByTruncatingTail
        }
        
        self.timeIntervalFormatter = TTTTimeIntervalFormatter()
        
        // timestamp
        self.timestampLabel = UILabel(frame: CGRectMake(50.0, 24.0, containerView!.bounds.size.width - 50.0 - 72.0, 18.0))
        containerView!.addSubview(self.timestampLabel!)
        self.timestampLabel!.textColor = UIColor(red: 114.0/255.0, green: 114.0/255.0, blue: 114.0/255.0, alpha: 1.0)
        self.timestampLabel!.font = UIFont.systemFontOfSize(11.0)
        self.timestampLabel!.backgroundColor = UIColor.clearColor()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK:- PAPPhotoHeaderView

    /// The photo associated with this view
    var photo: PFObject? {
        didSet {
            // user's avatar
            let user: PFUser? = photo!.objectForKey(kPAPPhotoUserKey) as? PFUser
            if PAPUtility.userHasProfilePictures(user!) {
                let profilePictureSmall: PFFile = user!.objectForKey(kPAPUserProfilePicSmallKey) as! PFFile
                self.avatarImageView!.setFile(profilePictureSmall)
            } else {
                self.avatarImageView!.setImage(PAPUtility.defaultProfilePicture()!)
            }

            self.avatarImageView!.contentMode = UIViewContentMode.ScaleAspectFill
            self.avatarImageView!.layer.cornerRadius = 17.5
            self.avatarImageView!.layer.masksToBounds = true

            let authorName: String = user!.objectForKey(kPAPUserDisplayNameKey) as! String
            self.userButton!.setTitle(authorName, forState: UIControlState.Normal)
            
            var constrainWidth: CGFloat = containerView!.bounds.size.width

            if self.buttons.contains(PAPPhotoHeaderButtons.User) {
                self.userButton!.addTarget(self, action: Selector("didTapUserButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)
            }
            
            if self.buttons.contains(PAPPhotoHeaderButtons.Comment) {
                constrainWidth = self.commentButton!.frame.origin.x
                self.commentButton!.addTarget(self, action: Selector("didTapCommentOnPhotoButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)
            }
            
            if self.buttons.contains(PAPPhotoHeaderButtons.Like) {
                constrainWidth = self.likeButton!.frame.origin.x
                self.likeButton!.addTarget(self, action: Selector("didTapLikePhotoButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)
            }
            
            // we resize the button to fit the user's name to avoid having a huge touch area
            let userButtonPoint: CGPoint = CGPointMake(50.0, 6.0)
            constrainWidth -= userButtonPoint.x
            let constrainSize: CGSize = CGSizeMake(constrainWidth, containerView!.bounds.size.height - userButtonPoint.y*2.0)

            
            let userButtonSize: CGSize = self.userButton!.titleLabel!.text!.boundingRectWithSize(constrainSize,
                                                                                        options: [NSStringDrawingOptions.TruncatesLastVisibleLine, NSStringDrawingOptions.UsesLineFragmentOrigin],
                                                                                     attributes: [NSFontAttributeName: self.userButton!.titleLabel!.font],
                                                                                        context: nil).size
            
            let userButtonFrame: CGRect = CGRectMake(userButtonPoint.x, userButtonPoint.y, userButtonSize.width, userButtonSize.height)
            self.userButton!.frame = userButtonFrame
            
            let timeInterval: NSTimeInterval = self.photo!.createdAt!.timeIntervalSinceNow
            let timestamp: String = self.timeIntervalFormatter!.stringForTimeInterval(timeInterval)
            self.timestampLabel!.text = timestamp

            self.setNeedsDisplay()
        }
    }

    func setLikeStatus(liked: Bool) {
        self.likeButton!.selected = liked
        
        // FIXME: both are just the same???
        if (liked) {
            self.likeButton!.titleEdgeInsets = UIEdgeInsetsMake(-3.0, 0.0, 0.0, 0.0)
        } else {
            self.likeButton!.titleEdgeInsets = UIEdgeInsetsMake(-3.0, 0.0, 0.0, 0.0)
        }
    }

    func shouldEnableLikeButton(enable: Bool) {
        if enable {
            self.likeButton!.removeTarget(self, action: Selector("didTapLikePhotoButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)
        } else {
            self.likeButton!.addTarget(self, action: Selector("didTapLikePhotoButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)
        }
    }
    
    // MARK:- ()

    static func validateButtons(buttons: PAPPhotoHeaderButtons) {
        if buttons == PAPPhotoHeaderButtons.None {
// FIXME            [NSException raise:NSInvalidArgumentException format:@"Buttons must be set before initializing PAPPhotoHeaderView."];
            fatalError("Buttons must be set before initializing PAPPhotoHeaderView.")
        }
    }
    
    func didTapUserButtonAction(sender: UIButton) {
        if delegate != nil && delegate!.respondsToSelector(Selector("photoHeaderView:didTapUserButton:user:")) {
            delegate!.photoHeaderView!(self, didTapUserButton: sender, user: self.photo![kPAPPhotoUserKey] as! PFUser)
        }
    }
    
    func didTapLikePhotoButtonAction(button: UIButton) {
        if delegate != nil && delegate!.respondsToSelector(Selector("photoHeaderView:didTapLikePhotoButton:photo:")) {
            delegate!.photoHeaderView!(self, didTapLikePhotoButton: button, photo: self.photo!)
        }
    }
    
    func didTapCommentOnPhotoButtonAction(sender: UIButton) {
        if delegate != nil && delegate!.respondsToSelector(Selector("photoHeaderView:didTapCommentOnPhotoButton:photo:")) {
            delegate!.photoHeaderView!(self, didTapCommentOnPhotoButton: sender, photo: self.photo!)
        }
    }
    

}

/*!
 The protocol defines methods a delegate of a PAPPhotoHeaderView should implement.
 All methods of the protocol are optional.
 */
@objc protocol PAPPhotoHeaderViewDelegate: NSObjectProtocol {
    /*!
     Sent to the delegate when the user button is tapped
     @param user the PFUser associated with this button
     */
    optional func photoHeaderView(photoHeaderView: PAPPhotoHeaderView, didTapUserButton button: UIButton, user: PFUser)

    /*!
     Sent to the delegate when the like photo button is tapped
     @param photo the PFObject for the photo that is being liked or disliked
     */
    optional func photoHeaderView(photoHeaderView: PAPPhotoHeaderView, didTapLikePhotoButton button: UIButton, photo: PFObject)

    /*!
     Sent to the delegate when the comment on photo button is tapped
     @param photo the PFObject for the photo that will be commented on
     */
    optional func photoHeaderView(photoHeaderView: PAPPhotoHeaderView, didTapCommentOnPhotoButton buton: UIButton, photo: PFObject)
}