#! /usr/bin/env fish

zola build
rm -rf public/js
rm -rf (string match -rv '^../src$' -- ../*)
cp -r public/* ../
