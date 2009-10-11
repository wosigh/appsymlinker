#!/bin/sh

# This code is open for re-use with no restrictions.  xorg
# This is a working proof of concept script still in development.
# Intent is for someone to port to a webOS app.
# Use at your own risk.

#-------------------------------------------------------------------------#
# versions:
# 0.1.0 - original (xorg)
# 0.1.1 - added unlink and clean functions (daventx)
# 0.1.2 - added bulkmv function, allows moving many apps (xorg)
# 0.1.3 - added option for tar backups (xorg)
# 0.1.4 - added listmoved function to show apps already moved (xorg)
# 0.1.5 - added restoreall function, couple cleanup items (xorg)
# 0.1.6 - fixed to show usage if no appname supplied to link/unlink (xorg)
# 0.1.7 - added cleanexit (w/mount ro /)
#       - added exit code documentation for javascripts calling this (xorg)
# 0.2.0 - will not move apps that would have attribute issues (xorg)
#       - will not move apps that have no json file
#       - improved error handling, improved listing shows actual app names
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# variables: these are globally available to all functions
#-------------------------------------------------------------------------#
COMMAND=$1
APP=$2
MEDIA=/media/internal/.apps
VAR=/var/usr/palm/applications

# Backup keeps file attributes but uses more /media space. Recommend doing backups.
BACKUP=1  # set to 1 for tar backups, 0 to disable
BACKUPDIR=/media/internal/.appbackups

# This should be turned on.  Only turn off if javascript is calling this script.
PROMPTS=1

#-------------------------------------------------------------------------#
# exit codes for javascripts:
# function usage:
# 1 - normal usage error
#
# function cleanapp:
# 0 - normal exit
#
# function linkapp:
# 10 - app name not supplied
# 11 - link already exists
# 12 - app does not exit in VAR
# 13 - copy failed from VAR to MEDIA
# 14 - removing app from VAR failed
# 15 - APP needs permissions not supported on FAT, did not move to MEDIA
# 16 - APP has no json file, did not move to MEDIA
#
# function unlinkapp:
# 20 - app name not supplied
# 21 - app doesn't exit on MEDIA
# 22 - tar restore failed
# 23 - copy failed
# 24 - remove failed
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# function: cleanexit - exit with cleanup items
#-------------------------------------------------------------------------#

cleanexit () {
 code=$1

# put / back to read only
  mount -o remount,ro /

# Uncomment if you want verbose exit codes
# echo "exit code: $code"

 exit $code
}
# end of cleanexit function


#-------------------------------------------------------------------------#
# function: usage - show command usage options
#-------------------------------------------------------------------------#
usage () {
   exitcode=$1
   if [ ! $exitcode ]
   then
     exitcode=1  # default exit code for usage, otherwise exit with incode
   fi

   echo "Usage: mvapp link domain.appname    - move app to media and link"
   echo "Usage: mvapp unlink domain.appname  - restore app to var, remove link"
   echo "Usage: mvapp clean domain.appname   - remove app dir and links"
   echo "Usage: mvapp list                   - list all apps sorted by size"
   echo "Usage: mvapp bulkmv                 - move/link bulk apps"
   echo "Usage: mvapp listmoved              - list apps that have been moved"
   echo "Usage: mvapp restoreall             - restore all apps to original"

  cleanexit $exitcode
}
# end of usage function


#-------------------------------------------------------------------------#
# function: cleanapp - removes symbolic links and folder in media and var
#-------------------------------------------------------------------------#

cleanapp () {

 mount -o remount,rw /

 # exit to usage if no app name supplied
 if [ ! $APP ]
 then
   usage 1
 fi

# Continue on if PROMPTS turned off (call from outside app)
 if [ $PROMPTS ]
 then
  echo "This will remove $APP from both $VAR and $MEDIA."
  echo "You should first attempt to remove the app using the official Pre methods."
  echo "Are you sure you want to remove $APP? [y/N]: "
  read answer
  case $answer in
   [Yy]*) continue;;
       *) cleanexit 0;;
  esac
 fi

 if [ -h $VAR/$APP ]
 then
   echo "Removing all traces of $APP."
 else
   echo "$APP does not exist..."
   usage 10
 fi

 echo "Size of $VAR before cleanup... "
 du -sh $VAR

 if [ -d $MEDIA/$APP ]
 then
     rm -r $MEDIA/$APP
      echo "Removed directory" $MEDIA/$APP
 fi
 if [ -d $VAR/$APP ]
 then
      rm -r $VAR/$APP
      echo "Removed directory" $VAR/$APP
 fi
 if [ -L $VAR/$APP ]
 then
      rm -r $VAR/$APP
      echo "Removed link" $VAR/$APP
 fi
 if [ -f $BACKUPDIR/$APP.tgz ]
 then
      rm -r $BACKUPDIR/$APP.tgz
      echo "Removed tar backup" $BACKUPDIR/$APP.tgz
 fi


 # rescan luna in case it's needed
 luna-send -n 1 palm://com.palm.applicationManager/rescan {} >/dev/null 2>&1
 echo "$APP directories and links removed."
 echo "Size of $VAR after cleanup... "
 du -sh $VAR
 cleanexit 0
}
# end of cleanup function


#-------------------------------------------------------------------------#
# function: listapps - list the size of each app, sort showing largest last
#-------------------------------------------------------------------------#
listapps () {
 cd $VAR
 for i in `du -s * | sort -n |cut -f 2`
 do
    APP=$i
    SIZE=`du -s $VAR/$APP |cut -f1`
    TITLE=""
    if [ -f $VAR/$APP/appinfo.json ]
    then
      TITLE=`grep title $VAR/$APP/appinfo.json |cut -d: -f2 |cut -d\" -f2`
    fi
    echo "$SIZE - $APP - $TITLE"
 done

 cleanexit 0
}
# end of listapps function

#-------------------------------------------------------------------------#
# function: listmoved - list apps moved/linked, sort showing largest last
#-------------------------------------------------------------------------#
listmoved () {
 #du -sk $MEDIA/* | sort -n  #doesn't show proper size on FAT fs, removing
 cd $MEDIA
 for i in `du -s * | sort -n |cut -f 2`
 do
    APP=$i
    # Not sure why du reports incorrectly on FAT fs
    #SIZE=`du -s $MEDIA/$APP |cut -f1`
    SIZE=""
    TITLE=""
    if [ -f $MEDIA/$APP/appinfo.json ]
    then
      TITLE=`grep title $MEDIA/$APP/appinfo.json |cut -d: -f2 |cut -d\" -f2`
    fi
    echo "$SIZE - $APP - $TITLE"
 done
 cleanexit 0
}
# end of listmoved function


#-------------------------------------------------------------------------#
# function: linkapp - move the app to media and create symbolic link
#-------------------------------------------------------------------------#
linkapp () {

 if [ ! $APP ]
 then
      echo "No application supplied..."
      usage 10
 fi

 if [ ! -f $VAR/$APP/appinfo.json ]
 then
    echo "$APP has no json file.  Will not be moved."
    code=16
    return 16
 fi

 if [ ! -d $MEDIA ]
 then
      mkdir $MEDIA
 fi

 if [ -h $VAR/$APP ]
 then
      echo "Link already exists for... ${APP}"
      cleanexit 11
 fi

 TITLE=`grep title $VAR/$APP/appinfo.json |cut -d: -f2 |cut -d\" -f2`

 mount -o remount,rw /

 if [ -d $VAR/$APP ]
 then
   echo "Moving $APP $TITLE to $MEDIA..."
 else
   echo "$APP does not exist..."
   usage 12
 fi

 # Backup using tar if enabled
 if [ $BACKUP ]
 then
   if [ ! -d $BACKUPDIR ]
   then
    mkdir $BACKUPDIR
   fi
   echo "Backing up $APP $TITLE to $BACKUPDIR..."
   tar czf $BACKUPDIR/${APP}.tgz $VAR/$APP
 fi

 mount -o remount,rw /

 echo "Size of $VAR before move... "
 du -sh $VAR

 # move over to USB drive
 cp -rp  $VAR/$APP $MEDIA >/tmp/cpresult.out 2>&1
 if [ $? != 0 ]
 then
  grep "cannot preserve ownership" /tmp/cpresult.out >/dev/null 2>&1
  if [ $? = 0 ]
  then
   echo
   echo "$APP cannot be moved as it requires special permissions."
   echo "Leaving app in $VAR."
   code=15
   return $code
  else
   echo "Copy failed. Leaving app in $VAR."
   code=13
  fi
  rm -r $MEDIA/$APP
  rm /tmp/cpresult.out
  cleanexit $code
 fi

 rm -r $VAR/$APP
 if [ $? != 0 ]
 then
  echo "Remove failed. Leaving app in $VAR."
  rm -r $MEDIA/$APP
  cleanexit 14
 fi

 # create the symbolic link
 ln -s $MEDIA/$APP $VAR/$APP

 # rescan luna in case it's needed
 luna-send -n 1 palm://com.palm.applicationManager/rescan {} >/dev/null 2>&1

 echo "$APP moved and linked."
 echo "Size of $VAR after move... "
 du -sh $VAR
}
# end of linkapp function


#-------------------------------------------------------------------------#
# function: unlinkapp -  restore the app to var and remove symbolic link
#-------------------------------------------------------------------------#
unlinkapp () {

 if [ ! $APP ]
 then
   echo "No application supplied..."
   usage 20
 fi

 mount -o remount,rw /

 if [ -d $MEDIA/$APP ]
 then
   echo "Restoring $APP..."
 else
   echo "$APP does not exist..."
   usage 21
 fi

 echo "Size of $VAR before move... "
 du -sh $VAR

 # remove the old symbolic link
 rm -r $VAR/$APP

 # move to original location or restore from tar if it exists
 if [ -f $BACKUPDIR/$APP.tgz ]
 then
  cd /
  tar xzf $BACKUPDIR/$APP.tgz
  if [ $? != 0 ]
 then
   echo "Tar restore failed. Remove and restore app using official webOS/Pre methods."
   cleanexit 22
  else
   rm -r $BACKUPDIR/$APP.tgz
  fi
 else
  cp -r  $MEDIA/$APP $VAR
  if [ $? != 0 ]
  then
   echo "Copy failed. Leaving app in $MEDIA."
   cleanexit 23
  fi
 fi

 rm -r $MEDIA/$APP
 if [ $? != 0 ]
 then
  echo "Remove failed. Leaving app in $MEDIA."
  rm -r $VAR/$APP
  cleanexit 24
 fi

 # rescan luna in case it's needed
 luna-send -n 1 palm://com.palm.applicationManager/rescan {} >/dev/null 2>&1

 echo "$APP moved and unlinked."
 echo "Size of $VAR after move... "
 du -sh $VAR
}
# end of unlinkapp function

#-------------------------------------------------------------------------#
# function: bulkmv -  move/link many apps
#-------------------------------------------------------------------------#
bulkmv() {
 echo
 echo
 echo "This allows moving many apps, asking which you'd like to move."
 echo "Starting with the largest apps."
 echo


 mount -o remount,rw /
 cd $VAR

 for i in `du -s * | sort -nr |cut -f 2`
 do
    export APP=$i
    SIZE=`du -sh $APP |cut -f 1`
    TITLE=`grep title $VAR/$APP/appinfo.json |cut -d: -f2 |cut -d\" -f2`
    echo "Size of $APP - $TITLE is $SIZE."
    echo "Would you like to move and link... $TITLE? [y/N/q]: "
    read answer
    case $answer in
    [Yy]*) linkapp;;
    [Qq]*) cleanexit 0;;
        *) echo "$APP not moved."
           continue;;
    esac

    echo
 done
}
# end of bulkmv function

#-------------------------------------------------------------------------#
# function: restoreall - restore all apps, back to /var
#-------------------------------------------------------------------------#
restoreall() {

#Only confirm if PROMPT turned on. (allows outside app to call)
  if [ $PROMPT ]
  then
   echo "This will restore all applications back to original location"
   echo "and remove the links.  Are you sure you want to continue? [y/N]:"
   read answer
   case $answer in
    [Yy]*) continue;;
        *) cleanexit 0;;
   esac
  fi

  ls $MEDIA | while read APP
  do
    echo "Restoring $APP and unlinking..."
    unlinkapp
  done
}
# end of restoreall function


#-------------------------------------------------------------------------#
# main - begins here
#-------------------------------------------------------------------------#

case $COMMAND in
"clean")
   cleanapp
   ;;
"list")
   listapps
   ;;
"listmoved")
   listmoved
   ;;
"link")
   linkapp
   ;;
"unlink")
   unlinkapp
   ;;
"bulkmv")
   bulkmv
   ;;
"restoreall")
   restoreall
   ;;
*)
   usage 1
   ;;
esac

cleanexit $code
