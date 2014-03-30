/**
LEDCubeの点灯パターン作成用のD言語ライブラリ<br>
次のようなことが可能です。以下の例ではx=y=zとなる対角線上のLEDを点灯させます。
Example:
---------------------------------------------------------
import mydutil.ledcube.framework;
pragma(lib,"mydutil");

void main(){
    style_0();
}

void style_0(){ //壁が移動する。
    Ledcube[] fs;
    fs.length = 48;
    foreach(i, ref f; fs){
        f = Ledcube(8, 8, 8);     //8x8x8の大きさで1フレーム作成
        foreach(v, ref b; f){     //各フレームはforeachでループ可能
            if(i < 16){
                if(v[0] == (i % 8))   //vはタプル$(LINK2 http://www.kmonos.net/alang/d/2.0/phobos/std_typecons.html#Tuple , std.typecons.Tuple)!(int,int,int)で、(x,y,z)
                    b = true;       //bは光っているかどうか
            }else if(16 <= i && i < 32){
                if(v[1] == (i % 8))
                    b = true;
            }else{
                if(v[2] == (i % 8))
                    b = true;
            }
        }
    }
    
    Ledcube[] dst;
    foreach(i, efs; fs){
        foreach(j; 0..5)
            dst ~= efs;
    }
    
    blcOut(dst, "style_0.blc");
}
---------------------------------------------------------
*/

module mydutil.ledcube.framework;

import std.math             : sin,cos;
import std.stdio            : File, writeln;
import std.typecons         : Tuple, tuple;

import mydutil.arith.linear   : Vector, Matrix;
import mydutil.file.csv       : isCSVin;
import mydutil.util.bits      : BitList;
import mydutil.util.tmp       : Trans;

version(unittest){
    pragma(lib,"mydutil");
    void main(){
        writeln("Unittest End");
    }
}

/**3次元のベクトルを作ります。$(LINK2 http://dl.dropbox.com/u/71366740/linear.html ,mydutil.arith.linear.Vector)を返します。
Example:
---
auto v = vector(0,1,2);

assert(v[0] == 0);
assert(v[1] == 1);
assert(v[2] == 2);
---
*/
Vector!T vector(T)(T x,T y,T z){
    Vector!T dst;
    dst.length = 3;
    dst[0] = x;
    dst[1] = y;
    dst[2] = z;
    return dst;
}

/++
LedCubeの状態(1フレーム)を保持しておくための構造体
+/
struct Ledcube{
private:
    BitList[][] _val;
    
    invariant(){
        size_t size;
        for(int i=0;i<_val.length;++i){
            if(i == 0)
                size = _val[0].length;
            else
                assert(size == _val[i].length);
        }
        
        for(int i=0;i<_val.length;++i)
            for(int j=0;j<_val[i].length;++j){
                if(i == 0 && j == 0)
                    size = _val[0][0].length;
                else
                    assert(size == _val[i][j].length);
            }
    }

public:
    /** コンストラクタ
    * Example:
    * ------------------------------
    * auto A = Ledcube(8,8,8);  //これでAは(x,y,z)=(8x8x8)のキューブ
    * ------------------------------
    */
    this(int x,int y,int z){
        _val.length = x;
        foreach(i; 0..x){
            _val[i].length = y;
            foreach(j; 0..y){
                _val[i][j].length = z;
            }
        }
    }

//演算子オーバーロード    
    /** インデックスアクセス可能
    * Example:
    * ------------------------------
    * auto A = Ledcube(8,8,8);
    * A[0,1,2] = true;
    * assert(A[0,1,2]);
    * assert(!A[0,1,3]);
    * ------------------------------
    */
    bool opIndex(int x,int y,int z){
        return _val[x][y][z];
    }
    unittest{
        auto A = Ledcube(8,8,8);
        A[0,1,2] = true;
        assert(A[0,1,2]);
        assert(!A[0,1,3]);
    }
    
    ///ditto
    bool opIndexAssign(bool b,int x,int y,int z){
        return (_val[x][y][z] = b);
    }
    
    /** ベクトル型でアクセス可能
    * Example:
    * ------------------------------
    * auto A = Ledcube(8,8,8);
    * auto v = vector(0,1,2);
    * A[v] = true;
    * assert(A[v]);
    * assert(A[vector(0,1,2)]);
    * ------------------------------
    */
    bool opIndex(Vector!int v)
    in{assert(v.length == 3);}
    body{
        if(v[0] < length!"x" && v[1] < length!"y" && v[2] < length!"z"
                    && v[0] >= 0 && v[1] >= 0 && v[2] >= 0)
            return _val[v[0]][v[1]][v[2]];
        else
            return false;
    }
    unittest{
        auto A = Ledcube(8,8,8);
        auto v = vector(0,1,2);
        A[v] = true;
        assert(A[v]);
        assert(A[vector(0,1,2)]);
    }
    
    ///ditto
    bool opIndexAssign(bool b,Vector!int v)
    in{assert(v.length == 3);}
    body{
        if(v[0] < length!"x" && v[1] < length!"y" && v[2] < length!"z"
                    && v[0] >= 0 && v[1] >= 0 && v[2] >= 0)
            return (_val[v[0]][v[1]][v[2]] = b);
        else
            return false;
    }
    
    /** ビットごとのOR,AND,XORが可能。Ledcube型とVector!int[]型に適応可能
    * Example:
    * ------------------------------
    * auto A = Ledcube(8,8,8);
    * auto B = Ledcube(8,8,8);
    * A[0,0,0] = true;
    * A[0,0,1] = true;
    * B[0,0,0] = true;
    * B[0,0,1] = false;
    *
    * assert((A|B)[0,0,0]);
    * assert((A|B)[0,0,1]);
    * 
    * assert((A&B)[0,0,0]);
    * assert(!(A&B)[0,0,1]);
    * 
    * assert(!(A^B)[0,0,0]);
    * assert((A^B)[0,0,1]);
    * 
    * auto v = [vector(0,0,1),vector(0,0,2)];
    * 
    * assert((A|v)[0,0,0]);
    * assert((A|v)[0,0,1]);
    * assert((A|v)[0,0,2]);
    * //以下同様にAND,XORも可能
    * ------------------------------
    */
    typeof(this) opBinary(string s,T)(T src)if(s.isCSVin("|,&,^") && (is(T == typeof(this)) || is(T == Vector!int[])))
    in{
        static if(is(T == typeof(this))){
            assert(src.length!"x" == length!"x");
            assert(src.length!"y" == length!"y");
            assert(src.length!"z" == length!"z");
        }else static if(is(T == Vector!int[])){
            assert(src.length != 0);
        }else{
            static assert(0);
        }
    }
    body{
        static if(is(T == typeof(this))){
            auto dst = Ledcube(length!"x",length!"y",length!"z");
            
        
            
            //for(int i=0;i<length!"x";++i)
            //    for(int j=0;j<length!"y";++j)
            foreach(i; 0..length!"x") foreach(j; 0..length!"y")
                    mixin("dst._val[i][j] = _val[i][j]"~s~"src._val[i][j];");
        }else{
            static if(s == "&"){
                Ledcube dst = Ledcube(length!"x",length!"y",length!"z");
            }else{
                Ledcube dst = Ledcube(length!"x",length!"y",length!"z");
                foreach(i, v; _val)
                    foreach(j, a; v)
                        dst._val[i][j] = a.dup;
                
            }
        
            foreach(Vector!int v; src){
                assert(v.length == 3);
                if(v[0] < length!"x" && v[1] < length!"y" && v[2] < length!"z"
                    && v[0] >= 0 && v[1] >= 0 && v[2] >= 0){
                    static if(s == "&")
                        mixin("dst._val[v[0]][v[1]][v[2]] = _val[v[0]][v[1]][v[2]];");
                    else static if(s == "|")
                        mixin("dst._val[v[0]][v[1]][v[2]] = true;");
                    else
                        mixin("dst._val[v[0]][v[1]][v[2]] = !dst._val[v[0]][v[1]][v[2]];");
                }
            }
        }
        return dst;
    }
    unittest{
        auto A = Ledcube(8,8,8);
        auto B = Ledcube(8,8,8);
        A[0,0,0] = true;
        A[0,0,1] = true;
        B[0,0,0] = true;
        B[0,0,1] = false;

        assert((A|B)[0,0,0]);
        assert((A|B)[0,0,1]);

        assert((A&B)[0,0,0]);
        assert(!(A&B)[0,0,1]);

        assert(!(A^B)[0,0,0]);
        assert((A^B)[0,0,1]);

        auto v = [vector(0,0,1),vector(0,0,2)];

        assert((A|v)[0,0,0]);
        assert((A|v)[0,0,1]);
        assert((A|v)[0,0,2]);

        assert(!(A&v)[0,0,0]);
        assert((A&v)[0,0,1]);
        assert(!(A&v)[0,0,2]);

        assert((A^v)[0,0,0]);
        assert(!(A^v)[0,0,1]);
        assert((A^v)[0,0,2]);
    }
    
    /** 各点灯状態を反転させる
    * Example:
    * ------------------------------
    * auto A = Ledcube(8,8,8);
    * A[0,0,0] = true;
    * 
    * assert(!(~A)[0,0,0]);
    * assert((~A)[0,0,1]);
    * ------------------------------
    */
    typeof(this) opUnary(string s:"~")(){
        auto dst = Ledcube(length!"x",length!"y",length!"z");
        for(int i=0;i<length!"x";++i)
            for(int j=0;j<length!"y";++j)
                dst._val[i][j] = ~_val[i][j];
                
        return dst;
    }
    unittest{
        auto A = Ledcube(8,8,8);
        A[0,0,0] = true;
        
        assert(!((~A)[0,0,0]));
        assert((~A)[0,0,1]);
    }
    
    /** 代入演算子により、Ledcube型とVector!int[]型を代入できる。
    * Example:
    * ------------------------------
    * auto A = Ledcube(8,8,8);
    * A = [vector(0,0,1),vector(0,0,9)];    //ここで(0,0,9)は範囲外なので無視される。
    * assert(A[0,0,1]);
    * 
    * auto B = Ledcube(8,8,8);
    * B[0,0,2] = true;
    * A = B;
    * assert(!A[0,0,1]);
    * assert(A[0,0,2]);
    * ------------------------------
    */
    typeof(this) opAssign(T)(T src)if(is(T == typeof(this)) || is(T == Vector!int[])){
        static if(is(T == typeof(this))){
            _val.length = src._val.length;
            for(int i=0;i<src._val.length;++i){
                _val[i].length = src._val[i].length;
                for(int j=0;j<src._val[i].length;++j)
                    _val[i][j] = src._val[i][j].dup;
            }
            return this;
        }else{
            return opAssign(opBinary!"|"(src));
        }
    }
    unittest{
        auto A = Ledcube(8,8,8);
        A = [vector(0,0,1),vector(0,0,9)];    //ここで(0,0,9)は範囲外なので無視される。
        assert(A[0,0,1]);
        
        auto B = Ledcube(8,8,8);
        B[0,0,2] = true;
        A = B;
        assert(!A[0,0,1]);
        assert(A[0,0,2]);
        
        A[0,0,0] = true;
        assert(!B[0,0,0]);
    }
    
    /** foreach文で回せる
    * Example:
    * ------------------------------
    * auto LC = Ledcube(8, 8, 8);
    * foreach(v, ref b; LC)
    *     b = true;
    * foreach(v, b; LC)
    *     assert(b == LC[v.tupleof]);
    * ------------------------------
    */
    int opApply(int delegate(Tuple!(int,int,int),ref bool) dg){
        int result = 0;
        bool b;
        for(int i=0;i<length!"x";++i)
            for(int j=0;j<length!"y";++j)
                for(int k=0;k<length!"z";++k){
                    b = _val[i][j][k];
                    result = dg(tuple(i,j,k),b);
                    _val[i][j][k] = b;
                    if(result)
                        break;
                }
        return result;
    }
    unittest{
        auto a = Ledcube(8,8,8);
        foreach(v,ref b;a)
            b = true;
        foreach(v,b;a)
            assert(a[v.tupleof] == b);
    }
    
    
    ///等号演算子
    bool opEquals(typeof(this) src)
    in{
        assert(src.length!"x" == length!"x");
        assert(src.length!"y" == length!"y");
        assert(src.length!"z" == length!"z");
    }body{
        for(int i=0;i<length!"x";++i)
            for(int j=0;j<length!"y";++j)
                for(int k=0;k<length!"z";++k)
                    if(src[i,j,k] != this[i,j,k])
                        return false;
        return true;
    }
    
//プロパティ
    /** length!"x"でx軸というように、各大きさを取得する。設定はできない。
    * Example:
    * ------------------------------
    * auto A = Ledcube(8,7,6);
    * 
    * assert(A.length!"x" == 8);
    * assert(A.length!"y" == 7);
    * assert(A.length!"z" == 6);
    * ------------------------------
    */
    @property const size_t length(string s)(){
        static if(s == "x")
            return _val.length;
        else static if(s == "y")
            return _val[0].length;
        else static if(s == "z")
            return _val[0][0].length;
        else
            static assert(0,"length!"~s~" is not defined.");
    }
    unittest{
        auto a = Ledcube(3,4,5);
        assert(a.length!"x" == 3);
        assert(a.length!"y" == 4);
        assert(a.length!"z" == 5);
    }
    
//その他のメンバ関数
    /**　転置を返す。sには"x","y","z"のいずれか。tには"x","-x","y","-y","z","-z"のいずれかを指定できます。
    *
    * Example:
    * ------------------------------
    * auto a = ledcube(3,4,5);
    * a[0,1,2] = true;
    * auto b = a.trans!("x","z");   //x軸とz軸を入れ替える形で転置を返します。
    * assert(b[2,1,0]);
    * auto c = a.trans!("x","-x");  //x軸の正負を入れ替えた転置を返します。(実際にはx = length!"x" - x -1となるような置換)
    * assert(c[2,1,2]);
    * auto d = a.trans!("x","-y");  //a.trans!("y","-y").trans!("x","y")と同じ
    * assert(d[2,0,2]);
    * ------------------------------
    */
    @property typeof(this) trans(string s,string t)()
    if(s.isCSVin("x,y,z") && t.isCSVin("x,-x,y,-y,z,-z")){
        static if(t.length == 2){
            static if(t[1] == 'x')
                enum _x="$-1-x",_y="y",_z="z";
            else static if(t[1] == 'y')
                enum _x="x",_y="$-1-y",_z="z";
            else static if(t[1] == 'z')
                enum _x="x",_y="y",_z="$-1-z";
            
            alias Trans!(s[0]-'x',t[1]-'x',_x,_y,_z) tup;
            alias Trans!(s[0]-'x',t[1]-'x',"length!\"x\"","length!\"y\"","length!\"z\"") sizetuple;
        }else{
            alias Trans!(s[0]-'x',t[0]-'x',"x","y","z") tup;
            alias Trans!(s[0]-'x',t[0]-'x',"length!\"x\"","length!\"y\"","length!\"z\"") sizetuple;
        }
        
        mixin("
        auto dst = Ledcube("~sizetuple[0]~","~sizetuple[1]~","~sizetuple[2]~");
        for(int x=0;x<length!\"x\";++x)
            for(int y=0;y<length!\"y\";++y)
                for(int z=0;z<length!\"z\";++z)
                    dst._val["~tup[0]~"]["~tup[1]~"]["~tup[2]~"] = _val[x][y][z];
        ");
        return dst;
    }
    unittest{
        auto a = Ledcube(3,4,5);
        a[0,1,2] = true;
        auto b = a.trans!("x","z");
        assert(b[2,1,0]);
        auto c = a.trans!("x","-x");
        assert(c[2,1,2]);
        auto d = a.trans!("x","-y");
        assert(d[2,0,2]);
    }
}


/**3次元回転ベクトルを作る。
* Example:
* ---
* auto v = vector(1,2,3);
* auto rotm = rotMatrix!"x"(std.math.PI/2); //90度回転
* auto vs = rotm * v;   //vベクトルをx軸の回りに90度回転させる
* ---
*/
Matrix!F rotMatrix(string s,F = real)(F rad)if(s.isCSVin("x,y,z")){
    Matrix!F dst = Matrix!F(3,3,0.0);
    static if(s == "x"){
        dst[0][0] = 1;
        dst[1][1] = cos(rad);
        dst[1][2] = -sin(rad);
        dst[2][1] = -dst[1][2];
        dst[2][2] = dst[1][1];
    }else static if(s == "y"){
        dst[0][0] = cos(rad);
        dst[0][2] = sin(rad);
        dst[1][1] = 1;
        dst[2][0] = -dst[0][2];
        dst[2][2] = dst[0][0];
    }else{
        dst[0][0] = cos(rad);
        dst[0][1] = -sin(rad);
        dst[1][0] = -dst[0][1];
        dst[1][1] = dst[0][0];
        dst[2][2] = 1;
    }
    return dst;
}

///出力時の形式を制御します
enum LFOMenu : ubyte{
    errata = 0x1,    ///軸エラッタ
    compress = 0x2,    ///圧縮
}

/**
* Ledmatrix[]をCSV形式でファイルに出力する。
* Params:
*    Option =        LFOMenuで制御します。
*    src =         書き出し対象のLedmatrixの配列
*    filename =        書きだすファイルの名前
* Example:
* --------------------
* Ledmatrix[] foo;
* //fooに対する何らかの操作
* ~~~~~~~~~~~~~~~~~
* //ファイル書き込み
* CSVout!(true,true)(foo, "foo.csv")
* --------------------
*/
void ssvOut(ubyte Option = (LFOMenu.errata | LFOMenu.compress))(Ledcube[] src, string filename)
in{ assert(src.length);
    assert(src[0].length!"x");
    assert(src[0].length!"y");
    assert(src[0].length!"z");
}
body{
    scope file = File(filename,"w");
    string Ei34x = src.length > 0xFFF ? "%04x " : "%03x ";
    
    foreach(i,st;src){
        st = st.trans!("x","z");
        static if(Option & LFOMenu.compress){
            if(i != 0 && i != (src.length-1) && src[i-1] == src[i])
                continue;
            file.writef(Ei34x,i);
        }
        for(int z=0;z<st.length!"z";++z){
            //writeln(z);
            for(int y=0;y<st.length!"y";++y){
                static if(Option & LFOMenu.errata){
                    if(y&1)
                        file.writef("%x",st._val[z][y-1]);
                    else
                        file.writef("%x",st._val[z][y+1]);
                }else
                    file.writef("%x",st._val[z][y]);
                
                 if(y == ((st.length!"y")/2-1))
                    file.write(" ");
            }
            if(z != (st.length!"z" -1))file.write(" ");
        }
        file.write("\n");
    }
    writeln("File Output Done. File name is ",filename);
}

void blcOut(ubyte Option = (LFOMenu.errata | LFOMenu.compress))(Ledcube[] src, string filename)
in{ assert(src.length);
    assert(src[0].length!"x");
    assert(src[0].length!"y");
    assert(src[0].length!"z");
}
body{
    scope file = File(filename,"w");
    string Ei34x = src.length > 0xFFF ? "%04x " : "%03x ";
    
    foreach(ushort i,st;src){
        st = st.trans!("x","z");    //xyz→zyx
        
        static if(Option & LFOMenu.compress){
            if(i != 0 && i != (src.length-1) && src[i-1] == src[i])
                continue;
        }
        
        file.rawWrite([i]);
        for(int z=0;z<st.length!"x";++z){
            ulong t = 0;
            for(int y=0;y<st.length!"y";++y){
                static if(Option & LFOMenu.errata){
                    if(y&1){
                        for(int j=st._val[z][y-1].length-1;j>=0;--j){
                            t <<= 1;
                            if(st._val[z][y-1][j])
                                t |= 1;
                        }
                    }else{
                        for(int j=st._val[z][y+1].length-1;j>=0;--j){
                            t <<= 1;
                            if(st._val[z][y+1][j])
                                t |= 1;
                        }
                    }
                }else{
                    for(int j=st._val[z][y-1].length-1;j>=0;--j){
                            t <<= 1;
                            if(st._val[z][y][j])
                                t |= 1;
                    }
                }
            }
            file.rawWrite([t]);
        }
    }
    writeln("File Output Done. File name is ",filename);
}

/**ファイルをパースして辞書にして返す。
* Example:
* ------------------------------------
* auto fonts = parseFonts("ledfonts.txt");
* auto A = Ledcube(8, 8, 8);
* 
* foreach(v; fonts["A"])
*     A[0, v.tupleof] = 1;
* ------------------------------------
*/
Tuple!(int,int)[][string] parseFonts(uint X = 8,uint Y = 8)(string filename){
    auto fLine = File(filename,"r").byLine;
    Tuple!(int,int)[][string] dst;
    
    while(!fLine.empty){
        while(!fLine.empty && (fLine.front.length < 2 || fLine.front[1..2] != ":")){
            //writeln(fLine.front);
            fLine.popFront;
        }
        
        if(!fLine.empty){
            string label = cast(string)(fLine.front[0..1].dup);
            Tuple!(int,int)[] tmp;
            fLine.popFront;
            for(int y=Y-1;y>=0;--y,fLine.popFront)
                for(int x=0;x<X;++x)
                    if(fLine.front[x..x+1] == "1")
                        tmp ~= tuple(x,y);
                
            dst[label] = tmp;
        }
    }
    return dst;
}
