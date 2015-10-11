// generate html files for every fixed view

import std.stdio, std.string, std.regex;

struct Desc {
	string name;
	string type;
}

Desc[][string] parseDesc() {
	Desc[][string] viewsDesc;
	static reDashes = ctRegex!"^--------";
	static reViewName = ctRegex!"^\\+\\+\\+(.*)\\+\\+\\+$";
	static reHeader   = ctRegex!r"Name\s+Null\s+Type";
	static reNameType = ctRegex!r"^\s*(\S+)\s+(\S+)$";
	string vname;
	Desc[] desc;
	auto fdesc = File("fvdesc.txt");
	foreach (l; fdesc.byLine) {
		if (matchFirst(l,reDashes) || matchFirst(l,reHeader)) {
			continue;
		} else if (auto m = match(l,reViewName)) {
			if (vname != "") {
				viewsDesc[vname] = desc;
				desc = [];
			}
			vname = m.captures[0];
		} else if (auto m = match(l,reNameType)) {
			Desc d;
			d.name = m[0];
			d.type = m[1];
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
	string[Desc[]] desc;
	string[string] sel;
	desc = parseDesc();
	sel = parseSelect();
	foreach (view; sel) {
		generateHtml(view);
	}
}

