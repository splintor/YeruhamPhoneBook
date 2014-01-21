'use strict';

angular.module('myApp', [
    'ngTouch',
    'ngRoute',
    'ngAnimate',
    'ngSanitize',
    'myApp.controllers',
    'myApp.dataServices'
]).
config(['$routeProvider', function ($routeProvider) {
    $routeProvider.when('/pages', {templateUrl: 'partials/page-list.html', controller: 'PageListCtrl'});
    $routeProvider.when('/pages/:pageName', {templateUrl: 'partials/page-detail.html', controller: 'PageDetailCtrl'});
    $routeProvider.otherwise({redirectTo: '/pages'});
    //$routeProvider.otherwise({redirectTo: '/welcome'});
}]).
filter("pagesFilter", function($filter) {
    return function(pages, search) {
    	if(typeof search != 'string' || search == '') return [];
    	var lowerCaseSearch = search.toLowerCase();
    	var searchFunc = function(value) {
    		return value.title.toLowerCase().indexOf(lowerCaseSearch) > -1 ||
    			   value.text.toLowerCase().indexOf(lowerCaseSearch) > -1;
    	}
    	var result = $filter('filter')(pages, searchFunc);
    	return result.length < 20 ? result : [];
    }
});