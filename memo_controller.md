## コントローラの処理

### ARPの解決について
ARP Request,またはARP ReplyがPacket_Inしたとき、Topology_contorollerにおいてARP解決のための処理を行う。
- ARP Requestを受け取ったとき  
ARPテーブル(@arp_table)を確認し、ARP解決をしたいホストの情報が存在するかを確認する。存在した場合、ARP Replyを作成し、Packet_Inが行われたポートにPacket_Outする。  
ARPテーブルに情報が存在しない場合、ホストが存在する可能性のある全てのポートに、Packet_InされたARP RequestをPacket_Outする。

- ARP Replyを受け取ったとき  
ホストが存在する可能性のある全てのポートに、ARP ReplyをPacket_Outする。

- ARPテーブルの更新  
ARP Request,またはARP ReplyがPacket_Inしたとき、送信ホストの情報をARPテーブルに保存する

### Topologyへのホストの登録について
Topologyへのホストの登録は、Topology_contoroller内で行う。IPv4PacketがPacket_Inされたとき、送信元ホストをTopologyに登録する(ARP RequestやARP ReplyのPacket_Inでは、ホストの登録は行わない。(docker0がホストとして登録されたりするので...)。  
ただし、IPアドレスの下3桁が100より大きいホスト、つまりVMはホストとして登録しない(ようにしている)  
Topologyに追加された情報は、Graphにも反映されている(ようだ)。Pathを作る際には、Graphの情報が利用される。

### VMとの通信
VMの情報はTopologyに登録しないため、ホストとVM間でパスを作ることは出来ない。そのため、VM宛、またはVMからのIPv4PacketがPacket_Inされたときには、VMを、VMのホストマシンとみなしてPathを作る。
- 事前準備
VMをVMのホストとみなしてパスを作るので、VMのホストマシンの情報をコントローラが知っている必要がある。  
コントローラに情報を知らせるには、VMのホストマシンからIPv4Packetを出し、Packet_Inさせればよい。path_in_slice_managerのPacket_Inメソッド内で、VMのホストマシンのmacアドレスが保存され、パスの作成に利用される。
- VM宛のPacketがPacket_Inしたとき  
スライスの設定はされており、コントローラはVMのホストマシンの情報を知っているものとする。  
1. path_in_slice_managerで、スライスのチェックが行われる。宛先ホストのスライス情報を調べるとき、Graphの情報が利用されるが、VMはGraphに登録されていないので、何もしないとスライスで弾かれてしまう。そのため、VMのホストマシンと送信元ホストが同じスライスであるかを調べるようにした。具体的には、Packet_In::slice_destination_vmというメソッドを作成し、VMのホストマシンのスライス情報が確認されるようにした。
2. path_managerのmaybe_create_shortest_pathメソッドでpathが作成される。このとき、Graph::dijkstraメソッドに引数として渡す宛先macアドレスを、予め保存しておいたVMのホストマシンのものにする。これで、送信元ホストからVMのホストマシンまでのPathが作成される。
