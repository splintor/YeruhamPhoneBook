(function( cordova ) {

    function SoftKeyboard() {}

    SoftKeyboard.prototype.show = function(win, fail) {
        return cordova.exec(
                function (args) { if(win !== undefined) { win(args); } },
                function (args) { if(fail !== undefined) { fail(args); } },
                "SoftKeyboardPlugin", "show", []);
    };

    SoftKeyboard.prototype.hide = function(win, fail) {
        return cordova.exec(
                function (args) { if(win !== undefined) { win(args); } },
                function (args) { if(fail !== undefined) { fail(args); } },
                "SoftKeyboardPlugin", "hide", []);
    };

    SoftKeyboard.prototype.isShowing = function(win, fail) {
        return cordova.exec(
                function (args) { if(win !== undefined) { win(args); } },
                function (args) { if(fail !== undefined) { fail(args); } },
                "SoftKeyboardPlugin", "isShowing", []);
    };

    if(!window.plugins) {
        window.plugins = {};
    }

    if (!window.plugins.softKeyboard) {
        window.plugins.softKeyboard = new SoftKeyboard();
    }

})( window.cordova );