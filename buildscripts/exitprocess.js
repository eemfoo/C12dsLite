const fs = require("node:fs");
const Path = require("node:path");
const {exit: _exitProcess} = require("node:process");
const {caos2PrayFilePath, tempCAOSDirectory} = require("./consts");
const {getOutputMapFile} = require("./mapfile");

/**
 * Deletes the temporary CAOS files generated during compile
 */
function cleanTemporaryFiles(keepPray = false) {

    if ((process.argv ?? []).indexOf("--no-clean") >= 0) {
        return;
    }

    try {
        deleteTempCaosFiles();
    } catch (e) {
        console.error("Failed to remove all files from temp directory");
    }

}

function deleteTempCaosFiles() {
    const files = fs.readdirSync(tempCAOSDirectory);
    let removedAll = true;
    for (let file of files) {
        if (!Path.isAbsolute(file)) {
            file = Path.join(tempCAOSDirectory, file);
        }
        try {
            fs.rmSync(file);
        } catch (e) {
            removedAll = false;
            console.error("Failed to remove file: " + file);
        }
    }
    if (removedAll) {
        fs.rmdirSync(tempCAOSDirectory);
    }
}

/**
 * Exit the script with code, cleaning up as needed
 * @param code
 */
function exitProcess(code) {
    // cleanTemporaryFiles(code !== 0);
    _exitProcess(code);
}


module.exports = {
    exitProcess
}