require 'pio'
require 'erb'

module View
  # Topology controller's GUI (vis.js).
  class Vis
    def initialize(output = './tmp/topology.json')
      @output = output
    end

    # rubocop:disable AbcSize
    def update(_event, _changed, topology)
      host_without_container = topology.hosts.each_with_object({}) do |each, tmp|
        unless check_container(each, topology.containers)
          tmp[i] = each
          i += 1
        end
      end
      nodes = topology.switches.each_with_object({}) do |each, tmp|
        tmp[each] = { "id"=> each, "label"=> each.to_hex }
      end
      i = 0
      links = topology.links.each_with_object({}) do |each, tmp|
        next unless nodes[each.dpid_a] && nodes[each.dpid_b]
        tmp[i] = { "id"=> 10000+i, "from"=> each.dpid_a, "to"=> each.dpid_b }
        i += 1
      end
      i = 0
      hosts = host_without_container.each_with_object({}) do |each, tmp|
        tmp[i] = { "id"=> 100+i, "label"=> each[0].to_s }
        i += 1
      end
      i = 0
      h_links = host_without_container.each_with_object({}) do |each, tmp|
#        tmp[nodes.length+i] = { "from"=> each[2], "to"=> nodes.length+i+2 }
         tmp[nodes.length+i] = { "id"=> 10000+nodes.length+i, "from"=> each[2], "to"=> 100+i }
        i += 1
      end
      i = 0
      containers = topology.containers.each_with_object({}) do |each, tmp|
        tmp[i] = { "id"=> 1000+i, "label"=> each[0].to_s }
        i += 1
      end
      i = 0
      c_links = topology.containers.each_with_object({}) do |each, tmp|
#        tmp[nodes.length+i] = { "from"=> each[2], "to"=> nodes.length+i+2 }
         server_id = hosts.each_with_object({}) do |server, tmp|
           tmp = server["id"] if server["label"] == each[1].to_s
         end
         tmp[nodes.length+hosts.length+i] = { "id"=> 10000+nodes.length+hosts.length+i, "from"=> server_id, "to"=> 1000+i }
        i += 1
      end
      open(@output, "w") do |io|
        JSON.dump([ "nodes"=> nodes.values, "hosts"=> hosts.values, 
                    "containers"=> containers.values, 
                    "links"=> (links.merge(h_links)).merge(c_links).values, 
                    "paths"=>topology.paths, "slices"=>topology.slices], io)
      end
    end
    # rubocop:enable AbcSize
#slices
    def to_s
      "vizJs mode, output = #{@output}"
    end

    def check_container(mac_address, containers)
      containers.each
        return true if each[0].to_s == mac_address.to_s
      end
      return false
    end

  end
end
