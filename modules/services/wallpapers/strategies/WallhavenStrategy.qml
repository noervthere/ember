import QtQuick

WallpaperApiStrategy {
    id: strategy

    function buildSearchUrl(query, page, perPage, apiKey) {
        let sorting = (query && query.trim() !== "") ? "relevance" : "toplist";
        let url = "https://wallhaven.cc/api/v1/search?purity=100&sorting=" + sorting + "&page=" + page;
        if (query && query.trim() !== "") {
            url += "&q=" + encodeURIComponent(query.trim());
        }
        if (apiKey && apiKey.trim() !== "") {
            url += "&apikey=" + encodeURIComponent(apiKey.trim());
        }
        return url;
    }

    function isSfw(item) {
        return !!(item && item.purity === "sfw");
    }

    function parseResponse(responseText, requestedPage) {
        let items = [];
        let page = requestedPage || 1;
        let lastPage = page;

        try {
            let data = JSON.parse(responseText);
            if (data && data.data && Array.isArray(data.data)) {
                for (let i = 0; i < data.data.length; i++) {
                    let wall = data.data[i];
                    if (wall && wall.purity === "sfw") {
                        let thumb = wall.thumbs ? (wall.thumbs.large || wall.thumbs.small || wall.path) : wall.path;
                        items.push({
                            id: wall.id ? String(wall.id) : ("wh_" + i),
                            source: "wallhaven",
                            previewUrl: thumb,
                            fullUrl: wall.path,
                            resolution: wall.resolution || "",
                            ratio: wall.ratio || "",
                            fileSize: wall.file_size || 0,
                            fileType: wall.file_type || "image/jpeg",
                            purity: wall.purity
                        });
                    }
                }
            }
            if (data && data.meta) {
                page = data.meta.current_page || page;
                lastPage = data.meta.last_page || page;
            }
        } catch (e) {
            console.error("WallhavenStrategy parse error:", e);
        }

        return {
            items: items,
            page: page,
            lastPage: Math.max(page, lastPage)
        };
    }
}
