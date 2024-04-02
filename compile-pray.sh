#! /usr/bin/env node
// noinspection SpellCheckingInspection

const Path = require("node:path");
const fs = require("node:fs");
const { spawn } = require('node:child_process');
const https = require("https");
const { platform, arch } = require("node:process");


const mainCos = "0.0 - Main.cos";
const attachmentExtensions = [".c16", ".s16", ".blk", ".mng", ".wav"];

function linkCos(text, relativePath, prefixComment) {
	const path = Path.join(__dirname, relativePath);
    const files = fs.readdirSync(path);

    files.sort();

   	if (!files) {
   		return;
   	}

	if (prefixComment) {
		text.push(`* ${prefixComment}`);
	}

	for (file of files) {
		if (Path.extname(file).toLowerCase() !== ".cos") {
			continue;
		}
		if (file.toLowerCase() == mainCos.toLowerCase()) {
			continue;
		}
		if (file.toLowerCase().indexOf(mainCos.toLowerCase) >= 0) {
			continue;
		}
		file = Path.join(relativePath, file);
		text.push(`*# Link \"${file}\"`);
	}
}

function attachFilesIn(text, relativePath, prefixComment) {
	const path = Path.join(__dirname, relativePath);
    const files = fs.readdirSync(path);

   	if (!files) {
   		return;
   	}

	if (prefixComment) {
		text.push(`* ${prefixComment}`);
	}

	for (file of files) {
		if (attachmentExtensions.indexOf(Path.extname(file).toLowerCase()) < 0) {
			continue;
		}
		file = Path.join(relativePath, file);
		text.push(`*# Attach \"${file}\"`);
	}
}


function buildCAOSFile() {

	let text = [];

	try {
		text.push(fs.readFileSync(Path.join(__dirname, "cos", mainCos), "latin1"));
	} catch (e) {
		console.error("Failed to read 0.0 - Main.cos file for CAOS2Pray headers");
		process.exit(1);
	}

	linkCos(text, "cos", "CAOS Scripts");

	attachFilesIn(text, "images", "Images");
	text.push("*# Attach \"map/c12dsl.blk\"")
	attachFilesIn(text, "sounds", "Sound Files");

	const filename = Path.join(__dirname, ".caos2pray.cos");
	fs.writeFileSync(filename, text.join("\n"));
	return filename;
}

function get(url) {
	return new Promise((resolve, reject) => {
		_get(url, resolve, reject);
	});
}

function _get(url, resolve, reject) {
	https.get(url, (res) => {
		// if any other status codes are returned, those needed to be added here
		if(res.statusCode === 301 || res.statusCode === 302) {
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
async function download(url, destination) {
	return new Promise(async (resolve, reject) => {
		const data = await get(url);
		fs.writeFileSync(destination, data);
		fs.chmodSync(destination, 0755);
		resolve(destination);
	});
}

function getBinaryError(binary) {
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
	return null;
}

async function getCompiler() {
	const dir = Path.join(__dirname, "bin");
	if (!fs.existsSync(dir)) {
		fs.mkdirSync(dir);
	}
	const ext = platform === "win32" ? ".exe" : "";
	const binary = Path.join(dir,  "agent-util" + ext);
	let binaryError = getBinaryError(binary);
	if (!binaryError) {
		return Promise.resolve(binary);
	}
	let exe;
	switch (platform.toLowerCase()) {
		case "darwin":
			exe = arch === "arm" ?
				"https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/1.1.0/Kotlin-Native/MacOS-arm64/agent-util-macos-arm64" :
				"https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/1.1.0/Kotlin-Native/MacOS-x64/agent-util-macos-x64";
			break;
		case "win32":
		case "win64":
			exe = "https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/1.1.0/Kotlin-Native/Windows-x64/agent-util-win-x64.exe";
			break;
		default:
			exe = arch === "arm" ?
				"https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/1.1.0/Kotlin-Native/Linux-arm64/agent-util-linux-arm64" :
				"https://github.com/bedalton/CreatureBinaries/raw/main/agent-util/1.1.0/Kotlin-Native/Linux-x64/agent-util-linux-x64";
			break;
	}

	console.log("Downloading: " + exe);
	return new Promise(async (resolve, reject) => {
		download(exe, binary)
		.then(() => {
			binaryError = getBinaryError();
			if (binaryError) {
				console.error("Failed to download: " + exe + "; Error: " + binaryError);
//				fs.unlinkSync(binary);
				reject(binaryError);
				return;
			} else {
				console.log("Downloaded: " + exe);
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


async function compile() {
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

		const filename = buildCAOSFile();

		let child;
		 try {
		 	child = spawn(exe, ["compile", filename]);
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

compile()
	.then((code) =>{
		if (code == 0) {
			console.info("Compiled agent successfully");
		} else {
			console.error("An error was encountered");
		}
		process.exit(code)
	})
	.catch((e) => {
		const error = e instanceof Error ? e.message : e;
		console.error("Compile agent failed; " + error);
		process.exit(1);
	});