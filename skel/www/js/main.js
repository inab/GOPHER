function InitXCESC() {
	var JSDEPS=new Array(
			'/js/jshash-2.2/md5-min.js',
			'/js/loginLogic.js',
			'/js/blogFeedBox.js'
		);

	WidgetCommon.widgetCommonInit(JSDEPS,function() {
		var container = document.getElementById('rightSideContainer');
		try {
			var loginBox = new LoginBox(container);
		} catch(e) {
			WidgetCommon.DebugMSG(e);
		}
		
		var contentId = 'news_content';
		try {
			var feedBox = new BlogFeedBox(container, contentId, function(html){
				var news = WidgetCommon.getElementById(contentId);
				if (news != undefined) 
					news.innerHTML = html;
			});
		} catch(e) {
			WidgetCommon.DebugMSG(e);
		}
	},'');
}

function DisposeXCESC() {
}
