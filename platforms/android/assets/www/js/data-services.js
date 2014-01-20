'use strict';

(function () {

    var pages = currentData.pages,

        findByName = function (name) {
            var page = null,
                l = pages.length,
                i;
            for (i = 0; i < l; i = i + 1) {
                if (pages[i].name === name) {
                    page = pages[i];
                    break;
                }
            }
            return page;
        };

    angular.module('myApp.dataServices', [])
        .factory('Page', [
            function () {
                return {
                    query: function () {
                        return pages;
                    },
                    get: function (page) {
                        return findByName(parseInt(page.name));
                    }
                }

            }]);
}());