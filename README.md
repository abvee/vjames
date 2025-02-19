Just a generic top down shooter game :D

# Building
Currently, the game runs ONLY on Linux and MacOS.

First, clone this repository:
```bash
git clone https://github.com/abvee/vjames
cd ./vjames
```
Download the Linux / MacOS Raylib tarball based on your operating system.

For Linux:
```bash
wget https://github.com/raysan5/raylib/releases/download/5.5/raylib-5.5_linux_amd64.tar.gz
```
For MacOS:
```bash
wget https://github.com/raysan5/raylib/releases/download/5.5/raylib-5.5_macos.tar.gz
```
Manual Downloads:
* [Linux tarball](https://github.com/raysan5/raylib/releases/download/5.5/raylib-5.5_linux_amd64.tar.gz).
* [MacOS tarball](https://github.com/raysan5/raylib/releases/download/5.5/raylib-5.5_macos.tar.gz).

Extract the tarball to the root of the project:
```bash
tar xvf raylib-5.5_linux_amd64.tar.gz
```
After that, just run `zig build` from the project root
to build both the server and the actual game.
# Running
You can directly run the binaries after running `zig build`. You would first
need to run the server binary:
```bash
./zig-out/bin/skrr-server
```
Then run the game:
```bash
./zig-out/bin/skrr
```
You can optionally specify a port for the server to bind to:
```bash
./zig-out/bin/skrr-server -p 8080
```
The client accepts an ip and port in the `<ip>:<port>` format as a commandline
argument:
```bash
./zig-out/bin/skrr 127.0.0.1:12271
```
The default port for both the client and the server is 12271. The client uses
localhost if no ip is specified.

# The large number of glaring issues
* Only builds on linux. This is because I'm on linux and all the networking code
is POSIX and linux specific. I'll add other OS support if my friends are
interested in playing the game.
* Everything is statically linked, and you **have** to download the raylib
tarball. I plan to remedy that by adding dynamic linking support in the future.
