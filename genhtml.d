// generate html files for every fixed view

import std.stdio, std.string, std.regex;

struct Desc {
	string name;
	string type;
}

string[Desc[]] parseDesc() {
	string[Desc[]] d;
	static reDashes = ctRegex!"^--------";
	static reViewName = ctRegex!"^\\+\\+\\+(.*)\\+\\+\\+$";
	auto fdesc = File("fvdesc.txt");
	foreach (l; fdesc.byLine) {

	}
	return d;
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

