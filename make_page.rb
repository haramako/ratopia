require 'pp'
require 'optparse'
require 'fileutils'
require 'ruby-graphviz'
require 'erb'

require './database'
require './atwiki_agent'

#====================================================

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

def h_img(w,h)
  "&image(https://img.atwiki.jp/ratopia/pub/x.png,width=#{w},height=#{h})"
end

def h_item(name_num)
  "[[#{name_num[0]}]]x#{name_num[1]}"
end

def h_item_list(items)
  items.map{|i| h_item(i)}.join(", ")
end

#====================================================
def make_building_page(b)
  out = template('building').result_with_hash({b:,})
  IO.write("#{OUTPUT_DIR}/out/buildings/#{b.name}.txt", out)
  download_page(b.name, out, 'building_base') if $download
  upload_page(b.name, out, 'building_base') if $upload
  puts out if !$download && !$upload
end

def make_building_list_page(b)
  out = template('building').result_with_hash({b:,})
  IO.write("#{OUTPUT_DIR}/out/buildings/#{b.name}.txt", out)
  download_page(b.name, out, 'building_base') if $download
  upload_page(b.name, out, 'building_base') if $upload
  puts out if !$download && !$upload
end

def make_page(name)
  b = $db.buildings[name]
  make_building_page(b) if b
end

def make_page_all
  $db.buildings.each_value do |b|
    make_building_page(b)
  end
end

#====================================================

def replace(src, out, base)
  page_src = src.gsub(/\r/,'')
  if page_src == ''
    # 新規ページの場合
    out_src = "//@@自動生成開始@@\n" + out + "\n//@@自動生成終了@@\n" + template(base).result
  else
    mo = page_src.match(%r{//@@自動生成開始@@(.+)@@自動生成終了@@}m)
    if mo
      # 置き換え
      out_src = mo.pre_match + "//@@自動生成開始@@\n" + out + "\n//@@自動生成終了@@" + mo.post_match
    else
      # $$自動生成開始$$がない場合は、頭に足す
      out_src = "//@@自動生成開始@@\n" + out + "\n//@@自動生成終了@@\n" + page_src
    end
  end
  [page_src != out_src, page_src, out_src]
end

def download_page(page_name, out, base)
  page = $wiki.get_page_by_name(page_name)
  changed, page_src, out_src = replace(page.src, out, base)
  puts "Changed #{page_name}" if changed
  IO.write("#{OUTPUT_DIR}/new/buildings/#{page_name}.txt", out_src)
  IO.write("#{OUTPUT_DIR}/old/buildings/#{page_name}.txt", page_src)
end

def upload_page(page_name, out, base)
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

if ARGV.size > 0
  ARGV.each { |name| make_page(name) }
else
  make_page_all
end


