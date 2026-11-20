"""証言 一〜三の部屋の音（2026-11-20、インタビューを作り直すスレッド）。届いている素材（/mnt/project-files/ の直下、入手先とライセンスは
docs/素材とアドオン.md）から切る。  python3 godot/sound/cut_interview.py   （ffmpeg）
切る場所は Claude が選んだ（耳での良し悪しはユーザー）。
  iv_room.ogg   昼の客間の空気（輪。stevebfx room-tone-1 の 20〜50 秒を、つなぎ目が切れないように頭と尾を重ねた）
  iv_leaves.ogg 障子の外で葉が鳴る（輪。tree-wind-creaking の 4〜34 秒、低い軋みを削って細く）
  iv_tv_on.wav  ブラウン管が点く高い鳴り（tv-chillido の頭 1.6 秒）
鉛筆（c7_pencil）、テープを入れる音（cassette_in・tape_clunk）は前からある物を使う。
"""
import os, subprocess
M = "/mnt/project-files/"
OUT = os.path.dirname(os.path.abspath(__file__)) + "/"
def ff(*a): subprocess.run(["ffmpeg", "-v", "error", "-y", *a], check=True)
def loop(src, a, n, out, af=""):
    # a crossfaded loop: the tail is laid over the head so the seam does not click
    x = 2.0
    filt = (f"[0:a]atrim={a}:{a + n + x},asetpts=PTS-STARTPTS,aformat=sample_rates=44100:channel_layouts=mono{af}[s];"
            f"[s]asplit[p][q];[p]atrim=0:{n},asetpts=PTS-STARTPTS[body];[q]atrim={n}:{n + x},asetpts=PTS-STARTPTS[tail];"
            f"[body]asplit[b1][b2];[b1]atrim=0:{x},asetpts=PTS-STARTPTS[head];[b2]atrim={x}:{n},asetpts=PTS-STARTPTS[rest];"
            f"[tail][head]acrossfade=d={x}:c1=tri:c2=tri[seam];[seam][rest]concat=n=2:v=0:a=1[o]")
    ff("-i", M + src, "-filter_complex", filt, "-map", "[o]", "-c:a", "libvorbis", "-q:a", "4", OUT + out)
loop("stevebfx-room-tone-1-579801.mp3", 20.0, 30.0, "iv_room.ogg")
loop("freesound_community-tree-wind-creaking-26618.mp3", 4.0, 30.0, "iv_leaves.ogg", ",highpass=f=900,lowpass=f=7000,volume=0.7")
ff("-i", M + "freesound_community-tv-chillido-66997.mp3", "-t", "1.6", "-af", "afade=t=in:d=0.02,afade=t=out:st=1.2:d=0.4", "-ac", "1", OUT + "iv_tv_on.wav")
print("ok")
