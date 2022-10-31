# Mufi-Lang Template

The Mufi-Lang template contains the core compiler of the toy language, Mufi. The Makefile contains two different ways to create the project, and this differs in how `compiler/common.h` is configured. 

A simple pdf guide of the language can be downloaded [here](https://github.com/MKProj/Mufi-Lang/releases/download/guide-0.1.0/mufi_guide.pdf) or the other guide releases can be seen [here](https://github.com/MKProj/Mufi-Lang/releases/tag/guide-0.1.0). 

To normally build the project use `make build`, however it is recommended to initially run one of the mode specific build options. 


To run the program in its normal or `release` mode, you will need to use the following commands: 
```
$ make release 
$ ./mufi 
Version 0.1.0 (Baloo Release)
(mufi) >> var a = 10; print a;
10
```

To looked at the debugged mode where you will see the different bytecode commands, and garbage collector tracing, you will need to create the program in `debug` mode or using the following commands: 

```
$ make debug 
$ ./mufi 
-- gc begin
-- gc end
   collected 0 bytes (from 5 to 5) next at 10
-- gc begin
-- gc end
   collected 0 bytes (from 45 to 45) next at 90
0x563f3d8a96d0 allocate 40 for 4
-- gc begin
0x563f3d8a96d0 mark init
0x563f3d8a96d0 blacken init
-- gc end
   collected 0 bytes (from 237 to 237) next at 474
Version 0.1.0 (Baloo Release)

(mufi) >> var a = 10; print a; 
-- gc begin
0x563f3d8a96d0 mark init
0x563f3d8a96d0 blacken init
-- gc end
   collected 0 bytes (from 309 to 309) next at 618
0x563f3d8a9c30 allocate 72 for 1
-- gc begin
0x563f3d8a9c30 mark <script>
0x563f3d8a96d0 mark init
0x563f3d8a96d0 blacken init
0x563f3d8a9c30 blacken <script>
-- gc end
   collected 0 bytes (from 311 to 311) next at 622
-- gc begin
0x563f3d8a9c30 mark <script>
0x563f3d8a96d0 mark init
0x563f3d8a96d0 blacken init
0x563f3d8a9c30 blacken <script>
-- gc end
   collected 0 bytes (from 351 to 351) next at 702
0x563f3d8a9ca0 allocate 40 for 4
-- gc begin
0x563f3d8a9ca0 mark a
0x563f3d8a9c30 mark <script>
0x563f3d8a96d0 mark init
0x563f3d8a96d0 blacken init
0x563f3d8a9c30 blacken <script>
0x563f3d8a9ca0 blacken a
-- gc end
   collected 0 bytes (from 479 to 479) next at 958
-- gc begin
0x563f3d8a9c30 mark <script>
0x563f3d8a96d0 mark init
0x563f3d8a96d0 blacken init
0x563f3d8a9c30 blacken <script>
0x563f3d8a9ca0 mark a
0x563f3d8a9ca0 blacken a
-- gc end
   collected 0 bytes (from 487 to 487) next at 974
-- gc begin
0x563f3d8a9c30 mark <script>
0x563f3d8a96d0 mark init
0x563f3d8a96d0 blacken init
0x563f3d8a9c30 blacken <script>
0x563f3d8a9ca0 mark a
0x563f3d8a9ca0 blacken a
-- gc end
   collected 0 bytes (from 519 to 519) next at 1038
-- gc begin
0x563f3d8a9c30 mark <script>
0x563f3d8a96d0 mark init
0x563f3d8a96d0 blacken init
0x563f3d8a9c30 blacken <script>
0x563f3d8a9ca0 mark a
0x563f3d8a9ca0 blacken a
-- gc end
   collected 0 bytes (from 527 to 527) next at 1054
-- gc begin
0x563f3d8a9c30 mark <script>
0x563f3d8a96d0 mark init
0x563f3d8a96d0 blacken init
0x563f3d8a9c30 blacken <script>
0x563f3d8a9ca0 mark a
0x563f3d8a9ca0 blacken a
-- gc end
   collected 0 bytes (from 559 to 559) next at 1118
== <script> ==
0000    1 OP_CONSTANT         1 '10'
0002    | OP_DEFINE_GLOBAL    0 'a'
0004    | OP_GET_GLOBAL       2 'a'
0006    | OP_PRINT
0007    2 OP_NIL
0008    | OP_RETURN
-- gc begin
0x563f3d8a9c30 mark <script>
0x563f3d8a96d0 mark init
0x563f3d8a96d0 blacken init
0x563f3d8a9c30 blacken <script>
0x563f3d8a9ca0 mark a
0x563f3d8a9ca0 blacken a
-- gc end
   collected 0 bytes (from 599 to 599) next at 1198
0x563f3d8a9dd0 allocate 40 for 0
         [ <script> ]
0000    1 OP_CONSTANT         1 '10'
-- gc begin
0x563f3d8a9dd0 mark <script>
0x563f3d8a96d0 mark init
0x563f3d8a96d0 blacken init
0x563f3d8a9dd0 blacken <script>
0x563f3d8a9c30 mark <script>
0x563f3d8a9c30 blacken <script>
0x563f3d8a9ca0 mark a
0x563f3d8a9ca0 blacken a
-- gc end
   collected 0 bytes (from 791 to 791) next at 1582
10

```
