#!/bin/bash
# Script developed by Luis Felipe Ariza Vesga
# lfarizav@gmail.com, lfarizav@unal.edu.co
set -e
function get_ip_address() {
    # Get the IP address of the first active network interface
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    
    # Check if the IP_ADDRESS is empty
    if [[ -z "$IP_ADDRESS" ]]; then
        echo "No IP address found."
        return 1
    else
        echo "$IP_ADDRESS"
        return 0
    fi
}
function install_cluster_1master_2workers() {
	kind create cluster --config kind-three-node-cluster.yaml --name dev
}
function install_calico() {
	kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/calico.yaml
}
function delete_kind_stop_all_container() {
	kind delete cluster --name dev
	docker stop $(docker ps -a -q) 
	docker rm $(docker ps -a -q)
	docker ps -a
}
function install_kind_ubuntu() {
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.26.0/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.26.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
}
cecho()  {
    # Color-echo
    # arg1 = message
    # arg2 = color
    local default_msg="No Message."
    message=${1:-$default_msg}
    color=${2:-$green}
    echo -e "$color$message$reset_color"
    return
}
echo_info()    { cecho "$*" $blue         ;}
function print_help() {
  echo_info "This script installs kind and more...
-I
   Install kind cluster with calico
-D
   Delete kind cluster and stop all containers
-C
   Install Calico
-h
   Print this help"
}
function main() {

  until [ -z "$1" ]
  do
    case "$1" in
       -I | --install)
		echo "Install kind on Ubuntu for AMD64 / x86_64"
       		install_kind_ubuntu
		echo "Install kind cluster called dev and calico (CNI)"
		install_cluster_1master_2workers
            exit 1;;
       -D | --delete)
		echo "Delete kind cluster and stop all containers"
		delete_kind_stop_all_container
            exit 1;;
       -C | --calico)
                echo "Delete kind cluster and stop all containers"
                install_calico
            exit 1;;
       -h | --help)
            print_help
            exit 1;;
        *)
            print_help
            echo_fatal "Unknown option $1"
            break;;
   esac
  done
}
main "$@"
