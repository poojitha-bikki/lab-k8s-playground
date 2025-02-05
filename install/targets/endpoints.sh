#!/bin/bash

LAB_HOME=${LAB_HOME:-`pwd`}
INSTALL_HOME=$LAB_HOME/install
source $INSTALL_HOME/funcs.sh

endpoints_dir=$INSTALL_HOME/targets/endpoints

add_endpoint "common" "Web Terminal" "https://$HOST_IP:4200"

if [[ -d $endpoints_dir ]]; then
  groups=($(ls $endpoints_dir))
  for group in "${groups[@]}" ; do
    endpoints=()
    while IFS='' read -r line || [[ -n "$line" ]] ; do
      endpoints+=("$line")
    done < $endpoints_dir/$group

    if [[ ${#endpoints[@]} != 0 ]]; then
      print_endpoints $group "${endpoints[@]}"
    fi
  done
fi
