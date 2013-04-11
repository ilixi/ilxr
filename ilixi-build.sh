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
INSTALL=$BASE/install

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
      echo "Not enough arguments!"
      exit 1
   fi

   if [ $# -eq 2 ]
   then            
      git clone $2 $1
   else
      if ! git ls-remote --heads $2 | grep -qE "$3 \$"
      then
         git clone -b $3 $2 $1
      else
         echo "Error: Branch \"$3\" does not exist!"
         exit 1
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
      echo "Not enough arguments!"
      exit 1
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
      echo "Not enough arguments!"
      exit 1
   fi

   if [ -d $SOURCE/$1 ]
   then
      if [ $( git rev-parse --resolve-git-dir $SOURCE/$1/.git ) ]
      then
         if [ $3 ] && ! git --git-dir=$SOURCE/$1/.git branch | grep -qE "^\* $3\$"
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
      echo "Not enough arguments!"
      exit 1
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
      echo "Not enough arguments!"
      exit 1
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
      echo "Not enough arguments!"
      exit 1
   fi
   echo "Configure $1 ..."
   cd $BUILD/$1
   ./configure $2
}

# === FUNCTION ================================================================
#  NAME: buildi_make
#  DESCRIPTION: Run make 
#  PARAMETER 1: name
#  PARAMETER 2: paramater (optional)
# =============================================================================
build_make()
{
   if [ $# -lt 1 ]
   then
      echo "Not enough arguments!"
      exit 1
   fi
   echo "Make $1 ..."
   cd $BUILD/$1
   make $2
}


# ------------------------------------------------------------------------------
# Get source
# ------------------------------------------------------------------------------
source_git_get "linux-fusion" "git://git.directfb.org/git/directfb/core/linux-fusion.git"
source_git_get "flux" "git://git.directfb.org/git/directfb/core/flux.git"
source_git_get "directfb" "git://git.directfb.org/git/directfb/core/DirectFB.git" "directfb-1.6"
source_git_get "ilixi" "git://git.directfb.org/git/directfb/libs/ilixi.git"

# ------------------------------------------------------------------------------
# Copy source to build
# ------------------------------------------------------------------------------
echo -e "\nCopying sources..."
source_copy "linux-fusion"
source_copy "flux"
source_copy "directfb"
source_copy "ilixi"

# ------------------------------------------------------------------------------
# Clean install
# ------------------------------------------------------------------------------
echo -e "\nClean install ..."
rm -Rf $INSTALL/*.*

# ------------------------------------------------------------------------------
# Build flux
# ------------------------------------------------------------------------------
echo -e "\nBuilding flux ..."
build_prerequisite_run flux autogen.sh
build_configure flux --prefix=$INSTALL
build_make flux
build_make flux install

# ------------------------------------------------------------------------------
# Build directfb
# ------------------------------------------------------------------------------
echo -e "\nBuilding directfb ..."
(
export FLUXCOMP=$INSTALL/bin/fluxcomp
build_prerequisite_run directfb autogen.sh $( --enable-multi --enable-one --enable-network --enable-sawman --enable-fusionsound --enable-fusiondale --prefix=$INSTALL )
build_make directfb
)
build_make directfb install

exit 0
