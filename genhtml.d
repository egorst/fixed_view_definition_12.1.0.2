// generate html files for every fixed view

import std.stdio, std.string, std.conv, std.file;

struct Desc {
	string nam;
	string typ;
}

struct Token {
	int depth;
	string tok;
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

string stripSpaces(char[] l) {
	bool prevspace = false;
	bool insidequotes = false;
	char[] newl;
	foreach (c; l) {
		if (insidequotes) {
			if (c == '\'') {
				insidequotes = false;
			}
			newl ~= c;
		} else {
			switch (c) {
				case '\'':
					insidequotes = true;
					newl ~= c;
					prevspace = false;
					break;
				case ' ':
					if (!prevspace) {
						prevspace = true;
						newl ~= c;
					}
					break;
				default:
					prevspace = false;
					newl ~= c;
			}
		}
	}
	return newl.to!string;
}

char[] kqfSearch(char[] pat) {
	auto qf = File("kqf.o");
	ubyte[] upat = cast(ubyte[]) pat;
	char[8*1024*1024] s;
	auto buf = cast(ubyte[])std.file.read("kqf.o",8*1024*1024);
	auto ind = std.string.indexOf(cast(char[])buf,pat[1..$]);
	if (ind != -1) {
		long i = ind;
		ubyte[] b;
		do {
			b = buf[i..i+1];
			i += 1;
		} while (b[0] != 0);
		return cast(char[])buf[ind..i-1];
	}
	return null;
}

string[string] parseSelect() {
	string[string] s;
	string viewname;
	char[] viewdef;
	auto fv = File("fvdef.lst");
	int i = 0;
	foreach (l; fv.byLine) {
		i += 1;
		if (l.indexOf("+++") == 0) {
			auto secondmarker = l[3..$].indexOf("+++")+3;
			viewname = l[3..secondmarker].to!string;
			if (l.length > 4037) {
				viewdef = kqfSearch(l[37..157]);
				if (viewdef.length > 0) {
					s[viewname] = stripSpaces(viewdef.strip);
				}
			} else {
				s[viewname] = stripSpaces(l[37..$].strip);
			}
		} else {
			writeln("unknown line #",i);
		}
	}
	return s;
}

Token[] pruneToks(Token[] toks) {
	Token[] ptoks;
	foreach (i,t; toks) {
		if (!(strip(t.tok) == "" && strip(toks[i-1].tok)[$-1..$] == ",")) {
			ptoks ~= t;
		}
	}
	return ptoks;
}

int selectMinDepth(Token[] toks) {
	int md = int.max;
	foreach (t; toks) {
		if (strip(t.tok).toLower == "select") {
			if (md > t.depth) {
				md = t.depth;
			}
		}
	}
	return md;
}

Token[] tokenizeDefinition(string s) {
	Token[] toks;
	int depth = 0;
	bool inquotes = false;
	Token t;
	string tok;
	foreach (c; s) {
		if (c == '\'') {
			if (inquotes) {
				inquotes = false;
			} else {
				inquotes = true;
			}
		}
		if (!inquotes) {
			if (c == ' ' || c == ',') {
				tok ~= c;
				t.depth = depth;
				t.tok = tok;
				toks ~= t;
				tok = "";
			} else if (c == '(') {
				tok ~= c;
				t.depth = depth;
				t.tok = tok;
				toks ~= t;
				tok = "";
			} else if (c == ')') {
				tok ~= c;
				t.depth = depth;
				t.tok = tok;
				toks ~= t;
				tok = "";
			} else {
				tok ~= c;
			}
			if (c == '(') {
				depth += 1;
			}
			if (c == ')') {
				depth -= 1;
			}
		} else {
			tok ~= c;
		}
	}
	t.depth = depth;
	t.tok = tok;
	toks ~= t;
	return pruneToks(toks);
}

void generateHtml(string v,string vd) {
	Token[] toks = tokenizeDefinition(vd);
	debug {
		writeln("=====\nview ",v, " selMinDepth=",selectMinDepth(toks));
		foreach (t; toks) {
			writeln(leftJustify("",t.depth*2),t.tok);
		}
	}
}

Desc[][string] desc;
string[string] sel;

void main() {
	desc = parseDesc();
	/*
	debug {
		foreach (v,dd; desc) {
			writeln(v);
			foreach (d; dd) {
				writeln("  ",d.nam,"\t",d.typ);
			}
		}
	}
	*/
	sel = parseSelect();
	/*
	debug {
		foreach (v,vd; sel) {
			writeln(v,":",vd);
		}
	}
	*/
	foreach (view,vdef; sel) {
		generateHtml(view,vdef);
	}
}

