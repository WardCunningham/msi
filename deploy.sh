# replace msi.fed.wiki.org pages from msi.localhost

cd ../pages
echo `ls | wc -l` pages ...
scp * fed.wiki.org:wiki/farm-8080/data/farm/msi.fed.wiki.org/pages

# replace fed.wiki.org/chart from localhost/chart

cd
cd Smallest-Federated-Wiki/client
echo `ls chart | wc -l` files ...
scp -r chart fed.wiki.org:wiki/farm-8080/client
echo done