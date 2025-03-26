#!/bin/bash
function get_account_mapping() {
  local accounts_mappings_src="$1"
  jq -r --arg op "$2" --slurpfile accountsdata "$accounts_mappings_src" '
    def get_account_data($account; $property):
      [ $accountsdata[][]
        | select((.[$property] | tostring) == ($account | tostring))
      ] as $output
      | if $output | length == 0 then null else $output[0] end;

    def get_displayname(account):
      get_account_data(account; "accountnumber").displayname // account;
    def get_displayname_from_name(account):
      get_account_data(account; "name").displayname // account;


    if $op == "get-name" then
      get_account_data(.; "accountnumber").name // .

    elif $op == "map-names" then
      map(. + {"account": (get_account_data(.accountnumber; "accountnumber").name)})

    elif $op == "map-names-to-displaynames" then
      map(. + {"account_internal": .account, "account": get_displayname_from_name(.account)})

    elif $op == "map-account-headers" then
      map(. + {"account_type_name": (get_account_data(.account_type; "key").value // .account_type)})

    elif $op == "map-notes" then
      map(. + {"note": (get_account_data(.account; "key").value // "")})

    elif $op == "parse-notes" then
      map({
        "key": get_displayname(.key),
        "value": (.value as $value
          | [$value | recurse(capture("(?<B>.*)\\$(?<num>[0-9\\.]+)\\$(?<A>.*)") | .B + "\\outputcurrency{" + .num + "} \\currencycode{}" + .A)][-
1] as $value
          | [$value | recurse(capture("(?<B>.*)\\@(?<num>[0-9]+)\\@(?<A>.*)")    | .B + "\\textit{" + get_displayname(.num) + "}" + .A)][-1])
      })

    else
      .
    end
  '
}

function get_account_name() {
  get_account_mapping "$1" "get-name"
}

function map_account_name() {
  get_account_mapping "$1" "map-names"
}

function parse_notes() {
  get_account_mapping "$1" "parse-notes"
}

# Given an array of objects with "account" properties, this function
# will map that "account" value to the corresponding "displayname"
# from the given account mappings file. Also sets "account_internal"
# to be the old "account" value.
function map_account_names() {
  get_account_mapping "$1" "map-names-to-displaynames"
}

function map_account_headers() {
  get_account_mapping "$1" "map-account-headers"
}

function map_notes() {
  get_account_mapping "$1" "map-notes"
}
