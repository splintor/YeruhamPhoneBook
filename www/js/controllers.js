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
    }])
    .controller('PageDetailCtrl', ['$scope', '$routeParams', 'Page', function ($scope, $routeParams, Page) {
        $scope.page = Page.get({name: $routeParams.pageName});
    }])
