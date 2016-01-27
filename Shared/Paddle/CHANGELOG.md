# 2.3.7
Bugfixes:
- Fixed issue where trial windows sometimes do not dismiss correctly
- Fixed paypal loading issue in PSK

# 2.3.6
Bugfixes:
- JSON Parsing, nil data, issue resolved
- Window centering
- Import Cocoa in header for Swift support

# 2.3.5
Bugfixes:
- UI fixes for OS X 10.11
- Centering licencing windows
- Fix for lost licences

# 2.3.4
Bugfixes:
- Fixed issue for < 3 character analytics event names
- Ensure analytics data is always sent over https
- Fixed issues regarding licences not being stored correctly

# 2.3.2
Features:
- Scheduler includes analytics events scheduling: next event.name
- Inclusion of default license
- Started moving to new v3 API

Bugfixes:
- Licence changed to License
- Fix 'week' schedules

# 2.3.1
Bugfixes:
- Layout and shadow issues in PTK

# 2.3.0
Features:
- PaddleToolKit
	- Happiness
	- Rating
	- Feedback
	- Email Subscribe
	- Scheduler

## 2.2.6
Bugfixes:
- Deactivate issue when for older licenses fixed

Features:
- PSK Purchase view responds to Esc key for closing
- Delegate method willShowBuyWindow for overriding purchasing behaviour

## 2.2.5
Features:
- startPurchase method for launching straight into the buy view for the product
- disableLicenseMigration method to prevent old licenses from < 2.2.x SDK from being transferred
- disableTrialResetOnDeactivate method to NOT reset trial periods when an activation is deactivated

Bugfixes:
- Analytics data is NOT sent when an app is run from Xcode/debugger for more accurate data

## 2.2.4
Features:
- Ability to override product price

## 2.2.3
Features:
- Debugging of time trials
- Resetting time trials for app version updates

## 2.2.2
Bugfixes:
- Improved validation of analytics data
- Preventing too many attempted connections to analytics
- Improving timeout errors on license activation

## 2.2.1
Bugfixes:
- Improved migration script from < 2.2 versions
- NSNotificationCenter notifications fix
- Friendly license activation message
- Continuing Time Trial button text changed from 'Quit' to 'Close'

## 2.2
Features:
- Paddle Analytics Kit
- License and product data storage moved to custom storage
- Trial data more secure
- User email included in purchase receipts
- Allows for feature limited trials after time trial completion
- Custom product view headings
- Allows for custom activation alerts

## 2.18
Features:
- UI updated for Yosemite
- Licensing windows are now draggable when not displayed as a sheet
- Grammar correction number of days remaining label

## 2.16
Bugfixes:
- Last activated date updated on successful verification

## 2.15
Bugfixes:
- Supports Retina displays on Purchase view
- Fixed Yosemite shadow bug
- Purchase view now draggable

## 2.13
Bugfixes:
- SSL/Verify delegate method fix. Some products were able to verify but delegate methods not being called

## 2.12
Bugfixes:
- Fixed modal web view when being used with JDK based apps
- PSKReceipt delegate issue on some implementations

## 2.11
Bugfixes:
- Truncated pricing in certain localizations
- Conflicting class names with other popular OS classes

Features:
- App descriptions displayed and sized appropriately

## 2.1
Bugfixes:
- Paypal payment window
- Fixed 'test  product' text issue
- Encryption issues

## 2.02
Bugfixes:
- Product icon display issue
- Preparation for local verification

## 2.01
Features:
- Added `showStoreViewForProductIds:(NSArray *)productIds` to PSK
- Added `startLicensing:(NSDictionary *)productInfo timeTrial:(BOOL)timeTrial withWindow:(NSWindow *)mainWindow` to Paddle. For starting licensing after settings keys
- Added `paddleDidFailWithError:(NSError *)error` delegate method to Paddle.h

Bugfixes:
- Error handling of no API keys set when initiating

## 2.0
Features:
- PaddleStoreKit (PSK) added to allow for In App Purchases
- Display a 'store' for your products, an individual product or open a 'purchase' view instantly
- Purchase verification for receipts
- Valid receipts stored locally and can be re-verified at any time

## 1.6
Features:
- Store activation_id on successful license activation for future verification

## 1.54
Bugfixes:
- Fix for product_image null value

## 1.53
Features:
- Added option to disable display of licensing view (willShowLicensingWindow)

Bugfixes:
- Improved de-activate licence cleanup
- Miscellaneous visual/UI fixes
- Improved unit tests
- Updated copyright information for 2014

## 1.52
Bugfixes:
- Licence changed to License in remaining locations
- Strip whitespace and new line characters when pasting email/license
- Added ActivityIndicator while checking license validity
- Improved security when quitting app with expired trial and no license (see docs for options)

## 1.51
Bugfixes:
- Changed Licence to License
- Internal reporting of device info to API fix

## 1.5
Bugfixes:
- Timeout increased to 30 seconds
- Licence activation, only one at a time, activation confirmation message

Features:
- Deactivate method included
- Device info for API to improve activations and debugging

## 1.43
Bugfixes:
- NSAlert from errors generated by Paddle rather than NSLog for ALL errors

## 1.42
Bugfixes:
- Switched from NSAlert to NSLog for errors
- First fix for bug when switching between trial and no trial on the API. Now requires an app restart from the user for changes to take effect (providing the app/framework was started once after the changes where made)

## 1.41
Bugfixes
- Fixed bug in which NSTextFields would not respond to key events in some implementations

## 1.4

Bugfixes:
- Fixed bug in which the framework would not always display discounts correctly
