#!/bin/bash

echo $PWD > testfile1.txt
echo $USER > testfile2.txt # this prints ubuntu
echo "Creating test file!"
echo "Hello" > testfile.txt

echo "Creating test file 4!"
cd /root
echo "Hello" > testfile4.txt

# should install required VM tools here

# TODO: test out root user swap, for installing various tools