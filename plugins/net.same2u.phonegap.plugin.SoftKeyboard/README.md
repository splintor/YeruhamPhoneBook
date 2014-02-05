## PhoneGap plugin (Android-only) for showing/hiding the soft (on-screen) keyboard

CAVEAT: Experimental - use at your own risk.

This [PhoneGap](http://phonegap.com/) plugin overcomes the (by-design) restriction that you cannot cause the on-screen keyboard to appear in WebViews simply by calling `.focus()` on an input element (except in limited circumstances).

The plugin is Android-only, because on iOS 6+ you can configure UIWebViews to lift this restriction programmatically. In the context of _AppGyver Steroids_ projects, you simply set `KeyboardDisplayRequiresUserAction` in `www/config.ios.xml` to `false`.

This read-me discusses use of the plugin via [AppGyver Steroids](http://www.appgyver.com/steroids).  
I have not tried to use it with PhoneGap directly.

### Prerequisites:

* You must have an [_AppGyver_ account](https://accounts.appgyver.com/users/sign_up) and your [_AppGyver Steroids_](http://www.appgyver.com/steroids)-based app project must be deployed to and configured in [AppGyver's Cloud Services](https://cloud.appgyver.com/applications/)
* Designed to work with Steroids version `2.7`, which is built on top of PhoneGap version `2.7.0`.

### Setup

#### Cloud-side:

In your app's Android build settings (<https://cloud.appgyver.com/applications/>_appId_), fill in the `Plugins` field; e.g. (the example assumes that this plugin is the only one to use):

    [
      { "source":"https://github.com/mklement0/phonegap-plugin-softkeyboard-android.git" }
    ]

This will cause this repo to be incorporated into your app's cloud compilation process, including compilation of the `.java` assets.

Note: For debugging, you can either create an ad-hoc build of your app or have a custom version of the _Scanner_ app built that includes the plugin.

#### App-project-side:

**Note**: These steps are current as of AppGyver Cloud Service version `2.7.3`.

##### Include the JavaScript wrapper:

Place a copy of `www/softkeyboard.js` from this repo in your app project's `www` subfolder (e.g., in `www/javascripts/plugins` and reference it in your HTML files as needed; e.g.

    <script src="javascripts/plugins/softkeyboard.js"></script>

This wrapper will expose the plugin's functionality as `[window.]plugins.softkeyboard`

##### Reference the plugin in your Android configuration:

Add the following element as a child element to the `cordova/plugins` element of your project's `www/config.android.xml` file:

    <plugin name="SoftKeyboardPlugin" value="net.same2u.phonegap.plugin.SoftKeyboard" onload="true"/>

### Usage

    if (device.platform === 'Android') {  // Be sure to only call on Android devices.
      plugins.softKeyboard.show(function () {
          // success
      },function (errDescr) {
         // fail
      });
    }


### Acknowledgements

Gratefully adapted from <https://github.com/phonegap/phonegap-plugins/tree/master/Android/SoftKeyboard>.  
The heart of the plugin is the same, but it has been restructured to conform to [PhoneGap's](http://phonegap.com/) new plugin architecture, and the namespace has been changed.

### License

Copyright (c) 2013 Michael Klement, released under the [MIT license](http://opensource.org/licenses/MIT)
