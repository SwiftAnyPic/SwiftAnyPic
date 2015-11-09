import UIKit

class PAPImageView: UIImageView {

    var placeholderImage: UIImage?

    private var currentFile: PFFile?
    private var url: String?

    // MARK:- PAPImageView

    func setFile(file: PFFile) {
        
        let requestURL: String? = file.url; // Save copy of url locally (will not change in block)
        self.url = file.url // Save copy of url on the instance
        
        file.getDataInBackgroundWithBlock { (data, error) in
            if error == nil {
                let image = UIImage(data: data!)
                if requestURL == self.url {
                    self.image = image
                    self.setNeedsDisplay()
                }
            } else {
                print("Error on fetching file")
            }
        }
    }

}
