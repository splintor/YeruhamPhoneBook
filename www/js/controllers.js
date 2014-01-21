'use strict';

angular.module('myApp.controllers', [])
    .controller('MainCtrl', ['$scope', '$rootScope', '$window', '$location', function ($scope, $rootScope, $window, $location) {
        $scope.slide = '';
        $rootScope.back = function() {
          $scope.slide = 'slide-right';
          $window.history.back();
        }
        $rootScope.go = function(path, currentSearch){
          $rootScope.rememberedSearch = currentSearch;
          $scope.slide = 'slide-left';
          $location.url(path);
        }
    }])
    .controller('PageListCtrl', ['$scope', '$rootScope', 'Page', function ($scope, $rootScope, Page) {
        $scope.pages = Page.query();
        $scope.search = $rootScope.rememberedSearch;
        var pad = "00000"
        var padNum = function(n) {
            var s = '' + n;
            return pad.substring(0, pad.length - s.length) + s;
        }
        
        $scope.trimText = function(t, n) { return t.length > n ? t.substring(0, n) + "..." : t; }
        $scope.orderFunc = function(page) { 
            var search = $scope.search;
            if(typeof search != 'string' || search == '') return page.title;
            search = search.toLowerCase();
            var titleIndex =  page.title.toLowerCase().indexOf(search); 
            if(titleIndex > -1) return "A" + padNum(titleIndex) + page.title;
            var textIndex =  page.text.toLowerCase().indexOf(search); 
            if(textIndex > -1) return "B" + padNum(textIndex) + page.title;
            return "C" + page.title;
        }
    }])
    .controller('PageDetailCtrl', ['$scope', '$routeParams', 'Page', function ($scope, $routeParams, Page) {
        $scope.page = Page.get({name: $routeParams.pageName});
    }])
