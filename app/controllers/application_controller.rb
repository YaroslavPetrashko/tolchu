class ApplicationController < ActionController::Base
  include Authentication
  # Import maps need Safari 16.4+, Chrome/Firefox 108+ (and the layout uses dvh units). Rails' :modern preset
  # (Safari 17.2+, Chrome 120+) turned away iPhones still on iOS 16–17. Unlisted browsers are allowed, and
  # every page still works without JavaScript.
  allow_browser versions: { safari: 16.4, chrome: 108, firefox: 108, opera: 94, ie: false }

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Public pages still need to know who is signed in (balance in the nav, existing bets, etc.).
  before_action :resume_session
end
