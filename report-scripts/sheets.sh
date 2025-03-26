#!/bin/bash

function create_json_sheet() {
  map_account_names "$account_mappings_src" |
  jq 'map(. + {"account_type": (.account[:1])}) | sort_by(.account)' |
  map_account_headers "$headers_file" |
  map_notes "$notes_file" |
  jq 'group_by(.account_type)' |
  jq 'map({"category": .[0].account_type_name, "category_num": .[0].account_type, "accounts": (. | map(del(.account_type, .account_type_name)))})'
}
