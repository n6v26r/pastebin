    function paste() {
      local file=/dev/stdin secure=0 ext=

      for arg in "$@"; do
        case "$arg" in
          -s) secure=1 ;;
          -e=*|-ext=*) ext=${arg#*=} ;;
          *) file=$arg ;;
        esac
      done

      if [ "$file" != /dev/stdin ] && [ -z "$ext" ]; then
        ext=${file##*.}; [ "$ext" = "$file" ] && ext=
      fi

      local url="{{URL}}/?"
      [ $secure -eq 1 ] && url+="s=&"
      [ -n "$ext" ] && url+="ext=$ext&"
      url=${url%&}

      curl --data-binary @"$file" "$url"; echo
    }
