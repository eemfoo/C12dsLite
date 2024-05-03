const Path = require("node:path");
const fs =  require("node:fs");
const {ROOT, tempCAOSDirectory} = require("./consts");

let outputMapFile = null;

function getOutputMapFile() {
    return outputMapFile;
}


/**
 * Adds music to the map file, and writes it to the ./cos subdirectory
 * @returns {boolean} true if map file is written
 */
const addMusicAndWriteMap = function () {

// Output
    const outputFileName = "0.01 - DO_NOT_EDIT - MAP.cos";
    outputMapFile = Path.join(tempCAOSDirectory, outputFileName);

    if (fs.existsSync(outputMapFile)) {
        try {
            fs.rmSync(outputMapFile);
        } catch {
            // ignore
        }
    }

// Get map file data
    const inputMapPath = Path.join(ROOT, "map", "c12dsL2024.cos");
    /** @var {string[]} mapData */
    let mapData;
    try {
        mapData = fs
            .readFileSync(inputMapPath, "latin1")
            .split(/\r?\n/);
    } catch (e) {
        console.error("Failed to read map data from file: " + inputMapPath, "error: ", e);
        return false;
    }

// Build output file contents
    let out = "";
    const roomRegex = /\s+setv va00 addr va01 (\d+) (\d+) (\d+) (\d+) (\d+) (\d+)/ig;
    for (const line of mapData) {
        // Add line no matter what
        out += line + "\r\n";
        const match = roomRegex.exec(line);
        if (match == null) {
            continue;
        }
        // Read room points
        const [
            left,
            right,
            topLeft,
            topRight,
            bottomLeft,
            bottomRight
        ] = match.slice(1).map((v) => parseInt(v, 10));

        // Calculate room midpoint X
        const midX = Math.floor((left + right) / 2);

        // Calculate room midpoint Y
        const top = Math.max(topLeft, topRight);
        const bottom = Math.min(bottomLeft, bottomRight);
        const midY = Math.floor((bottom + top) / 2);

        // Add music to room midpoint
        out += `    rmsc ${midX} ${midY} "c1_music.mng\\\\c12ds"\r\n`;
    }

    try {
        fs.writeFileSync(outputMapFile, out, "latin1");
        return true;
    } catch (e) {
        const error = e instanceof Error ? e.message : e;
        console.error("Failed to write map file with music;" + (error.trim() ? (" Error: " + error.trim()) : ""));
        return false;
    }
}

module.exports = {
    getOutputMapFile,
    addMusicAndWriteMap,
}