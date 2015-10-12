// generate html files for every fixed view

import std.stdio, std.string, std.conv;

struct Desc {
	string name;
	string type;
}

Desc[][string] parseDesc() {
	Desc[][string] viewsDesc;
	string vname;
	Desc[] desc;
	auto fdesc = File("fvdesc.txt");
	foreach (l; fdesc.byLine) {
		auto ll = l.to!string;
		if (ll.indexOf(" Name                                                  Null?    Type") 
				|| ll.indexOf(" ----------------------------------------------------- -------- ------------------------------------")) {
			continue;
		} else if (ll.length > 6 && ll[0..2] == "+++" && ll[-2..$] == "+++") {
			if (vname != "") {
				viewsDesc[vname] = desc;
				desc = [];
			}
			vname = ll[3..-3];
		} else if (split(ll).length == 2) {
			Desc d;
			d.name = split(ll)[0];
			d.type = split(ll)[1];
			desc ~= d;
		}
	}
	if (vname != "") {
		viewsDesc[vname] = desc;
	}
	return viewsDesc;
}

string[string] parseSelect() {
	string[string] s;
	return s;
}

void generateHtml(string v) {
}

void main() {
	Desc[][string] desc;
	string[string] sel;
	desc = parseDesc();
	sel = parseSelect();
	foreach (view; sel) {
		generateHtml(view);
	}
}

