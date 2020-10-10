#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
test  ${basedir} == ${PWD}
ckLocalRoot=$(cd ${basedir}/../clickhouse_all;pwd)
ckDockerRoot=/home/grakra/clickhouse

ck_client_list=$(perl -lne 'print $1 if /^\s*\d+(?:\.\d+){3}\s+(ck_client\d+)\s*$/' ${PWD}/hosts )
ck_client_list=$(echo ${ck_client_list}|perl -aF'\s+' -lne 'print join qq/ /, @F[0..2]')

dockerFlags="-ti --rm -u grakra -w /home/grakra --privileged --net static_net0 -v ${PWD}/hosts:/etc/hosts -v ${ckLocalRoot}:${ckDockerRoot}"

start_ck_client_args(){
  local node=${1:?"undefined 'ck_server'"};shift
  local ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b$node\b/" hosts)
  local flags="
  -v ${PWD}/${node}_data:/home/grakra/ck_client_data
  -v ${PWD}/${node}_logs:/home/grakra/ck_client_logs
  -v ${PWD}/ck_client_config:/etc/clickhouse-client
  --name $node
  --hostname $node
  --ip $ip
  "

  mkdir -p ${PWD}/${node}_logs
  rm -fr ${PWD}/${node}_logs/*

  # bootstrap-mode: cleanup datadir of ck_server
  mkdir -p ${PWD}/${node}_data
  if [ "x${bootstrap}x" != "xfalsex" ];then 
    rm -fr ${PWD}/${node}_data/*
  fi

  # run docker
  echo docker run ${dockerFlags} ${flags} grakra/clickhouse-binary-builder:20.04 \
    ${ckDockerRoot}/usr/local/bin/clickhouse-client $*

  docker run ${dockerFlags} ${flags} grakra/clickhouse-binary-builder:20.04 \
    ${ckDockerRoot}/usr/local/bin/clickhouse-client $*
}

start_ck_client_args $*
