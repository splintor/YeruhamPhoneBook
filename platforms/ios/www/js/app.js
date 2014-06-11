'use strict';

angular.module('myApp', [
    'ngTouch',
    'ngRoute',
    'ngAnimate',
    'ngSanitize',
    'myApp.controllers',
    'myApp.dataServices'
])
.config(['$routeProvider', function ($routeProvider) {
    $routeProvider.when('/pages', {templateUrl: 'partials/page-list.html', controller: 'PageListCtrl'});
    $routeProvider.when('/pages/:pageName', {templateUrl: 'partials/page-detail.html', controller: 'PageDetailCtrl'});
    $routeProvider.otherwise({redirectTo: '/pages'});
    //$routeProvider.otherwise({redirectTo: '/welcome'});
}])
.filter("pagesFilter", function($filter) {
    return function (pages, $scope) {
        if ($scope.resultsOverflowTimeout) {
            $scope.$timeout.cancel($scope.resultsOverflowTimeout);
        }

        var search = $scope.search;
        if (typeof search != 'string' || search == '') {
            $scope.resultsOverflow = -1;
            return [];
        }
        var parseToWords = function (value) {
            var pos = value.indexOf('"');
            if (pos == -1) return value.split(" ");
            var nextPos = value.indexOf('"', pos + 1);
            if (nextPos == -1) return parseToWords(value.replace(/"/, ""));
            return parseToWords(value.substr(0, pos)).concat(value.substr(pos + 1, nextPos - pos - 1)).concat(parseToWords(value.substr(nextPos + 1)));
        };
        var searchWords = parseToWords(search.toLowerCase());
        var matchWord = function (page, word) {
            return page.title.toLowerCase().indexOf(word) > -1 ||
                   page.text.toLowerCase().indexOf(word) > -1 ||
                   (word.match(/^[\d-]*$/) && page.text.replace(/-/g, "").indexOf(word.replace(/-/g, "")) > -1);
        };
        var searchFunc = function (page) {
            return searchWords.length > 0 && searchWords.every(function(word) { return matchWord(page, word); });
        };
        var result = $filter('filter')(pages, searchFunc);
        if (result.length > 40) {
            var resultsOverflow = result.length;
            if ($scope.resultsOverflow > 0) { // we already show overflow message, so immedately update it
                $scope.resultsOverflow = resultsOverflow;
            } else { // only show overflow message after two seconds the user hasn't types, to reduce noise.
                $scope.resultsOverflowTimeout = $scope.$timeout(function() {
                    $scope.resultsOverflow = resultsOverflow;
                }, 2000);
            }

            return [];
        }

        $scope.resultsOverflow = result.length == 0 ? 0 : -1;
        return result;
    };
})
.directive('focusOn', function () {
    return {
        link: function (scope, element, attrs) {
            scope.$watch(attrs.focusOn, function (value) {
                if (value === true) {
                    element[0].focus();
                    scope.showKeyboard();
                    scope[attrs.focusOn] = false;
                }
            });
        }
    };
});;