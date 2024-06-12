#!/bin/bash
# ── funkcje pomocnicze ────────────────────────────────────────────────

# COLORS
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
NOCOLOR="\e[0m"
BOLD="\e[1m"

# Prompt w selekcie
PS3="> "

# wystarczyloby zwykle echo ale, ze napisalem to pod inne skrypty to nie bede sie ograniczal
# msg -l (info/warning/error/success/note) -m 'message'
msg() {
	optstring="l:m:"
	local level=''
	local message=''

	while getopts ${optstring} opt; do
		case $opt in
		l)
			level="$OPTARG"
			;;
		m)
			message="$OPTARG"
			;;
		esac
	done

	OPTIND=1

	if [[ -z $message ]]; then
		echo -e "${RED}${BOLD}[ERROR]: Message is required.${NOCOLOR}"
		return 1
	fi

	case "$level" in
	i | info)
		echo -e "${BLUE}[INFO]: $message${NOCOLOR}"
		;;
	w | a | warn | alert | warning)
		echo -e "${YELLOW}[WARNING]: $message${NOCOLOR}"
		;;
	e | err | error | fail)
		echo -e "${RED}${BOLD}[ERROR]: $message${NOCOLOR}"
		return 1
		;;
	s | succ | success | completed)
		echo -e "${GREEN}[SUCCESS]: $message${NOCOLOR}"
		;;
	*)
		echo -e "${BOLD}[NOTE]: $message${NOCOLOR}"
		;;
	esac
}

separator() {
	local separator_char='='
	printf "%0$(tput cols)d" 0 | tr '0' $separator_char
}

center() {
	printf "%*s\n" $((($(tput cols) + ${#1}) / 2)) "$1"
}

titlebar() {
	clear
	echo -ne "\n"
	separator
	center "$1"
	separator
	echo -e "\n"
}

if [ "$EUID" -ne 0 ]; then
	msg -l e -m "Script is not must be run as ROOT."
	exit 1
fi

# ── Grupa 1 [11 pkt] ──────────────────────────────────────────────────

#  Zad1.

#  utworzy X kont użytkowników o nazwach user1..…userX o haśle : passwordX. Po utworzeniu każdego konta ma pojawić się informacja np. user1 utworzono, user2 utworzono... Po dodaniu do grup, program ma wyświetlić info: user1 dodano do grupy mazwagrupy itd. Pierwszą połowę userów (od 1 do X/2) przypisz do grupy studenci_informatyki, a drugą (X/2+1 - X) do studenci_etyki. Skrypt ponadto wyświetla [na życzenie a nie z automatu] konta, grupy i ich zawartość.

# ──────────────────────────────────────────────────────────────────────

create_users() {
	local users_count=$1
	local group1='studenci_informatyki'
	local group2='studenci_etyki'

	for i in $(seq 1 "$users_count"); do
		local username="user$i"
		local password="password$i"

		useradd -m -s /bin/bash "$username"
		echo "$username:$password" | chpasswd

		if [ "$i" -le $((users_count / 2)) ]; then
			usermod -aG "$group1" "$username"
			msg -l i -m "$username dodano do grupy $group1"
		else
			usermod -aG "$group2" "$username"
			msg -l i -m "$username dodano do grupy $group2"
		fi
	done
}

list_users() {
	local users=$(awk -F: '{ print $1 }' /etc/passwd)

	titlebar "Użytkownicy"
	echo -e "$users\n"
}

list_groups() {
	local groups=$(awk -F: '{ print $1 }' /etc/group)
	titlebar "Grupy"
	echo -e "$groups\n"
}

list_users_in_group() {
	group_name=$1
	users=$(awk -F: -v group_name="$group_name" '$1 == group_name { print $4 }' /etc/group) # analogiczne do grep $group_name /etc/group | awk -F: '{ print $4 }'
	titlebar "Użytkownicy w grupie $group_name"
	echo -e "$users\n"
}

# ── Grupa 2 [12 pkt] ──────────────────────────────────────────────────

#  Zad1.

#  a.      przypisze dla karty sieciowej przewodowej i bezprzewodowej :

#  i.     IP, maskę , bramę, dns – według potrzeb administratora

#  ii.      IP, maskę , bramę, dns - automatycznie

#  iii.      Jeżeli, któryś z powyższych interfejsów sieciowych nie istnieje w urządzeniu program ma wygenerować stosowany komunikat.

#  b.      Wykorzysta programy sieciowe [ping, traceroute, ipconfig, ufw, netstat …]

#  c.      Wyświetla informacje o ustawieniach sieciowych w systemie

# ──────────────────────────────────────────────────────────────────────

# ── Grupa 3 [5pkt] ────────────────────────────────────────────────────

#  Zad1.      Przeniesie pliki z katalogu X do katalogu XX. Ale tylko te, które pasują do podanego wzorca. Dodatkowo zliczy ilości wystąpień i stosowny komunikat informujący o tym. Stwórz 3 wzorce.

#  Zad2.      Zliczy i wyświetli: konta i grupy użytkowników. Program ma również menu, w którym wybieramy czynność do wykonania. Przykładowe czynności to usuwanie, dodawanie, modyfikowanie (nazwy), przenoszenie – użytkowników i grup.

#  Zad3.      policzy pliki w katalogu wskazanym jako parametr X, policzy katalogi w katalogu wskazanym jako parametr X, a ponadto skasuje, utworzy, skopiuje, przeniesie plik oraz katalog - wskazany jako parametr. Po skopiowaniu lub przeniesieniu powinna pojawić się informacja o liczbie przeniesionych/skopiowanych/usuniętych/znajdujących się plików/katalogów.

# ──────────────────────────────────────────────────────────────────────

# ── Grupa 4 [12 pkt] ──────────────────────────────────────────────────

#  Zad1.      stworzy bazę danych [plik tekstowy] z przykładową zawartością:

#  Nr_gracza  Imie_i_Nazwisko  Klub Ilosc_pkt

#  23  MichaelJordan  ChicagoBulls  31

#  32  MagicJohnson   LosAngelesLakers  30

#  33  LarryBird  BostonCeltics  32

#  Wyjaśnienie: Podczas tworzenia bazy danych program pyta o ilość kolumn. Podajemy z klawiatury wartość. Program pyta czy chcesz wprowadzić dane. Y – tak. Uzupełniamy bazę wprowadzając wartości. Program pyta czy chcesz wyświetlić plik. Y – tak. Program wyświetla całą bazę danych.

#  Program umożliwia wyświetlanie tylko określonych wierszy lub kolumn [wybór podczas interakcji z programem]. Bardzo ważne aby można było wyświetlać dowolne kolumny np. 1 i 3 lub 2 i 4 :

#  MichaelJordan  31

#  MagicJohnson  30

#  LarryBird  32

#  - - - - - - -

#  X to parametr wejściowy czyli wprowadzana wartość – z klawiatury - podczas interakcji programu z użytkownikiem.

#  ------------

# ── menu ──────────────────────────────────────────────────────────────

menu() {
	titlebar "Menu"

	select option in "Użytkownicy" "Sieć" "Pliki" "Baza danych" "Wyjście"; do
		case $option in
		"Użytkownicy")
			titlebar "Użytkownicy"
			menu_users
			;;
		"Sieć")
			titlebar "Sieć"
			menu_network
			;;
		"Pliki")
			titlebar "Pliki"
			menu_files
			;;
		"Baza danych")
			titlebar "Baza danych"
			menu_database
			;;
		"Wyjście")
			exit 0
			;;
		*)
			msg -l e -m "Opcja nie istnieje"
			;;
		esac
	done
}

return_menu() {
	read -p "Naciśnij dowolny klawisz aby wrócić do menu..."
	menu
}

menu_users() {
	select option in "Utwórz użytkowników" "Lista użytkowników" "Lista grup" "Lista użytkowników w grupie" "Powrót"; do
		case $option in
		"Utwórz użytkowników")
			read -p "Podaj ilość użytkowników do utworzenia: " users_count
			create_users "$users_count"
			return_menu
			;;
		"Lista użytkowników")
			list_users
			return_menu
			;;
		"Lista grup")
			list_groups
			return_menu
			;;
		"Lista użytkowników w grupie")
			read -p "Podaj nazwę grupy: " group_name
			list_users_in_group "$group_name"
			return_menu
			;;
		"Powrót")
			menu
			;;
		*)
			msg -l e -m "Opcja nie istnieje"
			;;
		esac
	done
}

# ──────────────────────────────────────────────────────────────────────

menu
