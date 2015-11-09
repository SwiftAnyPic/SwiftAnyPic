import UIKit

class PAPPhotoDetailsFooterView: UIView {

    private var mainView: UIView!
    
    var commentField: UITextField!
    var hideDropShadow: Bool = false

    // MARK:- NSObject

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Initialization code
        self.backgroundColor = UIColor.clearColor()
        
        mainView = UIView(frame: CGRectMake(0.0, 0.0, 320.0, 51.0))
        mainView.backgroundColor = UIColor.whiteColor()
        self.addSubview(mainView)
        
        let messageIcon = UIImageView(image: UIImage(named: "IconAddComment.png"))
        messageIcon.frame = CGRectMake(20.0, 15.0, 22.0, 22.0)
        mainView.addSubview(messageIcon)
        
        let commentBox = UIImageView(image: UIImage(named: "TextFieldComment.png")!.resizableImageWithCapInsets(UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0)))
        commentBox.frame = CGRectMake(55.0, 8.0, 237.0, 34.0)
        mainView.addSubview(commentBox)
        
        commentField = UITextField(frame: CGRectMake(66.0, 8.0, 217.0, 34.0))
        commentField.font = UIFont.systemFontOfSize(14.0)
        commentField.placeholder = "Add a comment"
        commentField.returnKeyType = UIReturnKeyType.Send
        commentField.textColor = UIColor(red: 34.0/255.0, green: 34.0/255.0, blue: 34.0/255.0, alpha: 1.0)
        commentField.contentVerticalAlignment = UIControlContentVerticalAlignment.Center
        commentField.setValue(UIColor(red: 114.0/255.0, green: 114.0/255.0, blue: 114.0/255.0, alpha: 1.0), forKeyPath: "_placeholderLabel.textColor") // Are we allowed to modify private properties like this? -Héctor
        mainView.addSubview(commentField)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK:- PAPPhotoDetailsFooterView

    class func rectForView() -> CGRect {
        return CGRectMake(0.0, 0.0, UIScreen.mainScreen().bounds.size.width, 69.0)
    }
}
