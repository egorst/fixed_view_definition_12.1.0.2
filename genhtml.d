// generate html files for every fixed view

import std.stdio, std.string, std.conv, std.file;
import std.uni : toLower;
import std.algorithm, std.array;
import std.typecons: No;
import std.getopt;

const int MAXLEN = 42;

bool textmode;

struct Desc {
    string nam;
    string typ;
}


struct SToken {
    int depth;
    TType ttype;
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
        } else if (split(l).length >= 2) {
            auto la = split(l);
            Desc d;
            d.nam = la[0].to!string;
            d.typ = join(la[1..$]," ").to!string;
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
            if (l.length > 1024) { // 4036 || viewname == "V$RECOVERY_AREA_USAGE") {
                viewdef = kqfSearch(l[37..$]);
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

enum TType { Select, From, Where, Func, Union, Other }

class Token {
    TType type;
    string value;
    this(TType typ, string val) {
        type = typ;
        value = val;
    }
    override string toString() {
        return std.string.format("Token(%s,%s)",type,value);
    }
}

class Interpreter {
    string text;
    int pos;

    this (string s) {
        text = s;
        pos = 0;
    }

    void setText(string s) {
        text = s.dup;
    }

    string getNextToken() {
        bool inquotes = false;
        bool inparen = false;
        string tok;
        int cpos;
        foreach (c; text[pos..$]) {
            if (c == '\'') {
                if (inquotes) {
                    inquotes = false;
                } else {
                    inquotes = true;
                }
            }
            if (! inquotes) {

            } else {
                tok ~= c;
                cpos += 1;
            }
        }
        return "";
    }

    int getStrPosition(string s, string chk) {
        int p;
        bool inquotes = false;
        int lvl = 0;
        int pos = -1;
        string tok = "";
        foreach (c; s) {
            pos += 1;
            if (c == '\'') {
                inquotes = ! inquotes;
            }
            if (!inquotes) {
                if (c == '(') {
                    lvl += 1;
                } else if (c == ')') {
                    lvl -= 1;
                }
                if (c == ' ' || c == ')' || c == '(') {
                    if (std.string.toLower(tok) == chk && lvl == 0) {
                        return (pos-cast(int)chk.length);
                    }
                    tok = "";
                } else {
                    tok ~= c;
                }
            } else {
                tok ~= c;
            }
        }
        if (std.string.toLower(tok) == chk && lvl == 0) {
            return (pos-cast(int)chk.length);
        }
        return cast(int)s.length;
    }

    int getRightParenPos(string s) {
        int pos = -1;
        int lvl = 0;
        bool inquotes = false;
        foreach (c; s) {
            pos += 1;
            if (c == '\'') {
                inquotes = ! inquotes;
            }
            if (!inquotes) {
                if (c == '(') {
                    lvl += 1;
                } else if (c == ')') {
                    lvl -= 1;
                    if (lvl == 0) {
                        return pos;
                    }
                }
            }
        }
        return pos;
    }

    int[] getSelectPositions (string s) {
        int[] sp;
        bool inquotes = false;
        int lvl = 0;
        int pos = -1;
        int cpos = 0;
        string tok = "";
        foreach (c; s) {
            pos += 1;
            if (c == '\'') {
                inquotes = ! inquotes;
            }
            if (!inquotes) {
                if (c == ' ') {
                    if ((std.string.toLower(tok) == "select") && (lvl == 0)) {
                        sp ~= pos-6;
                    }
                    tok = "";
                } else {
                    if (c == '(') {
                        lvl += 1;
                    } else if (c == ')') {
                        lvl -= 1;
                    }
                    tok ~= c;
                }
            } else {
                tok ~= c;
            }
        }
        if ((std.string.toLower(tok) == "select") && (lvl == 0)) {
            sp ~= pos-6;
        }
        return sp;
    }

    long getStrPos(string s, string sub) {
        auto x = indexOf(toLower(s),toLower(sub));
        if (x != -1 && count(s[0..x],'(') == count(s[0..x],')') && (count(s[0..x],'\'') % 2 == 0) ) {
            return x;
        } else {
            return -1;
        }
    }


    string[] getCommaFields (string s) {
        string[] toks = [];
        bool inquotes = false;
        bool inparens = false;
        string tok = "";
        int pos = -1;
        int lvl = 0;
        foreach (c; strip(s)) {
            pos += 1;
            if (c == '\'') {
                inquotes = ! inquotes;
            }
            if (!inquotes) {
                tok ~= c;
                /*if (c != ' ') {
                    tok ~= c;
                }*/
                if (c == '(') {
                    lvl += 1;
                } else if (c == ')') {
                    lvl -= 1;
                } else if ((c == ',') && (lvl == 0)) {
                    toks ~= tok;
                    tok = "";
                }
            } else {
                tok ~= c;
            }
        }
        if (tok.length > 0) {
            toks ~= tok;
        }
        return toks;
    }
}

SToken[] pruneToks(SToken[] toks) {
    SToken[] ptoks;
    foreach (i,t; toks) {
        if (!(strip(t.tok) == "" && strip(toks[i-1].tok)[$-1..$] == ",")) {
            ptoks ~= t;
        }
    }
    return ptoks;
}

int selectMinDepth(SToken[] toks) {
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

SToken[] tokenizeDefinition(string s) {
    SToken[] toks;
    int depth = 0;
    bool inquotes = false;
    SToken t;
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
    SToken[] toks = tokenizeDefinition(vd);
    debug {
        writeln("=====\nview ",v, " selMinDepth=",selectMinDepth(toks));
        foreach (t; toks) {
            writeln(leftJustify("",t.depth*2),t.tok);
        }
    }
}

long indexOfStr(string s, string chk) {
    char[] s2 = s.dup;
    bool inquotes, inparen;
    ulong pos;
    int lvl;
    for (auto i=0; i<s2.length; i++) {
        if (s2[i] == '\'') {
            inquotes = ! inquotes;
        }
        if (!inquotes) {
            if (s2[i] == '(') {
                lvl += 1;
            } else if (s2[i] == ')') {
                lvl -= 1;
            }
            if (lvl != 0) {
                s2[i] = '~';
            }
        } else {
            s2[i] = '~';
        }
    }
    return indexOf(s2, chk, No.caseSensitive);
}

ulong[] getSelectPositions (string s) {
    ulong[] sp;
    bool inquotes = false;
    int lvl = 0;
    int pos = -1;
    int cpos = 0;
    string tok = "";
    foreach (c; s) {
        pos += 1;
        if (c == '\'') {
            inquotes = ! inquotes;
        }
        if (!inquotes) {
            if (c == ' ') {
                if ((std.string.toLower(tok) == "select") && (lvl == 0)) {
                    sp ~= pos-6;
                }
                tok = "";
            } else {
                if (c == '(') {
                    lvl += 1;
                } else if (c == ')') {
                    lvl -= 1;
                }
                tok ~= c;
            }
        } else {
            tok ~= c;
        }
    }
    if ((std.string.toLower(tok) == "select") && (lvl == 0)) {
        sp ~= pos-6;
    }
    return sp;
}

string[] getCommaFields (string s) {
    string[] toks = [];
    bool inquotes = false;
    bool inparens = false;
    string tok = "";
    int pos = -1;
    int lvl = 0;
    foreach (c; strip(s)) {
        pos += 1;
        if (c == '\'') {
            inquotes = ! inquotes;
        }
        if (!inquotes) {
            tok ~= c;
            if (c == '(') {
                lvl += 1;
            } else if (c == ')') {
                lvl -= 1;
            } else if ((c == ',') && (lvl == 0)) {
                toks ~= tok;
                tok = "";
            }
        } else {
            tok ~= c;
        }
    }
    if (tok.length > 0) {
        toks ~= tok;
    }
    return toks;
}

Desc[][string] desc;
string[string] sel;

void main(string[] args) {
    auto opts = getopt(args, "text", &textmode);
    if (!textmode) {
        writeln("<doctype html>\n<html>\n<head>\n<title>fixed views definitions\n</title>\n");
        writeln("<style>\n");
        writeln(q""pre .fu, pre .co,pre .kwd{font-weight:700}
pre {display:block;background-color:#fff}
pre .nocode{background-color:none;color:#fff}
pre .str{color:#333}
pre .kwd{color:#07c}
pre .co{color:#2a2}
pre .typ{color:#98fb98}
pre .fun{color:#3d2c2c}
pre .pln,pre .pun{color:#fff}
pre .tag{color:khaki}
pre .atn{color:#bdb76b}
pre .atv{color:#ffa0a0}
pre .dec{color:#98fb98}
"");
        writeln("</style>\n");
        writeln("</head>\n<body>\n");
        writeln("<pre><code>\n");
    }
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
    ulong[] selpos;

    ulong getPaddingLength(string s) {
        ulong res = 4;
        if (s.length < 40) {
            res = 40 - s.length;
        } else if (s.length < 60) {
            res = 60 - s.length;
        } else if (s.length < 80) {
            res = 80 - s.length;
        }
        return res;
    }

    void printField(string f, int offset=0, Desc d=Desc()) {
        string[] dtoks;
        ulong padlen;
        long commentBeg = indexOf(f,"/*");
        long commentEnd = indexOf(f,"*/");
        if (commentBeg != -1) {
            if (textmode) {
                writeln(" ".replicate(offset),f[commentBeg..commentEnd+2]);
            } else {
                writeln(" ".replicate(offset),"<span class=\"co\">",f[commentBeg..commentEnd+2],"</span>");
            }
            f = strip(f[commentEnd+2..$]);
        }
        if (startsWith(toLower(f),"decode")) {
            f = f.replace("decode ","decode");
            dtoks = getCommaFields(f[7..$-2]);
            padlen = getPaddingLength(" ".replicate(offset)~f[0..7]~dtoks[0]);
            if (textmode) {
                writeln(" ".replicate(offset),f[0..7],dtoks[0]," ".replicate(padlen),"-- ",d.nam," ",d.typ);
            } else {
                writeln(" ".replicate(offset),"<span class=\"fu\">",f[0..7],"</span>",dtoks[0]," ".replicate(padlen),"<span class=\"co\">-- ",d.nam," ",d.typ,"</span>");
            }
            for (auto i=1;i < dtoks.length-1; i += 2) {
                writeln(" ".replicate(offset+2),strip(dtoks[i])," ",strip(dtoks[i+1]));
            }
            if (dtoks.length % 2 == 0) {
                if (dtoks.length > 1 && strip(dtoks[$-1])[$-1] == ')') {
                    writeln(" ".replicate(offset+2),strip(dtoks[$-1]));
                } else {
                    std.stdio.write(" ".replicate(offset+2),strip(dtoks[$-1]));
                }
            }

            if (dtoks.length > 1 && strip(dtoks[$-1])[$-1] == ')') {
                writeln(" ".replicate(offset),f[$-2..$]);
            } else {
                writeln(f[$-2..$]);
            }
            /*
        } else if (startsWith(toLower(f),"to_number")) {
            if (f.length > MAXLEN) {
                padlen = getPaddingLength(" ".replicate(offset)~f[0..10]);
                writeln(" ".replicate(offset),f[0..10]," ".replicate(padlen),"-- ",d.nam," ",d.typ,"\n    ",f[10..$]);
            } else {
                padlen = getPaddingLength(" ".replicate(offset)~f);
                writeln(" ".replicate(offset),f," ".replicate(padlen),"-- ",d.nam, " ", d.typ);
            }
            */
        } else if (startsWith(toLower(f),"to_date")
                    || startsWith(toLower(f),"to_timestamp")
                    || startsWith(toLower(f),"to_number")
                    || startsWith(toLower(f),"substr")
                    || startsWith(toLower(f),"floor")
                    || startsWith(toLower(f),"round")
                    || startsWith(toLower(f),"abs")
                    || startsWith(toLower(f),"nvl")) {
            long startind;
            if (startsWith(toLower(f),"to_date")) {
                startind = 8;
            } else if (startsWith(toLower(f),"to_timestamp")) {
                startind = 13;
            } else if (startsWith(toLower(f),"to_number")) {
                startind = 10;
            } else if (startsWith(toLower(f),"substr")) {
                startind = 7;
            } else if (startsWith(toLower(f),"floor") || startsWith(toLower(f),"round")) {
                startind = 6;
            } else if (startsWith(toLower(f),"abs") || startsWith(toLower(f),"nvl")) {
                startind = 4;
            }
            if (f.length > MAXLEN) {
                dtoks = getCommaFields(f[startind..$-2]);
                if (strip(dtoks[0]).length + offset + startind > MAXLEN) {
                    padlen = getPaddingLength(" ".replicate(offset)~f[0..startind]);
                    if (textmode) {
                        writeln(" ".replicate(offset),f[0..startind]," ".replicate(padlen),"-- ",d.nam," ",d.typ);
                        write(" ".replicate(offset+2)~strip(dtoks[0]));
                    } else {
                        writeln(" ".replicate(offset),"<span class=\"fu\">",f[0..startind],"</span>"," ".replicate(padlen),"<span class=\"co\">-- ",d.nam," ",d.typ,"</span>");
                        write(" ".replicate(offset+2)~strip(dtoks[0]));
                    }
                    foreach (el;dtoks[1..$]) {
                        write(strip(el));
                    }
                } else {
                    padlen = getPaddingLength(" ".replicate(offset)~f[0..startind]~strip(dtoks[0]));
                    if (textmode) {
                        writeln(" ".replicate(offset),f[0..startind],strip(dtoks[0])," ".replicate(padlen),"-- ",d.nam," ",d.typ);
                    } else {
                        writeln(" ".replicate(offset),"<span class=\"fu\">",f[0..startind],"</span>",strip(dtoks[0]),
                                " ".replicate(padlen),"<span class=\"co\">-- ",d.nam," ",d.typ,"</span>");
                    }
                    write(" ".replicate(offset+2));
                    foreach (el;dtoks[1..$]) {
                        write(strip(el));
                    }
                }
                writeln(f[$-2..$]);
            } else {
                padlen = getPaddingLength(" ".replicate(offset)~f);
                if (textmode) {
                    writeln(" ".replicate(offset),f," ".replicate(padlen),"-- ",d.nam," ",d.typ);
                } else {
                    writeln(" ".replicate(offset),"<span class=\"fu\">",f,"</span>"," ".replicate(padlen),"<span class=\"co\">-- ",d.nam," ",d.typ,"</span>");
                }
            }
        } else if (startsWith(toLower(f),"case")) {
            bool case2comment = true;
            dtoks = split(f);
            if (textmode) {
                std.stdio.write(" ".replicate(offset),strip(dtoks[0])," ");
            } else {
                std.stdio.write(" ".replicate(offset),"<span class=\"kwd\">",strip(dtoks[0]),"</span> ");
            }
            foreach (el;dtoks[1..$]) {
                if (strip(toLower(el)) in ["when":0]) {
                    if (case2comment) {
                        padlen = getPaddingLength(" ".replicate(offset)~strip(dtoks[0])~" ");
                        if (textmode) {
                            std.stdio.write(" ".replicate(padlen),"-- ",d.nam, " ",d.typ);
                        } else {
                            std.stdio.write(" ".replicate(padlen),"<span class=\"co\">-- ",d.nam, " ",d.typ,"</span>");
                        }
                        case2comment = false;
                    }
                    if (textmode) {
                        std.stdio.write("\n"," ".replicate(offset+2),strip(el)," ");
                    } else {
                        std.stdio.write("\n"," ".replicate(offset+2),"<span class=\"kwd\">",strip(el),"</span> ");
                    }
                } else if (strip(toLower(el)) in ["then":1,"else":2]) {
                    if (textmode) {
                        std.stdio.write("\n"," ".replicate(offset+2),strip(el)," ");
                    } else {
                        std.stdio.write("\n"," ".replicate(offset+2),"<span class=\"kwd\">",strip(el),"</span> ");
                    }
                } else if (strip(toLower(el)) == "end,") {
                    if (textmode) {
                        std.stdio.write("\n"," ".replicate(offset),strip(el));
                    } else {
                        std.stdio.write("\n"," ".replicate(offset),"<span class=\"kwd\">",strip(el),"</span>");
                    }
                } else if (toLower(el) == "end") {
                    if (textmode) {
                        std.stdio.write("\n"," ".replicate(offset),strip(el),"\n  ");
                    } else {
                        std.stdio.write("\n"," ".replicate(offset),"<span class=\"kwd\">",strip(el),"</span>\n  ");
                    }
                } else {
                    std.stdio.write(el," ");
                }
            }
            writeln("");
        } else {
            padlen = getPaddingLength(" ".replicate(offset)~f);
            if (textmode) {
                writeln(" ".replicate(offset),f," ".replicate(padlen),"-- ",d.nam," ",d.typ);
            } else {
                writeln(" ".replicate(offset),f," ".replicate(padlen),"<span class=\"co\">-- ",d.nam," ",d.typ,"</span>");
            }
        }
    }

    void printSelectFields(string s, long pos2, int offset=0, Desc[] vdesc=[]) {
        if (textmode) {
            writeln(" ".replicate(offset),s[0..7]);
        } else {
            writeln(" ".replicate(offset),"<span class=\"kwd\">",s[0..7],"</span>");
        }
        auto selfields = getCommaFields(s[7..pos2-1]);
        foreach (ind,f; selfields) {
            f = strip(f);
            printField(f,offset+2,vdesc[ind]);
        }
        //writeln(" ".replicate(offset+2),s[7..pos2-1]);
    }

    void printFromClause(string s, long pos1, long pos2, int offset=0) {
        if (pos1 == -1) return;

        if (textmode) {
            writeln(" ".replicate(offset),s[pos1..pos1+5]);
        } else {
            writeln(" ".replicate(offset),"<span class=\"kwd\">",s[pos1..pos1+5],"</span>");
        }
        writeln(" ".replicate(offset+2),s[pos1+5..pos2]);
    }

    void printWhereClause(string s, long pos1, long pos2, int offset=0) {
        if (pos1 == -1) return;

        if (textmode) {
            writeln(" ".replicate(offset),s[pos1..pos1+6]);
        } else {
            writeln(" ".replicate(offset),"<span class=\"kwd\">",s[pos1..pos1+6],"</span>");
        }
        writeln(" ".replicate(offset+2),s[pos1+6..pos2]);
    }

    void printGroupbyClause(string s, long pos1, long pos2, int offset=0) {
        if (pos1 == -1) return;

        if (textmode) {
            writeln(" ".replicate(offset),s[pos1..pos1+9]);
        } else {
            writeln(" ".replicate(offset),"<span class=\"kwd\">",s[pos1..pos1+9],"</span>");
        }
        writeln(" ".replicate(offset+2),s[pos1+9..pos2]);
    }

    void printHavingClause(string s, long pos1, long pos2, int offset=0) {
        if (pos1 == -1) return;

        if (textmode) {
            writeln(" ".replicate(offset),s[pos1..pos1+7]);
        } else {
            writeln(" ".replicate(offset),"<span class=\"kwd\">",s[pos1..pos1+7],"</span>");
        }
        writeln(" ".replicate(offset+2),s[pos1+7..pos2]);
    }

    void printOrderbyClause(string s, long pos1, long pos2, int offset=0) {
        if (pos1 == -1) return;

        if (textmode) {
            writeln(" ".replicate(offset),s[pos1..pos1+9]);
        } else {
            writeln(" ".replicate(offset),"<span class=\"kwd\">",s[pos1..pos1+9],"</span>");
        }
        writeln(" ".replicate(offset+2),s[pos1+9..pos2]);
    }

    void printUnionallClause(string s, long pos1,long pos2, int offset=0) {
        if (pos1 == -1) return;

        if (textmode) {
            writeln(s[pos1..pos1+10]);
        } else {
            writeln("<span class=\"kwd\">",s[pos1..pos1+10],"</span>");
        }
        if (pos1+10 != pos2) {
            writeln(" ".replicate(offset),s[pos1+10..pos2]);
        }
    }

    void printSelect(string v, string vd, int offset=0) {
        long frompos,wherepos,unionallpos,orderbypos,groupbypos,havingpos;
        frompos = indexOfStr(vd,"from ");
        wherepos = indexOfStr(vd,"where ");
        unionallpos = indexOfStr(vd,"union all ");
        groupbypos = indexOfStr(vd,"group by ");
        havingpos = indexOfStr(vd,"having ");
        orderbypos = indexOfStr(vd,"order by ");

        auto poses = [frompos,wherepos,unionallpos,groupbypos,havingpos,orderbypos];
        
        long[] pa2;
        long pos2;
        
        pa2 = poses.filter!(a=>a>-1).array;
        pos2 = (pa2.length > 0) ? pa2.minElement : vd.length;
        printSelectFields(vd,pos2,offset,desc[v]);

        pa2 = poses.filter!(a=>a>frompos).array; pos2 = (pa2.length > 0) ? pa2.minElement : vd.length;
        printFromClause(vd,frompos,pos2,offset);

        pa2 = poses.filter!(a=>a>wherepos).array; pos2 = (pa2.length > 0) ? pa2.minElement : vd.length;
        printWhereClause(vd,wherepos,pos2,offset);

        pa2 = poses.filter!(a=>a>groupbypos).array; pos2 = (pa2.length > 0) ? pa2.minElement : vd.length;
        printGroupbyClause(vd,groupbypos,pos2,offset);

        pa2 = poses.filter!(a=>a>havingpos).array; pos2 = (pa2.length > 0) ? pa2.minElement : vd.length;
        printHavingClause(vd,havingpos,pos2,offset);

        pa2 = poses.filter!(a=>a>orderbypos).array; pos2 = (pa2.length > 0) ? pa2.minElement : vd.length;
        printOrderbyClause(vd,orderbypos,pos2,offset);

        pa2 = poses.filter!(a=>a>unionallpos).array; pos2 = (pa2.length > 0) ? pa2.minElement : vd.length;
        printUnionallClause(vd,unionallpos,pos2,offset);
    }

    foreach (v,vd; sel) {
        selpos = getSelectPositions(vd);
        selpos ~= vd.length;
        writeln("\n*** ",v, ":",vd,"\n");
        foreach (i,a1; selpos[0..$-1]) {
            auto a2 = selpos[i+1];
            printSelect(v,vd[a1..a2]);
        }
    }

    debug {
        int[] selpos, frompos, wherepos;
        string[] dtoks;
        long commentBeg, commentEnd;
        foreach (v,vd; sel) {
            Interpreter ip = new Interpreter(vd);
            selpos = ip.getSelectPositions(vd);
            selpos ~= cast(int)vd.length;
            writeln("\n*** ",v); // ,":",vd,"\n");
            foreach (i,a1; selpos[0..$-1]) {
                auto a2 = selpos[i+1];
                auto frompos = ip.getStrPosition(vd[a1..a2],"from");
                auto wherepos = ip.getStrPosition(vd[a1..a2],"where");
                auto selfields = ip.getCommaFields(vd[a1+6..a1+frompos]);
                writeln(vd[a1..a1+6]); // select
                //writeln("*** wherepos, a1, a2 ***",wherepos," ",a1, " ",a2);
                foreach (f; selfields) {
                    f = strip(f);
                    commentBeg = indexOf(f,"/*");
                    commentEnd = indexOf(f,"*/");
                    if (commentBeg != -1) {
                        writeln("  ",f[commentBeg..commentEnd+2]);
                        f = strip(f[commentEnd+2..$]);
                    }
                    if (startsWith(toLower(f),"decode")) {
                        f = f.replace("decode ","decode");
                        dtoks = ip.getCommaFields(f[7..$-2]);
                        writeln("  ",f[0..7],dtoks[0]);
                        for (i=1;i < dtoks.length-1; i += 2) {
                            writeln("    ",strip(dtoks[i])," ",strip(dtoks[i+1]));
                        }
                        if (dtoks.length % 2 == 0) {
                            writeln("    ",strip(dtoks[$-1]));
                        }
                        writeln("  ",f[$-2..$]);
                    } else if (startsWith(toLower(f),"to_number")) {
                        if (f.length > MAXLEN) {
                            writeln("  ",f[0..10],"\n    ",f[10..$]);
                        } else {
                            writeln("  ",f);
                        }
                    } else if (startsWith(toLower(f),"to_date")) {
                        if (f.length > MAXLEN) {
                            dtoks = ip.getCommaFields(f[8..$-2]);
                            writeln("  ",f[0..8],strip(dtoks[0]));
                            write("    ");
                            foreach (el;dtoks[1..$]) {
                                write(strip(el));
                            }
                            //writeln("    ",join(dtoks[1..$]));
                            writeln(f[$-2..$]);
                        } else {
                            writeln("  ",f);
                        }
                    } else if (startsWith(toLower(f),"case")) {
                        dtoks = split(f);
                        std.stdio.write("  ",strip(dtoks[0])," ");
                        foreach (el;dtoks[1..$]) {
                            if (strip(toLower(el)) in ["when":0,"then":1,"else":2]) {
                                std.stdio.write("\n    ",strip(el)," ");
                            } else if (strip(toLower(el)) == "end,") {
                                std.stdio.write("\n  ",strip(el));
                            } else if (toLower(el) == "end") {
                                std.stdio.write("\n  ",strip(el),"\n  ");
                            } else {
                                std.stdio.write(el," ");
                            }
                        }
                        writeln("");
                    } else {
                        writeln("  ",f);
                    }
                }
                //writeln("",vd[a1+frompos..a1+wherepos]);
                auto fromtabs = ip.getCommaFields(vd[a1+frompos+4..a1+wherepos]);
                writeln(vd[a1+frompos..a1+frompos+4]);
                foreach (t; fromtabs) {
                    t = strip(t);
                    if (t != "") {
                        auto nlpos = ip.getStrPos(t,"union all");
                        if (nlpos != -1) {
                            t = t[0..nlpos] ~ "\n" ~ t[nlpos..$];
                        }
                        nlpos = ip.getStrPos(t,"group by ");
                        if (nlpos != -1) {
                            t = t[0..nlpos] ~ "\n" ~ t[nlpos..nlpos+8] ~ "\n  " ~ strip(t[nlpos+8..$]);
                        }
                        nlpos = ip.getStrPos(t,"order by ");
                        if (nlpos != -1) {
                            t = t[0..nlpos] ~ "\n" ~ t[nlpos..nlpos+8] ~ "\n  " ~ strip(t[nlpos+8..$]);
                        }
                        nlpos = ip.getStrPos(t,"having ");
                        if (nlpos != -1) {
                            t = t[0..nlpos] ~ "\n" ~ t[nlpos..$];
                        }
                        if (t[0] == '(') {
                            auto rppos = ip.getRightParenPos(t);
                            writeln("  (");
                            writeln("    ",strip(t[1..rppos]));
                            writeln("  ",t[rppos..$]);
                        } else {
                            writeln("  ",t);
                        }
                    }
                }
                if (a1+wherepos != a2) {
                    string wherestr = vd[a1+wherepos..a2];
                    writeln(wherestr[0..5]);
                    auto nlpos = ip.getStrPos(wherestr,"group by ");
                    if (nlpos != -1) {
                        wherestr = wherestr[0..nlpos] ~ "\n" ~ wherestr[nlpos..$];
                    }
                    nlpos = ip.getStrPos(wherestr,"order by ");
                    if (nlpos != -1) {
                        wherestr = wherestr[0..nlpos] ~ "\n" ~ wherestr[nlpos..$];
                    }
                    nlpos = ip.getStrPos(wherestr,"having ");
                    if (nlpos != -1) {
                        wherestr = wherestr[0..nlpos] ~ "\n" ~ wherestr[nlpos..$];
                    }
                    nlpos = ip.getStrPos(wherestr,"union all");
                    if (nlpos != -1) {
                        wherestr = wherestr[0..nlpos] ~ "\n" ~ wherestr[nlpos..$];
                    }
                    writeln("  ",strip(wherestr[5..$]));
                    /* uapos = ip.getStrPos(wherestr,"union all");
                    if (uapos != -1) {
                        while (uapos != -1) {
                            writeln("  ",strip(wherestr[5..uapos]));
                            writeln(strip(wherestr[uapos..uapos+9]));
                            wherestr = wherestr[uapos+9..$].dup;
                            uapos = ip.getStrPos(wherestr,"union all");
                        }
                    } else {
                        writeln("  ",strip(wherestr[5..$]));
                    } */
                    //writeln("",vd[a1+wherepos..a2]);
                }
            }
            //writeln("  selpos:",selpos, );
        }
    }
    /*
    foreach (view,vdef; sel) {
        generateHtml(view,vdef);
    }
    */
    if (!textmode) {
        writeln("</code></pre>");
        writeln("</body>\n</html>\n");
    }
}

