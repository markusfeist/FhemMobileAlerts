#!/bin/bash
MY_PATH="`dirname \"$0\"`"
echo "=== Running Test $1 ==="

CMD=$(cat $MY_PATH/$1-cmd.txt)
AUSGABE=$(perl /opt/fhem/fhem.pl 7072 "$CMD")

echo "- Ausgabe:"
echo "$AUSGABE"
echo "- Diff:"
diff <( grep -v -f $MY_PATH/$1-ign.txt -x <(echo "$AUSGABE")) <( grep -v -f $MY_PATH/$1-ign.txt -x $MY_PATH/$1-erg.txt) || {
    echo "=== Differenz erkannt ==="
    echo "=== Ende Test $1: Fehler ==="
    exit 1
}
echo "- Keine Differenz erkannt"
echo "=== Ende Test $1: OK ==="
exit 0

#echo Fuehre "$CMD"
#set -x
#AUSGABE=$(perl /opt/fhem/fhem.pl 7072 "$CMD")
#set +x
#echo $AUSGABE