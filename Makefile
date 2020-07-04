
/opt/fhem/FHEM/%.pm: FHEM/%.pm
	sudo cp $< $@ 

deploylocal: /opt/fhem/FHEM/50_MOBILEALERTSGW.pm /opt/fhem/FHEM/51_MOBILEALERTS.pm
	sudo /etc/init.d/fhem stop || true
	sudo systemctl stop fhem || true
	sudo rm /opt/fhem/log/fhem-*.log || true
	sudo cp test/fhem.cfg /opt/fhem/fhem.cfg
	sudo rm /opt/fhem/log/fhem.save || true
	test -e /etc/init.d/fhem && sudo TZ=Europe/Berlin /etc/init.d/fhem start || true
	test -e /etc/init.d/fhem || sudo TZ=Europe/Berlin systemctl start fhem

undeploylocal:
	sudo /etc/init.d/fhem stop
	sudo systemctl stop fhem || true
	sudo rm /opt/fhem/FHEM/50_MOBILEALERTSGW.pm /opt/fhem/FHEM/51_MOBILEALERTS.pm
	cd /opt/fhem && sudo TZ=Europe/Berlin /usr/bin/perl fhem.pl fhem.cfg

test: deploylocal
	@echo === Starte Tests ===
	test/test.sh 01
	test/test.sh 02
	test/test.sh MA10120PRO	
	test/test.sh MA10320PRO
	test/test.sh MA10650
	test/test.sh MA10660
	test/test.sh MA10450
	test/test.sh TFA30_3312_02
	test/test.sh WL2000
	test/test.sh TFA30_3060_01
	test/test.sh MA10880
	test/test.sh MA10238
	@echo === Alles Tests ok beendet ===
