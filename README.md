# dscord
dscord is a Discord client library written in D-lang thats focused on performance at high user and guild counts.

## Compiling
To compile dscord, you need any modern D-lang compiler (I recommend the latest stable version of dmd).

## Building Documentation

Building docs currently is a derp fest, due to some weird dependency issues. To do it:

1. Install scod from [here](https://github.com/b1naryth1ef/scod)
2. Manually pin the version in dub to wherever you cloned scod e.g. `{"version": "~master", "path": "../scod"}`
3. Run `dub build -b ddox` and profit.
