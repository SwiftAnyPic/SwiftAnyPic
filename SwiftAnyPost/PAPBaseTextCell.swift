import UIKit
import FormatterKit
import CoreGraphics
import ParseUI

var timeFormatter: TTTTimeIntervalFormatter?

/*! Layout constants */
private let vertBorderSpacing: CGFloat = 8.0
private let vertElemSpacing: CGFloat = 0.0

private let horiBorderSpacing: CGFloat = 8.0
private let horiBorderSpacingBottom: CGFloat = 9.0
private let horiElemSpacing: CGFloat = 5.0

private let vertTextBorderSpacing: CGFloat = 10.0

private let avatarX: CGFloat = horiBorderSpacing
private let avatarY: CGFloat = vertBorderSpacing
private let avatarDim: CGFloat = 33.0

private let nameX: CGFloat = avatarX+avatarDim+horiElemSpacing
private let nameY: CGFloat = vertTextBorderSpacing
private let nameMaxWidth: CGFloat = 200.0

private let timeX: CGFloat = avatarX+avatarDim+horiElemSpacing

class PAPBaseTextCell: PFTableViewCell {
    var horizontalTextSpace: Int = 0
    var _delegate: PAPBaseTextCellDelegate?
    
    /*! 
     Unfortunately, objective-c does not allow you to redefine the type of a property,
     so we cannot set the type of the delegate here. Doing so would mean that the subclass
     of would not be able to define new delegate methods (which we do in PAPActivityCell).
     */
//    var delegate: PAPBaseTextCellDelegate? {
//        get {
//            return _delegate
//        }
//        
//        set {
//            _delegate = newValue
//        }
//    }

    /*! The cell's views. These shouldn't be modified but need to be exposed for the subclass */
    var mainView: UIView?
    var nameButton: UIButton?
    var avatarImageButton: UIButton?
    var avatarImageView: PAPProfileImageView?
    var contentLabel: UILabel?
    var timeLabel: UILabel?
    var separatorImage: UIImageView?

    var hideSeparator: Bool = false // True if the separator shouldn't be shown
    
    // MARK:- NSObject

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        // Initialization code
        cellInsetWidth = 0.0
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        if timeFormatter == nil {
            timeFormatter = TTTTimeIntervalFormatter()
        }

        hideSeparator = false
        self.clipsToBounds = true
        horizontalTextSpace = Int(PAPBaseTextCell.horizontalTextSpaceForInsetWidth(cellInsetWidth))
        
        self.opaque = true
        self.selectionStyle = UITableViewCellSelectionStyle.None
        self.accessoryType = UITableViewCellAccessoryType.None
        self.backgroundColor = UIColor.clearColor()
        
        mainView = UIView(frame: self.contentView.frame)
        mainView!.backgroundColor = UIColor.whiteColor()
        
        self.avatarImageView = PAPProfileImageView()
        self.avatarImageView!.backgroundColor = UIColor.clearColor()
        self.avatarImageView!.opaque = true
        self.avatarImageView!.layer.cornerRadius = 16.0
        self.avatarImageView!.layer.masksToBounds = true
        mainView!.addSubview(self.avatarImageView!)
                
        self.nameButton = UIButton(type: UIButtonType.Custom)
        self.nameButton!.backgroundColor = UIColor.clearColor()
        
        if reuseIdentifier == "ActivityCell" {
            self.nameButton!.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
            self.nameButton!.setTitleColor(UIColor(red: 114.0/255.0, green: 114.0/255.0, blue: 114.0/255.0, alpha: 1.0), forState: UIControlState.Highlighted)
        } else {
            self.nameButton!.setTitleColor(UIColor(red: 34.0/255.0, green: 34.0/255.0, blue: 34.0/255.0, alpha: 1.0), forState: UIControlState.Normal)
            self.nameButton!.setTitleColor(UIColor(red: 114.0/255.0, green: 114.0/255.0, blue: 114.0/255.0, alpha: 1.0), forState: UIControlState.Highlighted)
        }
        self.nameButton!.titleLabel!.font = UIFont.boldSystemFontOfSize(13)
        self.nameButton!.titleLabel!.lineBreakMode = NSLineBreakMode.ByTruncatingTail
        self.nameButton!.addTarget(self, action: Selector("didTapUserButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)
        mainView!.addSubview(self.nameButton!)
        
        self.contentLabel = UILabel()
        self.contentLabel!.font = UIFont.systemFontOfSize(13.0)
        if reuseIdentifier == "ActivityCell" {
            self.contentLabel!.textColor = UIColor.whiteColor()
        } else {
            self.contentLabel!.textColor = UIColor(red: 34.0/255.0, green: 34.0/255.0, blue: 34.0/255.0, alpha: 1.0)
        }
        self.contentLabel!.numberOfLines = 0
        self.contentLabel!.lineBreakMode = NSLineBreakMode.ByWordWrapping
        self.contentLabel!.backgroundColor = UIColor.clearColor()
        mainView!.addSubview(self.contentLabel!)
        
        self.timeLabel = UILabel()
        self.timeLabel!.font = UIFont.systemFontOfSize(11)
        self.timeLabel!.textColor = UIColor(red: 114.0/255.0, green: 114.0/255.0, blue: 114.0/255.0, alpha: 1.0)
        self.timeLabel!.backgroundColor = UIColor.clearColor()
        mainView!.addSubview(self.timeLabel!)
        
        
        self.avatarImageButton = UIButton(type: UIButtonType.Custom)
        self.avatarImageButton!.backgroundColor = UIColor.clearColor()
        self.avatarImageButton!.addTarget(self, action: Selector("didTapUserButtonAction:"), forControlEvents: UIControlEvents.TouchUpInside)

        mainView!.addSubview(self.avatarImageButton!)
        
        self.separatorImage = UIImageView(image: UIImage(named: "SeparatorComments.png")!.resizableImageWithCapInsets(UIEdgeInsetsMake(0, 1, 0, 1)))
        //[mainView addSubview:separatorImage];
        
        self.contentView.addSubview(mainView!)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    // MARK:- UIView

    override func layoutSubviews() {
        super.layoutSubviews()
        
       mainView!.frame = CGRectMake(cellInsetWidth, self.contentView.frame.origin.y, self.contentView.frame.size.width-2*cellInsetWidth, self.contentView.frame.size.height)
        
        // Layout avatar image
        self.avatarImageView!.frame = CGRectMake(avatarX, avatarY + 5.0, avatarDim, avatarDim)
        self.avatarImageButton!.frame = CGRectMake(avatarX, avatarY + 5.0, avatarDim, avatarDim)
        
        // Layout the name button
        let nameSize: CGSize = self.nameButton!.titleLabel!.text!.boundingRectWithSize(CGSizeMake(nameMaxWidth, CGFloat.max),
                                                        options: [NSStringDrawingOptions.TruncatesLastVisibleLine, NSStringDrawingOptions.UsesLineFragmentOrigin], // word wrap?
                                                     attributes: [NSFontAttributeName: UIFont.boldSystemFontOfSize(13.0)],
                                                        context: nil).size
        self.nameButton!.frame = CGRectMake(nameX, nameY + 6.0, nameSize.width, nameSize.height)
        
        // Layout the content
        let contentSize: CGSize = self.contentLabel!.text!.boundingRectWithSize(CGSizeMake(CGFloat(horizontalTextSpace), CGFloat.max),
                                                        options: NSStringDrawingOptions.UsesLineFragmentOrigin,
                                                     attributes: [NSFontAttributeName: UIFont.systemFontOfSize(13.0)],
                                                        context: nil).size
        self.contentLabel!.frame = CGRectMake(nameX, vertTextBorderSpacing + 6.0, contentSize.width, contentSize.height)
        
        // Layout the timestamp label
        let timeSize: CGSize = self.timeLabel!.text!.boundingRectWithSize(CGSizeMake(CGFloat(horizontalTextSpace), CGFloat.max),
                                                        options: [NSStringDrawingOptions.TruncatesLastVisibleLine, NSStringDrawingOptions.UsesLineFragmentOrigin],
                                                     attributes: [NSFontAttributeName: UIFont.systemFontOfSize(11.0)],
                                                        context: nil).size
        self.timeLabel!.frame = CGRectMake(timeX, contentLabel!.frame.origin.y + contentLabel!.frame.size.height + vertElemSpacing, timeSize.width, timeSize.height)
        
        // Layour separator
        self.separatorImage!.frame = CGRectMake(0, self.frame.size.height-1, self.frame.size.width-cellInsetWidth*2, 1)
        self.separatorImage!.hidden = hideSeparator
    }


    // MARK:- Delegate methods

    /* Inform delegate that a user image or name was tapped */
    func didTapUserButtonAction(sender: AnyObject) {
        if self.delegate != nil && self.delegate!.respondsToSelector(Selector("cell:didTapUserButton:")) {
            self.delegate!.cell(self, didTapUserButton: self.user!)
        }
    }

    // MARK:- PAPBaseTextCell

    /* Static helper to get the height for a cell if it had the given name and content */
    class func heightForCellWithName(name: String, contentString content: String) -> CGFloat {
        return PAPBaseTextCell.heightForCellWithName(name, contentString: content, cellInsetWidth: 0)
    }

    /* Static helper to get the height for a cell if it had the given name, content and horizontal inset */
    class func heightForCellWithName(name: String, contentString content: String, cellInsetWidth cellInset: CGFloat) -> CGFloat {
// FIXME: Why nameSize is used before as the argument at the same time????        let nameSize: CGSize = name.boundingRectWithSize(nameSize,
        let nameSize: CGSize = name.boundingRectWithSize(CGSizeMake(nameMaxWidth, CGFloat.max),
                                                        options: [NSStringDrawingOptions.TruncatesLastVisibleLine, NSStringDrawingOptions.UsesLineFragmentOrigin],
                                                     attributes: [NSFontAttributeName: UIFont.boldSystemFontOfSize(13.0)],
                                                        context: nil).size

        let paddedString: String = PAPBaseTextCell.padString(content, withFont: UIFont.systemFontOfSize(13), toWidth: nameSize.width)
        let horizontalTextSpace: CGFloat = PAPBaseTextCell.horizontalTextSpaceForInsetWidth(cellInset)
       
        let contentSize: CGSize = paddedString.boundingRectWithSize(CGSizeMake(horizontalTextSpace, CGFloat.max),
                                                        options: NSStringDrawingOptions.UsesLineFragmentOrigin, // word wrap?
                                                     attributes: [NSFontAttributeName: UIFont.systemFontOfSize(13.0)],
                                                        context: nil).size

        let singleLineHeight: CGFloat = "test".boundingRectWithSize(CGSizeMake(CGFloat.max, CGFloat.max),
                                                         options: NSStringDrawingOptions.UsesLineFragmentOrigin,
                                                      attributes: [NSFontAttributeName: UIFont.systemFontOfSize(13.0)],
                                                         context: nil).size.height
        
        // Calculate the added height necessary for multiline text. Ensure value is not below 0.
        let multilineHeightAddition: CGFloat = (contentSize.height - singleLineHeight) > 0 ? (contentSize.height - singleLineHeight) : 0
        
        return horiBorderSpacing + avatarDim + horiBorderSpacingBottom + multilineHeightAddition
    }

    /* Static helper to obtain the horizontal space left for name and content after taking the inset and image in consideration */
    class func horizontalTextSpaceForInsetWidth(insetWidth: CGFloat) -> CGFloat {
        return (320-(insetWidth*2)) - (horiBorderSpacing+avatarDim+horiElemSpacing+horiBorderSpacing)
    }

    /* Static helper to pad a string with spaces to a given beginning offset */
    class func padString(string: String, withFont font: UIFont, toWidth width: CGFloat) -> String {
        // Find number of spaces to pad
        var paddedString = ""
        while (true) {
            paddedString += " "
            let resultSize: CGSize = paddedString.boundingRectWithSize(CGSizeMake(CGFloat.max, CGFloat.max),
                                                            options: [NSStringDrawingOptions.TruncatesLastVisibleLine, NSStringDrawingOptions.UsesLineFragmentOrigin],
                                                         attributes: [NSFontAttributeName: font],
                                                            context: nil).size
            if resultSize.width >= width {
                break
            }
        }
        
        // Add final spaces to be ready for first word
        paddedString += " \(string)"
        return paddedString
    }

    /*! The user represented in the cell */
    var user: PFUser? {
        didSet {
            // Set name button properties and avatar image
            if PAPUtility.userHasProfilePictures(self.user!) {
                self.avatarImageView!.setFile(self.user!.objectForKey(kPAPUserProfilePicSmallKey) as? PFFile)
            } else {
                self.avatarImageView!.setImage(PAPUtility.defaultProfilePicture()!)
            }

            self.nameButton!.setTitle(self.user!.objectForKey(kPAPUserDisplayNameKey) as? String, forState: UIControlState.Normal)
            self.nameButton!.setTitle(self.user!.objectForKey(kPAPUserDisplayNameKey) as? String, forState:UIControlState.Highlighted)
            
            // If user is set after the contentText, we reset the content to include padding
            if self.contentLabel!.text != nil {
                self.setContentText(self.contentLabel!.text!)
            }
            self.setNeedsDisplay()
        }
    }

    func setContentText(contentString: String) {
        // If we have a user we pad the content with spaces to make room for the name
        if self.user != nil {
            let nameSize: CGSize = self.nameButton!.titleLabel!.text!.boundingRectWithSize(CGSizeMake(nameMaxWidth, CGFloat.max),
                                                            options: [NSStringDrawingOptions.TruncatesLastVisibleLine, NSStringDrawingOptions.UsesLineFragmentOrigin],
                                                         attributes: [NSFontAttributeName: UIFont.boldSystemFontOfSize(13.0)],
                                                            context: nil).size
            let paddedString: String = PAPBaseTextCell.padString(contentString, withFont: UIFont.systemFontOfSize(13), toWidth: nameSize.width)
            self.contentLabel!.text = paddedString
        } else { // Otherwise we ignore the padding and we'll add it after we set the user
            self.contentLabel!.text = contentString
        }
        self.setNeedsDisplay()
    }

    func setDate(date: NSDate) {
        // Set the label with a human readable time
        self.timeLabel!.text = timeFormatter!.stringForTimeIntervalFromDate(NSDate(), toDate: date)
        self.setNeedsDisplay()
    }

    /*! The horizontal inset of the cell */
    var cellInsetWidth: CGFloat {
        didSet {
            // Change the mainView's frame to be insetted by insetWidth and update the content text space
            mainView!.frame = CGRectMake(cellInsetWidth, mainView!.frame.origin.y, mainView!.frame.size.width-2*cellInsetWidth, mainView!.frame.size.height)
            horizontalTextSpace = Int(PAPBaseTextCell.horizontalTextSpaceForInsetWidth(cellInsetWidth))
            self.setNeedsDisplay()
        }
    }

    /* Since we remove the compile-time check for the delegate conforming to the protocol
     in order to allow inheritance, we add run-time checks. */
    var delegate: PAPBaseTextCellDelegate? {
        get {
            return _delegate
        }
        
        set {
            // FIXME: any other way to check?
            if _delegate?.hash != newValue!.hash {
                _delegate = newValue
            }
        }
    }

    func hideSeparator(hide: Bool) {
        hideSeparator = hide
    }
}

@objc protocol PAPBaseTextCellDelegate: NSObjectProtocol {
    /*!
     Sent to the delegate when a user button is tapped
     @param aUser the PFUser of the user that was tapped
     */
    func cell(cellView: PAPBaseTextCell, didTapUserButton aUser: PFUser)
}