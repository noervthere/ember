pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals
import "wallpapers/strategies"

Singleton {
    id: root

    property string source: Config.onlineWallpapers ? Config.onlineWallpapers.defaultSource : "wallhaven"
    property string query: ""
    property int currentPage: 1
    property int lastPage: 1
    property var wallpapers: []
    property bool isLoading: false
    property string lastError: ""

    property bool isDownloading: false
    property string downloadingUrl: ""

    property WallhavenStrategy wallhavenStrategy: WallhavenStrategy {}
    property KonachanStrategy konachanStrategy: KonachanStrategy {}

    function getStrategy() {
        if (source === "konachan") {
            return konachanStrategy;
        }
        return wallhavenStrategy;
    }

    function setSource(newSource) {
        if (source !== newSource) {
            source = newSource;
            GlobalStates.onlineWallpaperSource = newSource;
            currentPage = 1;
            search(query, 1);
        }
    }

    function search(queryText, pageNum) {
        if (isLoading)
            searchProcess.running = false;

        query = queryText !== undefined ? queryText : query;
        currentPage = pageNum !== undefined ? pageNum : 1;
        isLoading = true;
        lastError = "";

        let perPage = Config.onlineWallpapers ? Config.onlineWallpapers.resultsPerPage : 24;
        let apiKey = (source === "wallhaven" && Config.onlineWallpapers) ? Config.onlineWallpapers.wallhavenApiKey : "";
        let strategy = getStrategy();
        let url = strategy.buildSearchUrl(query, currentPage, perPage, apiKey);

        let userAgent = "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0";
        searchProcess.command = ["bash", "-c", "curl -s -L -w '\\nHTTP_STATUS:%{http_code}' -A '" + userAgent + "' '" + url.replace(/'/g, "'\\''") + "'"];
        searchProcess.running = true;
    }

    function nextPage() {
        if (currentPage < lastPage && !isLoading) {
            search(query, currentPage + 1);
        }
    }

    function prevPage() {
        if (currentPage > 1 && !isLoading) {
            search(query, currentPage - 1);
        }
    }

    Process {
        id: searchProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isLoading)
                    return;

                let textStr = text || "";
                let statusCode = 0;
                let bodyText = textStr;

                let statusMatch = textStr.match(/HTTP_STATUS:(\d+)\s*$/);
                if (statusMatch) {
                    statusCode = parseInt(statusMatch[1]);
                    bodyText = textStr.substring(0, statusMatch.index).trim();
                }

                console.log("=== ONLINE WALLPAPER API RESPONSE LOG ===");
                console.log("Source:", root.source);
                console.log("HTTP Status Code:", statusCode);
                console.log("Body Snippet (first 300 chars):", bodyText.substring(0, 300));
                console.log("=======================================");

                if (statusCode !== 200 || bodyText === "" || bodyText.startsWith("<")) {
                    console.warn("Invalid API response from " + root.source + " [HTTP " + statusCode + "]: " + bodyText.substring(0, 300));
                    root.lastError = "Invalid response from " + root.source + " (HTTP " + statusCode + ")";
                    root.isLoading = false;
                    return;
                }

                let strategy = root.getStrategy();
                let res = strategy.parseResponse(bodyText, root.currentPage);

                let filtered = [];
                if (res && res.items && Array.isArray(res.items)) {
                    for (let i = 0; i < res.items.length; i++) {
                        let item = res.items[i];
                        if (strategy.isSfw(item)) {
                            filtered.push(item);
                        }
                    }
                }

                root.wallpapers = filtered;
                root.currentPage = res.page || 1;
                root.lastPage = res.lastPage || 1;
                root.isLoading = false;
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = "Network error fetching wallpapers";
                root.isLoading = false;
            }
        }
    }

    property var pendingDownloadItem: null
    property string pendingTargetScreen: ""
    property bool pendingSaveToCollection: false

    function downloadAndApply(item, targetScreen) {
        if (!item || !item.fullUrl || isDownloading)
            return;

        pendingDownloadItem = item;
        pendingTargetScreen = targetScreen || "";
        pendingSaveToCollection = false;
        isDownloading = true;
        downloadingUrl = item.fullUrl;
        GlobalStates.onlineWallpaperDownloadingUrl = item.fullUrl;

        let cacheDir = (Quickshell.env("HOME") + "/.cache/ambxst/online_wallpapers");
        let ext = _getExtension(item.fullUrl);
        let fileName = item.source + "_" + item.id + ext;
        let destPath = cacheDir + "/" + fileName;

        // Clean all old cached files before downloading the new one
        let userAgent = "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0";
        let cmd = "mkdir -p '" + cacheDir + "' && find '" + cacheDir + "' -type f -not -name '" + fileName + "' -delete && curl -s -L -A '" + userAgent + "' -o '" + destPath + "' '" + item.fullUrl.replace(/'/g, "'\\''") + "'";
        downloadProcess.destPath = destPath;
        downloadProcess.command = ["bash", "-c", cmd];
        downloadProcess.running = true;
    }

    function saveToCollection(item) {
        if (!item || !item.fullUrl || isDownloading)
            return;

        pendingDownloadItem = item;
        pendingTargetScreen = "";
        pendingSaveToCollection = true;
        isDownloading = true;
        downloadingUrl = item.fullUrl;
        GlobalStates.onlineWallpaperDownloadingUrl = item.fullUrl;

        let cacheDir = (Quickshell.env("HOME") + "/.cache/ambxst/online_wallpapers");
        let ext = _getExtension(item.fullUrl);
        let fileName = item.source + "_" + item.id + ext;
        let destPath = cacheDir + "/" + fileName;

        let userAgent = "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0";
        let cmd = "mkdir -p '" + cacheDir + "' && find '" + cacheDir + "' -type f -not -name '" + fileName + "' -delete && curl -s -L -A '" + userAgent + "' -o '" + destPath + "' '" + item.fullUrl.replace(/'/g, "'\\''") + "'";
        downloadProcess.destPath = destPath;
        downloadProcess.command = ["bash", "-c", cmd];
        downloadProcess.running = true;
    }

    function _getExtension(url) {
        if (url.endsWith(".png")) return ".png";
        if (url.endsWith(".jpeg")) return ".jpeg";
        if (url.endsWith(".webp")) return ".webp";
        return ".jpg";
    }

    Process {
        id: downloadProcess
        running: false
        property string destPath: ""

        onExited: exitCode => {
            root.isDownloading = false;
            root.downloadingUrl = "";
            GlobalStates.onlineWallpaperDownloadingUrl = "";

            if (exitCode === 0 && destPath !== "") {
                if (root.pendingSaveToCollection) {
                    // Right-click: copy to user's wallpaper directory
                    _copyToWallpaperDir(destPath);
                } else {
                    // Left-click: apply as wallpaper
                    if (GlobalStates.wallpaperManager) {
                        if (GlobalStates.wallpaperManager.setExternalWallpaper) {
                            GlobalStates.wallpaperManager.setExternalWallpaper(destPath, root.pendingTargetScreen);
                        } else {
                            GlobalStates.wallpaperManager.setWallpaper(destPath, root.pendingTargetScreen);
                        }
                    } else {
                        console.warn("GlobalStates.wallpaperManager is null, cannot set wallpaper");
                    }
                }
            } else {
                root.lastError = "Failed to download wallpaper";
            }
            root.pendingDownloadItem = null;
            root.pendingTargetScreen = "";
            root.pendingSaveToCollection = false;
        }
    }

    function _copyToWallpaperDir(srcPath) {
        let wallDir = "";
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.wallpaperDir) {
            wallDir = GlobalStates.wallpaperManager.wallpaperDir;
        }
        if (!wallDir || wallDir === "") {
            console.warn("No wallpaper directory configured, cannot save to collection");
            root.lastError = "No wallpaper directory configured";
            return;
        }
        let fileName = srcPath.substring(srcPath.lastIndexOf("/") + 1);
        let destPath = wallDir + "/" + fileName;
        saveProcess.command = ["bash", "-c", "mkdir -p '" + wallDir + "' && cp '" + srcPath + "' '" + destPath + "'"];
        saveProcess.running = true;
    }

    Process {
        id: saveProcess
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("Wallpaper saved to collection successfully");
                // Rescan wallpapers so the new file appears in the local grid
                if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.loadWallpapers) {
                    GlobalStates.wallpaperManager.loadWallpapers();
                }
            } else {
                console.warn("Failed to save wallpaper to collection");
                root.lastError = "Failed to save wallpaper to collection";
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(() => search("", 1));
    }
}
