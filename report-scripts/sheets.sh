#!/bin/bash

function create_json_sheet() {
  map_account_names "$account_mappings_src" |
  # The account type is the first digit of the account number
  jq --slurpfile mappings "$account_mappings_src" '
    map(.account_internal as $name
      | . + {"account_type": ($mappings[0] | map(select(.name == $name)) | first | .accountnumber | tostring | .[:1])})
    | sort_by(.account)' |
  map_account_headers "$headers_file" |
  map_notes "$notes_file" |
  jq 'group_by(.account_type)' |
  jq 'map({"category": .[0].account_type_name, "category_num": .[0].account_type, "accounts": (. | map(del(.account_type, .account_type_name)))})' |
  # Account types that share a header (e.g. 5 and 6) become one section
  jq 'reduce .[] as $section ([];
        if length > 0 and last.category == $section.category
        then last.accounts += $section.accounts
        else . + [$section] end)'
}

# Warns about the notes that are not shown in the given sheet, since there
# is no account in the sheet that they belong to.
function warn_about_unused_notes() {
  local notes_file="$1"
  local sheet_file="$2"
  jq -r --slurpfile sheet "$sheet_file" '
    ($sheet[0] | map(.accounts[].account)) as $accounts
    | map(.key) | unique
    | map(select(. as $key | $accounts | index($key) | not))
    | map("Warning: the note for \(.) is not shown, since that account is not in the report.")
    | .[]' "$notes_file" >&2
}
