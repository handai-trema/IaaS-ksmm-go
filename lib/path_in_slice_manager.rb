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
    puts ""#綺麗に表示するためだけの空行
    puts "PathInSliceManager::packet_in(_dpid, packet_in)"
    puts "--packet_in information(IPv4Packet)"
    puts " +dpid: #{packet_in.dpid}"
    puts " +in_port: #{packet_in.in_port}"
    puts " +source_mac: #{packet_in.source_mac}"
    puts " +destination_mac: #{packet_in.destination_mac}"
    puts " +source_ip_address: #{packet_in.source_ip_address.to_s}"
    puts " +destination_ip_address: #{packet_in.destination_ip_address.to_s}"

    #puts packet_in.source_ip_address.to_a[0].class
    return unless packet_in.source_ip_address.to_a[0] == 192
    return if packet_in.destination_ip_address.to_a[0] == 224
    return if packet_in.destination_ip_address.to_a[0] == 172
    return if (packet_in.source_ip_address.to_a[3] > 100 && packet_in.destination_ip_address.to_a[3] > 100)
    return if (packet_in.source_ip_address.to_s == "192.168.10.10" && packet_in.destination_ip_address.to_a[3] > 100)
    return if (packet_in.source_ip_address.to_a[3] > 100 && packet_in.destination_ip_address.to_s == "192.168.10.10")
    #puts packet_in.source_ip_address.to_s
    #puts packet_in.source_ip_address.to_s == "192.168.0.1"

    #サーバのIPを見かけたら、macアドレスを保存しておく
    if packet_in.source_ip_address.to_s == "192.168.10.10" then
      @server_mac[1] = packet_in.source_mac
      puts "--Server mac saved!!--"
    elsif packet_in.source_ip_address.to_s == "192.168.10.20" then
      @server_mac[2] = packet_in.source_mac
      puts "--Server mac saved!!--"
    end

    slice = Slice.find do |each|
      #同じスライスに属しているかを判定
      #puts each.member?(packet_in.slice_source)
      #puts each.member?(packet_in.slice_destination(@graph))

      each.member?(packet_in.slice_source) &&
           each.member?(packet_in.slice_destination(@graph))

          #Miura：一時的にコメントアウト
          # if packet_in.destination_ip_address.to_a[3] <= 100 then
          #   puts "dest_ip <= 100(physical machine)"
          #   puts each.member?(packet_in.slice_source)
          #   puts each.member?(packet_in.slice_destination(@graph))
          #   each.member?(packet_in.slice_source) &&
          #     each.member?(packet_in.slice_destination(@graph))
          # elsif (packet_in.destination_ip_address.to_a[3] > 100 && packet_in.destination_ip_address.to_a[3] <= 200) then
          #   puts "100 < dest_ip && dest_ip <= 200(container on server1)"
          #   if @server_mac.has_key?(1) then
          #     dammy_mac = @server_mac[1]
          #   else
          #     dammy_mac = Mac.new ("00:00:00:00:00:01")
          #   end
          #   each.member?(packet_in.slice_source) &&
          #     each.member?(packet_in.slice_destination_vm(dammy_mac))
          # elsif (packet_in.destination_ip_address.to_a[3] > 200) then
          #   puts "200 < dest_ip(container on server2)"
          #   if @server_mac.has_key?(2) then
          #     dammy_mac = @server_mac[2]
          #   else
          #     dammy_mac = Mac.new ("00:00:00:00:00:02")
          #   end
          #   each.member?(packet_in.slice_source) &&
          #     each.member?(packet_in.slice_destination_vm(dammy_mac))
          # end
    end

    ports = if slice
              puts "==slice is found! (name:#{slice})=="
              path = maybe_create_shortest_path_in_slice(slice.name, packet_in)
              path ? [path.out_port] : []
            else
              puts "==slice is not found.=="
              external_ports(packet_in)
            end
    #puts "--path--"
    #puts ports
    packet_out(packet_in.raw_data, ports)
  end
  # rubocop:enable MethodLength

#IPでコンテナを判別して、ホストのみをグラフに入れる（コンテナは弾く
  def add_host_or_container(mac_address, ip_address, port, _topology)
    puts ""#綺麗に表示するためだけの空行
    print "PathInSliceManager::add_host_or_container("
    print mac_address
    print ", "
    print ip_address
    print ", "
    print port
    puts ", _topology)"
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
    #このメソッドのpacket_inはARPパケットのみ
    puts ""#綺麗に表示するためだけの空行
    puts "PathInSliceManager::packet_in(_dpid, packet_in)::add_slice_member?(packet_in)"

    #もし,ARPリプライの宛先・送信元がアドミンならこれをアドミンスライスに追加
    if packet_in.data.target_protocol_address.to_s == "192.168.10.13" ||
          packet_in.data.sender_protocol_address.to_s == "192.168.10.13" then
      puts "  +ARP Packet is related to 192.168.10.13(admin)"
      if packet_in.data.is_a? Pio::Arp::Request
        #もし，ARPリクエストの宛先・送信元がアドミンなら送信元をアドミンスライスに追加
        arp_request = packet_in.data

        puts "--packet_in information(Arp::Request)"
        puts "  +Request is from: #{arp_request.sender_protocol_address.to_s}, #{arp_request.source_mac}"
        puts "  +Request is  to : #{arp_request.target_protocol_address.to_s}"

        unless @slice_admin.member?(packet_in.slice_source)
          puts "==add \"new_user:mac\" to \"slice:admin\"=="
          @slice_admin.add_mac_address(arp_request.source_mac,
                                       dpid: packet_in.dpid, port_no: packet_in.in_port)
        end
      elsif packet_in.data.is_a? Pio::Arp::Reply
        puts "--packet_in information(Arp::Reply)"
        arp_reply = packet_in.data

        puts "  +Reply is from: #{arp_reply.sender_protocol_address}, #{arp_reply.source_mac}"
        puts "  +Reply is  to : #{arp_reply.target_protocol_address}"

        unless @slice_admin.member?(packet_in.slice_source)
          puts "==add \"admin:mac\" to slice:admin\"=="
          @slice_admin.add_mac_address(arp_reply.source_mac,
                                       dpid: packet_in.dpid, port_no: packet_in.in_port)
        end
      end
    end


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
