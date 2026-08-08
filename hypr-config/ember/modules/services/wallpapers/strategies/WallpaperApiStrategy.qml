import QtQuick

QtObject {
    function buildSearchUrl(query, page, perPage, apiKey) {
        return "";
    }

    function parseResponse(responseText, requestedPage) {
        let p = requestedPage || 1;
        return {
            items: [],
            page: p,
            lastPage: p
        };
    }

    function isSfw(item) {
        return true;
    }
}
