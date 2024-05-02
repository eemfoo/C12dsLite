#! /usr/bin/env node
// noinspection SpellCheckingInspection

const version = "1.2.4";

// Node libararies
const Path = require("node:path");
const fs = require("node:fs");
const {spawn} = require('node:child_process');
const https = require("node:https");
const {platform, arch, exit: _exitProcess, argv} = require("node:process");

// ============== //
// ==== CAOS ==== //
// ============== //

const trueStart = Date.now();

// CAOS Vars
const caos2PrayFilePath = Path.join(__dirname, ".caos2pray.cos");
let outputMapFile = null;
const attachmentExtensions = [".c16", ".s16", ".blk", ".mng", ".wav", ".catalogue"];
const mainCos = "0.0 - Main.cos";
// Joins
const useJoins = argv.find((arg) => arg.toLowerCase() === "--with-joins") != null;
const joins = [];
const badDepends = /^\s*[*]#\s*depend\s+"\/?([.]+\/)+[a-zA-Z0-9\\/]+\.[a-zA-Z]+"/gi
const badClassifier = /(scrp|new:\s+[^ ]{4})\s+[23]\s+\d+\s+(?:[^6]|6[^5])\d*/gi;
const badLocationX = /(?:mvto|mvsf|mvft|va00)\s+(\d+)/gi
const badLocationY = /(?:mvto|mvsf|mvft|va01)\s+\d+\s+(\d+)/gi
const stimDisapointment = /stim\s+writ\s+[^ ]+\s+0/gi
const scriptHeader = /scrp\s+\d+\s+\d+\s+\d+\s+\d+/gi
const newGenus = /new:\s+[^ ]+\s+(\d+)\s+(\d+)/gi
const behaviorRegex = /bhvr\s+(\d+)/gi
let warning = "";


const behaviorStandards = {
    "2 2": 3, // Dopr
    "2 3": 48, // Seed
    "2 4": 11, // GoodPlant
    "2 5": 11, // BadPlant
    "2 6": 48, // Leaf
    "2 7": 0, //flower
    "2 8": 48, // Good Fruit
    "2 9": 48, // Bad Fruit
    "2 10": 48, // Detritus
    "2 11": 48, // Food
    "2 12": 48, // Buttons and Switches
    "2 13": 59, // Good Bug
    "2 14": 59, // Bad Bug
    "2 15": 59, // Good Critter
    "2 16": 11, // Bad critter
    "2 17": 11, // Nest
    "2 18": 48, // Agent Egg
    "2 19": 0, // Weather
    "2 20": 43, //BAD
    "2 21": 43, //Toy
    "2 22": 0, // Incubator
    "2 23": 11, // Vendors
    "2 24": 43, // tools
    "2 25": 48, // Potions
    "3 1": 3, // Lifts
    "3 2": 3, // Teleporters
    "3 3": 11, //Machinery (Fixed Non Moveable)
    "3 4": 32, // Creature egg
    "3 5": 0, //Norn Home
    "3 6": 0, // Grendel Home
    "3 7": 0, // Ettin Home
    "3 8": 43, // Gadgets
    "3 9": 3, // Portals
    "3 10": 0, // Vehicles
}


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

    let okay = true
    for (const file of files) {
        if (Path.extname(file).toLowerCase() !== ".cos") {
            continue;
        }
        if (file.toLowerCase().indexOf("99.0") >= 0) {
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

        if (fileRelative.toLowerCase().endsWith(" map.cos")) {
            continue;
        }

        const content = fs.readFileSync(Path.join(__dirname, fileRelative), "latin1").toLowerCase().trim();
        if (useJoins && content.indexOf("**caos2pray join") >= 0) {
            joins.push(fileRelative);
        }

        const dsLoadedIndex = content.indexOf("game \"c1_to_ds_loaded\"");
        if (dsLoadedIndex >= 0) {
            okay = false
            const [locationString] = getStringLocation(content, dsLoadedIndex);
            console.error("Incorrect `game \"C1_to_DS_Loaded\"` encountered in " + fileRelative + "; Should Be game \"C1_to_DS_Lite_Loaded\" @ " + locationString);
        }

        const clickableFoodIndex = content.indexOf("game \"c1_clickable_food\"");
        if (clickableFoodIndex >= 0) {
            okay = false
            const [locationString] = getStringLocation(content, clickableFoodIndex);
            console.error("Incorrect `game \"C1_Clickable_Food\"` encountered in " + fileRelative + "; Should Be game \"C1_to_DS_Clickable_Food\" @ " + locationString);
        }

        for (const match of content.matchAll(badClassifier)) {
            okay = false;
            const [locationString] = getStringLocation(content, match.index);
            console.error("Old C12DS classifier;. Found " + match[0] + " in " + fileRelative + " @ " + locationString);
        }

        for (const match of content.matchAll(badDepends)) {
            okay = false;
            const [locationString] = getStringLocation(content, match.index);
            console.error("Depend statements should be filename only not relative paths. Found " + match[0] + " in " + fileRelative + " @ " + locationString);
        }

        for (const match of content.matchAll(stimDisapointment)) {
            const index = match.index;
            const scriptIndex = content.substring(0, index).lastIndexOf("scrp");
            let script = "";
            if (scriptIndex >= 0) {
                const scriptTextUntil = content.substring(scriptIndex, index);
                const scriptHead = scriptHeader.exec(scriptTextUntil);
                if (scriptHead) {
                    script = " for " + scriptHead[0];
                }
            }
            const [locationString] = getStringLocation(content, index);
            warning += ("Agent stimming disappointment may be incorrect. Found " + match[0] + script + " in " + fileRelative) + " @ " + locationString + "\n";
        }

        for (const match of content.matchAll(badLocationX)) {
            const [locationString] = getStringLocation(content, match.index);
            try {
                const x = parseInt(match[1], 10);
                if (x > 6000 && x < 7000) {
                    continue;
                }
                if (x > 5500) {
                    warning += ("Possibly invalid X value: " + match[0] + " in " + fileRelative) + " @ " + locationString + "\n";
                }
            } catch (e) {
                console.error("Regex for X threw error; @ " + locationString, e);
            }
        }

        for (const match of content.matchAll(badLocationY)) {
            const [locationString] = getStringLocation(content, match.index);
            try {
                const y = parseInt(match[1], 10);
                if (y > 9100 && y < 9300) {
                    continue;
                }
                if (y < 18000) {
                    warning += ("Possibly invalid Y value: " + match[0] + " in " + fileRelative) + " @ " + locationString + "\n";
                }
            } catch (e) {
                console.error("Regex for Y threw error; @ " + locationString, e);
            }
        }

        const newOffsets = [...content.matchAll(newGenus)];
        for (let i = 0; i < newOffsets.length; i++) {
            const match = newOffsets[i];
            const genus = match[1] + " " + match[2];
            if (typeof behaviorStandards[genus] === "undefined") {
                continue;
            }
            const start = match.index;
            const end = i < (newOffsets.length - 1) ? newOffsets[i + 1].index : content.length;
            let behaviorMatch = [...content.substring(start, end).matchAll(behaviorRegex) ?? []];
            behaviorMatch = behaviorMatch ? behaviorMatch[0] : null;
            const behavior = behaviorMatch != null && behaviorMatch.length ? parseInt(behaviorMatch[1], 10) : null;
            if (behavior == null) {
                continue;
            }
            if (genus === "2 21" && behavior === 11) {
                // Allow toys to not be pickupable
                continue;
            }
            if (behaviorStandards[genus] !== behavior && behavior !== 0) {
                const [locationString] = getStringLocation(content, match.index);
                warning += "Possibly out of standards behavior: " + behavior + "; Expected: " + behaviorStandards[genus] + " for genus " + genus + " in " + fileRelative + " @ " + locationString + "\n";
            }
        }
    }
    if (!okay) {
        exitProcess(1);
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
        text.push(`*# Attach \"${file}\"`);
    }
}

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
        console.error("Failed to write map file with music;" + (error.trim() ? (" Error: " + error.trim()) : ""));
        return false;
    }
}

/**
 * Builds and writes the CAOS file and returns the path to it
 * @returns {string} path to generated CAOS2Pray file
 */
function buildCAOSFile() {

    // CAOS2Pray/comment statements array
    let text = [];

    // Output text
    let body;

    // Read Main.cos
    try {
        body = fs.readFileSync(Path.join(__dirname, "cos", mainCos), "latin1");
    } catch (e) {
        console.error("Failed to read 0.0 - Main.cos file for CAOS2Pray headers");
        exitProcess(1);
    }

    // Add misic to map and write generated file
    const wroteMap = addMusicAndWriteMap();
    if (!wroteMap) {
        console.error("Map failure");
        exitProcess(1);
    }

    // Link CAOS scripts
    linkCos(text, "cos", "* CAOS Scripts");

    // Attach Catalogues
    attachFilesIn(text, "catalogue", "Catalogues");

    // Attach Images
    attachFilesIn(text, "images", "Images");
    text.push("*# Attach \"map/c12dsl.blk\"")

    // Attach Sounds
    attachFilesIn(text, "sounds", "Sound Files");

    // Add Joins if any
    if (useJoins) {
        text = text.concat(joins.map((file) => "*# Join \"" + file + "\""));
    }

    // Insert CAOS2Pray statements into Main.cos
    body = body.replace("* {}", text.join("\n"));

    // Write generated CAOS2Pray file
    fs.writeFileSync(caos2PrayFilePath, body);
}

// =================== //
// ==== DOWNLOAD ==== //
// =================== //

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


// ================ //
// ==== BINARY ==== //
// ================ //

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
                    fs.writeFileSync(versionTextFilePath + ".tmp", "" + version, "utf-8");
                } catch {
                    console.error("Failed to write version.txt; Please create it manually in the ./bin/version.txt; with content: " + version);
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


// ================= //
// ==== UTILITY ==== //
// ================= //

/**
 * Exit the script with code, cleaning up as needed
 * @param code
 */
function exitProcess(code) {
    cleanTemporaryFiles(code !== 0);
    _exitProcess(code);
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

/**
 * Deletes the temporary CAOS files generated during compile
 */
function cleanTemporaryFiles(keepPray = false) {
    try {
        if (outputMapFile) {
            fs.rmSync(outputMapFile);
        }
    } catch {
    }

    try {
        if (!keepPray && fs.existsSync(caos2PrayFilePath)) {
            fs.rmSync(caos2PrayFilePath);
        }
    } catch {
    }
}

function getStringLocation(content, index) {
    const lines = content.substring(0, index).split("\n");
    const lineCount = lines.length
    const charIndex = (lines.pop() ?? "").length
    return [lineCount + ":" + charIndex, lines.length, charIndex];
}

// ================= //
// ==== COMPILE ==== //
// ================= //

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

        const compilerArgs = ["compile", caos2PrayFilePath, "-o", __dirname];
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
                const now = Date.now();
                const compileTimeString = formatTime(now - time);
                const timeString = formatTime(now - trueStart);
                if (warning) {
                    const bar = "===================================";
                    let head = "Validation Warnings"
                    let padLength = (bar.length - (head.length + 2)) / 2;
                    head = "=".repeat(padLength) + " " + head + " " + "=".repeat(padLength);
                    console.warn(bar + "\n" + head + "\n" + warning.trim() + "\n" + bar);
                }
                if (compileTimeString === timeString) {
                    console.info("Compiled agent successfully in " + timeString);
                } else {
                    console.info("Compiled agent successfully in " + timeString + "; Time in compiler: " + compileTimeString);
                }
            } else {
                console.error("An error was encountered");
            }
            return code
        })
        .catch((e) => {
            const error = e instanceof Error ? e.message : e;
            console.error("Compile agent failed; " + error);
            return 1;
        })
        .then((code) => {
            exitProcess(code)
        })
}

// ================= //
// ====== RUN ====== //
// ================= //

// Call compiler
compile();