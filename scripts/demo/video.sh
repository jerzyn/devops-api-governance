#!/bin/bash
# Post-production helpers for the demo recordings (ffmpeg).
#
#   video.sh cards <dir>                      title cards card1.mp4 .. card5.mp4 (3 s each):
#                                             stage name, what it adds, the pipeline so far
#   video.sh trim <in> <from> <to> <out>      keep only <from>..<to> (e.g. 00:01:05 or 65.5)
#   video.sh speed <in> <factor> <out>        play a clip faster, e.g. 4 for CI waiting
#   video.sh concat <out> <in1> <in2> ...     join clips (cards + recordings), normalised
#                                             to 1920x1080 @ 30 fps
set -euo pipefail

FONT_BOLD=/usr/share/fonts/google-noto/NotoSans-Bold.ttf
FONT=/usr/share/fonts/google-noto/NotoSans-Regular.ttf
FONT_ARROWS=/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf   # has the → glyph
W=1920; H=1080; FPS=30
ENC=(-c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -movflags +faststart)

has_audio() { [ -n "$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$1")" ]; }

card() {  # $1 = out, $2 = title, $3 = subtitle, $4 = pipeline line
  local t; t="$(mktemp -d)"
  printf '%s' "$2" > "$t/title"; printf '%s' "$3" > "$t/sub"; printf '%s' "$4" > "$t/pipe"
  ffmpeg -v error -y -f lavfi -i "color=c=0x14171c:s=${W}x${H}:r=${FPS}:d=3" \
    -f lavfi -i "anullsrc=r=48000:cl=stereo" -t 3 \
    -vf "drawtext=fontfile=${FONT_BOLD}:textfile=$t/title:fontcolor=white:fontsize=92:x=(w-text_w)/2:y=h*0.34,\
drawtext=fontfile=${FONT}:textfile=$t/sub:fontcolor=0x9fb3c8:fontsize=48:x=(w-text_w)/2:y=h*0.34+140,\
drawtext=fontfile=${FONT_ARROWS}:textfile=$t/pipe:fontcolor=0x7ee787:fontsize=40:x=(w-text_w)/2:y=h*0.72" \
    -c:a aac -shortest "${ENC[@]}" "$1"
  rm -rf "$t"
}

case "${1:-}" in
  cards)
    d="${2:?usage: video.sh cards <dir>}"; mkdir -p "$d"
    card "$d/card1.mp4" "Stage 1: Catalog" "One catalog-info.yaml makes the API visible" "Pipeline: no gates yet"
    card "$d/card2.mp4" "Stage 2: Guidelines as code" "Spectral lints every contract change" "Pipeline: Spectral"
    card "$d/card3.mp4" "Stage 3: Contract testing" "Microcks checks the running backend" "Pipeline: Spectral → Contract test"
    card "$d/card4.mp4" "Stage 4: API gateway" "KrakenD, generated from the contract" "Pipeline: Spectral → Contract test → Gateway"
    card "$d/card5.mp4" "Stage 5: Backwards compatibility" "oasdiff blocks breaking changes" "Pipeline: Spectral → Backwards compat → Contract test → Gateway"
    ls -1 "$d"/card*.mp4 ;;
  trim)
    in="$2"; from="$3"; to="$4"; out="$5"
    ffmpeg -v error -y -ss "$from" -to "$to" -i "$in" "${ENC[@]}" -c:a aac "$out" ;;
  speed)
    in="$2"; f="$3"; out="$4"
    if has_audio "$in"; then
      # atempo takes 0.5..2 per stage: chain enough stages for larger factors.
      a=""; r="$f"
      while awk "BEGIN{exit !($r > 2)}"; do a="${a}atempo=2,"; r=$(awk "BEGIN{print $r/2}"); done
      ffmpeg -v error -y -i "$in" -filter_complex "[0:v]setpts=PTS/${f}[v];[0:a]${a}atempo=${r}[a]" \
        -map "[v]" -map "[a]" "${ENC[@]}" -c:a aac "$out"
    else
      ffmpeg -v error -y -i "$in" -vf "setpts=PTS/${f}" -an "${ENC[@]}" "$out"
    fi ;;
  concat)
    out="$2"; shift 2; [ $# -ge 2 ] || { echo "concat needs at least two inputs" >&2; exit 1; }
    audio=1; for f in "$@"; do has_audio "$f" || audio=0; done
    [ $audio = 1 ] || echo "note: not every input has audio, so the result is silent" >&2
    args=(); fc=""; n=0
    for f in "$@"; do
      args+=(-i "$f")
      fc="${fc}[${n}:v]scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x14171c,fps=${FPS},setsar=1[v${n}];"
      [ $audio = 1 ] && fc="${fc}[${n}:a]aresample=48000,aformat=channel_layouts=stereo[a${n}];"
      n=$((n + 1))
    done
    for ((i = 0; i < n; i++)); do fc="${fc}[v${i}]"; [ $audio = 1 ] && fc="${fc}[a${i}]"; done
    if [ $audio = 1 ]; then
      fc="${fc}concat=n=${n}:v=1:a=1[v][a]"; maps=(-map "[v]" -map "[a]" -c:a aac)
    else
      fc="${fc}concat=n=${n}:v=1:a=0[v]"; maps=(-map "[v]")
    fi
    ffmpeg -v error -y "${args[@]}" -filter_complex "$fc" "${maps[@]}" "${ENC[@]}" "$out" ;;
  *) sed -n '2,11p' "$0"; exit 1 ;;
esac
