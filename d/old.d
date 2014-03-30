module mydutil.ledcube.old;

/+
last update is 2011/11/05
	・CSVoutをLedCubeの軸入れ替えに対応

・2011/10/29 & 30
	・dmd2.055 から　dmd2.056 に対応。
		・構造体のopEqualsのシグネチャ制限を解除(2.056から)
		・構造体のopCmpシグネチャ制限を解除(いつからできたの？)

	・Klaster
		・opCmpを追加。
		・opEqualsを修正。
		
	・myLedCube
		・LedMatrix に bool opIndex(Pos P);とbool opIndexAssign(bool val,Pos P)を追加
			ex.
				LedMatrix A = LedMatix(8,8,8);
				Pos X;	X.set(1,2,4);
				A[X] = true;
				assert(A[X] == A[1,2,4]);
				
		・クラスFontsを新規作成
			ex.
				Fonts Font = Fonts();	//これで初期化 Fonts.txtから情報を読み込む
				Fonts myFont = Fonts("myFonts.txt");	//myFonts.txtから読み込んだ情報でフォントを作成
				Font["A"];	//このように操作可能
				
				// Fonts == BitSet[string][]である。
				//つまり Font["A"]やFont["1"]はBitSet[]である。
				・ちなみに、もし同一Fontがtxt内で複数現れた場合、後に出てきたもので上書きされるので注意
		
		・LedMatrixに面についての配列演算子を追加
			ex.
				LedMatrix A = LedMatrix(4,4,4);
				auto B = A["x:yz",0];
				assert(typeof(B) == BitSet[]);	//A["xyz",0]の型はBitSet[]型
				A["x:yz",0] = (new Fonst())["A"];	//x=0の面にAを表示
				
				・説明
				""の中身の最初はx面かy面かz面かの選択。
				2番目3番目はBitSet[]はbool[][]に等しいので、
				bool[y][z]かbool[z][y]かを指定する必要があるため。
				つまりx=0の面をbool[y][z]で取得したい場合は
				A["x:yz",0]とすること。
		
		・LedMatrix << LedMatrix時のinvariantエラーを解決

・2011/10/26
	unittestを多少追加
	
・2011/10/22 と 23
	・そろそろ自分でも仕様を把握できなくなってきたので書いていく。
	・LedMatrixについて以下のような軸についての配列演算子を追加
		ex.
			LedMatrix A = LedMatrix(8,8,8);
			BitSet B = BitSet(0xFF);
			A["x-yz",1,1] = B;	//x軸に平行な直線(y,z) = (1,1)上にあるLEDの点灯情報はすべて点灯
			assert(A["x-yz",1,1] == B);
			A["x-yz",1,1] <<= 3;	//シフト
			A["x-yz",1,1] >>= 2;	//シフト
			A["x-yz",1,1] >>>= 3;	//右3bitローテート
			A["x-yz",1,1] >>>=-3;	//左3bitローテート
			A["x-yz",1,1] = A["y-zx",1,1] & A["z-xy",1,1];
			
			ちなみに"x-zy"などの代わりに"x:zy"というように-と:の両方を使える

+/

import std.stdio;
import std.array : popBack , popFront;
import std.bitmanip;
import std.ascii : isAlphaNum;
import std.conv	: roundTo;

//Triple!(int)の別名定義
alias Triple!(int) Pos;

struct LedMatrix{
	alias pattern this;
	
	//constractor
	this(int z, int y ,int bits){
		pattern.length = z;
		for(int i=0;i<z;i++){
			pattern[i].length = y;
			for(int j=0;j<y;j++)
				pattern[i][j] = BitSet(bits,false);
		}
	}
	this(int z,int y,int x,ubyte value){
		pattern.length = z;
		for(int i=0;i<z;i++){
			pattern[i].length = y;
			for(int j=0;j<y;j++){
				pattern[i][j] = BitSet(x,false);
				pattern[i][j] = value;
			}
		}
	}
	this(LedPlan p,ubyte value){
		pattern.length = p.zDim;
		for(int i=0;i<p.zDim;i++){
			pattern[i].length = p.yDim;
			for(int j=0;j<p.yDim;j++){
				pattern[i][j] = BitSet(p.xDim,false);
				pattern[i][j] = value;
			}
		}
	}
	
	/* 代入類の演算子オーバーロード */
	/* シフトを使い、代入先明示的に示せる。例 L >> M; の場合はMにLを代入 */
	ref LedMatrix opBinary(string s:"<<")(LedMatrix src){
		// this << src
		resize_xyz(src.xlength,src.ylength,src.zlength);
		
		for(int i=0;i<pattern.length;i++)
			for(int j=0;j<pattern[i].length;j++)
				for(int k=0;k<pattern[i][j].length;k++)
					pattern[i][j][k] = src[i][j][k];
			
		
		return this;
	}
	ref LedMatrix opBinary(string s:">>")(ref LedMatrix src){
		// this >> srcのオーバーロード　srcにthisを代入する。
		src.resize_xyz(xlength,ylength,xlength);
		
		for(int i=0;i<pattern.length;i++)
			for(int j=0;j<pattern[i].length;j++)
				for(int k=0;k<pattern[i][j].length;k++)
					src[i][j][k] = pattern[i][j][k];
		return src;
	}
	ref LedMatrix opBinary(string s:"<<")(Pos[] src){
		// this << Pos[]のオーバーロード
		for(int i=0;i<src.length;i++){
			if(src[i].z < pattern.length && src[i].z >= 0)
				if(src[i].y < pattern[src[i].z].length && src[i].y >= 0)
					if(src[i].x < pattern[src[i].z][src[i].y].length && src[i].x >= 0)
						pattern[src[i].z][src[i].y][src[i].x] = true;
		}
		return this;
	}
	ref LedMatrix opBinary(string s)(Pos src)if(s=="<<"){
		// this << Pos のオーバーロード
		if(src.z < pattern.length && src.z >= 0)
			if(src.y < pattern[src.z].length && src.y >= 0)
				if(src.x < pattern[src.z][src.y].length && src.x >= 0)
					pattern[src.z][src.y][src.x] = true;
		return this;
	}
	ref Pos[] opBinaryRight(string s:"<<")(ref Pos[] src){
		//Pos[] << LedMatrixの演算子オーバーロード
		src = toPArray;
		return src;
	}
	
	ref LedMatrix opOpAssign(string s:"<<")(Pos[] src){
		// this <<= Pos[]のオーバーロード
		// this << Pos演算子とは違い、Posの中身以外は消灯する
		for(int i=0;i<zlength;i++)
			for(int j=0;j<ylength;j++)
				for(int k=0;k<xlength;k++)
					pattern[i][j][k] = false;
		
		for(int i=0;i<src.length;i++){
			if(src[i].z < pattern.length && src[i].z >= 0)
				if(src[i].y < pattern[src[i].z].length && src[i].y >= 0)
					if(src[i].x < pattern[src[i].z][src[i].y].length && src[i].x >= 0)
						pattern[src[i].z][src[i].y][src[i].x] = true;
		}
		return this;
	}
	ref LedMatrix opOpAssign(string s:"<<")(Pos src){
		// this <<= Pos のオーバーロード
		for(int i=0;i<zlength;i++)
			for(int j=0;j<ylength;j++)
				for(int k=0;k<xlength;k++)
					pattern[i][j][k] = false;
		
		if(src.z < pattern.length && src.z >= 0)
			if(src.y < pattern[src.z].length && src.y >= 0)
				if(src.x < pattern[src.z][src.y].length && src.x >= 0)
					pattern[src.z][src.y][src.x] = true;
		return this;
	}
	
	
	//Index Assignment Operator Overloading
	bool opIndex(size_t x,size_t y,size_t z)
	in{
		assert(z < pattern.length);
		assert(y < pattern[z].length);
		assert(x < pattern[z][y].length);
	}
	body{return pattern[z][y]._val[x];}
	bool opIndexAssign(bool val ,size_t x,size_t y,size_t z)
	in{
		assert(z < pattern.length);
		assert(y < pattern[z].length);
		assert(x < pattern[z][y].length);
	}
	body{return pattern[z][y][x] = val;}
	
	ref BitSet[] opIndex(size_t z)
	in{assert(z < pattern.length);}
	body{return pattern[z];}
	
	//xLineやxsetを配列形式で呼ぶために定義 ex. LedMatrix["x-yz",1,2] はxLine(1,2)に等しい
	BitSet opIndex(string type,int a,int b)
	in{
		assert( type == "x:yz" || type == "x:zy" || type == "x-yz" || type == "x-zy" ||
				type == "y:xz" || type == "y:zx" || type == "y-xz" || type == "y-zx" ||
				type == "z:xy" || type == "z:yx" || type == "z-xy" || type == "z-yx");
		assert(a >= 0 && b >= 0);
		final switch(type){
			case "x:yz","x-yz":assert(a < ylength && b < zlength);break;
			case "x:zy","x-zy":assert(a < zlength && b < ylength);break;
			case "y:xz","y-xz":assert(a < xlength && b < zlength);break;
			case "y:zx","y-zx":assert(a < zlength && b < xlength);break;
			case "z:xy","z-xy":assert(a < xlength && b < ylength);break;
			case "z:yx","z-yx":assert(a < ylength && b < zlength);break;
		}
	}
	body{
		final switch(type){
			case "x:yz","x-yz":return xLine(a,b);
			case "x:zy","x-zy":return xLine(b,a);
			case "y:xz","y-xz":return yLine(b,a);
			case "y:zx","y-zx":return yLine(a,b);
			case "z:xy","z-xy":return zLine(a,b);
			case "z:yx","z-yx":return zLine(b,a);
		}
	}
	
	BitSet opIndexAssign(BitSet val,string type,int a,int b)
	in{
		assert( type == "x:yz" || type == "x:zy" || type == "x-yz" || type == "x-zy" ||
				type == "y:xz" || type == "y:zx" || type == "y-xz" || type == "y-zx" ||
				type == "z:xy" || type == "z:yx" || type == "z-xy" || type == "z-yx");
		assert(a >= 0 && b >= 0);
		final switch(type){
			case "x:yz","x-yz":assert(a < ylength && b < zlength);break;
			case "x:zy","x-zy":assert(a < zlength && b < ylength);break;
			case "y:xz","y-xz":assert(a < xlength && b < zlength);break;
			case "y:zx","y-zx":assert(a < zlength && b < xlength);break;
			case "z:xy","z-xy":assert(a < xlength && b < ylength);break;
			case "z:yx","z-yx":assert(a < ylength && b < zlength);break;
		}
	}
	body{
		final switch(type){
			case "x:yz","x-yz":
				val.length = xlength;
				xset(a,b,val);
				return xLine(a,b);
				
			case "x:zy","x-zy":
				val.length = xlength;
				xset(b,a,val);
				return xLine(b,a);
				
			case "y:xz","y-xz":
				val.length = ylength;
				yset(b,a,val);
				return yLine(b,a);
				
			case "y:zx","y-zx":
				val.length = ylength;
				yset(a,b,val);
				return yLine(a,b);
			
			case "z:xy","z-xy":
				val.length = zlength;
				zset(a,b,val);
				return zLine(a,b);
			
			case "z:yx","z-yx":
				val.length = zlength;
				zset(b,a,val);
				return zLine(b,a);
		}
	}
	
	BitSet opIndexOpAssign(string s)(BitSet val,string type,int a,int b)
	in{
		assert( type == "x:yz" || type == "x:zy" || type == "x-yz" || type == "x-zy" ||
				type == "y:xz" || type == "y:zx" || type == "y-xz" || type == "y-zx" ||
				type == "z:xy" || type == "z:yx" || type == "z-xy" || type == "z-yx");
		assert(a >= 0 && b >= 0);
		final switch(type){
			case "x:yz","x-yz":assert(a < ylength && b < zlength);break;
			case "x:zy","x-zy":assert(a < zlength && b < ylength);break;
			case "y:xz","y-xz":assert(a < xlength && b < zlength);break;
			case "y:zx","y-zx":assert(a < zlength && b < xlength);break;
			case "z:xy","z-xy":assert(a < xlength && b < ylength);break;
			case "z:yx","z-yx":assert(a < ylength && b < zlength);break;
		}
	}
	body{
		BitSet A;
		A = opIndex(type,a,b);
		A.opOpAssign!(s)(val);
		return opIndexAssign(A,type,a,b);
	}
	
	BitSet opIndexOpAssign(string s)(int val,string type,int a,int b)
	in{
		assert( type == "x:yz" || type == "x:zy" || type == "x-yz" || type == "x-zy" ||
				type == "y:xz" || type == "y:zx" || type == "y-xz" || type == "y-zx" ||
				type == "z:xy" || type == "z:yx" || type == "z-xy" || type == "z-yx");
		assert(a >= 0 && b >= 0);
		final switch(type){
			case "x:yz","x-yz":assert(a < ylength && b < zlength);break;
			case "x:zy","x-zy":assert(a < zlength && b < ylength);break;
			case "y:xz","y-xz":assert(a < xlength && b < zlength);break;
			case "y:zx","y-zx":assert(a < zlength && b < xlength);break;
			case "z:xy","z-xy":assert(a < xlength && b < ylength);break;
			case "z:yx","z-yx":assert(a < ylength && b < zlength);break;
		}
	}
	body{
		BitSet A;
		A = opIndex(type,a,b);
		A.opOpAssign!(s)(val);
		return opIndexAssign(A,type,a,b);
	}
	
	// LedMatrix[Pos(3,5,6)]を定義
	bool opIndex(Pos P){
		return pattern[P.z][P.y][P.x];
	}
	bool opIndexAssign(bool val,Pos P){
		return pattern[P.z][P.y][P.x] = val;
	}
	
	//LedMatrix["x-yz",0]を定義
	BitSet[] opIndex(string type,int a)
	in{
		assert( type == "x:yz" || type == "x:zy" || type == "x-yz" || type == "x-zy" ||
				type == "y:xz" || type == "y:zx" || type == "y-xz" || type == "y-zx" ||
				type == "z:xy" || type == "z:yx" || type == "z-xy" || type == "z-yx");
		assert(a >= 0);
		final switch(type){
			case "x:yz","x-yz":assert(a < xlength);break;
			case "x:zy","x-zy":assert(a < xlength);break;
			case "y:xz","y-xz":assert(a < ylength);break;
			case "y:zx","y-zx":assert(a < ylength);break;
			case "z:xy","z-xy":assert(a < zlength);break;
			case "z:yx","z-yx":assert(a < zlength);break;
		}
	}
	body{
		BitSet[] dst;
		final switch(type){
			case "x:yz","x-yz":
				for(int i=0;i<ylength;i++)
					dst ~= opIndex("z-xy",a,i);
				return dst;
				
			case "x:zy","x-zy":
				for(int i=0;i<zlength;i++)
					dst ~= opIndex("y-xz",a,i);
				return dst;
			
			case "y:xz","y-xz":
				for(int i=0;i<xlength;i++)
					dst ~= opIndex("z-xy",i,a);
				return dst;
				
			case "y:zx","y-zx":
				for(int i=0;i<zlength;i++)
					dst ~= opIndex("x-zy",i,a);
				return dst;
			
			case "z:xy","z-xy":
				for(int i=0;i<xlength;i++)
					dst ~= opIndex("y-xz",i,a);
				return dst;
				
			case "z:yx","z-yx":
				for(int i=0;i<ylength;i++)
					dst ~= opIndex("x-yz",i,a);
				return dst;
		}
	}
	
	BitSet[] opIndexAssign(BitSet[] val,string type,int a)
	in{
		assert( type == "x:yz" || type == "x:zy" || type == "x-yz" || type == "x-zy" ||
				type == "y:xz" || type == "y:zx" || type == "y-xz" || type == "y-zx" ||
				type == "z:xy" || type == "z:yx" || type == "z-xy" || type == "z-yx");
		assert(a >= 0);
		final switch(type){
			case "x:yz","x-yz":assert(a < xlength);break;
			case "x:zy","x-zy":assert(a < xlength);break;
			case "y:xz","y-xz":assert(a < ylength);break;
			case "y:zx","y-zx":assert(a < ylength);break;
			case "z:xy","z-xy":assert(a < zlength);break;
			case "z:yx","z-yx":assert(a < zlength);break;
		}
	}
	body{
		final switch(type){
			case "x:yz","x-yz":
				val.length = ylength;
				for(int i=0;i<val.length;i++){
					val[i].length = zlength;
					zset(a,i,val[i]);
				}
				return opIndex(type,a);
				
			case "x:zy","x-zy":
				val.length = zlength;
				for(int i=0;i<val.length;i++){
					val[i].length = ylength;
					yset(i,a,val[i]);
				}
				return opIndex(type,a);
				
			case "y:xz","y-xz":
				val.length = xlength;
				for(int i=0;i<val.length;i++){
					val[i].length = zlength;
					zset(i,a,val[i]);
				}
				return opIndex(type,a);
				
			case "y:zx","y-zx":
				val.length = zlength;
				for(int i=0;i<val.length;i++){
					val[i].length = xlength;
					xset(a,i,val[i]);
				}
				return opIndex(type,a);
			
			case "z:xy","z-xy":
				val.length = xlength;
				for(int i=0;i<val.length;i++){
					val[i].length = ylength;
					yset(a,i,val[i]);
				}
				return opIndex(type,a);
			
			case "z:yx","z-yx":
				val.length = ylength;
				for(int i=0;i<val.length;i++){
					val[i].length = xlength;
					xset(i,a,val[i]);
				}
				return opIndex(type,a);
		}
	}
	
	BitSet[] opIndexOpAssign(string s)(BitSet[] val,string type,int a)
	in{
		assert( type == "x:yz" || type == "x:zy" || type == "x-yz" || type == "x-zy" ||
				type == "y:xz" || type == "y:zx" || type == "y-xz" || type == "y-zx" ||
				type == "z:xy" || type == "z:yx" || type == "z-xy" || type == "z-yx");
		assert(a >= 0);
		final switch(type){
			case "x:yz","x-yz":assert(a < xlength);break;
			case "x:zy","x-zy":assert(a < xlength);break;
			case "y:xz","y-xz":assert(a < ylength);break;
			case "y:zx","y-zx":assert(a < ylength);break;
			case "z:xy","z-xy":assert(a < zlength);break;
			case "z:yx","z-yx":assert(a < zlength);break;
		}
	}
	body{
		auto temp = opIndex(type,a);
		val.length = temp.length;
		for(int i=0;i<temp.length;i++){
			val[i].length = temp[i].length;
			temp[i].opOpAssign!(s)(val[i]);
		}
		return opIndexAssign(temp,type,a);
	}
	
	BitSet[] opIndexOpAssign(string s)(int val,string type,int a)
	in{
		assert( type == "x:yz" || type == "x:zy" || type == "x-yz" || type == "x-zy" ||
				type == "y:xz" || type == "y:zx" || type == "y-xz" || type == "y-zx" ||
				type == "z:xy" || type == "z:yx" || type == "z-xy" || type == "z-yx");
		assert(a >= 0);
		final switch(type){
			case "x:yz","x-yz":assert(a < xlength);break;
			case "x:zy","x-zy":assert(a < xlength);break;
			case "y:xz","y-xz":assert(a < ylength);break;
			case "y:zx","y-zx":assert(a < ylength);break;
			case "z:xy","z-xy":assert(a < zlength);break;
			case "z:yx","z-yx":assert(a < zlength);break;
		}
	}
	body{
		auto temp = opIndex(type,a);
		for(int i=0;i<temp.length;i++)
			temp[i].opOpAssign!(s)(val);
		return opIndexAssign(temp,type,a);
	}
	
	//Assignment Operator Overloading
	bool opEquals(LedMatrix a){
		bool ret=true;
		for(int z=0;z<zlength;z++)
			for(int y=0;y<ylength;y++)
				for(int x=0;x<xlength;x++)
					ret &= (pattern[z][y][x] == a.pattern[z][y][x]);
		return ret;
	}
	ref LedMatrix opAssign(LedMatrix L){
		pattern.length = L.zlength;
		for(int z=0;z<L.zlength;z++){
			pattern[z].length = L.ylength;
			for(int y=0;y<L.ylength;y++){
				pattern[z][y] = BitSet(L.xlength,false);
				for(int x=0;x<L.xlength;x++)
					pattern[z][y][x] = L[z][y][x];
			}
		}
		return this;
	}
	
	//単項演算子~(ビットごとの反転)の定義
	LedMatrix opUnary(string s:"~")(){
		return inverse;
	}
	
	//castを定義
	T opCast(T:Pos[])(){
		Pos[] dst;
		return opBinaryRight!("<<")(dst);
	}
	
	//member fanction(property etc...)
	alias zlength zdim;
	alias ylength ydim;
	alias xlength xdim;
	@property const size_t zlength(){return pattern.length;}
	@property const size_t ylength(){return pattern[0].length;}
	@property const size_t xlength(){return pattern[0][0].length;}
	@property size_t zlength(size_t z){
		auto plan = LedPlan(xlength,ylength,z,1,1);
		resize(plan);
		return pattern.length;
	}
	@property size_t ylength(size_t y){
		auto plan = LedPlan(xlength,y,zlength,1,1);
		resize(plan);
		return pattern[0].length;
	}
	@property size_t xlength(size_t x){
		auto plan = LedPlan(x,ylength,zlength,1,1);
		resize(plan);
		return pattern[0][0].length;
	}
	void set(Pos p,bool val){
		if((p.x < xlength)&&(p.y < ylength)&&(p.z < zlength))
			if((p.x >= 0)&&(p.y >= 0)&&(p.z >= 0))
				pattern[p.z][p.y][p.x] = val;
	}
	void xset(int y,int z,BitSet val){
		for(int x=0;x<xlength;x++){
			if(x >= val.length){
				pattern[z][y][x] = false;
				continue;
			}
			pattern[z][y][x] = val[x];
		}
	}
	void yset(int z,int x,BitSet val){
		for(int y=0;y<ylength;y++){
			if(y >= val.length){
				pattern[z][y][x] = false;
				continue;
			}
			pattern[z][y][x] = val[y];
		}
	}
	void zset(int x,int y,BitSet val){
		for(int z=0;z<zlength;z++){
		if(z >= val.length){
				pattern[z][y][x] = false;
				continue;
			}
			pattern[z][y][x] = val[z];
		}
	}
	
	void resize(LedPlan plan){
		pattern.length = plan.zdim;
		for(int z=0;z<plan.zdim;++z){
			pattern[z].length = plan.ydim;
			for(int y=0;y<plan.ydim;++y)
				pattern[z][y].length = plan.xdim;
		}
	}
	void resize(Triple!(int) Tr){
		LedPlan P = LedPlan(Tr.x,Tr.y,Tr.z,1);
		return resize(P);
	}
	void resize_xyz(int x,int y,int z){
		auto P = LedPlan(x,y,z,1);
		return resize(P);
	}
	
	LedMatrix inverse(){
		LedMatrix ret = LedMatrix(zlength,ylength,xlength,0x00);
		for(int i=0;i<zlength;i++)
			for(int j=0;j<ylength;j++)
				ret[i][j] = (~pattern[i][j]).dup;
				
		return ret;
	}
	void cout(){
		for(int z=0;z<zlength;z++){
			for(int y=0;y<ylength;y++){
				writef("%s",pattern[z][y].toubyte);
				if(y!=(ylength-1))writef(",");
			}
			writef("\n");
		}
		writef("\n");
	}
	LedMatrix dup(){
		LedMatrix ret = LedMatrix(zlength,ylength,xlength,0x00);
		for(int z=0;z<zlength;z++)
			for(int y=0;y<ylength;y++)
				ret.pattern[z][y] = pattern[z][y].dup;
		return ret;
	}
	
	void zRotL(int x,int y,int bits){
	
		auto ret = BitSet(zlength,false);
		for(int z=0;z<zlength;z++)
			ret[z] = pattern[z][y][x];
		
		ret.rot_l(bits);
		
		for(int z=0;z<zlength;z++)
			pattern[z][y][x] = ret[z];
	}
	void zRotR(int x,int y,int bits){
		auto ret = BitSet(zlength,false);
		for(int z=0;z<zlength;z++)
			ret[z] = pattern[z][y][x];
		
		ret = ret.rot_r(bits);
		for(int z=0;z<zlength;z++)
			pattern[z][y][x] = ret[z];
	}
	void yRotL(int z,int x,int bits){
		auto ret = BitSet(ylength,false);
		for(int y=0;y<ylength;y++)
			ret[y] = pattern[z][y][x];
		
		ret.rot_l(bits);
		for(int y=0;y<ylength;y++)
			pattern[z][y][x] = ret[y];
	}
	void yRotR(int z,int x,int bits){
		auto ret = BitSet(ylength,false);
		for(int y=0;y<ylength;y++)
			ret[y] = pattern[z][y][x];
		
		ret = ret.rot_r(bits);
		for(int y=0;y<ylength;y++)
			pattern[z][y][x] = ret[y];
	}
	void xRotL(int y,int z,int bits){
		pattern[z][y] = pattern[z][y].rot_l(bits);
	}
	void xRotR(int y,int z,int bits){
		pattern[z][y] = pattern[z][y].rot_r(bits);
	}
	void zShiL(int x,int y,int bits){
		auto ret = BitSet(zlength,false);
		for(int z=0;z<zlength;z++)
			ret[z] = pattern[z][y][x];
		
		ret <<= bits;
		for(int z=0;z<zlength;z++)
			pattern[z][y][x] = ret[z];
	}
	void zShiR(int x,int y,int bits){
		auto ret = BitSet(zlength,false);
		for(int z=0;z<zlength;z++)
			ret[z] = pattern[z][y][x];
		
		ret >>= bits;
		for(int z=0;z<zlength;z++)
			pattern[z][y][x] = ret[z];
	}
	void yShiL(int z,int x,int bits){
		auto ret = BitSet(ylength,false);
		for(int y=0;y<ylength;y++)
			ret[y] = pattern[z][y][x];
		
		ret <<= bits;
		for(int y=0;y<ylength;y++)
			pattern[z][y][x] = ret[z];
	}
	void yShiR(int z,int x,int bits){
		auto ret = BitSet(ylength,false);
		for(int y=0;y<ylength;y++)
			ret[y] = pattern[z][y][x];
		
		ret >>= bits;
		for(int y=0;y<ylength;y++)
			pattern[z][y][x] = ret[z];
	}
	void xShiL(int y,int z,int bits){
			pattern[z][y] <<= bits;
	}
	void xShiR(int y,int z,int bits){
			pattern[z][y] >>= bits;
	}
	
	BitSet xLine(int y,int z){
		return pattern[z][y].dup;
	}
	BitSet yLine(int z,int x){
		auto ret = BitSet(ylength,false);
		for(int y=0;y<ylength;y++)
			ret[y] = pattern[z][y][x];
		return ret;
	}
	BitSet zLine(int x,int y){
		auto ret = BitSet(zlength,false);
		for(int z=0;z<zlength;z++)
			ret[z] = pattern[z][y][x];
		return ret;
	}
	
	void merge(Pos[] p,bool val){
		for(int i=0;i<p.length;i++)//たとえば8x8x8ならば7以上か0より小さいものがあればマージしない
			if((p[i].x < xlength)&&(p[i].y < ylength)&&(p[i].z < zlength))
				if((p[i].x >= 0)&&(p[i].y >= 0)&&(p[i].z >= 0))
					pattern[p[i].z][p[i].y][p[i].x] = val;
	}
	Pos[] toPArray(){
		Pos[] ret;
		for(int z=0;z<pattern.length;z++)
			for(int y=0;y<pattern[z].length;y++)
				for(int x=0;x<pattern[z][y].length;x++)
					if(pattern[z][y][x])
						ret ~= Pos(x,y,z);
		return ret;
	}
	
	invariant(){
		int zl = pattern.length , yl ,xl;
		if(zl){
			yl = pattern[0].length;
			for(int i=0;i<zl;++i)
				assert(yl == pattern[i].length);
		}
		//この時点でzlength = zl ,ylength = ylが成り立っている。
		if(yl && zl){
			xl = pattern[0][0].length;
			for(int i=0;i<zl;++i){
				for(int j=0;j<yl;++j)
					assert(xl == pattern[i][j].length);
			}
		}
	}
	
	BitSet[][] pattern;
}

struct LedPlan{
	this(uint x,uint y,uint z,uint fl,uint fp){xDim=x;yDim=y;zDim=z;flames=fl;fps=fp;}
	this(uint x,uint y,uint z,uint fl){xDim=x;yDim=y;zDim=z;flames=fl;}
	uint xDim;
	uint yDim;
	uint zDim;
	uint fps;
	uint flames;
	real sec(){
		return cast(real)flames/cast(real)fps;
	}
	//別名定義的なもの
	auto ref xdim(){return xDim;}
	auto ref ydim(){return yDim;}
	auto ref zdim(){return zDim;}
	auto ref hz(){return fps;}
	auto ref total(){return flames;}
}

struct BitSet{
	alias _val this;
	BitArray _val;
	
	this(uint n,bool b){
		_val.length = n;
		for(int i=0;i<n;i++)_val[i]=b;
	}
	this(ubyte v){
		_val.length = 8;
		for(int i=0;i<8;i++)
			_val[i] = ((v >> i)%2) ? true :false;
	}
	this(BitSet b){
		_val.length = b.length;
		for(int i=0;i<b.length;i++)_val[i] = b[i];
	}
	this(BitArray B){
		_val.length = B.length;
		for(int i=0;i<B.length;i++)
			_val[i] = B[i];
	}
	
	
	static BitSet opCall(ubyte v){
		BitSet X;
		X.length = 8;
		for(int i=0;i<8;i++)
			X[i] = ((v >> i)%2) ? true :false;
		return X;
	}
	static BitSet opCall(BitSet b){
		BitSet X;
		X.length = b.length;
		for(int i=0;i<b.length;i++)X[i] = b[i];
		return X;
	}
	static BitSet opCall(BitArray B){
		BitSet X;
		X.length = B.length;
		for(int i=0;i<B.length;i++)
			X[i] = B[i];
		return X;
	}
	
	//rot_rを>>>で代用している。
	
	const bool opIndex(size_t x){return _val[x];}
	bool opIndexAssign(bool b,size_t i){return (_val[i] = b);}
	ref BitSet opAssign(ubyte v){
		_val.length = 8;
		
		for(int i=0;i<8;i++)
			_val[i] = cast(bool)(((v >> i)&1)%2);
		return this;
	}
	ref BitSet opAssign(BitSet B){
		_val.length = B.length;
		for(int i=0;i<_val.length;i++)
			_val[i] = B[i];
		return this;
	}
	int opCmp(BitSet B){
		if(opEquals(B))return 0;//等しいなら0を返せば良い
		
		//aのほうが大きい場合は1,bのほうが大きい場合は-1を返す。
		BitSet A = dup;
		while(A.length > B.length)//Bのほうが小さい間
			B ~= (BitSet(1,false));//Bに1ビットずつ加える。
		while(A.length < B.length)//Aのほうが小さい間
			A ~= BitSet(1,false);//Aに1ビットずつ加える。
			
		//以下からA,Bは同じ大きさである
		for(int i=(A.length-1);i>=0;i--){
			if(A[i] == B[i])continue;
			
			if(A[i] && !B[i])//A=true,B=falseのとき
				return 1;
			if(!A[i] && B[i])//A=false,B=trueのとき
				return -1;
		}
		return 0;
		
	}
	BitSet opUnary(string s:"~")(){
        BitSet ret;
		ret.length = _val.length;
		for(int i=0;i<_val.length;i++)
			ret[i] = _val[i] ? false:true;
		return ret;
    }
	BitSet rot_r(int n){
		//再帰を使えば簡単に書ける
		/+
		if(n==0)return this;
		if(n < 0)return rot_l(n*-1);
		bool bot = val[0];
		BitSet tmp = dup;
		for(int i=1;i<val.length;i++)
			val[i-1] = tmp[i];
			
		val[val.length-1] = bot;
		
		return rot_r(n-1);
		+/
		/+ ex.
			1101101011 を 3bit rot_r
			0111101101となる。つまり、先頭3bit [$-1]~[$-3]までは[2]~[0]になる
			一般化すると
			[$-1]~[$-n+i]~[$-n]が[n-1]~[i]~[0] (iはn-1まで)
			
			この処理をするまえにシフト演算をしておけばローテートとなる
		+/
		if(n < 0)return rot_l(-n);
		//alias ret.length $;
		
		n %= _val.length;
		BitSet ret;
		ret.length = _val.length;
		//シフト部分
		ret = opBinary!(">>")(n);
		//ローテート部分
		for(int i=0;i<n;i++)
			ret[ret.length-n+i] = _val[i];
		return ret;
	}
	BitSet rot_l(int n){
	/+
		//再帰を使えば簡単
		if(n==0)return this;
		if(n < 0)return this;dmd 
		bool top = val[val.length -1];
		BitSet tmp = dup;
		
		for(int i=1;i<val.length;i++)
			val[i] = tmp[i-1];
		
		val[0] = top;
		return rot_l(n-1);
	+/
	/+	
		ex.
		11010101011を3bit左ローテートすると
		10101011110となる。
		一般にn bitローテートする場合ローテート部は
		[0]~[i]~[n-1] が [$-n] ~ [&-n+i] ~ [$-1]となる
		
	+/	
		if(n < 0)return rot_r(-n);
		
		n %= _val.length;
		BitSet ret;ret.length = _val.length;
		//シフト部
		ret = opBinary!("<<")(n);
			
		//ローテート部
		for(int i=0;(i<n);i++)
			ret[i] = _val[_val.length+i-n];
		
		return ret;
	}
	BitSet opBinary(string s:"<<")(uint n){
		BitSet ret;
		ret.length = _val.length;
		for(int i=0;i<(_val.length-n);i++)
			ret[i+n] = _val[i];
		return ret;
	}
	BitSet opBinary(string s:">>")(uint n){
		if(n>=_val.length)return BitSet(_val.length,false);
		BitSet ret = BitSet(_val.length,false);
		for(int i=0;i<(_val.length-n);i++)
			ret[i] = _val[i+n];
		return ret;
	}
	BitSet opBinary(string s:">>>")(int n){
		return rot_r(n);
	}
	BitSet opBinary(string s:"&")(BitSet a){
	/*	二つの大きさを無視して簡単に書くとこの様になる.
		BitSet ret = BitSet(val.length,false);
		for(int i=0;i<val.length;i++)
			ret[i] = val[i] && a[i];
		return val.length;
	*/
		if(_val.length > a.length){
			BitSet ret;ret.length = _val.length;
			for(int i=0;i<a.length;i++)
				ret[i] = _val[i] && a[i];
			for(int i=a.length;i<ret.length;i++)
				ret[i] = false;
			return ret;
		}else{
			BitSet ret;ret.length = a.length;
			for(int i=0;i<_val.length;i++)
				ret[i] = a[i] && _val[i];
			for(int i=_val.length;i<ret.length;i++)
				ret[i] = false;
			return ret;
		}
		return BitSet(0,false);
	}
	BitSet opBinary(string s:"&")(ubyte n){
	/*
		BitSet ret = BitSet(val.length,false);
		for(int i=0;i<val.length;i++)
			ret[i] = val[i] & ((n>>i)%2);
		return ret;
	*/
		if(_val.length > 8){
			BitSet ret = _val;
			for(int i=0;i<8;i++)
				ret[i] = ret[i] && cast(bool)((n>>i)%2);
			for(int i=8;i<ret.length;i++)
				ret[i] = false;
			return ret;
		}else{
			auto ret = BitSet(n);
			for(int i=0;i<_val.length;i++)
				ret[i] = ret[i] && _val[i];
			for(int i=_val.length;i<ret.length;i++)
				ret[i] = false;
			return ret;
		}
	}
	ubyte opBinaryRight(string s:"&")(ubyte n){
		if(_val.length > 8){
			BitSet ret = _val;
			for(int i=0;i<8;i++)
				ret[i] = ret[i] && cast(bool)((n>>i)%2);
			for(int i=8;i<ret.length;i++)
				ret[i] = false;
			return ret.toubyte;
		}else{
			auto ret = BitSet(n);
			for(int i=0;i<_val.length;i++)
				ret[i] = ret[i] && _val[i];
			for(int i=_val.length;i<ret.length;i++)
				ret[i] = false;
			return ret.toubyte;
		}
	}
	BitSet opBinary(string s:"|")(BitSet a){
		if(_val.length > a.length){
			BitSet ret;ret.length = _val.length;
			for(int i=0;i<a.length;i++)
				ret[i] = _val[i] || a[i];
			return ret;
		}else{
			BitSet ret;ret.length = a.length;
			for(int i=0;i<_val.length;i++)
				ret[i] = a[i] || _val[i];
			return ret;
		}
	}
	BitSet opBinary(string s:"|")(ubyte n){
		if(_val.length > 8){
			BitSet ret = _val;
			for(int i=0;i<8;i++)
				ret[i] = ret[i] || cast(bool)((n>>i)%2);
			return ret;
		}else{
			auto ret = BitSet(n);
			for(int i=0;i<_val.length;i++)
				ret[i] = ret[i] || _val[i];
			return ret;
		}
		return BitSet(0,false);
	}
	ubyte opBinaryRight(string s:"|")(ubyte n){
		if(bits > 8){
			BitSet ret = _val;
			for(int i=0;i<8;i++)
				ret[i] = ret[i] || cast(bool)((n>>i)%2);
			return ret.toubyte;
		}else{
			auto ret = BitSet(n);
			for(int i=0;i<_val.length;i++)
				ret[i] = ret[i] || _val[i];
			return ret.toubyte;
		}
		return 0;
	}
	BitSet opBinary(string s:"^")(BitSet a){
		if(_val.length > a.length){
			BitSet ret = _val;
			for(int i=0;i<a.length;i++)
				ret[i] = (ret[i] == a[i]) ? false :true;
			return ret;
		}else{
			BitSet ret;ret.length = a.length;
			for(int i=0;i<_val.length;i++)
				ret[i] = (a[i] == _val[i]) ? false : true;
			return ret;
		}
		return BitSet(0,false);
	}
	BitSet opBinary(string s:"^")(ubyte n){
		if(_val.length > 8){
			BitSet ret = _val;
			for(int i=0;i<8;i++)
				ret[i] = (ret[i] == cast(bool)((n>>i)%2)) ? false : true;
			return ret;
		}else{
			auto ret = BitSet(n);
			for(int i=0;i<_val.length;i++)
				ret[i] = (ret[i] == _val[i]) ? false :true;
			return ret;
		}
		return BitSet(0,false);
	}
	ubyte opBinaryRight(string s:"^")(ubyte n){
		if(_val.length > 8){
			BitSet ret = _val;
			for(int i=0;i<8;i++)
				ret[i] = (ret[i] == cast(bool)((n>>i)%2)) ? false : true;
			return ret.toubyte;
		}else{
			auto ret = BitSet(n);
			for(int i=0;i<_val.length;i++)
				ret[i] = (ret[i] == _val[i]) ? false :true;
			return ret.toubyte;
		}
		return 0;
	}
	ref BitSet opOpAssign(string s:"<<")(uint n){
		if(n>=_val.length){
			for(int i=0;i<_val.length;i++)
				_val[i] = false;
			return this;
		}
		BitSet ret;ret.length = _val.length;
		for(int i=0;i<(_val.length-n);i++)
			ret[i+n] = _val[i];
		
		for(int i=0;i<_val.length;i++)
			_val[i] = ret[i];
		
		return this;
	}
	ref BitSet opOpAssign(string s:">>")(uint n){
		if(n>=_val.length){
			for(int i=0;i<_val.length;i++)
				_val[i] = false;
			return this;
		}
		BitSet ret;ret.length = _val.length;
		for(int i=0;i<(_val.length-n);i++)
			ret[i] = _val[i+n];
			
		for(int i=0;i<_val.length;i++)
			_val[i] = ret[i];
			
		return this;
	}
	ref BitSet opOpAssign(string s:"&")(BitSet a){
	/*
		for(int i=0;i<bits;i++)
			val[i] = val[i] && a[i];
		return dup;
	*/
		if(_val.length > a.length){
			for(int i=0;i<a.length;i++)
				_val[i] = _val[i] && a[i];
			for(int i=a.length;i<_val.length;i++)
				_val[i] = 0;
		}else{
			for(int i=0;i<_val.length;i++)
				_val[i] = _val[i] && a[i];
			for(int i=_val.length;i<a.length;i++)
				_val ~= false;
		}
		return this;
	}
	ref BitSet opOpAssign(string s:">>>")(int n){
		Assign(opBinary!(">>>")(n));
		return this;
	}
	ref BitSet opOpAssign(string s:"&")(ubyte n){
	/*
		for(int i=0;i<bits;i++)
			val[i] = val[i] && cast(bool)((n>>i)%2);
		return dup;
	*/
		if(_val.length > 8){
			for(int i=0;i<8;i++)
				_val[i] = _val[i] && cast(bool)((n>>i)%2);
			for(int i=8;i<_val.length;i++)
				_val[i] = 0;
		}else{
			for(int i=0;i<_val.length;i++)
				_val[i] = _val[i] && cast(bool)((n>>i)%2);
			for(int i=_val.length;i<8;i++)
				_val ~= false;
		}
		return this;
	}
	ref BitSet opOpAssign(string s:"|")(BitSet a){
	/*
		for(int i=0;i<bits;i++)
			val[i] = val[i] || a[i];
		return dup;
	*/
		if(_val.length > a.length){
			for(int i=0;i<a.length;i++)
				_val[i] = _val[i] || a[i];
		}else{
			for(int i=0;i<_val.length;i++)
				_val[i] = _val[i] || a[i];
			for(int i=_val.length;i<a.length;i++)
				_val ~= a[i];
		}
		return this;
	}
	ref BitSet opOpAssign(string s:"|")(ubyte n){
	/*
		for(int i=0;i<bits;i++)
			val[i] = val[i] || cast(bool)((n>>i)%2);
		return dup;
	*/
		if(_val.length > 8){
			for(int i=0;i<8;i++)
				_val[i] = _val[i] || cast(bool)((n>>i)%2);
		}else{
			for(int i=0;i<_val.length;i++)
				_val[i] = _val[i] || cast(bool)((n>>i)%2);
			for(int i=_val.length;i<8;i++)
				_val ~= cast(bool)((n>>i)%2);
		}
		return this;
	}
	ref BitSet opOpAssign(string s:"^")(BitSet a){
	/*
		for(int i=0;i<bits;i++)
			val[i] = (val[i] != a[i]) ? 1 : 0;
		return dup;
	*/
		if(_val.length > a.length){
			for(int i=0;i<a.length;i++)
				_val[i] = (_val[i] == a[i])? false : true;
		}else{
			for(int i=0;i<_val.length;i++)
				_val[i] = (_val[i] == a[i])? false : true;
			for(int i=_val.length;i<a.length;i++)
				_val ~= a[i];
		}
		return this;
	}
	ref BitSet opOpAssign(string s:"^")(ubyte n){
	/*
		for(int i=0;i<bits;i++)
			val[i] = (val[i] != cast(bool)((n>>i)%2)) ? 1:0;
		return dup;
	*/
		if(_val.length > 8){
			for(int i=0;i<8;i++)
				_val[i] = (_val[i] == cast(bool)((n>>i)%2))? false : true;
		}else{
			for(int i=0;i<_val.length;i++)
				_val[i] = (_val[i] == cast(bool)((n>>i)%2))? false : true;
			for(int i=_val.length;i<8;i++)
				_val ~= cast(bool)((n>>i)%2);
		}
		return this;
	}
	BitSet opBinary(string s:"~")(BitSet a){
		//this ~ a
		BitSet X = _val;
		X.length = _val.length + a.length;
		for(int i=0;i<a.length;i++)
			X[i+_val.length] = a[i];
		return X;
	}
	BitSet opBinary(string s:"~")(bool b){
		BitSet X = _val;
		X.length = _val.length + 1;
		X[X.length-1] = b;
		return X;
	}
	ref BitSet opOpAssign(string s:"~")(BitSet B){
		_val ~= B.bitarray;
		return this;
	}
	BitSet opOpAssign(string s:"~")(bool b){
		_val ~= b;
		return this;
	}
	
	bool opEquals(BitSet B){
		int bl = B.length , vl = _val.length;
		for(int i=0;i<bl && i<vl ;i++)
			if(_val[i] != B[i])return false;
		if(bl > vl){
			for(int i=vl;i<bl;i++)
				if(B[i])return false;
			return true;
		}else{
			for(int i=bl;i<vl;i++)
				if(_val[i])return false;
			return true;
		}
	}
	T opCast(T:ubyte)(){
		return toubyte;
	}
	T opCast(T:ushort)(){
		return toushort;
	}
	T opCast(T:uint)(){
		return touint;
	}
	T opCast(T:ulong)(){
		return toulong;
	}
	
	BitSet opBinary(string s)(BitSet B)if(s=="+"){
		//飽和演算が嫌いな方へ
		//飽和演算せずに足し算を求める関数。
		if(zero())return B;
		if(B.zero())return this;
		BitSet xor = BitSet(0x00);
		BitSet and = BitSet(0x00);
		and = opBinary!("&")(B);
		and <<= 1;
		xor = opBinary!("^")(B);
		//二進数演算についてA + B = ((A&B)<<1) + A^Bという式が成り立つ。
		//再帰を使ってしまえばよい。
		return (and.opBinary!("+")(xor));
	}
	BitSet opBinary(string s)(BitSet B)if(s=="-"){
		//ラップ
		//あるビット列A,Bが与えられた時に、
		//A - B = A + (++(~B))
		//と等しい。この時+はラップアラウンド演算である。
		BitSet TH = ~B;
		TH.opUnary!("++");
		return opBinary!("+")(TH);
	}
	BitSet opUnary(string s)()if(s=="++"){
		//ラップ
		//前置インクリメント
		BitSet one;one.length = _val.length;
		one[0] = true;//1にする。
		Assign(opBinary!("+")(one));
		return this;
	}
	BitSet opBinary(string s : "*")(BitSet B){//正常に動くかどうかは未確認
		BitSet C = B;
		for(;C != BitSet(B.length,false);C=C-BitSet(1))
			opBinary!"+"(B);
		return this;
	}
	
	//飽和演算
	BitSet SB(string s)(BitSet B)if(s=="+"){
		//飽和
		if(zero())return B;
		if(B.zero())return this;
		BitSet xor = BitSet(0x00);
		BitSet and = BitSet(0x00);
		and = opBinary!("&")(B);
		and.rot_l(1);
		if(and[0]){//最上位桁以上まで繰り上がったとすればand[0]はtrueを返す
			//最上位桁以上まで繰り上がった場合には飽和演算をします（つまりそのビット数で表せれる最上数を返す）
			return BitSet(and.length,1);
		}
		xor = opBinary!("^")(B);
		//二進数演算についてA + B = (A&B<<1) + A^Bという式が成り立つ。
		//再帰を使ってしまえばよい。
		return (and.SB!("+")(xor));
	}
	BitSet SB(string s)(BitSet B)if(s=="-"){
		//飽和
		//あるビット列A,Bが与えられた時に、
		//A - B = A + (++(~B))
		//と等しい。この時+はラップアラウンド演算である。
		if(opCmp(B) <= 0){//飽和演算。A,Bが等しいか、Bのほうが大きいなら0を返す。
			int len = length > B.length ? length : B.length;
			return BitSet(len,false);
		}	
		BitSet TH = ~B;
		TH.opUnary!("++");
		return opBinary!("+")(TH);
	}
	BitSet SU(string s)()if(s=="++"){
		//前置インクリメント
		BitSet one;one.length = _val.length;
		one[0] = true;//1にする。
		Assign(SB!("+")(one));
		return this;
	}
	
	void cout(){
		writef("[");
		for(int i=_val.length-1;i>=0;i--){
			if(i!=0)
				writef("%d",_val[i]);
			else
				writef("%d]\n",_val[i]);
		}
	}
	void coutx(){
		//8bitずつ分割してそれら8bitを16進数2桁に変換して小文字で表示させる。
	}
	void coutX(){
		//8bitずつ分割してそれら8bitを16進数2桁に変換して大文字で表示させる。
	}
	
	@property BitArray bitarray(){return _val;}
	
	const BitSet dup(){
		BitSet ret;ret.length = _val.length;
		for(int i=0;i<_val.length;i++)
			ret[i] = _val[i];
		return ret;
	}
	@property const size_t length(){return _val.length;}
	@property size_t length(size_t x){_val.length = x;return x;}
	ubyte toubyte(){
		ubyte ret=0;
		int i=(8 > _val.length) ? (_val.length-1) : 7;
		for(;i>=0;i--){
			ret <<= 1;
			ret += _val[i] ? 1:0;
		}
		return ret;
	}
	ushort toushort(){
		ushort ret=0;
		int i=(16 > _val.length) ? (_val.length-1) : 15;
		for(;i>=0;i--){
			ret <<= 1;
			ret += _val[i] ? 1:0;
		}
		return ret;
	}
	uint touint(){
		uint ret=0;
		int i=(32 > _val.length) ? (_val.length-1) : 31;
		for(;i>=0;i--){
			ret <<= 1;
			ret += _val[i] ? 1:0;
		}
		return ret;
		
	}
	ulong toulong(){
		ulong ret=0;
		int i=(64 > _val.length) ? (_val.length-1) : 63;
		for(;i>=0;i--){
			ret <<= 1;
			ret += _val[i] ? 1:0;
		}
		return ret;
	}
	bool zero(){
		bool ret = false;
		for(int i=0;i<_val.length;i++)
			ret |= _val[i];
		//ここで、retの値はすべてfalseの場合に限りfalseとなる。
		//つまり、一つでもtrueがあればtrueとなっている
		return !ret;
	}
	
	BitSet Assign(BitSet B){
		_val.length = B.length;
		
		for(int i=0;i<B.length;i++)
			_val[i] = B[i];
		return this;
	}
	
	/+
	bool max(){
		bool ret = true;
		for(int i=0;i<bits;i++)
			ret &= val[i];
		return ret;
	}
	+/
	/*将来のために予約　ucentは128bitであるが、D言語自体は128bitのcent,ucentを将来のために予約としている
	ucent toucent(){
	}
	*/
}

struct Triple(T){
	this(T a,T b,T c){
		x=a;
		y=b;
		z=c;
	}
	void set(T a,T b,T c){
		x=a;
		y=b;
		z=c;
	}
	//Pos toPos(){return Pos(cast(int)x,cast(int)y,cast(int)z);}
	Triple!(T) dup(){return Triple!(T)(x,y,z);}
	bool opEquals(Triple!(T) p){
		return ((x==p.x) && (y==p.y) && (z==p.z));
	}
	Triple!(T) opAssign(Triple!(T) p){
		x = p.x;
		y = p.y;
		z = p.z;
		return this;
	}
	@property Triple!(int) toPos(){
		Triple!(int) X = Triple!(int)(cast(int)x,cast(int)y,cast(int)z);
		return X;
	}
	
	Triple!(T) opCast(T)(){
		Tripe!T X = Triple!T;
		T.set(cast(T)x,cast(T)y,cast(T)z);
	}
	
	void cout(){writefln("[%s,%s,%s]",x,y,z);}
	T x;
	T y;
	T z;
}

struct CLPlan{
	this(uint x,uint y,uint z,uint fl,uint fp,uint cb){assert((cb%3)==0);xDim=x;yDim=y;zDim=z;flames=fl;fps=fp;cbits=cb;}
	this(uint x,uint y,uint z,uint fl,uint cb){assert((cb%3)==0);xDim=x;yDim=y;zDim=z;flames=fl;cbits=cb;}
	
	uint xDim;
	uint yDim;
	uint zDim;
	uint fps;
	uint flames;
	uint cbits;
	real sec(){
		return cast(real)flames*cast(real)fps;
	}
}

struct CLMatrix{
	this(int z,int y,int x,uint cbits){
		assert((cbits%3)==0);
		val.length = z;
		for(int i=0;i<z;i++){
			val[i].length = y;
			for(int j=0;j<y;j++){
				val[i][j].length = x;
				for(int k=0;k<x;k++)
					val[i][j][k] = ColorSet(0,0,0,cbits);
			}
		}
	}
	this(int z,int y,int x,uint cbits,uint color){
		assert((color%3)==0);
		val.length = z;
		for(int i=0;i<z;i++){
			val[i].length = y;
			for(int j=0;j<y;j++){
				val[i][j].length = x;
				for(int k=0;k<x;k++)
					val[i][j][k] = ColorSet(color,cbits);
			}
		}
	}
	this(CLPlan Lcp){
		val.length = Lcp.zDim;
		for(int i=0;i<Lcp.zDim;i++){
			val[i].length = Lcp.yDim;
			for(int j=0;j<Lcp.yDim;j++){
				val[i][j].length = Lcp.xDim;
				for(int k=0;k<Lcp.xDim;k++)
					val[i][j][k] = ColorSet(0,0,0,Lcp.cbits);
			}
		}
	}
	this(CLPlan Lcp,uint color){
		val.length = Lcp.zDim;
		for(int i=0;i<Lcp.zDim;i++){
			val[i].length = Lcp.yDim;
			for(int j=0;j<Lcp.yDim;j++){
				val[i][j].length = Lcp.xDim;
				for(int k=0;k<Lcp.xDim;k++)
					val[i][j][k] = ColorSet(color,Lcp.cbits);
			}
		}
	}
	
	ref CLMatrix opBinary(string s)(ref LedMatrix src)if(s=="<<"){
		int z = src.zlength;
		int y = src.ylength;
		int x = src.xlength;
		
		assert((cbits%3)==0);
		val.length = z;
		for(int i=0;i<z;i++){
			val[i].length = y;
			for(int j=0;j<y;j++){
				val[i][j].length = x;
				for(int k=0;k<x;k++)
					val[i][j][k] = src[i][j][k].dup;
			}
		}
		return this;
	}
	ref ColorSet[][] opIndex(int z){return val[z];}
	ref ColorSet opIndex(int x,int y,int z){return val[z][y][x];}
	
	auto xlength(){return val[0][0].length;}
	auto ylength(){return val[0].length;}
	auto zlength(){return val.length;}
	auto cbits(){return val[0][0][0].cbits;}
	auto clength(){return val[0][0][0].length;}
	
	
	ColorSet[][][] val;
}

struct ColorSet{
	this(ubyte r,ubyte g,ubyte b,uint cbits){
		assert(cbits <= 24);//24bitカラーまで対応
		assert((cbits%3)==0);//23bitなどの3で割り切れない数は対応しない
		int bits = cbits / 3;
		Rval = BitSet(bits,false);
		Gval = BitSet(bits,false);
		Bval = BitSet(bits,false);
		
		//rについて
		for(int i=0;i<bits;i++)
			Rval[i] = (r>>i)%2;
			
		//gについて	
		for(int i=0;i<bits;i++)
			Gval[i] = (g>>i)%2;
		
		//bについて
		for(int i=0;i<bits;i++)
			Bval[i] = (b>>i)%2;
	}
	this(ColorSet v){
		Rval = BitSet(v.length,false);
		Gval = BitSet(v.length,false);
		Bval = BitSet(v.length,false);
		
		Rval = v.red.dup;
		Gval = v.green.dup;
		Bval = v.blue.dup;
	}
	this(uint color,uint cbits){
		assert(cbits <= 24);//24bitカラーまで対応
		assert((cbits%3)==0);//23bitなどの3で割り切れない数は対応しない
		int bits = cbits / 3;
		Rval = BitSet(bits,false);
		Gval = BitSet(bits,false);
		Bval = BitSet(bits,false);
		
		//colorを分割してrgbに代入
		ubyte r = cast(ubyte)(color >> (bits * 2)) % (1<<bits);
		ubyte g = cast(ubyte)(color >> (bits * 1)) % (1<<bits);
		ubyte b = cast(ubyte)(color >> (bits * 0)) % (1<<bits);
		
		//rについて
		for(int i=0;i<bits;i++)
			Rval[i] = (r>>i)%2;
			
		//gについて	
		for(int i=0;i<bits;i++)
			Gval[i] = (g>>i)%2;
		
		//bについて
		for(int i=0;i<bits;i++)
			Bval[i] = (b>>i)%2;
	}
	
	BitSet opIndex(int x){
		assert(x < 3);//例外処理
		assert(x >= 0);//例外処理
		switch(x){
			case 0:
				return Rval;
				break;//一応
			case 1:
				return Gval;
				break;
			case 2:
				return Bval;
				break;
			default :
				writeln("やめてください死んでしまいます");//普通のコンソール(SJIS)なら文字化けしますｗ
				return BitSet(0x00);
		}
	}
	BitSet opIndexAssign(BitSet src,uint x){
		assert(x < 3);//例外処理
		assert(x >= 0);//例外処理
		switch(x){
			case 0:
				Rval = src.dup;
				return Rval;
				break;//一応
			case 1:
				Gval = src.dup;
				return Gval;
				break;
			case 2:
				Bval = src.dup;
				return Bval;
				break;
			default ://一応
				writeln("やめてください死んでしまいます");//普通のコンソール(SJIS)なら文字化けしますｗ
				return BitSet(0x00);
		}
	}
	BitSet opIndexAssign(ubyte src,uint x){
		assert(x < 3);//例外処理
		assert(x >= 0);//例外処理
		switch(x){
			case 0:
				Rval = src;
				return Rval;
				break;//一応
			case 1:
				Gval = src;
				return Gval;
				break;
			case 2:
				Bval = src;
				return Bval;
				break;
			default ://一応
				writeln("やめてください死んでしまいます");//普通のコンソール(SJIS)なら文字化けしますｗ
				return BitSet(0x00);
		}
	}
	BitSet opIndex(string s){
		assert((s=="r")||(s=="g")||(s=="b")||(s=="R")||(s=="G")||(s=="B"));
		switch(s){
			case "r","R":
				return Rval;
				break;
			case "g","G":
				return Gval;
				break;
			case "b","B":
				return Bval;
				break;
			default:
				writeln("やめてください死んでしまいます");//普通のコンソール(SJIS)なら文字化けしますｗ
				return BitSet(0x00);
				break;
		}
	}
	BitSet opIndexAssign(BitSet src,string s){
		assert((s=="r")||(s=="g")||(s=="b")||(s=="R")||(s=="G")||(s=="B"));
		switch(s){
			case "r","R":
				Rval = src.dup;
				return Rval;
				break;
			case "g","G":
				Gval = src.dup;
				return Gval;
				break;
			case "b","B":
				Bval = src.dup;
				return Bval;
				break;
			default:
				writeln("やめてください死んでしまいます");//普通のコンソール(SJIS)なら文字化けしますｗ
				return BitSet(0x00);
				break;
		}
	}
	BitSet opIndexAssign(ubyte src,string s){
		assert((s=="r")||(s=="g")||(s=="b")||(s=="R")||(s=="G")||(s=="B"));
		switch(s){
			case "r","R":
				Rval = src;
				return Rval;
				break;
			case "g","G":
				Gval = src;
				return Gval;
				break;
			case "b","B":
				Bval = src;
				return Bval;
				break;
			default:
				writeln("やめてください死んでしまいます");//普通のコンソール(SJIS)なら文字化けしますｗ
				return BitSet(0x00);
				break;
		}
	}
	
	uint opAssign(uint x){
		Rval = cast(ubyte)((x>>(8*2))%(1<<length));
		Gval = cast(ubyte)((x>>(8*1))%(1<<length));
		Bval = cast(ubyte)((x>>(8*0))%(1<<length));
		
		return x;
	}
	ColorSet opAssign(ColorSet C){
		Rval = C.Rval.dup;
		Gval = C.Gval.dup;
		Bval = C.Gval.dup;
		return this;
	}
	
	bool opEquals(ColorSet C){
		return ((Rval == C.Rval)&&(Gval == C.Gval)&&(Bval == C.Gval));
	}
	
	auto length(){return Rval.length;}
	auto cbits(){return Rval.length*3;}
	ref BitSet red(){return Rval;}
	ref BitSet green(){return Gval;}
	ref BitSet blue(){return Bval;}
	ColorSet dup(){return ColorSet(Rval.toubyte , Gval.toubyte , Bval.toubyte , length);}
	void set(ubyte r,ubyte g,ubyte b){
		Rval = r;
		Gval = g;
		Bval = b;
	}
	void set(BitSet r,BitSet g,BitSet b){
		Rval = r.dup;
		Gval = g.dup;
		Bval = b.dup;
	}
	uint rgb(){return (Rval ~ Gval ~ Bval).touint;}
	
	BitSet Rval;
	BitSet Gval;
	BitSet Bval;
}

//A~Z,0~9のフォントを格納
class Fonts{
	this(string filename = "Fonts.txt"){
		File fp = File(filename,"r");
		File f = File(filename,"r");
		char[][] temp;
		foreach(string buf ; lines(f))
			temp ~= cast(char[])buf;
		
		//ファイルの中でもっとも長さが同じものが多い行の列数（文字数）を取得
		int[] freq;
		foreach(ref int a;freq){
			a = 0;
		}
		foreach(char[] buf ; temp){
			if(freq.length <= buf.length){
				freq.length = buf.length + 1; 
			}
			++freq[buf.length];
		}
		int max=0 , maxidx;
		foreach(int idx,int val;freq){
			if(max < val){
				max = val;
				maxidx = idx;
			}
		}
		
		int MajorLineIdx;
		foreach(int idx , char[] buf ; temp){
			if(buf.length == maxidx){
				MajorLineIdx = idx;
				break;
			}
		}
		
		int MajorLineLength=0;
		foreach(char a ; temp[MajorLineIdx])
			if(a == '0' || a == '1')
				++MajorLineLength;
		
		//ここまでで情報はMajorLineIdx(最初に出現する情報行の行数)
		//MajorLineLength…情報行の0と1の数
		//以下からは情報行が何行の塊で存在するか調べる
		int Lines=0;
		for(int i=MajorLineIdx;i<temp.length;i++){
			if(temp[i].length == maxidx)
				++Lines;
			else
				break;
		}
		
		//freqに頻度が入っているが、頻度を１回あたりの行数でわれば、何個のフォントかわかる
		int NumofFonts = roundTo!(int)(cast(real)freq[maxidx] / cast(real)Lines);
		
		//以上で知りたい情報はすべて知れたので格納していく。
		string StringIdx;
		int startIdx=0 , FontsIdx=0;
		_val.length = NumofFonts;
		
		foreach(int idx , char[] buf ; temp){
			if(buf.length < maxidx){
				if(isAlphaNum(buf[0])){
					buf.length = 1;
					StringIdx = cast(string)buf;
				}
				continue;
			}
			if(startIdx == 0){
				startIdx = idx;
				_val[FontsIdx].length = Lines;
				_tag[StringIdx] = FontsIdx;
			}
			BitSet Btemp = BitSet(MajorLineLength,false);
			for(int i=MajorLineLength-1;i>=0;i--){
				Btemp <<= 1;
				Btemp[0] = (buf[i] == '1') ? true : false ;
			}
			_val[FontsIdx][idx - startIdx] = Btemp;
			
			if(idx - startIdx == (Lines-1)){
				startIdx = 0;
				++FontsIdx;
			}
		}
		
	}
	
	BitSet[] opIndex(string s){
		return _val[_tag[s]];
	}
	BitSet[] opIndexAssign(BitSet[] B,string s){
		for(int i=0;i<8;i++)
			_val[_tag[s]] = B.dup;
		return _val[_tag[s]];
	}
	
	BitSet[][] _val;
	int[string] _tag;
}

void CSVout(LedMatrix[] src,string filename){
//現在は改変済み。製作されたものの軸のズレを修正しているはず。
	auto file = File(filename,"w");
	
	for(int i=0;i<src.length;i++){
	
		if((i!=(src.length -1)) && (i!=0))//0フレーム目か最終フレームでもない限り
			if(src[i-1]==src[i])continue;//変化分以外の余分は書かない
		
		if(src.length > 0xFFF)
			file.writef("%04x,",i);
		else
			file.writef("%03x,",i);
		
		for(int z=0;z<src[0].zlength;z++){
			for(int x=0;x<src[0].xlength;x++){
				//このforの中身をいろいろ変えている。
				if(x % 2 == 0)
					file.writef("%02x",src[i].yLine(z,x+1).toubyte);
				else
					file.writef("%02x",src[i].yLine(z,x-1).toubyte);
			}
			if(z != (src[0].zlength -1))file.writef(",");
		}
		file.writef("\n");
	}
	writefln("finished\nOutPut FILE is %s",filename);
}

void refresh(ref LedMatrix[] dst,LedPlan plan,ubyte val){
	dst.clear;
	for(int i=0;i<plan.flames;i++)
		dst ~= LedMatrix(plan.zDim,plan.yDim,plan.xDim,val);
}

void resize(ref LedMatrix[] dst,LedPlan plan){
	dst.length = plan.total;
	for(int i=0;i<plan.total;i++)
		dst[i].resize(plan);
}

/+
void FuncGo(ref LedMatrix[] dst,Triple!(int[] function(real,LedPlan)) Ft,LedPlan plan,uint div,uint havef){
	/*
	1フレームをdiv回に分割して計算する。havefフレームの間だけその点灯情報を保持する。
	1フレーム当たりの点灯情報はdiv×int[].lengthとなり、
	全体ではdiv*int[].length*havef個のLEDの点灯情報を所持
	
	
		引数説明
	・ref LedMatrix[] dst … この変数に結果を入れる
	・Triple!(int[] function(real,LedPlan)) Ft … x,y,zがフレーム数f(実数型)についての媒介変数方程式x(f),y(f),z(f)の複数解
	・LedPlan plan … どのようなプランなのか
	・uint div … 1フレームを何分割するか。この値を大きくするとドットがなめらかになる。
	・uint havef … 最大何フレーム前までの情報を保持するか。
	
		int[] function(real,LedPlan)について
	　int[] function(real)とは、たとえは(int)sin(x)のような関数のことで、ある浮動小数点値(real)が与えられたときに、
	複数の整数値を配列にして返す関数である。以下に例をあげておく。
	int[] exFunc(real flame,LedPlan plan){
		int[] ret;
		ret ~= cast(int)(4.0*sin(flame) + 4.0);
		ret ~= cast(int)(4.0*cos(flame) + 4.0);
		ret ~= cast(int)(4.0*cos(flame)*sin(flame) + 4.0);
	}
	上記のような関数をx,y,zぞれぞれについて用意してTripleに格納して引数とする。
	たぶんこれ以上簡単につくれといわれれば2ヶ月かけてアイディアを振り絞るしかない
	*/
	
	dst.clear;
	
	Pos[][] pos;
	Pos[] tmp;
	int[] x,y,z;
	int a;
	for(int f=0;f<plan.flames;f++){
		if(pos.length >= havef)//もし所持数の上限に達していたら
			pos.popFront;//前から1フレームの組みを消す。
			
			tmp.clear;
		
		//このフレームでの点灯情報をtmpに格納
		for(int i=0;i<div;i++){
			x = Ft.x(cast(real)f + cast(real)i/cast(real)div , plan);
			y = Ft.x(cast(real)f + cast(real)i/cast(real)div , plan);
			z = Ft.x(cast(real)f + cast(real)i/cast(real)div , plan);
			
			//x,y,zのうち一番短いものに合わせる
			a = (x.length > y.length)? y.length : x.length;
			a = (a > z.length)? z.length : a;
			
			for(int j=0;j<a;j++){
				tmp ~= Pos(x[j] , y[j] , z[j]);
			}
		}
		//情報の入れ込み
		pos ~= tmp;
		dst ~= LedMatrix(plan,0x00);
		
		//情報の入れ込み
		for(int i=0;i<pos.length;i++)
			dst[$-1].merge(pos[i],true);
	}
}

void FuncGo(ref CLMatrix[] dst,ColorSet function(int,int,int,int,CLPlan) Ft,CLPlan plan){
	/*
		引数説明
	・ref CLMatrix[] dst … この配列に結果を返す。
	・ColorSet function(int,int,int,int,CLPlan) Ft … x,y,z,flameから色を計算する関数。
	・CLPlan plan … どんなプランでつくるのか。
	
		ColorSet function(int,int,int,int,CLPlan)について
	　この関数はx,y,zとフレーム数を渡されたときにある色を返す関数とする。
	例えば
	ColorSet exTestFunc(int x,int y,int z,int flame,CLPlan plan){
		auto ret = ColorSet(x,y,z,plan.cbits);
		return ret;
	}
	このような関数となる。
	*/
	
	dst.clear;
	
	for(int f=0;f<plan.flames;f++){
		dst ~= CLMatrix(plan);
		for(int x=0;x<plan.xDim;x++)
			for(int y=0;y<plan.yDim;y++)
				for(int z=0;z<plan.zDim;z++)
					dst[$-1][x,y,z] = Ft(x,y,z,f,plan);
	}
}
+/
void FuncGO(ref LedMatrix[] dst,Pos[] function(real,LedPlan,Pos[]) Ft,LedPlan plan,uint div,uint havef=0){
	/*
	1フレームをdiv回に分割して計算する。havefフレームの間だけその点灯情報を保持する。
	1フレーム当たりの点灯情報はdiv×int[].lengthとなり、
	全体ではdiv*int[].length*havef個のLEDの点灯情報を所持
	
	
		引数説明
	・ref LedMatrix[] dst … この変数に結果を入れる
	・Pos[] function(real,LedPlan,Pos[]) Ft … x,y,zがフレーム数f(実数型)についての媒介変数方程式x(f),y(f),z(f)の解の配列
	・LedPlan plan … どのようなプランなのか
	・uint div … 1フレームを何分割するか。この値を大きくするとドットがなめらかになる。
	・uint havef … 最大何フレーム前までの情報を保持するか。0のときはずっと保持。
	
		Triple!(int)[] function(real,LedPlan,Pos[])について
	　Triple!(int)[] function(real,LedPlan,Pos[])とは、ある浮動小数点値(real)が与えられたときに、
	複数の整数値を配列にして返す関数である。以下に例をあげておく。
	Triple!(int) exFunc(real flame,LedPlan plan){
		auto val = Triple!(int)[](3);//x,y,zの組みを3つ作成…Triple!(int)[3]のこと
		for(int i=0;i<3;i++){
			val[i].x = cast(int)(3.5*sin(flame*i) + 3.5);
			val[i].y = cast(int)(3.5*cos(flame*i) + 3.5);
			val[i].z = cast(int)(3.5*cos(flame*i)*sin(flame) + 3.5);
		}
		return val;
	}
	最後の第三引数Pos[]には直前の点灯状況が入る。
	*/
	
	dst.clear;
	
	Pos[][] pos;
	Pos[] tmp , pre;
	Triple!(int)[] x;
	for(int f=0;f<plan.flames;f++){
		if((pos.length >= havef)&&havef)//もし所持数の上限に達していたら
			pos.popFront;//前から1フレームの組みを消す。
			
		tmp.clear;
		x.clear;
		//このフレームでの点灯情報をtmpに格納
		for(int i=0;i<div;i++)
			tmp ~= Ft(cast(real)f + cast(real)i/cast(real)div , plan,pre);
		
		//情報の入れ込み
		pre = tmp.dup;//直前情報
		pos ~= tmp.dup;//現在の状況
		dst ~= LedMatrix(plan,0x00);
		
		//情報の入れ込み
		for(int i=0;i<pos.length;i++)
			dst[$-1] << pos[i];
	}
}

void FuncGO(ref LedMatrix[] dst,Triple!(int)[] function(int,LedPlan,Pos[]) Ft,LedPlan plan,uint havef=0){
	dst.clear;
	
	Pos[][] pos;
	Pos[] tmp , pre;
	Triple!(int)[] x;
	for(int f=0;f<plan.flames;f++){
		if((pos.length >= havef)&&havef)//もし所持数の上限に達していたら
			pos.popFront;//前から1フレームの組みを消す。
			
		tmp.clear;
		tmp = Ft(f , plan ,pre);
		
		//情報の入れ込み
		pos ~= tmp.dup;
		dst ~= LedMatrix(plan,0x00);
		pre = tmp.dup;
		
		//情報の入れ込み
		for(int i=0;i<pos.length;i++)
			dst[$-1] << pos[i];
	}
}

version(unittest){
	unittest{
		Fonts Font = new Fonts();
		for(int i=0;i<8;i++){
			for(int j=0;j<8;j++)
				writef("%d",Font["1"][i][j]);
			writeln("");
		}
		for(int i=0;i<8;i++){
			for(int j=0;j<8;j++)
				writef("%d",Font["0"][i][j]);
			writeln("");
		}
		for(int i=0;i<8;i++){
			for(int j=0;j<8;j++)
				writef("%d",Font["Z"][i][j]);
			writeln("");
		}
	}

	unittest{
		ubyte CA = 0xCA;
		ubyte AA = 0x11;
		//一番怖いBitSetのテスト
		BitSet A = CA;
		BitSet B = AA;
		BitSet C;
		
		BitSet D = A.bitarray;
		assert(cast(ubyte)D == cast(ubyte)A);
		assert(cast(ubyte)A == CA);C = B;
		assert(C == B);
		assert(A > B);
		assert(B < A);
		assert(cast(ubyte)(A&B) == (CA & AA));
		assert(cast(ubyte)(A|B) == (CA | AA));
		assert(cast(ubyte)(A^B) == (CA ^ AA));
		assert(cast(ubyte)A.rot_l(2) == 0x2B);
		assert(cast(ubyte)A.rot_l(16) == CA);
		assert(cast(ubyte)A.rot_r(2) == 0xB2);
		assert(cast(ubyte)A.rot_l(24) == CA);
		assert(cast(ubyte)(A<<3) == cast(ubyte)(CA << 3));
		assert(cast(ubyte)(A>>3) == cast(ubyte)(CA >> 3));
		assert(cast(ubyte)(A<<8) == 0);
		assert(cast(ubyte)(A>>8) == 0);
		assert(cast(ubyte)(A&AA) == (CA & AA));
		assert((AA & A) == (AA & CA));
		assert(cast(ubyte)(A|AA) == (CA | AA));
		assert((AA & A) == (AA & CA));
		assert(cast(ubyte)(A^AA) == (CA ^ AA));
		assert((AA ^ A) == (AA ^ CA));
		assert(cast(ubyte)(C = CA) == CA);
		assert(cast(ubyte)(C = A) == CA);
		assert(cast(ubyte)(C&=B) == cast(ubyte)(A&B));C = A;
		assert(cast(ubyte)(C|=B) == cast(ubyte)(A|B));C = A;
		assert(cast(ubyte)(C^=B) == cast(ubyte)(A^B));C = A;
		assert(cast(ubyte)(C<<=2) == cast(ubyte)(A<<2));C = A;
		assert(cast(ubyte)(C>>=2) == cast(ubyte)(A>>2));C = A;C.length = 17;
		assert(C.length == 17);C = A;
		assert(C.length == 8);
		assert(cast(ubyte)(C&=AA) == cast(ubyte)(A&AA));C = A;
		assert(cast(ubyte)(C|=AA) == cast(ubyte)(A|AA));C = A;
		assert(cast(ubyte)(C^=AA) == cast(ubyte)(A^AA));C = A;
		assert(cast(ubyte)(A.dup) == cast(ubyte)A);
		assert(cast(ubyte)(A+B) == CA+AA);
		assert(cast(ubyte)(A-B) == CA-AA);C = 0xFF;
		assert(cast(ubyte)(A.SB!"+"(C)) == 0xFF);
		assert(cast(ubyte)(B.SB!"-"(A)) == 0x00);
		assert(cast(ubyte)C.SU!"++" == 0xFF); 
		
		C = A;
		C[0] = C[0] ? false : true;
		assert(A[0] != C[0]);
		
		BitSet V;V.length = 8;
		V[0] = true;
	}

	unittest{
		auto A = LedMatrix(3,3,3,0x00);
		LedMatrix B;
		B << A;
		A[0][0][0] = true;
		assert(!B[0][0][0]);//Bはfalse
		Pos C=Pos(1,1,2);
		A <<= C;
		assert(A[1,1,2]);
		assert(A[2][1][1]);
		assert(!A[0][0][0]);
		A["x-yz",1,2] = A["x-yz",1,2] << 1;
		assert(A[2,1,2]);
		A["x-yz",1,2] >>>= 1;
		assert(A[1,1,2]);
		
		A["x-yz",1,2] <<= 1;
		assert(A[2,1,2]);
		A["x-yz",1,2] >>= 1;
		assert(A[1,1,2]);
		B = LedMatrix(8,8,8);
				Pos X;	X.set(1,2,4);
				B[X] = true;
				assert(B[X] == B[1,2,4]);
		
		writeln("OK");
	}
	void main(){
		writeln("myLedCube's unittest is done");
	}
	
}