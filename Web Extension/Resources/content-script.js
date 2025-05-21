 (() => {
	 const message = {
		 type: 'SAVE_BOOKMARK',
		 data: {
			 url: location.href,
			 title: document.title,
			 html: document.documentElement.outerHTML
		 }
	 };
	 
	 browser.runtime.sendMessage(message)
		 .then(response => {
			 console.log("sendMessage response: ", response);
			 if (response && response.success) {
				 console.log('Bookmark saved successfully');
			 } else {
				 console.error('Failed to save bookmark', response && response.error);
			 }
		 })
		 .catch(err => {
			 console.error('sendMessage error:', err);
		 });
 })();
