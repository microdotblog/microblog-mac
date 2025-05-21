window.onload = () => {
	const params = new URLSearchParams(window.location.search);
	const bookmark_key = params.get('key');
	if (!bookmark_key) {
		return;
	}

	browser.storage.local.get([bookmark_key], items => {
		const data = items[bookmark_key] || {};

		// clean URL for display
		let display_url = (data.url || '').replace(/^https?:\/\//, '');
		if (display_url.length > 100) {
			display_url = display_url.slice(0, 100) + '…';
		}
		
		// show display URL
		const url_div = document.getElementById('bookmark-url');
		if (url_div) {
			url_div.textContent = display_url;
		}
		
		// populate hidden fields
		document.getElementById('title').value = data.title || '';
		document.getElementById('url').value = data.url || '';
		document.getElementById('html').value = data.html || '';
		
		// clear storage after loading
		browser.storage.local.remove(bookmark_key);
	});

	document.getElementById('bookmark-form').onsubmit = function(e) {
		e.preventDefault();

		const save_button = document.getElementById('save-btn');
		const spinner = document.getElementById('spinner');
		save_button.disabled = true;
		spinner.style.display = 'inline-block';

		const bookmark = {
			url: document.getElementById('url').value,
			title: document.getElementById('title').value,
			html: document.getElementById('html').value
		};
		browser.runtime.sendMessage({
			type: 'CONFIRM_BOOKMARK',
			data: bookmark
		})
		.then(response => {
			// wait a half second before closing
			setTimeout(() => {
				window.close();
			}, 500);
		});
	};
};
