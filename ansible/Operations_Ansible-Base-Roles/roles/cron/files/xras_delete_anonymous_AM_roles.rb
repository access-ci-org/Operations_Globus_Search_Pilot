#!/usr/bin/ruby.ruby2.1

require 'logger'
require 'sequel'

# The "Allocation Manager" role that is automatically created by the API when
# it creates a new request will cause issues with e-mail notifications because
# of the blank e-mail field.
#
# Guest users can't be meaningfully reconciled because they have no identifying
# personal information, so this script removes those "anonymous" allocation
# manager roles.

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

log_file = '/afs/ncsa/projects/db/logs/xras/xras_delete_anonymous_AM_roles.log'

# ----------------------------------------------------------------------------

# Note that #connect also accepts a logger option which may be useful for
# debugging, e.g., "Sequel.connect connection_opts, logger: STDOUT"

log_destination = DEBUGGING ? STDOUT : log_file
logger = Logger.new(log_destination, 'monthly')
DB = Sequel.connect(connection_opts)

# ----------------------------------------------------------------------------
# 2016-01-12:  Original version
# 2016-05-23:  Add "Submitter" role; reduce to eight hours from one day

delete_anonymous_allocation_manager_roles = %q{
  DELETE FROM
    request_people_roles
  WHERE
    request_people_role_id IN (
      SELECT
        request_people_role_id
      FROM
        request_people_roles
        INNER JOIN people USING (person_id)
        INNER JOIN requests USING (request_id)
        INNER JOIN request_role_types USING (request_role_type_id)
        INNER JOIN request_status_types USING (request_status_type_id)
      WHERE
        request_role_type IN ('Allocation Manager', 'Submitter')
        AND people.person_id = requests.entry_person
        AND people.is_reconciled = 'f'
        AND people.first_name IS NULL
        AND people.last_name IS NULL
        AND request_status_type != 'Incomplete'
        AND requests.entry_date < now() - interval '8 hours'
    )
  RETURNING *
}

begin
  DB.transaction do
    deleted_roles = DB[delete_anonymous_allocation_manager_roles].all

    # Log the deletions
    logger.info "Deleted #{deleted_roles.count} request roles" <<
      " (request_id, person_id) " <<
      deleted_roles.collect { |role| [role[:request_id], role[:person_id]] }.to_s

    # Don't actually delete anything during testing
    raise Sequel::Rollback if DEBUGGING
  end
rescue e
  logger.error e.message
end
