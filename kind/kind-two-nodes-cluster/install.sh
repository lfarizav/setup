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
function install_cluster_1master_1workers() {
	kind create cluster --config kind-two-nodes-cluster.yaml --name dev
}
function install_multus() {
	kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml
	# Control plane node configuration
	docker exec -it dev-control-plane ip link add br-net1 type bridge || true
	docker exec -it dev-control-plane ip addr add 192.168.1.1/24 dev br-net1 || true
	docker exec -it dev-control-plane ip link set br-net1 up
	docker exec -it dev-control-plane sysctl -w net.ipv4.ip_forward=1
	docker exec -it dev-control-plane iptables -t nat -A POSTROUTING -s 192.168.1.0/24 ! -o br-net1 -j MASQUERADE #configuration of cidr
	# Download on the CNI plugins on the host
	cd ~
	curl -LO https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz
        tar -xzf cni-plugins-linux-amd64-v1.4.0.tgz
	# Copy plugins into control plane node
        docker cp ~/bridge dev-control-plane:/opt/cni/bin/
        docker cp ~/host-local dev-control-plane:/opt/cni/bin/
        docker cp ~/loopback dev-control-plane:/opt/cni/bin/
	# Worker node configuration
	docker exec -it dev-worker ip link add br-net1 type bridge || true
	docker exec -it dev-worker ip addr add 192.168.1.1/24 dev br-net1 || true
	docker exec -it dev-worker ip link set br-net1 up
	docker exec -it dev-worker sysctl -w net.ipv4.ip_forward=1
	docker exec -it dev-worker iptables -t nat -A POSTROUTING -s 192.168.1.0/24 ! -o br-net1 -j MASQUERADE #configuration of cidr
	# Copy plugins into worker node
	docker cp ~/bridge dev-worker:/opt/cni/bin/
        docker cp ~/host-local dev-worker:/opt/cni/bin/
        docker cp ~/loopback dev-worker:/opt/cni/bin/
}
function delete_kind_stop_all_container() {
	kind delete cluster --name dev
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
   Install kind cluster with Multus
-D
   Delete kind cluster and stop all containers
-M
   Install Multus
-h
   Print this help"
}
function main() {

  until [ -z "$1" ]
  do
    case "$1" in
       -I | --install)
		#echo "Install kind on Ubuntu for AMD64 / x86_64"
       		#install_kind_ubuntu
		echo "Install kind cluster called dev and Multus (CNI)"
		install_cluster_1master_1workers
            exit 1;;
       -D | --delete)
		echo "Delete kind dev cluster and stop all containers"
		delete_kind_stop_all_container
            exit 1;;
       -M | --multus)
                echo "Install Multus (CNI)"
                install_multus
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
