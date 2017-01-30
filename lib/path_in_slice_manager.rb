require 'path_manager'
require 'slice'
require 'slice_exceptions'
require 'slice_extensions'

# L2 routing switch with virtual slicing.
class PathInSliceManager < PathManager
  def start
    super
    logger.info "#{name} started."

    @slice_admin = Slice.create("admin")
    @slice_servers = Slice.create("servers")
  end

  # rubocop:disable MethodLength
  def packet_in(_dpid, packet_in)
    #ARPのパケットインでスライスに自動追加するか判断
    if packet_in.data.is_a? Pio::Arp::Request
      add_slice_member?(packet_in)
    elsif packet_in.data.is_a? Pio::Arp::Reply
      add_slice_member?(packet_in)
    end

    #puts "packet_in_slice_manager!!"
    return unless packet_in.data.is_a? Parser::IPv4Packet

    #puts packet_in.source_ip_address.to_a[0].class
    return unless packet_in.source_ip_address.to_a[0] == 192
    return if packet_in.destination_ip_address.to_a[0] == 224
    return if packet_in.destination_ip_address.to_a[0] == 172
    return if (packet_in.source_ip_address.to_a[3] > 100 && packet_in.destination_ip_address.to_a[3] > 100)
    return if (packet_in.source_ip_address.to_s == "192.168.10.10" && packet_in.destination_ip_address.to_a[3] > 100)
    return if (packet_in.source_ip_address.to_a[3] > 100 && packet_in.destination_ip_address.to_s == "192.168.10.10")
    #puts packet_in.source_ip_address.to_s
    #puts packet_in.source_ip_address.to_s == "192.168.0.1"

    puts ""#綺麗に表示するためだけの空行
    puts "PathInSliceManager::packet_in(_dpid, packet_in)"
    puts "  = IPv4 packet_in is received."
    puts "  +packet_in information(IPv4Packet)"
    puts "  | +dpid: #{packet_in.dpid}"
    puts "  | +in_port: #{packet_in.in_port}"
    puts "  | +Source_ip_address: #{packet_in.source_ip_address.to_s}"
    puts "  | +Source_mac: #{packet_in.source_mac}"
    puts "  |          ↓"
    puts "  | +Destination_ip_address: #{packet_in.destination_ip_address.to_s}"
    puts "  | +Destination_mac: #{packet_in.destination_mac}"

    #サーバ経由のIPを見かけたら、dpidとportを保存しておく
    ipaddr = packet_in.source_ip_address.to_a[3]
    if ipaddr == 10 || (100 < ipaddr && ipaddr <= 200) then
      @server_dpid[1] = packet_in.dpid
      @server_port[1] = packet_in.in_port
      puts "  = Update Server1's dpid and port"
    elsif ipaddr == 20 || 200 < ipaddr then
      @server_dpid[2] = packet_in.dpid
      @server_port[2] = packet_in.in_port
      puts "  = Update Server2's dpid and port"
    end

    if ipaddr == 10 then
      @server_mac[1] = packet_in.source_mac
      puts "  = Update Server1's mac #{@server_mac[1]}"
    elsif ipaddr == 20 then
      @server_mac[2] = packet_in.source_mac
      puts "  = Update Server2's mac #{@server_mac[2]}"
    end



    slice = Slice.find do |each|
      #同じスライスに属しているかを判定
      puts "--slice #{each}?"
      if packet_in.destination_ip_address.to_a[3] <= 100 then
        #物理マシンの時
        puts " --dest: PYHSICAL machine (ip: .0~.100)"
        puts "  +source is member? : #{each.member?(packet_in.slice_source)}"
        puts "  +dest   is member? : #{each.member?(packet_in.slice_destination(@graph))}"
        each.member?(packet_in.slice_source) &&
          each.member?(packet_in.slice_destination(@graph))
      elsif (packet_in.destination_ip_address.to_a[3] > 100 &&
             packet_in.destination_ip_address.to_a[3] <= 200) then
         unless @server_port.has_key?(1) && @server_dpid.has_key?(1) then
          @server_dpid[1] = 0x1 #型適当．バグる気がする
          @server_port[1] = 1 #型適当．バグる気がする
         end

        puts " --dest: CONTAINER on server1 (ip: .101~.200)"
        puts "  +source is member? : #{each.member?(packet_in.slice_source)}"
        puts "  +dest   is member? : #{each.member?({ dpid: @server_dpid[1],
                                                      port_no: @server_port[1], mac: packet_in.source_mac })}"
        each.member?(packet_in.slice_source) &&
          each.member?({ dpid: @server_dpid[1], port_no: @server_port[1], mac: packet_in.source_mac })
      elsif (packet_in.destination_ip_address.to_a[3] > 200) then
        unless @server_port.has_key?(2) && @server_dpid.has_key?(2) then
         @server_dpid[2] = 0x2 #型適当．バグる気がする
         @server_port[2] = 2 #型適当．バグる気がする
        end

        puts " --dest: CONTAINER on server2 (ip: .201~.255)"
        puts "  +source is member? : #{each.member?(packet_in.slice_source)}"
        puts "  +dest   is member? : #{each.member?({ dpid: @server_dpid[2],
                                                      port_no: @server_port[2], mac: packet_in.source_mac })}"
        each.member?(packet_in.slice_source) &&
          each.member?({ dpid: @server_dpid[2], port_no: @server_port[2], mac: packet_in.source_mac })
      end
    end

    ports = if slice
              puts "  => slice is found! (name:#{slice})"
              path = maybe_create_shortest_path_in_slice(slice.name, packet_in)
              path ? [path.out_port] : []
            else
              puts "  => slice is NOT found."
              external_ports(packet_in)
            end
    #puts "--path--"
    #puts ports
    packet_out(packet_in.raw_data, ports)
  end
  # rubocop:enable MethodLength

#IPでコンテナを判別して、ホストのみをグラフに入れる（コンテナは弾く
  def add_host_or_container(mac_address, ip_address, port, _topology)
    puts "PathInSliceManager::add_host_or_container(#{mac_address}, #{ip_address}, #{port})"
############################################
#	         ホストかコンテナか
############################################
#	         ホストの場合
    @graph.add_link mac_address, port
############################################
#	         コンテナの場合
#    container = mac_address, server_mac_address
#    maybe_send_handler :add_container, container#トポロジ追加用
############################################
  end

  private


  def add_slice_member?(packet_in)

    arp_packet = packet_in.data
    senderIP = arp_packet.sender_protocol_address.to_a[3]
    targetIP = arp_packet.target_protocol_address.to_a[3]

    #このメソッドのpacket_inはARPパケットのみ
    puts ""#綺麗に表示するためだけの空行
    puts "PathInSliceManager::packet_in(_dpid, packet_in)::add_slice_member?(packet_in)"
    puts "  =ARP packet_in is received."
    puts "  +packet_in information(ARP)"
    if arp_packet.is_a? Pio::Arp::Request
      puts "  | +ARP      type     : REQUEST"
    else
      puts "  | +ARP      type     : REPLY"
    end
    puts "  | +ARP packet is from: #{arp_packet.sender_protocol_address.to_s}, #{arp_packet.source_mac}"
    puts "  | +ARP packet is  to : #{arp_packet.target_protocol_address.to_s}"


    #もし，ARPがserver間，server<=>adminなら，serversスライスに追加
    if  (senderIP==13 && targetIP==10) || (senderIP==10 && targetIP==13) ||
        (senderIP==13 && targetIP==20) || (senderIP==20 && targetIP==13) ||
        (senderIP==10 && targetIP==20) || (senderIP==20 && targetIP==10) then

          puts "  +ARP Packet is related to .10 or .20(servers)"
          unless @slice_servers.member?(packet_in.slice_source)
            if senderIP == 13
              puts "===> add admin   (#{arp_packet.sender_protocol_address.to_s})'s mac: \"#{arp_packet.source_mac}\" to slice: \"servers\" <==="
            elsif senderIP == 10
              puts "===> add server1 (#{arp_packet.sender_protocol_address.to_s})'s mac: \"#{arp_packet.source_mac}\" to slice: \"servers\" <==="
            elsif senderIP == 20
              puts "===> add server2 (#{arp_packet.sender_protocol_address.to_s})'s mac: \"#{arp_packet.source_mac}\" to slice: \”servers\" <==="
            end
            @slice_servers.add_mac_address(arp_packet.source_mac,
                                           dpid: packet_in.dpid, port_no: packet_in.in_port)
          end
    end


    #もし,ARPの宛先・送信元がアドミンかつ通信相手はサーバではないならこれをアドミンスライスに追加
    if  (senderIP==13 && targetIP!=10 && targetIP!=20) ||
        (targetIP==13 && senderIP!=10 && senderIP!=20)  then

          puts "  +ARP Packet is related to .13(admin)"

          unless @slice_admin.member?(packet_in.slice_source)
            if arp_packet.sender_protocol_address.to_a[3] == 13 then
              puts "===> add admin   (#{arp_packet.sender_protocol_address.to_s})'s mac: \"#{arp_packet.source_mac}\" to slice:  \"admin\"  <==="
            else
              puts "===> add new_user(#{arp_packet.sender_protocol_address.to_s})'s mac: \"#{arp_packet.source_mac}\" to slice:  \"admin\"  <==="
            end
            @slice_admin.add_mac_address(arp_packet.source_mac,
                                         dpid: packet_in.dpid, port_no: packet_in.in_port)
          end
    end



    #コンテナのipがserverのなら
    if (100<senderIP && senderIP<=199) then
      puts "  +ARP Packet's    SOURCE   is containers(on1)"
      userIP = 50 + (senderIP-100)/10
      if userIP == targetIP then
        tmp_slice = find_container_slice(userIP)
        unless tmp_slice.member?(packet_in.slice_source)
          puts "===> add container(#{arp_packet.sender_protocol_address.to_s})'s mac: \"#{arp_packet.source_mac}\" to slice: \"#{tmp_slice}\" <==="
          tmp_slice.add_mac_address(arp_packet.source_mac,
                                    dpid: packet_in.dpid, port_no: packet_in.in_port)
        end
      end

    elsif (100<targetIP && targetIP<=199) then
      puts "  +ARP Packet's DESTINATION is containers(on1)"
      userIP = 50 + (targetIP-100)/10
      puts "   +expected user's IP: #{userIP}"
      if userIP == senderIP then
        tmp_slice = find_container_slice(userIP)
        unless tmp_slice.member?(packet_in.slice_source)
          puts "===> add user    (#{arp_packet.sender_protocol_address.to_s})'s mac: \"#{arp_packet.source_mac}\" to slice: \"#{tmp_slice}\" <==="
          tmp_slice.add_mac_address(arp_packet.source_mac,
                                    dpid: packet_in.dpid, port_no: packet_in.in_port)
        end
      end

    elsif (200<senderIP && senderIP<=255) then
      puts "  +ARP Packet's    SOURCE   is containers(on2)"
      userIP = 50 + (senderIP-200)/10
      if userIP == targetIP then
        tmp_slice = find_container_slice(userIP)
        unless tmp_slice.member?(packet_in.slice_source)
          puts "===> add container(#{arp_packet.sender_protocol_address.to_s})'s mac: \"#{arp_packet.source_mac}\" to slice: \"#{tmp_slice}\" <==="
          tmp_slice.add_mac_address(arp_packet.source_mac,
                                    dpid: packet_in.dpid, port_no: packet_in.in_port)
        end
      end

    elsif (200<targetIP && targetIP<=255) then
      puts "  +ARP Packet's DESTINATION is containers(on2)"
      userIP = 50 + (targetIP-200)/10
      if userIP == senderIP then
        tmp_slice = find_container_slice(userIP)
        unless tmp_slice.member?(packet_in.slice_source)
          puts "===> add user    (#{arp_packet.sender_protocol_address.to_s})'s mac: \"#{arp_packet.source_mac}\" to slice: \"#{tmp_slice}\" <==="
          tmp_slice.add_mac_address(arp_packet.source_mac,
                                    dpid: packet_in.dpid, port_no: packet_in.in_port)
        end
      end
    end
  end

  def find_container_slice(userIP)
    tmp_slice = Slice.find_by(name: "slice_"+userIP.to_s)

    unless tmp_slice then
      tmp_slice = Slice.create("slice_"+userIP.to_s)
    end

    puts "find_container_slice :#{tmp_slice}"
    tmp_slice
  end


  def packet_out(raw_data, ports)
    ports.each do |each|
      send_packet_out(each.dpid,
                      raw_data: raw_data,
                      actions: SendOutPort.new(each.port_no))
    end
  end

  def maybe_create_shortest_path_in_slice(slice_name, packet_in)
    #puts "maybe_create_shortest_path_in_slice"
    path = maybe_create_shortest_path(packet_in)
    return unless path
    path.slice = slice_name
    path
  end

  def external_ports(packet_in)
    Slice.all.each_with_object([]) do |each, ports|
      next unless each.member?(packet_in.slice_source)
      ports.concat external_ports_in_slice(each, packet_in.source_mac)
    end
  end

  def external_ports_in_slice(slice, packet_in_mac)
    slice.each_with_object([]) do |(port, macs), result|
      next unless @graph.external_ports.any? { |each| port == each }
      result << port unless macs.include?(packet_in_mac)
    end
  end
end
