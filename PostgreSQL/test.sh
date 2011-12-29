#!/bin/sh

text="test.sh";
test=`stat -f %Su $text`;
echo "$test";
