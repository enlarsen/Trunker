//
//  main.m
//  Trunker
//
//  Created by Erik Larsen on 11/14/13.
//
//  Copyright (c) 2013 Erik Larsen.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <Foundation/Foundation.h>
#import "Affiliation.h"
#import "Call.h"

typedef struct OSW
{
    short command;
    short ID;
    bool group;
    bool isFrequency;
    bool isBad;
} OSW;

double accumulator = 0.0;
double bitError = 0.00;
int across = 0;

int sr = 0;
int bs = 0;
bool inSync = NO;
bool ob[1023];
int obHead = 0, obTail = 0;
bool gob[100];
bool osw[50];
int good = 0;
int blocks = 0;
int ct = 0;
OSW lastOSW;

const int bufferSize = 8192;
const int baudRate = 3600;
const int sampleRate = 48000;
const double timePerBit = 1.0 / baudRate;
const double timePerHalfBit = timePerBit / 2.0;



void analyze(int16_t *soundBuffer, int count);
void processBit(bool bit, int count);
void handleBit(bool bit);
void deinterleave(int skip);
void generateOSW(bool bit);
void processOSW(OSW computedOSW);
bool isFrequency(OSW osw);
void received310(OSW osw);
void received30b(OSW osw);
void received320(OSW osw);
void receivedFrequency(OSW osw);

void printCurrentAndLast(OSW osw);

NSMutableDictionary *affiliations;
NSMutableDictionary *calls;


int main(int argc, const char * argv[])
{
    int maxWords = 100;
    int16_t soundBuffer[maxWords];
    int count = 0;
    affiliations = [[NSMutableDictionary alloc] init];
    calls = [[NSMutableDictionary alloc] init];
    lastOSW.isBad = true;

    FILE *input;

    if(!strcmp(argv[1], "-"))
    {
        input = fopen("/dev/stdin", "r");
    }
    else
    {
        input = fopen(argv[1], "r");
    }

    if(!input)
    {
        printf("Could not open %s", argv[1]);
        exit(1);
    }
    @autoreleasepool {
        while(!feof(input))
        {

// fread(void *restrict ptr, size_t size, size_t nitems, FILE *restrict stream);

            fread(&soundBuffer[count++], 2, 1, input);
            if(count >= maxWords)
            {
                analyze(&soundBuffer[0], count);
                count = 0;
            }
        }
    }
    return 0;
}

void analyze(int16_t *soundBuffer, int size)
{
    int index = 0;
    static int count = 0;
    static bool bit = false;

    if(count != 0)
    {
        if(bit != (bool)(soundBuffer[index] > 0)) // bit flip on buffer boundry
        {
            processBit(bit, count);
            count = 0;
        }
    }

    while (index < size)
    {
        bit = soundBuffer[index++] > 0;

        count++;

        while (index < size && bit == (bool)(soundBuffer[index] > 0))
        {
            index++;
            count++;
        }

        if(index != size)
        {
            processBit(bit, count);
            count = 0;
        }
    }
}

void processBit(bool bit, int count)
{
    double delta = count;

    delta /= sampleRate;
    accumulator += delta;

    double fastCompare = bitError + timePerHalfBit;

    while (accumulator >= fastCompare)
    {
        handleBit(bit);
        accumulator -= timePerBit;
    }

    if (bit)
        bitError += (accumulator - bitError) / 15.0;

//    printf("bitError: %f\n", bitError);
}

void handleBit(bool bit)
{

    const int sync = 0xac;

    sr = (sr << 1) & 0xff;

    if (bit)
        sr |= 0x01;

    ob[bs] = bit;

    if (sr == sync)
    {
        if (bs > 83)
        {
            deinterleave(bs-83);
            inSync = true;
        }
    }
    if (bs < 989)
    {
        bs++;
    }
    else
    {
        bs = 0;
        inSync = false;

    }
}

void deinterleave(int skip)
{
    int i1, i2;

    ct = 0;

    for(i1 = 0; i1 < 19; ++i1)
    {
        for(i2 = 0; i2 < 4; ++i2)
        {
            generateOSW(ob[((i2*19) + i1) + skip]);
        }
    }
}

void generateOSW(bool bit)
{
    int i;
    int sr, sax, f1, f2, iid, cmd, neb;
    OSW computedOSW;

    gob[ct++] = bit;

    if (ct == 76)
    {
        if (blocks == 43)
        {
            blocks = 0; good = 0;
        }
        blocks++;
        sr = 0x036e;
        sax = 0x0393;
        neb = 0;

        for (i = 0; i < 76; i += 2)
        {
            osw[i >> 1] = gob[i];

            if (gob[i])
            {
                gob[i]     ^= true;
                gob[i + 1] ^= true;
                gob[i + 3] ^= true;
            }
        }

        for (i = 0; i < 76; i += 2)
        {
            if (gob[i + 1] && gob[i + 3])
            {
                osw[i >> 1] ^= true;
                gob[i + 1] ^= true;
                gob[i + 3] ^= true;
            }
        }
        for (i = 0; i < 27; i++)
        {
            if ((sr & 1) == 1)
                sr = (sr >> 1) ^ 0x0225;
            else
                sr >>= 1;

            if (osw[i])
                sax = sax ^ sr;
        }

        for (i = 0; i < 10; i++)
        {
            f1 = osw[36 - i] ? 0 : 1;
            f2 = sax & 1;

            sax >>= 1;

            if (f1 != f2)
                neb++;
        }
        if (neb == 0)
        {
            good++;
            bs = 0;
            iid = 0;
            for (i = 0; i < 16; i++)
            {
                iid <<= 1;

                if (!osw[i])
                    iid++;
            }
            computedOSW.ID = (short)(iid ^ 0x33c7);
            computedOSW.group = (osw[16] ^ true);

            cmd = 0;
            for (i = 17; i < 27; i++)
            {
                cmd <<= 1;

                if (!osw[i])
                    cmd++;
            }

            computedOSW.command = (short)(cmd ^ 0x032a);
            computedOSW.isBad = false;
            processOSW(computedOSW);
        }
        else
        {
            //printf("Bad\n");
            computedOSW.isBad = true;


            //showBadOSW(computedOSW);
        }
        lastOSW = computedOSW;
    }
}

void processOSW(OSW osw)
{

    // TODO: this might now be the best here.
    if(lastOSW.isBad == true)
    {
        return;
    }
    if(lastOSW.command == 0x308)
    {
        printf("Command: ");
        printCurrentAndLast(osw);
    }
    switch(osw.command)
    {
        case 0x308:
            return;
            break;

        case 0x310:
            received310(osw);
            break;

        case 0x30b:
            received30b(osw);
            break;

        case 0x320:
            received320(osw);
            break;

        default:
            if(isFrequency(osw))
            {
                receivedFrequency(osw);
                if(osw.ID == 0x1feb)
                {
                    printf("Control channel: ");
                    printCurrentAndLast(osw);
                }
                else
                {
                    double frequency = 851.1125 + 0.025 * (osw.command ^ 0x4);
                    printf("Frequency: %f, Talkgroup: %hu (%0.4hX)\n", frequency, osw.ID, osw.ID);
                }
            }
            else
            {
                printCurrentAndLast(osw);
            }
            break;
    }

}

bool isFrequency(OSW osw)
{
    if (osw.command >= 0 && osw.command <= 0x2f7)
    {
        return true;
    }
    if (osw.command >= 0x32f && osw.command <= 0x33f)
    {
        return true;
    }
    if (osw.command >= 0x3c1 && osw.command <= 0x3fe)
    {
        return true;
    }

    return false;
}

void received310(OSW osw)
{
    NSNumber *radio = [NSNumber numberWithShort:lastOSW.ID];

    short ID = osw.ID;

    ID &= 0xfff0;

    if(ID != osw.ID)
    {
        printf("Found odd ID: %0.4hX\n", osw.ID);
    }

    if([affiliations objectForKey:radio])
    {
        if (((Affiliation *)affiliations[radio]).kind == affiliation)
        {
            if (((Affiliation *)affiliations[radio]).group == ID)
            {
                return;
            }
            else
            {
                [affiliations removeObjectForKey:radio];
            }
        }
        else
        {
            if (((Affiliation *)affiliations[radio]).kind == deaffiliation)
            {
                [affiliations removeObjectForKey:radio];
            }
        }
    }
    else
    {

        Affiliation *a = [[Affiliation alloc] init];
        a.group = ID;
        a.kind = affiliation;
        a.radio = [radio shortValue];

        [affiliations setObject:a forKey:radio];
        printf("Radio %0.4hX aff--> %0.4hX\n", [radio shortValue], ID);
    }
}

void received30b(OSW osw)
{

    NSNumber *radio = [NSNumber numberWithShort:lastOSW.ID];

    if ([affiliations objectForKey:radio] &&
        ((Affiliation *)affiliations[radio]).kind == affiliation)
    {
        ((Affiliation *)affiliations[radio]).kind = deaffiliation;
        ((Affiliation *)affiliations[radio]).joinTime = [NSDate date];
        printf("%0.4hX deaff\n", [radio shortValue]);

    }
}

void received320(OSW osw)
{
    printf("System ID: %0.4hX ID: %0.4hX\n", lastOSW.ID, osw.ID);
}

void receivedFrequency(OSW osw)
{
    short channel = osw.command;
    short radio = lastOSW.ID;
    NSNumber *ID = [NSNumber numberWithShort:osw.ID & 0xfff0];

    if ([calls objectForKey:ID])
    {
        if (((Call *)calls[ID]).radio == radio)
        {
            NSDate *callTime = ((Call *)calls[ID]).callTime;
            if ([callTime compare: [callTime dateByAddingTimeInterval:-2.0]] ==  NSOrderedDescending)
            {
                ((Call *)calls[ID]).callTime = [NSDate date];
                ((Call *)calls[ID]).channel = channel;
//                Program.WriteToDB(calls[group]);
            }
            else
            {
                return;
            }

        }
        else
        {
            ((Call *)calls[ID]).radio = radio;
            ((Call *)calls[ID]).channel = channel;
            ((Call *)calls[ID]).callTime = [NSDate date];
//            Program.WriteToDB(calls[group]);
        }
    }

    else
    {
        Call *c = [[Call alloc] init];
        c.group = [ID shortValue];
        c.radio = radio;
        c.channel = channel;
        [calls setObject:c forKey:ID];
//        Program.WriteToDB(c);
    }

    printf("Call on channel: %0.4hX radio: %0.4hX --> talkgroup: %0.4hX\n", channel,
                      radio, [ID shortValue]);
}


void printCurrentAndLast(OSW osw)
{
    printf("2nd: %0.4hX %s %0.4hX       ", osw.command,
           osw.group ? "G" : "I",
           osw.ID);
    printf("1st: %0.4hX %s %0.4hX\n", lastOSW.command,
           lastOSW.group ? "G" : "I", lastOSW.ID);


}


