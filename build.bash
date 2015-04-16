#!/bin/bash
PATH=`npm bin`:$PATH
jade -Pp index.jade < index.jade |./insanify.ls > index.html
#jade -Pp index.jade < test.jade |./insanify.ls > test.html
