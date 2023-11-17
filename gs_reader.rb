require "google_drive"
require 'json'

class GsReader

  def initialize(service_acount_path)
    @session = GoogleDrive::Session.from_service_account_key(service_acount_path)
  end

  def read_sheet( spreadsheet_id, out_dir, format: :json)
    sp = @session.spreadsheet_by_key(spreadsheet_id)

    FileUtils.mkdir_p(out_dir)

    sp.worksheets.each do |ws|
      STDERR.puts "Reading #{ws.title}..."
      escaped_title = ws.title.gsub('/') { '-' }
      retry_count = 3
      while retry_count >= 0
        begin
          data = rows_to_hash_list(ws.rows)
          break
        rescue Google::Apis::RateLimitError
          puts "Retry, error is #{$!}"
          sleep 100
          retry_count -= 1
          next
        end
      end

      case format 
      when :marshal
        IO.binwrite("#{out_dir}/#{escaped_title}.bin", Marshal.dump(data))
      when :json
        IO.binwrite("#{out_dir}/#{escaped_title}.json", JSON.dump(data))
      else
        raise "invalid format #{format}"
      end
    end
  end

  private

  def rows_to_hash_list(rows)
    data = []
    header = nil
    rows.each do |row|
      # next unless row[0]
      if header
        # data
        next if row[0].to_s[0] == '#'
        row_hash = {}
        header.zip(row).each do |h, col|
          begin
            row_hash[h] = col.to_s
          rescue
            raise "#{$ERROR_INFO} in h=#{h}, col=#{col}"
          end
        end
        data << row_hash
      else
        # header
        header = row.map { |col| (col || '').strip }
      end
    end
    data
  end

end
