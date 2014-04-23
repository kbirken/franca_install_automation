#!/bin/sh
# (C) Gunnar Andersson
# License: CC0 for now.
# (Might convert final version to CC-BY or similar)

# Set to "false" or "true" for debug printouts
DEBUG=false


debug() {
   $DEBUG && {
      1>&2 echo $@ | sed 's/^/*DEBUG*: /'
   }
}

die() {
   echo "Something went wrong.  Message: "
   echo "$1"
   exit 1
}

# Set $VAGRANT non-empty if we are running under vagrant provisioning
test_vagrant() {
   VAGRANT=""
   echo "$0" | fgrep -q "vagrant-shell" && VAGRANT="yes"
}

# Run command only if Vagrant environment
if_vagrant() {
   [ -n "$VAGRANT" ] && eval $@
}

# Run command only if NOT Vagrant environment
unless_vagrant() {
   [ -z "$VAGRANT" ] && $@
}

step() {
      echo $@ | sed 's/^/ *** /'
}

ensure() {
   $* || die "Condition not met: $*"
}

defined() {
   debug "Checking: $@"
   for f in $@ ; do
      [ -n "$f" ] || "Variable $f not defined in CONFIG?"
   done
}

warn() {
   echo "WARNING: $1"
   echo Hit return to continue
   unless_vagrant read
}

sanity_check_filename() {
   [ -z "$1" ] && die "Filename empty."
}

deref() {
   # A kind of weird hack, but it evaluates the variable
   # whose name is defined by the input variable.
   # e.g. x=foo ; deref x returns the value of $foo!
   debug "dereffing $1"
   eval echo \$$1
}

download() {
   outfile=$(basename "$1")
   sanity_check_filename "$outfile"
   wget "$1" -O "$outfile" -c --no-check-certificate || die "wget failed.  Is wget installed?"
#   curl -C - -O "$1" -O "$outfile" || die "curl failed.  Is curl installed?"
   downloaded_file=$outfile
}

untar() {
   ensure [ -f "$1" ]
   targetdir="$2"
   # Use current directory as default targetdir if not specified
   [ -n "$targetdir" ] && targetdir=.
   tar xf "$1" -C "$2" || die "untar failed for $1"
}

md5_check() {
   item=$1
   file=$2

   wanted_md5=$(deref ${item}_MD5)
   debug "Checking MD5 $wanted_md5 for $item"

   # As long as <item>_MD5 is a non-empty string, perform the check
   if [ -n "$wanted_md5" ] ; then
      md5=$(md5sum <"$file" | cut -b 1-32)
      if [ "$md5" != "$wanted_md5" ]  ; then
         die "MD5 checksum ($md5) did not match predefined md5 ($wanted_md5) for item $item.  Check CONFIG file."
      else
         debug "MD5 ok ($item)"
      fi
   fi
}

# Check hash on update site such that an update is noticed
# (warning only)
check_site_hash() {
   url=$(deref ${1}_UPDATE_SERVER)
   hash=$(deref ${1}_UPDATE_SITE_HASH)
   debug "checking update site hash: $hash"
   curl -s "$url/" | grep -q "$hash" || warn "Site hash ($hash) not found on update site.  Probably it has been updated."
}

check_site_latest_version() {
   url=$(deref ${1}_UPDATE_SERVER)
   version=$(deref ${1}_VERSION)
   $DEBUG && {
      echo DEBUG: All versions:
      curl -s "$url/" | egrep '[0-9]\.[0-9]\.[0-9]' | sed 's/^/DEBUG: /'
   }
   latest=$(curl -s "$url/" | egrep '[0-9]\.[0-9]\.[0-9]' | sed 's/.*\([0-9]\.[0-9]\.[0-9]\).*/\1/' | sort -n | tail -1)
   debug "latest: $latest"
   if [ "$latest" != "$version" ] ; then
      warn "There appears to be a later version than $version for $1"
   fi
}

install_update_site() {
   # http://stackoverflow.com/questions/7163970/how-do-you-automate-the-installation-of-eclipse-plugins-with-command-line
   # http://help.eclipse.org/indigo/index.jsp?topic=%2Forg.eclipse.platform.doc.user%2Ftasks%2Frunning_eclipse.htm
   # http://help.eclipse.org/helios/index.jsp?topic=/org.eclipse.platform.doc.isv/guide/p2_director.html
   site=$(deref ${1}_UPDATE_SITE_URL)
   features=$(deref ${1}_FEATURES)

   debug "Installing from update site $1"

   $DEBUG && set -x
   $INSTALL_DIR/eclipse/eclipse -nosplash \
      -application org.eclipse.equinox.p2.director \
      -repository "$site" \
      -destination $INSTALL_DIR/eclipse \
      -installIU "$features"
   set +x
}

MYDIR=$(dirname "$0")
ORIGDIR="$PWD"

# Special case for vagrant. We know script is in /vagrant, and $0 is also the name of the shell instead of the script
test_vagrant
if_vagrant echo Using vagrant : $0
if_vagrant MYDIR=/vagrant

cd "$MYDIR"

# Check config contents...
. ./CONFIG
defined ECLIPSE_INSTALLER INSTALL_DIR DOWNLOAD_DIR DBUS_EMF_UPDATE_SITE_URL GEF4_UPDATE_SITE_URL FRANCA_ARCHIVE_URL

# Special case for vagrant
if_vagrant DOWNLOAD_DIR=/vagrant

mkdir -p "$INSTALL_DIR" || die "Can't create target dir ($INSTALL_DIR)"
if [ -d "$WORKSPACE_DIR" ] ; then
   echo
   echo "NOTE the workspace dir in CONFIG exists ($WORKSPACE_DIR)!"
   echo "I will unpack files into $WORKSPACE_DIR !"
   warn "Remove it to make a clean installation or back up your files!"
else
   mkdir -p "$WORKSPACE_DIR"
fi

# Get Eclipse archive
cd "$DOWNLOAD_DIR"
step "Downloading Eclipse installer"
download "$ECLIPSE_INSTALLER"  # This sets a variable named $downloaded_file

# File exists?, correct MD5?, and then unpack
[ -f "$downloaded_file" ] || die "ECLIPSE not found (not downloaded)."
step Checking MD5 sum for Eclipse
md5_check ECLIPSE "$downloaded_file"
untar "$downloaded_file" "$INSTALL_DIR"

step "Installing DBus EMF model from update site"
check_site_hash           DBUS_EMF
check_site_latest_version DBUS_EMF
install_update_site       DBUS_EMF

step "Installing GEF4 from update site"
install_update_site       GEF4

step "Downloading Franca update site archive (.zip)"
download "$FRANCA_ARCHIVE_URL" "$FRANCA_ARCHIVE"
md5_check FRANCA_ARCHIVE "$downloaded_file"

# I can't get install directly from zip file to work
# (using command line invocation --installIU) -- is it supposed to?
#
# For now unpacking contents first instead, because it works...

step Unpacking Franca update site archive
UNPACKDIR=$DOWNLOAD_DIR/tmp.$$
mkdir -p "$UNPACKDIR"            || die "mkdir UNPACKDIR ($UNPACKDIR) failed"
cd "$UNPACKDIR"                  || die "cd to UNPACKDIR ($UNPACKDIR) failed"
unzip -q "$DOWNLOAD_DIR/$downloaded_file" || die "unzip $DOWNLOAD_DIR/$downloaded_file failed"
cd -

FRANCA_UPDATE_SITE_URL="file://$UNPACKDIR"
step Installing Franca
install_update_site FRANCA

step Downloading Franca examples
cd "$WORKSPACE_DIR"                    || die "cd to WORKSPACE_DIR ($WORKSPACE_DIR) failed"
download "$EXAMPLES_URL"
EXAMPLES_FILE="$downloaded_file"

cat <<MSG

Instructions:
-------------
The examples are now in your workspace _directory_ but not yet known to your
project browser.  When you have started eclipse, go to Workspace, then select
   File -> Import.
   Select the "General" category (folder)
      and then "Import existing project"
   Then select option Archive
   and select the zip file containing $EXAMPLES_FILE
   Hit OK to import/copy into workspace

   Finally you may run the tests by going into "tests"/"src", right click
   and select Run As "JUnit Test".

   But from now on you should read the Franca documentation for more instructions
MSG

echo
echo You may now start eclipse by running: $INSTALL_DIR/eclipse/eclipse

if_vagrant chown -R vagrant:users "$INSTALL_DIR"
if_vagrant echo "fixed-chmod" > "$INSTALL_DIR/fixed-chmod"
