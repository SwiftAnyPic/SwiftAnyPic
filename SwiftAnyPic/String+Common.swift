// https://gist.github.com/albertbori/0faf7de867d96eb83591

import Foundation

extension String {
    var length: Int {
        get {
            return self.characters.count
        }
    }
    
    func subString(startIndex: Int, length: Int) -> String {
        let start = advance(self.startIndex, startIndex)
        let end = advance(self.startIndex, startIndex + length)
        return self.substringWithRange(Range<String.Index>(start: start, end: end))
    }
}
