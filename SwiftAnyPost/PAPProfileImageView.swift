import UIKit
import ParseUI

class PAPProfileImageView: UIView {

    var profileButton: UIButton?
    var profileImageView: PFImageView?
    var borderImageview: UIImageView?

    // MARK:- NSObject

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clearColor()
        
        self.profileImageView = PFImageView(frame: frame)
        self.addSubview(self.profileImageView!)
        
        self.profileButton = UIButton(type: UIButtonType.Custom)
        self.addSubview(self.profileButton!)
        
// FIXME: It crashed here. Who will set borderImageView actually?        self.addSubview(self.borderImageview!)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    // MARK:- UIView

    override func layoutSubviews() {
        super.layoutSubviews()
// FIXME: Who should set the borderImageView?        self.bringSubviewToFront(self.borderImageview!)
        
        self.profileImageView!.frame = CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height)
// FIXME: Who should set the borderImageView?        self.borderImageview!.frame = CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height)
        self.profileButton!.frame = CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height)
    }


    // MARK:- PAPProfileImageView

    func setFile(file: PFFile?) {
        if file == nil {
            return
        }

        self.profileImageView!.image = UIImage(named: "AvatarPlaceholder.png")
        self.profileImageView!.file = file
        self.profileImageView!.loadInBackground()
    }

    func setImage(image: UIImage) {
        self.profileImageView!.image = image
    }
}
