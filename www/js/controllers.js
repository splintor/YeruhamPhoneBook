'use strict';

angular.module('myApp.controllers', [])
    .controller('MainCtrl', ['$scope', '$rootScope', '$window', '$location', function ($scope, $rootScope, $window, $location) {
        $scope.slide = '';
        $rootScope.back = function() {
          $scope.slide = 'slide-right';
          $window.history.back();
        }
        $rootScope.go = function(path){
          $scope.slide = 'slide-left';
          $location.url(path);
        }
    }])
    .controller('PageListCtrl', ['$scope', 'Page', function ($scope, Page) {
        $scope.pages = Page.query();
        var pad = "00000"
        $scope.padNum = function(n) {
            var s = '' + n;
            return pad.substring(0, pad.length - s.length) + s;
        }
        $scope.orderFunc = function(page) { 
            var search = $scope.$rootScope.search;
            if(typeof search != 'string' || search == '') return page.title;
            search = search.toLowerCase();
            var titleIndex =  page.title.toLowerCase().indexOf(search); 
            if(titleIndex > -1) return "A" + $scope.padNum(titleIndex) + page.title;
            var textIndex =  page.text.toLowerCase().indexOf(search); 
            if(textIndex > -1) return "B" + $scope.padNum(textIndex) + page.title;
            return "C" + page.title;
        }
    }])
    .controller('PageDetailCtrl', ['$scope', '$routeParams', 'Page', function ($scope, $routeParams, Page) {
        $scope.page = Page.get({name: $routeParams.pageName});
    }])
