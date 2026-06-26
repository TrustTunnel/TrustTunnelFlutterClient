/// iOS activity identifiers that can be excluded from the share sheet.
enum ShareTarget {
  airDrop('com.apple.UIKit.activity.AirDrop'),
  addToReadingList('com.apple.UIKit.activity.AddToReadingList'),
  assignToContact('com.apple.UIKit.activity.AssignToContact'),
  copyToPasteboard('com.apple.UIKit.activity.CopyToPasteboard'),
  mail('com.apple.UIKit.activity.Mail'),
  markupAsPdf('com.apple.UIKit.activity.MarkupAsPDF'),
  message('com.apple.UIKit.activity.Message'),
  openInIBooks('com.apple.UIKit.activity.OpenInIBooks'),
  postToFacebook('com.apple.UIKit.activity.PostToFacebook'),
  postToFlickr('com.apple.UIKit.activity.PostToFlickr'),
  postToTencentWeibo('com.apple.UIKit.activity.PostToTencentWeibo'),
  postToTwitter('com.apple.UIKit.activity.PostToTwitter'),
  postToVimeo('com.apple.UIKit.activity.PostToVimeo'),
  postToWeibo('com.apple.UIKit.activity.PostToWeibo'),
  print('com.apple.UIKit.activity.Print'),
  saveToCameraRoll('com.apple.UIKit.activity.SaveToCameraRoll')
  ;

  const ShareTarget(this.platformIdentifier);

  final String platformIdentifier;
}
