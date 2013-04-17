# !/bin/bash
# ===============================================================================
# FILE		: ilixi-build.sh
# AUTHOR	: Armağan Erdem Budak
# USAGE		:
# DESCRIPTION	:
#
# LICENSE
#  
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# ==============================================================================

BASE=${PWD}/ilixi
SOURCE=$BASE/source
BUILD=$BASE/build
LOG=$BASE/log
INSTALL=$BASE/install
JOBS=8

# === FUNCTION ================================================================
#  NAME: log_error
#  DESCRIPTION: Log error messages and exit with error.
#  PARAMETERS: Error messages are printed on new lines.
# =============================================================================
log_error ()
{
   echo "(!) ${FUNCNAME[ 1 ]} ()"
   local prefix="    -> "
   for ln in "$@" ; do
      echo "${prefix}${ln}"
   done
   exit 1
}

# === FUNCTION ================================================================
#  NAME: source_git_clone
#  DESCRIPTION: Clones a git repository.
#  PARAMETER 1: destdir
#  PARAMETER 2: url
#  PARAMETER 3: branch (optional)
# =============================================================================
source_git_clone () 
{
   if [ $# -lt 2 ]
   then
      log_error "Not enough arguments!"
   fi

   git ls-remote $2 &>/dev/null
   if test $? != 0
   then
      log_error "Remote \"$2\" is not valid."
   fi

   if [ $# -eq 2 ]
   then            
      git clone $2 $1
   else
      if git ls-remote --heads $2 | grep -qE "$3\$" 
      then
         git clone -b $3 $2 $1
      else
         log_error "Branch \"$3\" does not exist!"
      fi
   fi
}

# === FUNCTION ================================================================
#  NAME: source_git_pull
#  DESCRIPTION: Pull from repositor.
#  PARAMETER 1: destdir
# =============================================================================
source_git_pull ()
{
   if [ $# -lt 1 ]
   then
      log_error "Not enough arguments!"
   fi
   git --git-dir=$1/.git pull
}

# === FUNCTION ================================================================
#  NAME: source_git_get
#  DESCRIPTION: Clone or pull source using git.
#  PARAMETER 1: name
#  PARAMETER 2: url
#  PARAMETER 3: branch (optional)
# =============================================================================
source_git_get () 
{
   if [ $# -lt 2 ]
   then
      log_error "Not enough arguments!"
   fi

   if [ -d $SOURCE/$1 ]
   then
      if git rev-parse --resolve-git-dir $SOURCE/$1/.git > /dev/null
      then
         if [ $3 ] && ! git --git-dir=$SOURCE/$1/.git branch | grep -qE "$3\$"
         then
            echo -e "\nBranch change. Cloning $1 ..."
            rm -rf $SOURCE/$1
            source_git_clone $SOURCE/$1 $2 $3
         else
            echo -e "\nUpdating $1 ..."
            source_git_pull $SOURCE/$1
	 fi
      else
         echo -e "\ngit-dir is not valid. Cloning $1 ..."
         rm -rf $SOURCE/$1
         source_git_clone $SOURCE/$1 $2 $3
      fi
   else
      echo -e "\nCloning $1 ..."
      source_git_clone $SOURCE/$1 $2 $3
   fi
}

# === FUNCTION ================================================================
#  NAME: source_copy
#  DESCRIPTION: Copy from source to build.
#  PARAMETER 1: name
# =============================================================================
source_copy ()
{
   if [ $# -lt 1 ]
   then
      log_error "Not enough arguments!"
   fi
   
   if [ -d $BUILD/$1 ]
   then
      rm -rf $BUILD/$1
   fi
   echo -e "Copying $1 from source to build."
   cp -r $SOURCE/$1 $BUILD/$1
}

# === FUNCTION ================================================================
#  NAME: build_prerequisite_run
#  DESCRIPTION: Run prerequisite before build 
#  PARAMETER 1: name
#  PARAMETER 2: script
#  PARAMETER 3: paramater (optional)
# =============================================================================
build_prerequisite_run()
{
   if [ $# -lt 2 ]
   then
      log_error "Not enough arguments!"
   fi
   echo "Running $2 ..."
   cd $BUILD/$1
   ./$2 $3
}

# === FUNCTION ================================================================
#  NAME: build_configure
#  DESCRIPTION: Run configure 
#  PARAMETER 1: name
#  PARAMETER 2: paramater (optional)
# =============================================================================
build_configure()
{
   if [ $# -lt 1 ]
   then
      log_error "Not enough arguments!"
   fi
   cd $BUILD/$1
   if [ ! -f configure.sh ]
   then
      echo "Running autoreconf..."
      autoreconf -fi &>/dev/null
   fi
   echo "Configuring..."
   saveIFS=$IFS
   IFS=' '
   ./configure $2 --prefix=$INSTALL &>"$LOG/$1.configure.log"
   if [ $? -ne 0 ]
   then
     log_error "Configure error."
   fi
   IFS=$saveIFS
}

# === FUNCTION ================================================================
#  NAME: build_make
#  DESCRIPTION: Run make 
#  PARAMETER 1: name
#  PARAMETER 2: paramater (optional)
#  PARAMETER 3: paramater (optional)
# =============================================================================
build_make()
{
   step="build"
   if [ $# -lt 1 ]
   then
      log_error "Not enough arguments!"
   fi

   if [ -z "$2" ]
   then
      step="install"
   fi

   cd $BUILD/$1

   make -j$JOBS &>"$LOG/$1.log"

   echo $step"..."
 
   if [ -z "$3" ]
   then
      sudo make -j$JOBS $2 &>"$LOG/$1.$step.log"
   else
      make -j$JOBS $2 &>"$LOG/$1.$step.log"
   fi

   if [ $? -ne 0 ]
   then
     log_error "Could not $step."
   fi
}

# === FUNCTION ================================================================
#  NAME: package_parser
#  DESCRIPTION: Parse packages file and declare variables
#  PARAMETER 1: package file
# =============================================================================
package_parser ()
{
   if [ ! -f $1 ]
   then
      log_error "file \"$1\" does not exist."
   fi

   ini="$(<$1)"
   ini="${ini//[/\[}"
   ini="${ini//]/\]}"
   IFS=$'\n' && ini=( ${ini} )
   ini=( ${ini[*]//;*/} )
   ini=( ${ini[*]/\    =/=} )
   ini=( ${ini[*]/=\   /=} )
   ini=( ${ini[*]/\ =\ /=} )
   ini=( ${ini[*]/#\\[/\}$'\n'package.} )
   ini=( ${ini[*]/%\\]/ \(} )
   ini=( ${ini[*]/=/=\( } )
   ini=( ${ini[*]/%/ \)} )
   ini=( ${ini[*]/%\\ \)/ \\} )
   ini=( ${ini[*]/%\( \)/\(\) \{} )
   ini=( ${ini[*]/%\} \)/\}} )
   ini[0]=""
   ini[${#ini[*]} + 1]='}'
   eval "$(echo "${ini[*]}")"
}

# === FUNCTION ================================================================
#  NAME: package_do
#  DESCRIPTION: Fetch, build and install a package
#  PARAMETER 1: Package name
# =============================================================================
package_do ()
{   
   package.$1
   if [ -z "$source" ]
   then
      log_error "Source for $1 is null!"
   fi

   saveIFS=$IFS
   IFS=' '
   source_git_get $1 $source
   IFS=$saveIFS
   source_copy $1

   if [ ! -z "$pre_build" ]
   then
     build_prerequisite_run $1 $pre_build
   fi

   if [ ! -z $depends ] && [[ $depends =~ .*autoconf.* ]]
   then
     build_configure $1 $options
   fi  

   build_make $1

   if [ ! -z "$install" ]
   then
      if [ -z "$sudo_install" ]
      then
         build_make $1 install 1
      else
         rm -rf $INSTALL$install
         build_make $1 install
      fi
   fi
   if [ ! -z "$install" ]
   then
      eval $post_install
   fi
   source=
   depends=
   sudo_install=
   install=
   pre_build=
   options=
   post_install=
}

# ------------------------------------------------------------------------------
# Print directory names
# ------------------------------------------------------------------------------
echo
echo "Base directory is $BASE."
echo "Source directory is $SOURCE."
echo "Build directory is $BUILD."
echo "Install directory is $INSTALL."


# ------------------------------------------------------------------------------
# Create directories
# ------------------------------------------------------------------------------
echo "Create directories."
mkdir -p $SOURCE
mkdir -p $BUILD
mkdir -p $INSTALL
mkdir -p $LOG

package_parser "packages"

package_do "linux-fusion"
package_do "flux"
package_do "directfb"
package_do "ilixi"

exit 0
