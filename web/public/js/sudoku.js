function setup()
{
	// replace inputs with grids
	var cells = getElementsByClass(document, "td", "entry");
	for(var i=0; i<cells.length; i++) {
		var inputs = cells[i].getElementsByTagName("input");
		if ((inputs.length == 1) && !inputs[0].value.match(/^\s*$/)) {
			cells[i].innerHTML = inputs[0].value;
			cells[i].ondblclick = function(e) {addGrid(this);this.ondblclick=null;};
		} else {
			addGrid(cells[i]);
		}
	}

	// set hook for sending form
	var form = document.forms[0];
	if (form) form.onsubmit = function(e) {sendForm(form);};

	// make menu clickable everywhere
	menu = document.getElementById("menu");
	items = menu.getElementsByTagName("li");
	for (var i=0; i<items.length; i++) {
		items[i].onclick = function(e) { 
			var a = this.getElementsByTagName("a")[0];
			window.location = a.href;
	       	};
	}

	// create help for js ui
	help = document.getElementById("help");
	if (help) {
		str = "<b>HELP: </b>"
		str = str + "<em>click once</em> on small blue number to remember &nbsp;";
		str = str + "<em>double-click</em> on small blue number to fill in &nbsp;";
		str = str + "<em>double-click</em> on big blue number to correct &nbsp;";
		help.innerHTML = str;
	}
}


function prepareForm(form)
{
	inputs = form.getElementsByTagName("input");
	for (var i=0; i<inputs.length; i++) {
		if (inputs[i].name.match(/^solution|memory\[.*/i)) {
			form.removeChild(inputs[i]);
		}
	}

	entries = getElementsByClass(document, "td", "entry");
	for (var i=0; i<entries.length; i++) {
		var value = entries[i].innerHTML;
		var coords = entries[i].id.match(/(\d+):(\d+)/);
		var y = coords[1];
		var x = coords[2];

		if (entries[i].innerHTML.match(/^\s*\d+\s*$/i)) {
			formAppendInput(form, "solution["+y+"]["+x+"]", "hidden", value);
		} else {
			selected = getElementsByClass(entries[i], "td", "selected");
			for (var j=0; j<selected.length; j++) {
				formAppendInput(form, "memory["+y+"]["+x+"][]", "hidden", selected[j].innerHTML);
			}
		}
	}
}

function formAppendInput(form, name, type, value)
{
	input = document.createElement("input");
	input.type = type;
	input.name = name;
	input.value = value;
	form.appendChild(input);
}

function sendForm(form)
{
	prepareForm(form);
	form.submit();
}

function getAjax()
{
	var xmlhttp;
	if (window.XMLHttpRequest)
	{// code for IE7+, Firefox, Chrome, Opera, Safari
		xmlhttp=new XMLHttpRequest();
	} else {// code for IE6, IE5
		xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
	}
	return xmlhttp;
}

function submitFormInBackground()
{
	var form = document.forms[0];

	str = "";
	entries = getElementsByClass(document, "td", "entry");
	for (var i=0; i<entries.length; i++) {
		var value = entries[i].innerHTML;
		var coords = entries[i].id.match(/(\d+):(\d+)/);
		var y = coords[1];
		var x = coords[2];

		if (entries[i].innerHTML.match(/^\s*\d+\s*$/i)) {
			str = str + "solution["+y+"]["+x+"]=" + value + "&";
		} else {

			selected = getElementsByClass(entries[i], "td", "selected");
			for (var j=0; j<selected.length; j++) {
				str = str + "memory["+y+"]["+x+"][]=" + selected[j].innerHTML + "&";
			}
		}
	}

	xmlhttp = getAjax();
	xmlhttp.open("GET","save?"+str,true);
	xmlhttp.send();
}

function addGrid(cell)
{
	var str = '<table class="grid" onmouseover="showGrid(this);">';

	for(var y=0; y<3; y++) {
		str = str + "<tr>";
		for(var x=0; x<3; x++) {
			var coords = cell.id.match(/(\d+):(\d+)/);
			var gy = coords[1];
			var gx = coords[2];
			var i = (y*3)+(x+1)

			var cl = "";
			if (memory!=null && memory[gy]!=null && memory[gy][gx]!=null && memory[gy][gx].indexOf(i)>=0) {
				cl = ' class="selected"';
			}
			str = str + '<td onclick="toggleSelected(this);" ondblclick="select(this);"'+cl+'>';
			if (cl != "") {
				str = str + i;
			}
			str = str + "</td>";
		}
		str = str + "</tr>";
	}

	cell.innerHTML = str + "</table>";
}


function showGrid(grid)
{
	hideGrids();
	var cells = grid.getElementsByTagName("td");
	for (var i=0; i<cells.length; i+=1) {
		cells[i].innerHTML = "" + (i+1);
	}
	grid.onmouseout = function(e){hideGrid(this); this.onmouseout=null;};
}


function hideGrids()
{
	var cells = getElementsByClass(document, "td", "entry");
	for(var i=0; i<cells.length; i++) {
		hideGrid(cells[i]);
	}
}


function hideGrid(cell)
{
	var tips = cell.getElementsByTagName("td");
	for (var i=0; i<tips.length; i++) {
		if (tips[i].className == "selected") continue;
		tips[i].innerHTML = "";
	}
}


function select(element)
{
	var entry = element;
	while (entry!=null && entry.className!="entry") entry = entry.parentNode;
	entry.innerHTML = element.innerHTML;
	setTimeout( function() {
		entry.ondblclick = function(e) {addGrid(entry); entry.ondblclick=null;};
	}, 100);
	submitFormInBackground();
}


function toggleSelected(element)
{
	element.className = (element.className == "") ? "selected" : "";
	submitFormInBackground();
}


function getElementsByClass(element, tag, name)
{
	var elements = element.getElementsByTagName(tag);
	var result = [];
	for (var i=0; i<elements.length; i++) {
		if (elements[i].className != name) continue;
		result.push(elements[i]);
	}
	return result;
}
