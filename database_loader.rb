require "google_drive"
require './gs_reader'

class DatabaseLoader
  CLASS_NAME_MAP = {
    '中流' => 1,
    '上流' => 2
  }

  def initialize
  end

  def self.load(force)
    DatabaseLoader.new.load(force)
  end

  def load(force)
    fetch if force
    building_sheet = JSON.parse(IO.binread('temp/ratopia/施設.json'))
    material_sheet = JSON.parse(IO.binread('temp/ratopia/資源.json'))
    materials = parse_materials(material_sheet)
    buildings = parse_buildings(building_sheet)
    Database.new(materials, buildings)
  end

  def fetch
    gs_reader = GsReader.new('service-account.json')
    gs_reader.read_sheet("1p7zXmhLbTcbU-o6FdqpYa2GxUxSq8Jtlc6xZ7La6-XI", 'temp/ratopia')
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
      list[row['name']] = Material.new(
        row['name'],
        last_category,
        row['get_by'],
        row['price'],
        row['effect'],
        row['effect2'],
        parse_class(row['target_class']),
        use_by,
        row['has_image'] != '',
        row['desc'],
        row['level'].to_i,
      )
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

      # 素材のリストアップ
      inputs = []
      %w(土 木 葉 石 花びら 木材 木の棒 石材 ロープ 生地).each do |m|
        inputs << [m, row[m].to_i] if row[m] != ''
      end
      inputs += parse_material_number_list(row['others'])

      b = Building.new(
        row['name'],
        last_category,
        row['cost'],
        row['w'],
        row['h'],
        row['effect'],
        nil,
        row['has_image'] != '',
        row['has_main_image'] != '',
        row['desc'],
        row['research_cost'],
        row['research_prerequired'],
        inputs,
        row['on_ground'] != '',
        row['has_worker'] != '',
        row['hp'].to_i,
        row['service_effect'],
        parse_class(row['service_target_class']),
        row['service_price'].to_i,
        parse_material_number_list(row['service_cost']),
        row['service_cost_amount'].to_i,
       )
      
      if b.category == '生産' || b.category == '原材料'
        b.products = parse_building_products(row)
        b.products.each {|p| p.building = b.name }
      end

      list[b.name] = b
    end
    list
  end

end

