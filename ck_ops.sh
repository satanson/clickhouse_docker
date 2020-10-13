#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
test  ${basedir} == ${PWD}
ckLocalRoot=$(cd ${basedir}/../clickhouse_all;pwd)
ckDockerRoot=/home/grakra/clickhouse

ck_server_list=$(perl -lne 'print $1 if /^\s*\d+(?:\.\d+){3}\s+(ck_server\d+)\s*$/' ${PWD}/hosts )
#ck_server_list=$(echo ${ck_server_list}|perl -aF'\s+' -lne 'print join qq/ /, @F[0..6]')

dockerFlags="-tid --rm -u grakra -w /home/grakra --privileged --net static_net0 -v ${PWD}/hosts:/etc/hosts -v ${ckLocalRoot}:${ckDockerRoot}"

do_all(){
  local func=${1:?"missing 'func'"}
  set -- $(perl -e "print qq/\$1 \$2/ if qq/${func}/ =~ /^(\\w+)_all_(\\w+)\$/")
  local cmd=${1:?"missing 'cmd'"};shift
  local service=${1:?"missing 'service'"};shift
  green_print "BEGIN: ${func}"
  for node in $(eval "echo \${${service}_list}"); do
    green_print "run: ${cmd}_${service} ${node}"
    ${cmd}_${service} ${node}
  done
  green_print "END: ${func}"
}

stop_node(){
  local name=$1;shift
  set +e +o pipefail
  docker kill ${name}
  docker rm ${name}
  set -e -o pipefail
}

stop_ck_server_args(){
  local node=${1:?"undefined 'ck_server'"};shift
  local finalize=${1:-"false"}
  stop_node ${node}
  if [ "x${finalize}x" != 'xfalsex' ];then
    [ -d "${PWD}/${node}_data" ] &&  rm -fr ${PWD}/${node}_data/*
    mkdir -p ${PWD}/${node}_data
  fi
}

stop_ck_server(){
  stop_ck_server_args ${1:?"missing 'ck_server'"} "false"
}

destroy_ck_server(){
  stop_ck_server_args ${1:?"missing 'ck_server'"} "true"
}

start_ck_server_args(){
  local node=${1:?"undefined 'ck_server'"};shift
  local bootstrap=${1:-"false"}
  local ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b$node\b/" hosts)
  local flags="
  -v ${PWD}/${node}_data:/home/grakra/ck_server_data
  -v ${PWD}/${node}_logs:/home/grakra/ck_server_logs
  -v ${PWD}/ck_server_config:/etc/clickhouse-server
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
    n=${node##zk_server}
    cat >${PWD}/${node}_data/config_priv.xml <<DONE
<macros>
  <shard>$((n/2))</shard>
  <replica>$((n%2))</replica>
</macros>
DONE
  fi

  # run docker
  echo docker run ${dockerFlags} ${flags} grakra/clickhouse-binary-builder:20.04 \
    ${ckDockerRoot}/usr/local/bin/clickhouse-server --config-file=/etc/clickhouse-server/config.xml

  docker run ${dockerFlags} ${flags} grakra/clickhouse-binary-builder:20.04 \
    ${ckDockerRoot}/usr/local/bin/clickhouse-server --config-file=/etc/clickhouse-server/config.xml
}

start_ck_server(){
  start_ck_server_args ${1:?"missing 'ck_server'"} "false"
}

bootstrap_ck_server(){
  start_ck_server_args ${1:?"missing 'ck_server'"} "true"
}


restart_ck_server(){
  stop_ck_server ${1:?"missing 'ck_server'"}
  start_ck_server $1
}

stop_all_ck_server(){ do_all ${FUNCNAME};}
destroy_all_ck_server(){ do_all ${FUNCNAME};}
start_all_ck_server(){ do_all ${FUNCNAME};}
bootstrap_all_ck_server(){ do_all ${FUNCNAME};}
restart_all_ck_server(){ do_all ${FUNCNAME};}


## clickhouse zookeeper
zkLocalRoot=${basedir}/../clickhouse_zk_all/zookeeper
zkDockerRoot=/home/hdfs/zk
ck_zk_list=$(perl -lne 'print $1 if /^\s*\d+(?:\.\d+){3}\s+(ck_zk\d+)\s*$/' ${PWD}/hosts )
ck_zk_list=$(echo ${ck_zk_list}|perl -aF'\s+' -lne 'print join qq/ /, @F[0..2]')


zkDockerFlags="-tid --rm -w /home/hdfs -u hdfs --privileged --net static_net0
-v ${PWD}/hosts:/etc/hosts -v ${zkLocalRoot}:${zkDockerRoot} -v ${PWD}/zk_conf:${zkDockerRoot}/conf"

stop_ck_zk_args(){
  local node=${1:?"missing 'node'"}
  local finalize=${1:-"false"}

  stop_node ${node}
  if [ "x${finalize}x" != 'xfalsex' ];then
    [ -d "${PWD}/${node}_data" ] &&  rm -fr ${PWD}/${node}_data/*
    mkdir -p ${PWD}/${node}_data
  fi
}

stop_ck_zk(){
  stop_ck_zk_args ${1:?"missing 'node'"} "false"
}

destroy_ck_zk(){
  stop_ck_zk_args ${1:?"missing 'node'"} "true"
}

start_ck_zk_args(){
  local node=${1:?"missing 'node"};shift
  local bootstrap=${1:-"false"};shift;
  local ip=$(perl -aF/\\s+/ -ne "print \$F[0] if /\b$node\b/" hosts)
  local flags="
  -v ${PWD}/${node}_data:/home/hdfs/zk_data
  -v ${PWD}/${node}_logs:/home/hdfs/zk/logs
  --name $node
  --hostname $node
  --ip $ip
  "
  [ -d ${PWD}/${node}_logs  ] && rm -fr ${PWD}/${node}_logs/*
  mkdir -p ${PWD}/${node}_logs

  [ "x${bootstrap}x" != "xfalsex" -a -d "${PWD}/${node}_data" ] &&  rm -fr ${PWD}/${node}_data/*
  mkdir -p ${PWD}/${node}_data

  local myid=${node##ck_zk}
  docker run ${zkDockerFlags} ${flags} hadoop_debian:8.8 \
    bash -c "echo ${myid} > /home/hdfs/zk_data/myid && cd /home/hdfs/zk && bin/zkServer.sh start-foreground"
}

stop_ck_zk(){
  stop_ck_zk_args ${1:?"undefined 'node'"} "false"
}

destroy_ck_zk(){
  stop_ck_zk_args ${1:?"undefined 'node'"} "true"
}

start_ck_zk(){
  start_ck_zk_args ${1:?"undefined 'node'"} "false"
}

bootstrap_ck_zk(){
  start_ck_zk_args ${1:?"undefined 'node'"} "true"
}

restart_ck_zk(){
  local node=${1:?"missing 'node"};shift
  stop_ck_zk ${node}
  start_ck_zk ${node}
}

stop_all_ck_zk(){ do_all ${FUNCNAME}; }
destroy_all_ck_zk(){ do_all ${FUNCNAME}; }
bootstrap_all_ck_zk(){ do_all ${FUNCNAME}; }
start_all_ck_zk(){ do_all ${FUNCNAME}; }
restart_all_ck_zk(){ do_all ${FUNCNAME}; }


## cluster

stop_ck_cluster(){
  stop_all_ck_server
  stop_all_ck_zk
}

destroy_ck_cluster(){
  destroy_all_ck_server
  destroy_all_ck_zk
}

start_ck_cluster(){
  start_all_ck_zk
  start_all_ck_server
}

bootstrap_ck_cluster(){
  bootstrap_all_ck_zk
  bootstrap_all_ck_server
}

restart_all_ck_server(){
  restart_all_ck_zk
  restart_all_ck_server
}

