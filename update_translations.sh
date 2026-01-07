#!/bin/bash
set -e

function buildDialoguesQuery() {
	query='db.dialogues.aggregate([
		{
			"$match": {
				"$and": [
					{"translations.'$1'":{$exists:true}},
					{"translations.'$1'":{$not:{$eq:""}}}
				]
			}
		},
		{
			"$project": {
				"_id": 0,
				"out": {"$concat": ["$text", ";", "$translations.'$1'"]}
			}
		},
	]).forEach((i)=>{console.log(i.out)})'

	echo $query
}

LANGS="spanish portuguese swedish german french italian"

# check if mongosh is installed
if ! command -v mongosh &> /dev/null
then
    echo "mongosh is not installed"
    exit 1
fi

# check if MONGODB_URI is set
if [ -z "$MONGODB_URI" ]; then
    echo "MONGODB_URI is not set"
    exit 1
fi

# check if jq is installed
if ! command -v jq &> /dev/null
then
    echo "jq is not installed"
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

for lang in $LANGS; do
	if [ ! -d $SCRIPT_DIR/$lang ]; then
		mkdir $SCRIPT_DIR/$lang
	fi
done

# update dialogues
for lang in $LANGS; do
	echo "Updating dialogues translations for $lang"

	query=$(buildDialoguesQuery $lang)
	file=$SCRIPT_DIR/${lang}/dialogue.txt
	echo "Saving to $file"
	mongosh $MONGODB_URI --eval "$query" > $file
done
