# !/bin/bash
# ===============================================================================
# FILE		: ilxr.sh
# AUTHORS	: A. Erdem Budak <ebudak@rhun.net>,
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

# === FUNCTION ================================================================
#  NAME: mk_dir
#  DESCRIPTION: Create directory
#  PARAMETER1 : destdir
# =============================================================================
mk_dir ()
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
#  NAME: check_deps
#  DESCRIPTION: Checks if given package(s) is installed, if not installs it
#               using package manager.
#  PARAMETER1 : space seperated list of packages
# =============================================================================
check_deps ()
{
   echo "Checking for dependencies..."
   saveIFS=$IFS
   IFS=' '  
   for package in $1; do
      local package_version=$(dpkg-query -W -f='${Version}' $package)
      if [ -z $package_version ]
      then
         echo "Installing $package..."
         sudo apt-get --force-yes --yes install $package &>/dev/null
         if [ $? -ne 0 ]
         then
            log_error "Could not install $package!"
         fi
      else
         echo "$package is installed (version $package_version)"
      fi
   done
   IFS=$saveIFS
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

   if [ -d $DL/git/$1 ]
   then
      if git rev-parse --resolve-git-dir $DL/git/$1/.git > /dev/null
      then
         if [ $3 ] && ! git --git-dir=$DL/git/$1/.git branch | grep -qE "$3\$"
         then
            echo -e "\nBranch change. Cloning $1 ..."
            rm -rf $DL/git/$1
            source_git_clone $DL/git/$1 $2 $3
         else
            echo -e "\nUpdating $1 ..."
            git --git-dir=$DL/git/$1/.git pull
	 fi
      else
         echo -e "\ngit-dir is not valid. Cloning $1 ..."
         rm -rf $DL/git/$1
         source_git_clone $DL/git/$1 $2 $3
      fi
   else
      echo -e "\nCloning $1 ..."
      source_git_clone $DL/git/$1 $2 $3
   fi
}

# === FUNCTION ================================================================
#  NAME: source_http_get
#  DESCRIPTION: Get source using http.
#  PARAMETER 1: name
#  PARAMETER 2: url
#  PARAMETER 3: filename
# =============================================================================
source_http_get () 
{
   if [ $# -lt 2 ]
   then
      log_error "Not enough arguments!"
   fi

   echo -e "\nDownloading $1 ..."

   if [ ! -d $DL/$1 ]
   then
      mkdir -p $DL/$1
   fi

   if [ ! -f $DL/$1/$3 ]
   then
      curl -o $DL/$1/$3 $2
   fi
}

# === FUNCTION ================================================================
#  NAME: source_copy
#  DESCRIPTION: Copy from source to build.
#  PARAMETER 1: name
#  PARAMETER 2: sourcedir
# =============================================================================
source_copy ()
{
   if [ $# -lt 1 ]
   then
      log_error "Not enough arguments!"
   fi
   
   if [ -d $WS/$1 ]
   then
      rm -rf $WS/$1
   fi
   echo -e "Copying $1 from source to build."
   cp -r $2 $WS/$1 &>"$LOG/$1.copy.log"
}

# === FUNCTION ================================================================
#  NAME: source_extract
#  DESCRIPTION: Extract from source to build.
#  PARAMETER 1: name
#  PARAMETER 2: filename
# =============================================================================
source_extract ()
{
   if [ $# -lt 2 ]
   then
      log_error "Not enough arguments!"
   fi
   
   if [ -d $WS/$1 ]
   then
      rm -rf $WS/$1
   fi
   mkdir -p $WS/$1

   echo -e "Extracting $1/$2 to build."
   if [[ $2 == *.tar ]]
   then
      tar --directory=$WS/$1 --strip 1 -xf $DL/$1/$2 &>"$LOG/$1.extract.log"
   elif [[ $2 == *.tar.gz ]]
   then
      tar --directory=$WS/$1 --strip 1 -zxf $DL/$1/$2 &>"$LOG/$1.extract.log"
   elif [[ $2 == *.tar.bz2 ]]
   then
      tar --directory=$WS/$1 --strip 1 -jxf $DL/$1/$2 &>"$LOG/$1.extract.log"
   else
      echo "unknown file"
   fi
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
   cd $WS/$1

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

   cd $WS/$1

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
   source=
   autoconf=
   depends=
   sudo_install=
   pre_build=
   options=
   post_install=

   cd $BASE
   package.$1
   if [ -z "$source" ]
   then
      log_error "Source for $1 is null!"
   fi

   saveIFS=$IFS
   IFS=' '  

   if [[ $source == *.git* ]]
   then
      source_git_get $1 $source
      source_copy $1 $DL/git/$1
   else
      AFTER_SLASH=${source##*/}
      filename=${AFTER_SLASH%%\?*}
      source_http_get $1 $source $filename
      source_extract $1 $filename
   fi
   IFS=$saveIFS

   check_deps $depends

   if [ ! -z "$pre_build" ]
   then
      echo "Evaluating pre_build"
      eval $pre_build &>"$LOG/$1.prebuild.log"
      if [ $? -ne 0 ]
      then
        log_error "Could evaluate pre_build!" "see $LOG/$1.install.log"
      fi
   fi

   if [ ! -z $autoconf ] && [ $autoconf = "yes" ]
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

DL=$BASE/dl
WS=$BASE/build
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
mk_dir $DL
mk_dir $DL/git
mk_dir $WS
mk_dir $INSTALL
mk_dir $LOG

export PKG_CONFIG_PATH="$INSTALL/lib/pkgconfig/"
export PATH="$INSTALL/bin:$PATH"

package_parser $PACKAGE

for package in $PACKAGE_LIST
   do if [ "$package" == "dependencies" ]
   then
      package.dependencies
      check_deps $depends
   else
      package_do "$package"
   fi
done

echo -e "\ndone.\n"
exit 0
