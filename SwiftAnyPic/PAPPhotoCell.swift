import UIKit
import ParseUI

class PAPPhotoCell: PFTableViewCell {
    var photoButton: UIButton?

    // MARK:- NSObject

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
     
        // Initialization code
        self.opaque = false
        self.selectionStyle = UITableViewCellSelectionStyle.None
        self.accessoryType = UITableViewCellAccessoryType.None
        self.clipsToBounds = false
        
        self.backgroundColor = UIColor.clearColor()
        
        self.imageView!.frame = CGRectMake(0.0, 0.0, self.bounds.size.width, self.bounds.size.width)
        self.imageView!.backgroundColor = UIColor.blackColor()
        self.imageView!.contentMode = UIViewContentMode.ScaleAspectFit
        
        self.photoButton = UIButton(type: UIButtonType.Custom)
        self.photoButton!.frame = CGRectMake(0.0, 0.0, self.bounds.size.width, self.bounds.size.width)
        self.photoButton!.backgroundColor = UIColor.clearColor()
        self.contentView.addSubview(self.photoButton!)
        
        self.contentView.bringSubviewToFront(self.imageView!)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK:- UIView

    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView!.frame = CGRectMake(0.0, 0.0, self.bounds.size.width, self.bounds.size.width)
        self.photoButton!.frame = CGRectMake(0.0, 0.0, self.bounds.size.width, self.bounds.size.width)
    }
}
