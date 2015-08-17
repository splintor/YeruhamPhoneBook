'use strict';

(function () {
    var logInfo = function(s) { console.log(s); };
    var logError = function (s) {
        console.error(s);
        //alert(s);
    };

    var pageTable = {
        getAllPages: function() { return currentData.pages; },
        getPage: function(name) {
            try {
                for (var i = 0; i < currentData.pages.length; ++i) {
                    var p = currentData.pages[i];
                    if (p.name === name) {
                        return p;
                    }
                }
            } catch (exception) {
                console.log("An exception has occurred in getPage: " + exception);
            }
            return null;
        },
        validateNumber: function (number) {
            if (!number) {
                this.validationNumber = getValidationNumber();
                logInfo("validationNumber set to: " + this.validationNumber);
                number = this.validationNumber;
            }

            if (!number) {
                logInfo("Empty validation number");
                return false;
            }

            if (!number.replace) {
                number = number.toString();
            }

            number = number.replace(/[\D]/g, '');

            if (number.length < 8) {
                logInfo("Validation number is too short:" + number);
                return false;
            }

            for (var i = 0; i < currentData.pages.length; ++i) {
                var p = currentData.pages[i];
                if (p.text.replace(/[-\.]/g, '').indexOf(number) >= 0) {
                    saveValidationNumber(number);
                    return true;
                }
            }
            return false;
        },
        clearValidationNumber: function() {
            saveValidationNumber('');
        },
        getAboutPage: function() {
            var current = this.getPage('about-page');
            if(!current) {
                var text = 'נכתב ע"י שמוליק פלינט (splintor@gmail.com). \n' +
                    'גרסה 2.1.1.\n' +
                    'דפים: ' + currentData.pages.length;
                if (currentData.updatedPages && currentData.updatedPages.length) {
                    text += ' (מתוכם ' + currentData.updatedPages.length + ' חדשים)';
                }
                text += '.\n';
                var mails = 0;
                var phones = 0;
                currentData.pages.forEach(function(page) {
                    //Change email addresses to mailto: links.
                    var foundMails = page.text.match(/(([a-zA-Z0-9\-_\.])+@[a-zA-Z_]+?(\.[a-zA-Z]{2,6})+)/gim);
                    if (foundMails) {
                        mails += foundMails.length;
                    }

                    var foundPhones = page.text.match(/(\b[0-9][0-9\-_\.]{5,11}\b)/gim);
                    if (foundPhones) {
                        phones += foundPhones.length;
                    }
                });
                text += "מספרי טלפון: " + phones + ".\n";
                text += "כתובות מייל: " + mails + ".\n";
                current = {
                    name: 'about-page',
                    title: "אפליקצית ספר הטלפונים של ירוחם",
                    text: text,
                    html: text.replace(/\n/g, '<br>'),
                    dummyPage: true,
                };
                currentData.pages.push(current);
            }
            return current;
        },
        getValidationPage: function() {
            var current = this.getPage('validation-page');
            if(!current) {
                var text = 'המספר שמשמש לזיהוי הוא:\n' +
                    '<strong>' + this.validationNumber + '</strong>';
                current = {
                    name: 'validation-page',
                    title: "אפליקצית ספר הטלפונים של ירוחם",
                    text: text,
                    html: text.replace(/\n/g, '<br>'),
                    dummyPage: true,
                };
                currentData.pages.push(current);
            }
            return current;
        },
        getValidationResetPage: function() {
            var current = this.getPage('validation-reset-page');
            if(!current) {
                var text = 'המספר שמשמש לזיהוי אופס.\n';
                current = {
                    name: 'validation-reset-page',
                    title: "אפליקצית ספר הטלפונים של ירוחם",
                    text: text,
                    html: text.replace(/\n/g, '<br>'),
                    dummyPage: true,
                };
                currentData.pages.push(current);
            }
            return current;
        },

    onPagesUpdate: null,
    };

    function raiseOnPagesUpdate(updatedPagesCount, updatedPages) {
        try {
            currentData.updatedPages = updatedPages || [];
            if (pageTable.onPagesUpdate) pageTable.onPagesUpdate(updatedPagesCount, updatedPages);
        } catch (exception) {
            console.log("An exception has occured in raiseOnPagesUpdate: " + exception);
        }
    }
    function onDatabaseTransactionError(tx, error) {
        logError("Database Error: " + error + ' at ' + tx);
    }
    function saveLastUpdateDate(lastUpdateDate) {
        logInfo("Setting lastUpdateDate to " + lastUpdateDate + " which is " + new Date(Number(lastUpdateDate)));
        window.localStorage.setItem("lastUpdateDate", lastUpdateDate);
    }

    function getLastUpdateDate() {
        return window.localStorage.getItem("lastUpdateDate");
    }

    window.saveValidationNumber = function (validationNumber) {
        logInfo("Setting validation number to " + validationNumber);
        window.localStorage.setItem("validationNumber", validationNumber);
    };

    window.getValidationNumber = function () { return window.localStorage.getItem("validationNumber"); };

    function addPageToDatabase(tx, page) {
        tx.executeSql("INSERT INTO pages (name,title,text,html,url) VALUES (?,?,?,?,?)", [page.name, page.title, page.text, page.html, page.url]);
    }
    // initialize database from currentData
    function initializeDatabase(database, callback) {
        logInfo("initializeDatabase");
        database.transaction(function (tx) {
            tx.executeSql('DROP TABLE IF EXISTS pages');
            tx.executeSql("CREATE TABLE IF NOT EXISTS pages (" +
                "name TEXT, " +
                "title TEXT, " +
                "text TEXT, " +
                "html TEXT, " +
                "url TEXT)");

            currentData.pages.forEach(function (page) { addPageToDatabase(tx, page); });
            saveLastUpdateDate(currentData.maxDate);
        }, onDatabaseTransactionError, callback);
    }
    // load currentData from database
    var loadDatabase = function (database, callback) {
        database.transaction(function (tx) {
            tx.executeSql("Select * from pages", [], function(tx1, results) {
                var pages = [];
                logInfo("reloading database. Rows count: " + results.rows.length);
                for (var i = 0; i < results.rows.length; i++) {
                    var row = results.rows.item(i);
                    pages.push({
                        name: row.name,
                        title: row.title,
                        text: row.text,
                        html: row.html,
                        url: row.url
                    });
                }
                currentData.pages = pages;
                logInfo("currentData.pages.length: " + currentData.pages.length);
                raiseOnPagesUpdate(null); // force list refresh
            });
        }, onDatabaseTransactionError, callback);
    };

    function processDatabaseStartup() {
        try {
            var deferred = window.deferService.defer();
            logInfo("In processDatabaseStartup");
            var database = window.openDatabase("YeruhamPhoneBookDB", "1.0", "Yeruham Phonebook Database", 500000);
            var autoUpdateCallback = function() { tryToUpdateDatabase(database, false); };
            if (getLastUpdateDate()) {
                loadDatabase(database, autoUpdateCallback);
            } else {
                initializeDatabase(database, autoUpdateCallback);
            }

            pageTable.forceUpdate = function() { tryToUpdateDatabase(database, true); };

            return deferred.promise;
        } catch (exception) {
            logError("An exception has occurred in processDatabaseStartup: " + exception);
            return null;
        }
    }
    function onDeviceReady() {
        if (!window.deferService || !window.httpService) {
            window.deviceReady = true; // call us again when services are initialized.
            return;
        }

        processDatabaseStartup();
    }

    // ReSharper disable once Html.EventNotResolved
    document.addEventListener("deviceready", onDeviceReady, false);

    function tryToUpdateDatabase(database, forceUpdate) {
        try {
            var connectionType = navigator.network ? navigator.network.connection.type : undefined;
            logInfo("connection type is " + connectionType);
// ReSharper disable UseOfImplicitGlobalInFunctionScope
            if (!forceUpdate && connectionType != Connection.WIFI && connectionType != Connection.ETHERNET) {
// ReSharper restore UseOfImplicitGlobalInFunctionScope
                logInfo("Auto-update only occurs on fast connections (wi-fi or ethernet).");
                raiseOnPagesUpdate(null); // Make sure the list is refreshed after the database was loaded.
                return;
            }

            var updateURL = "https://script.google.com/macros/s/AKfycbwk3WW_pyJyJugmrj5ZN61382UabkclrJNxXzEsTDKrkD_vtEc/exec?UpdatedAfter=";
            var url = updateURL + new Date(Number(getLastUpdateDate())).toISOString();
            raiseOnPagesUpdate(-1); // loading...
            logInfo("getting updates from " + url);
            window.httpService.get(url).success(function(data) {
                try {
                    logInfo("Updated page count: " + data.pages.length);
                    database.transaction(function(tx) {
                        try {
                            data.pages.forEach(function(page) {
                                tx.executeSql("DELETE FROM pages WHERE url=?", [page.url]);
                                if (!page.isDeleted) addPageToDatabase(tx, page);
                            });
                            loadDatabase(database);
                            saveLastUpdateDate(data.maxDate);
                            var updatedPagesCount = data.pages.length;
                            if (forceUpdate && updatedPagesCount == 0) updatedPagesCount = -2; // mark as not found
                            raiseOnPagesUpdate(updatedPagesCount, data.pages);
                        } catch (updateEx) {
                            logError("Failed to update data. error: " + updateEx);
                            raiseOnPagesUpdate(0); // clear "loading..." message
                        }
                    });
                } catch (e) {
                    logError("Failed to update database: " + e);
                    raiseOnPagesUpdate(0); // clear "loading..." message
                }
            }).error(function(data, status) {
                logError("http get failed.\nstatus: " + data + ",\nstatus: " + status);
                raiseOnPagesUpdate(0); // clear "loading..." message
            });
        } catch (ex) {
            logError("Failed to call http get. error: " + ex);
            raiseOnPagesUpdate(0); // clear "loading..." message
        }
    }
    angular.module('myApp.dataServices', [])
        .factory('PageTable', [
            '$q', '$http', function($q, $http) {
                try {
                    window.httpService = $http;
                    window.deferService = $q;

                    if (window.deviceReady) onDeviceReady();

                    return pageTable;
                } catch (exception) {
                    console.log("An exception has occured in PageDetailCtrl: " + exception);
                    return null;
                }
            }
        ]);
}());