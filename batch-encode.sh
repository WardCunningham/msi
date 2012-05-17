cd try4
for i in *
do echo $i
	iconv -f ISO-8859-1 -t UTF-8 <$i >../try4UTF8/$i
done
