#!/bin/bash
# ===============================================================================
# FILE		  : ilxr.sh
# AUTHORS	  : A. Erdem Budak <erdem@ilixi.org>,
#               Tarik Sekmen <tarik@ilixi.org>.
# DESCRIPTION : A simple bash script to help install ilixi and its dependencies 
#               on Ubuntu/Debian. Visit http://www.ilixi.org for more info.
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

CURRENT=${PWD}
BASE=${CURRENT}/ilxr
RECIPE_DIR=${CURRENT}/data/default
PATCH_DIR=${CURRENT}/data/patch
PACKAGE=slim-latest.ilxr
JOBS=8
PACKAGE_LIST=

# === COLORS ==================================================================
red='\e[0;91m'
green='\e[0;92m'
yellow='\e[0;93m'
clear='\e[0m'
bold='\e[1m'
# =============================================================================


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
   -r <directory>        Directory where recipes reside.
   -p <package_file>     Use given package file in recipe directory
   -d <directory>        Directory to use for downloading and building packages
   -o <directory>        Installation directory
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
   echo -e "${red}(!) ${FUNCNAME[ 1 ]}()"
   for ln in "$@" ; do
      echo "    -> ${ln}"
   done
   echo -e "${clear}"
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
   if [ $# -lt 1 ]
   then
      log_error "Not enough arguments!"
   fi

   echo "Checking for dependencies..."
   saveIFS=$IFS
   IFS=' '  
   for package in $1; do
      local package_version
      package_version=$(apt-cache policy $package | grep '  Candidate: ' | sed -e 's/  Candidate: //')
      apt-cache policy $package | grep -q 'Installed: (none)'
      if [ $? -eq 0 ]
      then
         if [ -z $package_version ]
         then
            echo "   apt-cache policy could not find $package. check your sources.list"
            exit 1
         else
            echo "   Installing $package... (version $package_version)"
            sudo apt-get --force-yes --yes install $package &>/dev/null
            if [ $? -ne 0 ]
            then
               log_error "Could not install $package!"
            fi
         fi
      else
         echo "   $package is installed (version $package_version)"
      fi
   done
   IFS=$saveIFS
}

# === FUNCTION ================================================================
#  NAME: copy_files
#  DESCRIPTION: Copies files.
#  PARAMETER1 : space seperated list of files.
# =============================================================================
copy_files ()
{
   if [ $# -lt 1 ]
   then
      log_error "Not enough arguments!"
   fi

   echo "Copying files..."
   saveIFS=$IFS
   IFS=' '
   local index
   local src
   local target
   for file in $1; do
      index=`expr index "$file" :`
      src=${file:0:$index-1}
      target=${file:$index}
      cp -ruv "$RECIPE_DIR/$src" "$target"
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

   echo -e "\nDownloading $1..."

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
#  DESCRIPTION: Copy from source to ws.
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
   echo "Copying $1 from source to ws..."
   cp -r $2 $WS/$1 &>"$LOG/$1.copy.log"
}

# === FUNCTION ================================================================
#  NAME: source_extract
#  DESCRIPTION: Extract from source to ws.
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

   echo "Extracting $1/$2 to ws..."
   if [[ $2 == *.tar ]]
   then
      tar --directory=$WS/$1 --strip 1 -xf $DL/$1/$2 &>"$LOG/$1.extract.log"
   elif [[ $2 == *.tar.gz ]]
   then
      tar --directory=$WS/$1 --strip 1 -zxf $DL/$1/$2 &>"$LOG/$1.extract.log"
   elif [[ $2 == *.tar.bz2 ]]
   then
      tar --directory=$WS/$1 --strip 1 -jxf $DL/$1/$2 &>"$LOG/$1.extract.log"
   elif [[ $2 == *.tar.xz ]]
   then
      tar --directory=$WS/$1 --strip 1 -xJf $DL/$1/$2 &>"$LOG/$1.extract.log"
   else
      echo "unknown file"
   fi
}

# === FUNCTION ================================================================
#  NAME: source_patch
#  DESCRIPTION: Patch source files.
#  PARAMETER 1: name
#  PARAMETER 2: filenames separated by space
# =============================================================================
source_patch ()
{
   if [ $# -lt 2 ]
   then
      log_error "Not enough arguments!"
   fi
   printf "Applying patches\t\t"
   cd $WS/$1
   
   saveIFS=$IFS
   IFS=" "

   for p in $2
   do
      echo "   $p"
      if [ -f $PATCH_DIR/$1/$p ];
      then
         patch -p1 < $PATCH_DIR/$1/$p &>"$LOG/$1.patch.$p.log"
         if [ $? -ne 0 ]
         then
            log_error "Patch error." "see $LOG/$1.patch.$p.log"
         fi
      else
         echo "Patch file $PATCH_DIR/$1/$p does not exist."
      fi
   done
   echo -e "${green} [done]${clear}"
   IFS=$saveIFS
}

# === FUNCTION ================================================================
#  NAME: build_cmake
#  DESCRIPTION: Runs cmake with given options.
#  PARAMETER 1: name
#  PARAMETER 2: list of parameters 
# =============================================================================
build_cmake ()
{
   if [ $# -lt 2 ]
   then
      log_error "Not enough arguments!"
   fi
   printf "Running cmake\t\t"
   cd $WS/$1
   
   saveIFS=$IFS
   IFS=' '
   cmake -DCMAKE_INSTALL_PREFIX=$INSTALL $2 &>"$LOG/$1.cmake.log"

   if [ $? -ne 0 ]
   then
     log_error "Cmake error." "see $LOG/$1.cmake.log"
   fi
   echo -e "${green} [done]${clear}"
   IFS=$saveIFS
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
      printf "Running autoreconf\t\t"
      autoreconf -fi &>"$LOG/$1.autoreconf.log"
   fi

   if [ $? -ne 0 ]
   then
     log_error "Autoreconf error." "see $LOG/$1.autoreconf.log"
   fi
   echo -e "${green} [done]${clear}"

   printf "Configuring\t\t\t"
   saveIFS=$IFS
   IFS=' '
   ./configure $2 --prefix=$INSTALL &>"$LOG/$1.configure.log"

   if [ $? -ne 0 ]
   then
     log_error "Configure error." "see $LOG/$1.configure.log"
   fi
   echo -e "${green} [done]${clear}"
   IFS=$saveIFS
}

# === FUNCTION ================================================================
#  NAME: build_make
#  DESCRIPTION: Run make 
#  PARAMETER 1: name
#  PARAMETER 2: if set, install using sudo (optional)
# =============================================================================
build_make()
{
   if [ $# -lt 1 ]
   then
      log_error "Not enough arguments!"
   fi

   cd $WS/$1

   printf "Building\t\t\t"
   make -j$JOBS &>"$LOG/$1.build.log"
   echo -e "${green} [done]${clear}"

   if [ $? -ne 0 ]
   then
     log_error "Could not build!" "see $LOG/$1.build.log"
   fi
 
   if [ -z "$2" ]
   then
      echo "(*) $1 requires sudo install"
      sudo checkinstall  --pkgname "$1" --pkgversion $package_version --default &>"$LOG/$1.install.log" --fstrans=no
      sudo chown -R $USER:$(groups | awk '{print $1}') $WS/$1
      printf "Installing\t\t\t"
   else
      printf "Installing\t\t\t"
      make -j$JOBS install &>"$LOG/$1.install.log"
   fi

   if [ $? -ne 0 ]
   then
     log_error "Could not install!" "see $LOG/$1.install.log"
   fi
   echo -e "${green} [done]${clear}"
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
   files=
   depends=
   sudo_install=
   package_version=
   pre_build=
   patch=
   autoconf_options=
   cmake_options=
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
      package_version=git.$(git --git-dir=$DL/git/$1/.git rev-parse HEAD)
      source_copy $1 $DL/git/$1
   else
      AFTER_SLASH=${source##*/}
      filename=${AFTER_SLASH%%\?*}
      source_http_get $1 $source $filename
      source_extract $1 $filename
   fi
   IFS=$saveIFS

   if [ ! -z "$depends" ]
   then
      check_deps $depends
   fi

   if [ ! -z "$pre_build" ]
   then
      saveIFS=$IFS
      IFS=':\'
      printf "Evaluating pre_build...\t" > "$LOG/$1.prebuild.log"
      for cmd in $pre_build
      do
         echo $cmd >>"$LOG/$1.prebuild.log"
         eval "sh $RECIPE_DIR/$cmd" >>"$LOG/$1.prebuild.log" 2>&1
         if [ $? -ne 0 ]
         then
           log_error "Could not evaluate: $cmd!" "see $LOG/$1.prebuild.log"
         fi
      done
      echo -e "${green} [done]${clear}"
      IFS=$saveIFS
   fi

   if [ ! -z "$patch" ]
   then
     source_patch $1 $patch
   fi  
   
   if [ ! -z $autoconf ] && [ $autoconf = "yes" ]
   then
     build_configure $1 $autoconf_options
   elif [ ! -z $cmake_options ]
   then
     build_cmake $1 $cmake_options
   fi

   if [ -z "$sudo_install" ]
   then
      build_make $1 1
   else
      build_make $1
   fi

   if [ ! -z "$post_install" ]
   then
      saveIFS=$IFS
      IFS=':\'
      printf "Evaluating post_install...\t" > "$LOG/$1.postinstall.log"
      for cmd in $post_install
      do
         echo $cmd >>"$LOG/$1.postinstall.log"
         eval "sh $RECIPE_DIR/$cmd" >>"$LOG/$1.postinstall.log" 2>&1
         if [ $? -ne 0 ]
         then
           log_error "Could not evaluate: $cmd!" "see $LOG/$1.postinstall.log"
         fi
      done
      echo -e "${green} [done]${clear}"
      IFS=$saveIFS
   fi

   if [ ! -z "$files" ]
   then
      copy_files $files
   fi
}

# ------------------------------------------------------------------------------
DISTRO=$(lsb_release -i | grep 'buntu\|ebian')
if [ -z "$DISTRO" ]
then
   log_error "Distro is not supported."
fi

INSTALL=
# Parse cmd line options
while getopts "hi:p:o:d:j:" OPTION
do
   case $OPTION in
      h)
         usage
         exit 1
         ;;
      r)
         RECIPE_DIR=$OPTARG
         ;;
      p)
         PACKAGE=$OPTARG
         ;;
      o)
         INSTALL=$OPTARG
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

if [ ! -f "$RECIPE_DIR/$PACKAGE" ]
then
   echo "  Invalid package: $RECIPE_DIR/$PACKAGE"
   exit 1
fi

if [ ${PACKAGE:${#PACKAGE}-5:5} != ".ilxr" ]
then
   echo "  Invalid package extension: $RECIPE_DIR/$PACKAGE"
   exit 1
fi

if [ ! -d $BASE ]
then
   mk_dir $BASE
fi

DL=$BASE/dl
WS=$BASE/ws
LOG=$BASE/log/${PACKAGE:0:${#PACKAGE}-5}

if [ -z $INSTALL ]
then
   INSTALL=$BASE/${PACKAGE:0:${#PACKAGE}-5}
fi

# Print info
echo -e "\n${yellow}--------------------- ilxr v0.3 ---------------------${clear}\n"
echo -e "${bold}Recipe directory:${clear} $RECIPE_DIR"
echo -e "${bold}Recipe file:${clear} $PACKAGE"
echo -e "${bold}Jobs:${clear} $JOBS"
echo -e "${bold}Base directory:${clear} $BASE"
echo -e "${bold}Install directory:${clear} $INSTALL\n"

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

package_parser "$RECIPE_DIR/$PACKAGE"
for package in $PACKAGE_LIST
   do if [ "$package" == "dependencies" ]
   then
      package.dependencies
      if [ ! -z "$depends" ]
      then
         check_deps $depends
      fi
   else
      package_do "$package"
   fi
done

echo -e "\n${yellow}----------------------- done! -----------------------${clear}\n"
echo -e "You can export following and start using installed packages:\n"
echo "   export LD_LIBRARY_PATH=$INSTALL/lib/:\$LD_LIBRARY_PATH"
echo "   export PKG_CONFIG_PATH=$INSTALL/lib/pkgconfig/"
echo -e "   export PATH=$INSTALL/bin:\$PATH\n"
exit 0
