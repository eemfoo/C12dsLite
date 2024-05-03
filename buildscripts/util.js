
// ================= //
// ==== UTILITY ==== //
// ================= //

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


function getStringLocation(content, index) {
    const lines = content.substring(0, index).split("\n");
    const lineCount = lines.length
    const charIndex = (lines.pop() ?? "").length
    return [lineCount + ":" + charIndex, lines.length, charIndex];
}

module.exports = {
    formatTime,
    getStringLocation,
}