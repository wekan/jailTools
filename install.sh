#! /bin/sh

case "$(readlink -f /proc/$$/exe)" in
	*busybox)
		sh="$(readlink -f /proc/$$/exe) sh"
		echo "using shell : $sh"
	;;

	*)
		sh="$(readlink -f /proc/$$/exe)"
		echo "using shell : $sh"
	;;
esac

. $(dirname $0)/scripts/utils.sh

if [ "$1" != "" ]; then
	if [ ! -d $1 ]; then
		echo "Please ensure the path is a directory and is writable"
		exit 1
	else
		scriptsDir=$(dirname $0)

		if [ "$(echo $scriptsDir | sed -e 's/^\(.\).*$/\1/')" != "/" ]; then # if the directory is not an absolute path, we use PWD
			scriptsDir=$PWD/$(dirname $0)
		fi

		# we change the internal path to the path where this script is
		populateFile $scriptsDir/scripts/jailtools.template.sh \/bin\/sh "$sh" @SCRIPT_PATH@ $scriptsDir > $1/jailtools
		ln -sfT $1/jailtools $1/jtools
		ln -sfT $1/jailtools $1/jt
		chmod u+x $1/jailtools
		echo "Done. Installed \`jailtools' and the symlinks \`jtools' and \`jt' in $1"
	fi
else
	echo "Please input a directory where you want to install the \`jailtools' master script"
	echo "Note that only that script is installed (along with the \`jt' and \`jtools' symlinks). It finds the other scripts by reference."
	exit 1
fi
