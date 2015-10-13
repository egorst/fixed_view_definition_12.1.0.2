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
		if (l.indexOf(" Name                                                  Null?    Type") != -1
				|| l.indexOf(" ----------------------------------------------------- -------- ------------------------------------") != -1) {
			continue;
		} else if (l.length > 6 && l[0..3] == "+++" && l[$-3..$] == "+++") {
			if (vname != "") {
				viewsDesc[vname] = desc;
				desc = [];
			}
			vname = l[3..$-3].to!string;
		} else if (split(l).length == 2) {
			Desc d;
			d.nam = split(l)[0].to!string;
			d.typ = split(l)[1].to!string;
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
	string viewname;
	auto fv = File("fvdef.lst");
	int i = 0;
	foreach (l; fv.byLine) {
		i += 1;
		if (l.indexOf("+++") == 0) {
			auto secondmarker = l[3..$].indexOf("+++")+3;
			viewname = l[3..secondmarker].to!string;
			if (l.length > 4037) {
				writeln("line #",i," view ",viewname,": too long definition");
			}
			s[viewname] = l[37..$].strip.to!string;
		} else {
			writeln("unknown line #",i);
		}
	}
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
	debug {
		foreach (v,vd; sel) {
			writeln(v,":",vd);
		}
	}
	foreach (view; sel) {
		generateHtml(view);
	}
}

