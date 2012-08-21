
echo "Exports from excel appear in dropbox folders dated by Jamie."
echo "Reruns of his export scripts may write over raw data for a given date."
echo "The running of various scripts has been coordinated on skype."
echo "Here we look for unprocessed, or out-of-order processed data."

cd db
for i in `ls -tr`
  do (
    cd $i
    echo
    echo $i
    ls -tr Raw/Tier1MSISummary.json Processed/formulas.txt 2>/dev/null
  )
done