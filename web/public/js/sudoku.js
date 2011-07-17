function setup()
{
	var cells = getElementsByClass("td", "entry");
	for(var i=0; i<cells.length; i++) {
		var inputs = cells[i].getElementsByTagName("input");
		if ((inputs.length == 1) && !inputs[0].value.match(/^\s*$/)) {
			cells[i].innerHTML = inputs[0].value;
			cells[i].ondblclick = function(e) {addGrid(this);this.ondblclick=null;};
		} else {
			addGrid(cells[i]);
		}
	}

	var form = document.forms[0];
	form.onsubmit = function(e) {sendForm(form);};
}


function sendForm(form)
{
	inputs = form.getElementsByTagName("input");
	for (var i=0; i<inputs.length; i++) {
		if (inputs[i].name.match(/^solution\[.*/i)) {
			form.removeChild(inputs[i]);
		}
	}

	entries = getElementsByClass("td", "entry");
	for (var i=0; i<entries.length; i++) {
		if (entries[i].innerHTML.match(/^\s*\d+\s*$/i)) {
			var value = entries[i].innerHTML;
			var coords = entries[i].id.match(/(\d+):(\d+)/);
			var y = coords[1];
			var x = coords[2];
			input = document.createElement("input");
			input.type = "hidden";
			input.name = "solution["+y+"]["+x+"]";
			input.value = value;
			form.appendChild(input);
		}
	}

	form.submit();
}


function addGrid(cell)
{
	var str = '<table class="grid" onmouseover="showGrid(this);">';

	for(var y=0; y<3; y++) {
		str = str + "<tr>";
		for(var x=0; x<3; x++) {
			str = str + '<td onclick="toggleSelected(this);" ondblclick="select(this);">';
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
	var cells = getElementsByClass("td", "entry");
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
}


function toggleSelected(element)
{
	element.className = (element.className == "") ? "selected" : "";
}


function getElementsByClass(tag, name)
{
	var elements = document.getElementsByTagName(tag);
	var result = [];
	for (var i=0; i<elements.length; i++) {
		if (elements[i].className != name) continue;
		result.push(elements[i]);
	}
	return result;
}
