const {joins, useJoins} = require("./consts");
const {getStringLocation} = require("./util");
const {classifierData} = require("./caos-data");
const {basename} = require("path");

const badDepends = /^\s*[*]#\s*depend\s+"\/?([.]+\/)+[a-zA-Z0-9\\/]+\.[a-zA-Z]+"/gi;
const badClassifier = /(scrp|new:\s+[^ ]{4})\s+[23]\s+\d+\s+(?:[^6]|6[^5])\d*/gi;
const badLocationX = /(?:mvto|mvsf|mvft|va00)\s+(\d+)/gi;
const badLocationY = /(?:mvto|mvsf|mvft|va01)\s+\d+\s+(\d+)/gi;
const stimDisappointment = /stim\s+writ\s+[^ ]+\s+0/gi;
const scriptHeader = /scrp\s+\d+\s+\d+\s+\d+\s+\d+/gi;
const eatScriptHeader = /scrp\s+(\d+)\s+(\d+)\s+(\d+)\s+12\D/gim;
const newGenus = /new:\s+[^ ]+\s+(\d+)\s+(\d+)/gi;
const behaviorRegex = /bhvr\s+(\d+)/gi;
const doifC12DSLoaded = /doif\s+game\s+"C12DS_Loaded"\s+(eq|=)\s+1\s+and\s+totl/gim;
const hasEatScript = Object.keys(classifierData)
    .filter((genus) => (classifierData[genus].bhvr & 16) === 16);

function validate(fileRelative, rawContent, copy, warnings) {

    const localWarnings = [];
    const localErrors = [];
    let validationData = {
        rawContent: rawContent,
        contentLowercase: rawContent.toLowerCase().trim(),
        transformed: false,
        okay: true,
        errors: localErrors,
        warnings: localWarnings,
        fileRelative: fileRelative
    }

    // Add file to joins if needed
    if (useJoins && validationData.contentLowercase.indexOf("**caos2pray join") >= 0) {
        joins.push(fileRelative);
    }

    validateC12DSLoaded(validationData);
    validateClickableFood(validationData);
    validateClassifier(validationData);
    validateDepends(validationData);
    validateStimDisappointment(validationData);
    validateLocation(validationData);
    validateBehavior(validationData);
    shouldHaveEatScript(validationData);

    if (localWarnings.length) {
        warnings.push(basename(fileRelative) + "\n\t- " + localWarnings.join("\n\t- "));
    }

    if (localErrors.length) {
        console.error(basename(fileRelative) + "\n\t- " + localErrors.join("\n\t- "));
    }

    if (validationData.transformed) {
        copy(fileRelative, rawContent);
    }
    return validationData.okay;
}


function validateC12DSLoaded(validationData) {

    const {contentLowercase, rawContent, warnings, errors} = validationData;
    let okay = true;
    const dsLoadedIndex = contentLowercase.indexOf("doif game \"c1_to_ds_loaded\"");
    if (dsLoadedIndex >= 0) {
        const [locationString] = getStringLocation(contentLowercase, dsLoadedIndex);
        const message = "Incorrect `game \"C12DS_Loaded\"` encountered; Should Be game \"C12DS_Lite_Installing\" @ " + locationString + "\n\t    * Corrected in copy before compile *";
        let temp = rawContent.replaceAll(doifC12DSLoaded, "doif game \"C12DS_Lite_Installing\" = 1 and totl");
        if (temp !== rawContent) {
            warnings.push(message);
            validationData.transformed = true;
            validationData.rawContent = temp;
        } else {
            validationData.okay = false;
            okay = false;
            errors.push(message);
        }
    }
    return okay;
}

function validateClickableFood(validationData) {

    const {contentLowercase, rawContent, warnings} = validationData;
    let okay = true;
    const clickableFoodIndex = contentLowercase.indexOf("game \"c1_clickable_food\"");
    if (clickableFoodIndex >= 0) {
        const [locationString] = getStringLocation(contentLowercase, clickableFoodIndex);
        const message = "Incorrect `game \"C1_Clickable_Food\"` encountered; Should Be game \"C12DS_Lite_Clickable_Food\" @ " + locationString;
        let temp = rawContent.replaceAll(/game "c1_clickable_food"/gmi, "game \"C12DS_Lite_Clickable_Food\"");
        if (temp !== rawContent) {
            warnings.push(message);
            validationData.transformed = true;
            validationData.rawContent = temp;
        } else {
            validationData.okay = false;
            validationData.errors.push(message);
        }
    }
    return okay;
}

function validateClassifier(validationData) {
    const {contentLowercase} = validationData;
    let okay = true;
    for (const match of contentLowercase.matchAll(badClassifier)) {
        validationData.okay = false;
        const [locationString] = getStringLocation(contentLowercase, match.index);
        validationData.errors.push("Old C12DS classifier;. Found " + match[0] + " @ " + locationString);
        okay = false;
    }
    validationData.okay = validationData.okay && okay;
    return okay;
}

function validateDepends(validationData) {

    const {contentLowercase} = validationData;
    let okay = true;
    for (const match of contentLowercase.matchAll(badDepends)) {
        okay = false;
        const [locationString] = getStringLocation(contentLowercase, match.index);
        validationData.errors.push("Depend statements should be filename only not relative paths. Found " + match[0] + " @ " + locationString);
    }
    validationData.okay = validationData.okay && okay;
    return okay;
}

function validateStimDisappointment(validationData) {

    const {contentLowercase, warnings} = validationData;

    for (const match of contentLowercase.matchAll(stimDisappointment)) {
        const index = match.index;
        const scriptIndex = contentLowercase.substring(0, index).lastIndexOf("scrp");
        let script = "";
        if (scriptIndex >= 0) {
            const scriptTextUntil = contentLowercase.substring(scriptIndex, index);
            const scriptHead = scriptHeader.exec(scriptTextUntil);
            if (scriptHead) {
                script = " for " + scriptHead[0];
            }
        }
        const [locationString] = getStringLocation(contentLowercase, index);
        warnings.push("Agent stimming disappointment may be incorrect. Found " + match[0] + script + " @ " + locationString);
    }
}


function validateLocation(validationData) {
    validateLocationX(validationData);
    validateLocationY(validationData);
}

function validateLocationX(validationData) {
    const {contentLowercase, warnings} = validationData;

    for (const match of contentLowercase.matchAll(badLocationX)) {
        const [locationString] = getStringLocation(contentLowercase, match.index);
        try {
            const x = parseInt(match[1], 10);
            if (x > 6000 && x < 7000) {
                continue;
            }
            if (x > 5500) {
                warnings.push("Possibly invalid X value: " + match[0] + " @ " + locationString)
            }
        } catch (e) {
            console.error("Regex for X threw error; @ " + locationString, e);
        }
    }
}


function validateLocationY(validationData) {
    const {contentLowercase, fileRelative, warnings} = validationData;
    for (const match of contentLowercase.matchAll(badLocationY)) {
        const [locationString] = getStringLocation(contentLowercase, match.index);
        try {
            const y = parseInt(match[1], 10);
            if (y > 9100 && y < 9300) {
                continue;
            }
            if (y < 18000) {
                warnings.push("Possibly invalid Y value: " + match[0] + " @ " + locationString);
            }
        } catch (e) {
            console.error("Regex for Y threw error in " + basename(fileRelative)+ " @ " + locationString, e);
        }
    }
}


function validateBehavior(validationData) {
    const {contentLowercase, warnings} = validationData;
    const newOffsets = [...contentLowercase.matchAll(newGenus)];
    for (let i = 0; i < newOffsets.length; i++) {
        const match = newOffsets[i];
        const genus = match[1] + " " + match[2];
        if (typeof classifierData[genus] === "undefined") {
            continue;
        }
        const start = match.index;
        const end = i < (newOffsets.length - 1) ? newOffsets[i + 1].index : contentLowercase.length;
        let behaviorMatch = [...contentLowercase.substring(start, end).matchAll(behaviorRegex) ?? []];
        behaviorMatch = behaviorMatch ? behaviorMatch[0] : null;
        const behavior = behaviorMatch != null && behaviorMatch.length ? parseInt(behaviorMatch[1], 10) : null;
        if (behavior == null) {
            continue;
        }
        if (genus === "2 21" && behavior === 11) {
            // Allow toys to not be pickup-able
            continue;
        }
        if (classifierData[genus]?.bhvr !== behavior && behavior !== 0) {
            const [locationString] = getStringLocation(contentLowercase, match.index);
            warnings.push(
                "Possibly out of standards behavior: " + behavior +
                "; Expected: " + classifierData[genus].bhvr +
                " for genus " + genus + "(" + classifierData[genus].name + ")" +
                " in " + " @ " + locationString
            );
        }
    }
}

function shouldHaveEatScript(validationData) {
    for (const match of validationData.contentLowercase.matchAll(eatScriptHeader)) {
        const genus = match[1] + " " + match[2];
        if (typeof classifierData[genus] === "undefined") {
            continue;
        }
        if (hasEatScript.indexOf(genus) >= 0) {
            continue;
        }
        const location = getStringLocation(validationData.contentLowercase, match.index);
        validationData.warnings.push("Agent [" + genus + "  " + match[3] + "] of type " + classifierData[genus].name + " should not have eat script @ " + location);
    }
    return true;
}

module.exports = {
    validate
}