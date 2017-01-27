module SliceExtensions
  # Extensions to Pio::PacketIn
  module PacketIn
    def slice_source
      #puts "-------------"
      #print "dpid:"
      #puts dpid
      #print "in_port:"
      #puts in_port
      #print "source_mac:"
      #puts source_mac
      #print "destination_mac:"
      #puts destination_mac
      #print "source_ip_address:"
      #puts source_ip_address.to_s
      #print "destination_ip_address:"
      #puts destination_ip_address.to_s
      { dpid: dpid, port_no: in_port, mac: source_mac }
    end

    def slice_destination(graph)
      graph.fetch(destination_mac).first.to_h.merge(mac: destination_mac)
    rescue KeyError
      nil
    end

    def slice_destination_vm(graph,mac)
      graph.fetch(mac).first.to_h.merge(mac: mac)
    rescue KeyError
      nil
    end
  end

  # Extensions to Pio::Mac
  module Mac
    def to_json(*_)
      %({"name": "#{self}"})
    end
  end
end

module Pio
  # SliceExtensions included
  class PacketIn
    include SliceExtensions::PacketIn
  end

  # SliceExtensions included
  class Mac
    include SliceExtensions::Mac
  end
end
