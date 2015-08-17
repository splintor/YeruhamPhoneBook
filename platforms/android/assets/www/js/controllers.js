'use strict';

angular.module('myApp.controllers', [])
    .controller('MainCtrl', [
        '$scope', '$rootScope', '$window', '$location', function($scope, $rootScope, $window, $location) {
            try {
                $scope.slide = '';
                $rootScope.back = function() {
                    //$scope.slide = 'slide-left';
                    $window.history.back();
                };

                $rootScope.fakeClick = function (anchorObj) { // http://stackoverflow.com/a/1421968/46635
                    try {
                        if (anchorObj.click) {
                            anchorObj.click();
                        } else if (document.createEvent) {
                            var evt = document.createEvent("MouseEvents");
                            evt.initMouseEvent("click", true, true, window,
                                0, 0, 0, 0, 0, false, false, false, false, 0, null);
                            anchorObj.dispatchEvent(evt);
                        }
                    } catch (e) {
                        console.log("Failed to fake a click: " + e);
                    } 
                };

                $rootScope.go = function (path, currentSearch, $event) {
                    if ($event && $event.target && $event.target.href) {
                        $rootScope.fakeClick($event.target);
                        $event.preventDefault();
                        $event.stopPropagation();
                        return;
                    }
                    $rootScope.rememberedSearch = currentSearch;
                    //$scope.slide = 'slide-right';
                    $location.url(path);
                };
                $rootScope.linkify = function(t, onlyNumbers) {
                    // taken from http://stackoverflow.com/a/3890175/46635

                    if (!onlyNumbers) {
                        //URLs starting with http://, https://, or ftp://
                        var replacePattern1 = /(\b(https?|ftp):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/gim;
                        t = t.replace(replacePattern1, '<a href="$1" target="_blank">$1</a>');

                        //URLs starting with "www." (without // before it, or it'd re-link the ones done above).
                        var replacePattern2 = /(^|[^\/])(www\.[\S]+(\b|$))/gim;
                        t = t.replace(replacePattern2, '$1<a href="http://$2" target="_blank">$2</a>');

                        //Change email addresses to mailto: links.
                        var replacePattern3 = /(([a-zA-Z0-9\-_\.])+@[a-zA-Z_]+?(\.[a-zA-Z]{2,6})+)/gim;
                        t = t.replace(replacePattern3, '<a href="mailto:$1">$1</a>');
                    }

                    //Change phone numbers to tel:: links.
                    var replacePattern4 = /(\b[0-9][0-9\-_\.]{5,11}\b)/gim;
                    t = t.replace(replacePattern4, '<a href="tel:$1">$1</a>');

                    t = t.replace("https://sites.google.com/site/yeruchamphonebook/", '#/pages/');

                    return t;
                };
            } catch (exception) {
                console.log("An exception has occurred in PageDetailCtrl: " + exception);
            }
        }
    ])
    .controller('PageListCtrl', [
        '$scope', '$rootScope', 'PageTable', '$timeout', function($scope, $rootScope, pageTable, $timeout) {
            try {
                $scope.pages = pageTable.getAllPages();
                $scope.search = $rootScope.rememberedSearch;
                $scope.linkify = $rootScope.linkify;
                pageTable.onPagesUpdate = function(updatedPagesCount, updatedPages) {
                    console.log("updatedPagesCount: " + updatedPagesCount);
                    if (updatedPagesCount == null) { // database was loaded, and refresh is needed
                        $scope.pages = pageTable.getAllPages();
                    } else { // only count was updated
                        $scope.updatedPages = updatedPages;
                        $scope.updatedPagesCount = updatedPagesCount;
                    }

                    if ($scope.validationFailed) {
                        $scope.validateNumber();
                    }

                    if (!$scope.$$phase) {
                        console.log("Calling $scope.$apply()");
                        $scope.$apply(); // we might need to apply, as this update can occur within a transaction callback, to which PhoneGap is not aware
                    }
                };

                $scope.invalidNumber = !pageTable.validateNumber();
                $scope.validationNumber = pageTable.validationNumber;
                $scope.validationFailed = false;
                $scope.validateNumber = function(number) {
                    if (pageTable.validateNumber(number)) {
                        console.log("setting $scope.invalidNumber to false");
                        $scope.invalidNumber = false;
                        $scope.validationFailed = false;
                    } else {
                        console.log("setting $scope.validationFailed to true");
                        $scope.validationFailed = true;
                    }
                };

                $scope.clearValidationNumber = pageTable.clearValidationNumber;

                $scope.getAboutPage = function() { return pageTable.getAboutPage(); };
                $scope.getValidationPage = function() { return pageTable.getValidationPage(); };
                $scope.getValidationResetPage = function() { return pageTable.getValidationResetPage(); };
                $scope.clearValidationNumber = function() { return pageTable.clearValidationNumber(); };

                $scope.forceUpdate = function() {
                    console.log("forceUpdate");
                    $timeout(function() { $scope.searchFocus = true; }, 0);
                    pageTable.forceUpdate();
                };

                $scope.resetUpdatesPagesCount = function() { $scope.updatedPagesCount = 0; };
                $scope.openUpdatesPages = function() {
                    $scope.resetUpdatesPagesCount();
                    $scope.search = "#חדשים";
                };

                // resultsOverflow can be one of the following values:
                //   -2 means waiting for timeout to update
                //   -1 means there was no overflow
                //   0 means search was not found
                //   Positive number means the overflow number of results
                $scope.resultsOverflow = -1;
                $scope.$timeout = $timeout;
                var pad = "00000";
                var padNum = function(n) {
                    var s = '' + n;
                    return pad.substring(0, pad.length - s.length) + s;
                };
                $scope.trimText = function(t, n) {
                    return t.length > n ? t.substring(0, n) + "..." : t;
                };
                $scope.orderFunc = function(p) {
                    var search = $scope.search;
                    if (typeof search != 'string' || search == '') return p.title;
                    search = search.toLowerCase();
                    var titleIndex = p.title.toLowerCase().indexOf(search);
                    if (titleIndex > -1) return "A" + padNum(titleIndex) + p.title;
                    var textIndex = p.text.toLowerCase().indexOf(search);
                    if (textIndex > -1) return "B" + padNum(textIndex) + p.title;
                    return "C" + p.title;
                };
                $scope.clearSearch = function() {
                    $scope.search = '';
                    $timeout(function() { $scope.searchFocus = true; }, 0);
                    $timeout(function() { $scope.searchFocus = true; }, 200);
                    $timeout(function() { $scope.searchFocus = true; }, 400);
                };
                $scope.showKeyboard = function() {
                    if (plugins && plugins.softKeyboard) {
                        plugins.softKeyboard.show(function() {}, function(error) { console.error("Error occurred in plugins.softKeyboard: " + error, error); });
                    }
                };

// ReSharper disable once Html.EventNotResolved
                document.addEventListener("deviceready", $scope.showKeyboard, false);
                if($scope.invalidNumber) {
                    $timeout(function() {
                        $scope.showKeyboard
                    }, 100);
                }
            } catch (exception) {
                console.log("An exception has occurred in PageListCtrl: " + exception);
            }
        }
    ])
    .controller('PageDetailCtrl', [
        '$scope', '$routeParams', '$rootScope', 'PageTable', function($scope, $routeParams, $rootScope, pageTable) {
            try {
                //noinspection JSUnresolvedVariable
                $scope.page = pageTable.getPage($routeParams.pageName);
                $scope.linkify = $rootScope.linkify;
            } catch (exception) {
                console.log("An exception has occurred in PageDetailCtrl: " + exception);
            }
        }
    ]);
