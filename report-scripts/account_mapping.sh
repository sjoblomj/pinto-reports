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
          | [$value | recurse(capture("(?<B>.*)\\$(?<num>[0-9\\.]+)\\$(?<A>.*)") | .B + "#amount(\"" + .num + "\");" + .A)][-
1] as $value
          | [$value | recurse(capture("(?<B>.*)\\@(?<num>[0-9]+)\\@(?<A>.*)")    | .B + "#account(" + (get_displayname(.num) | tojson) + ");" + .A)][-1])
      })

    else
      .
    end
  '
}

# Exits with an error if an account that is used in the ledger is missing
# from the account mappings file, since it would otherwise end up in the
# wrong place in the reports. Expects transactions.sh to be sourced.
function check_account_mappings() {
  local ledger_file="$1"
  local accounts_mappings_src="$2"
  local unmapped
  unmapped=$(bean-query -f csv "$ledger_file" "SELECT DISTINCT account ORDER BY account" |
    yq -pc -oj '.' |
    jq -r --slurpfile mappings "$accounts_mappings_src" --arg opening_balance_account "$OPENING_BALANCE_ACCOUNT" '
      ($mappings[0] | map(.name)) as $known
      | map(.account)
      | map(select(. != $opening_balance_account and (. as $account | $known | index($account) | not)))
      | .[]')

  if [ -n "$unmapped" ]; then
    echo "Error: these accounts are used in $ledger_file but missing from $accounts_mappings_src:" >&2
    echo "$unmapped" | sed 's/^/  /' >&2
    return 1
  fi

  # The section of an account is picked from its account number, but the report
  # it belongs to is picked from the first part of its name. The two must agree.
  local misplaced
  misplaced=$(bean-query -f csv "$ledger_file" "SELECT DISTINCT account ORDER BY account" |
    yq -pc -oj '.' |
    jq -r --slurpfile mappings "$accounts_mappings_src" --arg assets "$ASSETS_ACCOUNTS" --arg liabilities "$LIABILITIES_ACCOUNTS" --arg result "$RESULT_ACCOUNTS" \
          --arg assets_type "$ASSETS_ACCOUNT_TYPE" --arg liabilities_type "$LIABILITIES_ACCOUNT_TYPE" --arg result_types "$RESULT_ACCOUNT_TYPES" '
      def names: ltrimstr("^") | ltrimstr("(") | rtrimstr(")") | split("|") | join(" or ");
      map(.account) as $used
      | $mappings[0][]
      | select(.name as $name | $used | index($name))
      | (.accountnumber | tostring | .[:1]) as $type
      | (if $type == $assets_type then $assets
         elif $type == $liabilities_type then $liabilities
         elif ($result_types | contains($type)) then $result
         else empty end) as $expected
      | select(.name | test($expected) | not)
      | "\(.name) has account number \(.accountnumber), so its name must start with \($expected | names)"')

  if [ -n "$misplaced" ]; then
    echo "Error: these accounts in $ledger_file would end up in the wrong report, or in none:" >&2
    echo "$misplaced" | sed 's/^/  /' >&2
    return 1
  fi
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
