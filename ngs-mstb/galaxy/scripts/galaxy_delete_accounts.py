"""Delete and purge a list of Galaxy user accounts. This needs a running DB instance, but not a running Galaxy itself.
Run this as a script when your pwd is GALAXY_HOME, and pass config file as `-c` parameter, such as:  -c /etc/galaxy/galaxy.yml
Pass any number of user emails as positional arguments. Pass `all` to delete all accounts.
The primary use case of this script was a need to delete a default admin@galaxy.org account
that always appeared in the Galaxy docker image bgruening/galaxy-stable with a default password,
even when the envars for creating another default admin have been used.
"""
import sys

assert sys.argv[1] == "-c"
emails = sys.argv[:1] + sys.argv[3:]
sys.argv = sys.argv[:3]

## argv is parsed when db_shell is imported
from scripts.db_shell import *

for user in sa_session.query(User):
    if 'all' in emails or user.email in emails:
        user.deleted = True
        user.purged = True
        sa_session.flush()
        print ("Deleted and purged user record: {}".format(user.email))
