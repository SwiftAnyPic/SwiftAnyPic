import UIKit
import FormatterKit

// FIXME: redeclaration!!!! var timeFormatter: TTTTimeIntervalFormatter?
private let nameMaxWidth: CGFloat = 200.0

class PAPActivityCell: PAPBaseTextCell {

    /*! Private view components */
    var activityImageView: PAPProfileImageView?
    var activityImageButton: UIButton?

    /*! Flag to remove the right-hand side image if not necessary */
    var hasActivityImage: Bool = false
    
    // MARK:- NSObject
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        horizontalTextSpace = Int(PAPActivityCell.horizontalTextSpaceForInsetWidth(0))
        
        if timeFormatter == nil {
            timeFormatter = TTTTimeIntervalFormatter()
        }
        
        // Create subviews and set cell properties
        self.opaque = true
        self.selectionStyle = UITableViewCellSelectionStyle.None
        self.accessoryType = UITableViewCellAccessoryType.None
        self.hasActivityImage = false //No until one is set
        
        self.activityImageView = PAPProfileImageView()
        self.activityImageView!.backgroundColor = UIColor.clearColor()
        self.activityImageView!.opaque = true
        self.mainView!.addSubview(self.activityImageView!)
        
        self.activityImageButton = UIButton(type: UIButtonType.Custom)
        self.activityImageButton!.backgroundColor = UIColor.clearColor()
        self.activityImageButton!.addTarget(self, action: Selector("didTapActivityButton:"), forControlEvents: UIControlEvents.TouchUpInside)
        self.mainView!.addSubview(self.activityImageButton!)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK:- UIView
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Layout the activity image and show it if it is not nil (no image for the follow activity).
        // Note that the image view is still allocated and ready to be dispalyed since these cells
        // will be reused for all types of activity.
        self.activityImageView!.frame = CGRectMake(UIScreen.mainScreen().bounds.size.width - 46.0, 13.0, 33.0, 33.0)
        self.activityImageButton!.frame = CGRectMake(UIScreen.mainScreen().bounds.size.width - 46.0, 13.0, 33.0, 33.0)
        
        // Add activity image if one was set
        if self.hasActivityImage {
            self.activityImageView!.hidden = false
            self.activityImageButton!.hidden = false
        } else {
            self.activityImageView!.hidden = true
            self.activityImageButton!.hidden = true
        }
        
        // Change frame of the content text so it doesn't go through the right-hand side picture
        let contentSize: CGSize = self.contentLabel!.text!.boundingRectWithSize(CGSizeMake(UIScreen.mainScreen().bounds.size.width - 72.0 - 46.0, CGFloat.max),
                                                                                options: NSStringDrawingOptions.UsesLineFragmentOrigin, // wordwrap?
                                                                                attributes: [NSFontAttributeName: UIFont.systemFontOfSize(13.0)],
                                                                                context: nil).size
        self.contentLabel!.frame = CGRectMake(46.0, 16.0, contentSize.width, contentSize.height)
        
        // Layout the timestamp label given new vertical
        let timeSize: CGSize = self.timeLabel!.text!.boundingRectWithSize(CGSizeMake(UIScreen.mainScreen().bounds.size.width - 72.0 - 46.0, CGFloat.max),
                                                                            options: [NSStringDrawingOptions.TruncatesLastVisibleLine, NSStringDrawingOptions.UsesLineFragmentOrigin],
                                                                            attributes: [NSFontAttributeName: UIFont.systemFontOfSize(11.0)],
                                                                            context: nil).size
        self.timeLabel!.frame = CGRectMake(46.0, self.contentLabel!.frame.origin.y + self.contentLabel!.frame.size.height + 7.0, timeSize.width, timeSize.height)
    }
    
    
    // MARK:- PAPActivityCell

    /*!Set the new state. This changes the background of the cell. */
    func setIsNew(isNew: Bool) {
        if isNew {
            self.mainView!.backgroundColor = UIColor(red: 29.0/255.0, green: 29.0/255.0, blue: 29.0/255.0, alpha: 1.0)
        } else {
            self.mainView!.backgroundColor = UIColor.blackColor()
        }
    }
    
    /*!Setter for the activity associated with this cell */
    var activity: PFObject? {
        didSet {
            if (activity!.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeFollow || (activity!.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeJoined {
                self.setActivityImageFile(nil)
            } else {
                self.setActivityImageFile((activity!.objectForKey(kPAPActivityPhotoKey) as! PFObject).objectForKey(kPAPPhotoThumbnailKey) as? PFFile)
            }
            
            let activityString: String = PAPActivityFeedViewController.stringForActivityType(activity!.objectForKey(kPAPActivityTypeKey) as! String)!
            self.user = activity!.objectForKey(kPAPActivityFromUserKey) as? PFUser
            
            // Set name button properties and avatar image
            if PAPUtility.userHasProfilePictures(self.user!) {
                self.avatarImageView!.setFile(self.user!.objectForKey(kPAPUserProfilePicSmallKey) as? PFFile)
            } else {
                self.avatarImageView!.setImage(PAPUtility.defaultProfilePicture()!)
            }
            
            var nameString: String = NSLocalizedString("Someone", comment: "Text when the user's name is unknown")
            if self.user?.objectForKey(kPAPUserDisplayNameKey)?.length > 0 {
                nameString = self.user!.objectForKey(kPAPUserDisplayNameKey) as! String
            }
            
            self.nameButton!.setTitle(nameString, forState: UIControlState.Normal)
            self.nameButton!.setTitle(nameString, forState: UIControlState.Highlighted)
            
            // If user is set after the contentText, we reset the content to include padding
            if self.contentLabel!.text?.length > 0 {
                self.setContentText(self.contentLabel!.text!)
            }
            
            if self.user != nil {
                let nameSize: CGSize  = self.nameButton!.titleLabel!.text!.boundingRectWithSize(CGSizeMake(nameMaxWidth, CGFloat.max),
                                                                                                options: [NSStringDrawingOptions.TruncatesLastVisibleLine, NSStringDrawingOptions.UsesLineFragmentOrigin],
                                                                                                attributes: [NSFontAttributeName: UIFont.boldSystemFontOfSize(13.0)],
                                                                                                context: nil).size
                let paddedString: String = PAPBaseTextCell.padString(activityString, withFont: UIFont.systemFontOfSize(13.0), toWidth: nameSize.width)
                self.contentLabel!.text = paddedString
            } else { // Otherwise we ignore the padding and we'll add it after we set the user
                self.contentLabel!.text = activityString
            }
            
            self.timeLabel!.text = timeFormatter!.stringForTimeIntervalFromDate(NSDate(), toDate: activity!.createdAt!)
            
            self.setNeedsDisplay()
        }
    }
    
    override var cellInsetWidth: CGFloat {
        get {
            return super.cellInsetWidth
        }
        
        set {
            super.cellInsetWidth = newValue
            horizontalTextSpace = Int(PAPActivityCell.horizontalTextSpaceForInsetWidth(newValue))
        }
    }
    
    // Since we remove the compile-time check for the delegate conforming to the protocol
    // in order to allow inheritance, we add run-time checks.
    // FIXME: Do we need this in Swift???
//    - (id<PAPActivityCellDelegate>)delegate {
//        return (id<PAPActivityCellDelegate>)_delegate;
//    }
//    
//    - (void)setDelegate:(id<PAPActivityCellDelegate>)delegate {
//        if(_delegate != delegate) {
//            _delegate = delegate;
//        }
//    }
    
    
    // MARK:- ()
    
    override class func horizontalTextSpaceForInsetWidth(insetWidth: CGFloat) -> CGFloat {
        return (UIScreen.mainScreen().bounds.size.width - (insetWidth * 2.0)) - 72.0 - 46.0
    }
    
    override class func heightForCellWithName(name: String, contentString content: String) -> CGFloat {
        return self.heightForCellWithName(name, contentString: content, cellInsetWidth: 0.0)
    }
    
    override class func heightForCellWithName(name: String, contentString content: String, cellInsetWidth cellInset: CGFloat) -> CGFloat {
        let nameSize: CGSize = name.boundingRectWithSize(CGSizeMake(200.0, CGFloat.max),
                                                        options: [NSStringDrawingOptions.TruncatesLastVisibleLine, NSStringDrawingOptions.UsesLineFragmentOrigin],
                                                        attributes: [NSFontAttributeName: UIFont.boldSystemFontOfSize(13.0)],
                                                        context: nil).size
        let paddedString: String = PAPBaseTextCell.padString(content, withFont: UIFont.systemFontOfSize(13.0), toWidth: nameSize.width)
        let horizontalTextSpace: CGFloat = PAPActivityCell.horizontalTextSpaceForInsetWidth(cellInset)
        
        let contentSize: CGSize = paddedString.boundingRectWithSize(CGSizeMake(horizontalTextSpace, CGFloat.max),
                                                                    options: NSStringDrawingOptions.UsesLineFragmentOrigin, // wordwrap?
                                                                    attributes: [NSFontAttributeName: UIFont.systemFontOfSize(13.0)],
                                                                    context: nil).size
        
        let singleLineHeight: CGFloat = "Test".boundingRectWithSize(CGSizeMake(CGFloat.max, CGFloat.max),
                                                                    options: NSStringDrawingOptions.UsesLineFragmentOrigin,
                                                                    attributes: [NSFontAttributeName: UIFont.systemFontOfSize(13.0)],
                                                                    context: nil).size.height
        
        // Calculate the added height necessary for multiline text. Ensure value is not below 0.
        let multilineHeightAddition: CGFloat = contentSize.height - singleLineHeight
        
        return 58.0 + fmax(0.0, multilineHeightAddition)
    }
    
    func setActivityImageFile(imageFile: PFFile?) {
        if imageFile != nil {
            self.activityImageView!.setFile(imageFile)
            self.hasActivityImage = true
        } else {
            self.hasActivityImage = false
        }
    }
    
    func didTapActivityButton(sender: AnyObject) {
        if self.delegate?.respondsToSelector(Selector("cell:didTapActivityButton:")) != nil {
            (self.delegate! as! PAPActivityCellDelegate).cell(self, didTapActivityButton: self.activity!)
        }
    }
    
    
}

@objc protocol PAPActivityCellDelegate: PAPBaseTextCellDelegate {
    /*!
     Sent to the delegate when the activity button is tapped
     @param activity the PFObject of the activity that was tapped
     */
    func cell(cellView: PAPActivityCell, didTapActivityButton activity: PFObject)
}
