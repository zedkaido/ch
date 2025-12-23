#!/usr/bin/env bash

chhelp() {
	cat << 'EOF'
Usage: ch [commands]

Description: A ch(clipboard history) you are in control of.

Commands:
   -c, copy
   -s, save
   -d, delete, del
   -e, edit
   -clear [(clip)board|(hist)ory]
   -sel, select

Dependencies: fzf, fzy, rg
EOF
}

fzf() { command fzf --no-color "$@" ; }

OS=$(uname -s)

chfile="$HOME/.local/share/ch.txt"
if [[ ! -f "$chfile" ]]; then
	mkdir -p "$HOME/.local/share"
	touch "$HOME/.local/share/ch.txt"
fi

chsave() {
	clipboard=""
	case "$OS" in
		Linux) clipboard=$(xclip -selection clipboard -o) ;;
		Darwin) clipboard=$(pbpaste) ;;
		*) echo "Unsupported OS. Are you running on a potato?" ;;
	esac

	if [[ -n $clipboard ]]; then
		printf "||CLIP||{\n%s\n}||CLIP||\n" "$clipboard" | col -b >> "$chfile"
		exit 0
	fi
}

selCLIP() {
	perl -0777 -ne 'while (/\|\|CLIP\|\|\{\n?(.*?)\n?\}\|\|CLIP\|\|/gs) { print $1 . "\0" }' "$chfile" | \
		fzf --read0 --layout=reverse --tac \
			--prompt="$1" --query="$2" \
			--preview 'echo {}'
}

selCLIPblock() {
	perl -0777 -ne 'while (/\|\|CLIP\|\|\{.*?\}\|\|CLIP\|\|/gs) { print $& . "\0" }' "$chfile" | \
		fzf --read0 --layout=reverse --tac \
			--prompt="$1" --query="$2" \
			--preview 'echo {}'
}

chcopy() {
	chfilecheck
	s=$(selCLIP "COPY > ")
	echo "$s"
	case "$OS" in
		Linux) printf %s "$s" | xclip -selection clipboard ;;
		Darwin) printf %s "$s" | pbcopy ;;
		*) echo "unsupported OS. are you running on a potato?" ;;
	esac
}

chdel() {
	chfilecheck
	sel=$(selCLIPblock "DELETE > ")
	[[ -z $sel ]] && { echo "deletion cancelled."  ; exit 0 ;}

	lines=$(rg -U -F "$sel" -n "$chfile" | awk -F : '{ print $1 }')
	beg=$(echo "$lines" | head -n1)
	end=$(echo "$lines" | tail -n1)
	sed -i '' "$beg,$end d" "$chfile"
}

chsel() {
	chfilecheck
	s=$(selCLIP "$1" "$2" )
	echo "$s"
}

chclear() {
	clclipboard() { printf "" | pbcopy ; }
	clhistory() { : > "$chfile" ; }

	clearmenu() {
		choice=$(printf "clipboard\nhistory" | fzy -p "ch clear > ")
		case "$choice" in
			clipboard) clclipboard ;;
			history) clhistory ;;
			*) echo "nothing cleared." ;;
		esac
	}

	case "$1" in
		clipboard|clip) clclipboard ;;
		history|hist) clhistory ;;
		*) clearmenu ;;
	esac
}

chedit() { "$EDITOR" "$chfile" ; }

chfilecheck() {
	if [ $(head -2 $chfile | wc -l) -lt 2 ]; then
		cat << EOF
+---------------------------+
|  (ch) clipboard history   |
|---------------------------|
|                           |
|      < no ch clips >      |
|                           |
+---------------------------+
EOF
		read -rp "press any key to exit..." ;
		exit 0 ;
	fi
}

opts() {
	case "$1" in
		save|-s) chsave ;;
		copy|-c) chcopy ;;
		delete|del|-d) chdel ;;
		select|sel|-sel) chsel "${2:-SELECT > }" "$3" ;;
		clear|-cl) chclear "$2";;
		edit|ed|-e) chedit ;;
		help|-h|--help) chhelp ;;
		*) echo "Usage: $0 {(-c)opy|(-s)save|(-d)elete|(-sel)ect|(-cl)ear|(-e)dit|(-h)elp}" ;;
	esac
}

if [[ -n "$1" ]]; then
	opts "$@"
else
	opts=("copy" "save" "delete" "select" "clear" "edit" "help")
	sel=$(printf "%s\n" "${opts[@]}" | fzy -p "ch > ")
	opts "$sel"
fi
