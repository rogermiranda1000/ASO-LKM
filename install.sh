#!/bin/bash
if [ -z $1 ]; then
	echo "Introdueix un fitxer"
	exit 1
fi

cd $1 &&
	make &&
	sudo cp "$1.ko" /lib/modules/`uname -r`/kernel/drivers &&
	sudo sed -i "/^$1$/d" "/etc/modules" && # remove previous (if exists)
	echo "$1" | sudo tee -a "/etc/modules" && # equivalent a 'echo "$1" >> "/etc/modules"' amb permis de sudo
	sudo depmod &&
	echo "Recorda reiniciar per persistir els canvis!"
