import Foundation
import CoreGraphics
import UIImage_AF_Additions
import ParseFacebookUtils

class PAPUtility {

    // MARK:- PAPUtility
    
    // MARK Like Photos

    class func likePhotoInBackground(photo: PFObject, block completionBlock: ((succeeded: Bool, error: NSError?) -> Void)?) {
        let queryExistingLikes = PFQuery(className: kPAPActivityClassKey)
        queryExistingLikes.whereKey(kPAPActivityPhotoKey, equalTo: photo)
        queryExistingLikes.whereKey(kPAPActivityTypeKey, equalTo: kPAPActivityTypeLike)
        queryExistingLikes.whereKey(kPAPActivityFromUserKey, equalTo: PFUser.currentUser()!)
        queryExistingLikes.cachePolicy = PFCachePolicy.NetworkOnly
        queryExistingLikes.findObjectsInBackgroundWithBlock { (activities, error) in
            if error == nil {
                for activity in activities as! [PFObject] {
// FIXME: To be removed! this is synchronous!                    activity.delete()
                    activity.deleteInBackground()
                }
            }
            
            // proceed to creating new like
            let likeActivity = PFObject(className: kPAPActivityClassKey)
            likeActivity.setObject(kPAPActivityTypeLike, forKey: kPAPActivityTypeKey)
            likeActivity.setObject(PFUser.currentUser()!, forKey: kPAPActivityFromUserKey)
            likeActivity.setObject(photo.objectForKey(kPAPPhotoUserKey)!, forKey: kPAPActivityToUserKey)
            likeActivity.setObject(photo, forKey: kPAPActivityPhotoKey)
            
            let likeACL = PFACL(user: PFUser.currentUser()!)
            likeACL.setPublicReadAccess(true)
            likeACL.setWriteAccess(true, forUser: photo.objectForKey(kPAPPhotoUserKey) as! PFUser)
            likeActivity.ACL = likeACL

            likeActivity.saveInBackgroundWithBlock { (succeeded, error) in
                if completionBlock != nil {
                    completionBlock!(succeeded: succeeded.boolValue, error: error)
                }

                // refresh cache
                let query = PAPUtility.queryForActivitiesOnPhoto(photo, cachePolicy: PFCachePolicy.NetworkOnly)
                query.findObjectsInBackgroundWithBlock { (objects, error) in
                    if error == nil {
                        var likers = [PFUser]()
                        var commenters = [PFUser]()
                        
                        var isLikedByCurrentUser = false
                        
                        for activity in objects as! [PFObject] {
                            if (activity.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeLike && activity.objectForKey(kPAPActivityFromUserKey) != nil {
                                likers.append(activity.objectForKey(kPAPActivityFromUserKey) as! PFUser)
                            } else if (activity.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeComment && activity.objectForKey(kPAPActivityFromUserKey) != nil {
                                commenters.append(activity.objectForKey(kPAPActivityFromUserKey) as! PFUser)
                            }
                            
                            if (activity.objectForKey(kPAPActivityFromUserKey) as? PFUser)?.objectId == PFUser.currentUser()!.objectId {
                                if (activity.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeLike {
                                    isLikedByCurrentUser = true
                                }
                            }
                        }
                        
                        PAPCache.sharedCache.setAttributesForPhoto(photo, likers: likers, commenters: commenters, likedByCurrentUser: isLikedByCurrentUser)
                    }

                    NSNotificationCenter.defaultCenter().postNotificationName(PAPUtilityUserLikedUnlikedPhotoCallbackFinishedNotification, object: photo, userInfo: [PAPPhotoDetailsViewControllerUserLikedUnlikedPhotoNotificationUserInfoLikedKey: succeeded.boolValue])
                }

            }
        }
    }

    class func unlikePhotoInBackground(photo: PFObject, block completionBlock: ((succeeded: Bool, error: NSError?) -> Void)?) {
        let queryExistingLikes = PFQuery(className: kPAPActivityClassKey)
        queryExistingLikes.whereKey(kPAPActivityPhotoKey, equalTo: photo)
        queryExistingLikes.whereKey(kPAPActivityTypeKey, equalTo: kPAPActivityTypeLike)
        queryExistingLikes.whereKey(kPAPActivityFromUserKey, equalTo: PFUser.currentUser()!)
        queryExistingLikes.cachePolicy = PFCachePolicy.NetworkOnly
        queryExistingLikes.findObjectsInBackgroundWithBlock { (activities, error) in
            if error == nil {
                for activity in activities as! [PFObject] {
// FIXME: To be removed! this is synchronous!                    activity.delete()
                    activity.deleteInBackground()
                }
                
                if completionBlock != nil {
                    completionBlock!(succeeded: true, error: nil)
                }

                // refresh cache
                let query = PAPUtility.queryForActivitiesOnPhoto(photo, cachePolicy: PFCachePolicy.NetworkOnly)
                query.findObjectsInBackgroundWithBlock { (objects, error) in
                    if error == nil {
                        
                        var likers = [PFUser]()
                        var commenters = [PFUser]()
                        
                        var isLikedByCurrentUser = false
                        
                        for activity in objects as! [PFObject] {
                            if (activity.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeLike {
                                likers.append(activity.objectForKey(kPAPActivityFromUserKey) as! PFUser)
                            } else if (activity.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeComment {
                                commenters.append(activity.objectForKey(kPAPActivityFromUserKey) as! PFUser)
                            }
                            
                            if (activity.objectForKey(kPAPActivityFromUserKey) as! PFUser).objectId == PFUser.currentUser()!.objectId {
                                if (activity.objectForKey(kPAPActivityTypeKey) as! String) == kPAPActivityTypeLike {
                                    isLikedByCurrentUser = true
                                }
                            }
                        }
                        
                        PAPCache.sharedCache.setAttributesForPhoto(photo, likers: likers, commenters: commenters, likedByCurrentUser: isLikedByCurrentUser)
                    }
                    
                    NSNotificationCenter.defaultCenter().postNotificationName(PAPUtilityUserLikedUnlikedPhotoCallbackFinishedNotification, object: photo, userInfo: [PAPPhotoDetailsViewControllerUserLikedUnlikedPhotoNotificationUserInfoLikedKey: false])
                }

            } else {
                if completionBlock != nil {
                    completionBlock!(succeeded: false, error: error)
                }
            }
        }
    }

    // MARK Facebook

    class func processFacebookProfilePictureData(newProfilePictureData: NSData) {
        print("Processing profile picture of size: \(newProfilePictureData.length)")
        if newProfilePictureData.length == 0 {
            return
        }
        
        let image = UIImage(data: newProfilePictureData)
        
        let mediumImage: UIImage = image!.thumbnailImage(280, transparentBorder: 0, cornerRadius: 0, interpolationQuality: CGInterpolationQuality.High)
        let smallRoundedImage: UIImage = image!.thumbnailImage(64, transparentBorder: 0, cornerRadius: 0, interpolationQuality: CGInterpolationQuality.Low)

        let mediumImageData: NSData = UIImageJPEGRepresentation(mediumImage, 0.5)! // using JPEG for larger pictures
        let smallRoundedImageData: NSData = UIImagePNGRepresentation(smallRoundedImage)!

        if mediumImageData.length > 0 {
            let fileMediumImage: PFFile = PFFile(data: mediumImageData)
            fileMediumImage.saveInBackgroundWithBlock { (succeeded, error) in
                if error == nil {
                    PFUser.currentUser()!.setObject(fileMediumImage, forKey: kPAPUserProfilePicMediumKey)
                    PFUser.currentUser()!.saveInBackground()
                }
            }
        }
        
        if smallRoundedImageData.length > 0 {
            let fileSmallRoundedImage: PFFile = PFFile(data: smallRoundedImageData)
            fileSmallRoundedImage.saveInBackgroundWithBlock { (succeeded, error) in
                if error == nil {
                    PFUser.currentUser()!.setObject(fileSmallRoundedImage, forKey: kPAPUserProfilePicSmallKey)
                    PFUser.currentUser()!.saveInBackground()
                }
            }
        }
        print("Processed profile picture")
    }

    class func userHasValidFacebookData(user: PFUser) -> Bool {
        // Check that PFUser has valid fbid that matches current FBSessions userId
        let facebookId = user.objectForKey(kPAPUserFacebookIDKey) as? String
        return (facebookId != nil && facebookId!.length > 0 && facebookId == PFFacebookUtils.session()!.accessTokenData.userID)
    }
   
    class func userHasProfilePictures(user: PFUser) -> Bool {
        let profilePictureMedium: PFFile? = user.objectForKey(kPAPUserProfilePicMediumKey) as? PFFile
        let profilePictureSmall: PFFile? = user.objectForKey(kPAPUserProfilePicSmallKey) as? PFFile
        
        return profilePictureMedium != nil && profilePictureSmall != nil
    }

    class func defaultProfilePicture() -> UIImage? {
        return UIImage(named: "AvatarPlaceholderBig.png")
    }
    
    // MARK Display Name

    class func firstNameForDisplayName(displayName: String?) -> String {
        if (displayName == nil || displayName!.length == 0) {
            return "Someone"
        }
        
        let displayNameComponents: [String] = displayName!.componentsSeparatedByString(" ")
        var firstName = displayNameComponents[0]
        if firstName.length > 100 {
            // truncate to 100 so that it fits in a Push payload
            firstName = firstName.subString(0, length: 100)
        }
        return firstName
    }

    // MARK User Following

    class func followUserInBackground(user: PFUser, block completionBlock: ((succeeded: Bool, error: NSError?) -> Void)?) {
        if user.objectId == PFUser.currentUser()!.objectId {
            return
        }
        
        let followActivity = PFObject(className: kPAPActivityClassKey)
        followActivity.setObject(PFUser.currentUser()!, forKey: kPAPActivityFromUserKey)
        followActivity.setObject(user, forKey: kPAPActivityToUserKey)
        followActivity.setObject(kPAPActivityTypeFollow, forKey: kPAPActivityTypeKey)
        
        let followACL = PFACL(user: PFUser.currentUser()!)
        followACL.setPublicReadAccess(true)
        followActivity.ACL = followACL
        
        followActivity.saveInBackgroundWithBlock { (succeeded, error) in
            if completionBlock != nil {
                completionBlock!(succeeded: succeeded.boolValue, error: error)
            }
        }
        PAPCache.sharedCache.setFollowStatus(true, user: user)
    }

    class func followUserEventually(user: PFUser, block completionBlock: ((succeeded: Bool, error: NSError?) -> Void)?) {
        if user.objectId == PFUser.currentUser()!.objectId {
            return
        }
        
        let followActivity = PFObject(className: kPAPActivityClassKey)
        followActivity.setObject(PFUser.currentUser()!, forKey: kPAPActivityFromUserKey)
        followActivity.setObject(user, forKey: kPAPActivityToUserKey)
        followActivity.setObject(kPAPActivityTypeFollow, forKey: kPAPActivityTypeKey)
        
        let followACL = PFACL(user: PFUser.currentUser()!)
        followACL.setPublicReadAccess(true)
        followActivity.ACL = followACL
        
        followActivity.saveEventually(completionBlock)
        PAPCache.sharedCache.setFollowStatus(true, user: user)
    }

    class func followUsersEventually(users: [PFUser], block completionBlock: ((succeeded: Bool, error: NSError?) -> Void)?) {
        for user: PFUser in users {
            PAPUtility.followUserEventually(user, block: completionBlock)
            PAPCache.sharedCache.setFollowStatus(true, user: user)
        }
    }

    class func unfollowUserEventually(user: PFUser) {
        let query = PFQuery(className: kPAPActivityClassKey)
        query.whereKey(kPAPActivityFromUserKey, equalTo: PFUser.currentUser()!)
        query.whereKey(kPAPActivityToUserKey, equalTo: user)
        query.whereKey(kPAPActivityTypeKey, equalTo: kPAPActivityTypeFollow)
        query.findObjectsInBackgroundWithBlock { (followActivities, error) in
            // While normally there should only be one follow activity returned, we can't guarantee that.
            if error == nil {
                for followActivity: PFObject in followActivities as! [PFObject] {
                    followActivity.deleteEventually()
                }
            }
        }
        PAPCache.sharedCache.setFollowStatus(false, user: user)
    }

    class func unfollowUsersEventually(users: [PFUser]) {
        let query = PFQuery(className: kPAPActivityClassKey)
        query.whereKey(kPAPActivityFromUserKey, equalTo: PFUser.currentUser()!)
        query.whereKey(kPAPActivityToUserKey, containedIn: users)
        query.whereKey(kPAPActivityTypeKey, equalTo: kPAPActivityTypeFollow)
        query.findObjectsInBackgroundWithBlock { (activities, error) in
            for activity in activities as! [PFObject] {
                activity.deleteEventually()
            }
        }
        for user in users {
            PAPCache.sharedCache.setFollowStatus(false, user: user)
        }
    }
 
    // MARK Activities

    class func queryForActivitiesOnPhoto(photo: PFObject, cachePolicy: PFCachePolicy) -> PFQuery {
        let queryLikes: PFQuery = PFQuery(className: kPAPActivityClassKey)
        queryLikes.whereKey(kPAPActivityPhotoKey, equalTo: photo)
        queryLikes.whereKey(kPAPActivityTypeKey, equalTo: kPAPActivityTypeLike)
        
        let queryComments = PFQuery(className: kPAPActivityClassKey)
        queryComments.whereKey(kPAPActivityPhotoKey, equalTo: photo)
        queryComments.whereKey(kPAPActivityTypeKey, equalTo: kPAPActivityTypeComment)
        
        let query = PFQuery.orQueryWithSubqueries([queryLikes,queryComments])
        query.cachePolicy = cachePolicy
        query.includeKey(kPAPActivityFromUserKey)
        query.includeKey(kPAPActivityPhotoKey)

        return query
    }

    // MARK:- Shadow Rendering

    class func drawSideAndBottomDropShadowForRect(rect: CGRect, inContext context: CGContextRef) {
        // Push the context
        CGContextSaveGState(context)
        
        // Set the clipping path to remove the rect drawn by drawing the shadow
        let boundingRect: CGRect = CGContextGetClipBoundingBox(context)
        CGContextAddRect(context, boundingRect)
        CGContextAddRect(context, rect)
        CGContextEOClip(context)
        // Also clip the top and bottom
        CGContextClipToRect(context, CGRectMake(rect.origin.x - 10.0, rect.origin.y, rect.size.width + 20.0, rect.size.height + 10.0))
        
        // Draw shadow
        UIColor.blackColor().setFill()
        CGContextSetShadow(context, CGSizeMake(0.0, 0.0), 7.0)
        CGContextFillRect(context, CGRectMake(rect.origin.x, rect.origin.y - 5.0, rect.size.width, rect.size.height + 5.0))
        // Save context
        CGContextRestoreGState(context)
    }
    
    class func drawSideAndTopDropShadowForRect(rect: CGRect, inContext context: CGContextRef) {
        // Push the context
        CGContextSaveGState(context)
        
        // Set the clipping path to remove the rect drawn by drawing the shadow
        let boundingRect: CGRect = CGContextGetClipBoundingBox(context)
        CGContextAddRect(context, boundingRect)
        CGContextAddRect(context, rect)
        CGContextEOClip(context)
        // Also clip the top and bottom
        CGContextClipToRect(context, CGRectMake(rect.origin.x - 10.0, rect.origin.y - 10.0, rect.size.width + 20.0, rect.size.height + 10.0))
        
        // Draw shadow
        UIColor.blackColor().setFill()
        CGContextSetShadow(context, CGSizeMake(0.0, 0.0), 7.0)
        CGContextFillRect(context, CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height + 10.0))
        // Save context
        CGContextRestoreGState(context)
    }

    class func drawSideDropShadowForRect(rect: CGRect, inContext context: CGContextRef) {
        // Push the context 
        CGContextSaveGState(context)
        
        // Set the clipping path to remove the rect drawn by drawing the shadow
        let boundingRect: CGRect = CGContextGetClipBoundingBox(context)
        CGContextAddRect(context, boundingRect)
        CGContextAddRect(context, rect)
        CGContextEOClip(context)
        // Also clip the top and bottom
        CGContextClipToRect(context, CGRectMake(rect.origin.x - 10.0, rect.origin.y, rect.size.width + 20.0, rect.size.height))
        
        // Draw shadow
        UIColor.blackColor().setFill()
        CGContextSetShadow(context, CGSizeMake(0.0, 0.0), 7.0)
        CGContextFillRect(context, CGRectMake(rect.origin.x, rect.origin.y - 5.0, rect.size.width, rect.size.height + 10.0))
        // Save context
        CGContextRestoreGState(context)
    }
}
