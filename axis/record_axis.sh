#!/bin/bash

record_axis_help() {
  echo "$0 [OPTION]"
  echo "  I/O"
  echo "    --in: remote location of axis camera"
  echo "    --out: prefix for output video file"
  echo "    --split-time: split video for each time (default: 86400 [sec])"
  echo "    --max-file: Maximum number of files to keep on disk. Once the maximum is reached,old files start to be deleted to make room for new ones (default: 0)"
  echo "  Auth"
  echo "    --id: authentication user id"
  echo "    --pass: authentication user password"
  echo "  Quality"
  echo "    --width: video width (default 640)"
  echo "    --height: video height (default 480)"
  echo "    --rate: video rate (defualt: 2)"
  echo "    --quality: quality for encoding to h264 (default: 21)"
  echo "  Other"
  echo "    --dry-run: echo command instead of execute"
}

check_package() {
  local pkg=$1
  dpkg -s $pkg &>/dev/null
  if [ $? -ne 0 ]; then
    echo "$pkg is not yet installed."
    return 1
  fi
  return 0
}

record_axis() {
  SOUP_OPTION="is-live=true"
  ADDRESS="localhost"
  WIDTH="640"
  HEIGHT="480"
  RATE="2"
  QUALITY="21"
  OUT="out"
  CMD="exec"
  SPLIT_TIME="0"
  MAX_FILE="0"
  #
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --in|-i)
        ADDRESS=$2
        shift
        ;;
      --out|-o)
        OUT=$(readlink -f $2)
        shift
        ;;
      --max-file)
        MAX_FILE=$2
        shift
        ;;
      --split-time)
        SPLIT_TIME=$2
        shift
        ;;
      --id)
        SOUP_OPTION="$SOUP_OPTION user-id=$2"
        shift
        ;;
      --pass)
        SOUP_OPTION="$SOUP_OPTION user-pw=$2"
        shift
        ;;
      --width)
        width=$2
        shift
        ;;
      --height)
        HEIGHT=$2
        shift
        ;;
      --rate|-r)
        RATE=$2
        shift
        ;;
      --quality|-q)
        QUALITY=$2
        shift
        ;;
      --dry-run|-n)
        CMD="echo"
        shift
        ;;
      --help|-h)
        record_axis_help
        return 1
        ;;
      *)
        shift
        ;;
    esac
  done
  #
  local location="http://$ADDRESS/axis-cgi/mjpg/video.cgi?resolution=$WIDTHx$HEIGHT"
  local max_size_time=$(($SPLIT_TIME * 1000 * 1000 * 1000))
  #
  echo "input: $location"
  echo "output: $OUT"
  echo "max_size_time: $max_size_time"
  echo "max_file: $MAX_FILE"
  $CMD gst-launch-1.0 -v\
       souphttpsrc location=${location} ${SOUP_OPTION} do-timestamp=true !\
       image/jpeg,width=$WIDTH,height=$HEIGHT,framerate=\(fraction\)${RATE}/1 !\
       jpegdec !\
       videorate !\
       videoscale !\
       video/x-raw,width=$WIDTH,height=$HEIGHT,framerate=\(fraction\)${RATE}/1 !\
       videoconvert !\
       queue !\
       clockoverlay !\
       x264enc pass=quant quantizer=$QUALITY tune=zerolatency !\
       h264parse !\
       splitmuxsink location="${OUT}_%05d.avi" max-size-time=${max_size_time} max-files=${MAX_FILE} muxer=avimux
}

if  check_package gstreamer1.0-tools &&
    check_package gstreamer1.0-plugins-good &&
    check_package gstreamer1.0-plugins-base &&
    check_package gstreamer1.0-plugins-ugly &&
    check_package gstreamer1.0-plugins-bad; then
  record_axis $@
fi
