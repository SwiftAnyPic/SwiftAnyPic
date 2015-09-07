import UIKit
import ParseUI

class PAPLoadMoreCell: PFTableViewCell {
    var mainView: UIView?
    var separatorImageTop: UIImageView?
    var separatorImageBottom: UIImageView?
    var loadMoreImageView: UIImageView?

    var hideSeparatorTop: Bool = false
    var hideSeparatorBottom: Bool = false

    // MARK:- NSObject

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        // Initialization code
        self.cellInsetWidth = 0.0
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        hideSeparatorTop = false
        hideSeparatorBottom = false

        self.opaque = true
        self.selectionStyle = UITableViewCellSelectionStyle.None
        self.accessoryType = UITableViewCellAccessoryType.None
        self.backgroundColor = UIColor.clearColor()
        
        mainView = UIView(frame: self.contentView.frame)
        if reuseIdentifier == "NextPageDetails" {
            mainView!.backgroundColor = UIColor.whiteColor()
        } else {
            mainView!.backgroundColor = UIColor.blackColor()
        }
        
        // FIXME: I can't find where they are initialized in the original Anypic
        self.separatorImageTop = UIImageView(image: UIImage(named: "SeparatorComments.png"))
        self.separatorImageBottom = UIImageView(image: UIImage(named: "SeparatorComments.png"))
        
        self.loadMoreImageView = UIImageView(image: UIImage(named: "CellLoadMore.png"))
        mainView!.addSubview(self.loadMoreImageView!)

        self.contentView.addSubview(mainView!)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK:- UIView

    override func layoutSubviews() {
        mainView!.frame = CGRectMake(self.cellInsetWidth, self.contentView.frame.origin.y, self.contentView.frame.size.width-2*self.cellInsetWidth, self.contentView.frame.size.height)
        
        // Layout load more text
        self.loadMoreImageView!.frame = CGRectMake(105.0, 15.0, 111.0, 18.0)

        // Layout separator
        self.separatorImageBottom!.frame = CGRectMake(0.0, self.frame.size.height - 2.0, self.frame.size.width-self.cellInsetWidth * 2.0, 2.0)
        self.separatorImageBottom!.hidden = hideSeparatorBottom
        
        self.separatorImageTop!.frame = CGRectMake(0.0, 0.0, self.frame.size.width - self.cellInsetWidth * 2.0, 2.0)
        self.separatorImageTop!.hidden = hideSeparatorTop
    }

    override func drawRect(rect: CGRect) {
        super.drawRect(rect)
        if self.cellInsetWidth != 0.0 {
            PAPUtility.drawSideDropShadowForRect(mainView!.frame, inContext: UIGraphicsGetCurrentContext()!)
        }
    }


    // MARK:- PAPLoadMoreCell

    var cellInsetWidth: CGFloat {
        didSet {
            mainView!.frame = CGRectMake(cellInsetWidth, mainView!.frame.origin.y, mainView!.frame.size.width - 2.0 * cellInsetWidth, mainView!.frame.size.height)
            self.setNeedsDisplay()
        }
    }
}
