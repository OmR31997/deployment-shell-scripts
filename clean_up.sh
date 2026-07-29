#!/bin/bash
clean_up(){
        pm2 flush || true
        rm -rf "$HOME/.pm2/logs"/* 2>/dev/null || true
        npm cache clean --force || true
        find . -maxdepth 1 -type f \( -name "*.log" -o -name "*.tmp" -o -name "*.temp" \) -delete 2>/dev/null || true
}

clean_up