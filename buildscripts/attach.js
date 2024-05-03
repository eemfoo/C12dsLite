const Path = require("node:path");
const fs = require("node:fs");
const {attachmentExtensions, ROOT} = require("./consts");


/**
 * Adds attachment CAOS2Pray statements for all files in relative path
 * @param {string[]} text array of CAOS2Pray and comment lines
 * @param {string} relativePath the path relative to root for linking CAOS
 * @param {string|null|undefined} prefixComment comment to insert before CAOS2Pray lines
 */
function attachFilesIn(text, relativePath, prefixComment) {
    const path = Path.join(ROOT, relativePath);
    const files = fs.readdirSync(path)
        .filter((file) => attachmentExtensions.indexOf(Path.extname(file).toLowerCase()) >= 0)

    if (!files) {
        return;
    }

    if (prefixComment) {
        text.push(`* ${prefixComment}`);
    }

    for (let file of files) {
        file = Path.join(relativePath, file);
        text.push(`*# Attach \"../${file}\"`);
    }
}

module.exports = {
    attachFilesIn,
}