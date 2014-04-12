Trunker
=======

The beginnings of a Mac program to decode the Motorola trunking signal. It's
a translation of the code cited in an old Usenet post from 1997. See
the mottrunk.txt file for more info.

The current command-line tool is designed to work with RTLSDR and cheap radio
dongles that are based on the RTL2832U.

Example usage with ```rtl_fm```:

```
rtl_fm -s 170k -o 4 -r 48k -l 0 -f 859.8886M - | ./Trunker -
```


Sample output:

```
Call on channel: 0115 radio: 6005 --> talkgroup: A290
Frequency: 857.937500, Talkgroup: 41616 (A290)
2nd: 03BF I 42C0       1st: 0115 G A290
2nd: 03BF G 30A8       1st: 03BF I 42C0
2nd: 03C0 G 52C0       1st: 03BF G 30A8
2nd: 03BF G 6005       1st: 03C0 G 52C0
2nd: 03C0 G 30A8       1st: 03BF G 30A8
2nd: 03BF G 6005       1st: 03C0 G 30A8
2nd: 03C0 G 52C0       1st: 03BF G 30A8
2nd: 03C0 G 30A8       1st: 03C0 G 52C0
2nd: 03BF G 6005       1st: 03C0 G 30A8
2nd: 03BF I 42C0       1st: 03BF G 6005
Call on channel: 0115 radio: 42C0 --> talkgroup: A290
Frequency: 857.937500, Talkgroup: 41616 (A290)
Call on channel: 0136 radio: A290 --> talkgroup: B570
Frequency: 858.762500, Talkgroup: 46448 (B570)
2nd: 03C0 G 52C0       1st: 0136 G B570
2nd: 03C0 G 30A8       1st: 03C0 G 52C0
2nd: 03BF G 6005       1st: 03C0 G 30A8
```

Many of the commands remain undecoded.