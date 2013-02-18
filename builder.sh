#!/bin/bash

REPO_URL="http://pub.mate-desktop.org/releases/" #make it https! :(
CURRENT_RELEASE=1.4
CHECKSUMS="SHA1SUMS"

RED="\e[00;31m"
LRED="\e[01;31m"
NORMAL="\e[00m"

function warn()
{
		echo -e ${LRED}$*${NORMAL}
}

function log()
{
		echo -e ${RED}$*${NORMAL}
}

function handle_failure()
{
		[[ ${FORCE} -eq 1 ]] || exit 1
		warn "Force mode - ignoring errors"
}

function autoupgrade()
{
		#$1=package $2=old version $3=new version $4=sha1sum
		local p ov v s target escaped ss
		p=$1;ov=$2;v=$3;s=$4
		target=${p}/PKGBUILD

		[[ ${v} == "" ]] && {
				warn "Version detection failed, skipping"
				return
		}

		log "+ Auto-upgrading ${p} to version ${v}..."
		sed -i s/^pkgver=${ov}/pkgver=${v}/ ${target}
		sed -i s/^pkgrel=[0-9]/pkgrel=1/ ${target}
		escaped="$(echo "source=(${REPO_URL}${CURRENT_RELEASE}/"|sed -e 's/[\/&]/\\&/g')\${pkgname}-\${pkgver}.tar.xz"
		sed -i s/^source=.*xz/${escaped}/ ${target}
#		sed -i s/^sha.*sums=.*$/sha1sums=\(${s}\)/ ${target}
		ss=$(cd ${p} && makepkg -g)
		sed -i s/^sha[1-2].*\)$/${ss}/ ${target}
		sed -i N\;s/^sha[1-2].*\)$/${ss}/ ${target}
}

function autobuild()
{
	#$1=package
	local p
	p=$1

	log "+ Auto-building ${p}..."
	[[ ${NO_EXTRACT} -eq 1 ]] && (cd ${p} && makepkg -e)
	[[ ${NO_EXTRACT} -eq 1 ]] || (cd ${p} && makepkg)
}

function find_latest_version()
{
	#$1=package
	local p v
	p=$1

	IFS=""
	v=$(echo $sums|cut -d ' ' -f3|grep ${p}|tail -n 1)
	unset IFS
	v=${v##*-}
	v=${v%%.tar.xz}
	echo $v
}

function get_sum()
{
	#$1=package-version
	local p s
	p=$1
	IFS=""
	s=$(echo $sums|grep $p|cut -d ' ' -f1)
	unset IFS
	echo $s
}

function get_my_sums()
{
		[[ -f ${CHECKSUMS} ]] || wget ${REPO_URL}${CURRENT_RELEASE}/${CHECKSUMS}
		cat ${CHECKSUMS}
}

function process()
{
		[[ -f .skip_list ]] && skip_list=$(cat .skip_list)
		IFS="
		"
		for line in ${sums}; do
				#s=sum,p=package,v=version
				p=${line##* }
				p=${p%%.tar.xz}
				p=${p%-*}
				v=$(find_latest_version ${p})
				s=$(get_sum ${p}-${v})

				echo "${skip_list}" | grep -q ^${p} && { log "+ Skipping ${p}"; continue; }
				[[ -d ${p} ]] || { warn "! Package ${p} is missing"; continue; }
				[[ -f ${p}/PKGBUILD ]] || { warn "! PKGBUILD is missing for ${p}"; continue; }


				source $p/PKGBUILD
				[[ ${pkgver} != ${v} ]] && {
						log "- version mismatch. current: ${pkgver} newest: ${v} for package ${p}"
						autoupgrade ${p} ${pkgver} ${v} ${s} || {
								warn "! Failed auto-upgrade ${p}"
								handle_failure
						}
				}
				stat ${p}/${p}-${v}*.pkg.tar.xz > /dev/null 2>&1 || \
				autobuild ${p} || {
						warn "! Failed auto-building ${p}"
						handle_failure
				}
		done
		unset IFS
}


sums=$(get_my_sums)

OPTERR=1
while getopts ":f:v:e:a" option;
do
		case $option in
		e)
			NO_EXTRACT=1
			;;
		v)
			log "Source is ${REPO_URL}${CURRENT_RELEASE}"
			;;
		f)
			FORCE=1
			;;
		a)
			process
			exit
			;;
		*)
			;;
		esac
done
shift $(($OPTIND - 1))

[[ $# -eq 1  ]] && {
		p=$1
		[[ -d ${p} ]] || { warn "${p} does not exist."; handle_failure; }
		v=$(find_latest_version ${p})
		source ${p}/PKGBUILD
		[[ ${pkgver} != ${v} ]] && {
				log "- version mismatch. current: ${pkgver} newest: ${v} for package ${p}"
				autoupgrade ${p} ${pkgver} ${v}  || {
					warn "! Failed auto-upgrade ${p}"
					handle_failure
				}
		}
		autobuild ${p} || {
				warn "! Failed auto-building ${p}"
				handle_failure
		}
} || {
	echo "USAGE: $0 [OPTION] [PKGDIR]"
	echo "OPTIONS:"
	echo -e "\t\t-a\tBuild everything"
	echo -e "\t\t-f\tAttempt to force building on errors (keeps going on failure)"
	echo -e "\t\t-v\tVerbose"
	echo -e "\t\t-e\tDon't cleanup/extract when building (uses older src dir if present)"
	echo -e "PKGDIR:\t\t\tBuild a directory containing a PKGBUILD file"
	exit 127
}
