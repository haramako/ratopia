require "google_drive"
require './gs_reader'

Material = Struct.new(:name, :category, :get_by, :price, :effect, :effect2, :target_class, :use_by)
Building = Struct.new(:name, :category, :cost, :w, :h, :effect, :products)
Product = Struct.new(:product, :inputs, :cost)

class DatabaseLoader
  CLASS_NAME_MAP = {
    '中流' => 1,
    '上流' => 2
  }

  def initialize
  end

  def fetch
    gs_reader = GsReader.new('service-account.json')
    gs_reader.read_sheet("1p7zXmhLbTcbU-o6FdqpYa2GxUxSq8Jtlc6xZ7La6-XI", 'temp/ratopia')
  end

  def load(force)
    fetch if force
    building_sheet = JSON.parse(IO.binread('temp/ratopia/施設.json'))
    material_sheet = JSON.parse(IO.binread('temp/ratopia/資源.json'))
    materials = parse_materials(material_sheet)
    buildings = parse_buildings(building_sheet)
    Database.new(materials, buildings)
  end

  def parse_class(str)
    CLASS_NAME_MAP[str] || 0
  end

  def parse_materials(rows)
    list = {}
    last_category = ''
    rows.each do |row|
      if row['category'] != ""
        last_category = row['category']
      end
      next if row['name'] == ''
      use_by = (row['use_by'] != '')
      m = Material.new(row['name'], last_category, row['get_by'], row['price'],
                       row['effect'], row['effect2'],
                       parse_class(row['target_class']),
                       use_by)
      list[m.name] = m
    end
    list
  end

  def parse_building_products(row)
    result = []
    9.times do |i|
      product = row["product#{i}"]
      input = row["material#{i}"]
      next if product == "" && input == ""
      cost = row["cost#{i}"].to_i
      # pp input, parse_material_number_list(input)
      result << Product.new(parse_material_number(product), parse_material_number_list(input), cost)
    end
    result
  end

  def parse_material_number(str)
    if str == ""
      []
    else
      mo = str.strip.match(/^(.*)x(\d+)$/)
      if mo
        material_and_number = str.strip.split(/x/)
        [mo[1].strip, mo[2].strip.to_i]
      else
        [str,0]
      end
    end
  end

  def parse_material_number_list(str)
    str.split(/,/).map do |item|
      parse_material_number(item)
    end
  end

  def parse_buildings(rows)
    list = {}
    last_category = nil
    rows.each do |row|
      last_category = row['category'] if row['category'] != ""
      next if row['name'] == ''
      b = Building.new(row['name'], last_category, row['cost'], row['w'], row['h'], row['effect'])
      if b['category'] == '生産' || b['category'] == '原材料'
        b.products = parse_building_products(row)
      end
      list[b.name] = b
    end
    list
  end

end

class Database
  attr_reader :materials, :buildings
  def initialize(_materials, _buildings)
    @materials = _materials
    @buildings = _buildings
  end

  def verify_material_name(mat, msg)
    unless @materials[mat]
      puts "Material #{mat} not found in #{msg}"
    end
  end

  def verify_buildings
    @buildings.each do |_,b|
      next unless b.products
      b.products.each do |row|
        verify_material_name(row.product[0], "product of #{b.name}")
        row.inputs.each.with_index do |input, i|
          verify_material_name(input[0], "input of #{b.name} #{i}")
        end
      end
    end
  end
  
  def verify
    verify_buildings
  end

  def flatten_products
    @buildings.map do |_,b|
      (b.products || []).map do |p|
        [p, b.name]
      end
    end.flatten(1)
  end

end

