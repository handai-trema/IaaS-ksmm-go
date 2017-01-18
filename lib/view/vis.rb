require 'pio'
require 'erb'

module View
  # Topology controller's GUI (vis.js).
  class Vis
    def initialize(output = 'topology.js')
      @output = output
      delete_jsfile()
    end
    def delete_jsfile()
      File.delete "./output/path.js" if File.exist?("./output/path.js")
      fhtml = open("./output/path.js", "w")
      fhtml.write("paths = [];\n")
    end

    # rubocop:disable AbcSize
    def update(_event, _changed, topology)
      outtext = Array.new
      nodes = topology.switches.each_with_object({}) do |each, tmp|
        outtext.push(sprintf("nodes.push({id: %d, label: '%#x', image:DIR+'switch.jpg', shape: 'image'});", each.to_i, each.to_hex))
      end
      topology.links.each do |each|
        # next unless nodes[each.dpid_a] && nodes[each.dpid_b]
        outtext.push(sprintf("edges.push({from: %d, to: %d});", each.dpid_a.to_i, each.dpid_b.to_i))
      end
      #added (2016.11.9) add ellipse with ip_address and link between host and switch
      topology.hosts.each do |each|  #for all host
        outtext.push(sprintf("nodes.push({id: %d, label: '%s', image:DIR+'host.png', shape: 'image'});", each[0].to_i, each[0].to_s))#add ellipse with ip_address(each[1])
        outtext.push(sprintf("edges.push({from: %d, to: %d});", each[0].to_i, each[2].to_i))#add link between host and switch(each[2]:switch dpid)
      end
      @topology = outtext
      File.delete "./output/" + @output if File.exist?("./output/" + @output)
      fhtml = open("./output/" + @output, "w")
      fhtml.write(ERB.new(File.open('./output/template/topology_template.js').read).result(binding))
    end
    # rubocop:enable AbcSize

    def to_s
      "vis.js mode, output = #{@output}"
    end
  end
end
