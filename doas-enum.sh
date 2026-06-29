#!/bin/sh
# doas-enum - tests full path and command name
# Author: Sublarge
# GitHub: https://github.com/yanxinwu946/doas-enum

USER=""
DOAS=$(command -v doas 2>/dev/null || echo "")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    printf "${BLUE}"
    cat << "EOF"
 ____        _     _                      
/ ___| _   _| |__ | | __ _ _ __ __ _  ___ 
\___ \| | | | '_ \| |/ _` | '__/ _` |/ _ \
 ___) | |_| | |_) | | (_| | | | (_| |  __/
|____/ \__,_|_.__/|_|\__,_|_|  \__, |\___|
                               |___/       
EOF
    printf "${NC}\n"
    printf "doas-enum - enumerate doas permissions\n"
    printf "Author: Sublarge\n"
    printf "GitHub: https://github.com/yanxinwu946/doas-enum\n\n"
    printf "Usage: %s [-u user] [-h]\n" "$0"
    printf "  -u user     Target user\n"
    printf "  -h          Show this help\n"
    exit 1
}

while getopts "u:h" opt; do
    case "$opt" in
        u) USER="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

[ -z "$DOAS" ] && printf "${RED}doas not found${NC}\n" >&2 && exit 1

printf "${BLUE}=== DOAS ENUM ===${NC}\n"
[ -n "$USER" ] && printf "${BLUE}Target user:${NC} %s\n" "$USER"
printf "\n"

printf "${BLUE}[*] binary${NC}\n"
ls -l "$DOAS" 2>/dev/null
printf "\n"

printf "${BLUE}[*] configs${NC}\n"
for f in /etc/doas.conf /usr/local/etc/doas.conf; do
    [ -f "$f" ] || continue
    printf "${GREEN}[+]${NC} %s\n" "$f"
    cat "$f" 2>/dev/null || printf "unreadable\n"
done

if [ -d /etc/doas.d ]; then
    for f in /etc/doas.d/*.conf; do
        [ -f "$f" ] || continue
        printf "${GREEN}[+]${NC} %s\n" "$f"
        cat "$f" 2>/dev/null || printf "unreadable\n"
    done
fi
printf "\n"

DOAS_CMD="$DOAS"
[ -n "$USER" ] && DOAS_CMD="$DOAS_CMD -u $USER"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR; stty echo 2>/dev/null" EXIT

cmds=""
for p in $(echo "$PATH" | tr ':' ' '); do
    [ -d "$p" ] || continue
    for c in "$p"/*; do
        [ -x "$c" ] && cmds="$cmds $c"
    done
done

total=$(echo "$cmds" | wc -w)
printf "${BLUE}[*] probing${NC} %d commands...\n" "$total"

for c in $cmds; do
    id=$(echo "$c" | cksum | cut -d' ' -f1)
    printf "%s\n" "$c" > "$TMPDIR/cmd_$id"
    basename "$c" > "$TMPDIR/name_$id"
done

for c in $cmds; do
    id=$(echo "$c" | cksum | cut -d' ' -f1)
    name=$(basename "$c")
    
    {
        exec </dev/null >/dev/null 2>&1
        $DOAS_CMD "$c" --help
        printf "%d\n" $? > "$TMPDIR/exit_full_$id"
    } &
    printf "%d\n" $! > "$TMPDIR/pid_full_$id"
    
    {
        exec </dev/null >/dev/null 2>&1
        $DOAS_CMD "$name" --help
        printf "%d\n" $? > "$TMPDIR/exit_name_$id"
    } &
    printf "%d\n" $! > "$TMPDIR/pid_name_$id"
done

printf "${BLUE}[*] waiting...${NC}\n"
sleep 1

nopass_full=""
pass_full=""
nopass_name=""
pass_name=""
cnt=0

for pidf in "$TMPDIR"/pid_full_*; do
    [ -f "$pidf" ] || continue
    cnt=$((cnt + 1))
    printf "\r${BLUE}[%d/%d]${NC}" "$cnt" "$total"
    
    id=$(basename "$pidf" | sed 's/pid_full_//')
    pid=$(cat "$pidf" 2>/dev/null)
    cmd=$(cat "$TMPDIR/cmd_$id" 2>/dev/null)
    name=$(cat "$TMPDIR/name_$id" 2>/dev/null)
    [ -z "$cmd" ] && continue
    
    if kill -0 $pid 2>/dev/null; then
        kill $pid 2>/dev/null
        pass_full="$pass_full $cmd"
    else
        exitcode=$(cat "$TMPDIR/exit_full_$id" 2>/dev/null || printf "1")
        [ "$exitcode" = "0" ] && nopass_full="$nopass_full $cmd"
    fi
    
    pid_name=$(cat "$TMPDIR/pid_name_$id" 2>/dev/null)
    if kill -0 $pid_name 2>/dev/null; then
        kill $pid_name 2>/dev/null
        pass_name="$pass_name $name"
    else
        exitcode=$(cat "$TMPDIR/exit_name_$id" 2>/dev/null || printf "1")
        [ "$exitcode" = "0" ] && nopass_name="$nopass_name $name"
    fi
done

printf "\r%-80s\n" ""
printf "\n${BLUE}=== DONE ===${NC}\n"

if [ -n "$nopass_full" ] || [ -n "$pass_full" ]; then
    printf "\n${BLUE}--- Full path ---${NC}\n"
    if [ -n "$nopass_full" ]; then
        printf "\n${GREEN}========================================${NC}\n"
        printf "${GREEN}[!] ALLOWED (no password):${NC}\n"
        printf "${GREEN}========================================${NC}\n"
        for c in $nopass_full; do
            if [ -n "$USER" ]; then
                printf "  ${GREEN}doas -u %s %s${NC}\n" "$USER" "$c"
            else
                printf "  ${GREEN}doas %s${NC}\n" "$c"
            fi
        done
    fi
    if [ -n "$pass_full" ]; then
        printf "\n${YELLOW}========================================${NC}\n"
        printf "${YELLOW}[!] ALLOWED (password required):${NC}\n"
        printf "${YELLOW}========================================${NC}\n"
        for c in $pass_full; do
            if [ -n "$USER" ]; then
                printf "  ${YELLOW}doas -u %s %s${NC}\n" "$USER" "$c"
            else
                printf "  ${YELLOW}doas %s${NC}\n" "$c"
            fi
        done
    fi
fi

if [ -n "$nopass_name" ] || [ -n "$pass_name" ]; then
    printf "\n${BLUE}--- Command name ---${NC}\n"
    if [ -n "$nopass_name" ]; then
        printf "\n${GREEN}========================================${NC}\n"
        printf "${GREEN}[!] ALLOWED (no password):${NC}\n"
        printf "${GREEN}========================================${NC}\n"
        for n in $nopass_name; do
            if [ -n "$USER" ]; then
                printf "  ${GREEN}doas -u %s %s${NC}\n" "$USER" "$n"
            else
                printf "  ${GREEN}doas %s${NC}\n" "$n"
            fi
        done
    fi
    if [ -n "$pass_name" ]; then
        printf "\n${YELLOW}========================================${NC}\n"
        printf "${YELLOW}[!] ALLOWED (password required):${NC}\n"
        printf "${YELLOW}========================================${NC}\n"
        for n in $pass_name; do
            if [ -n "$USER" ]; then
                printf "  ${YELLOW}doas -u %s %s${NC}\n" "$USER" "$n"
            else
                printf "  ${YELLOW}doas %s${NC}\n" "$n"
            fi
        done
    fi
fi

[ -z "$nopass_full" ] && [ -z "$pass_full" ] && [ -z "$nopass_name" ] && [ -z "$pass_name" ] && printf "${RED}No commands allowed${NC}\n"

stty echo 2>/dev/null