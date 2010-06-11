/**
 * LoginBox constructor
 * @constructor
 * @param {HTMLElement} parent
 */
function LoginBox(parent) {
	this.initBox(parent);
	this.show(this.waitMiddle);
	this.showLoginInfo();
};

LoginBox.loginURL='/XCESC-logic/gui-login.xql';
LoginBox.infoURL='/XCESC-logic/gui-session-gate.xql';
LoginBox.authHeader='XCESC-auth';
LoginBox.loginHeader='XCESC-login';

LoginBox.prototype = {
	/**
	 * LoginBox Initialization
	 * @author jmfernandez
	 * @method
	 * @param {HTMLElement} parentElement
	 */
	initBox: function(parentElement) {
		if(parentElement!=undefined && parentElement!=null) {
			var thedoc = parentElement.ownerDocument;
			var loginBox = thedoc.createElement('div');
			this.loginBox = loginBox;
			loginBox.setAttribute('style','padding-bottom: 0pt;');
			loginBox.className = 'sidemenu';
			
			// Head
			var loginHead = thedoc.createElement('div');
			loginHead.setAttribute('style','padding-top: 0pt;');
			loginHead.className = 'head';
			loginBox.appendChild(loginHead);
			
			/**
			 * Helper function used to create fancy borders
			 * @param {Boolean} [isTop]
			 */
			var generateTopBottom = function (/*optional*/ isTop) {
				var inc;
				var ini;
				var fin;
				var style;
				var subStyle;
				if(isTop) {
					inc=1;
					ini=1;
					fin=5;
					style='margin-left: -5px; margin-right: -5px; background: none repeat scroll 0% 0% rgb(255, 255, 255); margin-bottom: -3px;';
					subStyle='background-color: rgb(26, 17, 147); border-color: rgb(140, 136, 201);';
				} else {
					inc=-1;
					ini=4;
					fin=0;
					style='margin-left: 0px; margin-right: 0px; background: none repeat scroll 0% 0% transparent; margin-top: -5px;';
					subStyle='background-color: transparent; border-color: rgb(255, 255, 255);';
				}
				var topB = thedoc.createElement('b');
				topB.setAttribute('style',style);
				topB.className = 'niftycorners';
					
				for(var i=ini;i!=fin;i+=inc) {
					var innerB = thedoc.createElement('b');
					innerB.setAttribute('style',subStyle);
					innerB.className = 'r'+i;
					topB.appendChild(innerB);
				}
				
				return topB;
			};
			
			var topB = generateTopBottom(1);
			loginHead.appendChild(topB);
			loginHead.appendChild(document.createTextNode('Login'));
			
			// Middle
			var loginMiddle = thedoc.createElement('div');
			this.loginMiddle =loginMiddle;
			this.currentMiddle = this.loginMiddle;
			loginMiddle.className = 'login';
			loginMiddle.style.display = 'none';
			loginBox.appendChild(loginMiddle);
			
			var form = thedoc.createElement('form');
			this.loginForm = form;
			//form.setAttribute('action','javascript:false;');
			form.setAttribute('accept-charset','utf-8');
			form.setAttribute('method','POST');
			loginMiddle.appendChild(form);
			
			var table = thedoc.createElement('table');
			table.setAttribute('width','100%');
			form.appendChild(table);
			
			var tbody = thedoc.createElement('tbody');
			table.appendChild(tbody);
			
			// The user field
			var tr = thedoc.createElement('tr');
			tbody.appendChild(tr);
			
			var td = thedoc.createElement('td');
			td.className='label';
			td.appendChild(thedoc.createTextNode('User:'));
			tr.appendChild(td);
			
			td = thedoc.createElement('td');
			td.className = 'field';
			tr.appendChild(td);
			
			var input = thedoc.createElement('input');
			this.userField = input;
			input.setAttribute('type','text');
			input.setAttribute('name','user');
			td.appendChild(input);
			
			// The password field
			tr = thedoc.createElement('tr');
			tbody.appendChild(tr);
			
			td = thedoc.createElement('td');
			td.className='label';
			td.appendChild(thedoc.createTextNode('Password:'));
			tr.appendChild(td);
			
			td = thedoc.createElement('td');
			td.className = 'field';
			tr.appendChild(td);
			
			var inputpass = thedoc.createElement('input');
			this.passField = inputpass;
			inputpass.setAttribute('type','password');
			inputpass.setAttribute('name','password');
			td.appendChild(inputpass);
			
			// Some event listeners
			WidgetCommon.addEventListener(input,'keydown',function(evt) {
				if(!evt)  evt=window.event;
				var key = ('keyCode' in evt) ? evt.keyCode : ('which' in evt) ? evt.which : evt.charCode;
				if(key==13) {
					evt.cancelBubble = true;
					if('stopPropagation' in evt)
						evt.stopPropagation();
					if('preventDefault' in evt)
						evt.preventDefault();
					inputpass.focus();
					return false;
				}
				return true;
			},false);
			
			var thisBox=this;
			WidgetCommon.addEventListener(inputpass,'keydown',function(evt) {
				if(!evt)  evt=window.event;
				var key = ('keyCode' in evt) ? evt.keyCode : ('which' in evt) ? evt.which : evt.charCode;
				if(key==13) {
					evt.cancelBubble = true;
					if('stopPropagation' in evt)
						evt.stopPropagation();
					if('preventDefault' in evt)
						evt.preventDefault();
					thisBox.doLogin(evt);
					return false;
				}
				return true;
			},false);
			
			WidgetCommon.addEventListener(form,'submit',function(evt) {
				if(!evt)  evt=window.event;
				evt.cancelBubble = true;
				if('stopPropagation' in evt)
					evt.stopPropagation();
				if('preventDefault' in evt)
					evt.preventDefault();
				return false;
			},false);
			
			// Submit button
			tr = thedoc.createElement('tr');
			tbody.appendChild(tr);
			
			td = thedoc.createElement('td');
			td.setAttribute('colspan','2');
			tr.appendChild(td);
			
			input = thedoc.createElement('button');
			this.submitButton = input;
			input.setAttribute('type','button');
			input.appendChild(thedoc.createTextNode('Login'));
			td.appendChild(input);
			
			// The event listener
			WidgetCommon.addEventListener(input, 'click', function(evt){
				if(!evt)  evt=window.event;
				return thisBox.doLogin(evt);
			}, true);
			
			// The div for the wait
			var waitMiddle = thedoc.createElement('div');
			this.waitMiddle =waitMiddle;
			waitMiddle.className = 'login';
			waitMiddle.style.display = 'none';
			var throbber = thedoc.createElement("img");
			throbber.src = "/style/ajaxLoader.gif";
			waitMiddle.appendChild(throbber);
			waitMiddle.appendChild(thedoc.createTextNode('Please wait'));
			loginBox.appendChild(waitMiddle);
			
			// The div for the user information
			var infoMiddle = thedoc.createElement('div');
			this.infoMiddle = infoMiddle;
			infoMiddle.className = 'login';
			infoMiddle.style.display = 'none';
			loginBox.appendChild(infoMiddle);
			
			// The div for the errors
			var errorMiddle = thedoc.createElement('div');
			this.errorMiddle = errorMiddle;
			errorMiddle.className = 'login';
			errorMiddle.style.display = 'none';
			try {
				var errorSVG = WidgetCommon.createSVG('/style/dialog-error.svg',errorMiddle);
			} catch(e) {
			}
			var errorSpan = thedoc.createElement('span');
			this.errorSpan = errorSpan;
			errorMiddle.appendChild(errorSpan);
			loginBox.appendChild(errorMiddle);
			
			// Bottom
			var bottomB = generateTopBottom(undefined);
			loginBox.appendChild(bottomB);
			
			// And at the end...
			parentElement.appendChild(loginBox);
		}
	},
	/**
	 * This internal method calculates the digest to send, based on
	 * parameters sent
	 * @method
	 * @param {String} user
	 * @param {String} password
	 * @param {String} realm
	 * @param {String} nonce
	 * @return {String}
	 */
	doLoginDigest: function (user, password, realm, nonce) {
		var HA1 = hex_md5(user+':'+realm+':'+password);
		return hex_md5(nonce+':'+HA1);
	},
	/**
	 * Event handler which fires the whole login process
	 * @method
	 * @param {Event} evt
	 */
	doLogin: function(evt) {
		var req = new XMLHttpRequest();
		var loginBox = this;
		var user = this.userField.value;
		var pass = this.passField.value;
		req.onreadystatechange = function() {
			if(req.readyState == 4) {
				// Opera does not behave well, shit!
				if(req.status == 401 || req.status == 0) {
					var header = req.getResponseHeader(LoginBox.authHeader);
					if(header!=null && header!=undefined) {
						// First, translate it to a normal string
						header = header + '';
						// Now, let's get the parameters
						var tokens = header.split(", ");
						var toklen = tokens.length;
						var nonce = undefined;
						var realm = undefined;
						for(var i=0;i<toklen;i++) {
							var token = tokens[i];
							var keyval = token.split('=',2);
							if(keyval.length == 2) {
								if(keyval[0]=='nonce') {
									nonce = keyval[1];
								} else if(keyval[0]=='realm') {
									realm = keyval[1];
								}
							}
						}
						
						if(nonce!=undefined && realm!=undefined) {
							// Time to prepare second act
							var generatedResponse = loginBox.doLoginDigest(user,pass,realm,nonce);
							var req2 = new XMLHttpRequest();
							req2.onreadystatechange = function() {
								if(req2.readyState == 4 ) {
									if(req2.status == 200) {
										// alert("In theory, logged in");
										if('LoginBox_DO_RELOAD' in window)
											window.location.reload();
										else
											loginBox.showLoginInfo(true);
									} else {
										// alert("Could not login: "+req2.status);
										loginBox.showError("Could not login (invalid username or password ["+req2.status+"]?)");
									}
								
									req2.onreadystatechange = function() { };
									req2 = undefined;
								}
							};
	
							req2.open('GET',LoginBox.loginURL,true);
							req2.setRequestHeader(LoginBox.loginHeader,"user="+user+", realm="+realm+", nonce="+nonce+", response="+generatedResponse);
							req2.send();
						} else {
							// alert("Garbled "+LoginBox.authHeader+" header");
							loginBox.showError("Corrupted authentication token (server or network problems?");
						}
					} else {
						// alert("Could not obtain "+LoginBox.authHeader+" header");
						loginBox.showError("Could not get authentication token (server or network problems?)");
					}
				} else {
					// alert("Could not request nonce");
					loginBox.showError("Error while starting login handshaking");
				}
				req.onreadystatechange = function() { };
				req = undefined;
			}
		};
		req.open('GET',LoginBox.loginURL,true);
		this.show(this.waitMiddle);
		req.send();
	},
	/**
	 * Event listener for clicking on logout 
	 * @method
	 */
	doLogout: function() {
		var req = new XMLHttpRequest();
		var loginBox = this;
		req.onreadystatechange = function(){
			if (req.readyState == 4) {
				// It doesn't matter whether we could logout or not
				req.onreadystatechange = function () {};
				req = undefined;
				if('LoginBox_DO_RELOAD' in window)
					window.location.reload();
				else
					loginBox.showLoginForm();
			}
		};
		var params=new Object();
		params['doLogout']='true';
		req.open('GET',WidgetCommon.generateQS(params,LoginBox.loginURL),true);
		this.show(this.waitMiddle);
		req.send();
	},
	/**
	 * This method clears user and password fields, and shows its box
	 */
	showLoginForm: function() {
		this.userField.value = '';
		this.passField.value = '';
		this.show(this.loginMiddle);
		this.userField.focus();
	},
	/**
	 * This function shows login information associated to the session
	 * @param {Boolean} [complain]
	 */
	showLoginInfo: function(/*optional*/ complain) {
		var req = new XMLHttpRequest();
		var loginBox = this;
		req.onreadystatechange = function () {
			if(req.readyState == 4) {
				if(req.status == 200) {
					var infoMiddle = loginBox.infoMiddle;
					var thedoc = infoMiddle.ownerDocument;
					try {
						WidgetCommon.clearNode(infoMiddle);
						if (req.parseError && req.parseError.errorCode != 0) {
							infoMiddle.appendChild(thedoc.createTextNode("User information is unparsable (IE)"));
						} else {
							var response=req.responseXML;
							if(response==undefined || response==null) {
								if(req.responseText!=undefined && req.responseText!=null) {
									var parser = new DOMParser();
									response = parser.parseFromString(req.responseText,'application/xml');
									if(response == null || response == undefined || WidgetCommon.getLocalName(response.documentElement) == 'parsererror') {
										infoMiddle.appendChild(thedoc.createTextNode("User information is unparsable (Non-IE)"));
										response=undefined;
									}
								}
							}
							
							// And now, let's show the gathered information!
							if(response!=undefined && response!=null) {
								loginBox.renderInfo(response.documentElement);
							}
						}
					} catch(e) {
						// Ignore???
						infoMiddle.appendChild(thedoc.createElement('br'));
						infoMiddle.appendChild(thedoc.createTextNode("Internal error on user information parsing: "+e));
					}
					loginBox.show(infoMiddle);
				} else if(complain){
					loginBox.showError("Unable to fetch user information (session timeout?)");
				} else {
					loginBox.showLoginForm();
				}
			}
		};
		req.open('GET',LoginBox.infoURL,true);
		this.show(this.waitMiddle);
		req.send();
	},
	/**
	 * Div switcher for loginBox
	 * @method
	 * @param {HTMLElement} [divToShow]
	 */
	show: function(/*optional*/ divToShow) {
		if(divToShow!=this.currentMiddle) {
			// First, let's hide the previous displayed div
			if(this.currentMiddle!=undefined)
				this.currentMiddle.style.display = 'none';
			
			if(divToShow!=undefined && divToShow!=null) {
				// And now, let's save the new one
				this.currentMiddle = divToShow;
				divToShow.style.display = 'block';
			} else {
				this.currentMiddle = undefined;
			}
		}
	},
	/**
	 * This function shows an error message for some seconds, and then it switches to the login window
	 * @method
	 * @param {String} errMsg
	 */
	showError: function(errMsg) {
		// Let's clean the content
		WidgetCommon.clearNode(this.errorSpan);
		var thedoc = this.errorSpan.ownerDocument;
		
		try {
			this.errorSpan.appendChild(thedoc.createTextNode(errMsg));
		} catch(Ig) {
			// Nothing interesting to do here, unless you are debugging
		}
		
		// Now, let's show the error
		this.show(this.errorMiddle);
		
		// And let's set the timeout on 3 seconds!
		var loginBox = this;
		window.setTimeout(function() { loginBox.showLoginForm(); },3000);
	},
	/**
	 * Information rendering
	 * @method
	 * @param {Element} root
	 */
	renderInfo: function(root) {
		var infoMiddle = this.infoMiddle;
		var thedoc = infoMiddle.ownerDocument;
		infoMiddle.appendChild(thedoc.createTextNode("User: "+root.getAttribute('firstName')+" "+root.getAttribute('lastName')));
		infoMiddle.appendChild(thedoc.createElement('br'));
		infoMiddle.appendChild(thedoc.createTextNode("Nickname: "+root.getAttribute('nickname')));
		infoMiddle.appendChild(thedoc.createElement('br'));
		var logoutButton = thedoc.createElement('button');
		logoutButton.setAttribute('type','button');
		logoutButton.appendChild(thedoc.createTextNode('Logout'));
		var thisBox = this;
		WidgetCommon.addEventListener(logoutButton,'click',function(evt){
			return thisBox.doLogout(evt);
		},true);
		infoMiddle.appendChild(logoutButton);
	}
};
