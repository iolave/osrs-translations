#!/bin/bash

function calculate_hash() {
	echo "$1" | md5 | cut -d' ' -f1
}

# check if MONGODB_URI is set
if [ -z "$MONGODB_URI" ]; then
    echo "MONGODB_URI is not set"
    exit 1
fi

echo "[info] retrieving npcs from osrsbox-db"
json_items=$(curl -s https://raw.githubusercontent.com/osrsbox/osrsbox-db/refs/heads/master/docs/npcs-summary.json | jq -r '
	map(to_entries)
	| flatten
	| group_by(.key)
	| map({key: first.key, value: map(.value)})
	| from_entries
	| .name
	| unique
')

json_items2=$(curl -s https://raw.githubusercontent.com/osrsbox/osrsbox-db/refs/heads/master/docs/monsters-complete.json | jq -r '
	map(to_entries)
	| flatten
	| group_by(.key)
	| map({key: first.key, value: map(.value)})
	| from_entries
	| .name
	| unique
')

json_items=$(echo "$json_items2$json_items" | jq -sr 'reduce .[] as $x ([]; . + $x)' | jq -r '.')

echo "[info] adding type and text to npcs"
db_items=$(echo "$json_items" | jq -r '
	.[] | 
	{type: "npc", text: .}
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
	
