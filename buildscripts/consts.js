// === CONFIG === //
const COMPILER_VERSION = "1.2.4";
const AGENT_NAME_PREFIX="C12DS-Lite"

// === Node Imports === //
const Path = require("node:path");
const {argv} = require("node:process");

// === Internal Variables === //
const ROOT = Path.join(__dirname, "..");
const mainCos = "0.0 - Main.cos";
const tempCAOSDirectory = Path.join(ROOT, ".tmp");
// CAOS Vars
const caos2PrayFilePath = Path.join(tempCAOSDirectory, ".caos2pray.cos");
const attachmentExtensions = [".c16", ".s16", ".blk", ".mng", ".wav", ".catalogue"];
// Joins
const useJoins = argv.find((arg) => arg.toLowerCase() === "--with-joins") != null;

const joins = [];
const warnings = [];

module.exports = {
    COMPILER_VERSION,
    AGENT_NAME_PREFIX,
    mainCos,
    tempCAOSDirectory,
    caos2PrayFilePath,
    attachmentExtensions,
    useJoins,
    joins,
    warnings,
    ROOT,
}