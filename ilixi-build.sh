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

#-------------------------------------------------------------------------------
# Print directory names
#-------------------------------------------------------------------------------
echo
echo "Base directory is $BASE."
echo "Source directory is $SOURCE."
echo "Build directory is $BUILD."
echo "Install directory is $INSTALL."


#-------------------------------------------------------------------------------
# Create directories
#-------------------------------------------------------------------------------
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
      local br=$(git ls-remote --heads $2 | grep $3)
      if [[ "${br}" != "" ]]
      then
         git clone -b $3 $2 $1
      else
         echo "Error: Branch \"$3\" does not exist!"
         exit 1
      fi
   fi

}

# === FUNCTION ================================================================
#  NAME: source_fetch_git
#  DESCRIPTION: Fetch source using git.
#  PARAMETER 1: name
#  PARAMETER 2: url
#  PARAMETER 3: branch (optional)
# =============================================================================
source_fetch_git () 
{

   if [ $# -lt 2 ]
   then
      echo "Not enough arguments!"
      exit 1
   fi

   local GIT_SOURCE=$SOURCE/$1

   echo -e "\nFetching $1."
   if [ -d $GIT_SOURCE ]
   then
      if [ $( git rev-parse --resolve-git-dir $GIT_SOURCE/.git ) ]
      then
         echo "updating..."
         git --git-dir=$GIT_SOURCE/.git --work-tree=$GIT_SOURCE pull
      else
         echo "git-dir is not valid."
         rm -rf $GIT_SOURCE
         source_git_clone $GIT_SOURCE $2 $3
      fi
   else
      source_git_clone $GIT_SOURCE $2 $3
   fi

}

#-------------------------------------------------------------------------------
# Get source
#-------------------------------------------------------------------------------
source_fetch_git "linux-fusion" "git://git.directfb.org/git/directfb/core/linux-fusion.git"
source_fetch_git "flux" "git://git.directfb.org/git/directfb/core/flux.git"
source_fetch_git "directfb" "git://git.directfb.org/git/directfb/core/DirectFB.git" "directfb-1.6"
source_fetch_git "ilixi" "git://git.directfb.org/git/directfb/libs/ilixi.git"

exit 0
