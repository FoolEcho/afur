#!/bin/bash -e
#
#	afur-makepkg - Génrère des paquets et les envoie sur [archlinuxfr]
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

myver='1.0'
myapp='afur-makepkg'
clean_first=0
from_dir=''
get_pkgbuild=''
remove_pkgdest=0
KEEP_BUILD=0
SEND=1
SEND_FILES=0
WARN_MAKEPKG_CONF=1

MAKEPKG_ARGS='--config /etc/afur-makepkg.conf -sr'


# TODO: avoir un makepkg.conf spécifique
[[ -r /etc/afur-makepkg.conf ]] && source /etc/afur-makepkg.conf
[[ -r $HOME/.afur-makepkg.conf ]] && source $HOME/.afur-makepkg.conf


usage ()
{
	echo "$myapp $myver"
	echo
	echo 'Usage: '$(basename "$0")' [options] -- [makepkg args]'
	echo "Ce script permet d'envoyer un paquet sur [archlinuxfr]."
	echo 'Sans options, par défaut il le construit.'
	echo
	echo 'Options:'
	echo -e "\t-h        Aide"
	echo -e "\t-c        Supprime les répertoires src/ et pkg/ avant de commencer"
	echo -e "\t-d <dir>  Répertoire contenant un paquet pré-construit"
	echo -e "\t-G        Utilisation de yaourt pour récupérer un PKGBUILD"
	echo -e "\t-k        Construit le paquet dans le répertoire par défaut"
	echo -e "\t-n        Ne pas envoyer le paquet"
	echo -e "\t-s        Envoyer les paquets/sources indiqués."
	exit $1
}

while getopts 'cd:G:hkns' arg; do
	case "${arg}" in
		c) clean_first=1 ;;
		d) from_dir="$OPTARG" ;;
		G) get_pkgbuild="$OPTARG" ;;
		k) KEEP_BUILD=1 ;;
		n) SEND=0 ;;
		s) SEND_FILES=1 ;;
		h) usage 0;;
		\?) usage 1;;
		*) MAKEPKG_ARGS="$MAKEPKG_ARGS -$arg $OPTARG" ;;
	esac
done

clean_dir ()
{
	echo 'Suppression des répertoires src/ et pkg/ dans 5 sec...'
	echo 'Ctrl-C pour arrêter.'
	sleep 5
	rm -r src pkg
}


build_filelist ()
{
	local folder="$1"
	[[ -d $folder ]] || return 1
	file_list=()
	for f in $(find "$folder" -type f -name "*$PKGEXT")
	do
		file_list+=("$f")
	done
	for f in $(find "$folder" -type f -name "*$SRCEXT")
	do
		file_list+=("$f")
	done
}


build ()
{
	makepkg $MAKEPKG_ARGS || return 1
	for pkg in "$PKGDEST/*$PKGEXT"; do
		if LC_ALL=C namcap $pkg | grep -q '^Err'; then
			echo
			echo 'Erreur lors du passage de namcap.'
			echo "Paquet: $pkg"
			exit 1
		fi
	done
	makepkg --source $MAKEPKG_ARGS || return 1
}

send ()
{
	echo 'Les fichiers suivants vont être envoyés sur [archlinuxfr]:'
	echo
	for f in "${file_list[@]}"
	do
		echo $f
	done
	echo
	echo 'Ctrl-C pour arrêter, [Entrée] pour continuer...'
	read

	{
		echo 'user "'$USER'" "'$PASSWD'"'
		for f in "${file_list[@]}"
		do
			echo 'put "'$f'"'
		done
		echo 'quit'
	} |	lftp "$SRV_URI" 
}

file_list=()
PKGDEST=''

if ((SEND_FILES)); then
	[[ ! ${*:$OPTIND} ]] && echo 'Aucun fichier en paramètres!' && exit 1
	file_list=()
	for f in ${*:$OPTIND}; do
		[[ ! -r $f ]] && echo "Impossible de lire $f." && exit 1
		file_list+=("$f")
	done
else
	MAKEPKG_ARGS="$MAKEPKG_ARGS ${*:$OPTIND}"
	if ((WARN_MAKEPKG_CONF)) && [[ -r "$HOME/.makepkg.conf" ]]; then
		echo "Vous avez une configuration personalisée pour 'makepkg': "
		echo "- $HOME/.makepkg.conf"
		echo
		echo "Certains réglages peuvent produire des paquets non compatibles."
		echo
		echo "Vous pouvez empêcher ce message de s'afficher en définissant l'option"
		echo "'WARN_MAKEPKG_CONF=0' dans /etc/afur-makepkg.conf"
		exit 1
	fi
fi


if [[ $get_pkgbuild ]]; then
	if [[ ! $GET_PKGBUILD_CMD ]]; then
		echo "Il faudrait définir une commande pour récupérer le PKGBUILD d'un paquet"
		echo "dans /etc/afur-makepkg.conf"
		echo "ex: GET_PKGBUILD_CMD='/usr/bin/yaourt -G'"
		exit 1
	fi
	eval $GET_PKGBUILD_CMD "$get_pkgbuild" || exit 1
	from_dir="$(readlink -f ${get_pkgbuild#*/})"
fi

if ((! SEND_FILES)) && [[ ! $from_dir ]]; then
	((clean_first)) && clean_dir
	if ((KEEP_BUILD)); then
		export PKGDEST=$(pwd)
	else
		remove_pkgdest=1
		export PKGDEST=$(mktemp -d) 
	fi
	export SRCPKGDEST=$PKGDEST 
	if ! build; then
		echo
		echo "- Erreur lors de la construction du paquet."
		echo "- Répertoire de compilation: $PKGDEST"
		exit 1
	fi
	build_filelist "$PKGDEST"
elif ((!SEND_FILES)) && [[ $from_dir ]]; then
	build_filelist "$from_dir"
fi

if ((SEND)); then
	if ! send; then
		echo
		echo "- Erreur lors de l'envoi des fichiers."
		[[ $PKGDEST ]] && echo "- Répertoire de compilation: $PKGDEST"
		exit 1
	fi

	((remove_pkgdest)) && rm -r "$PKGDEST"
	echo
	echo 'Envoi effectué'
fi

# vim: set ts=4 sw=4 noet:
