source ./chat.sh
source ./style.sh

tool_unload
style_resume

cd "$session"
git restore .

exit