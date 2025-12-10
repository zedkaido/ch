#!/usr/bin/env bash

chhelp() {
	cat << 'EOF'
Usage: ch [commands]

Description: A ch(clipboard history) you are in control of.

Commands:
   -a, add
   -c, copy
   -d, delete, del
   -s, select
   -e, edit 
   -clear [(clip)board|(hist)ory]

Dependencies: fzf, fzy, rg
EOF
}
 
fzf() { command fzf --no-color "$@" ; }

OS=$(uname -s)

chfile=$HOME/.local/share/ch.txt
if [ ! -f "$chfile" ]; then
	mkdir -p $HOME/.local/share
	touch $HOME/.local/share/ch.txt
fi

chadd() {
	clipboard=""
	case "$OS" in
		Linux) clipboard=$(xclip -selection clipboard -o) ;;
		Darwin) clipboard=$(pbpaste) ;;
		*) echo "Unsupported OS. Are you running on a potato?" ;;
	esac
	printf "||CLIP||{\n%s\n}||CLIP||\n" "$clipboard" | col -b >> $chfile
}

selCLIP() {
	perl -0777 -ne 'while (/\|\|CLIP\|\|\{\n?(.*?)\n?\}\|\|CLIP\|\|/gs) { print $1 . "\0" }' $chfile| \
		fzf --read0 --layout=reverse \
			--prompt="$1" --query="$2" \
			--preview 'echo {}'
}

selCLIPblock() {
	perl -0777 -ne 'while (/\|\|CLIP\|\|\{.*?\}\|\|CLIP\|\|/gs) { print $& . "\0" }' $chfile | \
		fzf --read0 --layout=reverse \
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
	if [ -z "$sel" ]; then echo "deletion cancelled." exit 0 ; fi

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
	clhistory() { : > $chfile ;}

	clfzy() {
		choice=$(printf "clipboard\\nhistory" | fzy --prompt "CLEAR > ")
		case "$choice" in
			clipboard) clclipboard ;;
			history) clhistory ;;
			*) echo "nothing cleared." ;;
		esac
	}

	case "$1" in
		clipboard|clip) cclipboard ;;
		history|hist) clhistory ;;
		*) clfzy ;;
	esac
}

chedit() { $EDITOR "$chfile" ; }

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
	   	read -p "press any key to exit..." ;
		exit 0 ; 
	fi
}

chfzy() {
	choice=$(printf "copy\\nadd\\ndelete\\nselect\\nclear\\nedit\\nhelp" | fzy)
	case "$choice" in
		copy) chcopy ;;
		add) chadd ;;
		delete) chdel ;;
		select) chsel "${2:-SELECT > }" "$3" ;;
		clear) chclear ;;
		edit) chedit ;;
		help) chhelp ;;
		*) echo "usage: $0 {(-c)opy|(-a)dd|(-d)elete|(-s)elect|(-c)lear|(-e)dit|(-h)elp}" ;;
	esac
}

case "$1" in
	add|-a) chadd ;;
	copy|-c) chcopy ;;
	delete|del|-d) chdel ;;
	select|sel|-s) chsel "${2:-SELECT > }" "$3" ;;
	clear|-cl) chclear "$2";;
	edit|ed|-e) chedit ;;
	help|-h|--help) chhelp ;;
	*) chfzy ;;
esac
