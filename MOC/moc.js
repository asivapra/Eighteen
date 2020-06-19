  // ***************************************************************************
  // ///////////////////////////////////////////////////////////////////////////
  // ***************************************************************************
  //
  //  Site: webgenie.com
  //   VERSION: 1.0
  // 
  // ***************************************************************************
  // ///////////////////////////////////////////////////////////////////////////
  // ***************************************************************************
  // Functions added by AVS
  // Copyright (c) 2011-2019 by AV Sivaprasad and WebGenie Software Pty Ltd.
// Global variables
var cgi = "cgi-bin/moc.cgi"; // calls users.cgi http://www.webgenie.com/GSKY/GoogleEarth/KML/Australia_Fractional_Cover_8_Day_2018-11-01.kml
function CopyToClipBoard()
{
	var textBox = document.getElementById('copytext');
	var copyButton = document.getElementById('copybutton');
	copybutton.style.color = '#d0d0d0';
	var text = textBox.innerHTML;
	textBox.select();
	document.execCommand('copy');
	textBox.style.display = 'none';
	showHide("copytext", "none");
	showHide("copybutton", "none");
	showHide("arcgis_window",'iframe',"block");
	showHide('bbox_finder','div','none');
	window.location.href = "#arcgis";
}
function Commify(x) {
    var parts = x.toString().split(".");
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    return parts.join(".");
}
function Monify(value)
{
  if (!value || value == undefined) return "0.00";
  var str = "" + Math.round(value*100);
  var len = str.length;

  return (str=="0")?"":(str.substring(0,len-2)+"."+str.substring(len-2,len));
}
function CancelJob(form)
{
//alert(form.id);	
	ajaxFunction(3,form);
}
function ValidateInput(form,n)
{
	document.getElementById("img_link").innerHTML = "<img alt=\"Wait!\" src=\"/images/ajax-loader.gif\"> Fetching...&nbsp;&nbsp;&nbsp;<input type=\"button\" value=\"Cancel\" style=\"color:red\" onclick=\"CancelJob(this.form)\">";
	ajaxFunction(n,form);
}
function showHideToggle(id,type)
{
		var style = document.getElementById(id).style.display;
		if(style == 'none') showHide(id,type,'block');
		else showHide(id,type,'none');
}
function showHide(id,type,state)
{
        if (state == undefined) state = 'block';
		var style = document.getElementById(id).style.display;
		document.getElementById(id).style.display=""+state;
}
function InsertAddress(form,item)
{
//alert(item[item.selectedIndex].value);	
	form.to_address.value = item[item.selectedIndex].value;
	item.selectedIndex = 0;
}
function CSWriteCookie() 
{
//	CSCookieArray = new Object;
	var name   = "MOC";
	cookieVal += "; path=/";
	var this_cookie = name + "=" + cookieVal;
	this_cookie += "; expires=" + "Thursday, 31-Dec-2099 00:00:00 GMT";
	document.cookie = this_cookie;
	var cookies = document.cookie;
}
function CSDeleteCookie() 
{
//	CSCookieArray = new Object;
	var name   = "MOC";
	cookieVal += "; path=/";
	var this_cookie = name + "=" + cookieVal;
	this_cookie += "; expires=" + "Thursday, 30-Dec-1999 00:00:00 GMT";
	document.cookie = this_cookie;
	var cookies = document.cookie;
}
function CSReadCookie() 
{
	cookieVal = '';
	username = '';
	var name    = "MOC";
	var cookies = document.cookie;
//alert(cookies);	
	var start = cookies.indexOf(name);
//	var mobile = detectmob();
	if(start == -1) 
	{
//		var loggedIn = 0
//		document.forms.login_form.User_email.value = '';
//		document.forms.login_form.passwd.value = '';
		showHide('LoginBlock','div','block');
		showHide('LoggedinBlock','div','none');
//		return loggedIn;
	}
	else
	{
		start += name.length + 1;
		var end = cookies.indexOf(";", start);
		if(end == -1) end = cookies.length;
		cookieVal = cookies.substring(start, end);
		if (!cookieVal) 
		{
			showHide('LoginBlock','div','block');
			showHide('LoggedinBlock','div','none');
		}
		else
		{
			cookieVal = unescape(cookieVal);
//alert(cookieVal);
			next = cookieVal.indexOf("|", 0);
			User_email = unescape(cookieVal.substring(0, next));
			start = next+1;
			next = cookieVal.indexOf("|", start);
			user_id = cookieVal.substring(start, next);
			start = next+1;
			next = cookieVal.indexOf("|", start);
			firstname = cookieVal.substring(start, next);
			start = next+1;
			next = cookieVal.indexOf("|", start);
			lastname = cookieVal.substring(start, next);
//alert(document.getElementById("LoginBlock").innerHTML);
			showHide('LoginBlock','div','none');
			loggedinBlockText = "<span style=\"font-size: 11px;\">" + firstname + " " + lastname + " | " + "</span>" +  "<span style=\"text-decoration:underline; cursor:pointer; font-size: 11px;\" onmousedown=\"LogOut()\">Logout</span>"
			document.getElementById("LoggedinBlock").innerHTML = loggedinBlockText;
			showHide('LoggedinBlock','div','block');
		}
	}

	var blankcookie = cookies.indexOf(name+";");
	if (blankcookie > 0) return "";
	return cookieVal;
}	
function GetAndListAddresses()
{
	ajaxFunction(3,document.forms.login_form);
}
function LoginCheckForAjax()
{
	CSReadCookie();
	if (cookieVal) { GetAndListAddresses(); }
}

function LogOut()
{
	CSDeleteCookie();	
	showHide('LoginBlock','div','block');
	showHide('LoggedinBlock','div','none');
}
function ajaxFunction(n,form,item)
{
  var xmlHttp;
  var url;
  try
  {  // Firefox, Opera 8.0+, Safari  
	  xmlHttp=new XMLHttpRequest();  
  }
  catch (e)
  {  // Internet Explorer  
    try
    {    
		xmlHttp=new ActiveXObject("Msxml2.XMLHTTP");    
	}
	catch (e)
    {    
		try
		{      
			xmlHttp=new ActiveXObject("Microsoft.XMLHTTP");      
		}
		catch (e)
      	{	      
			alert("Your browser does not support AJAX!");      
			return false;      
		}    
	}
  }
	xmlHttp.onreadystatechange=function()
	{
//alert(xmlHttp.readyState);
	  if(xmlHttp.readyState==4)
	  {
 		  response = xmlHttp.responseText;
		  if (n == 1) // Process the response
		  {
//alert("1. response = " + response);
		  	var fields = response.split("?");
		  	var img_url = fields[0];
			document.getElementById("copytext").innerHTML = response;
			document.getElementById("show_img").src = img_url;
			showHide("img_link", 'span', "none");
			showHide("show_img", 'iframe', "block");
			showHide("copytext", 'textarea', "block");
			copybutton.style.color = '#0000FF';
			showHide("copybutton", 'span', "block");
		  }
		  if (n == 2) // login
		  {
//alert("9. response = " + response);
			if (response)
			{
				fields = response.split("|");
				user_id = fields[0];
				firstname = fields[1];
				lastname = fields[2];
				showHide('LoginBlock','div','none');
				loggedinBlockText = "<span style=\"font-size: 11px;\">" + firstname + " " + lastname + " | " + "</span>" +  "<span style=\"text-decoration:underline; cursor:pointer; font-size: 11px;\" onmousedown=\"LogOut()\">Logout</span>"
				document.getElementById("LoggedinBlock").innerHTML = loggedinBlockText;
				showHide('LoggedinBlock','div','block');
				cookieVal = User_email + "|" + user_id + "|" + firstname + "|" + lastname + "|";
				CSWriteCookie();
				GetAndListAddresses();
			}
			else
			{
				alert('Email and/or Password is incorrect.');
			}
		  }
		  if (n == 3) // GetAndListAddresses
		  {
//alert("3. response = " + response);
			if (response)
			{
				document.getElementById("to_address_list").innerHTML = response;
			}
		  }
	  }
	}
	if (n == 1) // Send the URL
	{
		CSReadCookie();
		if (!cookieVal) 
		{
			document.getElementById("img_link").innerHTML = "";
			alert("Please login first!"); 
			return; 
		}
		showHide("img_link", 'span', "block");
		showHide("copytext", 'textarea', "none");
		showHide("copybutton", 'span', "none");
		if (!form.to_address.value || form.to_address.value.indexOf('@') < 0 )
		{
			document.getElementById("img_link").innerHTML = "";
			alert("Please choose or type in a VALID email address!"); 
			return; 
		}
		pquery = 
		"to_address=" + form.to_address.value;
		pquery = escape(pquery);
		pquery = pquery.replace("+","%2B");
		var ran_number= Math.random()*5000;
		url = cgi + "?MOC+" + ran_number + "+" + pquery;
	}
	if (n == 2) // login
	{
		var ran_number= Math.random()*5000;
		User_email = form.User_email.value;
		Password = form.Password.value;
		url = cgi + "?login+" + ran_number + "+" + User_email + "+" + Password;
	}
	if (n == 3) // GetAndListAddresses
	{
		var ran_number= Math.random()*5000;
		url = cgi + "?addresses+" + ran_number + "+" + user_id;
	}
//alert('n = ' + n + ' url = ' + url);	
//return;
	if (url)
	{
		xmlHttp.open("GET",url,true);
		xmlHttp.send(null);  
	}
	else
	{
		return;
	}
}

