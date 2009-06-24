var JSDEPS=new Array(
	'XCESC-GUI-logic/feed.xql'
);

function atomCallback(html) {
	var news = WidgetCommon.getElementById('news_content');
        if(news!=undefined)
		news.innerHTML = html;
}

function InitXCESC() {
	WidgetCommon.widgetCommonInit(JSDEPS,undefined,'');
}

function DisposeXCESC() {
}
