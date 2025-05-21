// on toolbar click, inject content‐script into the active tab
browser.action.onClicked.addListener(tab => {
	browser.scripting.executeScript({
		target: { tabId: tab.id },
		files: ['content-script.js']
	});
});

// listen for messages from content‐script
browser.runtime.onMessage.addListener((msg, sender, completion_handler) => {
	console.log("got in listener: ", msg.type);
	if (msg.type == 'SAVE_BOOKMARK') {
		// store data in chrome.storage.local with a unique key
		const bookmark_key = 'bookmark_' + Date.now();
		browser.storage.local.set({
			[bookmark_key]: msg.data
		})
		.then(() => {
		  const url = browser.runtime.getURL('prompt.html') + '?key=' + bookmark_key;
		  browser.tabs.create({ url });
		  completion_handler({ success: true, key: bookmark_key });
		})
		.catch(err => {
		  completion_handler({ success: false, error: err.message });
		});

		// keep the channel open for the async handler
		return true;
	}
	else if (msg.type == 'CONFIRM_BOOKMARK') {
		const form = new FormData();
		form.append('bookmark-of', msg.data.url);
		form.append('bookmark-name', msg.data.title);
		form.append('bookmark-content', msg.data.html);

		// get current token from native app
		browser.runtime.sendNativeMessage({ type: "GET_TOKEN" }).then(response => {
			if (response.token) {
				console.log("Got token:", response.token);

				// POST to Micro.blog
				fetch('https://micro.blog/micropub', {
					method: 'POST',
					body: form
				})
				.then(response => {
					response.text().then(text => {
						console.log("micropub response text:", text);
					});
					if (!response.ok) {
						throw new Error(response.statusText);
					}
					completion_handler({ success: true });
				})
				.catch(err => {
					console.error('Error saving bookmark:', err);
					completion_handler({ success: false, error: err.message });
				});
			}
			else {
				console.error("Token error:", response.error);
			}
		});
				
		// keep the channel open for the async handler
		return true;
	}
});
