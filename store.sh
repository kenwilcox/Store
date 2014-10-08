#!/bin/bash

# Store - an idea I've had and done several times
# with python and C#, and now just the plain old shell

sqlite=/usr/bin/sqlite3
db=~/.config/.store.db
DEBUG=false

function Echo {
  if [ $DEBUG = true ]
  then
    echo $*
  fi
}

# checks to see if the database exists, and if not creates it
function checkDatabase {
  checkTable="select * from sqlite_master where name='store' and type='table'"
  res=`$sqlite $db "$checkTable"`
  if [ "$res" == "" ]
  then
    createTable='create table store (key varchar(20) unique, value text)'
    $sqlite $db "$createTable"
    createTable='create table __internal__ (key varchar(20) unique, value text)'
    $sqlite $db "$createTable"
    $sqlite $db 'insert into __internal__ values ("version", "0.2")'
  fi
}

function _checkForKey {
  key=$1
  qry='select value from __internal__ where key="'$key'"'
  Echo $qry
  res=`$sqlite $db "$qry"`
  echo $res

}

function checkForKey {
  key=$1
  qry='select value from store where key="'$key'"'
  Echo $qry
  res=`$sqlite $db "$qry"`
  #echo "$ECHO - $ECHO_SEP"
  if [ $ECHO = true ]
  then
    echo $key"$ECHO_SEP"$res
  else
    echo $res
  fi
}

# This marked as redundant - same as checkForKey
#function getValueForKey {
#  echo "TBA"
#}

function insertKeyValue {
  key=$1
  value=$2
  qry='insert into store values ("'$key'", "'$value'")'
  Echo $qry
  $sqlite $db "$qry"
}

function updateKeyWithValue {
  key=$1
  value=$2
  qry='update store set value="'$value'" where key="'$key'"'
  Echo $qry
  $sqlite $db "$qry"
}

function appendKeyWithValue {
  key=$1
  value=$2
  qry='select value from store where key="'$key'"'
  Echo $qry
  str=`$sqlite $db "$qry"`
  value="$str $value"
  qry='update store set value="'$value'" where key="'$key'"'
  Echo $qry
  $sqlite $db "$qry"
}

function insertKeyWithValue {
  key=$1
  value=$2
  qry='select value from store where key="'$key'"'
  Echo $qry
  str=`$sqlite $db "$qry"`
  value="$value $str"
  qry='update store set value="'$value'" where key="'$key'"'
  Echo $qry
  $sqlite $db "$qry"
}

function removeKey {
  key=$1
  # Check is pointless, sqlite does not complain if it's not there
  #res=`checkForKey "$key"`
  #if [ "$res" != "" ]
  #then
    qry='delete from store where key="'$key'"'
    Echo $qry
    $sqlite $db "$qry"
    # Sqlite does not reclaim space unless you vacuum
    $sqlite $db vacuum
  #fi
}

function dump {
  #for line in `$sqlite $db 'select key from store'`
  #do
  #  echo "$line | " `$sqlite $db 'select value from store where key="'$line'"'`
  #done
  $sqlite $db 'select key, value from store'
}

function usage {
  year=`date +"%C%y"`
  if [ $year -ne 2009 ]
  then
    copy="2009-$year"
  else
    copy="2009"
  fi
  
  res=`_checkForKey "version"`
  echo "This is store, version: $res  (c)$copy Kenneth Wilcox"
  echo "Store does just that - it stores what you want."
  echo "It just boils down to a dictionary or hash"
  echo ""
  echo "Usage:"
  echo "store <key> <value>"
  echo "      stores <value> under the name <key>"
  echo "      ex: store name 'John Doe'"
  echo "      Note: if <key> already exists it's old value will be replaced"
  echo ""
  echo "store <key>"
  echo "      Reterives the value for <key>"
  echo "      ex: store name"
  echo "      -> John Doe"
  echo ""
  echo "Options:"
  echo "  -k <key> - for those that like paramerter args"
  echo "  -v <value> - parameter args take precidence"
  echo "  -l  Lists all stored key/values"
  echo "  -a  Appends instead of replaces"
  echo "      ex: store name"
  echo "      -> John Doe"
  echo "      store -a name Smith"
  echo "      store name"
  echo "      -> John Doe Smith"
  echo "  -i  Inserts in front of current value (stack like)"
  echo "      ex: store fruit"
  echo "      -> apple orange"
  echo "      store -i fruit banana"
  echo "      store fruit"
  echo "      -> banana apple orange"
  echo "  -r <key>"
  echo "      Removes key from store"
  echo "  -e  Echos the key name with value"
  echo "  -E  <sep>"
  echo "      Echos the key with the value seperated by <sep>"
}

# It doesn't take too long, so just do it right away
checkDatabase

# process any args first
# -k "key"
# -v "value"
# -h "help"
# -a "append to"
# -i "insert in front of"

APPEND_MODE="UPDATE"
KEY=""
VALUE=""
ECHO=false
ECHO_SEP="|"

while getopts "adhilk:v:r:eE:" flag
do
  # DEBUG flag not set until after this
  #echo "$flag" $OPTIND $OPTARG
  # Only the LAST insert mode option takes precidence
  case $flag in
    h) usage; exit 0; ;; #SHOW_HELP=true; ;;
    l) dump; exit 0; ;;
    d) DEBUG=true; ;;
    a) APPEND_MODE="APPEND"; ;;
    i) APPEND_MODE="INSERT"; ;;
    k) KEY=$OPTARG; ;;
    v) VALUE=$OPTARG; ;;
    r) removeKey "$OPTARG"; exit 0; ;;
    e) ECHO=true; ;;
    E) ECHO_SEP="$OPTARG"; ;;
  esac
done

shift $((OPTIND-1))
Echo "Remaining args $# - $@"

case $# in
  0) usage; exit 0; ;;
  1) 
    if [ "$KEY" = "" ]
    then
      KEY=$1;
    else
      VALUE=$*;
    fi
    ;;
  2) KEY=$1; VALUE=$2; ;;
esac

Echo "DEBUG: Append Mode: $APPEND_MODE | Key: $KEY | Value: $VALUE"

#exit 9;

# Now will all that figured out, we need to figure out what to do, lol
res=`checkForKey "$KEY"`
Echo "checkForKey $KEY = $res"
if [ "$VALUE" = "" ]
then
  # no value, just fetch
  echo $res
else
  # First verify the record's there
  if [ "$res" = "" ]
  then
    insertKeyValue "$KEY" "$VALUE"
  else
    # update, append or insert the record depending on options
    case $APPEND_MODE in
      U*) updateKeyWithValue "$KEY" "$VALUE"; ;;
      A*) appendKeyWithValue "$KEY" "$VALUE"; ;;
      I*) insertKeyWithValue "$KEY" "$VALUE"; ;;
    esac
  fi
fi

# We're done - whew!