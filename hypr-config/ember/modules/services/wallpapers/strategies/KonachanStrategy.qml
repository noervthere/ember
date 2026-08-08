import QtQuick

WallpaperApiStrategy {
    id: strategy

    function buildSearchUrl(query, page, perPage, apiKey) {
        let tags = "rating:safe";
        if (query && query.trim() !== "") {
            tags += "+" + encodeURIComponent(query.trim().replace(/\s+/g, "_"));
        }
        let limit = perPage || 24;
        let p = page || 1;
        return "https://konachan.net/post.json?tags=" + tags + "&page=" + p + "&limit=" + limit;
    }

    function isSfw(item) {
        return !!(item && item.rating === "s");
    }

    function parseResponse(responseText, requestedPage) {
        let items = [];
        let p = requestedPage || 1;
        let lastPage = p;

        try {
            let data = JSON.parse(responseText);
            if (Array.isArray(data)) {
                for (let i = 0; i < data.length; i++) {
                    let post = data[i];
                    if (post && post.rating === "s") {
                        let fullUrl = post.file_url || post.jpeg_url || post.sample_url || "";
                        let previewUrl = post.preview_url || post.sample_url || fullUrl;
                        if (fullUrl !== "") {
                            if (fullUrl.startsWith("//")) fullUrl = "https:" + fullUrl;
                            if (previewUrl.startsWith("//")) previewUrl = "https:" + previewUrl;

                            let res = (post.width && post.height) ? (post.width + "x" + post.height) : "";
                            items.push({
                                id: post.id ? String(post.id) : ("kona_" + i),
                                source: "konachan",
                                previewUrl: previewUrl,
                                fullUrl: fullUrl,
                                resolution: res,
                                ratio: "",
                                fileSize: post.file_size || 0,
                                rating: post.rating
                            });
                        }
                    }
                }
                lastPage = data.length >= 24 ? p + 1 : p;
            }
        } catch (e) {
            console.error("KonachanStrategy parse error:", e);
        }

        return {
            items: items,
            page: p,
            lastPage: Math.max(p, lastPage)
        };
    }
}
