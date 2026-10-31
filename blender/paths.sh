# bash から：. "$(dirname "$0")/paths.sh" で REPO KF RULES TRIPO ASSETS PLAN WORK BUILD GODOT が決まる（中身は paths.py と同じ）
_PD=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
eval "$(python3 "$_PD/paths.py")"
