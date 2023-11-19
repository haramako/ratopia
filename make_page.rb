require 'pp'
require 'optparse'
require 'fileutils'
require 'ruby-graphviz'
require 'erb'

require './database'
require './atwiki_agent'

$write_count = 0

#====================================================

def base_url
  'https://img.atwiki.jp/ratopia'
end

def template(filename)
  $templates ||= {}
  unless $templates[filename]
    $templates[filename] = ERB.new(IO.read("view/#{filename}.erb"), trim_mode:'-')
  end
  $templates[filename]
end

def blank(w,h)
  "&image(https://img.atwiki.jp/ratopia/pub/x.png,width=#{w},height=#{h})"
end

def h_icon(x,w=40,h=40,alt:nil, name:true, br:false, link:true,large:false)
  if x.is_a?(String)
    x = $db.buildings[x] || $db.materials[x]
  end

  opt = {}
  opt[:alt] = alt if alt
  opt[:linkpage] = x.name if link
  opt_str = ',' + opt.map{|k,v| "#{k.to_s}=#{v}"}.join(',')
  
  if x.is_a?(Material)
    if x.has_image
      img = "r/#{x.name}.jpg"
    else
      img = "noimage.jpg"
    end
  elsif x.is_a?(Building)
    if x.has_image
      if large
        img = "bl/#{x.name}.jpg"
      else
        img = "b/#{x.name}.jpg"
      end
    else
      img = "noimage.jpg"
    end
  else
    raise
  end
  
  img = "&ref(https://img.atwiki.jp/ratopia/pub/#{img},width=#{w},height=#{h}#{opt_str})"
  
  if name
    br_str = br ? '&br()':''
    "#{img}#{br_str}[[#{x.name}]]"
  else
    img
  end
end

def h_img(filename,w,h)
  "&image(https://img.atwiki.jp/ratopia/pub/#{filename},width=#{w},height=#{h})"
end

def h_item(name_num)
  "#{h_icon(name_num[0])} x #{name_num[1]}"
end

def h_item_list(items)
  items.map{|i| h_item(i)}.join(", ")
end

def h_class(n)
  case n
  when 1
    '中流階層以上'
  when 1
    '上流階層以上'
  else
    '全階層'
  end
end

def h_building(b)
  b = $db.buildings[b] if b.is_a?(String)
  "#{h_icon(b)}[[#{b.name}]]"
end

def h_resource(r)
  r = $db.materials[r] if r.is_a?(String)
  "#{h_icon(r,40,40)}[[#{r.name}]]"
end

def h_txt(txt)
  (txt||'').gsub(/\n/,'&br()')
end

def get_from(r)
  r = $db.materials(r) if r.is_a?(String)
  $db.flatten_products
    .select { |p| p[0].product[0] == r.name }
    .flat_map{|p| [*p[0].inputs.map{|n|n[0]}, p[1]] }
    .uniq
    .sort_by{|x| $db.buildings[x] ? 0 : 1 }
end

#====================================================
def make_building_page(b)
  out = template('building').result_with_hash({b:,})
  output_page(b.name, out, 'building_base')
end

def output_page(page_name, out, base = nil)
    IO.write("#{OUTPUT_DIR}/out/#{page_name}", out)
    download_page(page_name, out) if $download
    upload_page(page_name, out, base) if $upload
    puts out if !$download && !$upload
end

def make_building_list_page
  categories = ['基盤', '原材料', '生産', 'サービス', '軍事', '飾り', '王室']
  building_by_categories = $db.buildings.values.group_by{|b| b.category}

  # アテゴリごと
  categories.each do |category|
    out = template('building_list').result_with_hash({title: "#{category}施設リスト", buildings: building_by_categories[category]})
    output_page(category, out)
  end

  # 全リスト
  out = template('building_list_all').result_with_hash({categories:, building_by_categories:})
  output_page('施設一覧', out)
end

def make_resource_list_page
  categories = ['食べ物', '生活用品', '材料']
  resource_by_categories = $db.materials.values.group_by{|b| b.category}

  # アテゴリごと
  categories.each do |category|
    out = template('resource_list').result_with_hash({category:, resources: resource_by_categories[category]})
    output_page(category, out)
  end

  # 全リスト
  out = template('resource_list_all').result_with_hash({categories:, resource_by_categories:})
  output_page('資源一覧', out)
end

def make_resource_page(r)
  products = $db.flatten_products.select{|p,b| p.product[0] == r.name}
  out = template('resource').result_with_hash({r:,products:})
  output_page(r.name, out, 'resource_base')
end


def make_building_pages
  $db.buildings.each_value do |b|
    make_building_page(b)
  end
end

def make_resource_pages
  $db.materials.each_value do |r|
    make_resource_page(r)
  end
end

def make_page(name)
  case
  when b = $db.buildings[name]
    make_building_page(b)
  when r = $db.materials[name]
    make_resource_page(r)
  else
    case name
    when 'building'
      make_building_pages
    when 'resource'
      make_resource_pages
    when 'building_list'
      make_building_list_page
    when 'resource_list'
      make_resource_list_page
    when 'all'
      ['building_list','resource_list','building','resource'].each do |name|
        make_page(name)
      end
    end
  end
end

#====================================================

BEGIN_MARK = "//@@自動生成開始@@\n//この部分はプログラムで自動生成された部分です。「自動生成終了」の場所までは編集しないでください。編集しても上書きされます！\n"
END_MARK = "\n//この次の行までが、自動生成の部分です。\n//@@自動生成終了@@\n"

def replace(src, out, base)
  page_src = src.gsub(/\r/,'')
  if page_src == ''
    # 新規ページの場合
    out_src = BEGIN_MARK + out + END_MARK + (base ? template(base).result : '')
  else
    mo = page_src.match(%r{//@@自動生成開始@@(.+)@@自動生成終了@@\n}m)
    if mo
      # 置き換え
      out_src = mo.pre_match + BEGIN_MARK + out + END_MARK + mo.post_match
    else
      # $$自動生成開始$$がない場合は、頭に足す
      out_src = BEGIN_MARK + out + END_MARK + page_src
    end
  end
  [page_src != out_src, page_src, out_src]
end

def download_page(page_name, out, base = nil)
  page = $wiki.get_page_by_name(page_name)
  changed, page_src, out_src = replace(page.src, out, base)
  puts "Changed #{page_name}" if changed
  IO.write("#{OUTPUT_DIR}/new/buildings/#{page_name}.txt", out_src)
  IO.write("#{OUTPUT_DIR}/old/buildings/#{page_name}.txt", page_src)
end

def upload_page(page_name, out, base = nil)
  $write_count += 1
  if $write_count >= 50
    puts "Write limit! waite for 10 minites"
    sleep 60*10
    $write_count = 0
  end
  page = $wiki.get_page_by_name(page_name)
  changed, page_src, out_src = replace(page.src, out, base)
  if changed
    puts "Uploading #{page_name}..."
    page.src = out_src
    $wiki.write_page(page)
  end
end

#====================================================

# エントリーポイント
opt = OptionParser.new
opt.on('-f', '--force') { $force = true }
opt.on('--upload') { $upload = true }
opt.on('-d', '--download') { $download = true }
opt.parse!

$db = DatabaseLoader.new.load($force)
$db.verify

$wiki = AtwikiAgent.new(ENV['ATWIKI_SID'])

OUTPUT_DIR = 'output/wiki'

FileUtils.mkdir_p "#{OUTPUT_DIR}/out/buildings"
FileUtils.mkdir_p "#{OUTPUT_DIR}/out/materials"
FileUtils.mkdir_p "#{OUTPUT_DIR}/new/buildings"
FileUtils.mkdir_p "#{OUTPUT_DIR}/new/materials"
FileUtils.mkdir_p "#{OUTPUT_DIR}/old/buildings"
FileUtils.mkdir_p "#{OUTPUT_DIR}/old/materials"

ARGV.each { |name| make_page(name) }
