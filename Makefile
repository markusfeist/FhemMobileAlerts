
/opt/fhem/FHEM/%.pm: FHEM/%.pm
	sudo cp $< $@ 

deploylocal: /opt/fhem/FHEM/50_MOBILEALERTSGW.pm /opt/fhem/FHEM/51_MOBILEALERTS.pm
	sudo service fhem stop
	sudo rm /opt/fhem/log/fhem-*.log
	sudo cp test/fhem.cfg /opt/fhem/fhem.cfg
	sudo rm /opt/fhem/log/fhem.save
	sudo service fhem start

undeploylocal:
	sudo service fhem stop
	sudo rm /opt/fhem/FHEM/50_MOBILEALERTSGW.pm /opt/fhem/FHEM/51_MOBILEALERTS.pm
	sudo service fhem start

test: deploylocal
	test/test.sh 01