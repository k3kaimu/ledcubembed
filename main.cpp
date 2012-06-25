/*
* LED Cubeのプログラムです。mbed用。
*/

#include "mbed.h"
#include <vector>
#include <iostream>
#include <fstream>
#include <new>
#include <stdint.h>
#include <algorithm>

#define CLK(pin) {(pin)=0;(pin)=1;}
#define CGnd(n) {gnd = 0x1 << (n);}

#define ENDL "\r\n"<<flush;

using namespace std;

/* file */
LocalFileSystem local("local");

/* pin */
DigitalOut rck(p19);    //シフトレジスタのラッチクロック
DigitalOut sck(p20);    //シフトレジスタのシリアルクロック
BusOut led(p21, p22, p23, p24, p25, p26, p27, p28);    //シフトレジスタのシリアルinピン
BusOut gnd(p11, p12, p13, p14, p15, p16, p17, p18);    //グランドpin
//DigitalIn sw(p10);  //ON OFF Switch

DigitalOut led1(LED1);
DigitalOut led2(LED2);
DigitalOut led3(LED3);
DigitalOut led4(LED4);

/* functions */
vector<char*> FileNameRead();
inline void LEDout(uint8_t*);

/*シリアル入力やethernetの領域を確保し、あらかじめその領域に保存することにより、高速なLEDの点灯を可能にします */
uint8_t DATA[16384] __attribute__((section("AHBSRAM0"))); //serial USB memory area
uint8_t DATA1[16384] __attribute__((section("AHBSRAM1")));//ethernet memory area

void no_memory(){
    printf("panic: can't allocate to memory!\r\n");
    led3 = 1;
    led4 = 0;
    exit(-1);
}

int main(){
    vector<char*> filenames;
    set_new_handler(no_memory);
    cout.setf(ios::hex, ios::basefield);
    
    led1 = 0;
    led2 = 0;
    led3 = 1;
    led4 = 1;
    
    filenames = FileNameRead();
    
    cout << "Done FileRead!" << ENDL;
    
    vector<char*>::iterator it = filenames.begin();
    for(int i=0; it != filenames.end(); ++it, ++i)
        cout << i << " : " << *it << ENDL;
    
    led3 = 0;
    led4 = 1;
    
    led = 0;
    for(int i = 0; i < 8; ++i)
        CLK(sck);
    CLK(rck);
    
    cout << "Done Initialize All!!" << ENDL;
    
    //random list
    int *rl;
    rl = new int[filenames.size()];
    for(int i=0; i < filenames.size(); ++i)
        rl[i] = i;
    
    /*while(sw)*/
    while(1){
        //ランダムに並び替えます
        random_shuffle(rl, rl + filenames.size());
        for(int i=0; i < filenames.size(); ++i){
        
            vector<uint16_t> fileflame_s;
            
            FILE *fp;
            fp = fopen(filenames[rl[i]], "rb");
            if(fp == NULL){
                cout << "Not Found : Data File :" << filenames[rl[i]] << ENDL;
                //exit(-1);
                continue;
            }
            
            cout << "Start : " << filenames[rl[i]] << ENDL;
            led1 = 1;
            for(int i=0;i < 512;++i){
                uint16_t f;
                
                if(fread(&f, sizeof(uint16_t), 1, fp) != 1)
                    break;
                if(fread(DATA+i*64, sizeof(uint8_t), 64, fp) != 64)
                    break;    
                    
                fileflame_s.push_back(f);
            }
            led1 = 0;
            //cout << filenames[rl[i]] << ENDL;
            for(int i = 0; i < (fileflame_s.size() - 1); ++i)
                for(int j = fileflame_s[i]; j < fileflame_s[i+1]; ++j)
                    LEDout(DATA+i*64);
                    
            LEDout(DATA + (fileflame_s.size() - 1)*64);
            uint64_t t = ((uint64_t*)DATA)[0];
            cout << t << ENDL;
            
            led = 0;
            for(int i = 0; i < 8; ++i)
                CLK(sck);
            CLK(rck);
            
            fclose(fp);
        }
    }
    
    //return 0;
}

//filename.txtの内容を読み込み、ファイルのリストを返します
vector<char*> FileNameRead(){
    ifstream fp("/local/filename.txt",ifstream::in);
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

//データを出力します。LEDは配列で、その大きさは64でなければいけません。
inline void LEDout(uint8_t *LED){
    for(int k = 0; k < 2; ++k){
        for(int i = 0; i < 8; ++i){
            CGnd(8);
            for(int j = 0; j < 8; ++j){
                led = LED[i*8 + j];
                CLK(sck);
            }
            CGnd(i);
            CLK(rck);
            wait_us(1550);
        }
   }
}