#!/bin/bash
JEKYLL_ENV=production bundle exec jekyll build \
    && find _site \
        -name '*.html' \
        -not -name 'index.html' \
        -not -name '404.html' \
        -exec sh -c 'mv $1 ${1%.*}' sh {} \;
