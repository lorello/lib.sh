# lib.sh

Bash Library for common utilities, homogeneous logging, alerting on Slack

## Setup

    mkdir /usr/local/lib/bash
    wget -O /usr/local/lib/bash/lib.sh https://raw.githubusercontent.com/lorello/lib.sh/master/lib.sh

## Usage

    #!/usr/bin/env bash

    . $(dirname $(readlink -f $0))/../lib/bash/lib.sh || exit 99


## Credits

The library has been written by the Operations team at Softec SpA. 
Many system administrators contributed to it with ideas and code, 
but all of them are too lazy to convert the old SVN repository to
mantain the git history :)

So, in order of appearence:

* Lorenzo Salvadorini
* Filippo Cenobi (for the windows porting)
* Michela Tigli
* Alessandro Sagratini
* Matteo Capaccioli
* Francesco Bovicelli
* Paolo Larcheri
* Lorenzo Cocchi
* Felice Pizzurro


