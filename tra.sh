#!/bin/sh
# Copyright © 2025 hiruocha

# This program is free software: you can redistribute it and/or modify it under the 
# terms of the GNU General Public License as published by the Free Software 
# Foundation, either version 3 of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT ANY 
# WARRANTY; without even the implied warranty of MERCHANTABILITY or 
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for 
# more details.

# You should have received a copy of the GNU General Public License along with this 
# program. If not, see <https://www.gnu.org/licenses/>. 

set -e

uid=$(id -ru)
home_trash=${XDG_DATA_HOME:-$HOME/.local/share}/Trash
home_topdir=$(df -P "$home_trash" | awk 'NR==2 {print $NF}')

cmd="${1:-help}"
[ -n "$1" ] && shift 1

# https://github.com/ko1nksm/url
urldecode() {
  LC_ALL=C awk -v space="$SHURL_SPACE" -v eol="$SHURL_EOL" '
    function decode(map, str,   ret) {
      while (match(str, /%[0-9A-Fa-f][0-9A-Fa-f]/)) {
        ret = ret substr(str, 1, RSTART - 1) url[substr(str, RSTART + 1, 2)]
        str = substr(str, RSTART + RLENGTH)
      }
      return ret str
    }

    BEGIN {
      for (i = 0; i < 256; i++) url[sprintf("%02x", i)] = sprintf("%c", i)

      # Increase to 4 patterns to improve performance
      for (k in url) {
        m = substr(k, 1, 1); M = toupper(m)
        l = substr(k, 2, 1); L = toupper(l)
        url[m L] = url[M l] = url[M L] = url[k]
      }
    }

    BEGIN {
      for (i = 1; i < ARGC; i++) {
        if (length(space) > 0) gsub(space, " ", ARGV[i])
        print decode(url, ARGV[i])
      }
      if (ARGC > 1) exit
    }

    {
      if (length(space) > 0) gsub(/\+/, " ", $0)
      print decode(url, $0)
    }
  ' "$@"
}

get_trash() {
  if [ "$topdir" = "$home_topdir" ]
  then
    trash="$home_trash"
  elif
    [ -d "$topdir/.Trash" ] &&
    [ ! -L "$topdir/.Trash" ] &&
    [ -n "$(find "$topdir/.Trash" -prune -type d -perm -1000)" ]
  then
    trash="$topdir"/.Trash/"$uid"
  else
    trash="$topdir"/.Trash-"$uid"
  fi
}

cmd_ls() {
  {
    df -P | tail -n +2 | while read -r fs; do
      case "$fs" in
        /dev/*)
          topdir=$(printf '%s' "$fs" | awk '{print $NF}')
          get_trash
          [ -d "$trash" ] || return 0
          for trashinfo in "$trash"/info/*.trashinfo
          do
            [ -e "$trashinfo" ] || continue
            path=$(urldecode "$(awk -F '=' '/^Path=/ {print $2; exit}' "$trashinfo")")
            printf '%s' "$path"
            filename=${trashinfo##*/}
            filename=${filename%.trashinfo}
            if
              [ ! -e "$trash"/files/"$filename" ]
            then
              printf ' [MISSING]\n'
            elif
              [ -d "$trash"/files/"$filename" ]
            then
              printf ' (dir)\n'
            else
              printf '\n'
            fi
          done
          ;;
        *)
          ;;
      esac
    done
  } | sort
}

cmd_"$cmd" "$@"
