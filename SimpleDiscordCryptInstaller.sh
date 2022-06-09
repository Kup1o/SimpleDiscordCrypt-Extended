#!/bin/sh

# Setup JavaScript files into a working folder
touch /usr/share/SimpleDiscordCrypt/SimpleDiscordCryptLoader.js /usr/share/SimpleDiscordCrypt/NodeLoad.js

echo 'const onHeadersReceived = (details, callback) => { // SDCEx Hook headers to disable CSP blocking. This might be a security issue, because you can then send requests to everywhere you want?
	let response = { cancel: false };
	let responseHeaders = details.responseHeaders;
	if(responseHeaders['content-security-policy'] != null) {
		responseHeaders['content-security-policy'] = [""];
		response.responseHeaders = responseHeaders;
	}
	callback(response);
};

let originalBrowserWindow;
function browserWindowHook(options) {
	if(options?.webPreferences?.preload != null && options.title?.startsWith("Discord")) {
		let webPreferences = options.webPreferences;
		let originalPreload = webPreferences.preload;
		webPreferences.preload = `${__dirname}/SimpleDiscordCryptLoader.js`;
		webPreferences.additionalArguments = [...(webPreferences.additionalArguments || []), `--sdc-preload=${originalPreload}`];
	}
	return new originalBrowserWindow(options);
}
browserWindowHook.ISHOOK = true;


let originalElectronBinding;
function electronBindingHook(name) {
	let result = originalElectronBinding.apply(this, arguments);

	if(name === 'electron_browser_window' && !result.BrowserWindow.ISHOOK) {
		originalBrowserWindow = result.BrowserWindow;
		Object.assign(browserWindowHook, originalBrowserWindow);
		browserWindowHook.prototype = originalBrowserWindow.prototype;
		result.BrowserWindow = browserWindowHook;
		const electron = require('electron');

		electron.ipcMain.on("SDCExMessageDialog", (event, arg) => { // SDCEx - Receive message dialog that informs about updates
            event.returnValue = electron.dialog.showMessageBoxSync(null, arg);
        });
		electron.app.whenReady().then(() => { electron.session.defaultSession.webRequest.onHeadersReceived(onHeadersReceived) });
	}
	
	return result;
}
electronBindingHook.ISHOOK = true;

originalElectronBinding = process._linkedBinding;
if(originalElectronBinding.ISHOOK) return;
Object.assign(electronBindingHook, originalElectronBinding);
electronBindingHook.prototype = originalElectronBinding.prototype;
process._linkedBinding = electronBindingHook;' > /usr/share/SimpleDiscordCrypt/NodeLoad.js

echo 'let requireGrab = require;
if (requireGrab != null) {
	const require = requireGrab;

	if(window.chrome?.storage) delete chrome.storage;

	const localStorage = window.localStorage;
	const CspDisarmed = true;

	// SDCEx Manual Updates. Why should you trust a service not to steal your keys?
	var tempDlHelper = window.tempDlHelper = {
		updateInfoName: "SimpleDiscordCryptExUpdateInfo",
		https: require("https"),
		electronObj: require("electron"),
		latestVersion: 0,
		cachedObject: null,
		finalEval: function(jsCode) {
			const unsafeWindow = tempDlHelper.electronObj.webFrame.top.context; // Expose an unsafeWindow, so that SDC can work with it
			eval(jsCode);
		},
		downloadAndEval: function () {
			tempDlHelper.https.get(`https://raw.githubusercontent.com/Ceiridge/SimpleDiscordCrypt-Extended/${encodeURIComponent(tempDlHelper.latestVersion)}/SimpleDiscordCrypt.user.js`, {
				headers: {
					"User-Agent": navigator.userAgent // A User-Agent is recommended
				}
			}, (response) => {
				response.setEncoding('utf8');
				let data = "";
				response.on('data', (chunk) => data += chunk);
				response.on('end', async () => {
					tempDlHelper.updateUpdateObject("savedScript", data); // Save current version of the script
					tempDlHelper.updateUpdateObject("version", tempDlHelper.latestVersion);
					tempDlHelper.finish();

					tempDlHelper.finalEval(data);
				});
			});
		},
		updateUpdateObject: function (key, value) {
			let dbObj = JSON.parse(localStorage.getItem(tempDlHelper.updateInfoName)); // Localstorage can only store strings
			dbObj[key] = value;
			localStorage.setItem(tempDlHelper.updateInfoName, JSON.stringify(dbObj));
		},
		getLatestVersion: function () {
			return new Promise(resolve => {
				tempDlHelper.https.get("https://api.github.com/repos/Ceiridge/SimpleDiscordCrypt-Extended/git/refs/heads/master", {
					headers: {
						"User-Agent": navigator.userAgent // Needs a User-Agent
					}
				}, response => {
					response.setEncoding("utf8");
					let data = "";
					response.on('data', (chunk) => data += chunk);
					response.on('end', () => {
						let responseJson = JSON.parse(data);
						resolve(responseJson["object"]["sha"]);
					});
				}); // Get latest commit sha
			});
		},
		finish: function () {
			delete tempDlHelper;
			delete window.tempDlHelper;
		},
		userInteract: function (apply) {
			if (apply) {
				tempDlHelper.downloadAndEval(); // Finishes for me
			} else {
				tempDlHelper.finalEval(tempDlHelper.cachedObject["savedScript"]);
				tempDlHelper.finish();
			}
		}
	}

	async function tmpAsyncFnc() {
		tempDlHelper.latestVersion = await tempDlHelper.getLatestVersion();

		if (localStorage.getItem(tempDlHelper.updateInfoName) === null) { // If no version exists, download, execute and set
			localStorage.setItem(tempDlHelper.updateInfoName, "{}"); // Empty json object
			tempDlHelper.downloadAndEval();
		} else {
			tempDlHelper.cachedObject = JSON.parse(localStorage.getItem(tempDlHelper.updateInfoName));
			let currentVersion = tempDlHelper.cachedObject["version"];

			if (currentVersion != tempDlHelper.latestVersion) {
				let dialogAnswer = 0;
				let shellObj = tempDlHelper.electronObj.shell;

				while (dialogAnswer === 0) { // Open the blocking dialog again if the first button was clicked
					dialogAnswer = tempDlHelper.electronObj.ipcRenderer.sendSync("SDCExMessageDialog", {
                        type: "question",
                        buttons: ["View changes", "Apply latest update", "Execute saved version"],
                        defaultId: 0,
                        title: "New SimpleDiscordCrypt Extended Update",
                        message: "A new SimpleDiscordCrypt Extended version has been found."
                    });

					if (dialogAnswer === 0) {
						shellObj.openExternal(`https://github.com/Ceiridge/SimpleDiscordCrypt-Extended/compare/${encodeURIComponent(currentVersion)}..master`);
					}
				}

				tempDlHelper.userInteract(dialogAnswer === 1); // Apply if second button was clicked
			} else {
				tempDlHelper.userInteract(false); // Just eval the saved script and finish
			}
		}
	}
	tmpAsyncFnc();
	delete tmpAsyncFnc;


	const commandLineSwitches = process._linkedBinding('electron_common_command_line');
	let originalPreloadScript = commandLineSwitches.getSwitchValue('sdc-preload');

	if(originalPreloadScript != null) {
		commandLineSwitches.appendSwitch('preload', originalPreloadScript);
		require(originalPreloadScript);
	}
} else console.log("Uh-oh, looks like something is blocking require");' > /usr/share/SimpleDiscordCrypt/SimpleDiscordCryptLoader.js

# Create hard-link for Discord and electron
sudo ln /usr/share/discord/Discord /usr/share/discord/electron

# Rewrite Discord Startup Link

# Creating path's variables to avoid an unproperly working sed
old_link=Exec='/usr/share/discord/Discord'
new_link=Exec='gnome-terminal -e "set NODE_OPTIONS=-r /usr/share/SimpleDiscordCrypt/NodeLoad.js && /usr/share/discord/electron"'

sudo sed -i 's%$old_link%$new_link%g' /usr/share/applications/discord.desktop
sudo sed -i 's%$old_link%$new_link%g' /usr/share/discord/discord.desktop