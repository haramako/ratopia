require 'pp'
require './atwiki_agent'

wiki = AtwikiAgent.new(ENV['ATWIKI_SID'])

#pp wiki.page_list

#pp wiki.has_page?('test')
#pp wiki.has_page?('test2')

=begin
page = wiki.get_page_by_id(12)
page.src = 'piyoo'
wiki.write_page(page)
=end

t = wiki.get_page_by_name('test')
t2 = wiki.get_page_by_name('test2')

#t2.src = "new"
#wiki.write_page(t2)
pp t



