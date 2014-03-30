NNCT LED Cube Project
===========

* LICENSE

    NYSL


LED Cubeプロジェクトのリポジトリ。
ソースコードとか、mbedにツッコムバイナリとかの保存用。

## リポジトリの説明とかとか

* mbedにツッコム用のファイルたちは`files`ディレクトリの中身全部。

* `main.cpp`がmbedでのLED Cubeのプログラム。

* `d`ディレクトリの中身は興味があれば。  


## LED Cubeにツッコムためのバイナリについて

LED Cubeのバイナリの生成はD言語を使って行っています。
このコードは`d`ディレクトリにありますが、古いしコード汚いので信用しないでください。  
(3年のときに書いたコードだから仕方ないね)

`d/framework.d`だけが重要です。
他は信用しないでください。  

* エンディアン  
mbedに入れる点灯情報のバイナリは、基本的にリトルエンディアンとなっています。
これは、現在のIntel CPUとmbedの両方共がリトルエンディアンであるためです。

* 点灯情報のバイナリの構成について  

8x8x8という大きさを持ったLED Cubeですから、点灯情報も膨大なものとなります。
そこで、このLED Cubeでは情報を圧縮しています。
その圧縮の仕方は簡単で、現在のフレームの点灯状況と次のフレームのそれが全く同一であれば、次のフレームはバイナリに含めないという方法です。
つまりは点灯パターンの切り替わりの時の情報だけを保存しておきます。
よって、各点灯パターンの切り替わりの時間(先頭からのフレーム数)も必要になります。

以上により、次のような構成となっています。

~~~~~
[2byte(frame index)] [64byte(512bit, frame data)]
[2byte(frame index)] [64byte(512bit, frame data)]
[2byte(frame index)] [64byte(512bit, frame data)]
[2byte(frame index)] [64byte(512bit, frame data)]
[2byte(frame index)] [64byte(512bit, frame data)]
[2byte(frame index)] [64byte(512bit, frame data)]
~~~~~

+ `[2byte(frame index)]`
    先頭から数えた際のそのフレームの番号です。
    もしLED Cubeの点灯速度が`1fps`(1秒間に1フレーム)であれば、`frame index`秒後に表示されることになります。
    また、このフレームは、次の`frame index`まで継続されることになります。


+ `[64byte(512bit, frame data)]`

    512個のLEDの点灯状態を表すために64byte使用します。
    この並び順は、mbed内でそのまま出力できるようになっています。  
    注意しなければいけないこととして、ハンダ付けミスによって`[2bit目][1bit目][4bit][3bit目]...[8bit目][7bit目]`というように、奇数bit目と偶数bit目を入れ替える必要があることです。

    ↓こんな感じ↓

    ~~~~~
    [8bit(各シフトレジスタの2bit目, 高さの階層はz=0)][8bit(2bit目, z=0)][8bit(2bit目, z=0)]...[8bit(7bit目, z=0)]
    [8bit(各シフトレジスタの2bit目, z=1)][8bit(1bit目, z=1)]...[8bit(8bit目, z=1)]
    [8bit(各シフトレジスタの2bit目, z=2)][8bit(1bit目, z=2)]...[8bit(8bit目, z=2)]
    .
    .
    .
    [8bit(各シフトレジスタの2bit目, z=7)][8bit(1bit目, z=7)]...[8bit(8bit目, z=7)]
    ~~~~~


## その他

不明な点があれば、どうにかして連絡ください。
