require './database_loader'

class Material < Struct.new(:name, :category, :get_by, :price, :effect, :effect2, :target_class,
                            :use_by, :has_image, :desc, :level, :min_trade_amount)
  attr_accessor :resources_produce_from
  attr_accessor :resources_produce_to
  attr_accessor :buildings_by_output
  attr_accessor :buildings_by_input
  attr_accessor :building_used_by
end

class Building < Struct.new(
        :name, :category, :cost, :w, :h, :effect, :products,
        :has_image, :has_main_image,
        :desc, :research_cost, :research_prerequired, :inputs,
        :on_ground, :has_worker, :hp,
        :service_effect, :service_target_class, :service_price, :service_num,
        :service_cost, :service_cost_amount,
        :worker_salary, :only_one,
        :get_froms, :get_resources,
      )
end

class Product < Struct.new(:product, :inputs, :cost)
  attr_accessor :building
end

class Trading < Struct.new(:name, :imports, :exports)
end

class Equipment < Struct.new(:name, :category, :desc, :effect, :input, :memo, :has_image)
end

# Ratopiaデータベース
class Database
  RESOURCE_CATEGORIES = %w(食べ物 生活用品 材料)
  BUILDING_CATEGORIES = %w(基盤 原材料 生産 サービス 軍事 飾り 王室 その他)
  EQUIP_CATEGORIES = %w(武器 防具 装身具)
  
  attr_reader :materials, :buildings, :tradings, :equips
  def initialize(_materials, _buildings, _tradings, _equips)
    @materials = _materials
    @buildings = _buildings
    @tradings = _tradings
    @equips = _equips
    verify
  end

  def verify_material_name(mat, msg)
    unless @materials[mat]
      puts "Material #{mat} not found in #{msg}"
    end
  end

  def verify_resource_number_list(list, msg)
    list.each.with_index do |input, i|
      verify_material_name(input[0], msg)
    end
  end

  def verify_building_name(b, msg)
    unless @buildings[b]
      puts "Building #{b} not found in #{msg}"
    end
  end

  def verify_buildings
    @buildings.each do |_,b|
      verify_resource_number_list(b.inputs, "inputs of #{b.name}")

      if b.products
        b.products.each.with_index do |row,i|
          verify_material_name(row.product[0], "product of #{b.name}")
          verify_resource_number_list(row.inputs, "product of #{b.name} #{i}")
        end
      end

      b.get_resources.each do |row|
        verify_material_name(row, "get_resources of #{b.name}")
      end

      b.research_prerequired.each do |e|
        verify_building_name(e, "research_prerequired of #{b.name}")
      end
    end
  end

  def verify_tradings
    @tradings.each do |trading|
      trading.imports.each do |r|
        verify_material_name(r, "imports of #{trading.name}")
      end
      trading.exports.each do |r|
        verify_material_name(r, "exports of #{trading.name}")
      end
    end
  end
  
  def verify
    verify_buildings
    verify_tradings
    provide_resources
  end

  def provide_resources
    @materials.each_value do |r|
      r.resources_produce_to = products_by_output(r).map{|p| p.product[0]}.uniq
      r.resources_produce_from = products_by_input(r).map{|p| p.inputs.map{|i|i[0]}}.flatten.uniq
      r.buildings_by_input = products_by_input(r).map{|p| p.building}.uniq
      r.buildings_by_output = products_by_output(r).map{|p| p.building}.uniq
    end

    # 資源を使用する施設を検索
    @buildings.each_value do |b|
      if b.service_cost
        b.service_cost.each do |r,_|
          find(r).building_used_by = b.name
        end
      end
    end
  end

  def flatten_products
    @buildings.map do |_,b|
      (b.products || []).map do |p|
        [p, b.name]
      end
    end.flatten(1)
  end

  # 名前から資源か施設を取得する
  def find(name_or_obj)
    if name_or_obj.nil?
      nil
    elsif name_or_obj.is_a?(String)
      @materials[name_or_obj] || @buildings[name_or_obj] || @equips[name_or_obj]
    else
      name_or_obj
    end
  end

  def make_all_products_by_input
    list = Hash.new{|h,k| h[k] = Set.new}
    flatten_products.each do |product, building|
      product.inputs.each do |input|
        list[product.product[0]] << product
      end
    end
    list
  end

  # resource からをそれを入力とする生産を取得する
  def products_by_input(r)
    @production_by_input_cache ||= make_all_products_by_input
    r = find(r)
    r && @production_by_input_cache[r.name]
  end
  
  def make_all_products_by_output
    list = Hash.new{|h,k| h[k] = Set.new}
    flatten_products.each do |product, building|
      product.inputs.each do |input|
        list[input[0]] << product
      end
    end
    list
  end
  
  # resource からをそれを出力とする生産を取得する
  def products_by_output(r)
    @production_by_output_cache ||= make_all_products_by_output
    r = find(r)
    r && @production_by_output_cache[r.name]
  end

  def buildings_by_input(r)
    r = find(r)
    @buildings.values.select{|b| b.inputs.any?{|i| i[0] == r.name} }
  end

  def trading_imports_by_resource(r)
    r = find(r)
    @tradings.select{|t| t.imports.include?(r.name)}
  end
  
  def trading_exports_by_resource(r)
    r = find(r)
    @tradings.select{|t| t.exports.include?(r.name)}
  end

  # JSONとしてダンプするためのハッシュ化
  def dump
    blist = @buildings.values.map do |b|
      result = b.to_h
      result[:products] = b.products.map{|p| p.to_h}
      result
    end
    rlist = @materials.values.map do |r|
      r.to_h
    end

    {
      buildings: blist,
      resources: rlist,
    }
  end

end

