'use strict';

angular.module('myApp', [
    'ngTouch',
    'ngRoute',
    'ngAnimate',
    'myApp.controllers',
    'myApp.dataServices'
]).
config(['$routeProvider', function ($routeProvider) {
    $routeProvider.when('/pages', {templateUrl: 'partials/page-list.html', controller: 'PageListCtrl'});
    $routeProvider.when('/pages/:pageName', {templateUrl: 'partials/page-detail.html', controller: 'PageDetailCtrl'});
    $routeProvider.otherwise({redirectTo: '/pages'});
    //$routeProvider.otherwise({redirectTo: '/welcome'});
}]);