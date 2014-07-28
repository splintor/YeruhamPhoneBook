'use strict';

angular.module('myApp', [
    'ngTouch',
    'ngRoute',
    'ngAnimate',
    'ngSanitize',
    'myApp.controllers'
])
// .config(['$routeProvider', function ($routeProvider) {
//     $routeProvider.when('/pages', {templateUrl: 'partials/page-list.html', controller: 'PageListCtrl'});
//     $routeProvider.when('/pages/:pageName', {templateUrl: 'partials/page-detail.html', controller: 'PageDetailCtrl'});
//     $routeProvider.otherwise({redirectTo: '/pages'});
// }])
.filter("pagesFilter", function ($filter) {
    return function (pages, $scope) {
        try {
            var titleFilter = $scope.titleFilter;
            var textFilter = $scope.textFilter;
            var urlFilter = $scope.urlFilter;
            var nameFilter = $scope.nameFilter;
            var htmlFilter = $scope.htmlFilter;
            var parseToWords = function(value) {
                var pos = value.indexOf('"');
                if (pos == -1) {
                    var words = value.split(" ");
                    for (var i = 0; i < words.length; ++i) {
                        var match = words[i].match(/^\#\#(.*)/);
                        if (match) words.splice(i, 1, new RegExp(match[1]));
                    }

                    return words;
                }

                var nextPos = value.indexOf('"', pos + 1);
                if (nextPos == -1) return parseToWords(value.replace(/"/, ""));
                return parseToWords(value.substr(0, pos)).concat(value.substr(pos + 1, nextPos - pos - 1)).concat(parseToWords(value.substr(nextPos + 1)));
            };
            var matchFunc = function(s, filter) {
                return filter == undefined || filter.length == 0 || s.toLowerCase().indexOf(filter) > -1;
            }
            var searchFunc = function (page) {
                return matchFunc(page.title, titleFilter) &&
                    matchFunc(page.text, textFilter) &&
                    matchFunc(page.url, urlFilter) &&
                    matchFunc(page.name, nameFilter) &&
                    matchFunc(page.html, htmlFilter);
            };
            var results = $filter('filter')(pages, searchFunc);
            $scope.resultsCount = results.length;
            return results;
        } catch (exception) {
            console.log("An exception has occured in pagesFilter: " + exception);
            return [];
        }
    };
})
.filter("mailFilter", function ($filter) {
    return function (text, $scope) {
        try {
            var result = text.match(/(([a-zA-Z0-9\-\_\.])+@[a-zA-Z\_]+?(\.[a-zA-Z]{2,6})+)/gim);
            if (!result) return result;
            return '<a href="mailto:' + result + '">' + "abc" + '</a>';
        } catch (exception) {
            console.log("An exception has occured in pagesFilter: " + exception);
            return [];
        }
    };
})
.directive('focusOn', function () {
    return {
        link: function (scope, element, attrs) { 
            scope.$watch(attrs.focusOn, function (value) {
                try {
                    if (value === true) {
                        element[0].focus();
                        scope.showKeyboard();
                        scope[attrs.focusOn] = false;
                    }
                } catch (exception) {
                    console.log("An exception has occured in focusOn directive: " + exception);
                }
            });
        }
    };
});;