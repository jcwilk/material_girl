#!/usr/bin/env bash

echo 'find . | entr ./compile.rb'
find . | entr ./compile.rb

