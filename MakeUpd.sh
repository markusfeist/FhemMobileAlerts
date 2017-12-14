#!/bin/bash
MY_PATH="`dirname \"$0\"`"
cd $MY_PATH
rm controls_mobilealerts.txt
for FILE in $(ls FHEM/* | sort -V)
do
    TIME=$(git log --pretty=format:%cd -n 1 --date=iso -- "$FILE")
    TIME=$(TZ=Europe/Berlin date -d "$TIME" +%Y-%m-%d_%H:%M:%S)
    FILESIZE=$(stat -c%s "$FILE")
    echo "UPD $TIME $FILESIZE $FILE" >> controls_mobilealerts.txt
done
cd $OLDPWD
