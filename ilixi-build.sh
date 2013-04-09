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
#  NAME: git_source
#  DESCRIPTION: Clone or update source for given git repository
#  PARAMETER 1: name
#  PARAMETER 2: url
# =============================================================================
git_source () 
{

   local GIT_SOURCE=$SOURCE/$1

   echo
   echo "Fetching $1."
   echo "Check if $1 source is available."
   if [ -d $GIT_SOURCE ]
   then
      echo "$1 source found."
      echo "Check if $1 source has a valid git-dir."
      if [ $( git rev-parse --resolve-git-dir $GIT_SOURCE/.git ) ]
      then
         echo "git-dir is valid. executing git fetch and merge."
         git --git-dir= $GIT_SOURCE/.git fetch
         git --git-dir=$GIT_SOURCE/.git --work-tree=$GIT_SOURCE merge origin/master
      else
         echo "git-dir is not valid. executing rm -rf and git clone."
         rm -rf $GIT_SOURCE
         git clone $2 $GIT_SOURCE
      fi
   else
      echo "$1 source not found. executing git clone."
      git clone $2 $GIT_SOURCE
   fi

}

#-------------------------------------------------------------------------------
# Get source
#-------------------------------------------------------------------------------
git_source "linux-fusion" "git://git.directfb.org/git/directfb/core/linux-fusion.git"
git_source "flex" "git://git.directfb.org/git/directfb/core/flux.git"
git_source "directfb" "git://git.directfb.org/git/directfb/core/DirectFB.git"
