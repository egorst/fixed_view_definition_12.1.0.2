// generate html files for every fixed view

import std.stdio, std.string, std.conv;

struct Desc {
	string nam;
	string typ;
}

Desc[][string] parseDesc() {
	Desc[][string] viewsDesc;
	string vname;
	Desc[] desc;
	auto fdesc = File("fvdesc.txt");
	foreach (l; fdesc.byLine) {
		auto ll = l.to!string;
		if (ll.indexOf(" Name                                                  Null?    Type") != -1
				|| ll.indexOf(" ----------------------------------------------------- -------- ------------------------------------") != -1) {
			continue;
		} else if (ll.length > 6 && ll[0..3] == "+++" && ll[$-3..$] == "+++") {
			if (vname != "") {
				viewsDesc[vname] = desc;
				desc = [];
			}
			vname = ll[3..$-3];
		} else if (split(ll).length == 2) {
			Desc d;
			d.nam = split(ll)[0];
			d.typ = split(ll)[1];
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
	debug {
		foreach (v,dd; desc) {
			writeln(v);
			foreach (d; dd) {
				writeln("  ",d.nam,"\t",d.typ);
			}
		}
	}
	sel = parseSelect();
	foreach (view; sel) {
		generateHtml(view);
	}
}

