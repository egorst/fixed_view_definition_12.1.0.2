// generate html files for every fixed view

import std.stdio, std.string, std.regex, std.conv;

struct Desc {
	string name;
	string type;
}

Desc[][string] parseDesc() {
	Desc[][string] viewsDesc;
	static reDashes = regex(r"^--------");
	static reViewName = regex(r"^\+\+\+(.*)\+\+\+$");
	static reHeader   = regex(r"Name\s+Null\s+Type");
	static reNameType = regex(r"^\s*(\S+)\s+(\S+)$");
	string vname;
	Desc[] desc;
	auto fdesc = File("fvdesc.txt");
	foreach (l; fdesc.byLine.to!string) {
		if (matchFirst(l,reDashes) || matchFirst(l,reHeader)) {
			continue;
		} else if (auto m = match(l,reViewName)) {
			if (vname != "") {
				viewsDesc[vname] = desc;
				desc = [];
			}
			vname = m[1];
		} else if (auto m = match(l,reNameType)) {
			Desc d;
			d.name = m[1];
			d.type = m[2];
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

