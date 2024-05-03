// =================== //
// ==== DOWNLOAD ==== //
// =================== //

const https = require("node:https");
const fs = require("node:fs");

/**
 * Gets the bytes for a given URL
 * @param url
 * @returns {Promise<Buffer>}
 */
function get(url) {
    return new Promise((resolve, reject) => {
        _get(url, resolve, reject);
    });
}

/**
 * Follows redirects and resolved with bytes of the URL
 * @param {string} url
 * @param {(data: Buffer) => void}resolve
 * @param {(e:Error|string|null|undefined) => void} reject
 * @private
 */
function _get(url, resolve, reject) {
    https.get(url, (res) => {
        // if any other status codes are returned, those needed to be added here
        if (res.statusCode === 301 || res.statusCode === 302) {
            return _get(res.headers.location, resolve, reject)
        }

        let body = [];

        res.on("data", (chunk) => {
            body.push(chunk);
        });

        res.on("end", () => {
            try {
                resolve(Buffer.concat(body));
            } catch (err) {
                reject(err);
            }
        });
    });
}

/**
 * Downloads a file to a given destination path
 * @param {string} url path to download
 * @param {string} destination absolute path to write downloaded file
 * @returns {Promise<string>} Promise resolving to the output download location
 */
async function download(url, destination) {
    return new Promise(async (resolve) => {
        const data = await get(url);
        fs.writeFileSync(destination, data, "binary");
        fs.chmodSync(destination, 0o0755);
        setTimeout(() => {
            resolve(destination);
        }, 1);
    });
}


module.exports = {
    download,
}