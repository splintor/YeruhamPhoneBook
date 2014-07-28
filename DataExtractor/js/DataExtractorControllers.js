'use strict';

angular.module('myApp.controllers', [])
    .controller('MainCtrl', [
        '$scope', '$rootScope', '$window', '$location', function($scope, $rootScope, $window, $location) {
            try {
                $rootScope.getMail = function (text) {
                    try {
                        var result = text.match(/(([a-zA-Z0-9\-\_\.])+@[a-zA-Z\_]+?(\.[a-zA-Z]{2,6})+)/gim);
                        if (!result) return result;
                        return '<a href="mailto:' + result[0] + '">' + result[0] + '</a>';
                    } catch (exception) {
                        console.log("An exception has occured in pagesFilter: " + exception);
                        return 'aaa';
                    }
                }

                $rootScope.getPhone = function (text, index) {
                    try {
                        var result = text.match(/(\b[0-9][0-9\-\_\.]{5,11}\b)/gim);
                        return result ? result[index] : null;
                    } catch (exception) {
                        console.log("An exception has occured in pagesFilter: " + exception);
                        return 'aaa';
                    }
                }

                $scope.pages = dataExtractorData.pages;
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
                $scope.orderFunc = function(p) {
                    return p.title;
                };
            } catch (exception) {
                console.log("An exception has occured in PageDetailCtrl: " + exception);
            }
        }
    ]);
