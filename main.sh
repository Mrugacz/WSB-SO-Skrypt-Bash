#!/bin/bash
# Autor: Jakub Mrugalski
# Url: https://github.com/Mrugacz/WSB-SO-Skrypt-Bash

# ── funkcje pomocnicze ────────────────────────────────────────────────

# COLORS
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
NOCOLOR="\e[0m"
BOLD="\e[1m"

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
        echo -e "${BLUE}[I]: $message${NOCOLOR}"
        ;;
    w | a | warn | alert | warning)
        echo -e "${YELLOW}[W]: $message${NOCOLOR}"
        ;;
    e | err | error | fail)
        echo -e "${RED}${BOLD}[E]: $message${NOCOLOR}"
        return 1
        ;;
    s | succ | success | completed)
        echo -e "${GREEN}[S]: $message${NOCOLOR}"
        ;;
    *)
        echo -e "${BOLD}[N]: $message${NOCOLOR}"
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

# sprawdzenie usera
if [ "$EUID" -ne 0 ]; then
    msg -l e -m "Skrypt wymaga uprawnień ROOT."
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
            if ! getent group "$group1" >/dev/null; then
                groupadd "$group1"
            fi
            usermod -aG "$group1" "$username"
            msg -l i -m "$username dodano do grupy $group1"
        else
            if ! getent group "$group2" >/dev/null; then
                groupadd "$group2"
            fi
            usermod -aG "$group2" "$username"
            msg -l i -m "$username dodano do grupy $group2"
        fi
    done
}

list_users() {
    local users=$(awk -F: '{ print $1 }' /etc/passwd)

    titlebar "Użytkownicy"

    echo -e "Liczba użytkowników: $(echo "$users" | wc -l)\n"
    echo -e "Użytkownicy\n$users\n"
}

list_groups() {
    local groups=$(awk -F: '{ print $1 }' /etc/group)
    titlebar "Grupy"
    echo -e "Liczba grup: $(echo "$groups" | wc -l)\n"
    echo -e "Grupy:\n$groups\n"
}

list_users_in_group() {
    group_name=$1
    if ! getent group "$group_name" >/dev/null; then
        msg -l e -m "Grupa $group_name nie istnieje"
        return 1
    fi
    users=$(awk -F: -v group_name="$group_name" '$1 == group_name { print $4 }' /etc/group) # analogiczne do grep $group_name /etc/group | awk -F: '{ print $4 }'
    titlebar "Użytkownicy w grupie $group_name"
    echo -e "$users\n"
}

remove_user() {
    local username=$1
    if ! id "$username" &>/dev/null; then
        msg -l e -m "Użytkownik $username nie istnieje"
        return 1
    fi
    userdel -r "$username"
    msg -l i -m "Usunięto użytkownika $username"
}

remove_group() {
    local group_name=$1
    if ! getent group "$group_name" >/dev/null; then
        msg -l e -m "Grupa $group_name nie istnieje"
        return 1
    fi
    groupdel "$group_name"
    msg -l i -m "Usunięto grupę $group_name"
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

set_static_ip() {
    local interface=$1
    local ip=$2
    local mask=$3
    local gateway=$4
    local dns=$5

    if [ -z "$ip" ] || [ -z "$mask" ] || [ -z "$gateway" ] || [ -z "$dns" ]; then
        msg -l e -m "Wszystkie parametry są wymagane"
        menu_network_config
    fi

    ip addr add "$ip"/"$mask" dev "$interface"
    ip route add default via "$gateway"
    echo "nameserver $dns" >/etc/resolv.conf
    msg -l i -m "Ustawiono statyczne IP dla interfejsu $interface"
}

set_dhcp_ip() {
    local interface=$1

    dhclient "$interface"
    msg -l i -m "Ustawiono dynamiczne IP dla interfejsu $interface"
}

# ── Grupa 3 [5pkt] ────────────────────────────────────────────────────

#  Zad1.      Przeniesie pliki z katalogu X do katalogu XX. Ale tylko te, które pasują do podanego wzorca. Dodatkowo zliczy ilości wystąpień i stosowny komunikat informujący o tym. Stwórz 3 wzorce.

#  Zad2.      Zliczy i wyświetli: konta i grupy użytkowników. Program ma również menu, w którym wybieramy czynność do wykonania. Przykładowe czynności to usuwanie, dodawanie, modyfikowanie (nazwy), przenoszenie – użytkowników i grup.
#  NOTE: to nie powinno byc w sekcji wyzej? CO TO ZNACZY PRZENOSZENIE UZYTKOWNIKOW I GRUP? Mam przenosic /etc/passwd? wtf?

#  Zad3.      policzy pliki w katalogu wskazanym jako parametr X, policzy katalogi w katalogu wskazanym jako parametr X, a ponadto skasuje, utworzy, skopiuje, przeniesie plik oraz katalog - wskazany jako parametr. Po skopiowaniu lub przeniesieniu powinna pojawić się informacja o liczbie przeniesionych/skopiowanych/usuniętych/znajdujących się plików/katalogów.
# NOTE: nie ogarniam, mam wywalic plik, nastepnie utworzyc go, skopiowac i przeniesc jednoczesnie? rownoczesnie liczyc ile usunie/przeniesie (zawsze 1, bo taka jest instrukcja)

# ──────────────────────────────────────────────────────────────────────

pattern1='*.txt'
pattern2='*.sh'
pattern3='*.log'

move_files() {
    local pattern="pattern$1"
    local source_dir=$2
    local dest_dir=$3

    if [ ! -d "$source_dir" ]; then
        msg -l e -m "Katalog źródłowy nie istnieje"
        return 1
    fi

    if [ ! -d "$dest_dir" ]; then
        msg -l e -m "Katalog docelowy nie istnieje"
        return 1
    fi

    local files_count=$(find "$source_dir" -type f -name "$pattern" | wc -l)
    mv "$source_dir"/"$pattern" "$dest_dir"
    msg -l i -m "Przeniesiono $files_count plików z katalogu $source_dir do $dest_dir"
}

count_files() {
    local dir=$1
    local files_count=$(find "$dir" -type f | wc -l)
    local dirs_count=$(find "$dir" -type d | wc -l)
    msg -l i -m "Liczba plików: $files_count, liczba katalogów: $dirs_count"
}

remove_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        msg -l e -m "Plik $file nie istnieje"
        return 1
    fi
    rm "$file"
    msg -l i -m "Usunięto plik $file"
}

create_file() {
    local file=$1
    if [ -f "$file" ]; then
        msg -l e -m "Plik $file już istnieje"
        return 1
    fi
    touch "$file"
    msg -l i -m "Utworzono plik $file"
}

copy_file() {
    local source_file=$1
    local dest_file=$2
    if [ ! -f "$source_file" ]; then
        msg -l e -m "Plik źródłowy $source_file nie istnieje"
        return 1
    fi
    cp "$source_file" "$dest_file"
    msg -l i -m "Skopiowano plik $source_file do $dest_file"
}

move_file() {
    local source_file=$1
    local dest_file=$2
    if [ ! -f "$source_file" ]; then
        msg -l e -m "Plik źródłowy $source_file nie istnieje"
        return 1
    fi
    mv "$source_file" "$dest_file"
    msg -l i -m "Przeniesiono plik $source_file do $dest_file"
}

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

create_database() {
    local file='database.txt'
    local columns_count

    if [ -f "$file" ]; then
        msg -l w -m "Baza danych już istnieje, czy chcesz nadpisać? [y/n]"
        read -n 1 overwrite
        if [ "$overwrite" == 'y' ]; then
            rm "$file"
        fi
    fi

    echo -e "\nPodaj ilość kolumn: "
    read columns_count
    if [ -z "$columns_count" ]; then
        msg -l e -m "Ilość kolumn jest wymagana"
        return 1
    fi

    touch "$file"
    while true; do
        echo -e "\nCzy chcesz wprowadzić dane? [y/n]: "
        read -n 1 input_data
        if [ "$input_data" == 'y' ]; then
            for i in $(seq 1 "$columns_count"); do
                echo -e "\nPodaj dane dla kolumny $i: "
                read data
                echo -n "$data " >>"$file"
            done
            echo >>"$file"
        else
            break
        fi
    done

    echo -e "\nCzy chcesz wyświetlić plik? [y/n]: "
    read -n 1 display_file
    if [ "$display_file" == 'y' ]; then
        echo
        cat "$file"
    fi
}

display_database() {
    local file='database.txt'
    if [ ! -f "$file" ]; then
        msg -l e -m "Baza danych nie istnieje"
        return 1
    fi
    echo "Podaj kolumny do wyświetlenia (np. 1 3): "
    read -a columns
    IFS=','

    cat "$file" | cut -d' ' -f"${columns[*]}"
}

# ── menu ──────────────────────────────────────────────────────────────

# Prompt w selekcie
PS3=$(
    echo -ne "\n"
    separator
    echo "> "
)

menu() {
    titlebar "Menu"
    COLUMNS=1

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
    echo
    separator
    read -p "Naciśnij dowolny klawisz aby wrócić do menu..."
    menu
}

# ── uzytkownicy ───────────────────────────────────────────────────────

menu_users() {
    COLUMNS=1

    select option in "Utwórz użytkowników" "Lista użytkowników" "Lista grup" "Lista użytkowników w grupie" "Usuwanie użytkowników" "Usuwanie grup" "Powrót"; do
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
        "Usuwanie użytkowników")
            read -p "Podaj nazwę użytkownika: " username
            remove_user "$username"
            return_menu
            ;;
        "Usuwanie grup")
            read -p "Podaj nazwę grupy: " group_name
            remove_group "$group_name"
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

# ── siec ──────────────────────────────────────────────────────────────

menu_network() {
    COLUMNS=1

    select option in "Konfiguracja Sieci" "Narzędzia sieciowe" "Informacje o sieci" "Powrót"; do
        case $option in
        "Konfiguracja Sieci")
            titlebar "Konfiguracja Sieci"
            menu_network_config
            ;;
        "Narzędzia sieciowe")
            titlebar "Narzędzia sieciowe"
            menu_network_tools
            ;;
        "Informacje o sieci")
            titlebar "Informacje o sieci"
            ip a s
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

menu_network_config() {
    COLUMNS=1

    select option in "Ustaw IP statyczne" "Ustaw IP dynamiczne" "Powrót"; do
        case $option in
        "Ustaw IP statyczne")
            select interface in $(ip link show | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]" { print $2 }'); do
                read -p "Podaj IP: " ip
                read -p "Podaj maskę: " mask
                read -p "Podaj bramę: " gateway
                read -p "Podaj DNS: " dns
                set_static_ip "$interface" "$ip" "$mask" "$gateway" "$dns"
                return_menu
            done
            ;;
        "Ustaw IP dynamiczne")
            select interface in $(ip link show | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]" { print $2 }'); do
                set_dhcp_ip "$interface"
                return_menu
            done
            ;;
        "Powrót")
            menu_network
            ;;
        *)
            msg -l e -m "Opcja nie istnieje"
            ;;
        esac
    done
}

menu_network_tools() {
    COLUMNS=1

    select option in "Ping" "Traceroute" "UFW" "Netstat" "Powrót"; do
        case $option in
        "Ping")
            read -p "Podaj adres docelowy(IP/domena): " ip
            ping -c 4 "$ip"
            return_menu
            ;;
        "Traceroute")
            read -p "Podaj adres docelowy(IP/domena): " ip
            traceroute "$ip"
            return_menu
            ;;
        "UFW")
            ufw status
            return_menu
            ;;
        "Netstat")
            netstat -tulpn
            return_menu
            ;;
        "Powrót")
            menu_network
            ;;
        *)
            msg -l e -m "Opcja nie istnieje"
            ;;
        esac
    done
}

# ── pliki ─────────────────────────────────────────────────────────────

menu_files() {
    COLUMNS=1

    select option in "Przenieś pliki wg wzorca" "Policz pliki/katalogi" "Usuń plik" "Utwórz plik" "Skopiuj plik" "Przenieś plik" "Powrót"; do
        case $option in
        "Przenieś pliki wg wzorca")
            echo "Wybierz wzorzec:"
            echo '1. *.txt'
            echo '2. *.sh'
            echo '3. *.log'
            select pattern in 1 2 3; do
                read -p "Podaj katalog źródłowy: " source_dir
                read -p "Podaj katalog docelowy: " dest_dir
                move_files "$pattern" "$source_dir" "$dest_dir"
                return_menu
            done
            ;;
        "Policz pliki/katalogi")
            read -p "Podaj katalog: " dir
            count_files "$dir"
            return_menu
            ;;
        "Usuń plik")
            read -p "Podaj nazwę pliku: " file
            remove_file "$file"
            return_menu
            ;;
        "Utwórz plik")
            read -p "Podaj nazwę pliku: " file
            create_file "$file"
            return_menu
            ;;
        "Skopiuj plik")
            read -p "Podaj plik źródłowy: " source_file
            read -p "Podaj plik docelowy: " dest_file
            copy_file "$source_file" "$dest_file"
            return_menu
            ;;
        "Przenieś plik")
            read -p "Podaj plik źródłowy: " source_file
            read -p "Podaj plik docelowy: " dest_file
            move_file "$source_file" "$dest_file"
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

# ── baza danych ───────────────────────────────────────────────────────

menu_database() {
    COLUMNS=1

    select option in "Utwórz bazę" "Wyświetl bazę" "Powrót"; do
        case $option in
        "Utwórz bazę")
            create_database
            return_menu
            ;;
        "Wyświetl bazę")
            display_database
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
