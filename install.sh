#!/bin/bash

ipath=/usr/share/graphs1090
install=0

packages="collectd-core rrdtool lighttpd unzip python"
mkdir -p $ipath/installed

for i in $packages
do
	if ! dpkg -s $i 2>/dev/null | grep 'Status.*installed' &>/dev/null
	then
		install=1
		touch $ipath/installed/$i
	fi
done

if [ $install == 1 ]
then
	echo "Installing required packages: $packages"
	apt-get update
	apt-get upgrade -y
	if ! apt-get install -y $packages
	then
		echo "Failed to install required packages: $packages"
		echo "Exiting ..."
		exit 1
	fi
fi

if ! dpkg -s libpython2.7 2>/dev/null | grep 'Status.*installed' &>/dev/null
then
	apt-get install -y libpython2.7
fi

if [ -z $1 ] || [ $1 != "test" ]
then
	cd /tmp
	if ! wget --timeout=30 -q -O master.zip https://github.com/wiedehopf/graphs1090/archive/master.zip || ! unzip -q -o master.zip
	then
		echo "Unable to download files, exiting! (Maybe try again?)"
		exit 1
	fi
	cd graphs1090-master
fi

cp -n /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_dbfs-NaN.rrd /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_tisb-recent.rrd 2>/dev/null
cp -n /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_dbfs-NaN.rrd /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_tisb-recent_978.rrd 2>/dev/null
cp graphs1090.sh dump1090.db dump1090.py boot.sh uninstall.sh LICENSE $ipath
cp -n /etc/collectd/collectd.conf /etc/collectd/collectd.conf.graphs1090 2>/dev/null
cp collectd.conf /etc/collectd/collectd.conf
cp cron-graphs1090 /etc/cron.d/
cp -r html $ipath
cp -n default /etc/default/graphs1090
cp default $ipath


cp 88-graphs1090.conf /etc/lighttpd/conf-available
lighty-enable-mod graphs1090 >/dev/null


if wget --timeout=30 http://localhost/dump1090/data/stats.json -O /dev/null -q
then
	sed -i 's?localhost/dump1090-fa?localhost/dump1090?' /etc/collectd/collectd.conf
	echo --------------
	echo "dump1090 webaddress automatically set to http://localhost/dump1090/"
	echo --------------
elif ! wget --timeout=30 http://localhost/dump1090-fa/data/stats.json -O /dev/null -q
then
	echo --------------
	echo "Non-standard configuration detected, you need to change the data URL in /etc/collectd/collectd.conf!"
	echo --------------
fi

if grep jessie /etc/os-release >/dev/null
then
	echo --------------
	echo "Some features are not available on jessie!"
	echo --------------
	sed -i -e 's/ADDNAN/+/' -e 's/TRENDNAN/TREND/' -e 's/MAXNAN/MAX/' -e 's/MINNAN/MIN/' $ipath/graphs1090.sh
fi


mkdir -p /var/lib/collectd/rrd/localhost/dump1090-localhost

mkdir -p /run/graphs1090

systemctl daemon-reload
systemctl enable collectd &>/dev/null
systemctl restart collectd lighttpd


if [ -f /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_messages-local_accepted.rrd ]
then
	$ipath/graphs1090.sh
fi

echo --------------
echo "All done!"
