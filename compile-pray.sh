#! /usr/bin/env node
// noinspection SpellCheckingInspection

// Node libararies
const Path = require("node:path");
const os = require("node:os");
const fs = require("node:fs");
const {spawn, execSync} = require('node:child_process');
const {argv} = require("node:process");
const {linkCos} = require("./buildscripts/link-caos");
const {attachFilesIn} = require("./buildscripts/attach");
const {useJoins, caos2PrayFilePath, mainCos, joins, warnings, tempCAOSDirectory} = require("./buildscripts/consts");
const {exitProcess} = require("./buildscripts/exitprocess");
const {addMusicAndWriteMap} = require("./buildscripts/mapfile");
const {getCompiler} = require("./buildscripts/binary");
const {formatTime} = require("./buildscripts/util");

// ============== //
// ==== CAOS ==== //
// ============== //

const trueStart = Date.now();

/**
 * Builds and writes the CAOS file and returns the path to it
 * @returns {string} path to generated CAOS2Pray file
 */
function buildCAOSFile() {

    if (!fs.existsSync(tempCAOSDirectory)) {
        fs.mkdirSync(tempCAOSDirectory);
    }

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
    text.push("*# Attach \"../map/c12dsl.blk\"")

    // Attach Sounds
    attachFilesIn(text, "sounds", "Sound Files");

    // Add Joins if any
    if (useJoins) {
        text = text.concat(joins.map((file) => "*# Join \"" + file.split(/[\\\/]/).pop() + "\""));
    }

    // Insert CAOS2Pray statements into Main.cos
    body = body.replace("* {}", text.join("\n"));

    // Write generated CAOS2Pray file
    fs.writeFileSync(caos2PrayFilePath, body);
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

        // Capture error output (stderr)
        child.stderr.on('data', (chunk) => {
            console.log(chunk.toString());
        });

        // Handle spawn errors (e.g., command not found)
        child.on('error', (err) => {
            console.error(err.message);
        });

       child.on('close', (code) => {
           resolve(code);
       });
    });
}

function postBuild() {

    let script = Path.join(__dirname, "postbuild.sh");
    if (os.platform() === "win32") {
        let script = Path.join(__dirname, "postbuild.bat");
    }

    if (fs.existsSync(script)) {
        try {
            execSync(script);
        } catch (e) {
            console.error("Failed to run post build step; " + e);
            return 1;
        }
    }
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
                if (warnings.length) {
                    const maxWarningLength = Math.max(...warnings.map(w => w.length), 35);
                    const bar = "=".repeat(maxWarningLength);
                    let head = "Validation Warnings"
                    let padLength = (bar.length - (head.length + 2)) / 2;
                    head = "=".repeat(padLength) + " " + head + " " + "=".repeat(padLength);
                    console.warn(bar + "\n" + head + "\n" + warnings.join("\n").trim() + "\n" + bar);
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
            postBuild();
            exitProcess(code)
        })
}

// ================= //
// ====== RUN ====== //
// ================= //

// Call compiler
compile();
