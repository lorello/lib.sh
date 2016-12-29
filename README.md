# lib.sh

Bash Library for common utilities, homogeneous logging, alerting on Slack

## Setup

    mkdir /usr/local/lib/bash
    wget -O /usr/local/lib/bash/lib.sh https://raw.githubusercontent.com/lorello/lib.sh/master/lib.sh

You can also install using the [Bash Package Manager (BPKG)](http://www.bpkg.io/) using:

    bpkg install lorello/lib.sh

## Usage

    #!/usr/bin/env bash

    . $(dirname $(readlink -f $0))/../lib/bash/lib.sh || exit 99


## Credits

The library was created by the Operations team at [Softec SpA](http://www.softecspa.com). 
Many system administrators contributed to it with ideas and code, 
but all of them are too lazy to convert the old SVN repository to
mantain the git history :)

