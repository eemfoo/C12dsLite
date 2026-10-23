
// ================ //
// ==== BINARY ==== //
// ================ //

const fs = require("node:fs");
const Path = require("node:path");
const {COMPILER_VERSION, ROOT} = require("./consts");
const {arch, platform} = require("node:process");
const {download} = require("./download");

/**
 * Returns an error message describing a problem with the agent compiler binary; Returns null if okay
 * @param {string} binary path to agent-compiler binary
 * @param {string} versionTextFilePath path to version.txt file
 * @returns {null|string}
 */
function getBinaryError(binary, versionTextFilePath) {
    if (!fs.existsSync(binary)) {
        return "Binary file failed to download";
    }
    const stats = fs.lstatSync(binary);
    const fileSize = stats.size;
    if (fileSize === 0) {
        return "File failed to download any bytes";
    }
    if (fileSize < 3500000) {
        return "Incomplete file download";
    }

    let currentVersion;
    try {
        currentVersion = fs.existsSync(versionTextFilePath)
            ? fs.readFileSync(versionTextFilePath, "utf-8")
            : ""
    } catch {
        currentVersion = "";
    }
    if (currentVersion.trim() !== COMPILER_VERSION) {
        return "Compiler version out of date";
    }
    return null;
}

/**
 * Gets the path to the agent compiler, downloading if necessary
 * @returns {Promise<string>} path to the agent compiler binary
 */
async function getCompiler() {
    const dir = Path.join(ROOT, "bin");
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir);
    }

    // Get the target extension for the binary
    const ext = platform === "win32" ? ".exe" : "";

    // Get the final path for the binary
    const binary = Path.join(dir, "agent-util" + ext);

    // Get the path to the versions.txt file
    const versionTextFilePath = Path.join(dir, "version.txt");

    // Get errors if any on the binary
    // Will return null if binary exists and is correct version
    let binaryError = getBinaryError(binary, versionTextFilePath);

    // If binary exists and is the correct version resolve and return immediately
    if (!binaryError) {
        return Promise.resolve(binary);
    }


    // Get GitHub path for the binary based on OS and CPU architecture
    let exe;
    switch (platform.toLowerCase()) {
        case "darwin":
            exe = arch === "arm64" ?
                `https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/${COMPILER_VERSION}/Kotlin-Native/macos-arm64/agent-util` :
                `https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/${COMPILER_VERSION}/Kotlin-Native/macos-x64/agent-util`;
            break;
        case "win32":
        case "win64":
            exe = `https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/${COMPILER_VERSION}/Kotlin-Native/windows-x64/agent-util.exe`;
            break;
        default:
            exe = arch === "arm64" ?
                `https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/${COMPILER_VERSION}/Kotlin-Native/linux-arm64/agent-util` :
                `https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/${COMPILER_VERSION}/Kotlin-Native/linux-x64/agent-util`;
            break;
    }


    // Actually download the file
    return new Promise(async (resolve, reject) => {
        console.log("Downloading: " + exe);
        download(exe, binary)
            .then((destination) => {
                try {
                    fs.writeFileSync(versionTextFilePath + ".tmp", "" + COMPILER_VERSION, "utf-8");
                } catch {
                    console.error("Failed to write version.txt; Please create it manually in the ./bin/version.txt; with content: " + COMPILER_VERSION);
                }
                return destination;
            })
            .then((destination) => {
                binaryError = getBinaryError(destination, versionTextFilePath + ".tmp");
                if (binaryError) {
                    fs.rmSync(versionTextFilePath + ".tmp")
                    console.error("Failed to download: " + exe + "; Error: " + binaryError);
                    reject(binaryError);
                } else {
                    if (fs.existsSync(versionTextFilePath)) {
                        fs.rmSync(versionTextFilePath);
                    }
                    fs.renameSync(versionTextFilePath + ".tmp", versionTextFilePath);
                    resolve(binary);
                }
            })
            .catch((e) => {
                console.error(e);
//			fs.unlinkSync(binary);
                reject(e);
            });
    });

}


module.exports = {
    getCompiler,
}