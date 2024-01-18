#!/usr/bin/ruby.ruby2.1

require 'logger'
require 'sequel'

# 2016-10-20: initial version -- mirror of xras_delete_anonymous_AM_roles.rb
# For those actions that are hanging in the system as Incomplete, after a period of time
# they need to be marked as deleted so they won't show up on the Admin GUI

DEBUGGING = false 

# http://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html
connection_opts = {
  adapter: 'postgres',
  host: 'tgcdb.xsede.org',
  database: 'teragrid',
  user: 'xras',
  password: 'Gr@Blz0fr',
  search_path: 'xras'
}

log_file = '/afs/ncsa/projects/db/logs/xras/xras_xsede_mark_as_deleted_incomplete_actions.log'

# ----------------------------------------------------------------------------

# Note that #connect also accepts a logger option which may be useful for
# debugging, e.g., "Sequel.connect connection_opts, logger: STDOUT"

log_destination = DEBUGGING ? STDOUT : log_file
logger = Logger.new(log_destination, 'monthly')
DB = Sequel.connect(connection_opts)

# Requirements for marking an Incomplete action as deleted:
# Incomplete status, there are no reviewer assignments, action is older than 6 months
incomplete_actions_query =  %q{
update xras.actions a
set is_deleted = 't'
from xras.action_status_types ast, xras.allocations_processes ap,
xras.requests r, xras.opportunities o
where ap.allocations_process_name_abbr = 'XSEDE'
and   a.request_id = r.request_id
and   r.opportunity_id = o.opportunity_id
and   o.allocations_process_id = ap.allocations_process_id
and   ast.action_status_type = 'Incomplete'
and   a.action_status_type_id = ast.action_status_type_id
and   a.entry_date < current_date - interval '6 months'
and   a.is_deleted = 'f'
and not exists (select 1 from xras.action_assigned_reviewers aar where aar.action_id = a.action_id)
}

begin
  DB.transaction do
    deleted_actions = DB[incomplete_actions_query].all

    # Log the deletions
    logger.info "Marked as deleted #{deleted_actions.count} incomplete actions" <<
      " (a.action_id, action_status_type_id) " <<
      deleted_actions.collect { |action| [action[:action_id], action[:action_status_type_id]] }.to_s

    # Don't actually delete anything during testing
    raise Sequel::Rollback if DEBUGGING
  end
rescue Sequel::Error => e 
  logger.error e.message
end
