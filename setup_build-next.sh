#!/bin/sh
# OpenXT git repo setup file.

#######################################################################
# checkout_git_branch                                                 #
# param1: Path to the git repo                                        #
# param2: Preferred branch to checkout.  Fallback will be to master.  #
#                                                                     #
# Checks out the branch specified in param2 for the repo located at   #
# the file path in param1.  If the branch is not part of the git repo #
# the master branch is checked out instead.                           #
#######################################################################
checkout_git_branch() {
	local path="$1"
	local branch="$2"

	cd $path
	git checkout "$branch" 2>/dev/null || { echo "The branch $branch does not exist. Falling back to master."; git checkout master 2>/dev/null; }
	cd $OLDPWD
}

#######################################################################
# fetch_git_repo                                                      #
# param1: Path (absolute) to place the repo                           #
# param2: Git url to fetch                                            #
# param3: Preferred branch to checkout.  Fallback will be to master.  #
#                                                                     #
# Fetches the repo specified by param2 into the directory specified   #
# by param1.  The branch name is not used in the fetch, but to then   #
# call checkout_git_branch.                                           #
#######################################################################
fetch_git_repo() {
	local path="$1"
	local repo="$2"
	local branch="$3"

	echo "Fetching $repo..."
	set +e
	git clone -n $repo "$path" || die "Clone of git repo failed: $repo"
	set -e
}

#######################################################################
# update_git_repo                                                     #
# param1: Path to the git repo                                        #
#                                                                     #
# Updates the repo located at the path specified by param1.  All      #
# branches will be updated.                                           #
#######################################################################
update_git_repo() {
	local path="$1"
	local repo="$2"

	echo "Updating local copy of $repo..."
	cd $path
	set +e
	#git fetch || die "Update of git repo failed: $path"
	cd $OLDPWD
}

process_git_repo() {
	local path="$1"
	local repo="$2"
	local branch="$3"


	if [ -d $path ]; then
		# The destination for the repo already exists.
		if [ -d $path/.git ]; then
			# And it is already a git repo!
			cd $path
			set +e
			local existing=$(git config --get remote.origin.url)
			set -e
			cd $OLDPWD
			if [ "$existing" = "$repo" ]; then
				# The repo has already been pulled before.  Update it.
				update_git_repo $path $repo
				# Always checkout the branch again in case the user specified another one.
				checkout_git_branch $path $branch
			else
				# Whatever is here it is not what we want.
				echo "Found an unexpected repo at $path.  Replacing with $repo."
				rm -rf $path
				fetch_git_repo $path $repo $branch
				# Always checkout the branch again in case the user specified another one.
				checkout_git_branch $path $branch
			fi
		else
			# The folder as already there but not a git repo.  Blow it away.
			echo "Path $path exists but is not a git repo.  Replacing with $repo."
			cd $OLDPWD
			rm -rf $path
			fetch_git_repo $path $repo $branch
			# Always checkout the branch again in case the user specified another one.
			checkout_git_branch $path $branch
		fi
	else
		# The path does not exist.  Proceed.
		fetch_git_repo $path $repo $branch
		# Always checkout the branch again in case the user specified another one.
		checkout_git_branch $path $branch
	fi
}

OE_XENCLIENT_DIR=`pwd`
REPOS=$OE_XENCLIENT_DIR/repos
OE_PARENT_DIR=$(dirname $OE_XENCLIENT_DIR)

# Load our config
[ -f "$OE_PARENT_DIR/.config" ] && . "$OE_PARENT_DIR/.config"

[ -f "$OE_XENCLIENT_DIR/local.settings" ] && . "$OE_XENCLIENT_DIR/local.settings"

mkdir -p $REPOS || die "Could not create local build dir"

# Pull down the OpenXT repos
process_git_repo $REPOS/xenclient-oe https://github.com/aikidokatech/xenclient-oe.git $XENCLIENT_TAG
process_git_repo $REPOS/bitbake $BITBAKE_REPO $BB_BRANCH
process_git_repo $REPOS/openembedded-core $OE_CORE_REPO $OE_BRANCH
process_git_repo $REPOS/meta-openembedded $META_OE_REPO $OE_BRANCH
process_git_repo $REPOS/meta-java $META_JAVA_REPO $OE_BRANCH
process_git_repo $REPOS/meta-selinux $META_SELINUX_REPO $OE_BRANCH

if [ ! -z "$EXTRA_DIR" ]; then
	process_git_repo $REPOS/$EXTRA_DIR $EXTRA_REPO $EXTRA_TAG
fi

if [ ! -e $OE_XENCLIENT_DIR/conf/local.conf ]; then
  ln -s $OE_XENCLIENT_DIR/conf/local.conf-dist \
      $OE_XENCLIENT_DIR/conf/local.conf
fi

BBPATH=$OE_XENCLIENT_DIR/oe/xenclient:$REPOS/openembedded:$OE_XENCLIENT_DIR/oe-addons
if [ ! -z "$EXTRA_DIR" ]; then
  BBPATH=$REPOS/$EXTRA_DIR:$BBPATH
fi

cat > oeenv <<EOF 
OE_XENCLIENT_DIR=$OE_XENCLIENT_DIR
PATH=$OE_XENCLIENT_DIR/repos/bitbake/bin:\$PATH
BBPATH=$BBPATH
BB_ENV_EXTRAWHITE="OE_XENCLIENT_DIR MACHINE GIT_AUTHOR_NAME EMAIL"

export OE_XENCLIENT_DIR PATH BBPATH BB_ENV_EXTRAWHITE
EOF
