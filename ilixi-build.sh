# !/bin/bash
# ===============================================================================
# FILE		: ilxr.sh
# AUTHORS	: A. Erdem Budak <>,
#		  Tarik Sekmen <tarik@ilixi.org>
# DESCRIPTION	: A simple bash script to help install ilixi and its dependencies 
#                 on your system. Visit http://www.ilixi.org for more info.
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

BASE=${PWD}/ilxr
PACKAGE=packages
JOBS=8
PACKAGE_LIST=

# === FUNCTION ================================================================
#  NAME: usage
#  DESCRIPTION: Prints command line options and usage information.
# =============================================================================
usage()
{
cat << EOF
usage: $0 options

OPTIONS:
   -h                    Show this message
   -i <package_file>     Use given package file
   -d <directory>        Destination directory
   -j <#>                Jobs for parallel build, default=$JOBS
EOF
}

# === FUNCTION ================================================================
#  NAME: log_error
#  DESCRIPTION: Log error messages and exit with error.
#  PARAMETERS: Error messages are printed on new lines.
# =============================================================================
log_error ()
{
   echo "(!) ${FUNCNAME[ 1 ]} ()"
   for ln in "$@" ; do
      echo "    -> ${ln}"
   done
   exit 1
}

mk_dir()
{
   if [ $# -lt 1 ]
   then
      log_error "Not enough arguments!"
   fi

   mkdir -p $1
   if [ $? -ne 0 ]
   then
      log_error "Could not create directory!"
   fi
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
      autoreconf -fi &>"$LOG/$1.autoreconf.log"
   fi

   if [ $? -ne 0 ]
   then
     log_error "Autoreconf error." "see $LOG/$1.autoreconf.log"
   fi

   echo "Configuring..."
   saveIFS=$IFS
   IFS=' '
   ./configure $2 --prefix=$INSTALL &>"$LOG/$1.configure.log"

   if [ $? -ne 0 ]
   then
     log_error "Configure error." "see $LOG/$1.configure.log"
   fi
   IFS=$saveIFS
}

# === FUNCTION ================================================================
#  NAME: build_make
#  DESCRIPTION: Run make 
#  PARAMETER 1: name
#  PARAMETER 2: paramater (optional)
# =============================================================================
build_make()
{
   if [ $# -lt 1 ]
   then
      log_error "Not enough arguments!"
   fi

   cd $BUILD/$1

   echo "Building..."
   make -j$JOBS &>"$LOG/$1.build.log"

   if [ $? -ne 0 ]
   then
     log_error "Could not build!" "see $LOG/$1.build.log"
   fi
 
   echo "Installing..."
   if [ -z "$2" ]
   then
      sudo make -j$JOBS install &>"$LOG/$1.install.log"
   else
      make -j$JOBS install &>"$LOG/$1.install.log"
   fi

   if [ $? -ne 0 ]
   then
     log_error "Could not install!" "see $LOG/$1.install.log"
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

   PACKAGE_LIST=`grep "^\[" $1 | sed 's/\[\([^]]*\)\]/\\1/g'`

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

   cd $BASE
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
      echo "Evaluating pre_build"
      eval $pre_build &>"$LOG/$1.prebuild.log"
      if [ $? -ne 0 ]
      then
        log_error "Could evaluate pre_build!" "see $LOG/$1.install.log"
      fi
   fi

   if [ ! -z $depends ] && [[ $depends =~ .*autoconf.* ]]
   then
     build_configure $1 $options
   fi  

   if [ -z "$sudo_install" ]
   then
      build_make $1 1
   else
      build_make $1
   fi

   if [ ! -z "$post_install" ]
   then
      echo "Evaluating post_install"
      eval $post_install &>"$LOG/$1.postinstall.log"
      if [ $? -ne 0 ]
      then
        log_error "Could not evaluate post_install!" "see $LOG/$1.install.log"
      fi
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
# Parse cmd line options
while getopts "hi:d:j:" OPTION
do
   case $OPTION in
      h)
         usage
         exit 1
         ;;
      i)
         PACKAGE=$OPTARG
         ;;
      d)
         BASE=$OPTARG
         ;;
      j)
         JOBS=$OPTARG
         ;;
      :)
         echo "Option -$OPTARG requires an argument."
         exit 1
         ;;
      \?)
         usage
         exit 1
         ;;
   esac
done

if [ ! -f $PACKAGE ]
then
   echo "  Invalid package: $PACKAGE"
   exit 1
fi

if [ ! -d $BASE ]
then
   mk_dir $BASE
fi

# Print info
echo -e "ilxr v0.1\n"
echo "Packgage file: $PACKAGE"
echo "Jobs: $JOBS"
echo -e "Base directory: $BASE\n"

SOURCE=$BASE/source
BUILD=$BASE/build
LOG=$BASE/log
INSTALL=$BASE/install

# Purge $INSTALL
if [ -d $INSTALL ]
then
   echo "Purging install directories from last build."
   rm -rf $INSTALL
fi

# Create directories
echo "Creating directories."
mk_dir $SOURCE
mk_dir $BUILD
mk_dir $INSTALL
mk_dir $LOG

export PKG_CONFIG_PATH="$INSTALL/lib/pkgconfig/"
export PATH="$INSTALL/bin:$PATH"

package_parser $PACKAGE

for package in $PACKAGE_LIST
   do package_do "$package" # :)
done

echo -e "done.\n"

exit 0
