#!/usr/bin/ruby.ruby2.1

require 'rubygems'
require 'logger'
require 'csv'
require 'sequel'
require 'google_drive'

# https://github.com/gimite/google-drive-ruby
# https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md
# http://www.rubydoc.info/gems/google_drive/GoogleDrive/Worksheet

# This script updates a Google Spreadsheet with the results of a database query.
#
# Authentication is performed through the use of a Google "service account,"
# sybase1-cron@xsede-daily-metrics.iam.gserviceaccount.com, currently
# maintained under the xsede.conference.posters@gmail.com (Steven Peckins)
# account.  However, this can be changed at any time, and access to the
# spreadsheet by this service account may be revoked by any authorized user.
#
# Note that Google API access cannot be configured through @illinois.edu
# addresses at this time (but according to the Help Desk, it may be possible in
# the future).

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

service_account_key = '/home/postgres/cron/metrics_daily_report-4b579b6a7fd7.json'

# This is the URL of the Google Sheets worksheet into which the data will be inserted.
worksheet_url  = 'https://spreadsheets.google.com/feeds/worksheets/1Nrp0A1XKkJvvRqi_KcpQ2c9tr_yB9mFdXMZQEZfIovo/private/full/ocf4qj1'

# This is the URL of the Google Drive folder where a copy of the CSV file will be uploaded.
collection_url = 'https://drive.google.com/drive/folders/0B716DDks-5UkX1RmVVo1QTlLZDA'

local_path     = '/afs/ncsa.uiuc.edu/web/irg-internal/production/xsede-metrics.xsede.org'
# Use tmp path for now since permissions are not correct for ^^^
local_path     = '/tmp/tmp.CY4jYqV9ds'
filename       = "metrics-#{Time.now.strftime '%F_%T'}.csv"
logger         = Logger.new "#{local_path}/metrics_daily_report.log"

db_config = {
  :adapter     => 'postgresql',
  :host        => 'tgcdb.xsede.org',
  :port        => '5432',
  :user        => 'xras',
  :password    => 'Gr@Blz0fr',
  :ssl         => 'require',
  :database    => 'teragrid',
  :search_path => 'metrics'
}

# ------------------------------------------------------------------------------

# Log error if we exit with one
at_exit do
  case $!
  when StandardError
    logger.error "#{$!.class}:  #{$!.message}"
    $!.backtrace.each { |line| logger.error "\t#{line}" }
  when NilClass # (no error)
    logger.info 'Completed'
  end
end

cert_path = Gem.loaded_specs['google-api-client'].full_gem_path + '/lib/cacerts.pem'
ENV['SSL_CERT_FILE'] = cert_path

DB = Sequel.connect(db_config)

session = GoogleDrive::Session.from_service_account_key(service_account_key)

query = %q{
    SELECT
        w.wbs_value,
        m.metric_name,
        m.metric_id,
        (w.wbs_value || ' '::text) || w.wbs_name AS wbs_display_name,
        m.definition,
        m.methodology,
        m.is_kpi,
        s.goal_name,
        g.goal_name AS subgoal,
        m.is_annual_only,
        a.aggregation_type,
        m.ts::date AS last_modified,
        t.target_value
    FROM metrics.metrics m
    JOIN metrics.wbs w ON m.wbs_id = w.wbs_id
    JOIN metrics.goals g ON m.goal_id = g.goal_id
    JOIN metrics.goals s ON g.parent_id = s.goal_id
    JOIN metrics.aggregation_types a ON m.aggregation_type_id = a.aggregation_type_id
    JOIN metrics.targets_years t ON m.metric_id = t.metric_id
    ORDER by w.wbs_value, m.metric_id
}

data = DB[query]

# 1) save a CSV file locally

csv = CSV.open "#{local_path}/#{filename}", "wb" do |csv|
  # CSV headers
  csv << data.columns
  # CSV data
  data.map(&:values).reduce(csv, :<<)
end


# 2) upload the file to Google Drive

collection = session.collection_by_url collection_url
collection.upload_from_file csv.path


# 3) update the Google spreadsheet with the current data

worksheet = session.worksheet_by_url(worksheet_url)

# Clear previous values
worksheet.delete_rows 1, worksheet.num_rows

# Add column names to worksheet (row 1, column 1)
worksheet.update_cells 1, 1, [data.columns]

# Add data to worksheet (row 2, column 1)
worksheet.update_cells 2, 1, data.map(&:values)

worksheet.save
