#!/bin/bash
rm RoutingSwitch.*
sudo ip link delete switch3_1 type veth
sudo ip link delete switch1_1 type veth
sudo ip link delete switch15_2 type veth
sudo ip link delete switch15_1 type veth
