#!/bin/bash
set -e -o pipefail
basedir=$(cd $(dirname $(readlink -f ${BASH_SOURCE:-$0}));pwd)
cd ${basedir}

source ${basedir}/functions.sh
source ${basedir}/ck_ops.sh

cluster_op(){
  yellow_print "cmd: "
  cmd=$(selectOption "start" "restart" "stop" "bootstrap" "destroy")
  green_print "exec: ${cmd}_${service}"
  confirm
  ${cmd}_${service}
}

service_op(){
  yellow_print "cmd: "
  cmd=$(selectOption "restart" "stop" "start" "bootstrap" "destroy" "restart_all" "stop_all" "start_all" "bootstrap_all" "destroy_all")
  if isIn ${cmd} "restart_all|stop_all|start_all|bootstrap_all|destroy_all";then
    green_print "exec: ${cmd}_${service}"
    confirm
    ${cmd}_${service}
  elif isIn ${cmd} "restart|stop|start|bootstrap|destroy";then
    yellow_print "node: "
    if isIn ${service} "ck_server";then
      node=$(selectOption ${ck_server_list})
    elif isIn ${service} "ck_zk";then
      node=$(selectOption ${ck_zk_list})
    fi
    green_print "exec: ${cmd}_${service} ${node}"
    confirm
    ${cmd}_${service} ${node}
  fi
}

op(){
  yellow_print "service: "
  service=$(selectOption "ck_cluster" "ck_server" "ck_zk")
  if isIn ${service} "ck_cluster";then
    cluster_op
  else
    service_op
  fi
}

op
