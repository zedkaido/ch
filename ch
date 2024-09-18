#!/bin/sh

# ch (Clipboard History)
# The trully suckless clipboard manager!
#
# `$0`: Choose option interactivelly
# `$0 copy`: Copy an entry from ch
# `$0 append`: Append current clipboard value to history
# `$0 delete`: Delete an entry from ch 
# `$0 rmlast` Remove last entry from ch  
# `$0 edit`: Edit ch manually
# `$0 select`: Select an entry from ch
# `$0 clear`: Delete all ch 

CH_HISTORY_FILE="$HOME/.local/share/ch_history"
OS=$(uname -s)

ch_copy() {
	selection=$(ch_select)
	case "$OS" in 
		Linux) echo "$selection" | xclip -selection clipboard ;;
		Darwin) echo "$selection" | pbcopy ;;
		*) echo "Unsupported OS. Are you running on a potato?" ;;
	esac
}

ch_append() {
	clipboard_content=""
	case "$OS" in
		Linux) clipboard_content=$(xclip -selection clipboard -o) ;;
		Darwin) clipboard_content=$(pbpaste) ;;
		*) echo "Unsupported OS. Are you running on a potato?" ;;
	esac
	printf "\n-#-#-#-\n%s\n-#-#-#-\n" "$clipboard_content" >> ~/.local/share/ch_history
}

ch_delete() {
	selection=$(ch_select)
	safe_selection=$(printf '%q\n' "$selection")
	line=$(grep --line-number --text "$selection" "$CH_HISTORY_FILE" | fzf --reverse | cut -d: -f1)
	if [ -n "$line" ]; then
		line_number=$(echo "$line" | cut -d: -f1)
		if [ -n "$line_number" ]; then
			block_start=$(sed -n "1,${line_number}p" "$CH_HISTORY_FILE" | grep -n "^-#-#-#-" | tail -n 1 | cut -d: -f1)
			block_end=$(sed -n "$((block_start + 1)),\$p" "$CH_HISTORY_FILE" | grep -n "^-#-#-#-" | head -n 1 | cut -d: -f1)

			if [ -n "$block_end" ]; then
				block_end=$((block_start + block_end))
			else
				block_end=$(wc -l < "$CH_HISTORY_FILE")
			fi
			case "$OS" in
				Linux) sed -i "$((block_start - 1)),${block_end}d" "${CH_HISTORY_FILE}" ;;
				Darwin) sed -i '' "$((block_start - 1)),${block_end}d" "${CH_HISTORY_FILE}" ;;
				*) echo "Unsupported OS. Are you running on a potato?" ;;
			esac
			echo "Deleted :$block_start-:$block_end from $CH_HISTORY_FILE"
		else
			echo "Nothing selected :("
		fi
	fi
}

ch_rmlast() {
	block_start=$(grep -n "^-#-#-#-" "$CH_HISTORY_FILE" | tail -n 2 | head -n 1 | cut -d: -f1)
	if [ -n "$block_start" ]; then
		block_end=$(wc -l < "$CH_HISTORY_FILE") 
		case "$OS" in
			Linux) sed -i "$((block_start - 1)),$block_end d" "$CH_HISTORY_FILE" ;;
			Darwin) sed -i '' "$((block_start - 1)),$block_end d" "$CH_HISTORY_FILE" ;;
			*) echo "Unsupported OS. Are you running on a potato?" ;;
		esac
	else
		echo "Clipboard history is empty. Nothing to remove" 
	fi
}

ch_edit() {
	nvim $CH_HISTORY_FILE
}

ch_clear() {
	echo "" > $CH_HISTORY_FILE
}

ch_select() {
	ch_selection=$(awk '
		/^-#-#-#-$/ {
			if (content) {
				gsub(/^\s+|\s+$/, "", content);
				gsub(/\n/, "\\n", content);
				print content;
				content = "";
			}
			next;
		} { content = content (content ? "\\n" : "") $0 }
		' "$CH_HISTORY_FILE" | fzf --reverse --tac --preview 'echo -e "{}"'
	)
	# selection=$(echo "$ch_selection" | sed 's/\\n/\n/g')
	echo "$ch_selection"
}

ch_help() {
	echo "Visit $CH_HISTORY_FILE for help"
}

ch_choose() {
	choice=$(printf "copy\\nappend\\ndelete\\nrmlast\\nedit\\nclear\\nselect\\nhelp" | fzf)
	case "$choice" in
		copy) ch_copy ;;
		append) ch_append ;;
		delete) ch_delete ;;
		rmlast) ch_rmlast ;;
		edit) ch_edit ;;
		clear) ch_clear ;;
		select) ch_select ;;
		help) ch_help ;;
		*) echo "Usage: $0 {copy|append|delete|rmlast|clear|...}" ;;
	esac
}

case "$1" in
	copy) ch_copy ;;
	append) ch_append ;;
	delete) ch_delete ;;
	rmlast) ch_rmlast ;;
	edit) ch_edit ;;
	clear) ch_clear ;;
	select) ch_select ;;
	help) ch_help ;;
	*) ch_choose ;; 
esac
