#!/bin/bash

#
# NOTE: you should replace these variables with concrete details of your own system
#

user="root"
pass=${PASSWORD}

v1_host=${V1_IP}
v1_ca=${V1_SERVER_CA}
v1_cert=${V1_CLIENT_CERT}
v1_key=${V1_CLIENT_KEY}

v2_host=${V2_IP}
v2_ca=${V2_SERVER_CA}
v2_cert=${V2_CLIENT_CERT}
v2_key=${V2_CLIENT_KEY}









echo ""

echo -e "\e[1;33m
     _           _            _
 ___| |___ _ _ _| |   ___ ___| |
|  _| | . | | | . |  |_ -| . | |
|___|_|___|___|___|  |___|_  |_|
                           |_|  \e[0m"

echo "[================ v1 to v2 migrate script 1.0 ================]"
echo "[                                                             ]"
echo "[    unsupported, unofficial, user should alter if needed     ]"
echo "[                                                             ]"
echo "[=============================================================]"
echo ""

echo "connection params:"
echo "user=\"root\"
pass=********

v1_host=${V1_IP}
v1_ca=${V1_SERVER_CA}
v1_cert=${V1_CLIENT_CERT}
v1_key=${V1_CLIENT_KEY}

v2_host=${V2_IP}
v2_ca=${V2_SERVER_CA}
v2_cert=${V2_CLIENT_CERT}
v2_key=${V2_CLIENT_KEY}" | sed -e 's/^/\t/'
echo ""

echo -e "\e[4;37mStarting...\e[0m"
echo ""



# get list of databases on v1 server

echo -e "\e[1;36m>>> getting databases from v1 server ${v1_host}...\e[0m"
echo ""

mysql -h ${v1_host} -u ${user} --password=${pass} \
      --ssl-ca=${v1_ca} --ssl-cert=${v1_cert} --ssl-key=${v1_key} \
      -A -N \
          -e"SELECT schema_name FROM information_schema.schemata \
    WHERE schema_name NOT IN ('information_schema','mysql','performance_schema')" \
	  > /tmp/v1dblist.txt;

echo -e "\tgot databases: \n"
cat /tmp/v1dblist.txt | sed -e 's/^/\t\t* /'
echo ""



# generate data dump files (minus triggers) from v1 server

echo -e "\e[1;36m>>> generating dump files (minus triggers) for each database from v1 server...\e[0m"
echo ""
echo -e "\tcreating:\n"

for DB in `cat /tmp/v1dblist.txt`; do

    echo -en "\t\t* /tmp/${DB}_dump_notrigger.sql ... "

    mysqldump --databases ${DB} \
	      -h ${v1_host} -u ${user} --password=${pass} \
	      --ssl-ca=${v1_ca} --ssl-cert=${v1_cert} --ssl-key=${v1_key} \
	      --hex-blob --default-character-set=utf8 --skip-triggers \
	      > /tmp/${DB}_dump_notrigger.sql;

    echo "done"

done
echo ""



# pipe dump files (minus triggers) to v2 server

# (first get databases of v2 server just to show diff to user)

echo -e "\e[1;36m>>> piping dump files (minus triggers) into v2 server...\e[0m"
echo ""

mysql -h ${v2_host} -u ${user} --password=${pass} \
      --ssl-ca=${v2_ca} --ssl-cert=${v2_cert} --ssl-key=${v2_key} \
      -A -N \
          -e"SELECT schema_name FROM information_schema.schemata \
    WHERE schema_name NOT IN ('information_schema','mysql','performance_schema')" \
	  > /tmp/v2dblist.txt;

echo -e "\tbefore piping, current databases of v2 instance:\n"
cat /tmp/v2dblist.txt | sed -e 's/^/\t\t* /'
echo ""
echo -e "\t---\n"

# actual piping of dump files

echo -e "\tpiping:\n"

for DB in `cat /tmp/v1dblist.txt`; do

    echo -en "\t\t* /tmp/${DB}_dump_notrigger.sql ... "

    mysql \
	-h ${v2_host} -u ${user} --password=${pass} \
	--ssl-ca=${v2_ca} --ssl-cert=${v2_cert} --ssl-key=${v2_key} \
	< /tmp/${DB}_dump_notrigger.sql;

    echo "done"
    echo ""

done

echo -e "\t---\n"

mysql -h ${v2_host} -u ${user} --password=${pass} \
      --ssl-ca=${v2_ca} --ssl-cert=${v2_cert} --ssl-key=${v2_key} \
      -A -N \
          -e"SELECT schema_name FROM information_schema.schemata \
    WHERE schema_name NOT IN ('information_schema','mysql','performance_schema')" \
	  > /tmp/v2dblist.txt;

echo -e "\tafter piping, current databases of v2 instance:\n"
cat /tmp/v2dblist.txt | sed -e 's/^/\t\t* /'
echo ""



# grab trigger definitions from v1 instance

echo -e "\e[1;36m>>> getting trigger definers from v1 instance...\e[0m"
echo ""

echo -e "\tcreating:\n"

for DB in `cat /tmp/v1dblist.txt`; do

    echo -en "\t\t* /tmp/${DB}-routines.sql ... "

    mysqldump -h ${v1_host} -u ${user} --password=${pass} \
	      --ssl-ca=${v1_ca} --ssl-cert=${v1_cert} --ssl-key=${v1_key} \
	      --no-data --no-create-info --routines ${DB} \
	      > /tmp/${DB}-routines.sql;

    echo "done"

done
echo ""



# inserting triggers into v2 instance

echo -e "\e[1;36m>>> inserting triggers into v2 instance...\e[0m"
echo ""

echo -e "\tpiping:\n"
 
for DB in `cat /tmp/v1dblist.txt`; do

    echo -en "\t\t* /tmp/${DB}-routines.sql ... "

    mysql \
	-h ${v2_host} -u ${user} --password=${pass} \
	--ssl-ca=${v2_ca} --ssl-cert=${v2_cert} --ssl-key=${v2_key} ${DB} \
	< /tmp/${DB}-routines.sql;

    echo "done"

done

echo ""
echo -e "\e[4;37mDone.\e[0m"
echo ""
