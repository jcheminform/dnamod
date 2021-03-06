#!/usr/bin/env bash
set -o nounset -o pipefail -o errexit

# Internal Hoffman Lab script, used to synchronize and push the website.
#
# -------------------------------------------------------------------------------
# Copyright (C) 2016  Coby Viner
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# -------------------------------------------------------------------------------

ERR_EXIT=64

# Copy contents of the site's HTML files into the directory for the live site, updating the repo.

if [[ ! ($(hostname) =~ 'mordor' && -n $(groups | fgrep 'hoffmangroup')) ]]; then
    >&2 echo "Must be run on the Hoffman Lab cluster, by a lab member."
    exit $ERR_EXIT
fi

SOURCE_DIR="$(dirname $(readlink -f $0))" # From: https://gist.github.com/tvlooy/cbfbdb111a4ebad8b93e
CONSTANTS_SCRIPT="$SOURCE_DIR/../constants.sh"

# Testing mode: If this is set to true the site will be copied into a test folder in ~/DNA_Base_Database/DNA_mod_site
TESTING_MODE=false

internal_only=${1:-false}

MAIN_SITE_DIR="$($CONSTANTS_SCRIPT 'site_html_dir')"

# push to the internal www directory, to copy over to the external

# Path variables for testing mode and real mode
TEST_PATH="$($CONSTANTS_SCRIPT 'root_dir')/sync_test"

# NB: system-specific, so not stored within the constants file
#     only used within this particular script
REAL_PATH='/mnt/work1/users/hoffmangroup/www/proj/dnamod'

EXTERNAL_PATH='/mnt/work1/users/hoffmangroup/www-external/proj/dnamod'

REPO_SSH_PATH='ssh://hg@bitbucket.org/hoffmanlab/www-external'

# array of additional files to sync
ADDTL_FILES=($($CONSTANTS_SCRIPT 'database'))

if [[ "$TESTING_MODE" == true ]]; then
    rm -Rf "$TEST_PATH"
    COPY_PATH="$TEST_PATH"    
    mkdir "$COPY_PATH"
else
    COPY_PATH="$REAL_PATH"
fi

>&2 echo "Fixing permissions and copying to www directory."

chmod -Rv g+rwX,a+rX "$MAIN_SITE_DIR/.." "${ADDTL_FILES[@]}"
rsync --progress -av --delete "$MAIN_SITE_DIR"/* "${ADDTL_FILES[@]}" "$COPY_PATH" || true

# push the actual site to the external directory
if [[ "$TESTING_MODE" == false && "$internal_only" == false ]]; then
# if tracked files were changed, commit the changes to the lab Bitbucket
    if [[ -n "$(cd $REAL_PATH && hg diff)" ]]; then
        >&2 echo "Committing and pushing changes."
        (cd "$REAL_PATH" && hg pull "$REPO_SSH_PATH" && hg update && hg commit --config extensions.hgspellcheck=! -m "Updated DNAmod. Consult its repository ($(cd $SOURCE_DIR && echo $(hg paths default) | sed -r 's|ssh://.*?@|https://|')) for details." . && hg push "$REPO_SSH_PATH")
    fi

    >&2 echo "Pushing to www-external."
    rsync --progress -av --delete "$REAL_PATH"/* "$EXTERNAL_PATH" || true

    >&2 echo -e "\n\nEmail Qun Jin <qjin@uhnresearch.ca> to push the public webpage.\n"
fi

