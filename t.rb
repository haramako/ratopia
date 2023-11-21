require 'pp'
require 'optparse'
require 'fileutils'
require 'ruby-graphviz'
require './database'

# エントリーポイント
opt = OptionParser.new
opt.on('--force') { @force = true }
opt.on('--json') { @json = true }
opt.parse!

db = DatabaseLoader.load(@force)

def make_resource_node(g,r)
  color = :black
  penwidth = 1
  fillcolor = 'none'
  label = r.name
  case r.get_by
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
  case r.category
  when '食べ物'
    fillcolor = '#ff8888'
    label = "#{class_mark[r.target_class]}#{r.name}"
  when '生活用品'
    fillcolor = '#88ff88'
    label = "#{class_mark[r.target_class]}#{r.name}"
  else
    # DO NOTHING
  end

  if r.use_by
    # label = '▼' + label
  end

  g.add_nodes(
    r.name,
    shape: shape,
    style: :filled,
    fillcolor: fillcolor, 
    color: color,
    penwidth: penwidth,
    label: label,
  )
end

def make_building_node(g,b)
  g.add_nodes(b.name, label: b.name, shape: :house, style: :filled, fillcolor: '#aaaaff')
end

def graph_make_from(db, filename, target_class)
  g = GraphViz.new( :G, type: :digraph, layout: :dot)

  nodes = {}
  db.materials.values.each do |r|
    next if r.resources_produce_from.empty? && r.resources_produce_to.empty?
    next if r.level > target_class
    
    nodes[r.name] = make_resource_node(g,r)
  end

  db.materials.each_value do |r|
    r.resources_produce_to.each do |to|
      if nodes[r.name] && nodes[to]
        g.add_edge(nodes[r.name], nodes[to])
      end
    end

    # 建物へのノードを追加
    if nodes[r.name]
      r.buildings_by_input.each do |_b|
        b = db.buildings[_b]
        nodes[b.name] = make_building_node(g,b) unless nodes[b.name]
        g.add_edge(nodes[b.name], nodes[r.name])
      end

      if r.building_used_by
        b = db.find(r.building_used_by)
        nodes[b.name] = make_building_node(g,b) unless nodes[b.name]
        g.add_edge(nodes[r.name], nodes[b.name])
      end
    end
  end

  g.output(jpg: filename)
end

FileUtils.mkdir_p('output')
pp db.find('ステーキ')
exit

graph_make_from(db, 'output/production_graph0.jpg', 0)
graph_make_from(db, 'output/production_graph1.jpg', 1)
graph_make_from(db, 'output/production_graph2.jpg', 2)
