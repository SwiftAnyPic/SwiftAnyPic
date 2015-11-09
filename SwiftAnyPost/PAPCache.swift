import Foundation

final class PAPCache {
    private var cache: NSCache

    // MARK:- Initialization
    
    static let sharedCache = PAPCache()

    private init() {
        self.cache = NSCache()
    }

    // MARK:- PAPCache

    func clear() {
        cache.removeAllObjects()
    }

    func setAttributesForPhoto(photo: PFObject, likers: [PFUser], commenters: [PFUser], likedByCurrentUser: Bool) {
        let attributes = [
            kPAPPhotoAttributesIsLikedByCurrentUserKey: likedByCurrentUser,
            kPAPPhotoAttributesLikeCountKey: likers.count,
            kPAPPhotoAttributesLikersKey: likers,
            kPAPPhotoAttributesCommentCountKey: commenters.count,
            kPAPPhotoAttributesCommentersKey: commenters
        ]
        setAttributes(attributes as! [String : AnyObject], forPhoto: photo)
    }

    func attributesForPhoto(photo: PFObject) -> [String:AnyObject]? {
        let key: String = self.keyForPhoto(photo)
        return cache.objectForKey(key) as? [String:AnyObject]
    }

    func likeCountForPhoto(photo: PFObject) -> Int {
        let attributes: [NSObject:AnyObject]? = self.attributesForPhoto(photo)
        if attributes != nil {
            return attributes![kPAPPhotoAttributesLikeCountKey] as! Int
        }

        return 0
    }

    func commentCountForPhoto(photo: PFObject) -> Int {
        let attributes = attributesForPhoto(photo)
        if attributes != nil {
            return attributes![kPAPPhotoAttributesCommentCountKey] as! Int
        }
        
        return 0
    }

    func likersForPhoto(photo: PFObject) -> [PFUser] {
        let attributes = attributesForPhoto(photo)
        if attributes != nil {
            return attributes![kPAPPhotoAttributesLikersKey] as! [PFUser]
        }
        
        return [PFUser]()
    }

    func commentersForPhoto(photo: PFObject) -> [PFUser] {
        let attributes = attributesForPhoto(photo)
        if attributes != nil {
            return attributes![kPAPPhotoAttributesCommentersKey] as! [PFUser]
        }
        
        return [PFUser]()
    }

    func setPhotoIsLikedByCurrentUser(photo: PFObject, liked: Bool) {
        var attributes = attributesForPhoto(photo)
        attributes![kPAPPhotoAttributesIsLikedByCurrentUserKey] = liked
        setAttributes(attributes!, forPhoto: photo)
    }

    func isPhotoLikedByCurrentUser(photo: PFObject) -> Bool {
        let attributes = attributesForPhoto(photo)
        if attributes != nil {
            return attributes![kPAPPhotoAttributesIsLikedByCurrentUserKey] as! Bool
        }
        
        return false
    }

    func incrementLikerCountForPhoto(photo: PFObject) {
        let likerCount = likeCountForPhoto(photo) + 1
        var attributes = attributesForPhoto(photo)
        attributes![kPAPPhotoAttributesLikeCountKey] = likerCount
        setAttributes(attributes!, forPhoto: photo)
    }

    func decrementLikerCountForPhoto(photo: PFObject) {
        let likerCount = likeCountForPhoto(photo) - 1
        if likerCount < 0 {
            return
        }
        var attributes = attributesForPhoto(photo)
        attributes![kPAPPhotoAttributesLikeCountKey] = likerCount
        setAttributes(attributes!, forPhoto: photo)
    }

    func incrementCommentCountForPhoto(photo: PFObject) {
        let commentCount = commentCountForPhoto(photo) + 1
        var attributes = attributesForPhoto(photo)
        attributes![kPAPPhotoAttributesCommentCountKey] = commentCount
        setAttributes(attributes!, forPhoto: photo)
    }

    func decrementCommentCountForPhoto(photo: PFObject) {
        let commentCount = commentCountForPhoto(photo) - 1
        if commentCount < 0 {
            return
        }
        var attributes = attributesForPhoto(photo)
        attributes![kPAPPhotoAttributesCommentCountKey] = commentCount
        setAttributes(attributes!, forPhoto: photo)
    }

    func setAttributesForUser(user: PFUser, photoCount count: Int, followedByCurrentUser following: Bool) {
        let attributes = [
            kPAPUserAttributesPhotoCountKey: count,
            kPAPUserAttributesIsFollowedByCurrentUserKey: following
        ]

        setAttributes(attributes as! [String : AnyObject], forUser: user)
    }

    func attributesForUser(user: PFUser) -> [String:AnyObject]? {
        let key = keyForUser(user)
        return cache.objectForKey(key) as? [String:AnyObject]
    }

    func photoCountForUser(user: PFUser) -> Int {
        if let attributes = attributesForUser(user) {
            if let photoCount = attributes[kPAPUserAttributesPhotoCountKey] as? Int {
                return photoCount
            }
        }
        
        return 0
    }

    func followStatusForUser(user: PFUser) -> Bool {
        if let attributes = attributesForUser(user) {
            if let followStatus = attributes[kPAPUserAttributesIsFollowedByCurrentUserKey] as? Bool {
                return followStatus
            }
        }

        return false
    }

    func setPhotoCount(count: Int,  user: PFUser) {
        if var attributes = attributesForUser(user) {
            attributes[kPAPUserAttributesPhotoCountKey] = count
            setAttributes(attributes, forUser: user)
        }
    }

    func setFollowStatus(following: Bool, user: PFUser) {
        if var attributes = attributesForUser(user) {
            attributes[kPAPUserAttributesIsFollowedByCurrentUserKey] = following
            setAttributes(attributes, forUser: user)
        }
    }

    func setFacebookFriends(friends: NSArray) {
        let key: String = kPAPUserDefaultsCacheFacebookFriendsKey
        self.cache.setObject(friends, forKey: key)
        NSUserDefaults.standardUserDefaults().setObject(friends, forKey: key)
        NSUserDefaults.standardUserDefaults().synchronize()
    }

    func facebookFriends() -> [PFUser] {
        let key = kPAPUserDefaultsCacheFacebookFriendsKey
        if cache.objectForKey(key) != nil {
            return cache.objectForKey(key) as! [PFUser]
        }
        
        let friends = NSUserDefaults.standardUserDefaults().objectForKey(key)
        if friends != nil {
            cache.setObject(friends!, forKey: key)
            return friends as! [PFUser]
        }
        return [PFUser]()
    }

    // MARK:- ()

    func setAttributes(attributes: [String:AnyObject], forPhoto photo: PFObject) {
        let key: String = self.keyForPhoto(photo)
        cache.setObject(attributes, forKey: key)
    }

    func setAttributes(attributes: [String:AnyObject], forUser user: PFUser) {
        let key: String = self.keyForUser(user)
        cache.setObject(attributes, forKey: key)
    }

    func keyForPhoto(photo: PFObject) -> String {
        return "photo_\(photo.objectId)"
    }

    func keyForUser(user: PFUser) -> String {
        return "user_\(user.objectId)"
    }
}
