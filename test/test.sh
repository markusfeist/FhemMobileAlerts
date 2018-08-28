#!/bin/bash
MY_PATH="`dirname \"$0\"`"
echo "=== Running Test $1 ==="

if [ -e $MY_PATH/$1-nutzdaten.dat ]; then
    curl --silent --show-error -o /dev/null --request PUT --data-binary "@$MY_PATH/$1-nutzdaten.dat" --header "HTTP_IDENTIFY: 800E2EEF:001D8C0E2EEF:C0"   http://localhost:9001/gateway/put || {
        echo "- Fehler beim senden $?."
        echo "=== Ende Test $1: Fehler ==="
        exit 1        
    }    
fi

CMD=$(cat $MY_PATH/$1-cmd.txt)
AUSGABE=$(perl /opt/fhem/fhem.pl 7072 "$CMD")

echo "- Diff:"
diff <( grep -v -f $MY_PATH/$1-ign.txt -x <(echo "$AUSGABE")) <( grep -v -f $MY_PATH/$1-ign.txt -x $MY_PATH/$1-erg.txt) || {
    echo "- Differenz erkannt"
    echo "- Ausgabe:"
    echo "$AUSGABE"    
    echo "- FHEM Log"
    cat /opt/fhem/log/fhem-*.log
    echo "=== Ende Test $1: Fehler ==="
    exit 1
}
echo "- Keine Differenz erkannt"
grep "PERL WARNING" /opt/fhem/log/fhem-*.log | grep MOBILE > /dev/null && {
    echo "PERL WARNING in Log:"
    grep "PERL WARNING" /opt/fhem/log/fhem-*.log
    echo "=== Ende Test $1: Fehler ==="
    exit 1    
}
echo "=== Ende Test $1: OK ==="
exit 0
