import Foundation
import ParseUI

class PAPFindFriendsCell: PFTableViewCell {
    var delegate: PAPFindFriendsCellDelegate?
    
    var photoLabel: UILabel!
    var followButton: UIButton!
    
    /*! The cell's views. These shouldn't be modified but need to be exposed for the subclass */
    var nameButton: UIButton!
    var avatarImageButton: UIButton!
    var avatarImageView: PAPProfileImageView!

    // MARK:- NSObject

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = UIColor.blackColor()
        self.selectionStyle = UITableViewCellSelectionStyle.None

        self.avatarImageView = PAPProfileImageView()
        self.avatarImageView.frame = CGRectMake(10.0, 14.0, 40.0, 40.0)
        self.avatarImageView.layer.cornerRadius = 20.0
        self.avatarImageView.layer.masksToBounds = true
        self.contentView.addSubview(self.avatarImageView)
        
        self.avatarImageButton = UIButton(type: UIButtonType.Custom)
        self.avatarImageButton.backgroundColor = UIColor.clearColor()
        self.avatarImageButton.frame = CGRectMake(10.0, 14.0, 40.0, 40.0)
        self.avatarImageButton.addTarget(self, action: Selector("didTapUserButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)
        self.contentView.addSubview(self.avatarImageButton)
        
        self.nameButton = UIButton(type: UIButtonType.Custom)
        self.nameButton.backgroundColor = UIColor.clearColor()
        self.nameButton.titleLabel!.font = UIFont.boldSystemFontOfSize(16.0)
        self.nameButton.titleLabel!.lineBreakMode = NSLineBreakMode.ByTruncatingTail
        self.nameButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        self.nameButton.setTitleColor(UIColor(red: 114.0/255.0, green: 114.0/255.0, blue: 114.0/255.0, alpha: 1.0), forState: UIControlState.Highlighted)
        self.nameButton.addTarget(self, action: Selector("didTapUserButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)
        self.contentView.addSubview(self.nameButton)
        
        self.photoLabel = UILabel()
        self.photoLabel.font = UIFont.systemFontOfSize(11.0)
        self.photoLabel.textColor = UIColor.grayColor()
        self.photoLabel.backgroundColor = UIColor.clearColor()
        self.contentView.addSubview(self.photoLabel)
        
        self.followButton = UIButton(type: UIButtonType.Custom)
        self.followButton.titleLabel!.font = UIFont.boldSystemFontOfSize(15.0)
        self.followButton.titleEdgeInsets = UIEdgeInsetsMake(0.0, 10.0, 0.0, 0.0)
        self.followButton.setBackgroundImage(UIImage(named: "ButtonFollow.png"), forState: UIControlState.Normal)
        self.followButton.setBackgroundImage(UIImage(named: "ButtonFollowing.png"), forState: UIControlState.Selected)
        self.followButton.setImage(UIImage(named: "IconTick.png"), forState: UIControlState.Selected)
        self.followButton.setTitle(NSLocalizedString("Follow  ", comment: "Follow string, with spaces added for centering"), forState: UIControlState.Normal)
        self.followButton.setTitle("Following", forState: UIControlState.Selected)
        self.followButton.setTitleColor(UIColor(red: 254.0/255.0, green: 149.0/255.0, blue: 50.0/255.0, alpha: 1.0), forState: UIControlState.Normal)
        self.followButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Selected)
        self.followButton.addTarget(self, action: Selector("didTapFollowButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)
        self.contentView.addSubview(self.followButton)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    // MARK:- PAPFindFriendsCell

    /*! The user represented in the cell */
    var user: PFUser? {
        didSet {
            // Configure the cell
            if PAPUtility.userHasProfilePictures(self.user!) {
                self.avatarImageView.setFile(self.user!.objectForKey(kPAPUserProfilePicSmallKey) as? PFFile)
            } else {
                self.avatarImageView.setImage(PAPUtility.defaultProfilePicture()!)
            }
            
            // Set name 
            let nameString: String = self.user!.objectForKey(kPAPUserDisplayNameKey) as! String
            let nameSize: CGSize = nameString.boundingRectWithSize(CGSizeMake(144.0, CGFloat.max),
                                                            options: [NSStringDrawingOptions.TruncatesLastVisibleLine, NSStringDrawingOptions.UsesLineFragmentOrigin],
                                                         attributes: [NSFontAttributeName: UIFont.boldSystemFontOfSize(16.0)],
                                                            context: nil).size
            nameButton.setTitle(self.user!.objectForKey(kPAPUserDisplayNameKey) as? String, forState: UIControlState.Normal)
            nameButton.setTitle(self.user!.objectForKey(kPAPUserDisplayNameKey) as? String, forState: UIControlState.Highlighted)

            nameButton.frame = CGRectMake(60.0, 17.0, nameSize.width, nameSize.height)
            
            // Set photo number label
            let photoLabelSize: CGSize = "photos".boundingRectWithSize(CGSizeMake(144.0, CGFloat.max),
                                                            options: [NSStringDrawingOptions.TruncatesLastVisibleLine, NSStringDrawingOptions.UsesLineFragmentOrigin],
                                                         attributes: [NSFontAttributeName: UIFont.systemFontOfSize(11.0)],
                                                            context: nil).size
            photoLabel.frame = CGRectMake(60.0, 17.0 + nameSize.height, 140.0, photoLabelSize.height)
            
            // Set follow button
            followButton.frame = CGRectMake(208.0, 20.0, 103.0, 32.0)
        }
    }

    // MARK:- ()

    class func heightForCell() -> CGFloat {
        return 67.0
    }

    /* Inform delegate that a user image or name was tapped */
    func didTapUserButtonAction(sender: AnyObject) {
        if self.delegate?.respondsToSelector(Selector("cell:didTapUserButton:")) != nil {
            self.delegate!.cell(self, didTapUserButton: self.user!)
        }    
    }

    /* Inform delegate that the follow button was tapped */
    func didTapFollowButtonAction(sender: AnyObject) {
        if self.delegate?.respondsToSelector(Selector("cell:didTapFollowButton:")) != nil {
            self.delegate!.cell(self, didTapFollowButton: self.user!)
        }        
    }
}

@objc protocol PAPFindFriendsCellDelegate: NSObjectProtocol {
    /*!
     Sent to the delegate when a user button is tapped
     @param aUser the PFUser of the user that was tapped
     */
    func cell(cellView: PAPFindFriendsCell, didTapUserButton aUser: PFUser)
    func cell(cellView: PAPFindFriendsCell, didTapFollowButton aUser: PFUser)
}
