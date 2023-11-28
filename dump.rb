require './database'

db = DatabaseLoader.load(@force)

puts JSON.pretty_generate(db.dump, {indent: '  '})
