#! /bin/sh

# this has to be called from the super script jailtools
if [ "$jailToolsPath" = "" ] || [ ! -d $jailToolsPath ]; then
	echo "This script has to be called from the 'jailtools' super script like so :"
	echo "jailtools upgrade <path to jail>"
	exit 1
fi

# if the result is 0 this means the files are the same
fileDiff() {
	diff -q $2/$1 $3/$1 >/dev/null
}

startUpgrade() {
	# we are already garanteed that the first argument is the jail path and it is valid
	local jPath=$1

	# convert the path of this script to an absolute path
	if [ "$jPath" = "." ]; then
		local jPath=$PWD
	else
		if [ "$(substring 0 1 $jPath)" = "/" ]; then
			# absolute path, we do nothing
			:
		else
			# relative path
			local jPath=$PWD/$jPath
		fi
	fi
	local jailName=$(basename $jPath)

	if [ ! -e $jPath/._rootCustomConfig.sh.initial ]; then
		echo "This jail is too old to be upgraded automatically, please upgrade it manually first"
		exit 1
	fi

	if [ -e $jPath/run/jail.pid ]; then
		echo "This jail may be running. You need to stop it before upgrading."
		exit 1
	fi

	if [ -e $jPath/startRoot.sh.orig ] || [ -e $jPath/rootCustomConfig.sh.orig ] || [ -e $jPath/rootCustomConfig.sh.patch ]; then
		echo "Either startRoot.sh.orig or rootCustomConfig.sh.orig or rootCustomConfig.sh.patch are present."
		echo "Please either remove them or move them somewhere else as we don't want to override them"
		echo "They could contain important backups from a previously failed upgrade attempt"
		echo "rerun this script once that is done"
		exit 1
	fi

	local njD=$jPath/.__jailUpgrade # the temporary new jail path
	[ ! -d $njD ] && mkdir $njD

	local nj=$njD/$jailName

	jailtools new $nj >/dev/null

	if $(fileDiff startRoot.sh $jPath $nj) && $(fileDiff ._rootCustomConfig.sh.initial $jPath $nj) ; then
		echo "Jail already at the latest version."
	else
		echo "Initial Checks complete. Upgrading jail."

		cp $jPath/rootCustomConfig.sh $jPath/rootCustomConfig.sh.orig
		cp $jPath/startRoot.sh $jPath/startRoot.sh.orig
		# first patch
		$jailToolsPath/busybox/busybox diff -p $jPath/._rootCustomConfig.sh.initial $jPath/rootCustomConfig.sh > $jPath/rootCustomConfig.sh.patch
		cp $nj/rootCustomConfig.sh $jPath
		cp $nj/startRoot.sh $jPath


		# we first make a patch from the initial
		# we then make a patch from the new jail to the current jail
		# these 2 patches are attempted in order, if one of them pass, we do it
		# otherwise, we have to rely on the user to patch manually

		# first attempt

		[ ! -d $jPath/.backup ] && mkdir $jPath/.backup
		local backupF=$jPath/.backup/$($jailToolsPath/busybox/busybox date +"%Y.%m.%d-%T")
		mkdir $backupF

		if cat $jPath/rootCustomConfig.sh.patch | $jailToolsPath/busybox/busybox patch; then
			cp $nj/._rootCustomConfig.sh.initial $jPath

			echo "Done upgrading jail. Thank you for using the jailUpgrade services."
		else 
			cp $nj/._rootCustomConfig.sh.initial $jPath/rootCustomConfig.sh.initial.new
			cp rootCustomConfig.sh rootCustomConfig.sh.new
			cp $jPath/rootCustomConfig.sh.orig rootCustomConfig.sh
			cp $jPath/startRoot.sh startRoot.sh.new
			cp $jPath/startRoot.sh.orig startRoot.sh

			echo "There was an error upgrading your custom configuration file."
			echo "You will need to upgrade it manually and here are the steps :"
			echo "We moved the files of the upgrade in the path : $backupF"
			echo "You could attempt to upgrade manually by comparing your rootCustomConfig.sh with rootCustomConfig.sh.new and merge the changes manually."
			echo "Or you can check the backup path to determine what exactly went wrong."

			echo "Alternatively, you can use a tool like GNU diff3 to handle the changes for you. Do this :"
			echo "diff3 -m rootCustomConfig.sh.new ._rootCustomConfig.sh.initial rootCustomConfig.sh > rootCustomConfig.sh.merged"
			echo "At this point, the file rootCustomConfig.sh.merged will contain the changes that you can manually merge."
			echo "When you are done, just move rootCustomConfig.sh.merged to rootCustomConfig.sh"
			echo "Also copy startRoot.sh.new to startRoot.sh"
			echo "And rootCustomConfig.sh.initial.new to ._rootCustomConfig.sh.initial"

			echo "In the meantime, we have not upgraded any of your files, so you can continue using the jail like normal."
			echo
			echo "We're sorry for the inconvenience. Thank you for using the jailUpgrade services."
		fi

		mv $jPath/rootCustomConfig.sh.orig $backupF
		mv $jPath/startRoot.sh.orig $backupF
		mv $jPath/rootCustomConfig.sh.patch $backupF
		cp $jPath/._rootCustomConfig.sh.initial $backupF
	fi

	if [ "$njD" != "" ] && [ -d $nj ]; then
		rm -Rf $nj
		rmdir $njD
	fi
}
