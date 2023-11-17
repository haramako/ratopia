require 'pp'
require 'optparse'
require 'time'
require 'fileutils'
require 'ruby-graphviz'
require './gs_reader'
require './database'

# エントリーポイント
opt = OptionParser.new
opt.on('--force') { @force = true }
opt.on('--json') { @json = true }
opt.parse!

if @force || !File.exist?('temp')
  require "google_drive"

  gs_reader = GsReader.new('service-account.json')
  gs_reader.read_sheet("1p7zXmhLbTcbU-o6FdqpYa2GxUxSq8Jtlc6xZ7La6-XI", 'temp/ratopia')
end

db = DatabaseLoader.new.load
db.verify

def make_to(db)
  r = Hash.new{|h,k| h[k] = Set.new}
  db.flatten_products.each do |product, building|
    product.inputs.each do |input|
      r[input[0]] << product.product[0]
    end
  end
  r
end

def make_from(db)
  r = Hash.new{|h,k| h[k] = Set.new}
  db.flatten_products.each do |product, building|
    product.inputs.each do |input|
      r[product.product[0]] << input[0]
    end
  end
  r
end

def graph_make_from(db, filename, target_class)
  data = make_from(db)
  data2 = make_to(db)
  g = GraphViz.new( :G, type: :digraph, layout: :dot)
  
  nodes = {}
  (data.keys + data2.keys).uniq.each do |k|
    mat = db.materials[k]

    next if mat.target_class > target_class
    next if mat.category == '交易品'
    
    color = :black
    penwidth = 1
    fillcolor = 'none'
    label = mat.name
    case mat.get_by
    when ''
      shape = :box
    when '採掘'
      shape = :hexagon
      fillcolor = '#bbbbbb'
    else
      shape = :ellipse
      fillcolor = '#bbbbbb'
    end

    class_mark = ['','●','★']
    case mat.category
    when '食べ物'
      fillcolor = '#ff8888'
      label = "#{class_mark[mat.target_class]}#{mat.name}"
    when '生活用品'
      fillcolor = '#88ff88'
      label = "#{class_mark[mat.target_class]}#{mat.name}"
    when '交易品'
      fillcolor = '#8888ff'
    else
      # DO NOTHING
    end

    if mat.use_by
      label = '▼' + label
    end

    nodes[k] = g.add_nodes(
      k,
      shape: shape,
      style: :filled,
      fillcolor: fillcolor, 
      color: color,
      penwidth: penwidth,
      label: label,
    )
  end
  
  data.each do |k,set|
    set.each do |out|
      if nodes[k] && nodes[out]
        if nodes[out] && nodes[k]
          g.add_edge(nodes[out], nodes[k])
        end
      end
    end
  end

  db.buildings.each do |_,b|
    next unless ['生産','原材料'].include?(b.category)
    nodes[b.name] = g.add_nodes(b.name, label: b.name, shape: :house, style: :filled, fillcolor: '#aaaaff')
    b.products.each do |p|
      out = p.product[0]
      if nodes[out]
        g.add_edge(nodes[b.name], nodes[out])
      end
    end
  end

  g.output(png: filename)
end

def graph_make_from2(db, filename)
  data = make_from(db)
  data2 = make_to(db)
  g = GraphViz.new( :G, type: :digraph, layout: :dot)
  
  data = make_from(db)
  data2 = make_to(db)
  nodes = {}
  (data.keys + data2.keys).uniq.each do |k|
    nodes[k] = g.add_nodes(k, shape: :box)
  end

  i = 0
  db.flatten_products.each do |product, building|
    i += 1
    if product.inputs.size <= 1
      g.add_edge(nodes[product.inputs[0][0]], nodes[product.product[0]])
    else
      prod_node = g.add_nodes("#{building}#{i}", label: '', shape: :circle, width: 0.2, height: 0.2)
    product.inputs.each do |input|
      g.add_edge(nodes[input[0]], prod_node)
    end
    g.add_edge(prod_node, nodes[product.product[0]])
    end
  end
  
  g.output(png: filename)
end

# pp make_from(db)
# pp make_to(db)
graph_make_from(db, 'make_from0.png', 0)
graph_make_from(db, 'make_from1.png', 1)
graph_make_from(db, 'make_from2.png', 2)
#graph_make_from2(db, 'make_from2.png')
