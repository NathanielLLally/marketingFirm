#!/bin/sh

FILE=$1

#ssh mail.accurateleadinfo.com -- psql -U postgres -h 127.0.0.1 <<'__END__'
#select now();
#__END__

#echo "select now();" | ssh $host -- psql -U postgres -h 127.0.0.1 --file="/dev/stdin"

#for i in mail.leadmailerhq.com mail.accurateleadinfo.com mail.grandstreet.group mail.pipelinesend.com mail.happytailspawcare.com; do 
for host in mail.accurateleadinfo.com mail.grandstreet.group; do 
  echo $host $FILE
  cat $FILE | ssh $host -- psql -U postgres -h 127.0.0.1 --file="/dev/stdin"
done
