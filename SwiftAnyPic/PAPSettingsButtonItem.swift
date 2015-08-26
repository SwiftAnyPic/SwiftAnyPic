import UIKit

class PAPSettingsButtonItem: UIBarButtonItem {

    // MARK:- Initialization

    init(target: AnyObject, action: Selector) {
        let settingsButton: UIButton = UIButton(type: UIButtonType.Custom)

        super.init()
        customView = settingsButton
//        [settingsButton setBackgroundImage:[UIImage imageNamed:@"ButtonSettings.png"] forState:UIControlStateNormal];
        settingsButton.addTarget(target, action: action, forControlEvents: UIControlEvents.TouchUpInside)
        settingsButton.frame = CGRectMake(0.0, 0.0, 35.0, 32.0)
        settingsButton.setImage(UIImage(named: "ButtonImageSettings.png"), forState: UIControlState.Normal)
        settingsButton.setImage(UIImage(named: "ButtonImageSettingsSelected.png"), forState:UIControlState.Highlighted)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
