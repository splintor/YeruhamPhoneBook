'use strict';

angular.module('myApp.controllers', [])
    .controller('MainCtrl', [
        '$scope', '$rootScope', '$window', '$location', function($scope, $rootScope, $window, $location) {
            $scope.slide = '';
            $rootScope.back = function() {
                //$scope.slide = 'slide-left';
                $window.history.back();
            };
            $rootScope.go = function(path, currentSearch, $event) {
                if ($event && $event.target && $event.target.href) return; // ignore if a link was clicked
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
                    var replacePattern3 = /(([a-zA-Z0-9\-\_\.])+@[a-zA-Z\_]+?(\.[a-zA-Z]{2,6})+)/gim;
                    t = t.replace(replacePattern3, '<a href="mailto:$1">$1</a>');
                }

                //Change phone numbers to tel:: links.
                var replacePattern4 = /(\b[0-9][0-9\-\_\.]{5,11}\b)/gim;
                t = t.replace(replacePattern4, '<a href="tel:$1">$1</a>');

                return t;
            };
        }
    ])
    .controller('PageListCtrl', [
        '$scope', '$rootScope', 'PageTable', '$timeout', function ($scope, $rootScope, pageTable, $timeout) {
            $scope.pages = pageTable.getAllPages();
            $scope.search = $rootScope.rememberedSearch;
            $scope.linkify = $rootScope.linkify;
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
                    plugins.softKeyboard.show(function() {}, function(errDescr) { $scope.search = "Error occured: " + errDescr; });
                }
            };
            $timeout($scope.showKeyboard);
            $timeout($scope.showKeyboard, 200);
        }
    ])
    .controller('PageDetailCtrl', [
        '$scope', '$routeParams', '$rootScope', 'PageTable', function($scope, $routeParams, $rootScope, pageTable) {
            $scope.page = pageTable.getPage({ name: $routeParams.pageName });
            $scope.linkify = $rootScope.linkify;
        }
    ]);
