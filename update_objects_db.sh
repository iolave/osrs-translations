#!/bin/bash

function calculate_hash() {
	echo "$1" | md5 | cut -d' ' -f1
}

# check if MONGODB_URI is set
if [ -z "$MONGODB_URI" ]; then
    echo "MONGODB_URI is not set"
    exit 1
fi

echo "[info] retrieving objects from osrsbox-db"
json_items=$(curl -s https://raw.githubusercontent.com/osrsbox/osrsbox-db/refs/heads/master/docs/objects-summary.json | jq -r '
	map(to_entries)
	| flatten
	| group_by(.key)
	| map({key: first.key, value: map(.value)})
	| from_entries
	| .name
	| unique
')

echo "[info] adding type and text to objects"
db_items=$(echo "$json_items" | jq -r '
	.[] | 
	{type: "object", text: .}
')
max_per_insert=100
i=0
echo "[info] calculating hashes"
echo $db_items | jq -c . |
	while IFS= read -r obj; do 
		i=$((i+1))
		total=$((total+1))

	    	text_to_hash=$(printf '%s' "$obj" | jq -j '(.type + ":" + .text)')
		hash=$(calculate_hash "$text_to_hash")
		data=$data$(jq -cM --arg hash "$hash" '.hash = $hash | ._id = $hash' <<<"$obj")

		if [ "$i" -eq "$max_per_insert" ]; then
			to_insert=$(echo $data | jq -s -cM '.')
			echo $to_insert
			mongosh "${MONGODB_URI}" --eval "db.dialogues.insertMany(${to_insert}, { ordered: false })"
			echo [info] inserted $total items
			i=0
			data=""
		fi
	done && \
	if [ ! "$i" -ne "0" ]; then
		to_insert=$(echo $data | jq -s -cM '.')
		echo $to_insert
		mongosh "${MONGODB_URI}" --eval "db.dialogues.insertMany(${to_insert})"
		echo [info] inserted $total items
	fi && \
	echo [info] done
	
