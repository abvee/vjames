Just a generic top down shooter game :D

# Building
Download the linux raylib tarball from
[here](https://github.com/raysan5/raylib/releases/download/5.5/raylib-5.5_linux_amd64.tar.gz).

Extract the tarball to the root of the project:
```
tar xvf raylib-5.5_linux_amd64.tar.gz -C <project root>
```
After that, just run `zig build` from the project root
to build both the server and the actual game.

# The large number of glaring issues
* Only builds on linux. This is because I'm on linux and all the networking code
is POSIX and linux specific. I'll add other OS support if my friends are
interested in playing the game.
* Everything is statically linked, and you **have** to download the raylib
tarball. I plan to remedy that by adding dynamic linking support in the future.
