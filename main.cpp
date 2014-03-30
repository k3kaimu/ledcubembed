/*
 * Japanese Document : https://github.com/k3kaimu/ledcubembed/blob/master/main.cpp
 */

#include "mbed.h"
#include <vector>
#include <iostream>
#include <fstream>
#include <new>
#include <stdint.h>
#include <algorithm>

#define CLK(pin) {(pin)=0;(pin)=1;(pin)=0;}
#define CGnd(n) {gnd = 0x1 << (n);}

#define ENDL "\r\n"<<flush;

using namespace std;

typedef uint8_t ubyte;
typedef uint16_t ushort;
typedef uint32_t uint;
typedef uint64_t ulong;

/* file */
LocalFileSystem local("local");

/* pin */
DigitalOut rck(p20);    //Shift Register Latch Clock
DigitalOut sck(p19);    //Shift Register Serial Clock
BusOut led(p21,p22,p23,p24,p25,p26,p27,p28);    //Shift Register IN
//BusOut gnd(p11,p12,p13,p14,p15,p16,p17,p18);    //GND pin
BusOut gnd(p18, p17, p16, p15, p14, p13, p12, p11);
//DigitalIn endSw(p8);  //END Switch

// 動作状況確認用のLED
DigitalOut led1(LED1);
DigitalOut led2(LED2);
DigitalOut led3(LED3);
DigitalOut led4(LED4);

// 各ボタンの設定
DigitalIn _restart(p5);
DigitalIn _toInfLoop(p6);
DigitalIn _shuffle(p7);


struct RisingEdge
{
    RisingEdge(){}
    RisingEdge(DigitalIn* state) : _state(state) {}


    void update()
    {
        _bLastState = _state->read();
    }


    bool read()
    {
        bool now = _state->read();
        bool ret = !_bLastState && now;
        _bLastState = now;
        return ret;
    }
    
  
  private:
    DigitalIn* _state;
    bool _bLastState;
};

RisingEdge restart(&_restart);
RisingEdge toInfLoop(&_toInfLoop);
RisingEdge shuffle(&_shuffle);


/* functions */
vector<char*> readFileNames();
inline void outputToLED(ubyte*);

/* Memory Allocate */
ubyte DATA[16384] __attribute__((section("AHBSRAM0"))); //serial USB memory area
ubyte DATA1[16384] __attribute__((section("AHBSRAM1")));//ethernet memory area

void no_memory()
{
    printf("panic: can't allocate to memory!\r\n");
    led3 = 1;
    led4 = 0;
    exit(-1);
}


void rand_init()
{
    AnalogIn rseed1(p19), rseed2(p20);
    std::srand(rseed1.read_u16() ^ rseed2.read_u16());
}


void initialize()
{
    rand_init();

    rck = DigitalOut(p20);
    sck = DigitalOut(p19);
    restart.update();
    toInfLoop.update();
    shuffle.update();
}


int main()
{
    initialize();
    vector<char*> fnames;
    set_new_handler(no_memory);

    cout.setf(ios::hex, ios::basefield);

    led1 = 0;
    led2 = 0;
    led3 = 1;
    led4 = 1;

    fnames = readFileNames();

    cout << "Done FileRead!" << ENDL;

    vector<char*>::iterator it = fnames.begin();
    for(uint i = 0;it != fnames.end(); ++it, ++i)
        cout << i << " : " << *it << ENDL;

    led3 = 0;
    led4 = 1;

    led = 0;
    for(uint i = 0; i < 8; ++i)
        CLK(sck);
    CLK(rck);

    cout << "Done Initialize All!!" << ENDL;

    //random list
    int *rl;
    rl = new int[fnames.size()];
    for(int i = 0; i < fnames.size(); ++i)
        rl[i] = i;

    bool bInfMode = false;

    //while(endSw){
    while(1){
        //randomize
      LShuffle:
        if(!bInfMode)
            random_shuffle(rl, rl + fnames.size());

        for(uint i = 0; i < fnames.size(); ++i){
            vector<ushort> frameIdxs;

            FILE *fp;
            fp = fopen(fnames[rl[i]], "rb");
            if(fp == NULL){
                cout << "Not Found : Data File :" << fnames[rl[i]] << ENDL;
                //exit(-1);
                continue;
            }

            cout << "Start : " << fnames[rl[i]] << ENDL;
            led1 = 1;
            for(uint i = 0; i < 512; ++i){
                ushort f;

                if(fread(&f, sizeof(ushort), 1, fp) != 1)
                    break;
                if(fread(DATA + i * 64, sizeof(ubyte), 64, fp) != 64)
                    break;

                frameIdxs.push_back(f); 
            }
            fclose(fp);

            // 現在のフレームidxと次のidxとの2つは最低必要
            if(frameIdxs.size() <= 1)
                continue;

            led1 = 0;
            restart.update();
            toInfLoop.update();
            shuffle.update();
            
          LRestart:
            // 継続条件がi < frameIdxs.size()だと、frameIdxs[i+1]が範囲外参照となるのでNG
            for(uint i = 0; i < (frameIdxs.size() - 1); ++i){
                // スイッチが押されていないかチェックする
                if(restart.read())
                    goto LRestart;
                if(toInfLoop.read()){
                    if(bInfMode)
                        goto LNextMode;

                    bInfMode = !bInfMode;
                }
                if(shuffle.read()){
                    bInfMode = false;
                    goto LShuffle;
                }

                // 次のフレームまで同一フレームを表示し続ける
                for(uint j = frameIdxs[i]; j < frameIdxs[i+1]; ++j)
                    outputToLED(DATA+i*64);
            }

            // 無限ループモードでは、次も同じファイルを読み込む
            if(bInfMode)
                --i;
            
          LNextMode:
            int _dummy_ = 0;
        }
    }
    led1 = 1;
    led2 = 1;
    
    //return 0;
}


vector<char*> readFileNames(){
    ifstream fp("/local/filename.txt", ifstream::in);
    vector<char*> data;
    char* name;

    if(!fp){
        cout << "Not Found : filename.txt" << ENDL;
        led2 = 1;
        exit(-1);
    }

    while(fp.good()){
        name = new char[32];
        fp.getline(name,31);
        data.push_back(name);
    }
    fp.close();

    return data;
}

//Output data   (assert(sizeof(LED) == 64))
inline void outputToLED(ubyte *LED){
    // チラツキ回避のため、二回同じ表示をする
    for(uint k = 0; k < 2; ++k){
        for(uint i = 0; i < 8; ++i){
            for(uint j = 0; j < 8; ++j){
                led = LED[i*8 + j];
                CLK(sck);
            }
            CGnd(i);
            CLK(rck);
            wait_us(1550);
        }
   }
}
