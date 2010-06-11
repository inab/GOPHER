/**
 * BlogFeedBox constructor
 * @constructor
 * @param {HTMLElement} parent
 * @param {String} contentId
 * @param {Function} newAtomCallback
 */
function BlogFeedBox(parent,contentId,newAtomCallback) {
	this.initBox(parent,contentId);
	this.show(newAtomCallback);
};

BlogFeedBox.FeedURL='/XCESC-GUI-logic/feed.xql';
BlogFeedBox.AtomCallback = function (html) {};


BlogFeedBox.prototype = {
	/**
	 * BlogFeedBox Initialization
	 * @method
	 * @param {HTMLElement} parentElement
	 * @params {String} contentId
	 */
	initBox: function(parentElement,contentId) {
		if (parentElement != undefined && parentElement != null) {
			var thedoc = parentElement.ownerDocument;
			var feedBox = thedoc.createElement('div');
			this.feedBox = feedBox;
			feedBox.className = 'block';
			
			var headDiv = thedoc.createElement('div');
			headDiv.className = 'head';
			var title = thedoc.createElement('h3');
			title.appendChild(thedoc.createTextNode('GOPHER Blog Feed'));
			headDiv.appendChild(title);
			feedBox.appendChild(headDiv);
			
			var contentDiv = thedoc.createElement('div');
			contentDiv.className = 'news_content';
			// This id is used by callback function used to fill it in with content
			if(contentId!=undefined && contentId!=null) {
				contentDiv.id = contentId;
			}
			contentDiv.appendChild(thedoc.createTextNode('Loading News ...'));
			var throbber = thedoc.createElement("img");
			throbber.src = "/style/ajaxLoader.gif";
			contentDiv.appendChild(throbber);
			feedBox.appendChild(contentDiv);
			
			// At the end...
			parentElement.appendChild(feedBox);
		}
	}
	,
	/**
	 * @method
	 * @param {Function} newAtomCallback
	 */
	show: function(newAtomCallback) {
		// Callback function is set only when a function is passed to the show method
		if(typeof newAtomCallback == 'function')
			BlogFeedBox.AtomCallback = newAtomCallback;
		// Now, let's load the feed info
		var pars = new Object();
		pars['callback'] = 'BlogFeedBox.AtomCallback';
		WidgetCommon.dhtmlLoadScript( WidgetCommon.generateQS(pars, BlogFeedBox.FeedURL));
	}
};
