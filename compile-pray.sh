#! /usr/bin/env node
// noinspection SpellCheckingInspection

const version = "1.2.1";

const Path = require("node:path");
const fs = require("node:fs");
const {spawn} = require('node:child_process');
const https = require("node:https");
const {platform, arch, exit: exitProcess, argv} = require("node:process");


const mainCos = "0.0 - Main.cos";
const attachmentExtensions = [".c16", ".s16", ".blk", ".mng", ".wav"];

const joins = [];

/**
 * Adds link statements for all CAOS files in relative path
 * @param {string[]} text array of CAOS2Pray and comment lines
 * @param {string} relativePath the path relative to root for linking CAOS
 * @param {string|null|undefined} prefixComment comment to insert before CAOS2Pray lines
 */
function linkCos(text, relativePath, prefixComment = null) {
    const path = Path.join(__dirname, relativePath);
    const files = fs.readdirSync(path);

    files.sort();

    if (!files) {
        return;
    }

    if (prefixComment) {
        text.push(`* ${prefixComment}`);
    }

    for (const file of files) {
        if (Path.extname(file).toLowerCase() !== ".cos") {
            continue;
        }
        if (file.toLowerCase() === mainCos.toLowerCase()) {
            continue;
        }
        if (file.toLowerCase().indexOf(mainCos.toLowerCase()) >= 0) {
            continue;
        }

        const fileRelative = Path.join(relativePath, file);
        text.push(`*# Link \"${fileRelative}\"`);

        const content = fs.readFileSync(Path.join(__dirname, fileRelative), "latin1").toLowerCase().trim();
        if (content.indexOf("**caos2pray join") >= 0) {
            joins.push(fileRelative);
        }

    }
}

/**
 * Adds attachment CAOS2Pray statements for all files in relative path
 * @param {string[]} text array of CAOS2Pray and comment lines
 * @param {string} relativePath the path relative to root for linking CAOS
 * @param {string|null|undefined} prefixComment comment to insert before CAOS2Pray lines
 */
function attachFilesIn(text, relativePath, prefixComment) {
    const path = Path.join(__dirname, relativePath);
    const files = fs.readdirSync(path);

    if (!files) {
        return;
    }

    if (prefixComment) {
        text.push(`* ${prefixComment}`);
    }

    for (let file of files) {
        if (attachmentExtensions.indexOf(Path.extname(file).toLowerCase()) < 0) {
            continue;
        }
        file = Path.join(relativePath, file);
        text.push(`*# Attach \"${file}\"`);
    }
}


const caos2PrayFilePath = Path.join(__dirname, ".caos2pray.cos");
/**
 * Builds and writes the CAOS file and returns the path to it
 * @returns {string} path to generated CAOS2Pray file
 */
function buildCAOSFile() {

    let text = [];

    let body;

    try {
        body = fs.readFileSync(Path.join(__dirname, "cos", mainCos), "latin1");
    } catch (e) {
        console.error("Failed to read 0.0 - Main.cos file for CAOS2Pray headers");
        process.exit(1);
    }

    const wroteMap = addMusicAndWriteMap();
    if (!wroteMap) {
        console.error("Map failure");
        process.exit(1);
    }

    linkCos(text, "cos", "* CAOS Scripts");

    attachFilesIn(text, "images", "Images");
    text.push("*# Attach \"map/c12dsl.blk\"")
    attachFilesIn(text, "sounds", "Sound Files");

    text = text.concat(joins.map((file) => "*# Join \"" + file + "\""));

    body = body.replace("* {}", text.join("\n"));

    fs.writeFileSync(caos2PrayFilePath, body);
}

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
    if (fileSize < 8000000) {
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
    if (currentVersion.trim() !== version) {
        return "Compiler version out of date";
    }
    return null;
}

/**
 * Gets the path to the agent compiler, downloading if necessary
 * @returns {Promise<string>} path to the agent compiler binary
 */
async function getCompiler() {
    const dir = Path.join(__dirname, "bin");
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
            exe = arch === "arm" ?
                `https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/${version}/Kotlin-Native/macos-arm64/agent-util` :
                `https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/${version}/Kotlin-Native/macos-x64/agent-util`;
            break;
        case "win32":
        case "win64":
            exe = `https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/${version}/Kotlin-Native/windows-x64/agent-util.exe`;
            break;
        default:
            exe = arch === "arm" ?
                `https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/${version}/Kotlin-Native/linux-arm64/agent-util` :
                `https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/${version}/Kotlin-Native/linux-x64/agent-util`;
            break;
    }


    // Actually download the file
    return new Promise(async (resolve, reject) => {
        console.log("Downloading: " + exe);
        download(exe, binary)
            .then((destination) => {
                try {
                    fs.writeFileSync(versionTextFilePath, "" + version, "utf-8");
                } catch {
                    console.error("Failed to write version.txt; Please create it manually in the ./bin/version.txt; with content: " + version);
                }
                return destination;
            })
            .then((destination) => {
                binaryError = getBinaryError(destination, versionTextFilePath);
                if (binaryError) {
                    console.error("Failed to download: " + exe + "; Error: " + binaryError);
                    reject(binaryError);
                } else {
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


/**
 * Formats duration into minutes and seconds
 * @param {number} time
 * @returns {string}
 */
function formatTime(time) {
    const duration = time / 1000.0;
    const minutes = Math.floor(duration / 60.0);
    const seconds = duration - (minutes * 60);
    let timeString = minutes ? (minutes + "m ") : "";
    if (seconds > 0) {
        timeString += seconds + "s ";
    }
    return timeString;
}


let outputMapFile = null;
/**
 * Adds music to the map file, and writes it to the ./cos subdirectory
 * @returns {boolean} true if map file is written
 */
const addMusicAndWriteMap = function () {

// Output
    const outputFileName = "0.01 - DO_NOT_EDIT - MAP.cos";
    outputMapFile = Path.join(__dirname, "cos", outputFileName);

    if (fs.existsSync(outputMapFile)) {
        try {
            fs.rmSync(outputMapFile);
        } catch {
            // ignore
        }
    }

// Get map file data
    const inputMapPath = Path.join(__dirname, "map", "c12dsL2024.cos");
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
        console.error("Failed to write map file with music;" + (e.trim() ? (" Error: " + e.trim()) : ""));
        return false;
    }
}

/**
 * Compile agent and get compiler exit code
 * @returns {Promise<number>} compiler exit code
 */
async function _compile() {
    return new Promise(async (resolve, reject) => {

        let exe;
        try {
            exe = await getCompiler();
        } catch (e) {
            console.error(e);
            reject(e);
        }

        if (exe == null) {
            console.error("Failed to get agent-util binary for compile");
            resolve(1);
            return;
        }

        buildCAOSFile();

        const compilerArgs = ["compile", caos2PrayFilePath]
        const debug = argv.find((arg) => arg.toLowerCase() === "--debug") != null;
        if (debug) {
            compilerArgs.push("--debug");
        }


        let child;
        try {
            console.log("Compiling agent...");
            child = spawn(exe, compilerArgs);
        } catch (e) {
//		 	fs.rmSync(exe, exe + ".broken");
            reject(e);
        }

        // use child.stdout.setEncoding('utf8'); if you want text chunks
        child.stdout.on('data', (chunk) => {
            console.log(chunk.toString());
        });

        child.on('close', (code) => {
            resolve(code);
        });
    });
}

/**
 * Compile agent and log result
 */
function compile() {
    let time = Date.now();
    _compile()
        .then((code) => {
            if (code === 0) {
                const timeString = formatTime(Date.now() - time);
                console.info("Compiled agent successfully in " + timeString);
                try {
                    if (outputMapFile) {
                        fs.rmSync(outputMapFile);
                    }
                    if (fs.existsSync(caos2PrayFilePath)) {
                        fs.rmSync(caos2PrayFilePath);
                    }
                } catch {
                    // ignore
                }
            } else {
                console.error("An error was encountered");
            }
            exitProcess(code)
        })
        .catch((e) => {
            const error = e instanceof Error ? e.message : e;
            console.error("Compile agent failed; " + error);
            exitProcess(1);
        });
}


// Call compiler
compile();