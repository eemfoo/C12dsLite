const Path = require("node:path");
const fs = require("node:fs");
const {AGENT_NAME_PREFIX, mainCos, tempCAOSDirectory, warnings, ROOT} = require("./consts");
const {validate} = require("./validate-build");
const {getOutputMapFile} = require("./mapfile");
const {exitProcess} = require("./exitprocess");

// File Local Variables
const caos2PrayAgentName = /^[ \t]*[*]#\s*((?:C3|DS|[A-Za-z0-9_]{4})-Name)\s+"/gim;

/**
 * Adds link statements for all CAOS files in relative path
 * @param {string[]} text array of CAOS2Pray and comment lines
 * @param {string} relativePath the path relative to root for linking CAOS
 * @param {string|null|undefined} prefixComment comment to insert before CAOS2Pray lines
 */
function linkCos(text, relativePath, prefixComment = null) {
    const path = Path.join(ROOT, relativePath);
    const files = fs.readdirSync(path);

    files.sort();

    if (!files) {
        return;
    }

    if (prefixComment) {
        text.push(`* ${prefixComment}`);
    }

    const agentNamePrefixLastChar = AGENT_NAME_PREFIX ? AGENT_NAME_PREFIX[AGENT_NAME_PREFIX.length - 1] : null;
    const agentNamePrefix = (agentNamePrefixLastChar >= 'a' && agentNamePrefixLastChar <= 'z') ||
    (agentNamePrefixLastChar >= '0' && agentNamePrefixLastChar <= '9')
        ? (AGENT_NAME_PREFIX + " ")
        : AGENT_NAME_PREFIX;

    const copy = (path, contents) => {
        const fileName = Path.basename(path);
        const outFile = Path.join(tempCAOSDirectory, fileName);
        if (contents) {
            fs.writeFileSync(outFile, contents, "latin1");
        } else {
            fs.copyFileSync(path, outFile);
        }
        text.push(`*# Link \"${outFile}\"`);
        return outFile;
    }

    text.push("*# Link \"" + getOutputMapFile() + "\"");

    let okay = true
    for (const file of files) {

        if (!shouldProcess(file)) {
            continue;
        }

        let fileRelative = Path.join(relativePath, file);

        if (fileRelative.toLowerCase().endsWith(" map.cos")) {
            copy(fileRelative);
            continue;
        }

        // Get file contents for checks and Joined agent names
        let rawContent = fs.readFileSync(Path.join(ROOT, fileRelative), "latin1");

        // Add AGENT prefixes if any
        rawContent = rawContent.replaceAll(caos2PrayAgentName, "*# $1 \"" + agentNamePrefix);

        // Save file with updated names
        fileRelative = copy(fileRelative, rawContent);

        okay = validate(fileRelative, rawContent, copy, warnings) && okay;

    }
    if (!okay) {
        exitProcess(1);
    }
}


function shouldProcess(file) {
    if (Path.extname(file).toLowerCase() !== ".cos") {
        return false;
    }

    if (file.toLowerCase().indexOf("99.0") >= 0) {
        return false;
    }

    if (file.toLowerCase() === mainCos.toLowerCase()) {
        return false;
    }

    if (file.toLowerCase().indexOf(mainCos.toLowerCase()) >= 0) {
        return false;
    }
    return true;
}

module.exports = {
    linkCos
}