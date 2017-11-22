// generate html files for every fixed view

import std.stdio, std.string, std.conv, std.file;
import std.uni : toLower;
import std.algorithm;

const int MAXLEN = 42;

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
}

