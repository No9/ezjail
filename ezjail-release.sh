#!/bin/sh

# ugly: this variable is set during port install time
ezjail_prefix=/usr/local
ezjail_etc=${ezjail_prefix}/etc
ezjail_share=${ezjail_prefix}/share/ezjail
ezjail_examples=${ezjail_prefix}/share/examples/ezjail
ezjail_jailcfgs=${ezjail_etc}/ezjail

# read user config
[ -f ${ezjail_etc}/ezjail.conf ] && . ${ezjail_etc}/ezjail.conf

# set defaults
ezjail_jaildir=${ezjail_jaildir:-"/usr/jails"}
ezjail_jailtemplate=${ezjail_jailtemplate:-"${ezjail_jaildir}/newjail"}
ezjail_jailbase=${ezjail_jailbase:-"${ezjail_jaildir}/basejail"}
ezjail_jailfull=${ezjail_jailfull:-"${ezjail_jaildir}/fulljail"}
ezjail_flavours=${ezjail_flavours:-"${ezjail_jaildir}/flavours"}
ezjail_sourcetree=${ezjail_sourcetree:-"/usr/src"}
ezjail_portscvsroot=${ezjail_portscvsroot:-":pserver:anoncvs@anoncvs.at.FreeBSD.org:/home/ncvs"}

# define our bail out shortcut
exerr () { echo -e "$*"; exit 1; }

# check for command
[ "$1" ] || exerr "Usage: `basename -- $0` [create|delete|list|release|update] {params}"

case "$1" in
######################## ezjail-admin RELEASE ########################
release)
  shift
  args=`getopt mpr:s: $*` || exerr "Usage: `basename -- $0` release [-m] [-p] [-r release] [-s server]"

  basejail_release=
  basejail_server=
  basejail_manpages=
  basejail_ports=
  basejail_reldir=

  set -- ${args}
  for arg do
    case ${arg} in
      -m) basejail_manpages=" manpages"; shift;;
      -m) basejail_ports=" ports"; shift;;
      -r) basejail_release="$2"; shift 2;;
      -s) basejail_server="$2"; shift 2;;
      --) shift; break;;
    esac
  done

  basejail_arch=`uname -p`
  basejail_server=${basejail_server:-"ftp.freebsd.org:"}
  basejail_server=${basejail_server#ftp://}
  basejail_dir=${basejail_server#file://}
  [ "${basejail_dir%%[!/]*}" ] || ${basejail_reldir}=${PWD}
  basejail_tmp=${ezjail_jaildir}/tmp
  basejail_fill="base ${basejail_manpages} ${basejail_ports}"

  # ftp servers normally wont provide CURRENT-builds
  if [ -z "{$basejail_release}" ]; then
    ${basejail_release}=`uname -r`
    if [ "${basejail_release%CURRENT}" != "${basejail_release}" -a "${basejail_dir}" != "${basejail_server}" ]; then
      echo "Your system is ${basejail_release}. Normally FTP-servers don't provide CURRENT-builds."
      echo -n "Release [ ${basejail_release} ]: "
      read release_tmp
      [ "$release_tmp" ] && basejail_release=${release_tmp}
    fi
  fi

  # Normally fulljail should be renamed by past ezjail-admin commands.
  # However those may have failed
  [ -d ${ezjail_jailfull} ] && chflags -R noschg ${ezjail_jailfull}
  rm -rf ${ezjail_jailfull}
  mkdir -p ${ezjail_jailfull} || exerr "Could not create temporary base jail directory ${ezjail_jailfull}."
  DESTDIR=${ezjail_jailfull}

  rm -rf ${basejail_tmp}
  for pkg in ${basejail_fill}; do
    if [ "${basejail_dir}" = "${basejail_server}" ]; then
      mkdir -p ${basejail_tmp} || exerr "Could not create temporary base jail directory ${basejail_tmp}."
      cd ${basejail_tmp}
      for basejail_path in /pub/FreeBSD/releases /pub/FreeBSD/snapshot /FreeBSD NO; do
        [ "${basejail_path}" = "NO" ] && exerr "Could not fetch ${pkg} from ${basejail_server}."
        ftp "${basejail_server}${basejail_path}/${basejail_arch}/${basejail_release}/${pkg}/*" > /dev/null && break
      done
      [ -f install.sh ] && yes | . install.sh
      rm -rf ${basejail_tmp}
    else
      cd ${basejail_reldir}/${basejail_dir}/${pkg} || exerr "Could not change to ${basejail_dir}."
      [ -f install.sh ] && yes | . install.sh
    fi
  done

  # Fill basejail from installed world
  cd ${ezjail_jailfull}
  # This mkdir is important, since cpio will create intermediate
  # directories with permission 0700 which is bad
  mkdir -p ${ezjail_jailbase}/usr
  for dir in bin boot lib libexec rescue sbin usr/bin usr/include usr/lib usr/libexec usr/sbin usr/src usr/share; do
    find ${dir} | cpio -d -p -v ${ezjail_jailbase} || exerr "Installation of ${dir} failed."
    chflags -R noschg ${dir}; rm -r ${dir}; ln -s /basejail/${dir} ${dir}
  done
  mkdir basejail

  # Try to remove the old template jail
  if [ -d ${ezjail_jailtemplate} ]; then
    if [ -d ${ezjail_jailtemplate}_old ]; then
      chflags -R noschg ${ezjail_jailtemplate}_old
      rm -rf ${ezjail_jailtemplate}_old
    fi
    mv ${ezjail_jailtemplate} ${ezjail_jailtemplate}_old
  fi
  mv ${ezjail_jailfull} ${ezjail_jailtemplate}

  ;;
*)
  exerr "Usage: `basename -- $0` [create|delete|list|update] {params}"
  ;;
esac

