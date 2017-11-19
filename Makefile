
/opt/fhem/FHEM/%.pm: FHEM/%.pm
	sudo cp $< $@ 

deploylocal: /opt/fhem/FHEM/50_MOBILEALERTSGW.pm /opt/fhem/FHEM/51_MOBILEALERTS.pm
	sudo service fhem stop
	sudo rm /opt/fhem/log/fhem-*.log || true
	sudo cp test/fhem.cfg /opt/fhem/fhem.cfg
	sudo rm /opt/fhem/log/fhem.save
	sudo service fhem start

undeploylocal:
	sudo service fhem stop
	sudo rm /opt/fhem/FHEM/50_MOBILEALERTSGW.pm /opt/fhem/FHEM/51_MOBILEALERTS.pm
	sudo service fhem start

test: deploylocal
	test/test.sh 01
	test/test.sh MA10320PRO
	test/test.sh MA10650
	test/test.sh MA10660