package net.same2u.phonegap.plugin;

import org.json.JSONArray;

import android.content.Context;
import android.view.inputmethod.InputMethodManager;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;

public class SoftKeyboard extends CordovaPlugin {

    public SoftKeyboard() {
    }

    public void showKeyboard() {
        InputMethodManager mgr = (InputMethodManager) cordova.getActivity().getSystemService(Context.INPUT_METHOD_SERVICE);
        mgr.showSoftInput(webView.getView(), InputMethodManager.SHOW_IMPLICIT);
    }

    public void hideKeyboard() {
        InputMethodManager mgr = (InputMethodManager) cordova.getActivity().getSystemService(Context.INPUT_METHOD_SERVICE);
        mgr.hideSoftInputFromWindow(webView.getView().getWindowToken(), 0);
    }

    public boolean isKeyboardShowing() {

      int heightDiff = webView.getView().getRootView().getHeight() - webView.getView().getHeight();
      return (100 < heightDiff); // if more than 100 pixels, its probably a keyboard...
    }

    @Override
  public boolean execute(String action, JSONArray args, CallbackContext callbackContext) {
    if (action.equals("show")) {
            this.showKeyboard();
            callbackContext.success("done");
            return true;
    }
        else if (action.equals("hide")) {
            this.hideKeyboard();
            callbackContext.success();
            return true;
        }
        else if (action.equals("isShowing")) {
            callbackContext.success(Boolean.toString(this.isKeyboardShowing()));
            return true;
        }
    else {
      return false;
    }
  }
}