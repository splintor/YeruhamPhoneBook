'use strict';

(function () {
    var logInfo = function(s) { console.log(s); }
    var logError = function (s) {
        console.error(s);
        //alert(s);
    }

    var pageTable = {
        getAllPages: function() { return currentData.pages; },
        getPage: function(name) {
            for (var i = 0; i < currentData.pages.length; ++i) {
                var p = currentData.pages[i];
                if (p.name === name) {
                    return p;
                }
            }
            return null;
        },
        onPagesUpdate: null,
    }

    var raiseOnPagesUpdate = function(updatedPagesCount) {
        if (pageTable.onPagesUpdate) pageTable.onPagesUpdate(updatedPagesCount);
    }

    var onDatabaseTransactionError = function (tx, error) {
        logError("Database Error: " + error);
    }

    var saveLastUpdateDate = function (lastUpdateDate) {
        logInfo("Setting lastUpdateDate to " + lastUpdateDate + " which is " + new Date(Number(lastUpdateDate)));
        window.localStorage.setItem("lastUpdateDate", lastUpdateDate);
    }

    var getLastUpdateDate = function () { return window.localStorage.getItem("lastUpdateDate"); }

    var addPageToDatabase = function(tx, page) {
        tx.executeSql("INSERT INTO pages (name,title,text,html,url) VALUES (?,?,?,?,?)", [page.name, page.title, page.text, page.html, page.url]);
    }

    // initialize database from currentData
    var initializeDatabase = function (database, callback) {
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
    };

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

    window.processDatabaseStartup = function() {
        var deferred = window.deferService.defer();
        logInfo("In processDatabaseStartup");
        var database = window.openDatabase("YeruhamPhoneBookDB", "1.0", "Yeruham Phonebook Database", 500000);
        var autoUpdateCallback = function() { tryToUpdateDatabase(database, false); };
        if (getLastUpdateDate()) {
            loadDatabase(database, autoUpdateCallback);
        } else {
            initializeDatabase(database, autoUpdateCallback);
        }

        pageTable.forceUpdate = function () { tryToUpdateDatabase(database, true); };

        return deferred.promise;
    }

    var onDeviceReady = function () {
        if (!window.deferService || !window.httpService) {
            window.deviceReady = true; // call us again when services are initialized.
            return;
        }

        processDatabaseStartup();
    };

    // ReSharper disable once Html.EventNotResolved
    document.addEventListener("deviceready", onDeviceReady, false);

    var tryToUpdateDatabase = function (database, forceUpdate) {
        var connectionType = navigator.network ? navigator.network.connection.type : undefined;
        logInfo("connection type is " + connectionType);
        if (!forceUpdate && connectionType != Connection.WIFI && connectionType != Connection.ETHERNET) {
            logInfo("Auto-update only occurs on fast connections (wi-fi or ethernet).");
            raiseOnPagesUpdate(null); // Make sure the list is refreshed after the database was loaded.
            return;
        }
        var updateURL = "https://script.google.com/macros/s/AKfycbwk3WW_pyJyJugmrj5ZN61382UabkclrJNxXzEsTDKrkD_vtEc/exec?UpdatedAfter=";
        try {
            var url = updateURL + new Date(Number(getLastUpdateDate())).toISOString();
            raiseOnPagesUpdate(-1); // loading...
            logInfo("getting updates from " + url);
            window.httpService.get(url).success(function (data) {
                try {
                    logInfo("Updated page count: " + data.pages.length);
                    database.transaction(function (tx) {
                        try {
                            data.pages.forEach(function (page) {
                                tx.executeSql("DELETE FROM pages WHERE url=?", [page.url]);
                                if (!page.isDeleted) addPageToDatabase(tx, page);
                            });
                            loadDatabase(database);
                            saveLastUpdateDate(data.maxDate);
                            var updatedPagesCount = data.pages.length;
                            if (forceUpdate && updatedPagesCount == 0) updatedPagesCount = -2; // mark as not found
                            raiseOnPagesUpdate(updatedPagesCount);
                        } catch (updateEx) {
                            logError("Failed to update data. error: " + updateEx);
                            raiseOnPagesUpdate(0); // clear "loading..." message
                        }
                    });
                } catch (e) {
                    logError("Failed to update database: " + e);
                    raiseOnPagesUpdate(0); // clear "loading..." message
                };
            }).error(function (data, status) {
                logError("http get failed.\nstatus: " + data + ",\nstatus: " + status);
                raiseOnPagesUpdate(0); // clear "loading..." message
            });
        } catch (ex) {
            logError("Failed to call http get. error: " + ex);
            raiseOnPagesUpdate(0); // clear "loading..." message
        }
    };

    angular.module('myApp.dataServices', [])
        .factory('PageTable', [
            '$q', '$http', function($q, $http) {
                window.httpService = $http;
                window.deferService = $q;

                if (window.deviceReady) processDatabaseStartup();

                return pageTable;
            }
        ]);
}());