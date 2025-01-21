#!/bin/sh

cd /home/$USER/src/git/marketingFirm/parsers;

echo 'Address,City,Email,Name,Phone,State,Tags,Website,Zip' > ./data/page1.csv

for i in `find data/*.html`; do 
  echo $i; 
  ./parseYP.csv.pl $i >> ./data/page1.csv;
done

