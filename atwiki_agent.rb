require 'mechanize'

Page = Struct.new(:id, :name, :src, :tags)

class AtwikiAgent
  def initialize(sid)
    @base_url = 'https://w.atwiki.jp/ratopia'
    @sid = sid

    @m = Mechanize.new 
    @m.agent.allowed_error_codes = [404]
    @m.user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
    cookie = Mechanize::Cookie.new('_atwiki_sid', @sid)
    cookie.domain = '.atwiki.jp'
    cookie.path = '/'
    @m.agent.cookie_jar.add(cookie)
    
  end

  def has_page?(name)
    res = @m.get("#{@base_url}/?page=#{name}")
    # pp res
    if res.form('edit_select').nil?
      # pp res.links
      link = res.links.find{|l| l.text == 'EditThisPage'}
      mo = link.href.match(%r{editx/(\d+)\.html})
      mo[1].to_i
    else
      nil
    end
  end

  def get_page_by_name(name)
    if id = has_page?(name)
      get_page_by_id(id)
    else
      Page.new(nil, name, '', [])
    end
  end
  
  def get_page_by_id(id)
    page = @m.get("#{@base_url}/pedit/#{id}.html")
    form = page.form('edit_form')
    Page.new(id, form.pagename, form.source,form.tags.split(','))
  end
  
  def write_page(page)
    if page.id
      res = @m.get("#{@base_url}/pedit/#{page.id}.html")
      form = res.form('edit_form')
      form['source'] = page.src
      res = form.submit
    else
      res = @m.get("#{@base_url}/?cmd=pedit&page=#{page.name}")
      form = res.form('edit_form')
      form['source'] = page.src
      res = form.submit
    end
  end

  def page_list
    res = @m.get("#{@base_url}/list")
    link_base = '//' + @base_url.gsub('https://','')
    page_links =  res.links.select{|l| l.href =~ %r{#{link_base}/\?page=}}
    page_links.map {|l| l.text}
  end

  
end

