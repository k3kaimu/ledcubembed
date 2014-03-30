/++
LEDオブジェクトはレンジの考えを全面的にサポートするように設計すること！<br>
オブジェクトはすべて前進レンジでなければならないとする。<br>
前進レンジゆえに以下のプロパティなどを所持すること<br>
・void popFront<br>
・T front		...	TはVector!intまたはVector!int[]とすること。<br>
・bool empty<br>
・U opAssign(typeof(this))	...	Uはvoidまたはtypeof(this)<br>
+/

module mydutil.ledcube.object;

import std.array;
import std.range;
//import std.random;
import std.conv:roundTo;
import std.math;
import std.numeric;
import std.algorithm;
import std.range:isInfinite;

import mydutil.ledcube.framework;
import mydutil.arith.linear;

version(unittest){
	import std.stdio;
	pragma(lib,"mydutil");
	void main(){
		writeln("End");
	}
}

///x,y,z,tが与えられた時にtrueを返せる関数
alias bool function(int x,int y,int z,int t) Fxyzt;

///LedCubeオブジェクトレンジかどうか判定します。
template isLCORange(T){
	static if(isInfinite!T && (is(ElementType!T == Vector!int) || is(ElementType!T == Vector!int[])))
		enum isLCORange = true;
	else
		enum isLCORange = false;
}


///境界からはみ出ると反射する点…return Vector!int
struct Refrect(uint X,uint Y,uint Z){
	auto velocity = Vector!real([1,0,0]);
	auto pos = Vector!real([0,0,0]);
	enum empty = false;			//無限レンジ
	int[] lim = [X,Y,Z];
	
	///コンストラクタ
	this(Vector!int start,Vector!real v){
		pos = start.vec.ElementCast!real;
		velocity = v[];
	}
	
	@property Vector!int front(){
		Vector!int p = Vector!int(array(map!(a => roundTo!int(a))(pos.array)));
		return p;
	}
	
	@property void popFront(){
		pos += velocity;
		for(int i=0;i<3;++i){
			if(pos[i] > lim[i]){
				pos[i] = lim[i];
				velocity[i] *= -1;
			}else if(pos[i] < 0){
				pos[i] = 0;
				velocity[i] *= -1;
			}
		}
	}
	
	typeof(this) opAssign(typeof(this) src){
		velocity = src.velocity[];
		pos = src.pos[];
		return this;
	}
}


///数式に従った線…return Vector!int[]
struct MathExpLine(uint X,uint Y,uint Z){
	Fxyzt f;
	int t = 0;
	enum empty = false;
	
	///コンストラクタ
	this(Fxyzt fun,int starttime = 0){
		f = fun;
		t = starttime;
	}
	
	@property Vector!int[] front(){
		Vector!int[] dst;
		for(int i=0;i<X;++i)
			for(int j=0;j<Y;++j)
				for(int k=0;k<Z;++k)
					if(Fxyzt(i,j,k,t))
						dst ~= Vector!int([i,j,k]);
		return dst;
	}
	
	@property void popFront(){
		t++;
	}
	
	typeof(this) opAssign(typeof(this) src){
		f = src.f;
		t = src.t;
		return this;
	}
	
}


///反射する球で、大きさはFxyzt関数により操作可能
struct RefrectBall(uint X,uint Y,uint Z){
	Refrect!(X,Y,Z) core;		//中心の座標
	int function(int,int,int,int) fr;			//半径を算出する関数
	enum empty = false;	//無限レンジ
	
	///コンストラクタ
	this(Vector!int start, Vector!real velocity, int function(int,int,int,int) f){
		core = Refrect!(X,Y,Z)(start,velocity);
		fr = f;
	}
	
	@property void popFront(){
		core.popFront();
	}
	
	@property Vector!int[] front(){
		Vector!int[] p;
		for(int i=0;i<X;++i)
			for(int j=0;j<Y;++j)
				for(int k=0;k<Z;++k){
					if(0 == roundTo!int(euclideanDistance(core.front.vec.ElementCast!real.array,cast(real[])[i,j,k])))
						p ~= Vector!int([i,j,k]);
				}
		return p;
	}
	
	typeof(this) opAssign(typeof(this) src){
		core = src.core;
		fr = src.fr;
		return this;
	}
}


///上下または左右に移動する壁
struct Wall(uint X,uint Y,uint Z,string s)if(s=="x"||s=="y"||s=="z"){
	alias Refrect!(X,Y,Z) RefrectX;
	static if(s=="x")
		RefrectX[] core;
	else static if(s=="y")
		RefrectX[] core;
	else
		RefrectX[] core;
	enum empty = false;
	
	///コンストラクタ
	this(real speed = 1){
		static if(s == "x"){
			for(int y=0;y<Y;++y)
				for(int z=0;z<Z;++z)
					core ~= RefrectX(Vector!int([0,y,z]),Vector!real([speed,0,0]));
		}else static if(s == "y"){
			for(int x=0;x<X;++x)
				for(int z=0;z<Z;++z)
					core ~= RefrectX(Vector!int([x,0,z]),Vector!real([0,speed,0]));
		}else{
			for(int x=0;x<X;++x)
				for(int y=0;y<Y;++y)
					core ~= RefrectX(Vector!int([x,y,0]),Vector!real([0,0,speed]));
		}
	}
	
	@property void popFront(){
		for(int i=0;i<core.length;++i)
			core.popFront();
	}
	
	@property Vector!int[] front(){
		Vector!int[] dst;
		dst = reduce!"a~b.front"(dst,core);
		return dst;
	}
	
	typeof(this) opAssign(typeof(this) src){
		core = src.core.dup;
		return this;
	}
	
}


///複数のLEDCubeレンジオブジェクトをまとめることができる。
LCRanges!Ranges lcranges(Ranges...)(Ranges range)if(allSaticfy!(isLCORange,Ranges)){
	return LCRanges!Ranges(range);
}

struct LCRanges(Ranges...)if(allSatisfy!(isLOCRanges,Ranges)){
private:
	Ranges _ranges;
	
public:
	enum empty = false;
	
	this(Ranges range){
		_ranges = range;
	}
	
	///レンジ基本関数
	void popFront(){
		foreach(r;ranges)
			r.popFront;
	}
	
	///ditto
	Vector!int[] front(){
		Vector!int[] dst;
		foreach(r;ranges)
			dst ~= r.front;
		return dst;
	}
	
	///ditto
	typeof(this) opAssign(typeof(this) src){
		foreach(int idx,a;_ranges)
			_ranges[i] = src[i];
		return this;
	}
	
	/++結合演算子により結合したものを返す。
	Example:
	------------------------------
	alias Wall!(8,8,8) Wall8;
	
	auto a = lcranges(Wall8()(1),Wall8(2),Wall8(3));
	auto b = a ~ Wall8(4);
	------------------------------
	+/
	LCRanges!(Ranges,T) opBinary(string s:"~",T)(T rhs){
		return typeof(return)(_ranges,rhs);
	}
	unittest{
		alias Wall!(8,8,8) Wall8;
		
		auto a = lcranges(Wall8()(1),Wall8(2),Wall8(3));
		auto b = a ~ Wall8(4);
	}
}
