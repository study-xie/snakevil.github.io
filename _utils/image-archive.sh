#!/bin/sh

[ -d '_assets' -a -d '_posts' ] || {
  echo 'Sub modules are out of control.'
  exit 1
}

[ -f '_assets/i/watermark.png' ] || {
  echo 'Watermark is missing.'
  exit 2
}

'rm' -f _assets/tmp.png > /dev/null 2>&1

'ls' _assets/*.png _assets/*.jpg _assets/*.svg 2> /dev/null | \
  while read file; do
    name=`'basename' "$file"`
    echo "processing \`$name':"
    printf '%-31s' "  checking references..."
    phrase="]({{ site.asset.url }}/$name"
    refcnt=`'grep' -F "$phrase" _posts/20??-??-??-*.md | 'wc' -l`
    echo $refcnt
    [ 0 -ne $refcnt ] || {
      echo ' IGNORED for non-reference.'
      continue
    }
    printf '%-31s' "  watermarking..."
    ext=`echo "$name" | 'awk' -F'.' '{print $NF}'`
    realname="$name"
    [ 'png' = $ext ] || {
      realname="$('basename' "$name" ".$ext").png"
      ext='png'
    }
    tempfile="_assets/tmp.$ext"
    'composite' -dissolve 38% -gravity center -quality 100 \
      _assets/i/watermark.png "$file" $tempfile > /dev/null 2>&1
    [ 0 -eq $? ] && echo 'succeed' || {
      echo 'failed'
      echo ' SKIPPED for failure of watermarking.'
      continue
    }
    printf '%-31s' "  optimizing..."
    ratio=`'pngcrush' -oldtimestamp -ow $tempfile 2>&1 >/dev/null | \
      'grep' 'critical chunk reduction' | \
      'awk' '{print substr($1, 2)}'`
    [ 0 -eq $? ] && echo $ratio || {
      echo 'failed'
      echo ' SKIPPED for failure of optimization.'
      continue
    }
    printf '%-31s' "  hashing storage folder..."
    dir="i$('sha1sum' "$tempfile" | 'cut' -c1)"
    echo $dir
    [ -d "_assets/$dir" ] || {
      'mkdir' "_assets/$dir" > /dev/null 2>&1
      [ 0 -eq $? ] || {
        echo ' SKIPPED for failure of folder creation.'
        continue
      }
    }
    printf '%-31s' "  updating references..."
    'grep' -FRl "$phrase" _posts/20??-??-??-*.md | \
      while read file; do
        [ -f "$file.bak" ] || 'cp' -a "$file" "$file.bak"
        'sed' -i -e \
          "s/]({{ site.asset.url }}\/$name/]({{ site.asset.url }}\/$dir\/$realname/g" \
          "$file" > /dev/null 2>&1
        [ 0 -eq $? ] || exit 86
      done
    [ 0 -eq $? ] && echo 'succeed' || {
      echo 'failed'
      echo ' SKIPPED for failure of auto posts modification.'
      continue
    }
    printf '%-31s' "  archiving..."
    'mv' "$tempfile" "_assets/$dir/$realname" && \
      'mv' "$file" "$file.bak"
    [ 0 -eq $? ] && echo 'succeed' || {
      echo 'failed'
      echo ' SKIPPED for failure of archiving.'
      continue
    }
    echo ' DONE'
  done