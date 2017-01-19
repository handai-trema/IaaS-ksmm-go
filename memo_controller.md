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
Topologyへのホストの登録は、Topology_contoroller内で行う。IPv4PacketがPacket_Inされたとき、送信元ホストをTopologyに登録する(ARP RequestやARP ReplyのPacket_Inでは、ホストの登録は行わない。docker0がホストとして登録されたりするので...)。  
ただし、IPアドレスの下3桁が100より大きいホスト、つまりVMはホストとして登録しない(ようにしている)  
Topologyに追加された情報は、Graphにも反映されている(ようだ)。Pathを作る際には、Graphの情報が利用される。
